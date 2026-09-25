/// <reference path="../types/netlify-globals.d.ts" />
/**
 * social-generate.ts — POST /api/social-generate
 *
 * Generates social-media-ready copy grounded in the CV knowledge base.
 * This is the bridge between the BRAIN (this CV site) and the VOICE
 * (SirScottA2A-STUDIO, formerly SirTrav), which does the publishing.
 *
 *   SirScottA2A  →  POST /api/social-generate  (this file)
 *                       ↓  POST /retrieve (Cloud Run → pgvector)
 *                   grounding chunks + voice pack + hashtag pack
 *                       ↓  Claude Opus 4.6
 *                   platform-formatted draft + provenance trail
 *                       ↓
 *   SirScottA2A publishes. THIS ENDPOINT NEVER PUBLISHES ANYTHING.
 *
 * ⚠️  MODEL RULE — NON-NEGOTIABLE:
 *     Claude Opus 4.6 only, same as /api/chat. Roberto's rule, see CLAUDE.md.
 *
 * ⚠️  GENERATION ONLY — NO SIDE EFFECTS:
 *     No posting, no ingest, no writes of any kind. A caller that receives a
 *     200 from here has a draft, not a published post. Publishing authority
 *     lives in exactly one place (SirScottA2A) on purpose.
 *
 * Environment variables (read via Netlify.env.get — Deno runtime, NOT process.env):
 *   ANTHROPIC_API_KEY   — required. Claude Opus 4.6.
 *   BUSINESS_ACCESS_KEY — required for tier=business and include_seatrace.
 *   VECTOR_ENGINE_URL   — optional. Enables RAG grounding; absence is reported
 *                         honestly as rag_status "not_configured", never faked.
 *
 * Contract: docs/agent-contracts.md § POST /api/social-generate
 */

// ─── Rate limiting ─────────────────────────────────────────────────────────────
// Tighter than /api/chat: each call is a long generation, and the caller is a
// pipeline that can retry in a loop. Per-isolate, same tradeoff as chat.ts.
const rateLimitMap = new Map<string, { count: number; resetAt: number }>();

const RATE_LIMITS = {
  public: { max: 5, windowMs: 60_000 },
  business: { max: 30, windowMs: 60_000 },
};

function checkRateLimit(ip: string, tier: "public" | "business"): {
  allowed: boolean;
  remaining: number;
  resetIn: number;
} {
  const now = Date.now();
  const limit = RATE_LIMITS[tier];
  const key = `${tier}:${ip}`;
  const entry = rateLimitMap.get(key);

  if (!entry || now > entry.resetAt) {
    rateLimitMap.set(key, { count: 1, resetAt: now + limit.windowMs });
    return { allowed: true, remaining: limit.max - 1, resetIn: limit.windowMs };
  }
  if (entry.count >= limit.max) {
    return { allowed: false, remaining: 0, resetIn: entry.resetAt - now };
  }
  entry.count++;
  return {
    allowed: true,
    remaining: limit.max - entry.count,
    resetIn: entry.resetAt - now,
  };
}

// ─── Platform rules ────────────────────────────────────────────────────────────
const PLATFORMS = {
  linkedin: { limit: 3000, hashtagMax: 5, desc: "LinkedIn post — professional, paragraph form, no clickbait" },
  twitter: { limit: 280, hashtagMax: 2, desc: "X/Twitter post — one tight idea, hard 280-character ceiling" },
  general: { limit: 1200, hashtagMax: 4, desc: "Platform-neutral copy — reusable across channels" },
} as const;

type Platform = keyof typeof PLATFORMS;
const TONES = ["professional", "thought-leader", "technical"] as const;
type Tone = typeof TONES[number];

// Identity boundaries are a trust_policy rule in public/api/identity.json:
// "Keep SirTrav personal work separate from SeaTrace business work."
// Mapping identities to hashtag pools enforces that instead of just asking for it.
const IDENTITIES = ["sirscott", "sirtrav", "seatrace", "sirjames"] as const;
type Identity = typeof IDENTITIES[number];

const IDENTITY_HASHTAG_POOLS: Record<Identity, string[]> = {
  sirscott: ["core"],
  sirtrav: ["core", "personal_studio", "creative_producer"],
  seatrace: ["core", "business"],
  sirjames: ["creative"],
};

// ─── RAG retrieval with an honest status ──────────────────────────────────────
// chat.ts historically collapsed every retrieval outcome into a single boolean,
// so "RAG is off", "RAG timed out" and "RAG returned nothing relevant" were
// indistinguishable from the outside. That is how a dead corpus goes unnoticed.
// Every failure mode gets its own name here.
type RagStatus =
  | "ok"
  | "empty"
  | "below_threshold"
  | "not_configured"
  | "timeout"
  | "upstream_error";

interface RetrieveResult {
  content: string;
  score: number;
  source: string;
  partition: string;
}

interface RagOutcome {
  context: string;
  status: RagStatus;
  sources: string[];
  chunk_count: number;
}

const SCORE_FLOOR = 0.3;

async function fetchRAGContext(
  query: string,
  tier: "public" | "business",
  partition: string | null,
  vectorEngineUrl: string
): Promise<RagOutcome> {
  const empty = (status: RagStatus): RagOutcome => ({
    context: "",
    status,
    sources: [],
    chunk_count: 0,
  });

  if (!vectorEngineUrl) return empty("not_configured");

  let results: RetrieveResult[];
  try {
    const response = await fetch(`${vectorEngineUrl}/retrieve`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ query, tier, top_k: 5, partition }),
      signal: AbortSignal.timeout(8000),
    });
    if (!response.ok) {
      // Status only — the upstream body can echo the query back.
      console.error("social-generate RAG upstream status:", response.status);
      return empty("upstream_error");
    }
    results = await response.json();
  } catch (err: unknown) {
    const isTimeout = err instanceof Error && err.name === "TimeoutError";
    console.error("social-generate RAG error:", isTimeout ? "timeout" : "unreachable");
    return empty(isTimeout ? "timeout" : "upstream_error");
  }

  if (!Array.isArray(results) || results.length === 0) return empty("empty");

  const relevant = results.filter((r) => r.score > SCORE_FLOOR);
  if (relevant.length === 0) return empty("below_threshold");

  const context = relevant
    .map((r, i) => `[Context ${i + 1} — ${r.source} / ${r.partition} (relevance ${(r.score * 100).toFixed(0)}%)]:\n${r.content}`)
    .join("\n\n");

  const sources = [...new Set(relevant.map((r) => `${r.partition}:${r.source}`))];
  return { context, status: "ok", sources, chunk_count: relevant.length };
}

// ─── Truth packs (same-origin static assets) ──────────────────────────────────
// voice.json / hashtags.json / identity.json are the committed source of truth
// that scripts/truth_audit.py gates. Fetching them instead of hardcoding a
// prompt means the audit and the generator can never disagree.
interface TruthPacks {
  voice: Record<string, unknown> | null;
  hashtags: Record<string, string[] | string> | null;
  identity: Record<string, unknown> | null;
}

async function loadTruthPacks(requestUrl: string): Promise<TruthPacks> {
  const get = async (path: string) => {
    try {
      const resp = await fetch(new URL(path, requestUrl).toString(), {
        signal: AbortSignal.timeout(4000),
      });
      return resp.ok ? await resp.json() : null;
    } catch {
      return null;
    }
  };
  const [voice, hashtags, identity] = await Promise.all([
    get("/data/voice.json"),
    get("/data/hashtags.json"),
    get("/api/identity.json"),
  ]);
  return { voice, hashtags, identity };
}

function pickHashtags(
  packs: TruthPacks,
  identity: Identity,
  max: number
): string[] {
  const pools = IDENTITY_HASHTAG_POOLS[identity];
  const source = packs.hashtags || {};
  const tags: string[] = [];
  for (const pool of pools) {
    const value = source[pool];
    if (Array.isArray(value)) {
      for (const tag of value) {
        if (typeof tag === "string" && tag.startsWith("#") && !tags.includes(tag)) {
          tags.push(tag);
        }
      }
    }
  }
  return tags.slice(0, max);
}

// ─── System prompt ────────────────────────────────────────────────────────────
function buildSystemPrompt(opts: {
  platform: Platform;
  tone: Tone;
  identity: Identity;
  packs: TruthPacks;
  ragContext: string;
  ragStatus: RagStatus;
  allowedHashtags: string[];
}): string {
  const p = PLATFORMS[opts.platform];
  const voice = opts.packs.voice ? JSON.stringify(opts.packs.voice, null, 1) : "(voice pack unavailable)";
  const boundaries = opts.packs.identity
    ? JSON.stringify((opts.packs.identity as Record<string, unknown>).identity_boundaries ?? {}, null, 1)
    : "(identity pack unavailable)";
  const trust = opts.packs.identity
    ? JSON.stringify((opts.packs.identity as Record<string, unknown>).trust_policy ?? [], null, 1)
    : "(trust policy unavailable)";

  const groundingRule =
    opts.ragStatus === "ok"
      ? `RETRIEVED CONTEXT IS YOUR STRONGEST SOURCE. Every factual claim in the post must trace to it or to the verified packs above.`
      : `NO RETRIEVED CONTEXT IS AVAILABLE (status: ${opts.ragStatus}). Write only what the verified packs above support. Do NOT invent metrics, dates, customer names, volumes, or milestones. If the topic cannot be covered truthfully without retrieval, say so in the content field instead of inventing a post.`;

  return `You are the content generator for R. Scott Echols' professional presence. You draft social copy that another system publishes. You are NOT a marketer and you do NOT hype.

TARGET: ${p.desc}
HARD LIMIT: ${p.limit} characters for the post body, excluding hashtags. Going over is a failure, not a style choice.
TONE: ${opts.tone}
SPEAKING AS IDENTITY: ${opts.identity}

VOICE PACK (Scott's actual writing style — match it):
${voice}

IDENTITY BOUNDARIES (never blend these):
${boundaries}

TRUST POLICY (binding):
${trust}

${groundingRule}
${opts.ragContext}

APPROVED HASHTAGS for the "${opts.identity}" identity — choose from this list ONLY, at most ${p.hashtagMax}:
${opts.allowedHashtags.join(" ") || "(none available)"}

RULES:
- No invented statistics, no fabricated milestones, no imagined quotes.
- No em dashes as decoration; write like an operator, not a brand account.
- Do not open with "Excited to announce" or any variant of it.
- Never claim something is live or shipped unless the retrieved context says so.
- Keep the identities separate: a ${opts.identity} post does not borrow credibility from the others.

OUTPUT FORMAT — return RAW JSON only, no markdown fence, no commentary:
{"content": "the post body, no hashtags inside it", "hashtags": ["#Tag"], "claims": ["each factual claim made, one per line"]}`;
}

// ─── Claude call ──────────────────────────────────────────────────────────────
// ⚠️  MODEL LOCK: claude-opus-4-6 — DO NOT CHANGE
// Same lock as chat.ts. Roberto has required Claude Opus 4.6 for all
// generation surfaces on this site. Any agent editing this file must preserve it.
const CLAUDE_MODEL = "claude-opus-4-6";
const ANTHROPIC_API_URL = "https://api.anthropic.com/v1/messages";
const ANTHROPIC_VERSION = "2023-06-01";

async function callClaude(
  apiKey: string,
  systemPrompt: string,
  userMessage: string,
  maxTokens: number
): Promise<string> {
  const resp = await fetch(ANTHROPIC_API_URL, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "x-api-key": apiKey,
      "anthropic-version": ANTHROPIC_VERSION,
    },
    body: JSON.stringify({
      model: CLAUDE_MODEL,
      max_tokens: maxTokens,
      system: systemPrompt,
      messages: [{ role: "user", content: userMessage }],
    }),
    signal: AbortSignal.timeout(25_000),
  });

  if (!resp.ok) {
    // Status only — never the key, never the raw upstream body.
    console.error("Anthropic API error:", resp.status);
    throw new Error(`Anthropic API error: ${resp.status}`);
  }

  const data = await resp.json();
  return data?.content?.[0]?.text ?? "";
}

interface ModelDraft {
  content: string;
  hashtags: string[];
  claims: string[];
}

function parseDraft(raw: string): ModelDraft | null {
  // Tolerate a fenced block even though the prompt forbids one.
  const cleaned = raw.trim().replace(/^```(?:json)?\s*/i, "").replace(/\s*```$/, "");
  try {
    const parsed = JSON.parse(cleaned);
    if (typeof parsed?.content !== "string") return null;
    return {
      content: parsed.content,
      hashtags: Array.isArray(parsed.hashtags) ? parsed.hashtags.filter((h: unknown) => typeof h === "string") : [],
      claims: Array.isArray(parsed.claims) ? parsed.claims.filter((c: unknown) => typeof c === "string") : [],
    };
  } catch {
    return null;
  }
}

// ─── CORS ─────────────────────────────────────────────────────────────────────
const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type, X-Access-Key",
  "Content-Type": "application/json",
};

const json = (body: unknown, status: number, extra: Record<string, string> = {}) =>
  new Response(JSON.stringify(body), { status, headers: { ...CORS, ...extra } });

// ─── Handler ──────────────────────────────────────────────────────────────────
export default async (request: Request) => {
  if (request.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: CORS });
  }
  if (request.method !== "POST") {
    return json({ error: "Method not allowed. Use POST." }, 405);
  }

  let body: {
    topic?: string;
    platform?: string;
    tone?: string;
    identity?: string;
    include_seatrace?: boolean;
    tier?: string;
  };
  try {
    body = await request.json();
  } catch {
    return json({ error: "Invalid JSON" }, 400);
  }

  const topic = (body.topic || "").trim();
  if (!topic || topic.length < 3) {
    return json({ error: "topic is required (minimum 3 characters)" }, 400);
  }
  if (topic.length > 500) {
    return json({ error: "topic must be 500 characters or fewer" }, 400);
  }

  const platform: Platform =
    body.platform && body.platform in PLATFORMS ? (body.platform as Platform) : "general";
  const tone: Tone =
    body.tone && (TONES as readonly string[]).includes(body.tone)
      ? (body.tone as Tone)
      : "professional";
  const requestedIdentity: Identity =
    body.identity && (IDENTITIES as readonly string[]).includes(body.identity)
      ? (body.identity as Identity)
      : "sirscott";

  // ── Tier validation (server-side, never trust the client) ──
  const accessKey = request.headers.get("X-Access-Key") || "";
  const businessKey = Netlify.env.get("BUSINESS_ACCESS_KEY") || "";
  const isBusiness = body.tier === "business" && !!businessKey && accessKey === businessKey;
  const effectiveTier: "public" | "business" = isBusiness ? "business" : "public";

  // The tier boundary, restated at the endpoint: business_seatrace content and
  // the seatrace identity are business-tier only. A public caller asking for
  // them is refused outright rather than quietly downgraded — a silent
  // downgrade would produce a post that looks authorised but is not.
  const wantsSeatrace = body.include_seatrace === true || requestedIdentity === "seatrace";
  if (wantsSeatrace && !isBusiness) {
    return json(
      {
        error:
          "SeaTrace business content requires business tier. Provide a valid X-Access-Key with tier=business.",
      },
      403
    );
  }

  const ip = request.headers.get("x-forwarded-for")?.split(",")?.[0]?.trim() || "unknown";
  const rateCheck = checkRateLimit(ip, effectiveTier);
  if (!rateCheck.allowed) {
    const retryAfterSec = Math.ceil(rateCheck.resetIn / 1000);
    return json(
      {
        error: "Rate limit exceeded. Generation is expensive; please pace requests.",
        retry_after_seconds: retryAfterSec,
      },
      429,
      { "Retry-After": String(retryAfterSec), "X-RateLimit-Remaining": "0" }
    );
  }

  const anthropicKey = Netlify.env.get("ANTHROPIC_API_KEY");
  if (!anthropicKey) {
    return json(
      { error: "Generation service not configured. Set ANTHROPIC_API_KEY and redeploy." },
      503
    );
  }

  // ── Grounding ──
  const vectorEngineUrl = Netlify.env.get("VECTOR_ENGINE_URL") || "";
  const partition = wantsSeatrace ? "business_seatrace" : null;
  const [rag, packs] = await Promise.all([
    fetchRAGContext(topic, effectiveTier, partition, vectorEngineUrl),
    loadTruthPacks(request.url),
  ]);

  const p = PLATFORMS[platform];
  const allowedHashtags = pickHashtags(packs, requestedIdentity, p.hashtagMax * 3);

  const systemPrompt = buildSystemPrompt({
    platform,
    tone,
    identity: requestedIdentity,
    packs,
    ragContext: rag.context,
    ragStatus: rag.status,
    allowedHashtags,
  });

  let raw: string;
  try {
    raw = await callClaude(
      anthropicKey,
      systemPrompt,
      `Draft one ${platform} post about: ${topic}`,
      1500
    );
  } catch (err: unknown) {
    const errMsg = err instanceof Error ? err.message : "Unknown error";
    console.error("social-generate error:", errMsg);
    return json(
      { error: "Generation failed upstream. Check ANTHROPIC_API_KEY validity and retry." },
      502
    );
  }

  const draft = parseDraft(raw);
  if (!draft) {
    return json(
      { error: "Model returned an unparseable draft. Retry; if it persists the prompt contract has drifted." },
      502
    );
  }

  // Enforce the hashtag allowlist server-side. The prompt asks for it; this
  // guarantees it, so a hallucinated tag can never reach a published post.
  const hashtags = draft.hashtags
    .filter((h) => allowedHashtags.includes(h))
    .slice(0, p.hashtagMax);

  const characterCount = draft.content.length;

  return json(
    {
      content: draft.content,
      hashtags,
      character_count: characterCount,
      platform,
      platform_limit: p.limit,
      // Honest: false when the model overran the platform ceiling. The caller
      // decides whether to retry or trim — this endpoint does not silently cut
      // a post in half mid-sentence.
      platform_formatted: characterCount <= p.limit,
      identity: requestedIdentity,
      tone,
      tier: effectiveTier,
      sources_used: rag.sources,
      rag_status: rag.status,
      rag_chunks_used: rag.chunk_count,
      claims: draft.claims,
      model: CLAUDE_MODEL,
      published: false, // always. Publishing is SirScottA2A's responsibility.
    },
    200,
    { "X-RateLimit-Remaining": String(rateCheck.remaining) }
  );
};

export const config = { path: "/api/social-generate" };
