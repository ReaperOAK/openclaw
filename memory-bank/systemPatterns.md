# OpenClaw — System Patterns

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

## Key Technical Decisions

### Dependency Injection

- `createDefaultDeps()` in `src/cli/deps.ts` provides channel send functions and
  shared services.
- Follow this pattern — don't instantiate singletons directly.

### Plugin SDK

- Extensions import from `openclaw/plugin-sdk` (resolved via jiti alias at
  runtime).
- Plugin-only deps go in the extension's `package.json`, never the root.
- Avoid `workspace:*` in `dependencies` (npm install breaks).

### Hooks System

- Bundled in `src/hooks/bundled/` (session-memory, boot-md, command-logger).
- User hooks via config.
- Hooks are async functions receiving context + next.

### Configuration

- Zod-validated schema in `src/config/`.
- Env precedence: `process.env` → `./.env` → `~/.openclaw/.env` →
  `openclaw.json` env block.
- Config lives at `~/.openclaw/openclaw.json`.

### Channel Architecture

- All channels (built-in + extension) must be considered when touching routing,
  allowlists, pairing, onboarding, or command gating.
- Built-in: `src/telegram/`, `src/discord/`, `src/slack/`, `src/signal/`,
  `src/imessage/`, `src/web/`
- Extensions: `extensions/*` (workspace packages)

### Build System

- **tsdown** for production builds → `dist/`
- **tsx** for dev execution
- **Bun** supported for scripts and dev (keep both Node + Bun paths working)

### CLI Framework

- Commander for command parsing
- `@clack/prompts` for interactive prompts
- `osc-progress` for progress bars
- `src/cli/progress.ts` for spinners (never hand-roll)
- `src/terminal/palette.ts` for colors (no hardcoded ANSI)
- `src/terminal/table.ts` for table output

## Design Patterns

### Message Routing

```
User message → Channel adapter → Routing layer → Agent → Model → Response → Channel adapter → User
```

### Extension Loading

```
Extension discovered → jiti resolves plugin-sdk → Extension registers channels/tools → Gateway integrates
```

### Config Resolution

```
process.env → .env (local) → ~/.openclaw/.env → openclaw.json env block → Zod validation → Config object
```

## Anti-Patterns to Avoid

- **No re-export wrapper files**: Import directly from the source module.
- **No duplicate utilities**: Search before creating formatters/helpers.
- **No hardcoded colors**: Use `src/terminal/palette.ts`.
- **No hand-rolled spinners**: Use `src/cli/progress.ts`.
- **No `any` types**: Strict TypeScript throughout.
- **No `console.log` in production**: Use tslog structured logging.

## Component Relationships

| Component  | Depends On                 | Provides                     |
| ---------- | -------------------------- | ---------------------------- |
| CLI        | Commander, deps.ts, config | User commands, onboarding    |
| Gateway    | Express, WS, channels      | Control plane, WebSocket API |
| Pi Agent   | Model providers, tools     | AI conversation, tool use    |
| Control UI | Lit, Vite                  | Web dashboard                |
| Plugin SDK | jiti, TypeBox              | Extension API surface        |
| Channels   | Routing, config            | Message delivery             |
