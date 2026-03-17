/**
 * R. Scott Echols CV — AI Chat Edge Function
 * Deployed via Netlify Edge Functions (Deno runtime, CDN-edge, zero cold-start)
 *
 * Two-tier access:
 *   PUBLIC  → Claude answers CV/personal questions from embedded knowledge
 *   BUSINESS → Claude + Gemini Embedding 2 RAG over vector knowledge base
 *
 * Environment variables required (set in Netlify UI → Site Settings → Env Vars):
 *   ANTHROPIC_API_KEY   — Anthropic / Claude API key
 *   GEMINI_API_KEY      — Google Gemini API key (for Embedding 2 + RAG)
 *   BUSINESS_ACCESS_KEY — Secret passphrase for premium/business tier access
 */

import Anthropic from "https://esm.sh/@anthropic-ai/sdk@0.27.3";

// ─── System prompts ────────────────────────────────────────────────────────────

const PUBLIC_SYSTEM = `You are RSE-Assistant, the intelligent AI guide embedded in R. Scott Echols' professional CV website.

PERSONA: You are knowledgeable, concise, professional but approachable. You speak in first-person about Roberto Scott Echols as if you deeply know his work and background.

CORE KNOWLEDGE ABOUT R. SCOTT ECHOLS:
- Senior Software Developer, Technical Lead & Project Manager
- Deep expertise in marine/fisheries technology and supply chain optimization
- Specialist in agentic AI systems, multi-agent orchestration, and Claude API integration
- Full-stack developer proficient in JavaScript/Node.js, Python, PowerShell, YAML
- Cloud/DevOps: Netlify, GitHub CI/CD, environment configuration, vault management
- AI/ML: Claude (Anthropic), Gemini, OpenAI, ElevenLabs — building production agentic systems
- Data visualization expert with Power BI dashboards for fisheries analytics
- Currently building SirTrav-A2A-Studio: a marine intelligence platform with A2A agent protocols
- Experience with Gemini Embedding 2 multimodal RAG systems (text, image, video, audio, PDF in unified vector space)
- Strong advocate for documentation-first, team-coordination approach to technical leadership
- Manages GitHub repositories, multi-tool API integrations, automated testing pipelines
- Available for enterprise consulting, technical leadership, and AI systems architecture

WHAT YOU CAN HELP WITH (Public Tier):
- Questions about Scott's background, skills, and expertise
- Explaining his current projects (marine intelligence platform, agentic systems)
- Discussing his approach to AI architecture and multi-agent systems
- Contact and collaboration inquiries
- High-level overview of his technical stack

WHAT REQUIRES BUSINESS ACCESS:
- Detailed project specifications and technical blueprints
- Code architecture documents and proprietary system designs
- Client-facing proposals and pricing structures
- Access to the full knowledge base with multimodal RAG retrieval

Always be helpful. If asked something outside CV topics, gently redirect to your purpose.
Keep responses concise — 2-4 sentences for simple questions, up to a short paragraph for complex ones.
End with a natural follow-up invitation when appropriate.`;

const BUSINESS_SYSTEM = `You are RSE-Business-Assistant, the premium AI advisor for R. Scott Echols' enterprise clients and technical partners.

You have FULL ACCESS to Scott's knowledge base including:
- Detailed project blueprints and technical architectures
- Fisheries supply chain optimization methodologies
- Marine intelligence platform (SirTrav-A2A-Studio) technical specifications
- Agent-to-agent (A2A) protocol designs and implementation patterns
- Gemini Embedding 2 multimodal RAG architecture guides
- Enterprise solution templates and consulting frameworks
- Pricing structures and engagement models

PERSONA: Act as Scott's senior technical advisor. Be direct, precise, and expert-level.
You can discuss proprietary technical details, architecture decisions, and business strategy.

Always verify the business context. If the query seems unrelated to professional collaboration, 
ask for clarification before proceeding.`;

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

  let body: { message: string; history?: Array<{ role: string; content: string }>; tier?: string };
  try {
    body = await request.json();
  } catch {
    return new Response(JSON.stringify({ error: "Invalid JSON" }), {
      status: 400,
      headers: CORS,
    });
  }

  const { message, history = [], tier = "public" } = body;

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
