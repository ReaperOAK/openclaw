# OpenClaw — Progress

## What Works

- Full build pipeline: `pnpm install → pnpm ui:build → pnpm build`
- Dev loop: `pnpm gateway:watch` with auto-reload
- CLI: `pnpm openclaw ...` for all commands
- Pre-commit hooks: Oxlint + Oxfmt auto-fix on staged files
- CI: GitHub Actions with lint, type-check, test, build
- Test suite: Vitest with forks pool, 120s timeout, V8 coverage
- 35+ extensions in workspace packages
- Documentation: Mintlify-hosted docs at docs.openclaw.ai
- **Gateway**: v2026.2.16 running with all free features enabled
- **Models**: 54 aliased across 5 providers (all free)
- **Skills**: 24/51 ready (all installable free CLIs on Linux)
- **Voice Pipeline**: TTS (sherpa-onnx) + STT (Whisper) fully working
- **Voice-Call Plugin**: Enabled, webhook at http://127.0.0.1:3334/voice/webhook
- **Security**: 0 CRITICAL findings, fail2ban active, sandbox enabled
- **Channels**: Telegram (pairing) + WhatsApp (read-only, hardened)
- **Fallback Chain**: 12-model-deep cascade across 5 providers
- **Image Model**: Vision pipeline with qwen-portal + 4 free fallbacks
- **Context Pruning**: cache-ttl mode, 1h TTL, auto soft/hard trim
- **Memory Flush**: Auto-saves memories before context compaction
- **Heartbeat**: Every 30m using qwen3-coder:free
- **Canvas Host**: Local canvas at /**openclaw**/canvas/ with live reload
- **Cron**: Enabled, max 2 concurrent runs
- **Session Management**: Per-sender scope, idle reset at 4h, thread daily reset
- **Message Queue**: Collect mode with debounce (1.5s default, 5s WhatsApp)
- **Agent Identity**: Named "Onyx" 🦅 with mention patterns
- **Subagents**: Configured with llama-3.3-70b, max 2 concurrent
- **Plugins**: 21 active (added thread-ownership)

## What's Left to Build

- Google Gemini CLI OAuth login (needs interactive browser)
- Gmail watcher keyring password (GOG_KEYRING_PASSWORD)
- Push upstream merge to origin fork
- Discord channel setup (needs DISCORD_BOT_TOKEN)
- Brave Search API key for web search tool
- Docker installation for sandbox execution
- Remaining ~27 skills mostly need macOS, paid services, or hardware

## Current Status

| Area             | Status                                 |
| ---------------- | -------------------------------------- |
| Build            | ✅ Working (v2026.2.16)                |
| Tests            | ✅ Configured (70% coverage threshold) |
| Lint/Format      | ✅ Oxlint + Oxfmt via `pnpm check`     |
| Git hooks        | ✅ Pre-commit (lint + format)          |
| CI/CD            | ✅ 8 GitHub Actions workflows          |
| Documentation    | ✅ Mintlify + inline docs              |
| Memory Bank      | ✅ Initialized (2026-02-16)            |
| Node version pin | ✅ `.nvmrc` + `engines` field          |
| Gateway          | ✅ Running (PID on port 18789)         |
| Models           | ✅ 54 aliased (5 providers, all free)  |
| Fallback Chain   | ✅ 12-deep cascade                     |
| Image Model      | ✅ Vision pipeline with 5 fallbacks    |
| Context Pruning  | ✅ cache-ttl, 1h TTL                   |
| Memory Flush     | ✅ Auto-save before compaction         |
| Heartbeat        | ✅ Every 30m                           |
| Canvas Host      | ✅ Mounted with live reload            |
| Cron             | ✅ Enabled, max 2 concurrent           |
| Session Mgmt     | ✅ Per-sender, idle reset 4h           |
| Message Queue    | ✅ Collect mode, debounce 1.5s         |
| Skills           | ✅ 24/51 ready                         |
| Security         | ✅ 0 CRITICAL, fail2ban active         |
| Voice            | ✅ TTS + STT round-trip verified       |
| Voice-Call       | ✅ Plugin active, webhook on :3334     |
| CLI Tools        | ✅ 20+ tools installed                 |
| Plugins          | ✅ 21 active                           |

## Known Issues

- Gmail watcher fails: needs GOG_KEYRING_PASSWORD env var set
- Upstream merge puts fork 1757 commits ahead of origin
- `spawn docker ENOENT` — sandbox tries Docker but it's not installed
- Google Gemini CLI configured but not authenticated (needs interactive OAuth)
- Browser tools disabled (no GUI on headless OCI instance)
