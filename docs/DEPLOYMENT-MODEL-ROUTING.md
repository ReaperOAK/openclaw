# Deployment Guide — Model Routing & Quota Protection

## What Changed

### 1. Primary Model → Free Tier

| Setting       | Before                              | After                              |
| ------------- | ----------------------------------- | ---------------------------------- |
| Default model | `github-copilot/gpt-5-mini` (0.33x) | `github-copilot/gpt-4.1` (0x)      |
| Heartbeat     | `github-copilot/gpt-5-mini` (0.33x) | `github-copilot/gpt-4.1-nano` (0x) |
| Subagent      | `github-copilot/gpt-5-mini` (0.33x) | `github-copilot/gpt-4.1` (0x)      |

**Impact:** All autonomous operations (heartbeats, subagents, default conversations)
now consume zero premium quota. Previously, every heartbeat burned 0.33x.

### 2. Fallback Chain → All Free

| Position   | Before                  | After                   |
| ---------- | ----------------------- | ----------------------- |
| Primary    | gpt-5-mini (0.33x)      | gpt-4.1 (0x)            |
| Fallback 1 | gemini-2.5-pro (free)   | gemini-2.5-pro (free)   |
| Fallback 2 | qwen/coder (free)       | qwen/coder (free)       |
| Fallback 3 | gemini-2.5-flash (free) | gemini-2.5-flash (free) |
| Fallback 4 | _(none)_                | gpt-4.1-mini (0x)       |

**Impact:** If primary fails, all fallbacks are free. No automatic escalation
to premium models.

### 3. Model Aliases Reorganized

Aliases are now tier-labeled for quick recognition:

**Free (0x):** `code`, `fast`, `mini41`, `4o`, `gemini`, `flash`, `qwen`, `vision`
**Budget (0.25x-0.5x):** `haiku`, `mini`, `reason`
**Premium (1x):** `sonnet`, `opus`, `gpt`, `codex`

Use `/use <alias>` to switch models in conversation.

### 4. Loop Detection Enabled

Was: **disabled** (default).
Now: **enabled** with aggressive thresholds:

- Warning at 5 repeated tool calls
- Critical (force-stop) at 10
- Circuit breaker at 15
- All detectors active: generic repeat, poll-no-progress, ping-pong

### 5. Quota Monitor Deployed

- Script: `~/.openclaw/scripts/quota-monitor.sh`
- State: `~/.openclaw/logs/quota-state.json`
- Log: `~/.openclaw/logs/quota-usage.log`
- Cron: hourly status log + monthly auto-reset

## How to Use

### Check quota status

```bash
~/.openclaw/scripts/quota-monitor.sh
```

### Record a request (for manual tracking)

```bash
~/.openclaw/scripts/quota-monitor.sh --record claude-sonnet-4.6
```

### Switch to a premium model in conversation

```
/use sonnet
```

Then switch back to free:

```
/use code
```

### Emergency: Restore previous config

```bash
cp ~/.openclaw/openclaw.json.backup-* ~/.openclaw/openclaw.json
# Then restart OpenClaw
```

## Quota Budget

- **Monthly:** 300 premium-equivalent requests
- **Daily Tier 2 budget:** ~7 requests (1x each)
- **Warning at:** 240/300 (80%)
- **Critical at:** 285/300 (95%)

## Architecture Reference

See [docs/MODEL-ROUTING-ARCHITECTURE.md](docs/MODEL-ROUTING-ARCHITECTURE.md)
for the full routing diagram, tier definitions, and failure containment protocol.
