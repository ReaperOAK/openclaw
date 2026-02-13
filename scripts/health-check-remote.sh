#!/usr/bin/env bash
# health-check-remote.sh — Server-side health check
# Usage: health-check.sh [max_retries] [wait_seconds]
# Deployed to: /opt/openclaw/scripts/health-check.sh
set -euo pipefail

MAX_RETRIES="${1:-10}"
WAIT_SECONDS="${2:-3}"
ENDPOINT="http://127.0.0.1:18789/"

for i in $(seq 1 "$MAX_RETRIES"); do
  HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 --max-time 10 "$ENDPOINT" 2>/dev/null || echo "000")

  if [ "$HTTP_CODE" -ge 200 ] && [ "$HTTP_CODE" -lt 500 ]; then
    echo "[HEALTH $(date -u +%H:%M:%S)] PASS (HTTP ${HTTP_CODE}) after ${i} attempts"
    exit 0
  fi

  echo "[HEALTH $(date -u +%H:%M:%S)] Attempt ${i}/${MAX_RETRIES}: HTTP ${HTTP_CODE}"
  sleep "$WAIT_SECONDS"
done

echo "[HEALTH $(date -u +%H:%M:%S)] FAILED after ${MAX_RETRIES} attempts"
exit 1
