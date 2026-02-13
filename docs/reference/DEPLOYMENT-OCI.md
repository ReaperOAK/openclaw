# OpenClaw — Production Deployment to Oracle Cloud (OCI)

> Complete DevOps playbook: fork strategy, server architecture, CI/CD, security
> hardening, and advanced improvements for self-hosted OpenClaw on an OCI Ubuntu
> server.

---

## Table of Contents

- [Part 1 — Git Strategy](#part-1--git-strategy)
- [Part 2 — Server Architecture](#part-2--server-architecture)
- [Part 3 — CI/CD Pipeline](#part-3--cicd-pipeline)
- [Part 4 — Security Hardening](#part-4--security-hardening)
- [Part 5 — Advanced Improvements](#part-5--advanced-improvements)

---

## Part 1 — Git Strategy

### 1.1 Fork vs Direct Clone

**Use a proper GitHub fork.** A direct clone gives you no upstream linkage, no
PR workflow back to upstream, and makes syncing painful. A fork gives you:

- Clean separation of `origin` (your fork) vs `upstream` (openclaw/openclaw)
- GitHub UI for comparing divergence
- Ability to submit PRs upstream if you fix bugs
- Proper commit attribution

```bash
# 1. Fork openclaw/openclaw on GitHub UI → ReaperOAK/openclaw

# 2. Clone YOUR fork
git clone git@github.com:ReaperOAK/openclaw.git
cd openclaw

# 3. Add upstream remote
git remote add upstream https://github.com/openclaw/openclaw.git
git remote set-url --push upstream DISABLE  # prevent accidental pushes

# 4. Verify
git remote -v
origin    git@github.com:ReaperOAK/openclaw.git (fetch)
origin    git@github.com:ReaperOAK/openclaw.git (push)
upstream  https://github.com/openclaw/openclaw.git (fetch)
upstream  DISABLE (push)
```

### 1.2 Branch Strategy

```
upstream/main ──────────────────────────────────────────────→
                    ↓ sync                ↓ sync
main ──────────────●─────────────────────●──────────────────→  (production-ready, your canonical)
  │                                       │
  ├── dev ────────●───●───●──────────────●──────────────────→  (integration branch)
  │    │          │   │   │              │
  │    ├── feat/custom-auth              ├── feat/oci-monitoring
  │    ├── feat/custom-dashboard         └── fix/upstream-compat
  │    └── feat/branding
  │
  └── release/* ──→  (cut from dev, deployed to prod)
```

| Branch | Purpose | Merges From | Deploys To |
| --- | --- | --- | --- |
| `main` | Stable production mirror | `release/*`, upstream sync | Production |
| `dev` | Integration of your features | `feat/*`, `fix/*` | Staging |
| `feat/*` | Individual features | — | Dev/local |
| `fix/*` | Bug fixes | — | Dev/local |
| `release/YYYY.M.D` | Release candidates | `dev` | Staging → Prod |
| `upstream-sync` | Temporary merge branch | `upstream/main` | — |

### 1.3 Isolating Your Custom Modifications

**Golden rule:** Never commit custom code directly to `main`. All your
modifications live on `dev` or feature branches. `main` tracks upstream +
merged releases.

Create a tracking file for your customizations:

```bash
# Create a manifest of your custom changes
cat > CUSTOM_CHANGES.md << 'EOF'
# Custom Modifications (Maintained by ReaperOAK)

## Active Feature Branches
- `feat/custom-auth` — Custom SSO integration
- `feat/branding` — White-label UI changes
- `feat/oci-monitoring` — OCI-specific health checks

## Modified Upstream Files
Track files you frequently modify to watch for merge conflicts:
- `src/gateway/server.ts` — Custom middleware
- `docker-compose.yml` — OCI-specific overrides
- `package.json` — Additional dependencies

## Extensions (Clean Separation)
Prefer using the `extensions/` plugin system for custom code.
This avoids merge conflicts entirely.
EOF
```

**Best practice:** Use the OpenClaw extension/plugin system (`extensions/`)
for custom features whenever possible. Extensions are isolated workspace
packages that never conflict with upstream.

### 1.4 Syncing Upstream Safely

```bash
# ── Periodic upstream sync (do this weekly or before releases) ──

# 1. Fetch upstream changes
git fetch upstream

# 2. Create a temporary sync branch from your main
git checkout main
git checkout -b upstream-sync

# 3. Merge upstream into the sync branch
git merge upstream/main --no-edit

# If conflicts:
#   - Resolve conflicts (prefer upstream for files you don't customize)
#   - git add <resolved-files>
#   - git merge --continue

# 4. Test the merged result
pnpm install
pnpm build
pnpm test

# 5. If tests pass, fast-forward main
git checkout main
git merge upstream-sync --ff-only
# If --ff-only fails, use:
# git merge upstream-sync --no-ff -m "chore: sync upstream $(date +%Y-%m-%d)"

# 6. Cleanup
git branch -d upstream-sync

# 7. Push your updated main
git push origin main

# 8. Rebase dev onto updated main
git checkout dev
git rebase main
# Resolve any conflicts with your custom code
git push origin dev --force-with-lease
```

### 1.5 Merge vs Rebase Decision Matrix

| Scenario | Strategy | Why |
| --- | --- | --- |
| Syncing upstream → `main` | **Merge** | Preserves upstream history, clear merge commits |
| Updating `feat/*` from `dev` | **Rebase** | Clean linear history for features |
| Merging `feat/*` → `dev` | **Merge --no-ff** | Preserves feature boundary in history |
| Cutting `release/*` from `dev` | **Branch** | Snapshot for stabilization |
| Merging `release/*` → `main` | **Merge --no-ff** | Clear release boundary |

### 1.6 Automated Upstream Sync Check (GitHub Actions)

```yaml
# .github/workflows/upstream-sync-check.yml
name: Upstream Sync Check

on:
  schedule:
    - cron: '0 9 * * 1'  # Every Monday 9am UTC
  workflow_dispatch:

jobs:
  check-upstream:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: Check upstream divergence
        run: |
          git remote add upstream https://github.com/openclaw/openclaw.git || true
          git fetch upstream main
          BEHIND=$(git rev-list --count HEAD..upstream/main)
          AHEAD=$(git rev-list --count upstream/main..HEAD)
          echo "## Upstream Sync Status" >> $GITHUB_STEP_SUMMARY
          echo "- Behind upstream: **${BEHIND} commits**" >> $GITHUB_STEP_SUMMARY
          echo "- Ahead of upstream: **${AHEAD} commits** (your customizations)" >> $GITHUB_STEP_SUMMARY
          if [ "$BEHIND" -gt 50 ]; then
            echo "::warning::You are ${BEHIND} commits behind upstream. Sync recommended."
          fi
```

---

## Part 2 — Server Architecture

### 2.1 Technology Choices

| Component | Choice | Rationale |
| --- | --- | --- |
| Process manager | **Docker Compose** | Matches existing Dockerfile, reproducible, resource isolation |
| Reverse proxy | **nginx** | Battle-tested, WebSocket support (required for gateway) |
| SSL | **Let's Encrypt (certbot)** | Free, auto-renewing, production standard |
| Env management | **`.env` files + Docker secrets** | Secure, not in VCS |
| Init system | **systemd** (for Docker Compose) | Survives reboots, journald logging |
| Release model | **Symlinked releases** | Instant rollback, atomic switches |

### 2.2 Server Directory Structure

```
/opt/openclaw/
├── releases/                    # Versioned release dirs
│   ├── 2026.2.13-abc1234/       # <version>-<short-sha>
│   │   ├── docker-compose.yml
│   │   ├── .env                 # Copied from shared (not in git)
│   │   └── ... (full repo checkout)
│   ├── 2026.2.12-def5678/
│   └── 2026.2.11-aaa9999/
├── current -> releases/2026.2.13-abc1234   # Active release symlink
├── shared/                      # Persistent data across releases
│   ├── .env                     # Master environment file
│   ├── openclaw-data/           # Gateway state, sessions, config
│   └── workspace/               # Agent workspace
├── backups/                     # Database/config backups
│   └── pre-deploy/
├── logs/                        # Centralized logs (optional)
└── scripts/
    ├── deploy.sh                # Deployment script
    ├── rollback.sh              # Rollback script
    └── health-check.sh          # Health verification
```

### 2.3 Initial Server Setup

```bash
# ── Run as root on the OCI server ──

# Create deployment user and structure
sudo mkdir -p /opt/openclaw/{releases,shared,backups/pre-deploy,logs,scripts}
sudo mkdir -p /opt/openclaw/shared/{openclaw-data,workspace}
sudo chown -R ubuntu:ubuntu /opt/openclaw

# Install Docker + Docker Compose
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker ubuntu
# Log out and back in for group to take effect

# Install nginx
sudo apt update && sudo apt install -y nginx certbot python3-certbot-nginx

# Verify
docker --version
docker compose version
nginx -v
```

### 2.4 nginx Reverse Proxy

```nginx
# /etc/nginx/sites-available/openclaw
upstream openclaw_gateway {
    server 127.0.0.1:18789;
    keepalive 64;
}

# Rate limiting zones
limit_req_zone $binary_remote_addr zone=api:10m rate=30r/s;
limit_req_zone $binary_remote_addr zone=ws:10m rate=10r/s;

server {
    listen 80;
    server_name your-domain.com;
    return 301 https://$host$request_uri;
}

server {
    listen 443 ssl http2;
    server_name your-domain.com;

    # SSL (managed by certbot)
    ssl_certificate /etc/letsencrypt/live/your-domain.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/your-domain.com/privkey.pem;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384;
    ssl_prefer_server_ciphers off;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 1d;
    ssl_stapling on;
    ssl_stapling_verify on;

    # Security headers
    add_header Strict-Transport-Security "max-age=63072000; includeSubDomains; preload" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;

    # Logging
    access_log /var/log/nginx/openclaw_access.log;
    error_log /var/log/nginx/openclaw_error.log warn;

    # WebSocket support (critical for OpenClaw gateway)
    location / {
        limit_req zone=api burst=50 nodelay;

        proxy_pass http://openclaw_gateway;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        # Timeouts for long-lived WebSocket connections
        proxy_read_timeout 86400s;
        proxy_send_timeout 86400s;

        # Buffering
        proxy_buffering off;
        proxy_cache_bypass $http_upgrade;
    }

    # Health check endpoint (no rate limit)
    location /health {
        proxy_pass http://openclaw_gateway;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        access_log off;
    }

    # Deny access to dotfiles
    location ~ /\. {
        deny all;
        access_log off;
        log_not_found off;
    }
}
```

```bash
# Enable the site and get SSL
sudo ln -sf /etc/nginx/sites-available/openclaw /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default
sudo nginx -t
sudo certbot --nginx -d your-domain.com --non-interactive --agree-tos -m you@email.com
sudo systemctl reload nginx
```

### 2.5 Docker Compose for Production

```yaml
# /opt/openclaw/shared/docker-compose.production.yml
services:
  openclaw-gateway:
    image: openclaw:local
    build:
      context: .
      dockerfile: Dockerfile
    env_file:
      - /opt/openclaw/shared/.env
    environment:
      NODE_ENV: production
      HOME: /home/node
      TERM: xterm-256color
    volumes:
      - /opt/openclaw/shared/openclaw-data:/home/node/.openclaw
      - /opt/openclaw/shared/workspace:/home/node/.openclaw/workspace
    ports:
      - "127.0.0.1:18789:18789"
      - "127.0.0.1:18790:18790"
    init: true
    restart: unless-stopped
    deploy:
      resources:
        limits:
          memory: 2G
          cpus: "2.0"
        reservations:
          memory: 512M
    healthcheck:
      test: ["CMD", "node", "-e", "fetch('http://localhost:18789/').then(r => process.exit(r.ok ? 0 : 1)).catch(() => process.exit(1))"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s
    logging:
      driver: "json-file"
      options:
        max-size: "50m"
        max-file: "5"
    command:
      [
        "node",
        "dist/index.js",
        "gateway",
        "--bind",
        "lan",
        "--port",
        "18789",
      ]
```

### 2.6 .env Template

```bash
# /opt/openclaw/shared/.env
# ── OpenClaw Gateway Configuration ──
OPENCLAW_GATEWAY_TOKEN=<generate-with: openssl rand -base64 32>
OPENCLAW_GATEWAY_PASSWORD=<strong-password>

# ── AI Provider Keys ──
# CLAUDE_AI_SESSION_KEY=
# CLAUDE_WEB_SESSION_KEY=
# OPENAI_API_KEY=
# ANTHROPIC_API_KEY=

# ── Channel Tokens ──
# TELEGRAM_BOT_TOKEN=
# DISCORD_BOT_TOKEN=
# SLACK_BOT_TOKEN=

# ── Deployment metadata (set by CI/CD) ──
DEPLOY_VERSION=
DEPLOY_SHA=
DEPLOY_TIMESTAMP=
```

### 2.7 systemd Service

```ini
# /etc/systemd/system/openclaw.service
[Unit]
Description=OpenClaw AI Gateway (Docker Compose)
After=docker.service network-online.target
Requires=docker.service
Wants=network-online.target

[Service]
Type=oneshot
RemainAfterExit=yes
User=ubuntu
Group=ubuntu
WorkingDirectory=/opt/openclaw/current
ExecStart=/usr/bin/docker compose -f docker-compose.production.yml up -d --remove-orphans
ExecStop=/usr/bin/docker compose -f docker-compose.production.yml down
ExecReload=/usr/bin/docker compose -f docker-compose.production.yml restart
TimeoutStartSec=120
TimeoutStopSec=60

[Install]
WantedBy=multi-user.target
```

```bash
sudo systemctl daemon-reload
sudo systemctl enable openclaw.service
```

---

## Part 3 — CI/CD Pipeline

### 3.1 GitHub Secrets Required

Set these in your fork's **Settings → Secrets and variables → Actions**:

| Secret Name | Value |
| --- | --- |
| `OCI_SSH_PRIVATE_KEY` | Contents of your SSH private key |
| `OCI_SSH_HOST` | `80.225.219.45` |
| `OCI_SSH_USER` | `ubuntu` |
| `OCI_SSH_PORT` | `22` (or custom) |
| `DEPLOY_WEBHOOK_URL` | (Optional) Slack/Discord webhook for notifications |

### 3.2 Deployment Script (Server-Side)

```bash
#!/usr/bin/env bash
# /opt/openclaw/scripts/deploy.sh
# Usage: deploy.sh <git-ref> <version>
set -euo pipefail

# ── Configuration ──
DEPLOY_ROOT="/opt/openclaw"
RELEASES_DIR="${DEPLOY_ROOT}/releases"
SHARED_DIR="${DEPLOY_ROOT}/shared"
CURRENT_LINK="${DEPLOY_ROOT}/current"
REPO_URL="git@github.com:ReaperOAK/openclaw.git"
MAX_RELEASES=5

GIT_REF="${1:?Usage: deploy.sh <git-ref> <version>}"
VERSION="${2:?Usage: deploy.sh <git-ref> <version>}"
SHORT_SHA=$(echo "$GIT_REF" | cut -c1-7)
RELEASE_NAME="${VERSION}-${SHORT_SHA}"
RELEASE_DIR="${RELEASES_DIR}/${RELEASE_NAME}"
TIMESTAMP=$(date -u +%Y%m%d%H%M%S)

log() { echo "[DEPLOY $(date -u +%H:%M:%S)] $*"; }

# ── Pre-flight ──
log "Starting deployment: ${RELEASE_NAME}"

if [ -d "$RELEASE_DIR" ]; then
  log "Release ${RELEASE_NAME} already exists — removing stale dir"
  rm -rf "$RELEASE_DIR"
fi

# ── Backup current state ──
if [ -L "$CURRENT_LINK" ]; then
  PREVIOUS_RELEASE=$(readlink -f "$CURRENT_LINK")
  log "Previous release: $(basename "$PREVIOUS_RELEASE")"

  # Backup config/state
  cp "${SHARED_DIR}/.env" "${DEPLOY_ROOT}/backups/pre-deploy/.env.${TIMESTAMP}" 2>/dev/null || true
fi

# ── Clone release ──
log "Cloning ${GIT_REF} into ${RELEASE_DIR}"
git clone --depth 1 --branch "${GIT_REF}" "${REPO_URL}" "${RELEASE_DIR}" 2>/dev/null || \
  git clone --depth 1 "${REPO_URL}" "${RELEASE_DIR}" && \
  cd "${RELEASE_DIR}" && git checkout "${GIT_REF}"

cd "${RELEASE_DIR}"

# ── Copy shared config ──
cp "${SHARED_DIR}/.env" "${RELEASE_DIR}/.env"
cp "${SHARED_DIR}/docker-compose.production.yml" "${RELEASE_DIR}/docker-compose.production.yml"

# ── Build Docker image ──
log "Building Docker image"
docker compose -f docker-compose.production.yml build --no-cache

# ── Health check on new container (pre-switch) ──
log "Starting new container for health check"
docker compose -f docker-compose.production.yml -p "openclaw-canary" up -d

# Wait for container health
HEALTH_RETRIES=15
HEALTH_WAIT=4
for i in $(seq 1 $HEALTH_RETRIES); do
  sleep $HEALTH_WAIT
  STATUS=$(docker inspect --format='{{.State.Health.Status}}' "$(docker compose -f docker-compose.production.yml -p openclaw-canary ps -q openclaw-gateway 2>/dev/null)" 2>/dev/null || echo "unknown")
  log "Health check attempt ${i}/${HEALTH_RETRIES}: ${STATUS}"
  if [ "$STATUS" = "healthy" ]; then
    log "New release is healthy!"
    break
  fi
  if [ "$i" -eq "$HEALTH_RETRIES" ]; then
    log "ERROR: Health check failed after ${HEALTH_RETRIES} attempts"
    docker compose -f docker-compose.production.yml -p "openclaw-canary" down --remove-orphans
    exit 1
  fi
done

# ── Stop canary, switch symlink, start production ──
log "Stopping canary container"
docker compose -f docker-compose.production.yml -p "openclaw-canary" down --remove-orphans

log "Switching symlink to new release"
ln -sfn "${RELEASE_DIR}" "${CURRENT_LINK}"

log "Starting production container"
cd "${CURRENT_LINK}"
docker compose -f docker-compose.production.yml -p "openclaw" up -d --remove-orphans

# ── Verify production is running ──
sleep 5
PROD_STATUS=$(docker compose -f docker-compose.production.yml -p "openclaw" ps --format '{{.Status}}' 2>/dev/null | head -1)
log "Production status: ${PROD_STATUS}"

# ── Cleanup old releases ──
RELEASE_COUNT=$(ls -1d "${RELEASES_DIR}"/*/ 2>/dev/null | wc -l)
if [ "$RELEASE_COUNT" -gt "$MAX_RELEASES" ]; then
  log "Cleaning old releases (keeping ${MAX_RELEASES})"
  ls -1dt "${RELEASES_DIR}"/*/ | tail -n +$((MAX_RELEASES + 1)) | while read -r old_release; do
    log "Removing old release: $(basename "$old_release")"
    rm -rf "$old_release"
  done
fi

log "Deployment complete: ${RELEASE_NAME}"
```

### 3.3 Rollback Script

```bash
#!/usr/bin/env bash
# /opt/openclaw/scripts/rollback.sh
# Usage: rollback.sh [release-name]   (defaults to previous release)
set -euo pipefail

DEPLOY_ROOT="/opt/openclaw"
RELEASES_DIR="${DEPLOY_ROOT}/releases"
CURRENT_LINK="${DEPLOY_ROOT}/current"

log() { echo "[ROLLBACK $(date -u +%H:%M:%S)] $*"; }

CURRENT_RELEASE=$(basename "$(readlink -f "$CURRENT_LINK")")
log "Current release: ${CURRENT_RELEASE}"

if [ -n "${1:-}" ]; then
  TARGET_RELEASE="$1"
else
  # Get the second most recent release
  TARGET_RELEASE=$(ls -1t "${RELEASES_DIR}" | sed -n '2p')
fi

if [ -z "$TARGET_RELEASE" ] || [ ! -d "${RELEASES_DIR}/${TARGET_RELEASE}" ]; then
  log "ERROR: No valid rollback target found"
  ls -1t "${RELEASES_DIR}"
  exit 1
fi

log "Rolling back to: ${TARGET_RELEASE}"

# Stop current
cd "${CURRENT_LINK}"
docker compose -f docker-compose.production.yml -p "openclaw" down --remove-orphans 2>/dev/null || true

# Switch symlink
ln -sfn "${RELEASES_DIR}/${TARGET_RELEASE}" "${CURRENT_LINK}"

# Start previous release
cd "${CURRENT_LINK}"
docker compose -f docker-compose.production.yml -p "openclaw" up -d --remove-orphans

sleep 5
log "Rollback complete. Active release: ${TARGET_RELEASE}"
docker compose -f docker-compose.production.yml -p "openclaw" ps
```

### 3.4 Health Check Script

```bash
#!/usr/bin/env bash
# /opt/openclaw/scripts/health-check.sh
set -euo pipefail

MAX_RETRIES=${1:-10}
WAIT_SECONDS=${2:-3}
ENDPOINT="http://127.0.0.1:18789/"

for i in $(seq 1 "$MAX_RETRIES"); do
  HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$ENDPOINT" 2>/dev/null || echo "000")
  if [ "$HTTP_CODE" -ge 200 ] && [ "$HTTP_CODE" -lt 500 ]; then
    echo "Health check passed (HTTP ${HTTP_CODE})"
    exit 0
  fi
  echo "Attempt ${i}/${MAX_RETRIES}: HTTP ${HTTP_CODE}"
  sleep "$WAIT_SECONDS"
done

echo "Health check FAILED after ${MAX_RETRIES} attempts"
exit 1
```

### 3.5 GitHub Actions Workflow

```yaml
# .github/workflows/deploy-oci.yml
name: Deploy to OCI

on:
  push:
    branches: [main]
    paths-ignore:
      - 'docs/**'
      - '**/*.md'
      - '**/*.mdx'
      - '.agents/**'
      - 'skills/**'
      - 'apps/macos/**'
      - 'apps/ios/**'
      - 'apps/android/**'
  workflow_dispatch:
    inputs:
      ref:
        description: 'Git ref to deploy (branch, tag, or SHA)'
        required: false
        default: 'main'

concurrency:
  group: deploy-oci
  cancel-in-progress: false  # Never cancel in-progress deploys

env:
  DEPLOY_USER: ubuntu
  DEPLOY_DIR: /opt/openclaw

jobs:
  # ── Gate: Run tests before deploying ──
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Setup pnpm
        uses: pnpm/action-setup@v4

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: 22
          cache: pnpm

      - name: Install dependencies
        run: pnpm install --frozen-lockfile

      - name: Type check
        run: pnpm tsgo

      - name: Lint
        run: pnpm lint

      - name: Build
        run: pnpm build

      - name: Test
        run: pnpm test

  # ── Deploy to OCI server ──
  deploy:
    needs: test
    runs-on: ubuntu-latest
    environment:
      name: production
      url: https://your-domain.com
    steps:
      - name: Checkout
        uses: actions/checkout@v4
        with:
          ref: ${{ github.event.inputs.ref || github.sha }}

      - name: Extract version info
        id: version
        run: |
          VERSION=$(node -p "require('./package.json').version")
          SHORT_SHA=$(echo "${{ github.sha }}" | cut -c1-7)
          echo "version=${VERSION}" >> "$GITHUB_OUTPUT"
          echo "short_sha=${SHORT_SHA}" >> "$GITHUB_OUTPUT"
          echo "release_name=${VERSION}-${SHORT_SHA}" >> "$GITHUB_OUTPUT"

      - name: Configure SSH
        run: |
          mkdir -p ~/.ssh
          echo "${{ secrets.OCI_SSH_PRIVATE_KEY }}" > ~/.ssh/deploy_key
          chmod 600 ~/.ssh/deploy_key
          ssh-keyscan -H ${{ secrets.OCI_SSH_HOST }} >> ~/.ssh/known_hosts 2>/dev/null

      - name: Deploy to server
        env:
          SSH_CMD: ssh -i ~/.ssh/deploy_key -o StrictHostKeyChecking=accept-new -o ConnectTimeout=30 ${{ env.DEPLOY_USER }}@${{ secrets.OCI_SSH_HOST }}
          SCP_CMD: scp -i ~/.ssh/deploy_key -o StrictHostKeyChecking=accept-new
        run: |
          set -euo pipefail

          RELEASE_NAME="${{ steps.version.outputs.release_name }}"
          RELEASE_DIR="${{ env.DEPLOY_DIR }}/releases/${RELEASE_NAME}"

          echo "::group::Deploying ${RELEASE_NAME}"

          # Upload deploy script (idempotent)
          $SCP_CMD scripts/deploy-remote.sh ${{ env.DEPLOY_USER }}@${{ secrets.OCI_SSH_HOST }}:${{ env.DEPLOY_DIR }}/scripts/deploy.sh
          $SSH_CMD "chmod +x ${{ env.DEPLOY_DIR }}/scripts/deploy.sh"

          # Execute deployment
          $SSH_CMD "${{ env.DEPLOY_DIR }}/scripts/deploy.sh '${{ github.sha }}' '${{ steps.version.outputs.version }}'"

          echo "::endgroup::"

      - name: Verify deployment
        run: |
          SSH_CMD="ssh -i ~/.ssh/deploy_key -o StrictHostKeyChecking=accept-new ${{ env.DEPLOY_USER }}@${{ secrets.OCI_SSH_HOST }}"

          # Run remote health check
          $SSH_CMD "${{ env.DEPLOY_DIR }}/scripts/health-check.sh 10 3"

      - name: Rollback on failure
        if: failure()
        run: |
          SSH_CMD="ssh -i ~/.ssh/deploy_key -o StrictHostKeyChecking=accept-new ${{ env.DEPLOY_USER }}@${{ secrets.OCI_SSH_HOST }}"
          echo "::warning::Deployment failed — initiating rollback"
          $SSH_CMD "${{ env.DEPLOY_DIR }}/scripts/rollback.sh" || true

      - name: Cleanup SSH
        if: always()
        run: rm -f ~/.ssh/deploy_key

      - name: Notify deployment
        if: always()
        run: |
          STATUS="${{ job.status }}"
          VERSION="${{ steps.version.outputs.release_name }}"
          if [ -n "${{ secrets.DEPLOY_WEBHOOK_URL }}" ]; then
            curl -s -X POST "${{ secrets.DEPLOY_WEBHOOK_URL }}" \
              -H "Content-Type: application/json" \
              -d "{\"content\": \"🚀 OpenClaw deploy **${VERSION}**: ${STATUS}\"}" || true
          fi
          echo "## Deployment: ${STATUS}" >> "$GITHUB_STEP_SUMMARY"
          echo "- Release: \`${VERSION}\`" >> "$GITHUB_STEP_SUMMARY"
          echo "- SHA: \`${{ github.sha }}\`" >> "$GITHUB_STEP_SUMMARY"
          echo "- Triggered by: ${{ github.actor }}" >> "$GITHUB_STEP_SUMMARY"
```

---

## Part 4 — Security Hardening

### 4.1 SSH Hardening

```bash
# /etc/ssh/sshd_config.d/hardening.conf
# ── Create this file on the OCI server ──

# Disable password auth entirely
PasswordAuthentication no
ChallengeResponseAuthentication no
UsePAM yes

# Disable root login
PermitRootLogin no

# Only allow specific users
AllowUsers ubuntu

# Key-based auth only
PubkeyAuthentication yes
AuthorizedKeysFile .ssh/authorized_keys

# Restrict algorithms
KexAlgorithms curve25519-sha256,curve25519-sha256@libssh.org
Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com
MACs hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com

# Session limits
MaxAuthTries 3
MaxSessions 5
LoginGraceTime 30

# Disable unused features
X11Forwarding no
AllowTcpForwarding no
AllowStreamLocalForwarding no
PermitTunnel no

# Logging
LogLevel VERBOSE
```

```bash
# Apply SSH hardening
sudo cp /path/to/hardening.conf /etc/ssh/sshd_config.d/hardening.conf
sudo sshd -t  # Validate config
sudo systemctl restart sshd

# IMPORTANT: Keep your current session open and test in a new terminal!
ssh -i ~/path/to/key ubuntu@80.225.219.45
```

### 4.2 Firewall (UFW)

```bash
# Reset and configure UFW
sudo ufw --force reset

# Default deny incoming, allow outgoing
sudo ufw default deny incoming
sudo ufw default allow outgoing

# SSH (rate-limited)
sudo ufw limit 22/tcp comment 'SSH rate-limited'
# If using a custom SSH port:
# sudo ufw limit <port>/tcp comment 'SSH custom'

# HTTP + HTTPS (nginx)
sudo ufw allow 80/tcp comment 'HTTP'
sudo ufw allow 443/tcp comment 'HTTPS'

# OpenClaw gateway (only via nginx, NOT directly exposed)
# DO NOT: sudo ufw allow 18789  ← This would bypass nginx

# Enable firewall
sudo ufw enable

# Verify
sudo ufw status verbose
```

### 4.3 Fail2ban

```bash
sudo apt install -y fail2ban

# Create jail configuration
sudo tee /etc/fail2ban/jail.local << 'EOF'
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 3
backend = systemd
banaction = ufw

[sshd]
enabled = true
port = ssh
filter = sshd
maxretry = 3
bantime = 86400

[nginx-http-auth]
enabled = true
port = http,https
filter = nginx-http-auth
maxretry = 5

[nginx-limit-req]
enabled = true
port = http,https
filter = nginx-limit-req
maxretry = 10
findtime = 120
bantime = 600
EOF

sudo systemctl enable fail2ban
sudo systemctl restart fail2ban
sudo fail2ban-client status
```

### 4.4 Protect .env and Secrets

```bash
# Restrict .env permissions
chmod 600 /opt/openclaw/shared/.env
chown ubuntu:ubuntu /opt/openclaw/shared/.env

# Ensure .env is NEVER in git
echo ".env" >> /opt/openclaw/.gitignore

# Restrict openclaw-data (contains sessions, tokens)
chmod 700 /opt/openclaw/shared/openclaw-data

# Ensure SSH keys have correct permissions
chmod 700 ~/.ssh
chmod 600 ~/.ssh/authorized_keys
chmod 600 ~/.ssh/*.key 2>/dev/null || true
```

### 4.5 Automatic Security Updates

```bash
sudo apt install -y unattended-upgrades
sudo dpkg-reconfigure -plow unattended-upgrades

# Verify
sudo systemctl status unattended-upgrades
```

### 4.6 Backup Strategy

```bash
#!/usr/bin/env bash
# /opt/openclaw/scripts/backup.sh
# Cron: 0 3 * * * /opt/openclaw/scripts/backup.sh
set -euo pipefail

BACKUP_DIR="/opt/openclaw/backups"
TIMESTAMP=$(date -u +%Y%m%d_%H%M%S)
BACKUP_FILE="${BACKUP_DIR}/openclaw-backup-${TIMESTAMP}.tar.gz"
MAX_BACKUPS=14

log() { echo "[BACKUP $(date -u +%H:%M:%S)] $*"; }

log "Starting backup"

# Backup config + state
tar -czf "$BACKUP_FILE" \
  -C /opt/openclaw/shared \
  .env \
  openclaw-data/ \
  2>/dev/null || true

# Verify archive integrity
tar -tzf "$BACKUP_FILE" > /dev/null 2>&1
BACKUP_SIZE=$(du -h "$BACKUP_FILE" | cut -f1)
log "Backup created: ${BACKUP_FILE} (${BACKUP_SIZE})"

# Prune old backups
BACKUP_COUNT=$(find "$BACKUP_DIR" -name "openclaw-backup-*.tar.gz" | wc -l)
if [ "$BACKUP_COUNT" -gt "$MAX_BACKUPS" ]; then
  find "$BACKUP_DIR" -name "openclaw-backup-*.tar.gz" -type f | \
    sort | head -n -"$MAX_BACKUPS" | xargs rm -f
  log "Pruned old backups (kept ${MAX_BACKUPS})"
fi

log "Backup complete"
```

```bash
chmod +x /opt/openclaw/scripts/backup.sh

# Schedule daily at 3 AM UTC
(crontab -l 2>/dev/null; echo "0 3 * * * /opt/openclaw/scripts/backup.sh >> /opt/openclaw/logs/backup.log 2>&1") | crontab -
```

---

## Part 5 — Advanced Improvements

### 5.1 Pre-Deploy Database/State Backup

The deploy script already calls backup as a pre-flight step. To make it
explicit, add to the deploy workflow:

```bash
# Add to deploy.sh, before the clone step:

log "Running pre-deploy backup"
/opt/openclaw/scripts/backup.sh
```

### 5.2 Health Check With Auto-Rollback

Already integrated in the deploy script (Section 3.2), but here's the enhanced
standalone version:

```bash
#!/usr/bin/env bash
# /opt/openclaw/scripts/deploy-safe.sh
# Wraps deploy.sh with automatic rollback on any failure
set -euo pipefail

DEPLOY_ROOT="/opt/openclaw"
CURRENT_BEFORE=$(readlink -f "${DEPLOY_ROOT}/current" 2>/dev/null || echo "none")

log() { echo "[SAFE-DEPLOY $(date -u +%H:%M:%S)] $*"; }

# Run the actual deployment
if ! "${DEPLOY_ROOT}/scripts/deploy.sh" "$@"; then
  log "ERROR: Deployment failed"

  if [ "$CURRENT_BEFORE" != "none" ] && [ -d "$CURRENT_BEFORE" ]; then
    log "Auto-rolling back to: $(basename "$CURRENT_BEFORE")"
    ln -sfn "$CURRENT_BEFORE" "${DEPLOY_ROOT}/current"
    cd "${DEPLOY_ROOT}/current"
    docker compose -f docker-compose.production.yml -p "openclaw" up -d --remove-orphans
    log "Rollback complete"
  else
    log "CRITICAL: No previous release to roll back to!"
  fi
  exit 1
fi

# Post-deploy health verification
log "Running post-deploy health check"
if ! "${DEPLOY_ROOT}/scripts/health-check.sh" 15 4; then
  log "ERROR: Post-deploy health check failed — rolling back"
  if [ "$CURRENT_BEFORE" != "none" ] && [ -d "$CURRENT_BEFORE" ]; then
    ln -sfn "$CURRENT_BEFORE" "${DEPLOY_ROOT}/current"
    cd "${DEPLOY_ROOT}/current"
    docker compose -f docker-compose.production.yml -p "openclaw" down --remove-orphans 2>/dev/null || true
    docker compose -f docker-compose.production.yml -p "openclaw" up -d --remove-orphans
    log "Rollback complete"
  fi
  exit 1
fi

log "Deployment verified and healthy"
```

### 5.3 Logging Setup

```bash
# ── Structured logging with logrotate ──

# Create logrotate config for OpenClaw
sudo tee /etc/logrotate.d/openclaw << 'EOF'
/opt/openclaw/logs/*.log {
    daily
    missingok
    rotate 30
    compress
    delaycompress
    notifempty
    create 0644 ubuntu ubuntu
    sharedscripts
    postrotate
        /usr/bin/docker compose -f /opt/openclaw/current/docker-compose.production.yml -p openclaw restart 2>/dev/null || true
    endscript
}
EOF

# Docker logs are already handled by json-file driver (see docker-compose)
# View logs:
docker compose -f /opt/openclaw/current/docker-compose.production.yml -p openclaw logs -f --tail 100

# Or via journald for systemd-managed:
journalctl -u openclaw.service -f --no-pager
```

### 5.4 Monitoring Suggestions

| Tool | Purpose | Setup Effort | Cost |
| --- | --- | --- | --- |
| **Uptime Kuma** | Self-hosted uptime monitor | Low (Docker) | Free |
| **Prometheus + Grafana** | Metrics + dashboards | Medium | Free |
| **Netdata** | Real-time system monitoring | Low (`bash <(curl -Ss https://get.netdata.cloud/kickstart.sh)`) | Free |
| **Better Stack** | Hosted uptime + logs | None | Freemium |
| **Sentry** | Error tracking | Low (SDK) | Freemium |

Quick win — Uptime Kuma alongside OpenClaw:

```yaml
# Add to docker-compose.production.yml
  uptime-kuma:
    image: louislam/uptime-kuma:1
    volumes:
      - /opt/openclaw/shared/uptime-kuma:/app/data
    ports:
      - "127.0.0.1:3001:3001"
    restart: unless-stopped
```

Then add a nginx location block:

```nginx
location /status/ {
    proxy_pass http://127.0.0.1:3001/;
    proxy_set_header Host $host;
    # Add basic auth for protection
    auth_basic "Monitoring";
    auth_basic_user_file /etc/nginx/.htpasswd;
}
```

### 5.5 Complete Deployment Lifecycle Diagram

```
┌─────────────┐     ┌──────────┐     ┌───────────────┐
│  git push   │ ──→ │  GitHub  │ ──→ │  CI Pipeline  │
│  to main    │     │  Actions │     │  test + lint   │
└─────────────┘     └──────────┘     └───────┬───────┘
                                             │ pass
                                             ▼
                                     ┌───────────────┐
                                     │  SSH into OCI  │
                                     │  server        │
                                     └───────┬───────┘
                                             │
                    ┌────────────────────────┼────────────────────────┐
                    ▼                        ▼                        ▼
            ┌──────────────┐     ┌───────────────────┐     ┌────────────────┐
            │ Pre-deploy   │     │ Clone + Build      │     │ Health Check   │
            │ backup       │ ──→ │ Docker image       │ ──→ │ canary test    │
            └──────────────┘     └───────────────────┘     └───────┬────────┘
                                                                    │
                                                        ┌───────────┴───────────┐
                                                        │                       │
                                                   ✅ healthy              ❌ unhealthy
                                                        │                       │
                                                        ▼                       ▼
                                                ┌──────────────┐       ┌──────────────┐
                                                │ Switch        │       │ Auto         │
                                                │ symlink       │       │ rollback     │
                                                │ + restart     │       │ + alert      │
                                                └──────┬───────┘       └──────────────┘
                                                       │
                                                       ▼
                                                ┌──────────────┐
                                                │ Cleanup old  │
                                                │ releases     │
                                                └──────────────┘
```

### 5.6 Quick Reference Commands

```bash
# ── Server Management ──
# View current release
readlink /opt/openclaw/current

# View all releases
ls -lt /opt/openclaw/releases/

# View logs
docker compose -f /opt/openclaw/current/docker-compose.production.yml -p openclaw logs -f

# Manual rollback
/opt/openclaw/scripts/rollback.sh

# Rollback to specific release
/opt/openclaw/scripts/rollback.sh 2026.2.12-def5678

# Restart without redeploying
sudo systemctl restart openclaw

# Check service status
sudo systemctl status openclaw
docker compose -f /opt/openclaw/current/docker-compose.production.yml -p openclaw ps

# Manual backup
/opt/openclaw/scripts/backup.sh

# Check firewall
sudo ufw status verbose

# Check fail2ban
sudo fail2ban-client status sshd

# Check SSL cert expiry
sudo certbot certificates

# Force SSL renewal
sudo certbot renew --force-renewal
```

---

## Security Notice

This document was built with accessibility in mind, but deployment
configurations should still be manually reviewed against your organization's
security policies. Run tools like
[Accessibility Insights](https://accessibilityinsights.io/) against the web UI,
and conduct periodic security audits of the server configuration.

**SSH Key Management:** Never commit private keys to version control. Rotate
keys periodically. The attached `ssh-key-2026-02-11.key` should be stored in
GitHub Secrets and on local machines only — never in the repository.
