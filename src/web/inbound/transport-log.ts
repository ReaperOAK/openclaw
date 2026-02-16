/**
 * Transport-level WhatsApp message logging — fires for ALL messages regardless
 * of access control policy (disabled / allowlist / pairing / open).
 *
 * Zero AI cost — pure local file I/O + keyword/pattern urgency detection.
 * Enables passive intelligence gathering even when dmPolicy is "disabled".
 *
 * @module transport-log
 */

import { appendFileSync, mkdirSync, existsSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";
import { loadConfig } from "../../config/config.js";
import { logVerbose } from "../../globals.js";

const INTEL_DIR = join(homedir(), ".openclaw", "whatsapp-intel");

/** Telegram chat ID for urgency notifications. */
const TELEGRAM_CHAT_ID = "1295024057";

/** Keywords that trigger an urgent Telegram notification (case-insensitive). */
const URGENCY_KEYWORDS = [
  "urgent",
  "emergency",
  "asap",
  "immediately",
  "help me",
  "sos",
  "critical",
  "911",
  "right now",
  "dying",
  "accident",
  "hospital",
  "call me",
  "pick up",
  "come now",
  "important",
  "need you",
  "please reply",
  "respond now",
  "time sensitive",
];

/** Patterns that suggest high-priority messages. */
const URGENCY_PATTERNS: RegExp[] = [
  /!!{2,}/, // multiple exclamation marks
  /\b(?:HELP|URGENT|SOS|ASAP)\b/, // ALL-CAPS urgency words
  /(?:call|ring|phone)\s+me/i, // requests to call
];

// ── Helpers ────────────────────────────────────────────────────────────────

function ensureDir(dir: string): void {
  if (!existsSync(dir)) {
    mkdirSync(dir, { recursive: true, mode: 0o700 });
  }
}

function getDateStr(): string {
  return new Date().toISOString().slice(0, 10);
}

function detectUrgency(content: string): string | null {
  const lower = content.toLowerCase();
  for (const keyword of URGENCY_KEYWORDS) {
    if (lower.includes(keyword)) {
      return `keyword: "${keyword}"`;
    }
  }
  for (const pattern of URGENCY_PATTERNS) {
    if (pattern.test(content)) {
      return `pattern: ${pattern.source}`;
    }
  }
  return null;
}

function escapeHtml(str: string): string {
  return str.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
}

/**
 * Resolve the Telegram bot token. Checks config first, then env var.
 * Cached after first successful resolution.
 */
let cachedBotToken: string | null | undefined;
function resolveBotToken(): string | null {
  if (cachedBotToken !== undefined) {
    return cachedBotToken;
  }
  try {
    const cfg = loadConfig();
    const token = cfg.channels?.telegram?.botToken ?? process.env.TELEGRAM_BOT_TOKEN ?? null;
    cachedBotToken = token;
    return token;
  } catch {
    cachedBotToken = process.env.TELEGRAM_BOT_TOKEN ?? null;
    return cachedBotToken;
  }
}

async function notifyTelegram(text: string): Promise<void> {
  const token = resolveBotToken();
  if (!token) {
    return;
  }
  try {
    const res = await fetch(`https://api.telegram.org/bot${token}/sendMessage`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        chat_id: TELEGRAM_CHAT_ID,
        text,
        parse_mode: "HTML",
        disable_web_page_preview: true,
      }),
    });
    if (!res.ok) {
      logVerbose(`[transport-log] Telegram API error ${res.status}`);
    }
  } catch (err) {
    logVerbose(`[transport-log] Telegram notify failed: ${String(err)}`);
  }
}

// ── Public API ─────────────────────────────────────────────────────────────

export interface TransportLogEntry {
  from: string;
  pushName?: string;
  content: string;
  chatId: string;
  isGroup: boolean;
  groupSubject?: string;
  /** Whether this message passed access control (will reach AI). */
  allowed: boolean;
}

/**
 * Log a WhatsApp message at the transport layer.
 *
 * Called **before** the access control gate in monitor.ts so that every message
 * is captured regardless of dmPolicy / groupPolicy. Performs:
 *
 * 1. JSONL file write to `~/.openclaw/workspace/whatsapp-intel/messages-YYYY-MM-DD.jsonl`
 * 2. Keyword/pattern urgency detection (zero AI cost)
 * 3. Telegram notification for urgent messages
 */
export function transportLog(entry: TransportLogEntry): void {
  const now = new Date().toISOString();
  const record = { ts: now, ...entry };

  // ── 1. Write to daily JSONL ──────────────────────────────────────────
  try {
    ensureDir(INTEL_DIR);
    const file = join(INTEL_DIR, `messages-${getDateStr()}.jsonl`);
    appendFileSync(file, JSON.stringify(record) + "\n", { mode: 0o600 });
  } catch (err) {
    logVerbose(`[transport-log] File write failed: ${String(err)}`);
  }

  // ── 2. Urgency detection + Telegram alert ────────────────────────────
  const urgency = detectUrgency(entry.content);
  if (urgency) {
    const source = entry.isGroup ? `group "${entry.groupSubject ?? entry.chatId}"` : "DM";
    const senderLabel = entry.pushName ? `${entry.pushName} (${entry.from})` : entry.from;

    const lines = [
      `🚨 <b>URGENT WhatsApp ${source}</b>`,
      ``,
      `<b>From:</b> ${escapeHtml(senderLabel)}`,
      `<b>Message:</b>`,
      escapeHtml(entry.content.length > 500 ? entry.content.slice(0, 500) + "…" : entry.content),
      ``,
      `<i>Triggered by ${urgency}</i>`,
    ];
    // Fire-and-forget — never block the transport layer
    void notifyTelegram(lines.join("\n"));
  }
}
