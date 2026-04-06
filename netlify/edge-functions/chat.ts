/**
 * R. Scott Echols CV — AI Chat Edge Function
 * Deployed via Netlify Edge Functions (Deno runtime, CDN-edge, zero cold-start)
 *
 * Architecture (Phase 1 production path):
 *   public/index.html → POST /api/chat → Claude Opus 4.6 (claude-opus-4-6)
 *                                      ↓ (business tier only, when VECTOR_ENGINE_URL set)
 *                                      Cloud Run /retrieve → pgvector (Supabase) → RAG context
 *
 * ⚠️  MODEL RULE — NON-NEGOTIABLE:
 *   Claude Opus 4.6 for ALL tiers. No substitutions. No cost-cutting.
 *   Roberto Scott Echols has explicitly required this. Do NOT migrate to Gemini or any other model.
 *   See: CLAUDE.md, AGENT-OPS.md, and conversation history (worldseafood@gmail.com).
 *
 * Two-tier access:
 *   PUBLIC   → Claude answers CV/personal questions from embedded knowledge (3 free questions)
 *   BUSINESS → Claude + RAG retrieval from Cloud Run vector service (invitation key required)
 *
 * Rate limiting (in-edge, per IP):
 *   Public tier:   20 requests per minute per IP
 *   Business tier: 100 requests per minute per IP
 *
 * Keywords that trigger rich context: R.SCOTT CV, Resume, RSE, SeaTrace, SirTrav, WorldSeafood
 *
 * Environment variables:
 *   ANTHROPIC_API_KEY   — Claude Opus 4.6 (Anthropic)
 *   BUSINESS_ACCESS_KEY — Secret passphrase for business tier
 *   VECTOR_ENGINE_URL   — Cloud Run retrieval API base URL (optional — enables RAG)
 *                         e.g. https://rse-retrieval-abc123-uc.a.run.app
 *
 * CLAUDE CODE LANE — see CLAUDE.md and docs/agent-contracts.md before editing
 */

// ─── In-edge rate limiting (per IP, sliding window) ──────────────────────────
const rateLimitStore = new Map<string, { count: number; resetAt: number }>();

const RATE_LIMITS = {
  public:   { rpm: 20,  window: 60_000 },
  business: { rpm: 100, window: 60_000 },
};

function checkRateLimit(ip: string, tier: "public" | "business"): {
  allowed: boolean;
  remaining: number;
  resetIn: number;
} {
  const now = Date.now();
  const limit = RATE_LIMITS[tier];
  const key = `${ip}:${tier}`;
  const entry = rateLimitStore.get(key);

  if (!entry || now > entry.resetAt) {
    rateLimitStore.set(key, { count: 1, resetAt: now + limit.window });
    return { allowed: true, remaining: limit.rpm - 1, resetIn: limit.window };
  }

  if (entry.count >= limit.rpm) {
    return { allowed: false, remaining: 0, resetIn: entry.resetAt - now };
  }

  entry.count++;
  return { allowed: true, remaining: limit.rpm - entry.count, resetIn: entry.resetAt - now };
}

// ─── Verified profile pack (embedded fallback, truth-first) ───────────────────

// Sources:
// - knowledge_base/public/cv/identity_verified.md
// - public/data/identity.json
// - docs/CONTENT_SOURCE_OF_TRUTH.md
const RSE_CV_DATA = `
IDENTITY: Roberto Scott Echols (R. Scott Echols, RSE)
PUBLIC ROLE: Founder, technical lead, and systems builder working across World Seafood Producers, SeaTrace, and SirTrav-A2A-Studio.
CONTACT: worldseafood@gmail.com
GITHUB: github.com/WSP001

## VERIFIED PUBLIC FOCUS
- Marine intelligence and fisheries-domain systems
- Traceability and operational software
- AI-assisted workflows, agent orchestration, and knowledge tooling
- Public project communication and consulting profile work

## ACTIVE PUBLIC PROJECTS
- R.-Scott-Echols-CV
- SirTrav-A2A-Studio
- SeaTrace-ODOO
- SirJamesAdventures

## IDENTITY BOUNDARIES
- SirScott = professional CV and consulting identity
- SeaTrace = business and commercial work
- SirTrav = personal studio and agent systems work
- Sir James = creative and family storytelling project
- Never conflate SeaTrace business history with SirTrav personal identity

## TRUTH POLICY
- Answer only from this verified profile pack and any retrieved context
- If a question depends on early-career detail, legacy narrative, or historical claims not present in retrieved context, say the source package is under review
- Do not present speculative narrative as settled fact
- When retrieval is unavailable, keep answers conservative and clearly scoped

## SAFE PUBLIC SUMMARY
- Scott's public profile connects software, AI-assisted systems, marine intelligence, and traceability work
- The current trust-first rebuild is cleaning public answers before deeper vector retrieval is enabled
- Contact for business or verification requests: worldseafood@gmail.com
`;

// ─── RAG retrieval from Cloud Run ─────────────────────────────────────────────

interface RetrieveResult {
  content: string;
  score: number;
  source: string;
  partition: string;
}

async function fetchRAGContext(
  query: string,
  tier: "public" | "business",
  vectorEngineUrl: string
): Promise<string> {
  try {
    const response = await fetch(`${vectorEngineUrl}/retrieve`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ query, tier, top_k: 3 }),
      signal: AbortSignal.timeout(5000),
    });

    if (!response.ok) return "";

    const results: RetrieveResult[] = await response.json();
    if (!results.length) return "";

    const chunks = results
      .filter((r) => r.score > 0.3)
      .map((r, i) => `[Context ${i + 1} — ${r.source} (relevance: ${(r.score * 100).toFixed(0)}%)]:\n${r.content}`)
      .join("\n\n");

    return chunks
      ? `\n\nRELEVANT KNOWLEDGE BASE CONTEXT (retrieved via semantic search):\n${chunks}\n`
      : "";
  } catch {
    return "";
  }
}

// ─── System prompts ────────────────────────────────────────────────────────────

const buildPublicSystem = (ragContext = "") => `You are RSE-Assistant, the intelligent AI guide embedded in R. Scott Echols' professional CV website.

PERSONA: Grounded, concise, professional, and careful with claims. You are helpful, but you do not improvise history.

${RSE_CV_DATA}
${ragContext}

ANSWER RULES:
- Treat retrieved context as the strongest source when it exists.
- If retrieved context is absent, stay within the verified profile pack above.
- If asked about early-career history, location-specific claims, old lineage stories, or technical origin claims not present in retrieved context, answer that the source package is under review and avoid specifics.
- Keep identity boundaries clean: SeaTrace is business, SirTrav is personal studio, Sir James is creative.
- Never present a mixed-trust historical draft as verified fact.

CHATBOT ACCESS MODEL:
- Public tier: 3 free questions, then invitation key required
- Business tier: Invitation key unlocks full knowledge base & technical deep-dives
- After 3 free questions: kindly let the user know they can sign in with an invitation key
  Say: "To continue exploring Scott's full background and technical work, you can request an invitation key at worldseafood@gmail.com"

RESPONSE STYLE:
- Keep responses concise: 2-4 sentences for simple questions, short paragraphs for complex ones
- Prefer documented current work, public project boundaries, and trust-status explanations over mythology
- When a public-tier user is on their last (3rd) question, gently mention the invitation key option
- Always end with a natural follow-up invitation

Always be helpful. If asked something outside CV/professional topics, gently redirect.`;

const buildBusinessSystem = (ragContext = "") => `You are RSE-Business-Assistant, the premium AI advisor for R. Scott Echols' enterprise clients and technical partners.

You have business-tier access to deeper technical context, but you still must stay grounded.

${RSE_CV_DATA}
${ragContext}

ADDITIONAL BUSINESS-TIER KNOWLEDGE:
- SeaTrace API detailed technical specifications and integration guides
- Agent-to-agent (A2A) protocol implementation patterns and code architecture
- Gemini Embedding 2 multimodal RAG implementation with Cloud Run / ChromaDB
- Enterprise consulting frameworks and engagement models
- GitHub repositories: WSP001 — all active projects
- WAFC Business intelligence system
- Linear workspace: linear.app/wsp2agent — active project management
- SirTrav agents: Codex (frontend/Three.js), Claude Code (backend API), Antigravity (QA/testing)
- Phase 1 production stack: Netlify Edge + Cloud Run + pgvector (Supabase) + Gemini Embedding 2

PERSONA: Act as Scott's senior technical advisor. Be direct, precise, expert-level, and disciplined about evidence.
You can discuss technical details, architecture decisions, and business strategy, but do not fill source gaps with confident fiction.

Always verify the business context. If the query seems unrelated to professional collaboration, ask for clarification.
If a historical claim is not present in retrieved context, say it is under review instead of asserting it.`;

// ─── Anthropic Claude Opus 4.6 API call ───────────────────────────────────────

// ⚠️  MODEL LOCK: claude-opus-4-6 — DO NOT CHANGE
// Roberto Scott Echols has explicitly required Claude Opus 4.6 for ALL tiers.
// This is non-negotiable. Any agent editing this file must preserve this constant.
const CLAUDE_MODEL = "claude-opus-4-6";
const ANTHROPIC_API_URL = "https://api.anthropic.com/v1/messages";
const ANTHROPIC_VERSION = "2023-06-01";

async function callClaude(
  apiKey: string,
  systemPrompt: string,
  history: Array<{ role: string; content: string }>,
  userMessage: string,
  maxTokens: number
): Promise<string> {
  // Build messages array — Claude uses "user" / "assistant" roles
  const messages = [
    ...history.slice(-10).map((m) => ({
      role: m.role === "assistant" ? "assistant" : "user",
      content: m.content,
    })),
    { role: "user", content: userMessage },
  ];

  const body = {
    model: CLAUDE_MODEL,
    max_tokens: maxTokens,
    system: systemPrompt,
    messages,
  };

  const resp = await fetch(ANTHROPIC_API_URL, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "x-api-key": apiKey,
      "anthropic-version": ANTHROPIC_VERSION,
    },
    body: JSON.stringify(body),
    signal: AbortSignal.timeout(25_000),
  });

  if (!resp.ok) {
    const errText = await resp.text();
    console.error("Anthropic API error:", resp.status, errText);
    throw new Error(`Anthropic API error: ${resp.status}`);
  }

  const data = await resp.json();
  // Claude returns content as an array of content blocks
  const text = data?.content?.[0]?.text ?? "";
  return text;
}

// ─── CORS headers ──────────────────────────────────────────────────────────────

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type, X-Access-Key",
  "Content-Type": "application/json",
};

// ─── Main handler ─────────────────────────────────────────────────────────────

export default async (request: Request) => {
  if (request.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: CORS });
  }

  if (request.method !== "POST") {
    return new Response(JSON.stringify({ error: "Method not allowed" }), {
      status: 405,
      headers: CORS,
    });
  }

  let body: {
    message: string;
    history?: Array<{ role: string; content: string }>;
    tier?: string;
    questionCount?: number;
  };
  try {
    body = await request.json();
  } catch {
    return new Response(JSON.stringify({ error: "Invalid JSON" }), {
      status: 400,
      headers: CORS,
    });
  }

  const { message, history = [], tier = "public", questionCount = 0 } = body;

  if (!message || typeof message !== "string" || message.trim().length === 0) {
    return new Response(JSON.stringify({ error: "Message is required" }), {
      status: 400,
      headers: CORS,
    });
  }

  // Tier validation
  const accessKey = request.headers.get("X-Access-Key") || "";
  const businessKey = Netlify.env.get("BUSINESS_ACCESS_KEY") || "";
  const isBusiness = tier === "business" && businessKey && accessKey === businessKey;
  const effectiveTier = isBusiness ? "business" : "public";

  // ── Rate limiting (per IP) ──
  const ip = request.headers.get("x-forwarded-for")?.split(",")?.[0]?.trim() || "unknown";
  const rateCheck = checkRateLimit(ip, effectiveTier);

  if (!rateCheck.allowed) {
    const retryAfterSec = Math.ceil(rateCheck.resetIn / 1000);
    return new Response(
      JSON.stringify({
        error: "Rate limit exceeded. Please wait a moment before sending another message.",
        retry_after_seconds: retryAfterSec,
      }),
      {
        status: 429,
        headers: {
          ...CORS,
          "Retry-After": String(retryAfterSec),
          "X-RateLimit-Remaining": "0",
          "X-RateLimit-Reset": String(Math.ceil((Date.now() + rateCheck.resetIn) / 1000)),
        },
      }
    );
  }

  // ── 3-question free tier server-side enforcement ──
  if (!isBusiness && questionCount >= 3) {
    return new Response(
      JSON.stringify({
        reply:
          "You've reached the 3 free question limit. To continue exploring Scott's full background, SeaTrace architecture, and business solutions, sign in with an invitation key — or email worldseafood@gmail.com to request access.",
        tier: "public",
        limit_reached: true,
      }),
      { status: 200, headers: CORS }
    );
  }

  // ⚠️  ANTHROPIC_API_KEY — required for Claude Opus 4.6
  const anthropicKey = Netlify.env.get("ANTHROPIC_API_KEY");
  if (!anthropicKey) {
    return new Response(
      JSON.stringify({ error: "AI service not configured. Please contact the site admin." }),
      { status: 503, headers: CORS }
    );
  }

  // ── RAG retrieval (optional, non-blocking) ──
  let ragContext = "";
  const vectorEngineUrl = Netlify.env.get("VECTOR_ENGINE_URL") || "";
  if (vectorEngineUrl) {
    ragContext = await fetchRAGContext(message.trim(), effectiveTier, vectorEngineUrl);
  }
  const ragActive = ragContext.length > 0;

  const systemPrompt = isBusiness
    ? buildBusinessSystem(ragContext)
    : buildPublicSystem(ragContext);

  try {
    const maxTokens = isBusiness ? 2048 : 512;
    const text = await callClaude(
      anthropicKey,
      systemPrompt,
      history,
      message.trim(),
      maxTokens
    );

    return new Response(
        JSON.stringify({
          reply: text,
          tier: effectiveTier,
          rag_context_used: ragActive,
          answer_source: ragActive
            ? (isBusiness ? "RAG — Business Corpus" : "RAG — CV Corpus")
            : (isBusiness ? "Verified Profile Pack — Business" : "Verified Profile Pack — Public"),
        }),
      {
        status: 200,
        headers: {
          ...CORS,
          "X-RateLimit-Remaining": String(rateCheck.remaining),
        },
      }
    );
  } catch (err: unknown) {
    const errMsg = err instanceof Error ? err.message : "Unknown error";
    console.error("Claude chat error:", errMsg);
    return new Response(
      JSON.stringify({
        error: "I'm having trouble connecting right now. Please try again in a moment.",
      }),
      { status: 502, headers: CORS }
    );
  }
};

export const config = { path: "/api/chat" };
