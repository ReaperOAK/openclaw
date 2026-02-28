# Model Routing Architecture — Quota-Protected Multi-Tier Strategy

> **Version:** 1.0.0
> **Date:** 2026-03-01
> **Scope:** OpenClaw instance on OCI ARM — GitHub Copilot Student (300 premium req/month)
> **Status:** DEPLOYED

---

## 1. Executive Summary

This architecture protects a GitHub Copilot Student plan (300 premium requests/month,
reset 1st UTC) from runaway consumption while maintaining high-quality AI output.
The strategy routes requests through 3 tiers — free models handle routine work,
mid-tier handles complex tasks, and premium models are reserved for critical work
at ~10/day budget.

**Design principles:**

- Default to zero-cost models for all routine work
- Escalation is explicit (alias-triggered), never automatic
- Loop detection kills quota-burning spirals before they eat budget
- Fallback chains always terminate at a free tier model
- No config change touches source code — everything is `openclaw.json`

---

## 2. Tier Definitions

### Tier 0 — Free (0x multiplier, unlimited)

| Model            | Provider          | Multiplier | Context | Notes                           |
| ---------------- | ----------------- | ---------- | ------- | ------------------------------- |
| gpt-4.1          | github-copilot    | 0x         | 128K    | Best free model — strong coding |
| gpt-4.1-mini     | github-copilot    | 0x         | 128K    | Fast, good for simple tasks     |
| gpt-4.1-nano     | github-copilot    | 0x         | 128K    | Fastest, minimal tasks          |
| gpt-4o           | github-copilot    | 0x         | 128K    | Multimodal, good general        |
| gemini-2.5-flash | google-gemini-cli | Free       | 1M      | Free via OAuth, huge context    |
| gemini-2.5-pro   | google-gemini-cli | Free       | 1M      | Free via OAuth, strongest free  |
| coder-model      | qwen-portal       | Free       | 128K    | Free via OAuth, code-focused    |
| vision-model     | qwen-portal       | Free       | 128K    | Free via OAuth, multimodal      |

### Tier 1 — Budget (0.25x-0.5x, ~40/day budget = 10-20 premium-equiv)

| Model                | Provider       | Multiplier | Context | Notes                  |
| -------------------- | -------------- | ---------- | ------- | ---------------------- |
| claude-haiku-4.5     | github-copilot | 0.25x      | 200K    | Best budget Anthropic  |
| gpt-5-mini           | github-copilot | 0.33x      | 128K    | Budget OpenAI flagship |
| o3-mini              | github-copilot | 0.5x       | 128K    | Reasoning, 0.5x cost   |
| gemini-3-pro-preview | github-copilot | 0.5x       | 128K    | Copilot Gemini         |

### Tier 2 — Premium (1x, ~10/day hard budget)

| Model             | Provider       | Multiplier | Context | Notes               |
| ----------------- | -------------- | ---------- | ------- | ------------------- |
| claude-sonnet-4.6 | github-copilot | 1x         | 200K    | Best coding model   |
| claude-opus-4.6   | github-copilot | 1x         | 200K    | Strongest reasoning |
| gpt-5.2           | github-copilot | 1x         | 128K    | OpenAI flagship     |
| gpt-5.2-codex     | github-copilot | 1x         | 128K    | Code-optimized      |

---

## 3. Routing Architecture

```
                        ┌──────────────────────────┐
                        │    INBOUND REQUEST        │
                        └────────────┬─────────────┘
                                     │
                                     ▼
                        ┌──────────────────────────┐
                        │  MODEL ALIAS RESOLUTION   │
                        │  (user types /use alias)  │
                        └────────────┬─────────────┘
                                     │
               ┌─────────────────────┼─────────────────────┐
               │                     │                     │
               ▼                     ▼                     ▼
     ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐
     │   TIER 0 (0x)   │  │  TIER 1 (0.25x) │  │  TIER 2 (1x)   │
     │   DEFAULT PATH  │  │  EXPLICIT ONLY   │  │  EXPLICIT ONLY  │
     └────────┬────────┘  └────────┬────────┘  └────────┬────────┘
              │                    │                     │
              ▼                    ▼                     ▼
     ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐
     │ github-copilot/  │  │ github-copilot/  │  │ github-copilot/  │
     │ gpt-4.1          │  │ claude-haiku-4.5 │  │ claude-sonnet-4.6│
     │                  │  │                  │  │                  │
     │ FALLBACK →       │  │ FALLBACK →       │  │ FALLBACK →       │
     │ gemini-2.5-pro   │  │ gpt-5-mini       │  │ claude-haiku-4.5 │
     │ qwen/coder       │  │ gpt-4.1          │  │ gpt-5-mini       │
     │ gemini-2.5-flash │  │ gemini-2.5-pro   │  │ gemini-2.5-pro   │
     │ gpt-4.1-mini     │  │ qwen/coder       │  │ gpt-4.1          │
     └─────────────────┘  └─────────────────┘  └─────────────────┘
              │                    │                     │
              ▼                    ▼                     ▼
     ┌──────────────────────────────────────────────────────────────┐
     │                  LOOP DETECTION GUARD                        │
     │  warning=5 │ critical=10 │ circuit_breaker=15                │
     │  Detectors: generic_repeat + poll_no_progress + ping_pong   │
     └──────────────────────────────────────────────────────────────┘
```

### Default Path (no alias specified)

All requests without an explicit `/use <alias>` command hit the **Tier 0** path:

1. **Primary:** `github-copilot/gpt-4.1` — best free Copilot model
2. **Fallback 1:** `google-gemini-cli/gemini-2.5-pro` — free, 1M context
3. **Fallback 2:** `qwen-portal/coder-model` — free, code-optimized
4. **Fallback 3:** `google-gemini-cli/gemini-2.5-flash` — free, fast
5. **Fallback 4:** `github-copilot/gpt-4.1-mini` — free, fast Copilot

**Zero premium requests consumed on the default path.**

### Explicit Escalation (alias-triggered)

Users escalate via `/use <alias>`:

- `/use haiku` → Tier 1 claude-haiku-4.5 (0.25x)
- `/use mini` → Tier 1 gpt-5-mini (0.33x)
- `/use sonnet` → Tier 2 claude-sonnet-4.6 (1x)
- `/use opus` → Tier 2 claude-opus-4.6 (1x)
- `/use gpt` → Tier 2 gpt-5.2 (1x)
- `/use codex` → Tier 2 gpt-5.2-codex (1x)

---

## 4. Alias Map

| Alias    | Target Model                       | Tier | Multiplier |
| -------- | ---------------------------------- | ---- | ---------- |
| `fast`   | github-copilot/gpt-4.1-nano        | 0    | 0x         |
| `code`   | github-copilot/gpt-4.1             | 0    | 0x         |
| `gemini` | google-gemini-cli/gemini-2.5-pro   | 0    | Free       |
| `flash`  | google-gemini-cli/gemini-2.5-flash | 0    | Free       |
| `qwen`   | qwen-portal/coder-model            | 0    | Free       |
| `haiku`  | github-copilot/claude-haiku-4.5    | 1    | 0.25x      |
| `mini`   | github-copilot/gpt-5-mini          | 1    | 0.33x      |
| `reason` | github-copilot/o3-mini             | 1    | 0.5x       |
| `sonnet` | github-copilot/claude-sonnet-4.6   | 2    | 1x         |
| `opus`   | github-copilot/claude-opus-4.6     | 2    | 1x         |
| `gpt`    | github-copilot/gpt-5.2             | 2    | 1x         |
| `codex`  | github-copilot/gpt-5.2-codex       | 2    | 1x         |
| `vision` | qwen-portal/vision-model           | 0    | Free       |

---

## 5. Quota Budget Model

**Monthly budget:** 300 premium (1x-equivalent) requests

| Tier               | Daily Budget | Monthly Cost                    | % of Budget |
| ------------------ | ------------ | ------------------------------- | ----------- |
| Tier 0             | Unlimited    | 0                               | 0%          |
| Tier 1 (0.25x avg) | ~40 requests | ~300 requests × 0.3 = 90 equiv  | 30%         |
| Tier 2 (1x)        | ~7 requests  | ~210 requests × 1.0 = 210 equiv | 70%         |
| **Total**          | —            | —                               | **100%**    |

**Conservative allocation:**

- Tier 2: 7/day × 30 days = 210 premium-equivalent
- Tier 1: 40/day × 30 days = 1200 requests × 0.3 avg = ~90 premium-equivalent
- Reserve: 0 (no margin — but Tier 0 is unlimited backup)

---

## 6. Loop Detection Configuration

Enabled with aggressive thresholds to prevent quota-burning spirals:

```json
{
  "loopDetection": {
    "enabled": true,
    "historySize": 20,
    "warningThreshold": 5,
    "criticalThreshold": 10,
    "globalCircuitBreakerThreshold": 15,
    "detectors": {
      "genericRepeat": true,
      "knownPollNoProgress": true,
      "pingPong": true
    }
  }
}
```

**What this does:**

- After 5 identical tool calls → WARNING injected into context
- After 10 → CRITICAL, model told to stop and try different approach
- After 15 → CIRCUIT BREAKER, tool loop force-terminated
- Ping-pong detection catches A→B→A→B alternating patterns
- Poll-no-progress catches `command_status` spam

---

## 7. Subagent & Heartbeat Protection

| Feature          | Model                       | Tier | Rationale                                               |
| ---------------- | --------------------------- | ---- | ------------------------------------------------------- |
| Heartbeat        | github-copilot/gpt-4.1-nano | 0    | Heartbeats are high-frequency, low-value — must be free |
| Subagent default | github-copilot/gpt-4.1      | 0    | Subagents run autonomously — must not burn quota        |
| Image model      | qwen-portal/vision-model    | 0    | Vision tasks go to free Qwen                            |

---

## 8. Exec Security

```json
{
  "exec": {
    "host": "gateway",
    "security": "full",
    "ask": "off",
    "backgroundMs": 10000,
    "timeoutSec": 1800,
    "cleanupMs": 1800000
  }
}
```

- `host: gateway` — all exec runs on the gateway (no sandbox overhead)
- `security: full` — full exec permission (owner-operated instance)
- `ask: off` — no approval prompts (single-user, trusted environment)
- `timeoutSec: 1800` — 30 min hard kill on exec commands

---

## 9. Failure Containment

**Failover chain guarantees:**

1. Every fallback chain terminates at a free-tier model
2. No fallback chain escalates to a higher cost tier
3. If all providers fail → error surfaced to user, no silent retry loops

**Provider health:**

- `github-copilot` token cached with auto-refresh
- `google-gemini-cli` OAuth with 2 accounts for rotation
- `qwen-portal` OAuth, free, no rate limits observed

---

## 10. Monitoring

External quota tracking via cron script at
`~/.openclaw/scripts/quota-monitor.sh`. Runs daily, logs to
`~/.openclaw/logs/quota-usage.log`.

Tracks:

- Estimated daily premium consumption
- Remaining monthly budget
- Alerts at 80% threshold (240/300) and 95% threshold (285/300)
