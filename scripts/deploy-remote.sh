#!/usr/bin/env bash
# deploy-remote.sh — Server-side atomic deployment for OpenClaw on OCI
# Usage: deploy.sh <git-sha> <version>
# Deployed to: /opt/openclaw/scripts/deploy.sh
set -euo pipefail

# ── Configuration ──
DEPLOY_ROOT="/opt/openclaw"
RELEASES_DIR="${DEPLOY_ROOT}/releases"
SHARED_DIR="${DEPLOY_ROOT}/shared"
CURRENT_LINK="${DEPLOY_ROOT}/current"
REPO_URL="https://github.com/ReaperOAK/openclaw.git"
MAX_RELEASES=5
COMPOSE_FILE="docker-compose.production.yml"
PROJECT_NAME="openclaw"
CANARY_PORT=19789

GIT_SHA="${1:?Usage: deploy.sh <git-sha> <version>}"
VERSION="${2:?Usage: deploy.sh <git-sha> <version>}"
SHORT_SHA="${GIT_SHA:0:7}"
RELEASE_NAME="${VERSION}-${SHORT_SHA}"
RELEASE_DIR="${RELEASES_DIR}/${RELEASE_NAME}"
TIMESTAMP=$(date -u +%Y%m%d%H%M%S)

log() { echo "[DEPLOY $(date -u +%H:%M:%S)] $*"; }
die() { log "FATAL: $*"; exit 1; }

cleanup_canary() {
  if [ -f "${RELEASE_DIR}/docker-compose.canary.yml" ]; then
    cd "${RELEASE_DIR}" 2>/dev/null || true
    docker compose -f docker-compose.canary.yml \
      -p "${PROJECT_NAME}-canary" down --remove-orphans 2>/dev/null || true
    rm -f "${RELEASE_DIR}/docker-compose.canary.yml"
  fi
}

trap cleanup_canary EXIT

# ── Pre-flight ──
log "═══════════════════════════════════════════════"
log "  Deploying: ${RELEASE_NAME}"
log "═══════════════════════════════════════════════"
command -v docker >/dev/null 2>&1 || die "docker not found"
command -v git >/dev/null 2>&1 || die "git not found"

mkdir -p "${RELEASES_DIR}" "${SHARED_DIR}" "${DEPLOY_ROOT}/backups/pre-deploy" "${DEPLOY_ROOT}/logs"

# ── Pre-deploy backup ──
if [ -f "${SHARED_DIR}/.env" ]; then
  cp "${SHARED_DIR}/.env" "${DEPLOY_ROOT}/backups/pre-deploy/.env.${TIMESTAMP}"
  log "Backed up .env"
fi
if [ -d "${SHARED_DIR}/openclaw-data" ]; then
  tar -czf "${DEPLOY_ROOT}/backups/pre-deploy/state-${TIMESTAMP}.tar.gz" \
    -C "${SHARED_DIR}" openclaw-data/ 2>/dev/null || log "Warning: state backup skipped"
  log "Backed up openclaw-data"
fi

# ── Clone release ──
[ -d "$RELEASE_DIR" ] && rm -rf "$RELEASE_DIR"
log "Cloning at ${SHORT_SHA}"
git clone --depth 1 "${REPO_URL}" "${RELEASE_DIR}" 2>&1 || die "Git clone failed"
cd "${RELEASE_DIR}"
git fetch origin "${GIT_SHA}" --depth 1 2>/dev/null || true
git checkout "${GIT_SHA}" 2>/dev/null || log "Already at HEAD"

# ── Copy shared config into release ──
[ -f "${SHARED_DIR}/.env" ] && cp "${SHARED_DIR}/.env" "${RELEASE_DIR}/.env"
[ -f "${SHARED_DIR}/${COMPOSE_FILE}" ] && cp "${SHARED_DIR}/${COMPOSE_FILE}" "${RELEASE_DIR}/${COMPOSE_FILE}"

# Inject deploy metadata
{
  echo ""
  echo "# Deploy metadata (auto-injected)"
  echo "DEPLOY_VERSION=${VERSION}"
  echo "DEPLOY_SHA=${GIT_SHA}"
  echo "DEPLOY_TIMESTAMP=${TIMESTAMP}"
  echo "DEPLOY_RELEASE=${RELEASE_NAME}"
} >> "${RELEASE_DIR}/.env"

# ── Build image ──
log "Building Docker image"
cd "${RELEASE_DIR}"
docker compose -f "${COMPOSE_FILE}" build --no-cache 2>&1 || die "Docker build failed"

# ── Canary health check (standalone compose with canary port only) ──
log "Starting canary on port ${CANARY_PORT}"
cat > "${RELEASE_DIR}/docker-compose.canary.yml" << CANARY
services:
  openclaw-gateway:
    image: openclaw:local
    env_file:
      - .env
    environment:
      NODE_ENV: production
      HOME: /home/node
      TERM: xterm-256color
    volumes:
      - /opt/openclaw/shared/openclaw-data:/home/node/.openclaw
      - /opt/openclaw/shared/workspace:/home/node/.openclaw/workspace
    ports:
      - "127.0.0.1:${CANARY_PORT}:18789"
    init: true
    deploy:
      resources:
        limits:
          memory: 2G
          cpus: "2.0"
    command: [ "node", "openclaw.mjs", "gateway", "--allow-unconfigured", "--bind", "lan", "--port", "18789" ]
CANARY

docker compose -f docker-compose.canary.yml \
  -p "${PROJECT_NAME}-canary" up -d 2>&1 || {
  cleanup_canary
  die "Canary start failed"
}

log "Waiting 45s for gateway cold start..."
sleep 45

HEALTH_OK=false
for i in $(seq 1 15); do
  HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 --max-time 10 \
    "http://127.0.0.1:${CANARY_PORT}/" 2>/dev/null || echo "000")
  log "Canary health ${i}/15: HTTP ${HTTP_CODE}"
  if [ "$HTTP_CODE" -ge 200 ] && [ "$HTTP_CODE" -lt 500 ]; then
    HEALTH_OK=true
    log "Canary healthy!"
    break
  fi
  sleep 5
done

cleanup_canary
trap - EXIT

if [ "$HEALTH_OK" != "true" ]; then
  die "Canary health check failed — aborting"
fi

# ── Atomic switch ──
PREVIOUS_RELEASE=""
if [ -L "$CURRENT_LINK" ]; then
  PREVIOUS_RELEASE=$(readlink -f "$CURRENT_LINK")
  log "Previous: $(basename "$PREVIOUS_RELEASE")"
fi

# Stop old production
if [ -n "$PREVIOUS_RELEASE" ] && [ -f "${PREVIOUS_RELEASE}/${COMPOSE_FILE}" ]; then
  log "Stopping previous production"
  cd "$PREVIOUS_RELEASE"
  docker compose -f "${COMPOSE_FILE}" -p "${PROJECT_NAME}" down --remove-orphans 2>&1 || true
fi

# Switch symlink atomically
log "Switching: current → ${RELEASE_NAME}"
ln -sfn "${RELEASE_DIR}" "${CURRENT_LINK}"

# Start production
log "Starting production"
cd "${CURRENT_LINK}"
docker compose -f "${COMPOSE_FILE}" -p "${PROJECT_NAME}" up -d --remove-orphans 2>&1

# Post-deploy verification (gateway takes ~45s to cold start)
log "Waiting 45s for production cold start..."
sleep 45
PROD_OK=false
for i in $(seq 1 15); do
  HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 --max-time 10 \
    "http://127.0.0.1:18789/" 2>/dev/null || echo "000")
  if [ "$HTTP_CODE" -ge 200 ] && [ "$HTTP_CODE" -lt 500 ]; then
    PROD_OK=true
    break
  fi
  sleep 5
done

if [ "$PROD_OK" != "true" ]; then
  log "WARNING: Production unhealthy — auto-rolling back"
  if [ -n "$PREVIOUS_RELEASE" ] && [ -f "${PREVIOUS_RELEASE}/${COMPOSE_FILE}" ]; then
    cd "${CURRENT_LINK}"
    docker compose -f "${COMPOSE_FILE}" -p "${PROJECT_NAME}" down --remove-orphans 2>&1 || true
    ln -sfn "${PREVIOUS_RELEASE}" "${CURRENT_LINK}"
    cd "${CURRENT_LINK}"
    docker compose -f "${COMPOSE_FILE}" -p "${PROJECT_NAME}" up -d --remove-orphans 2>&1
    die "Auto-rolled back to $(basename "$PREVIOUS_RELEASE")"
  fi
  die "Production unhealthy and no previous release to roll back to"
fi

log "Production verified (HTTP ${HTTP_CODE})"

# ── Prune old releases ──
RELEASE_COUNT=$(find "${RELEASES_DIR}" -mindepth 1 -maxdepth 1 -type d | wc -l)
if [ "$RELEASE_COUNT" -gt "$MAX_RELEASES" ]; then
  log "Pruning old releases (keeping ${MAX_RELEASES})"
  CURRENT_REAL=$(readlink -f "$CURRENT_LINK")
  find "${RELEASES_DIR}" -mindepth 1 -maxdepth 1 -type d -printf '%T@ %p\n' | \
    sort -n | head -n -"${MAX_RELEASES}" | awk '{print $2}' | while read -r old; do
      [ "$CURRENT_REAL" = "$old" ] && continue
      log "Removing: $(basename "$old")"
      rm -rf "$old"
    done
fi

docker image prune -f --filter "until=168h" 2>/dev/null || true

log "═══════════════════════════════════════════════"
log "  Deploy complete: ${RELEASE_NAME}"
log "═══════════════════════════════════════════════"
