/// <reference path="../types/netlify-globals.d.ts" />
/**
 * R. Scott Echols CV — Abacus.AI Edge Function
 * Deployed via Netlify Edge Functions (Deno runtime, CDN-edge, zero cold-start)
 *
 * Architecture:
 *   caller → POST /api/abacus → Abacus.AI (management API or RouteLLM)
 *
 * ⚠️  MODEL LOCK IS INTACT — READ THIS BEFORE EXTENDING:
 *   This endpoint does NOT serve /api/chat and MUST NOT be wired into it.
 *   The CV chatbot stays on Claude Opus 4.6 (claude-opus-4-6) per CLAUDE.md
 *   ("Claude Opus 4.6 for ALL chatbot tiers. No exceptions." — Roberto's rule).
 *   Abacus.AI was added by explicit owner request as an ADDITIVE, side-channel
 *   integration for platform/agent work — not as a chatbot substitute.
 *
 * Access:
 *   BUSINESS TIER ONLY. Abacus.AI bills against a paid subscription, so this
 *   endpoint is never exposed to anonymous public traffic. X-Access-Key is
 *   validated server-side against BUSINESS_ACCESS_KEY — the client is never trusted.
 *
 * Rate limiting (in-edge, per IP): 30 requests per minute.
 *
 * Two Abacus.AI surfaces are reachable, because they authenticate differently:
 *   op=health / op=projects → https://api.abacus.ai/api/v0/*  header: `apiKey: <key>`
 *   op=chat                 → https://routellm.abacus.ai/v1/* header: `Authorization: Bearer <key>`
 *   (RouteLLM is OpenAI-compatible; the management API is not.)
 *
 * Environment variables:
 *   ABACUS_API_KEY      — Abacus.AI API key (required). Abacus console → API Keys Dashboard.
 *   BUSINESS_ACCESS_KEY — Secret passphrase for business tier (required).
 *   ABACUS_MODEL        — optional; RouteLLM model name. Default: "route-llm".
 *
 * SECURITY: the key is read server-side only and is never returned, logged, or
 * echoed. Presence is reported as a boolean, never as a value.
 *
 * CLAUDE CODE LANE — see CLAUDE.md and docs/agent-contracts.md before editing
 */

// ─── Upstream constants ───────────────────────────────────────────────────────
const ABACUS_API_BASE = "https://api.abacus.ai/api/v0";
const ROUTELLM_BASE = "https://routellm.abacus.ai/v1";
const DEFAULT_MODEL = "route-llm";
const UPSTREAM_TIMEOUT_MS = 25_000;

// ─── In-edge rate limiting (per IP, sliding window) ──────────────────────────
const rateLimitStore = new Map<string, { count: number; resetAt: number }>();
const RATE_LIMIT = { rpm: 30, window: 60_000 };

function checkRateLimit(ip: string): {
  allowed: boolean;
  remaining: number;
  resetIn: number;
} {
  const now = Date.now();
  const entry = rateLimitStore.get(ip);

  if (!entry || now > entry.resetAt) {
    rateLimitStore.set(ip, { count: 1, resetAt: now + RATE_LIMIT.window });
    return { allowed: true, remaining: RATE_LIMIT.rpm - 1, resetIn: RATE_LIMIT.window };
  }

  if (entry.count >= RATE_LIMIT.rpm) {
    return { allowed: false, remaining: 0, resetIn: entry.resetAt - now };
  }

  entry.count += 1;
  return {
    allowed: true,
    remaining: RATE_LIMIT.rpm - entry.count,
    resetIn: entry.resetAt - now,
  };
}

// ─── CORS headers ─────────────────────────────────────────────────────────────
const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type, X-Access-Key",
  "Content-Type": "application/json",
};

const json = (body: unknown, status = 200, extra: Record<string, string> = {}) =>
  new Response(JSON.stringify(body), { status, headers: { ...CORS, ...extra } });

// ─── Types ────────────────────────────────────────────────────────────────────
type Op = "health" | "projects" | "chat";
const ALLOWED_OPS: Op[] = ["health", "projects", "chat"];

interface ChatMessage {
  role: "user" | "assistant" | "system";
  content: string;
}

// ─── Abacus.AI management API (apiKey header) ────────────────────────────────
async function listProjects(apiKey: string): Promise<{ status: number; body: unknown }> {
  const resp = await fetch(`${ABACUS_API_BASE}/listProjects`, {
    method: "GET",
    headers: { apiKey, "Content-Type": "application/json" },
    signal: AbortSignal.timeout(UPSTREAM_TIMEOUT_MS),
  });

  let body: unknown = null;
  try {
    body = await resp.json();
  } catch {
    body = null;
  }
  return { status: resp.status, body };
}

// ─── Abacus.AI RouteLLM (OpenAI-compatible, Bearer header) ───────────────────
async function routeLlmChat(
  apiKey: string,
  model: string,
  messages: ChatMessage[],
  maxTokens: number
): Promise<string> {
  const resp = await fetch(`${ROUTELLM_BASE}/chat/completions`, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${apiKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({ model, messages, max_tokens: maxTokens }),
    signal: AbortSignal.timeout(UPSTREAM_TIMEOUT_MS),
  });

  if (!resp.ok) {
    // Log the status only — never the key, never the raw upstream body.
    console.error("Abacus RouteLLM error:", resp.status);
    throw new Error(`Abacus RouteLLM error: ${resp.status}`);
  }

  const data = await resp.json();
  return data?.choices?.[0]?.message?.content ?? "";
}

// ─── Main handler ─────────────────────────────────────────────────────────────
export default async (request: Request) => {
  if (request.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: CORS });
  }

  if (request.method !== "POST") {
    return json({ error: "Method not allowed" }, 405);
  }

  // ── Business-tier gate (server-side; never trust the client) ──
  const accessKey = request.headers.get("X-Access-Key") || "";
  const businessKey = Netlify.env.get("BUSINESS_ACCESS_KEY") || "";
  if (!businessKey || accessKey !== businessKey) {
    return json(
      { error: "Business tier access required for Abacus.AI. Provide a valid X-Access-Key." },
      403
    );
  }

  // ── Rate limiting (per IP) ──
  const ip = request.headers.get("x-forwarded-for")?.split(",")?.[0]?.trim() || "unknown";
  const rateCheck = checkRateLimit(ip);
  if (!rateCheck.allowed) {
    const retryAfterSec = Math.ceil(rateCheck.resetIn / 1000);
    return json({ error: "Rate limit exceeded.", retry_after_seconds: retryAfterSec }, 429, {
      "Retry-After": String(retryAfterSec),
      "X-RateLimit-Remaining": "0",
    });
  }

  // ── ABACUS_API_KEY — required ──
  const abacusKey = Netlify.env.get("ABACUS_API_KEY");
  if (!abacusKey) {
    return json(
      {
        error: "Abacus.AI is not configured.",
        hint: "Set ABACUS_API_KEY in Netlify environment variables, then redeploy.",
        abacus_key_present: false,
      },
      503
    );
  }

  // ── Parse body ──
  let body: Record<string, unknown>;
  try {
    body = await request.json();
  } catch {
    return json({ error: "Invalid JSON body" }, 400);
  }

  const op = (body.op as Op) ?? "health";
  if (!ALLOWED_OPS.includes(op)) {
    return json({ error: `Unsupported op. Allowed: ${ALLOWED_OPS.join(", ")}` }, 400);
  }

  try {
    // ── op=health — verify the key works, without exposing account data ──
    if (op === "health") {
      const { status } = await listProjects(abacusKey);
      const keyValid = status === 200;
      return json(
        {
          ok: keyValid,
          abacus_key_present: true,
          key_valid: keyValid,
          upstream_status: status,
          note: keyValid
            ? "Abacus.AI key accepted."
            : "Abacus.AI rejected the key — rotate ABACUS_API_KEY (401 = invalid, 403 = no subscription).",
        },
        keyValid ? 200 : 502
      );
    }

    // ── op=projects — trimmed project listing (no secrets, no payloads) ──
    if (op === "projects") {
      const { status, body: upstream } = await listProjects(abacusKey);
      if (status !== 200) {
        return json({ error: "Abacus.AI request failed.", upstream_status: status }, 502);
      }
      const raw = (upstream as { result?: unknown })?.result;
      const projects = Array.isArray(raw)
        ? raw.map((p: Record<string, unknown>) => ({
            projectId: p.projectId ?? p.project_id ?? null,
            name: p.name ?? null,
            useCase: p.useCase ?? p.use_case ?? null,
          }))
        : [];
      return json({ projects, count: projects.length }, 200, {
        "X-RateLimit-Remaining": String(rateCheck.remaining),
      });
    }

    // ── op=chat — RouteLLM. NOT the CV chatbot; see model lock banner above. ──
    const message = typeof body.message === "string" ? body.message.trim() : "";
    if (!message) {
      return json({ error: "Field 'message' is required for op=chat" }, 400);
    }

    const history = Array.isArray(body.history) ? (body.history as ChatMessage[]) : [];
    const model = (typeof body.model === "string" && body.model) ||
      Netlify.env.get("ABACUS_MODEL") ||
      DEFAULT_MODEL;
    const maxTokens = typeof body.max_tokens === "number" ? body.max_tokens : 1024;

    const messages: ChatMessage[] = [
      ...history
        .filter((m) => m && typeof m.content === "string" && m.role !== "system")
        .slice(-10),
      { role: "user", content: message },
    ];

    const reply = await routeLlmChat(abacusKey, model, messages, maxTokens);

    return json(
      {
        reply,
        provider: "abacus.ai",
        surface: "routellm",
        model,
        // Stated explicitly so no downstream agent mistakes this for the CV chatbot.
        note: "Side-channel endpoint. The CV chatbot at /api/chat remains Claude Opus 4.6.",
      },
      200,
      { "X-RateLimit-Remaining": String(rateCheck.remaining) }
    );
  } catch (err: unknown) {
    const errMsg = err instanceof Error ? err.message : "Unknown error";
    console.error("Abacus.AI edge error:", errMsg);
    return json({ error: "Abacus.AI request failed. Please try again in a moment." }, 502);
  }
};

export const config = { path: "/api/abacus" };
