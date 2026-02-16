# OpenClaw — Product Context

## Why This Project Exists

People want a personal AI assistant that:

- Lives where they already communicate (WhatsApp, Telegram, Slack, etc.)
- Runs on their own devices — not a cloud service they don't control
- Feels local, fast, and always-on
- Doesn't require switching to yet another chat app

OpenClaw fills this gap by acting as a bridge between AI models and messaging
platforms, with the user's device as the control plane.

## Problems It Solves

1. **Channel fragmentation**: Instead of checking multiple AI chat UIs, the
   assistant meets you on your existing channels.
2. **Privacy and control**: Self-hosted means your conversations stay on your
   hardware.
3. **Model flexibility**: Switch between Anthropic, OpenAI, or other providers
   without changing your workflow.
4. **Extensibility**: Community can build channel integrations, tools, and hooks
   without forking the core.

## How It Should Work

### User Flow

1. Install via `npm install -g openclaw@latest`
2. Run `openclaw onboard --install-daemon` (guided wizard)
3. Connect channels (WhatsApp QR, Telegram bot token, etc.)
4. Send messages to the assistant on any connected channel
5. Assistant responds using configured AI model

### Gateway Architecture

- WebSocket control plane on port 18789
- Control UI on port 18790 (Lit-based web app)
- Channels register with the gateway and route messages
- Pi Agent handles AI model communication via RPC

## User Experience Goals

- **Zero-config start**: The onboarding wizard handles everything.
- **Channel parity**: Same assistant experience across all platforms.
- **Reliability**: Gateway should survive restarts, network issues, and model
  failures gracefully.
- **Developer-friendly**: Clear plugin SDK, good docs, conventional patterns.
- **Fast feedback loops**: `pnpm gateway:watch` for instant dev iteration.

## Channels (Built-in + Extensions)

### Built-in

WhatsApp, Telegram, Discord, Slack, Signal, iMessage, Google Chat, WebChat

### Extensions

BlueBubbles, Matrix, Microsoft Teams, Zalo, Zalo Personal, Nostr, IRC, Line,
Mattermost, Nextcloud Talk, Twitch, Feishu, and more.

## Release Channels

- **stable**: Tagged releases (`vYYYY.M.D`), npm `latest`
- **beta**: Prerelease tags (`vYYYY.M.D-beta.N`), npm `beta`
- **dev**: Moving head of `main`
