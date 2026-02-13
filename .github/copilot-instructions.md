# OpenClaw AI Coding Agent Guide

## Project overview

OpenClaw is a personal AI assistant gateway. It connects to messaging channels
(WhatsApp, Telegram, Slack, Discord, Signal, iMessage, Google Chat, Teams, etc.)
and routes conversations through an AI agent runtime. Core flow:
**Channel → Gateway → Agent (Pi runtime) → Response → Channel**.

## Monorepo layout (pnpm workspaces)

| Folder         | Stack / Role                                         |
| -------------- | ---------------------------------------------------- |
| `src/`         | Core: CLI (`src/cli`), Gateway (`src/gateway`), channels, agents, media, config, plugins |
| `extensions/*` | Plugin packages (msteams, matrix, zalo, memory, voice-call, etc.) |
| `apps/`        | Native apps — `macos/` (SwiftUI), `ios/` (SwiftUI), `android/` (Kotlin) |
| `ui/`          | Web Control UI (Vite + Lit) |
| `packages/*`   | Companion bots (clawdbot, moltbot) |
| `skills/`      | Bundled/managed agent skills |
| `docs/`        | Mintlify docs (docs.openclaw.ai) |

## Architecture essentials

- **Gateway** (`src/gateway/server.ts`): WebSocket control plane managing sessions, channels, tools, cron, hooks, and plugins. Entry: `src/entry.ts` → CLI → Gateway.
- **Channels**: Core channels in `src/{telegram,discord,slack,signal,imessage,web}/`; extension channels in `extensions/*`. All implement adapter interfaces from `src/plugin-sdk/`.
- **Plugin SDK** (`src/plugin-sdk/index.ts`): Adapter-based architecture — channels implement `ChannelMessagingAdapter`, `ChannelOutboundAdapter`, `ChannelSetupAdapter`, etc. Extensions import `openclaw/plugin-sdk`.
- **Dependency injection**: CLI wiring via `createDefaultDeps()` in `src/cli/deps.ts`; extend this when adding outbound send deps.
- **Config**: YAML-based (`~/.openclaw/`), validated with Zod schemas in `src/config/zod-schema.*.ts`, TypeBox types in `src/config/schema.ts`.
- **Sessions**: Pi agent transcripts use `parentId` chain/DAG — always write via `SessionManager.appendMessage()`, never raw JSONL.
- **Protocol**: Gateway ↔ native apps communicate via generated protocol (`scripts/protocol-gen.ts` → `dist/protocol.schema.json`; Swift models in `apps/macos/Sources/OpenClawProtocol/`).

## Key commands

| Goal              | Command                | Notes                                       |
| ----------------- | ---------------------- | ------------------------------------------- |
| Install deps      | `pnpm install`         | Also: `bun install` (keep lockfiles in sync)|
| Build             | `pnpm build`           | tsdown → `dist/`                            |
| Type-check        | `pnpm tsgo`            | Uses `@typescript/native-preview`           |
| Lint + format     | `pnpm check`           | oxfmt + oxlint (NOT ESLint/Prettier)        |
| Format fix        | `pnpm format`          | `oxfmt --write`                             |
| Unit tests        | `pnpm test`            | Vitest, parallelized via `scripts/test-parallel.mjs` |
| E2E tests         | `pnpm test:e2e`        | `vitest.e2e.config.ts`                      |
| Live tests        | `OPENCLAW_LIVE_TEST=1 pnpm test:live` | Requires real API keys          |
| Dev gateway       | `pnpm gateway:watch`   | Auto-reload on changes                      |
| Run CLI (dev)     | `pnpm openclaw ...`    | Runs TS directly via tsx                    |
| UI build          | `pnpm ui:build`        | Web Control UI                              |
| Commit changes    | `scripts/committer "<msg>" <files...>` | Scoped staging; avoid raw `git add/commit` |

## Coding conventions

- **Language**: TypeScript ESM, strict mode, ES2023 target. Avoid `any`.
- **Formatting**: oxfmt + oxlint (run `pnpm check`). NOT Prettier/ESLint.
- **Naming**: Product = **OpenClaw**; CLI/package/paths = `openclaw`. Filenames: `kebab-case`.
- **Tests**: Colocated `*.test.ts`; E2E: `*.e2e.test.ts`; live: `*.live.test.ts`. Coverage threshold: 70% lines/functions/statements.
- **Commits**: Action-oriented — `CLI: add verbose flag to send`. Use `scripts/committer`.
- **File size**: Aim for <700 LOC; split when it helps clarity.
- **Progress UI**: Use `src/cli/progress.ts` (osc-progress + @clack/prompts); don't hand-roll spinners.
- **Status tables**: Use `src/terminal/table.ts` for ANSI-safe table output.

## Extension/plugin patterns

- Extensions live in `extensions/*/` as workspace packages with their own `package.json`.
- Runtime deps go in `dependencies`; avoid `workspace:*` there (breaks npm install). Put `openclaw` in `devDependencies` or `peerDependencies`.
- Plugins are installed via `npm install --omit=dev` in plugin dir.
- When adding a channel: update all UI surfaces (macOS, web, mobile), onboarding docs, status forms, and `.github/labeler.yml`.

## Reference files

- `AGENTS.md` — Full agent operating guidelines, VM ops, commit workflow.
- `src/cli/deps.ts` — Dependency injection pattern for outbound sends.
- `src/plugin-sdk/index.ts` — All exported adapter interfaces for extensions.
- `src/config/schema.ts` + `src/config/zod-schema.ts` — Config shape and validation.
- `src/gateway/server-methods/AGENTS.md` — Session transcript write rules.
- `docs/reference/RELEASING.md` — Release flow (read before any release work).

## Critical rules

- **Never edit `node_modules`** or anything under global/Homebrew installs.
- **Never update the Carbon dependency** (`@buape/carbon`).
- Patched deps (`pnpm.patchedDependencies`) must use **exact versions** (no `^`/`~`).
- Patching/vendoring deps requires **explicit approval**.
- Pre-commit hook (`git-hooks/pre-commit`) auto-runs lint + format on staged files.
- **Never run `git push --no-verify`.**
