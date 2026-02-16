#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# validate-whatsapp-readonly.sh
# Checks that WhatsApp read-only safeguards are in place after every build.
#
# Read-only architecture (v2):
#   - dmPolicy: "disabled"  → no DMs reach AI (zero credits)
#   - groupPolicy: "disabled" → no group messages reach AI (zero credits)
#   - actions.sendMessage: false → bot cannot send WhatsApp messages
#   - Transport-level logging in monitor.ts captures ALL messages pre-ACL
#   - whatsapp-outbound-block is NO LONGER required (nothing reaches AI)
#
# Run:  pnpm build && bash scripts/validate-whatsapp-readonly.sh
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

CONFIG="${HOME}/.openclaw/openclaw.json"
TRANSPORT_LOG="src/web/inbound/transport-log.ts"
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'
ERRORS=0

check() {
  local label="$1" jq_expr="$2" expected="$3"
  local actual
  actual=$(jq -r "$jq_expr" "$CONFIG" 2>/dev/null || echo "__MISSING__")
  if [[ "$actual" == "$expected" ]]; then
    printf "${GREEN}  ✓${NC} %s = %s\n" "$label" "$actual"
  else
    printf "${RED}  ✗${NC} %s = %s (expected: %s)\n" "$label" "$actual" "$expected"
    ERRORS=$((ERRORS + 1))
  fi
}

echo ""
echo "═══════════════════════════════════════════════════════"
echo "  WhatsApp Read-Only Validation (v2 — transport-level)"
echo "═══════════════════════════════════════════════════════"
echo ""

# 1. Config file exists
if [[ ! -f "$CONFIG" ]]; then
  printf "${RED}  ✗${NC} Config file not found: %s\n" "$CONFIG"
  exit 1
fi
printf "${GREEN}  ✓${NC} Config file exists\n"

# 2. DM & group policies — must be "disabled" to prevent AI processing
echo ""
echo "── Access control (zero AI credits) ──"
check "dmPolicy"     '.channels.whatsapp.dmPolicy'     "disabled"
check "groupPolicy"  '.channels.whatsapp.groupPolicy'  "disabled"

# 3. WhatsApp channel actions — all outbound blocked
echo ""
echo "── Outbound actions ──"
check "actions.sendMessage"      '.channels.whatsapp.actions.sendMessage'     "false"
check "actions.reactions"        '.channels.whatsapp.actions.reactions'       "false"
check "actions.polls"            '.channels.whatsapp.actions.polls'           "false"
check "sendReadReceipts"         '.channels.whatsapp.sendReadReceipts'        "false"
check "ackReaction.emoji"        '.channels.whatsapp.ackReaction.emoji'       ""
check "ackReaction.direct"       '.channels.whatsapp.ackReaction.direct'      "false"
check "ackReaction.group"        '.channels.whatsapp.ackReaction.group'       "never"

# 4. Transport-level logging exists (the new passive capture mechanism)
echo ""
echo "── Transport-level logging ──"
if [[ -f "$TRANSPORT_LOG" ]]; then
  printf "${GREEN}  ✓${NC} Transport log module: %s\n" "$TRANSPORT_LOG"
else
  printf "${RED}  ✗${NC} Transport log module missing: %s\n" "$TRANSPORT_LOG"
  ERRORS=$((ERRORS + 1))
fi

if grep -q "transportLog" "src/web/inbound/monitor.ts" 2>/dev/null; then
  printf "${GREEN}  ✓${NC} monitor.ts calls transportLog (pre-ACL logging active)\n"
else
  printf "${RED}  ✗${NC} monitor.ts does NOT call transportLog — messages won't be logged!\n"
  ERRORS=$((ERRORS + 1))
fi

# 5. Telegram is enabled (reply/notification channel)
echo ""
echo "── Telegram (notification channel) ──"
check "telegram.enabled"  '.channels.telegram.enabled'   "true"
check "telegram plugin"   '.plugins.entries.telegram.enabled' "true"

# Summary
echo ""
echo "═══════════════════════════════════════════════════════"
if [[ "$ERRORS" -eq 0 ]]; then
  printf "${GREEN}  All checks passed!${NC} WhatsApp is locked to read-only.\n"
  printf "  Messages logged at transport layer → zero AI credits.\n"
else
  printf "${RED}  %d check(s) failed!${NC} WhatsApp read-only may be compromised.\n" "$ERRORS"
  printf "${YELLOW}  Fix the issues above and restart the gateway.${NC}\n"
  exit 1
fi
echo "═══════════════════════════════════════════════════════"
echo ""
