#!/usr/bin/env bash
# backup-remote.sh — Server-side backup script for OpenClaw state
# Cron: 0 3 * * * /opt/openclaw/scripts/backup.sh >> /opt/openclaw/logs/backup.log 2>&1
# Deployed to: /opt/openclaw/scripts/backup.sh
set -euo pipefail

DEPLOY_ROOT="/opt/openclaw"
SHARED_DIR="${DEPLOY_ROOT}/shared"
BACKUP_DIR="${DEPLOY_ROOT}/backups"
TIMESTAMP=$(date -u +%Y%m%d_%H%M%S)
BACKUP_FILE="${BACKUP_DIR}/openclaw-backup-${TIMESTAMP}.tar.gz"
MAX_BACKUPS=14

log() { echo "[BACKUP $(date -u +%H:%M:%S)] $*"; }

mkdir -p "$BACKUP_DIR"

log "Starting backup"

# Build file list (only include what exists)
INCLUDE_PATHS=()
[ -f "${SHARED_DIR}/.env" ] && INCLUDE_PATHS+=(".env")
[ -d "${SHARED_DIR}/openclaw-data" ] && INCLUDE_PATHS+=("openclaw-data/")
[ -d "${SHARED_DIR}/workspace" ] && INCLUDE_PATHS+=("workspace/")

if [ ${#INCLUDE_PATHS[@]} -eq 0 ]; then
  log "Nothing to back up"
  exit 0
fi

tar -czf "$BACKUP_FILE" -C "$SHARED_DIR" "${INCLUDE_PATHS[@]}" 2>/dev/null

# Verify archive integrity
if ! tar -tzf "$BACKUP_FILE" > /dev/null 2>&1; then
  log "ERROR: Backup archive is corrupt"
  rm -f "$BACKUP_FILE"
  exit 1
fi

BACKUP_SIZE=$(du -h "$BACKUP_FILE" | cut -f1)
log "Backup created: ${BACKUP_FILE} (${BACKUP_SIZE})"

# Prune old backups
BACKUP_COUNT=$(find "$BACKUP_DIR" -name "openclaw-backup-*.tar.gz" -type f | wc -l)
if [ "$BACKUP_COUNT" -gt "$MAX_BACKUPS" ]; then
  PRUNE_COUNT=$((BACKUP_COUNT - MAX_BACKUPS))
  find "$BACKUP_DIR" -name "openclaw-backup-*.tar.gz" -type f | \
    sort | head -n "$PRUNE_COUNT" | xargs rm -f
  log "Pruned ${PRUNE_COUNT} old backups (kept ${MAX_BACKUPS})"
fi

log "Backup complete"
