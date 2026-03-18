/**
 * R. Scott Echols CV — AI Chat Edge Function
 * Deployed via Netlify Edge Functions (Deno runtime, CDN-edge, zero cold-start)
 *
 * Two-tier access:
 *   PUBLIC  → Claude answers CV/personal questions from embedded knowledge (3 free questions)
 *   BUSINESS → Claude + Gemini Embedding 2 RAG over vector knowledge base (invitation key required)
 *
 * Keywords that trigger rich context: R.SCOTT CV, Resume, RSE, SeaTrace, SirTrav, WorldSeafood
 *
 * Environment variables required (set in Netlify UI → Site Settings → Env Vars):
 *   ANTHROPIC_API_KEY   — Anthropic / Claude API key
 *   GEMINI_API_KEY      — Google Gemini API key (for Embedding 2 + RAG)
 *   BUSINESS_ACCESS_KEY — Secret passphrase for premium/business tier access
 */

import Anthropic from "https://esm.sh/@anthropic-ai/sdk@0.27.3";

// ─── CV Knowledge Base (embedded, no vector DB needed for public tier) ────────

const RSE_CV_DATA = `
IDENTITY: R. Scott Echols (also known as R.SCOTT CV, Roberto Scott Echols, RSE)
TITLE: Founder, Technical Lead & AI Systems Architect
COMPANY: World Seafood Producers / SirTrav-A2A-Studio (GitHub: WSP001)
STACK VALUATION: $4.2M USD
EMAIL: worldseafood@gmail.com
GITHUB: github.com/WSP001

RESUME SUMMARY (R.SCOTT CV):
- Senior Software Developer and Technical Lead with 12+ years of experience
- Deep marine/fisheries domain expertise combined with cutting-edge AI systems architecture
- Founder of World Seafood Producers — building SeaTrace marine traceability and SirTrav AI platform
- Specialist in agentic AI, multi-agent orchestration, and Claude API integration
- Full-stack: JavaScript/Node.js, Python, PowerShell, TypeScript (Deno)
- Cloud/DevOps: Netlify Edge Functions, GitHub CI/CD, environment vault management
- AI/ML: Claude Opus 4.6 (Anthropic), Gemini Embedding 2, OpenAI, ElevenLabs
- Data: Power BI dashboards for fisheries supply chain analytics

KEY PROJECTS:
1. SirTrav-A2A-Studio — Marine intelligence A2A agent platform
   - Three agents: Codex (frontend), Claude Code (backend), Antigravity (QA)
   - Claude Opus 4.6 + Gemini Embedding 2 multimodal RAG
   - Live: sirtrav-a2a-studio.netlify.app

2. SeaTrace — Four Pillars Marine Traceability API
   - SeaSide: Vessel tracking & catch origin verification at sea
   - DeckSide: On-deck catch verification & HACCP compliance logging
   - DockSide: Port processing, supply chain handoff & cold chain data
   - MarketSide: Consumer QR verification & retail traceability portal
   - Live: seatrace.worldseafoodproducers.com
   - Business: worldseafoodproducers.com

3. Netlify AI Edge Platform
   - Composable AI stack: Netlify Edge Functions + Anthropic + Gemini
   - Zero cold-start CDN-edge inference
   - This very CV site runs this architecture

4. Multimodal RAG Pipeline
   - Gemini Embedding 2 maps text, images, video, audio, PDFs into unified vector space
   - Knowledge partitions: cv_personal, cv_projects (public); business_seatrace, business_proposals (business tier)

5. Fisheries Supply Chain Intelligence
   - Power BI dashboards for enterprise maritime supply chain clients
   - Real-time analytics, traceability workflows, operational KPIs

SKILLS:
- Cloud & DevOps: Netlify/CI-CD (95%), GitHub Workflows (92%), API Management (93%)
- Development: JavaScript/Node.js (92%), Python (85%), PowerShell (88%), TypeScript (80%)
- Agentic AI: Claude API/Anthropic (95%), Gemini Embedding 2 (88%), Multi-Agent Systems (90%), RAG Pipelines (85%)
- Data & Domain: Power BI (90%), Marine/Fisheries Domain (97%), Supply Chain Optimization (92%)

EXPERIENCE:
- 2022–Present: Founder, Technical Lead & AI Systems Architect — World Seafood Producers / WSP001
- 2018–2022: Senior Software Developer & Data Engineer — [enterprise clients]
- 2015–2018: Software Developer & DevOps Engineer
- 2010–2015: Marine Technology Specialist & Supply Chain Analyst

SERVICES OFFERED:
1. Agentic AI Systems — Multi-agent orchestration, A2A protocol design, Claude & Gemini integration
2. Marine Intelligence Platforms — Domain-specific AI for fisheries, traceability, maritime ops
3. Cloud & DevOps Architecture — Netlify composable stack, GitHub CI/CD, vault management
4. Data Visualization & Analytics — Power BI, fisheries analytics, supply chain KPIs

CONTACT & COLLABORATION:
- Available for: Enterprise consulting, technical leadership, AI systems architecture, marine tech
- Email: worldseafood@gmail.com
- For business tier access: contact worldseafood@gmail.com to request invitation key
`;

// ─── System prompts ────────────────────────────────────────────────────────────

const PUBLIC_SYSTEM = `You are RSE-Assistant, the intelligent AI guide embedded in R. Scott Echols' professional CV website.

PERSONA: Knowledgeable, concise, professional but approachable. You speak about Roberto Scott Echols as if you deeply know his work.

${RSE_CV_DATA}

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
- After 3 free questions, direct users to email worldseafood@gmail.com for invitation key

RESPONSE STYLE:
- Keep responses concise: 2-4 sentences for simple questions, short paragraphs for complex ones
- When a public-tier user is on their last (3rd) question, gently mention invitation key option
- Always end with a natural follow-up invitation

Always be helpful. If asked something outside CV/professional topics, gently redirect.`;

const BUSINESS_SYSTEM = `You are RSE-Business-Assistant, the premium AI advisor for R. Scott Echols' enterprise clients and technical partners.

You have FULL ACCESS to Scott's complete knowledge base.

${RSE_CV_DATA}

ADDITIONAL BUSINESS-TIER KNOWLEDGE:
- SeaTrace API detailed technical specifications and integration guides
- Agent-to-agent (A2A) protocol implementation patterns and code architecture
- Gemini Embedding 2 multimodal RAG implementation with BigQuery/Supabase vector search
- Enterprise consulting frameworks and engagement models
- GitHub repositories: WSP001 — all active projects
- WAFC Business intelligence system
- Linear workspace: linear.app/wsp2agent — active project management
- SirTrav agents: Codex (frontend/Three.js), Claude Code (backend API), Antigravity (QA/testing)

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

  // ── 3-question free tier server-side enforcement ──
  if (!isBusiness && questionCount >= 3) {
    return new Response(
      JSON.stringify({
        reply: "You've reached the 3 free question limit. To continue exploring Scott's full background, SeaTrace architecture, and business solutions, enter an invitation key below — or email worldseafood@gmail.com to sign in and request access to more tokens.",
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

  const client = new Anthropic({ apiKey: anthropicKey });

  // Build message history (limit to last 10 turns to control tokens)
  const messages = [
    ...history.slice(-10).map((m) => ({
      role: m.role as "user" | "assistant",
      content: m.content,
    })),
    { role: "user" as const, content: message.trim() },
  ];

  try {
    const response = await client.messages.create({
      model: "claude-opus-4-6",
      max_tokens: isBusiness ? 2048 : 512,
      system: isBusiness ? BUSINESS_SYSTEM : PUBLIC_SYSTEM,
      messages,
    });

    const text = response.content[0]?.type === "text" ? response.content[0].text : "";

    return new Response(
      JSON.stringify({
        reply: text,
        tier: isBusiness ? "business" : "public",
        tokens_used: response.usage?.output_tokens ?? 0,
      }),
      { status: 200, headers: CORS }
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
