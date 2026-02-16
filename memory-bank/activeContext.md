# OpenClaw — Active Context

## Current Work Focus

WhatsApp passive intelligence system fully operational. OpenClaw silently reads
all WhatsApp DMs and groups, logs them to JSONL, detects urgent messages and
forwards them to Telegram, and sends daily summaries at 11 PM UTC.

## Recent Changes (2026-02-16)

### WhatsApp Passive Intelligence System (NEW)

- **Typing indicator suppressed**: Set `agents.defaults.typingMode: "never"` —
  traced through 5 layers of source code (monitor.ts → process-message.ts →
  reply-dispatcher.ts → typing.ts → typing-mode.ts) to find the config option
- **Message logging plugin**: `whatsapp-passive-intel` — hooks into `message_received`,
  logs every WhatsApp message to `~/.openclaw/whatsapp-intel/messages-YYYY-MM-DD.jsonl`
  with full metadata (sender name, phone, conversation ID, group flag)
- **Urgency detection**: Keyword + regex pattern matching triggers instant Telegram
  notification via Bot API (keywords: urgent, emergency, help me, SOS, etc.)
- **Daily summary**: Cron job at 11 PM UTC runs `whatsapp-daily-summary.sh`, groups
  messages by sender, sends structured summary to Telegram
- **Outbound block**: Existing `whatsapp-outbound-block` plugin still active —
  3-layer defense prevents any outbound WhatsApp messages
- **Primary model changed**: qwen-portal/coder-model (free, authenticated)

### Superpower Activation Session (Updated 2026-02-16)

- **Skills**: 7 → 22 ready (installed: github, mcporter, session-logs, openai-whisper,
  sherpa-onnx-tts, video-frames, weather, tmux, skill-creator, healthcheck,
  nano-pdf, oracle, blogwatcher, himalaya, gifgrep, wacli, ordercli, gemini, gog,
  clawhub, prose, coding-agent)
- **Plugins**: 19/38 loaded — telegram, whatsapp, copilot-proxy, diagnostics-otel,
  discord, google-antigravity-auth, google-gemini-cli-auth, googlechat, llm-task,
  lobster, open-prose, device-pair, phone-control, talk-voice, memory-core,
  minimax-portal-auth, qwen-portal-auth, whatsapp-outbound-block, whatsapp-passive-intel
- **CLI tools installed**: ffmpeg, ripgrep, gh, uv, clawhub, mcporter, bzip2,
  whisper (STT), sherpa-onnx (TTS), nano-pdf, oracle, blogwatcher, himalaya,
  gifgrep, wacli, ordercli, gemini, gog, jq, tmux, curl
- **Voice pipeline**: Fully working (sherpa-onnx TTS + Whisper STT round-trip verified)
- **Newly installed (this session)**: gifgrep (GIF search), wacli (WhatsApp CLI),
  ordercli (food delivery), gemini CLI (Google AI)

### Security Hardening

- Security audit: 4 CRITICAL → 0 CRITICAL, 0 WARN
- WhatsApp: dmPolicy changed from "open" to "pairing", groupPolicy to "allowlist"
- Sandbox mode enabled for all sessions (protects small models)
- Gateway auth rate limiting added (10 attempts / 60s window / 5min lockout)
- fail2ban installed for SSH protection (5 attempts → 1hr ban)
- .env permissions tightened to 600
- hooks.defaultSessionKey set to "hook:ingress"

### OpenClaw Updated

- Version: 2026.2.13 → 2026.2.16 (merged upstream/main)
- Dependencies updated (TypeScript native-preview, oxlint-tsgolint)

## Current State

- **Version**: 2026.2.16
- **Branch**: main (ahead of origin by 1757 commits — upstream merge)
- **Gateway**: PID running on ws://0.0.0.0:18789, bind=lan, mode=local
- **Channels**: Telegram (@Onyx_oakbot, pairing) + WhatsApp (+917003080896, passive read-only)
- **Primary model**: qwen-portal/coder-model (free)
- **Fallbacks**: github-copilot/gpt-5-mini → grok-code-fast-1 → openrouter free models
- **Auth**: GitHub Copilot + OpenRouter + Qwen Portal (active), MiniMax (plugin enabled)
- **WhatsApp Intel**: Logging to ~/.openclaw/whatsapp-intel/, cron at 23:00 UTC
- **Telegram chat_id**: 1295024057

## Active Plugins (Custom)

- `whatsapp-outbound-block` — prevents all WhatsApp outbound messages
- `whatsapp-passive-intel` — logs messages + urgency detection + Telegram alerts

## Known Issues

- `spawn docker ENOENT` — sandbox mode "all" tries Docker but it's not installed.
  Doesn't affect passive reading. Install Docker or set sandbox to "off" if needed.
- Gmail watcher needs keyring password configured (GOG_KEYRING_PASSWORD)

## Next Steps

1. Monitor WhatsApp passive intel for a day to verify all features work reliably
2. Consider adding AI-powered summaries (currently using structured text aggregation)
3. Push upstream merge to origin fork
4. Install Docker if sandbox execution is needed for agent tools
5. Consider per-channel typingMode if Telegram needs typing indicators restored

## Active Decisions

- Using pnpm (not bun) for dependency management
- Following AGENTS.md conventions for commit workflow
- Sandbox mode "all" enabled globally for security
- WhatsApp is read-only (outbound-block plugin active)
- BlueBubbles permanently disabled
