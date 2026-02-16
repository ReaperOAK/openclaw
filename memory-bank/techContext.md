# OpenClaw — Tech Context

## Core Technologies

| Technology | Version       | Purpose                         |
| ---------- | ------------- | ------------------------------- |
| Node.js    | ≥22.12.0      | Runtime                         |
| TypeScript | ~5.9.x        | Language                        |
| pnpm       | 10.23.0       | Package manager                 |
| Bun        | Latest        | Dev/script execution (optional) |
| ESM        | ES2023 target | Module system                   |

## Build & Dev Tooling

| Tool        | Purpose                           |
| ----------- | --------------------------------- |
| tsdown      | Production bundler (→ `dist/`)    |
| tsx         | Dev-time TypeScript execution     |
| Oxlint      | Linter (type-aware)               |
| Oxfmt       | Formatter                         |
| Vitest      | Test framework                    |
| V8 Coverage | Coverage provider (70% threshold) |

## Development Setup

### Install

```bash
git clone https://github.com/openclaw/openclaw.git
cd openclaw
pnpm install
pnpm ui:build
pnpm build
```

### Daily Commands

| Command              | Purpose                             |
| -------------------- | ----------------------------------- |
| `pnpm gateway:watch` | Dev server with auto-reload         |
| `pnpm dev`           | Run CLI in dev mode                 |
| `pnpm openclaw ...`  | Run any CLI command                 |
| `pnpm build`         | Full production build               |
| `pnpm tsgo`          | Type-check (native TS checker)      |
| `pnpm check`         | Lint + format check                 |
| `pnpm format:fix`    | Auto-fix formatting                 |
| `pnpm test`          | Run test suite (Vitest, forks pool) |
| `pnpm test:coverage` | Test with V8 coverage report        |
| `pnpm test:e2e`      | End-to-end tests                    |
| `pnpm test:fast`     | Unit tests only                     |

### Commit Workflow

```bash
# Use the project's committer script (scoped staging)
scripts/committer "feat(gateway): add health endpoint" src/gateway/health.ts

# Never use raw git add/git commit (multi-agent safety)
```

## Technical Constraints

- **Node ≥22**: Required for ESM, native fetch, and modern APIs.
- **pnpm workspace**: Monorepo with `extensions/*` and `packages/*` as workspace
  packages.
- **Max 16 test workers**: Hard limit (already tested, more causes issues).
- **No Carbon updates**: Dependency frozen.
- **Patched deps must be exact versions**: No `^`/`~` for `pnpm.patchedDependencies`.
- **ESM resolution**: `.js` extension required in cross-package imports.

## Key Dependencies

### Runtime

- `express` (v5) — HTTP server
- `ws` — WebSocket server
- `grammy` — Telegram bot framework
- `@buape/carbon` — Discord integration
- `@slack/bolt` — Slack integration
- `@whiskeysockets/baileys` — WhatsApp (Web) integration
- `playwright-core` — Browser automation
- `sharp` — Image processing
- `zod` — Schema validation
- `tslog` — Structured logging
- `commander` — CLI framework

### Dev

- `vitest` — Test runner
- `oxlint` / `oxfmt` — Lint and format
- `tsdown` — Bundler
- `tsx` — TypeScript execution
- `@typescript/native-preview` — Native TS type checker

## Environment Variables

Config is Zod-validated at startup. Key env vars:

- `OPENCLAW_SKIP_CHANNELS` — Skip channel initialization (dev)
- `CLAWDBOT_LIVE_TEST` / `OPENCLAW_LIVE_TEST` — Enable live tests
- `CI` / `GITHUB_ACTIONS` — CI detection

Config file: `~/.openclaw/openclaw.json` (JSON5)
Credentials: `~/.openclaw/credentials/`
Sessions: `~/.openclaw/sessions/`

## Deployment Targets

- **Local**: macOS/Linux/Windows (WSL2) via npm global install
- **Docker**: `Dockerfile` + `docker-compose.yml`
- **Fly.io**: `fly.toml` for cloud deployment
- **Render**: `render.yaml`

## CI/CD

- GitHub Actions (`ci.yml`) — lint, type-check, test, build
- Docker release workflow
- Install smoke tests
- Stale issue management
