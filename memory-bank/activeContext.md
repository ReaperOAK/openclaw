# OpenClaw — Active Context

## Current Work Focus

Full superpower maximization complete. OpenClaw now runs with 54 model aliases,
12 new free features, 21 active plugins, a 12-deep fallback chain across 5 providers,
and dedicated vision/image models. WhatsApp passive intel, heartbeat, cron,
context pruning, canvas host, and memory flush all active.

## Recent Changes (2026-02-16)

### Superpower Maximization Session (LATEST — 2026-02-16)

**Models: 40 → 54 configured**

- Added 19 new free OpenRouter models: DeepSeek R1 0528, Hermes 405B, Llama 3.3 70B,
  Qwen3-235B thinking, Qwen3-next-80B, Qwen3-VL-235B (vision), Qwen3-VL-30B (vision),
  Nemotron-3-nano-30B, Nemotron-nano-12B-VL (vision), Trinity Large, Gemma 3 12B/4B,
  Gemma 3n e4B, Dolphin-Mistral 24B, Liquid LFM 2.5 models, Aurora Alpha
- Added Google Gemini CLI models: gemini-2.5-flash, gemini-2.5-pro, gemini-3-flash-preview,
  gemini-3-pro-preview, gemini-2.0-flash
- Added extra GitHub Copilot models: gemini-3-flash/pro-preview, gpt-5/5.1/5.2,
  gpt-5.1-codex/codex-max/codex-mini, gpt-5.2-codex, gpt-4.1, gpt-4o

**Fallback chain: 9 → 12-deep cascade**

- qwen-portal/coder-model → gpt-5-mini → grok-code-fast-1 → claude-haiku-4.5 →
  gemini-2.5-pro → gemini-2.5-flash → deepseek-r1-0528:free → hermes-405b:free →
  llama-3.3-70b:free → qwen3-coder:free → gpt-oss-120b:free → openrouter/free

**Vision/Image model (NEW)**

- Primary: qwen-portal/vision-model
- Fallbacks: nemotron-nano-12b-v2-vl:free → qwen3-vl-235b-thinking → qwen3-vl-30b-thinking → gemini-2.5-pro

**12 New Free Features Enabled:**

1. `contextPruning` — cache-ttl mode, 1h TTL, keeps 3 last assistants, soft/hard trim
2. `cron` — enabled, max 2 concurrent runs, 24h retention
3. `canvasHost` — local canvas at ~/.openclaw/workspace/canvas/ with live reload
4. `heartbeat` — every 30m using qwen3-coder:free
5. `session` — per-sender scope, idle reset at 4h, thread daily reset at 4am, maintenance prune after 30d
6. `messages.queue` — collect mode with 1.5s debounce, cap 20
7. `messages.inbound` — 2s debounce (5s for WhatsApp, 1.5s for Telegram)
8. `logging` — info level, compact console, sensitive redaction on tools
9. `discovery.mdns` — minimal mode
10. `compaction.memoryFlush` — auto-saves memories before compaction
11. `tools.exec.notifyOnExit` — notifies when background commands finish
12. `tools.elevated` — enabled for full system access

**Agent identity (NEW)**

- Named agent "Onyx" with 🦅 emoji and mention patterns
- Subagents configured with llama-3.3-70b model, max 2 concurrent
- maxConcurrent: 3 parallel agent runs

**Plugins: 20 → 21 active** (added thread-ownership)

### WhatsApp Passive Intelligence System

- **Typing indicator suppressed**: `agents.defaults.typingMode: "never"`
- **Message logging plugin**: `whatsapp-passive-intel` — logs to JSONL with metadata
- **Urgency detection**: Keyword + regex matching → instant Telegram notification
- **Daily summary**: Cron at 11 PM UTC via `whatsapp-daily-summary.sh`
- **Outbound block**: 3-layer defense prevents any WhatsApp sends

### Security Hardening

- Security audit: 4 CRITICAL → 0 CRITICAL, 0 WARN
- WhatsApp: dmPolicy=disabled, groupPolicy=disabled (passive read-only)
- Sandbox mode=all, gateway auth rate limiting, fail2ban for SSH
- .env permissions 600, hooks.defaultSessionKey set

## Current State

- **Version**: 2026.2.16
- **Branch**: main (ahead of origin by 1757 commits — upstream merge)
- **Gateway**: PID running on ws://0.0.0.0:18789, bind=lan, mode=local
- **Canvas**: Mounted at http://0.0.0.0:18789/__openclaw__/canvas/
- **Heartbeat**: Active, every 30m
- **Channels**: Telegram (@Onyx_oakbot, pairing) + WhatsApp (+917003080896, passive read-only)
- **Primary model**: qwen-portal/coder-model (free)
- **Image model**: qwen-portal/vision-model → nemotron-vl:free → qwen3-vl:free
- **Fallbacks**: 12-deep cascade across 5 providers (Qwen Portal, GitHub Copilot, Google Gemini CLI, OpenRouter, MiniMax Portal)
- **Total models**: 54 aliased models (16 GitHub Copilot + 22 OpenRouter free + 5 Google Gemini CLI + 2 Qwen Portal + 2 MiniMax Portal + 7 duplicates across providers)
- **Auth**: GitHub Copilot + OpenRouter + Qwen Portal + MiniMax Portal (active), Google Gemini CLI (configured, needs OAuth)
- **Skills**: 24 ready
- **Plugins**: 21 active
- **WhatsApp Intel**: Logging to ~/.openclaw/whatsapp-intel/, cron at 23:00 UTC
- **Telegram chat_id**: 1295024057

## Active Plugins (Custom)

- `whatsapp-outbound-block` — prevents all WhatsApp outbound messages
- `whatsapp-passive-intel` — logs messages + urgency detection + Telegram alerts

## Known Issues

- `spawn docker ENOENT` — sandbox tries Docker but it's not installed. Non-blocking.
- Gmail watcher needs GOG_KEYRING_PASSWORD for keyring access
- Google Gemini CLI needs interactive OAuth login (configured but not authenticated)
- Browser tools disabled (no GUI on OCI instance — set `browser.enabled: false`)

## Next Steps

1. Monitor heartbeat + context pruning + memory flush behavior over 24h
2. Test canvas host with a real canvas artifact
3. Authenticate Google Gemini CLI for 5 additional models
4. Install Docker if sandbox execution is needed
5. Consider adding Brave Search API key for web search tool
6. Push upstream merge to origin fork

## Active Decisions

- Using pnpm (not bun) for dependency management
- Following AGENTS.md conventions for commit workflow
- Sandbox mode=all enabled globally for security
- WhatsApp is read-only (outbound-block plugin active)
- BlueBubbles permanently disabled
- Browser tools disabled (headless server)
