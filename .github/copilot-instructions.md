# OpenClaw — Project-Level Copilot Instructions

> These instructions apply to all AI coding agents working inside this repository.
> For comprehensive repo guidelines, see [`AGENTS.md`](../AGENTS.md) at the repo root.
> For codebase patterns, see [`.github/instructions/copilot.instructions.md`](.github/instructions/copilot.instructions.md).

---

## Quick Reference

- **Product name**: OpenClaw (capitalized); `openclaw` for CLI, package, paths, config keys.
- **Runtime**: Node 22+ (ESM). Bun supported for dev/scripts.
- **Package manager**: pnpm 10.x (pinned in `packageManager` field).
- **Build**: `pnpm install && pnpm ui:build && pnpm build` (tsdown → `dist/`).
- **Dev loop**: `pnpm gateway:watch` (auto-reload) or `pnpm dev` (CLI).
- **Lint/Format**: `pnpm check` (Oxlint + Oxfmt). Fix: `pnpm format:fix`.
- **Test**: `pnpm test` (Vitest, forks pool, 120s timeout). Coverage: `pnpm test:coverage` (V8, 70% threshold).
- **Type-check**: `pnpm tsgo` or `pnpm build`.
- **Commit**: Use `scripts/committer "<msg>" <file...>` — never raw `git add`/`git commit`.

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                    OpenClaw Runtime                          │
├──────────┬──────────────┬───────────────┬───────────────────┤
│   CLI    │   Gateway    │   Pi Agent    │   Control UI      │
│ (cmdr)   │  (WS:18789)  │   (RPC)       │  (Lit, :18790)   │
├──────────┴──────────────┴───────────────┴───────────────────┤
│                   Channel Layer                              │
│  WhatsApp · Telegram · Discord · Slack · Signal · iMessage   │
│  + extension channels (Matrix, Teams, Zalo, Nostr, etc.)     │
├──────────────────────────────────────────────────────────────┤
│  Plugin SDK (openclaw/plugin-sdk)  │  Hooks (bundled)        │
├──────────────────────────────────────────────────────────────┤
│  Config (Zod schema, JSON5, ~/.openclaw/)                    │
└──────────────────────────────────────────────────────────────┘
```

### Key Architectural Patterns

1. **Dependency Injection**: `createDefaultDeps()` in `src/cli/deps.ts` provides channel send functions and shared services. Follow this pattern — don't instantiate singletons directly.
2. **Plugin SDK**: Extensions import from `openclaw/plugin-sdk` (resolved via jiti alias at runtime). Plugin-only deps go in the extension's `package.json`, never the root.
3. **Hooks**: Bundled in `src/hooks/bundled/` (session-memory, boot-md, command-logger). User hooks via config. Hooks are async functions receiving context + next.
4. **Config**: Zod-validated schema in `src/config/`. Env precedence: `process.env` → `./.env` → `~/.openclaw/.env` → `openclaw.json` env block.
5. **Channel Architecture**: All channels (built-in + extension) must be considered when touching routing, allowlists, pairing, onboarding, or command gating.

---

## Source Layout

| Path                                                                                      | Purpose                                                   |
| ----------------------------------------------------------------------------------------- | --------------------------------------------------------- |
| `src/cli/`                                                                                | CLI wiring, option parsing, DI (`deps.ts`, `progress.ts`) |
| `src/commands/`                                                                           | All CLI commands (150+ files)                             |
| `src/gateway/`                                                                            | WebSocket control plane + gateway server (100+ files)     |
| `src/channels/`                                                                           | Channel routing and shared channel logic                  |
| `src/telegram/`, `src/discord/`, `src/slack/`, `src/signal/`, `src/imessage/`, `src/web/` | Built-in channel implementations                          |
| `src/config/`                                                                             | Configuration loading, Zod schemas                        |
| `src/hooks/bundled/`                                                                      | Built-in hook implementations                             |
| `src/plugin-sdk/`                                                                         | Plugin SDK exports (channel adapters, types, utilities)   |
| `src/infra/`                                                                              | Shared infrastructure (formatting, utilities)             |
| `src/terminal/`                                                                           | Terminal UI (tables, themes, palette)                     |
| `src/media/`                                                                              | Media processing pipeline                                 |
| `src/routing/`                                                                            | Message routing logic                                     |
| `src/sessions/`                                                                           | Session management                                        |
| `extensions/`                                                                             | 35 extension packages (workspace packages)                |
| `packages/`                                                                               | Internal packages (clawdbot, moltbot)                     |
| `ui/`                                                                                     | Control UI (Lit + Vite → `dist/control-ui/`)              |
| `docs/`                                                                                   | Mintlify documentation source                             |

---

## Critical Conventions

### Code Style

- TypeScript ESM. Strict typing. Avoid `any`.
- `.js` extension in cross-package imports (ESM resolution).
- `import type { X }` for type-only imports.
- Files under ~500-700 LOC. Extract helpers when larger.
- Use `src/terminal/palette.ts` for colors — no hardcoded ANSI.
- Use `src/cli/progress.ts` for spinners/progress bars — no hand-rolled UI.

### Testing

- Co-located: `feature.ts` → `feature.test.ts`. E2E: `*.e2e.test.ts`.
- Run `pnpm test` before pushing any logic changes.
- Live tests require `CLAWDBOT_LIVE_TEST=1` or `LIVE=1`.
- Max 16 test workers (hard limit — already tested).

### Multi-Agent Safety

- Never create/apply/drop `git stash` unless explicitly asked.
- Never switch branches unless explicitly asked.
- Never create/modify `git worktree` unless explicitly asked.
- Scope commits to your changes only. Use `scripts/committer`.
- If you see unrecognized files, keep going — focus on your changes.

### Extensions

- Extensions are pnpm workspace packages under `extensions/`.
- Runtime deps in `dependencies`. `openclaw` in `devDependencies` or `peerDependencies`.
- Never use `workspace:*` in `dependencies` (breaks npm install).
- When adding channels/extensions, update `.github/labeler.yml` and create matching labels.

### Security

- Never commit real phone numbers, credentials, or live config values.
- Never update the Carbon dependency.
- Patched dependencies (`pnpm.patchedDependencies`) must use exact versions (no `^`/`~`).
- Patching deps requires explicit approval.

---

## What NOT to Do

- Don't duplicate functions — search first, import from source.
- Don't create re-export wrapper files.
- Don't edit `node_modules` (any install method).
- Don't send streaming/partial replies to external messaging surfaces.
- Don't change version numbers without explicit consent.
- Don't run `npm publish` without explicit approval and OTP.
- Don't rebuild the macOS app over SSH.
