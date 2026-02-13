#!/usr/bin/env bash
# rollback-remote.sh — Server-side rollback script
# Usage: rollback.sh [release-name]
# If no release specified, rolls back to the previous release.
# Deployed to: /opt/openclaw/scripts/rollback.sh
set -euo pipefail

DEPLOY_ROOT="/opt/openclaw"
RELEASES_DIR="${DEPLOY_ROOT}/releases"
CURRENT_LINK="${DEPLOY_ROOT}/current"
COMPOSE_FILE="docker-compose.production.yml"
PROJECT_NAME="openclaw"

log() { echo "[ROLLBACK $(date -u +%H:%M:%S)] $*"; }

if [ ! -L "$CURRENT_LINK" ]; then
  log "ERROR: No current release symlink found"
  exit 1
fi

CURRENT_RELEASE=$(basename "$(readlink -f "$CURRENT_LINK")")
log "Current release: ${CURRENT_RELEASE}"

if [ -n "${1:-}" ]; then
  TARGET_RELEASE="$1"
else
  # Get the second most recent release (by modification time)
  TARGET_RELEASE=$(find "${RELEASES_DIR}" -mindepth 1 -maxdepth 1 -type d -printf '%T@ %f\n' | \
    sort -rn | awk '{print $2}' | sed -n '2p')
fi

if [ -z "$TARGET_RELEASE" ] || [ ! -d "${RELEASES_DIR}/${TARGET_RELEASE}" ]; then
  log "ERROR: No valid rollback target found"
  log "Available releases:"
  find "${RELEASES_DIR}" -mindepth 1 -maxdepth 1 -type d -printf '%T@ %f\n' | sort -rn | awk '{print "  " $2}'
  exit 1
fi

if [ "$TARGET_RELEASE" = "$CURRENT_RELEASE" ]; then
  log "ERROR: Target release is the same as current — nothing to roll back to"
  exit 1
fi

log "Rolling back to: ${TARGET_RELEASE}"

# Stop current
cd "${CURRENT_LINK}"
docker compose -f "${COMPOSE_FILE}" -p "${PROJECT_NAME}" down --remove-orphans 2>/dev/null || true

# Switch symlink
ln -sfn "${RELEASES_DIR}/${TARGET_RELEASE}" "${CURRENT_LINK}"

# Start previous release
cd "${CURRENT_LINK}"
docker compose -f "${COMPOSE_FILE}" -p "${PROJECT_NAME}" up -d --remove-orphans 2>&1

sleep 5

PROD_RUNNING=$(docker compose -f "${COMPOSE_FILE}" -p "${PROJECT_NAME}" ps --format '{{.Status}}' 2>/dev/null | head -1 || echo "unknown")
log "Rollback complete. Status: ${PROD_RUNNING}"
log "Active release: ${TARGET_RELEASE}"
