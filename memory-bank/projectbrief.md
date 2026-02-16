# OpenClaw — Project Brief

## Overview

**OpenClaw** is a personal AI assistant you run on your own devices. It answers
you on the channels you already use (WhatsApp, Telegram, Slack, Discord, Google
Chat, Signal, iMessage, Microsoft Teams, WebChat), plus extension channels like
BlueBubbles, Matrix, Zalo, and Zalo Personal. It can speak and listen on
macOS/iOS/Android, and can render a live Canvas you control.

The Gateway is the control plane — the product is the assistant.

## Core Requirements

1. **Multi-channel messaging**: Route AI-powered conversations across 15+
   messaging platforms (built-in + extensions).
2. **Single-user, self-hosted**: Designed for one person running it on their own
   infrastructure.
3. **Always-on**: Gateway daemon runs persistently via launchd/systemd.
4. **Extensible**: Plugin SDK for community extensions; hooks system for
   customization.
5. **Cross-platform**: macOS app, iOS app, Android app, CLI, WebChat.
6. **Model-agnostic**: Works with Anthropic, OpenAI, and other providers via
   OAuth or API keys.

## Project Scope

- **In scope**: Gateway server, CLI, messaging channels, plugin SDK, mobile
  apps, control UI, documentation.
- **Out of scope**: Multi-tenant SaaS hosting, enterprise admin panels.

## Success Criteria

- Gateway starts and stays running reliably.
- Messages route correctly across all connected channels.
- Extensions install cleanly and don't break core.
- CLI onboarding wizard works end-to-end on macOS/Linux/Windows (WSL2).
- Tests pass at 70% coverage threshold.
- Documentation stays in sync with code changes.

## Repository

- **Repo**: https://github.com/openclaw/openclaw
- **License**: MIT
- **Version scheme**: `vYYYY.M.D` (CalVer)
- **Current version**: 2026.2.13
