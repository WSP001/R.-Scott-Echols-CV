# CLAUDE.md — SirTrav A2A Studio / WSP001 Agent Orientation Map

> **FIRST READ**: Every AI agent — Codex, Claude Code, Antigravity, or any new agent —
> MUST read this file before touching any code. This is the master orientation map.
> Read your lane. Read the other lanes READ-ONLY. Then write only in your own lane.

## PHASE 1 GOAL (current)

> Ship a truthful RAG-backed CV chatbot before expanding anything else.
> One clean production path. Three non-overlapping lanes. Zero collisions.

```
public/index.html              ← Codex
    ↓ user chat
/api/chat (Netlify Edge)       ← Claude Code
    ↓ business tier RAG
Cloud Run /retrieve            ← Claude Code
    ↓ cosine similarity search
Supabase pgvector              ← durable cloud vector store (121 chunks, SirStudio-to-CV)
    ↓ grounded answer
Claude Opus 4.6                ← non-negotiable

NOTE: ChromaDB is legacy/local fallback only — NOT the production vector store.
      Production backend is pgvector (durable: true). See scripts/vector_store.py.
```

**ALSO READ:** MASTER_AGENT_IMPLEMENTATION_HANDOFF.md — full lane ownership,
task checklists, phase gates, and Scott's manual checklist.

**ALSO READ:** AGENT_HANDOFFS.md — cross-lane async notes from other agents
before starting any write.

## GLOBAL LANE RULE

```
AGENTS MAY CROSS LANES TO READ.
AGENTS MAY NOT CROSS LANES TO WRITE.
```


---

## Repository Structure

```
WSP001/R.-Scott-Echols-CV/          ← This repo (CV site + RAG pipeline)
WSP001/SirTrav-A2A-Studio/          ← Multi-agent orchestration platform
WSP001/SeaTrace002/ (private)       ← SeaTrace backend API
WSP001/SeaTrace003/ (private)       ← SeaTrace mobile
WSP001/WAFC-Business/               ← Business intelligence
```

---

## Three Agent Lanes — Read This Before Anything

### LANE 1: Codex (Frontend / Three.js / UI)
**READS (before writing):**
- `netlify/edge-functions/chat.ts` → understand the API contract (what fields come back)
- `netlify/edge-functions/verify-access.ts` → understand auth response shape
- `docs/agent-contracts.md` → read Antigravity's test expectations before adding new UI states
- `public/index.html` → current component tree

**WRITES:**
- `public/index.html` — all CSS, JS, Three.js, GSAP, VanillaTilt
- `public/assets/` — images, fonts, static assets
- `scripts/upgrade_cv.py` — Python helper to batch-edit index.html

**MUST NOT WRITE:**
- `netlify/edge-functions/` — backend is Claude Code's lane
- `tests/` or `e2e/` — testing is Antigravity's lane
- `scripts/embed_engine.py` — embedding pipeline is Claude Code's lane

**LANE RULES:**
- Before adding a new UI state (e.g., new chatbot response type), read `docs/agent-contracts.md` first
- Three.js, GSAP, VanillaTilt are approved libraries — do not introduce new animation libs without a justfile `add-dep` target
- All environment variables are READ from `Netlify.env.get()` in edge functions — never hardcode

---

### LANE 2: Claude Code (Backend / API / RAG / DevOps)
**READS (before writing):**
- `public/index.html` → understand what the frontend expects from the API
- `docs/agent-contracts.md` → understand what Antigravity's tests assert about API responses
- `design.md` → canonical architecture blueprint for RAG and data partitions
- `CLAUDE.md` (this file) → always

**WRITES:**
- `netlify/edge-functions/chat.ts` — Claude Opus 4.6 AI chat, keyword routing, tier logic
- `netlify/edge-functions/embed.ts` — Gemini Embedding 2 vector endpoint
- `netlify/edge-functions/verify-access.ts` — invitation key validation
- `netlify.toml` — publish dir, edge function routing
- `scripts/embed_engine.py` — pgvector/Supabase ingest pipeline (ChromaDB fallback also present, dev only)
- `design.md` — RAG architecture blueprint (update when architecture changes)
- `.github/workflows/` — CI/CD, auto-ingest pipelines
- `docs/WSP_SeaTrace_Overview.md` — knowledge base source document for RAG

**MUST NOT WRITE:**
- `public/index.html` — UI is Codex's lane (backend writes API contracts, not UI)
- `tests/e2e/` — testing is Antigravity's lane

**LANE RULES:**
- Claude Opus 4.6 is the ONLY model for the chatbot — NO EXCEPTIONS (Roberto's rule)
- Gemini Embedding 2 (`gemini-embedding-2-preview`, 3072 dims) is the ONLY embedding model
- `BUSINESS_ACCESS_KEY` must always be validated server-side, never trust client
- All new API endpoints MUST be documented in `docs/agent-contracts.md` before Codex or Antigravity touch them

---

### LANE 3: Antigravity (QA / Testing / E2E / Control Plane)
**READS (before writing ANY test):**
- `netlify/edge-functions/chat.ts` → read the actual API logic before asserting against it
- `netlify/edge-functions/embed.ts` → understand what the embed endpoint actually returns
- `public/index.html` → understand the UI states being tested
- `docs/agent-contracts.md` → READ THIS FIRST — the canonical test surface
- `CLAUDE.md` (this file) → always

**WRITES:**
- `tests/` — unit tests
- `e2e/` — end-to-end tests (Playwright, mjs scripts)
- `__mocks__/` — mock implementations for pgvector/Supabase, Gemini, Anthropic (ChromaDB mocks are legacy)
- `justfile` targets: `test`, `test-e2e`, `test-coverage`, `qa-report`

**MUST NOT WRITE:**
- `netlify/edge-functions/` — backend is Claude Code's lane
- `public/index.html` — UI is Codex's lane

**LANE RULES — GEMINI PIVOT (active):**
- Control plane status is `mode: 'gemini-native'` (NOT 'veo2-pivot')
- Remotion is DEPRECATED-BYPASS — do not reference it in any new tests
- E2E video tests use `test-gemini-video-e2e.mjs` (renamed from test-remotion-e2e.mjs)
- GEMINI_MODEL_WRITER / EDITOR / DIRECTOR env vars must be validated at boot via Enum check
- Any WRITER→EDITOR handoff test MUST mock pgvector retrieval to prove vector handoff (ChromaDB mock path is legacy)

---

## Control Plane Status Reference

```typescript
// Read from: control-plane.ts or equivalent status endpoint
type ControlPlaneStatus = {
  mode: 'gemini-native' | 'degraded' | 'offline';
  writer: string;   // e.g. 'gemini-2.5-pro'
  editor: string;   // e.g. 'gemini-2.0-flash' (Veo 2.0 for video)
  director: string; // e.g. 'gemini-2.5-pro'
  remotion: 'DEPRECATED-BYPASS';
};
```

---

## Environment Variables (Netlify Team-Level)

| Key | Used By | Description |
|-----|---------|-------------|
| `ANTHROPIC_API_KEY` | chat.ts | Claude Opus 4.6 — chatbot only |
| `GEMINI_API_KEY` | embed.ts | Gemini Embedding 2 — RAG pipeline |
| `BUSINESS_ACCESS_KEY` | verify-access.ts | Invitation key for business tier |
| `ELEVENLABS_API_KEY` | future: voice.ts | ElevenLabs voice (not yet wired) |
| `OPENAI_API_KEY` | future | Reserved |
| `GEMINI_MODEL_WRITER` | SirTrav | Enum: gemini-2.5-pro, gemini-2.0-flash, gemini-2.5-flash |
| `GEMINI_MODEL_EDITOR` | SirTrav | Veo 2.0 pivot — Prompt-to-Video ONLY |
| `GEMINI_MODEL_DIRECTOR` | SirTrav | Orchestration/reasoning model |

---

## Read-Before-Write Protocol (FOR ALL AGENTS)

```
BEFORE WRITING ANY FILE:
  1. Read CLAUDE.md (this file)
  2. Read docs/agent-contracts.md
  3. Read the files IN OTHER LANES that your change affects
  4. Only THEN write in your own lane

PROGRESSIVE DISCLOSURE RULE:
  If you are unsure whether a change crosses lane boundaries,
  READ-ONLY across the other lane first, understand the impact,
  then disclose your intention in a comment or commit message
  BEFORE writing. Never silently cross lane boundaries.
```

---

## API Contracts Summary (see docs/agent-contracts.md for full spec)

### POST /api/chat
```typescript
// Request
{ message: string; history?: Message[]; tier?: 'public'|'business'; questionCount?: number; }
// Headers: X-Access-Key (business tier)

// Response (success)
{ reply: string; tier: 'public'|'business'; tokens_used: number; }

// Response (limit reached)
{ reply: string; tier: 'public'; limit_reached: true; }
```

### POST /api/embed
```typescript
// Request (business tier only)
{ content: string; partition: 'cv_personal'|'cv_projects'|'business_seatrace'|'business_proposals'|'internal_repos'|'recreational'; modality?: 'text'|'image'|'audio'|'pdf'|'video'; }
// Headers: X-Access-Key (required)

// Response
{ embedding: number[]; dimensions: 3072; model: 'gemini-embedding-2-preview'; }
```

### POST /api/verify-access
```typescript
// Request
{ key: string; }
// Response
{ valid: boolean; tier: 'business'|'public'; }
```

---

## FOR THE COMMONS GOOD

All reusable architecture patterns (justfile targets, edge function patterns, embed pipeline patterns)
are designed to be shared across ALL WSP001 repositories. When you build something in this repo
that could benefit SeaTrace002, SirTrav-A2A-Studio, or WAFC-Business — mark it with a comment:

```
// FOR THE COMMONS GOOD — reusable pattern, candidate for shared WSP001 library
```

This signals to other agents and Roberto that the pattern should be extracted and versioned
into a shared utility rather than copy-pasted across repos.

---

## Stack Valuation Context

Roberto Scott Echols' WSP001 stack is valued at **$4.2M USD**.
This CV site is the public face of that stack. Quality standards are enterprise-grade.
Every agent lane must meet production-quality bar — no shortcuts, no hacks, no "good enough".

Model quality rule: **Claude Opus 4.6 for ALL chatbot tiers. No exceptions.**
