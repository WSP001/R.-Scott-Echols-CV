/**
 * R. Scott Echols CV — AI Chat Edge Function
 * Deployed via Netlify Edge Functions (Deno runtime, CDN-edge, zero cold-start)
 *
 * Architecture (Phase 1 production path):
 *   public/index.html → POST /api/chat → Claude Opus 4.6
 *                                      ↓ (business tier only, when VECTOR_ENGINE_URL set)
 *                                      Cloud Run /retrieve → ChromaDB → RAG context
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
 *   ANTHROPIC_API_KEY   — Anthropic / Claude Opus 4.6
 *   BUSINESS_ACCESS_KEY — Secret passphrase for business tier
 *   VECTOR_ENGINE_URL   — Cloud Run retrieval API base URL (optional — enables RAG)
 *                         e.g. https://rse-retrieval-abc123-uc.a.run.app
 *
 * CLAUDE CODE LANE — see CLAUDE.md and docs/agent-contracts.md before editing
 */

import Anthropic from "https://esm.sh/@anthropic-ai/sdk@0.27.3";

// ─── In-edge rate limiting (per IP, sliding window using Netlify KV) ─────────
// Simple token bucket via Map (resets on cold start — good enough for edge)
// For persistent rate limiting, use Netlify Blob Store or Upstash Redis.
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

// ─── CV Knowledge Base (embedded — public tier fallback, no vector DB needed) ─

// Source: knowledge_base/docs/CHATBOT_KNOWLEDGE_BRIEF.md (Cascade, 2026-03-21)
// This embedded knowledge is the public-tier fallback when vector RAG is unavailable.
const RSE_CV_DATA = `
IDENTITY: R. Scott Echols (Roberto Scott Echols, R.SCOTT CV, RSE)
TITLE: Founder, Technical Lead & AI Systems Architect
COMPANIES: World Seafood Producers (WSP001) / WARP Industries / SirTrav-A2A-Studio
STACK VALUATION: $4.2M USD
EMAIL: worldseafood@gmail.com
GITHUB: github.com/WSP001

## ORIGIN STORY — Digital Communications First
Scott's career did NOT start in seafood. It started in digital communications engineering.
- 1979: Education began at Lees McRae College
- 1984–1987: Member of the ALOHA-net team at University of Hawaii under Dr. Norman Abramson
  - ALOHA-net set the first wide-area mobile/wireless packet switching international network (X.25 protocol)
  - "The ALOHA-net was the basis for the modern internet today" — reduced complexity of Ethernet and later Wi-Fi
- 1987: Co-founded WARP Industries (World Automated Robotic Producers) — Advanced Mobile Robotics R&D
- 1988: Founded World Seafood Producers (WSP) — to FUND the WARP Industries robotics work
  NOTE: WSP was the funding vehicle. Seafood funded the robotics research.

## PEARL HARBOR & THE PATENT ORIGIN
- ~1985–1990: Systems Analyst at Advanced Digital Systems (ADS)
- Installed U.S. Navy Pearl Harbor Fuel Depot Inventory & Control Management Systems
- Networked Pearl Harbor back to Washington D.C. via area-wide broadband packet switching with in-house proprietary protocol
- That system is STILL RUNNING TODAY
- This protocol architecture is the foundation of USPTO Patent No. 16/936,852 filed 2020

## USPTO PATENT
- Application No.: 16/936,852
- Filed: July 23, 2020
- Title: "TRUSTABLE CHAIN BUILDING EXTERNAL INFORMATION INVENTION FOR FISHERIES INDEXING, SEAFOOD MANAGEMENT, OR OTHER INDUSTRIES RAW-TO-FINISHED PRODUCTS SECURE INTERNAL COMMUNICATIONS NETWORK PROTOCOL"
- IP Vault: Perkin Coie, Seattle — No.: 130214-8001.US01

## ALASKA MILESTONES
- Worked with Senator Ted Stevens to establish Alaska Science & Technology Foundation — $107MM legislative endowment
- WARP Industries awarded $2.2MM public grant (UAA Technologies) + WSP matching $2.2MM private R&D
- Assigned to Alaska State Salmon Restoration Committee by Chairman Senator Ben Stevens (1990–2002)
- 21 consecutive seasons of record-setting salmon grounds prices and crewshares
- Instituted first public hatchery cost/private ranch recovery contract with DIPAC — standard still in use today

## SEATRACE — FOUR PILLARS MARINE TRACEABILITY PLATFORM
- SeaSide (HOLD): Vessel tracking and initial data capture at sea
- DeckSide (RECORD): Catch verification, HACCP compliance certification on deck
- DockSide (STORE): Supply chain handoff, cold chain, port processing data
- MarketSide (EXCHANGE): Consumer QR verification and retail traceability portal
- Stack Operator Valuation: $4.2M USD
- Tech: React/Vite, FastAPI, Kong Gateway, Prometheus/Grafana, Netlify Edge Functions
- Live: seatrace.worldseafoodproducers.com

## SIRTRAV-A2A-STUDIO
- Marine intelligence A2A (agent-to-agent) platform
- Three-agent architecture: Codex (frontend), Claude Code (backend), Antigravity (QA)
- Claude Opus 4.6 + Gemini Embedding 2 multimodal RAG
- Live: sirtrav-a2a-studio.netlify.app

## CREDENTIALS
- Education: UH Manoa — Digital Communication Engineering (Masters-level, 1984–1987)
- ALOHA-net: Member, founding team, X.25 protocol, under Dr. Norman Abramson
- USPTO Patent: App. No. 16/936,852, filed July 23, 2020
- USCG License: Licensed Captain — commercial, recreational, subsistence
- USDA: Plant Operator Certification
- Halal/Kosher: Plant Licensed Owner (both certifications)
- Ikura Tech: 21 seasons, record Japanese premium roe market operations
- SIMP: Original framework final draftsman architect (U.S. NOAA/NMFS)
- ITTP: International Trusted Traders Program designer

## SKILLS
- Cloud & DevOps: Netlify/CI-CD (95%), GitHub Workflows (92%), API Management (93%)
- Development: JavaScript/Node.js (92%), Python (85%), PowerShell (88%), TypeScript (80%)
- Agentic AI: Claude API/Anthropic (95%), Gemini Embedding 2 (88%), Multi-Agent Systems (90%), RAG Pipelines (85%)
- Data & Domain: Power BI (90%), Marine/Fisheries Domain (97%), Supply Chain Optimization (92%)

## CONTACT
- Email: worldseafood@gmail.com
- GitHub: github.com/WSP001
- Available for: Enterprise consulting, AI systems architecture, marine intelligence platforms
- Business tier access: email worldseafood@gmail.com to request invitation key
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
      signal: AbortSignal.timeout(5000), // 5s timeout — don't block the user
    });

    if (!response.ok) return "";

    const results: RetrieveResult[] = await response.json();
    if (!results.length) return "";

    // Format retrieved chunks as context for Claude
    const chunks = results
      .filter((r) => r.score > 0.3) // only include reasonably relevant chunks
      .map((r, i) => `[Context ${i + 1} — ${r.source} (relevance: ${(r.score * 100).toFixed(0)}%)]:\n${r.content}`)
      .join("\n\n");

    return chunks
      ? `\n\nRELEVANT KNOWLEDGE BASE CONTEXT (retrieved via semantic search):\n${chunks}\n`
      : "";
  } catch {
    // RAG is additive — if it fails, fall back to embedded CV data gracefully
    return "";
  }
}

// ─── System prompts ────────────────────────────────────────────────────────────

const buildPublicSystem = (ragContext = "") => `You are RSE-Assistant, the intelligent AI guide embedded in R. Scott Echols' professional CV website.

PERSONA: Knowledgeable, concise, professional but approachable. You speak about Roberto Scott Echols as if you deeply know his work.

${RSE_CV_DATA}
${ragContext}

KEYWORD TRIGGERS — respond with rich detail when these appear in the user's question:
- "R.SCOTT CV", "RSE resume", "resume", "CV" → Give the full resume summary above
- "SeaTrace" → Describe all Four Pillars with specific functions
- "SirTrav" → Describe the A2A platform and three agents
- "Four Pillars" → SeaSide, DeckSide, DockSide, MarketSide with descriptions
- "worldseafoodproducers" or "WSP" → World Seafood Producers company overview
- "$4.2M" or "valuation" → Explain the stack operator valuation context

CHATBOT ACCESS MODEL:
- Public tier: 3 free questions, then invitation key required
- Business tier: Invitation key unlocks full knowledge base & technical deep-dives
- After 3 free questions: kindly let the user know they can sign in with an invitation key to access more tokens
  Say something like: "To continue exploring Scott's full background and technical work, you can request an invitation key at worldseafood@gmail.com"

RESPONSE STYLE:
- Keep responses concise: 2-4 sentences for simple questions, short paragraphs for complex ones
- When a public-tier user is on their last (3rd) question, gently mention the invitation key option
- Always end with a natural follow-up invitation

Always be helpful. If asked something outside CV/professional topics, gently redirect.`;

const buildBusinessSystem = (ragContext = "") => `You are RSE-Business-Assistant, the premium AI advisor for R. Scott Echols' enterprise clients and technical partners.

You have FULL ACCESS to Scott's complete knowledge base.

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
- Phase 1 production stack: Netlify Edge + Cloud Run + ChromaDB + Claude Opus 4.6

PERSONA: Act as Scott's senior technical advisor. Be direct, precise, expert-level.
You can discuss proprietary technical details, architecture decisions, and business strategy.

Always verify the business context. If the query seems unrelated to professional collaboration, ask for clarification.`;

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
  const ip = request.headers.get("x-forwarded-for")?.split(",")[0]?.trim() || "unknown";
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
          "You've reached the 3 free question limit. To continue exploring Scott's full background, SeaTrace architecture, and business solutions, sign in with an invitation key — or email worldseafood@gmail.com to request access to more tokens.",
        tier: "public",
        limit_reached: true,
      }),
      { status: 200, headers: CORS }
    );
  }

  const anthropicKey = Netlify.env.get("ANTHROPIC_API_KEY");
  if (!anthropicKey) {
    return new Response(
      JSON.stringify({ error: "AI service not configured. Please contact the site admin." }),
      { status: 503, headers: CORS }
    );
  }

  // ── RAG retrieval (business tier + Cloud Run, non-blocking) ──
  let ragContext = "";
  const vectorEngineUrl = Netlify.env.get("VECTOR_ENGINE_URL") || "";
  if (vectorEngineUrl) {
    ragContext = await fetchRAGContext(message.trim(), effectiveTier, vectorEngineUrl);
  }
  const ragActive = ragContext.length > 0;

  // ── Build Claude messages ──
  const client = new Anthropic({ apiKey: anthropicKey });
  const messages = [
    ...history.slice(-10).map((m) => ({
      role: m.role as "user" | "assistant",
      content: m.content,
    })),
    { role: "user" as const, content: message.trim() },
  ];

  const systemPrompt = isBusiness
    ? buildBusinessSystem(ragContext)
    : buildPublicSystem(ragContext);

  try {
    const response = await client.messages.create({
      model: "claude-opus-4-6",  // Claude Opus 4.6 — non-negotiable (Roberto's rule)
      max_tokens: isBusiness ? 2048 : 512,
      system: systemPrompt,
      messages,
    });

    const text = response.content[0]?.type === "text" ? response.content[0].text : "";

    return new Response(
      JSON.stringify({
        reply: text,
        tier: effectiveTier,
        tokens_used: response.usage?.output_tokens ?? 0,
        rag_context_used: ragActive,
        answer_source: ragActive
          ? (isBusiness ? "RAG — Business Corpus" : "RAG — CV Corpus")
          : (isBusiness ? "Embedded Knowledge — Business" : "Embedded CV — Public Profile"),
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
    console.error("Claude API error:", errMsg);
    return new Response(
      JSON.stringify({
        error: "I'm having trouble connecting right now. Please try again in a moment.",
      }),
      { status: 502, headers: CORS }
    );
  }
};

export const config = { path: "/api/chat" };
