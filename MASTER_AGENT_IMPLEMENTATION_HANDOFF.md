# MASTER AGENT IMPLEMENTATION HANDOFF
# WSP001 / R.-Scott-Echols-CV — Production Stabilization: Phase 1
# FOR THE COMMONS GOOD — this file is the repo's operating constitution

---

## PHASE 1 GOAL (read this first, every agent)

> Ship a truthful RAG-backed CV chatbot before expanding anything else.
> One clean production path. Three non-overlapping lanes. Zero collisions.

```
public/index.html          ← Codex owns
    ↓  (user chat)
/api/chat (Netlify Edge)   ← Claude Code owns
    ↓  (retrieval call)
api_server.py (Cloud Run)  ← Claude Code owns
    ↓  (vector search)
ChromaDB / pgvector        ← Claude Code owns
    ↓  (grounded answer)
Claude Opus 4.6            ← Claude Code owns (model is non-negotiable)
```

Nothing ships to production that breaks this path.
No agent adds features that scatter this shape.

---

## GLOBAL LANE RULE (applies to all agents, always)

```
AGENTS MAY CROSS LANES TO READ.
AGENTS MAY NOT CROSS LANES TO WRITE.
```

Before writing ANYTHING:
1. Run `just orient` — read CLAUDE.md
2. Run `just contracts` — read docs/agent-contracts.md
3. Run `just handoffs` — read AGENT_HANDOFFS.md (cross-lane notes from other agents)
4. Only then write in your own lane

Progressive disclosure: if your change affects another lane, leave a note in
AGENT_HANDOFFS.md BEFORE making the change. Do not surprise your lane-mates.

---

## SCOTT LANE (human owner — final authority)

**Scott owns:**
- All Netlify environment variables (set in Netlify UI only, never committed)
- All Cloud Run secrets (set in Google Cloud console)
- Invitation key policy (who gets BUSINESS_ACCESS_KEY)
- Final publish decisions (merge to main = live site)
- Business-tier access policy and pricing
- Phase gate approvals (Scott says "go" before each phase advances)

**Scott's manual checklist (run before any major deploy):**
```
□ ANTHROPIC_API_KEY is set in Netlify team env vars
□ GEMINI_API_KEY is set in Netlify team env vars
□ BUSINESS_ACCESS_KEY is set and not expired
□ ELEVENLABS_API_KEY is set (for future voice)
□ VECTOR_ENGINE_URL is set (points to Cloud Run retrieval API)
□ Cloud Run service is healthy (check: just cloud-status)
□ Rate limiting is active on /api/chat (check netlify.toml)
□ Site loads clean at robertoscottecholscv.netlify.app
□ Chat sends and receives a response (public tier, Q1)
□ Business gate appears at Q3 (invitation key prompt)
□ Business key unlocks successfully
```

---

## CLAUDE CODE LANE

**Mission:** Own the production data path. Edge functions stay clean routers.
Real retrieval lives in Cloud Run. Every API contract change is documented first.

**Owns (write access):**
```
netlify/edge-functions/chat.ts
netlify/edge-functions/embed.ts
netlify/edge-functions/verify-access.ts
netlify.toml
scripts/api_server.py        ← Cloud Run retrieval service (FastAPI)
scripts/embed_engine.py      ← ChromaDB ingest + query
scripts/Dockerfile           ← Cloud Run container
scripts/deploy-cloud-run.ps1 ← Windows deploy script
design.md
docs/WSP_SeaTrace_Overview.md
docs/agent-contracts.md      ← update before changing any API shape
CLAUDE.md
.github/workflows/
```

**READ before writing (cross-lane read-only):**
```
public/index.html            → what does the frontend expect from /api/chat?
AGENT_HANDOFFS.md            → any pending notes from Codex or Antigravity?
```

**Phase 1 task list for Claude Code:**
- [ ] Add `VECTOR_ENGINE_URL` env var read to chat.ts
- [ ] Add retrieval call in chat.ts: when business tier, POST to `$VECTOR_ENGINE_URL/retrieve`
- [ ] Build scripts/api_server.py (FastAPI, /retrieve endpoint, ChromaDB search)
- [ ] Build scripts/Dockerfile
- [ ] Build scripts/deploy-cloud-run.ps1
- [ ] Add rate limiting rules to netlify.toml (`/api/chat` → 20 req/min public, 100 req/min business)
- [ ] Add X-RateLimit headers to chat.ts response
- [ ] Update docs/agent-contracts.md with /retrieve endpoint shape

**Validation gate (Claude Code must pass before merging):**
```
just backend-validate-models   → all GEMINI_MODEL_* vars pass Enum check
just backend-check-env         → all required env vars present
curl -X POST /api/chat -d '{"message":"Who is RSE?","tier":"public"}' → 200 OK
curl -X POST $VECTOR_ENGINE_URL/retrieve -d '{"query":"SeaTrace"}' → [{content, score}]
just ingest-all                → ChromaDB populated from docs/
```

---

## CODEX LANE

**Mission:** Own the full visual experience. The frontend is the first impression.
3D, animation, glassmorphism, repo cards — this is Codex's creative territory.

**Owns (write access):**
```
public/index.html              ← all CSS + JS + Three.js + GSAP inline
public/assets/                 ← images, logos, emblems, fonts
scripts/upgrade_cv.py          ← Python batch-edit helper for index.html
```

**READ before writing (cross-lane read-only):**
```
docs/agent-contracts.md        → what API fields does the chat UI rely on?
AGENT_HANDOFFS.md              → any backend changes affecting UI state?
netlify/edge-functions/chat.ts → what does limit_reached: true look like?
```

**Phase 1 task list for Codex:**
- [ ] Add `data-testid` attributes to all chat UI elements (see agent-contracts.md UI State table)
- [ ] Add `VECTOR_ENGINE_URL` status indicator to chat panel (shows "RAG Active" when /api/retrieve is live)
- [ ] 3D logo/emblem animation: each repo card gets its own animated emblem (glassmorphism + CSS orbit)
- [ ] Per-business-symbol 3D treatment: plug new logo into existing harness, emblem swaps without rebuilding
- [ ] Mobile polish pass: hero + chat panel responsive at 375px
- [ ] Repo showcase grid: 8 featured repos with glassmorphism cards + per-repo emblem slots
- [ ] Accessibility pass: aria-labels, keyboard nav for chat input

**Emblem/Logo Harness System (Codex's key innovation):**
The goal is a plug-and-play emblem harness:
```
1. One CSS/Three.js harness that handles all 3D orbit + glow effects
2. Emblem slot accepts any logo image or SVG
3. To add new persona: swap emblem src, harness relearns the new shape
4. SeaTrace emblem, WSP logo, SirTrav emblem — all plug into same harness
5. Green = proven working harness | swap emblem | plug back in
```
This is the "FOR THE COMMONS GOOD" frontend pattern — build it once, reuse across all WSP001 sites.

**Validation gate (Codex must pass before merging):**
```
data-testid="chat-input" exists in DOM
data-testid="chat-response" exists in DOM
data-testid="question-count" exists in DOM
data-testid="access-gate" appears after Q3
Three.js orbit rings render at 60fps (check Chrome DevTools Performance)
Mobile screenshot at 375px: no horizontal scroll, chat panel usable
```

---

## ANTIGRAVITY LANE

**Mission:** Own proof-of-work. Nothing is "done" until Antigravity says it works.
Read both other lanes before writing any test. Mock external services — never call real APIs in tests.

**Owns (write access):**
```
tests/                         ← unit tests
e2e/                           ← Playwright end-to-end tests
__mocks__/                     ← mock ChromaDB, Gemini, Anthropic, Cloud Run
scripts/smoke-test.mjs         ← live production smoke test (safe, read-only)
```

**READ before writing ANY test (cross-lane read-only):**
```
AGENT_HANDOFFS.md              → read this FIRST — any pending lane changes?
docs/agent-contracts.md        → read this SECOND — what are the actual contracts?
netlify/edge-functions/chat.ts → read the actual logic before asserting against it
public/index.html              → read the UI states before writing Playwright selectors
```

**Phase 1 task list for Antigravity:**
- [ ] Create `__mocks__/anthropic.ts` — mock Claude response (never call real API in tests)
- [ ] Create `__mocks__/chromadb.ts` — mock ChromaDB collection with 3 test chunks
- [ ] Create `tests/chat.test.mjs` — unit test: limit_reached triggers at questionCount >= 3
- [ ] Create `tests/chat.test.mjs` — unit test: business tier bypasses limit
- [ ] Create `tests/vector-handoff.test.mjs` — mock WRITER→EDITOR handoff (3072-dim vector roundtrip)
- [ ] Create `e2e/smoke-test.mjs` — live production smoke: GET site, POST /api/chat Q1, assert reply
- [ ] Create `e2e/test-gemini-video-e2e.mjs` — Gemini pivot path test (mode: gemini-native)
- [ ] Create `scripts/smoke-test.mjs` — safe, idempotent production check (no writes, no business key)

**Gemini Pivot — Antigravity's specific rules (active):**
```
mode: 'gemini-native'           ← control plane status, ALWAYS this string
remotion: 'DEPRECATED-BYPASS'  ← never reference Remotion in new tests
GEMINI_MODEL_EDITOR             ← Veo 2.0, Prompt-to-Video ONLY
test file name: test-gemini-video-e2e.mjs (NOT test-remotion-e2e.mjs)
ChromaDB mock REQUIRED in vector handoff test
```

**Validation gate (Antigravity must pass before any Phase 2 work begins):**
```
just test              → all unit tests pass
just test-e2e-chat     → live smoke: /api/chat returns 200 with reply field
just test-vector-handoff → mock WRITER→EDITOR handoff passes
just qa-report         → no failures, all gates green
```

---

## SHARED ARCHITECTURE CONTRACT (all lanes)

### Production Stack (Phase 1)
```
Layer           | Technology              | Owner
─────────────────────────────────────────────────────
UI + 3D         | Three.js, GSAP, Lenis   | Codex
CDN + Deploy    | Netlify (main branch)   | Scott
Edge Routing    | Netlify Edge Functions  | Claude Code
AI Chat         | Claude Opus 4.6         | Claude Code (non-negotiable)
Embeddings      | Gemini Embedding 2      | Claude Code (3072 dims)
Vector Retrieval| FastAPI + ChromaDB      | Claude Code
Container       | Cloud Run (scales to 0) | Claude Code
Testing         | Node test runner / mjs  | Antigravity
CI/CD           | GitHub Actions          | Claude Code
Env Vars        | Netlify Team + GCP      | Scott
```

### Netlify Edge Function Constraints (everyone must know this)
```
Code size:   20 MB max
Memory:      512 MB across all edge functions
CPU time:    50 ms per request
→ Edge functions are for routing, auth, and rate limiting ONLY
→ Heavy vector search lives in Cloud Run, not in edge functions
→ chat.ts calls Cloud Run via HTTP — it does NOT run ChromaDB inline
```

### Environment Variables (full list — Scott sets all of these)
```
ANTHROPIC_API_KEY      → chat.ts (Claude Opus 4.6)
GEMINI_API_KEY         → embed.ts (Gemini Embedding 2)
BUSINESS_ACCESS_KEY    → verify-access.ts (invitation key)
ELEVENLABS_API_KEY     → future voice.ts (not yet wired)
OPENAI_API_KEY         → reserved
VECTOR_ENGINE_URL      → chat.ts (Cloud Run retrieval API URL) ← ADD THIS
GEMINI_MODEL_WRITER    → SirTrav (gemini-2.5-pro default)
GEMINI_MODEL_EDITOR    → SirTrav (gemini-2.0-flash, Veo 2.0)
GEMINI_MODEL_DIRECTOR  → SirTrav (gemini-2.5-pro default)
```

### Phase Gates (Scott approves each before next phase begins)

```
PHASE 1 GATE — CV RAG Bridge (current)
  ✓ Beautiful frontend loads with 3D hero
  ✓ /api/chat returns Claude Opus 4.6 answers from embedded CV data
  ✓ 3-question free tier enforced client + server side
  ✓ Business key unlocks full tier
  □ Cloud Run /retrieve endpoint live and healthy
  □ chat.ts calls Cloud Run for business-tier RAG context
  □ Rate limiting active on /api/chat
  □ All Antigravity tests pass
  → Scott approves → Phase 2 begins

PHASE 2 GATE — Repo Showcase + Emblem Harness
  □ 8 repo cards with glassmorphism + per-repo emblems
  □ Emblem harness plug-and-play (swap logo, keep 3D harness)
  □ Mobile fully responsive
  □ Antigravity Playwright E2E passes
  → Scott approves → Phase 3 begins

PHASE 3 GATE — Gemini Routing + Video Pivot
  □ GEMINI_MODEL_* env var routing live
  □ Veo 2.0 pipeline replacing Remotion (DEPRECATED-BYPASS)
  □ test-gemini-video-e2e.mjs passes with mock ChromaDB
  □ Antigravity smoke test covers video path
  → Scott approves → Phase 4 begins
```

---

## WHAT NOT TO DO (Phase 1 blockers — do not start these yet)

```
✗ Dynamic Gemini capability routing       → Phase 3
✗ Veo pivot / Remotion replacement        → Phase 3
✗ Full agent-wide justfile polymorphism   → later
✗ Multi-user vector persistence           → Phase 2+
✗ ElevenLabs voice integration            → Phase 3
✗ Linear / project management wiring     → Phase 3
✗ Neon extension (not used by CV app)     → remove later
```

---

## FOR THE COMMONS GOOD

This file and the patterns inside it (lane contracts, phase gates, emblem harness concept,
validation checklists) are designed to be replicated across ALL WSP001 repos.

When you build something reusable here, mark it:
```
// FOR THE COMMONS GOOD — extract to shared WSP001 library
```

Repos that will inherit this pattern next:
- WSP001/SirTrav-A2A-Studio
- WSP001/SeaTrace002
- WSP001/WAFC-Business
