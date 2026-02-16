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
- **Gateway**: v2026.2.16 running with security hardening
- **Skills**: 22/50 ready (all installable free CLIs on Linux)
- **Voice Pipeline**: TTS (sherpa-onnx) + STT (Whisper) fully working
- **Security**: 0 CRITICAL findings, fail2ban active, sandbox enabled
- **Channels**: Telegram (pairing) + WhatsApp (read-only, hardened)

## What's Left to Build

- MiniMax/Qwen model auth (needs interactive SSH device code flow)
- Gmail watcher keyring password (GOG_KEYRING_PASSWORD)
- Push upstream merge to origin fork
- Remaining 32 skills mostly need macOS or paid services

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
| Skills           | ✅ 20/52 ready                         |
| Security         | ✅ 0 CRITICAL, fail2ban active         |
| Voice            | ✅ TTS + STT round-trip verified       |
| CLI Tools        | ✅ 14 tools installed                  |

## Known Issues

- Gmail watcher fails: needs GOG_KEYRING_PASSWORD env var set
- Upstream merge puts fork 1757 commits ahead of origin

## Known Issues

- CLAUDE.md symlink at repo root may have encoding issues (embedded newline in
  symlink target on some systems)
- No memory bank existed prior to 2026-02-16 setup
