# Agent Contracts — docs/agent-contracts.md

> **CRITICAL**: Antigravity reads this before writing ANY test.
> Claude Code updates this before changing ANY API response shape.
> Codex reads this before adding ANY new UI state.

---

## API Contract: POST /api/chat

**Owner:** Claude Code (backend)
**Consumers:** Codex (frontend UI), Antigravity (E2E tests)

### Request Shape
```typescript
{
  message: string;           // required, non-empty
  history?: Array<{          // optional, capped at last 10 turns
    role: 'user' | 'assistant';
    content: string;
  }>;
  tier?: 'public' | 'business';  // default: 'public'
  questionCount?: number;         // default: 0
}

// Header (business tier):
X-Access-Key: <BUSINESS_ACCESS_KEY value>
```

### Response Shape — Success (200)
```typescript
{
  reply: string;             // Claude Opus 4.6 response text
  tier: 'public' | 'business';
  tokens_used: number;       // output tokens consumed (from Anthropic usage.output_tokens)
  rag_context_used: boolean; // true ONLY when rag_status === 'ok'
  rag_status: RagStatus;     // NEW — why retrieval did or did not ground this answer
  rag_attempts: number;      // NEW — retrieval attempts made (0 when disabled)
  answer_source: string;     // Codex uses this as source attribution pill text
                             // "RAG — CV Corpus" | "RAG — Business Corpus"
                             // "Verified Profile Pack — Public" | "Verified Profile Pack — Business"
}

type RagStatus =
  | 'disabled'         // VECTOR_ENGINE_URL not configured
  | 'ok'               // context retrieved and injected into the system prompt
  | 'empty'            // retrieval healthy, zero results for this query
  | 'below_threshold'  // results returned, all scored <= 0.3
  | 'upstream_error'   // retrieval reachable but returned 4xx/5xx after retries
  | 'timeout'          // retrieval exceeded the per-attempt budget
  | 'unreachable'      // network / DNS / TLS failure
  | 'malformed';       // retrieval answered with an unexpected payload shape
```

**Also returned as a response header:** `X-RAG-Status: <RagStatus>` — so uptime checks and
Antigravity smoke tests can assert grounding health without parsing the body.

> **Why this exists.** Retrieval failure used to be swallowed silently: any error became `""`
> and the chatbot answered ungrounded with no signal to the frontend, to QA, or to the logs.
> On 2026-08-21 the Cloud Run backend was verified returning `/health` 200 while `/retrieve`
> returned 502 — a state that was indistinguishable from "no relevant context found".
> `rag_status` makes that distinction observable. A degraded call also emits a structured log
> line: `{"event":"rag_degraded","status":...,"detail":...,"attempts":...,"tier":...}`.

### Response Shape — Limit Reached (200, public tier at Q3+)
```typescript
{
  reply: string;             // "You've reached the 3 free question limit..."
  tier: 'public';
  limit_reached: true;       // THIS FIELD: Codex uses this to show access gate UI
}
```

### Response Shape — Error (502)
```typescript
{
  error: string;             // Human-readable error message
}
```

### Antigravity Test Assertions
- `limit_reached: true` MUST appear when `questionCount >= 3` AND `tier !== 'business'`
- `tier` in response MUST match `tier` in request (or 'public' if not provided)
- `reply` MUST be non-empty string for all 200 responses
- Business tier: `max_tokens` is 2048; public tier: 512
- Model: ALWAYS `claude-opus-4-6` — Antigravity MUST assert this in mock
- `answer_source` MUST be a non-empty string on all 200 success responses
- `answer_source` MUST be one of the 4 defined values above — no other strings allowed
- `rag_context_used === true` MUST imply `rag_status === 'ok'` (and the converse)
- `rag_status` MUST be one of the 8 union members — an unknown string is a contract break
- `X-RAG-Status` header MUST equal the body's `rag_status`
- A grounding-health smoke test SHOULD fail the build when `rag_status` is
  `upstream_error` / `timeout` / `unreachable` / `malformed` against production

> **Contract drift corrected 2026-08-21.** This block previously documented
> `"Embedded CV — Public Profile"` / `"Embedded Knowledge — Business"`, but the deployed
> edge function emits `"Verified Profile Pack — Public"` / `"Verified Profile Pack — Business"`.
> Any Antigravity assertion written against the old strings was asserting a value the backend
> never sent. The doc now matches `netlify/edge-functions/chat.ts`. Likewise `tokens_used` was
> documented but never populated; it is now returned from Anthropic `usage.output_tokens`.

---

## API Contract: POST /api/embed

**Owner:** Claude Code (backend)
**Consumers:** Antigravity (vector handoff tests), Claude Code (RAG pipeline)

### Request Shape
```typescript
{
  content: string;
  partition: 'cv_personal' | 'cv_projects' | 'business_seatrace' | 'business_proposals' | 'internal_repos' | 'recreational';
  modality?: 'text' | 'image' | 'audio' | 'pdf' | 'video';  // default: 'text'
}

// Header (required — business tier only):
X-Access-Key: <BUSINESS_ACCESS_KEY value>
```

### Response Shape — Success (200)
```typescript
{
  embedding: number[];       // 3072 dimensions
  dimensions: 3072;          // ALWAYS 3072 — Antigravity must assert this
  model: 'gemini-embedding-2-preview';
}
```

### Antigravity Test Assertions (WRITER→EDITOR Vector Handoff)
- Response `dimensions` MUST equal 3072
- Response `model` MUST equal `'gemini-embedding-2-preview'`
- Mock ChromaDB MUST be used — do NOT call real Gemini API in tests
- WRITER→EDITOR handoff test flow:
  1. Mock: POST /api/embed → returns mock 3072-dim vector
  2. Assert: Vector is stored in mock ChromaDB collection
  3. Assert: EDITOR can retrieve vector by similarity query
  4. This proves the handoff works without real API calls

---

## API Contract: POST /api/verify-access

**Owner:** Claude Code (backend)
**Consumers:** Codex (frontend access gate), Antigravity (auth tests)

### Request Shape
```typescript
{
  key: string;
}
```

### Response Shape
```typescript
{
  valid: boolean;
  tier: 'business' | 'public';  // 'public' when valid=false
}
```

### Antigravity Test Assertions
- `valid: true` MUST only return when key matches `BUSINESS_ACCESS_KEY` exactly
- `valid: false` for empty string, wrong key, null
- `tier: 'public'` MUST be returned when `valid: false`

---

## UI State Contract (Codex → Antigravity boundary)

**Owner:** Codex (frontend)
**Consumers:** Antigravity (Playwright E2E tests)

### Chat UI States

| State | Trigger | Expected DOM |
|-------|---------|--------------|
| `idle` | Page load | Chat input visible, empty history |
| `typing` | User sends message | Loading indicator visible |
| `public-response` | API returns `tier: 'public'` | Reply shown, questionCount+1 |
| `limit-reached` | API returns `limit_reached: true` | Access gate shown, input disabled |
| `business-response` | API returns `tier: 'business'` | Reply shown, no question limit |
| `error` | API returns error field | Error message shown |

### Data Attributes (Codex must maintain these for Antigravity selectors)
```html
data-testid="chat-input"          <!-- chat input field -->
data-testid="chat-submit"         <!-- send button -->
data-testid="chat-response"       <!-- latest response text -->
data-testid="question-count"      <!-- current question count -->
data-testid="access-gate"         <!-- invitation key gate (shown at limit) -->
data-testid="tier-badge"          <!-- 'public' or 'business' indicator -->
data-testid="source-pill"      <!-- per-message source attribution pill (mode: public|business|fallback) -->
```

---

## Gemini Pivot Control Plane Contract

**Owner:** Antigravity (defines status shape)
**Consumers:** All agents (read-only)

```typescript
type ControlPlaneStatus = {
  mode: 'gemini-native' | 'degraded' | 'offline';
  writer: string;                  // env: GEMINI_MODEL_WRITER
  editor: string;                  // env: GEMINI_MODEL_EDITOR (Veo 2.0 for video)
  director: string;                // env: GEMINI_MODEL_DIRECTOR
  remotion: 'DEPRECATED-BYPASS';  // ALWAYS this value — never change
};
```

### Allowed Model Enum
```typescript
const ALLOWED_MODELS = [
  'gemini-2.5-pro',
  'gemini-2.0-flash',
  'gemini-2.5-flash'
] as const;
```

### Antigravity Boot Validation
Antigravity MUST validate at service boot:
1. Each `GEMINI_MODEL_*` env var is in `ALLOWED_MODELS` if set
2. If invalid → **fail fast** with error, do not start
3. If absent → use default (see justfile `status` target)

---

## Cross-Lane Change Protocol

When any agent needs to change an API contract:

1. **Claude Code changing API shape:**
   - Update this file FIRST
   - Notify Codex: add `// CONTRACT CHANGE: <description>` comment in edge function
   - Notify Antigravity: update Antigravity test assertions section in this file

2. **Codex adding a new UI state:**
   - Update the UI State Contract table in this file
   - Add `data-testid` attribute to the new element BEFORE requesting Antigravity tests

3. **Antigravity changing test assertions:**
   - Update the Antigravity Test Assertions section in this file
   - READ the current edge function source before changing assertions
   - Never assert against behavior not present in the current source


## Output Provenance Tracking Contract

**Owner:** Acting Master (Windsurf/Cascade)
**Enforced by:** All agents — no output without provenance metadata.

Every chatbot response, card edit, and content output MUST track four provenance dimensions.
This applies to `/api/chat` responses, UI card edits, and pipeline outputs across all WSP001 repos.

### Provenance Dimensions

| Dimension | Field | Values | Where Stored |
|-----------|-------|--------|--------------|
| **Identity source** | `identity_source` | `identity.json` · `identity_verified.md` · `legacy_narrative (mixed-trust)` | API response + changelog |
| **Style source** | `style_source` | `voice.json` · `hashtags.json` · `creative_credits` · `none` | API response |
| **Project source** | `project_source` | `sirscott` · `sirtrav` · `seatrace` · `sirjames` · `learnquest` | API response + changelog |
| **Retrieval mode** | `retrieval_mode` | `vector-active` · `fallback-local` · `embedded-seed` | API response + UI pill |

### /api/chat 200 response — SHIPPED contract (`netlify/edge-functions/chat.ts`, main @ 2026-09-05)

This is what the runtime emits. QA writes tests against **this** block, nothing else.

```typescript
{
  reply: string;
  tier: 'public' | 'business';
  tokens_used: number;               // Anthropic usage.output_tokens
  rag_context_used: boolean;         // === (rag_status === 'ok')
  rag_status: 'ok' | 'disabled' | 'empty' | 'below_threshold' | 'malformed'
            | 'upstream_error' | 'timeout' | 'unreachable';
  rag_attempts: number;              // real count of /retrieve calls made (0..3)
  answer_source:
    | 'RAG — CV Corpus'                         // public  + rag_status ok
    | 'RAG — Business Corpus'                   // business + rag_status ok
    | 'Verified Profile Pack — Public'          // public  + any other rag_status
    | 'Verified Profile Pack — Business';       // business + any other rag_status
}
// Response header: X-RAG-Status: <rag_status>   (mirrors the body field)
```

`retrieval_mode` is **derived**, not sent: `ok` → `vector-active`; `disabled` → `embedded-seed`;
every other `rag_status` → `fallback-local`.

### `provenance` object — PLANNED, NOT SHIPPED

The four-dimension `provenance` object below was specified 2026-08 and has never been emitted
(`grep -rn provenance netlify/` is empty). It stays here as the target design, with the reason it is
not yet implemented: `project_source` requires classifying the user's question into one of the five
identity boundaries. Doing that by keyword heuristic would put an **ungrounded claim** into the one
field whose purpose is to prove grounding. It ships when retrieval results carry a `boundary` tag in
their metadata so the value can be read, not guessed.

```typescript
// TARGET — do not assert on this until chat.ts emits it
provenance?: {
  identity_source: 'identity.json' | 'identity_verified.md' | 'legacy_narrative';
  style_source: 'voice.json' | 'hashtags.json' | 'creative_credits' | 'none';
  project_source: 'sirscott' | 'sirtrav' | 'seatrace' | 'sirjames' | 'learnquest';
  retrieval_mode: 'vector-active' | 'fallback-local' | 'embedded-seed';
  chunks_used: number;
};
```

### UI Provenance Display (Codex renders from response)

The source attribution pill (`data-testid="source-pill"`) MUST render `answer_source` verbatim and
class itself from `rag_status`:

| rag_status | Pill Text (= `answer_source`) | Pill Class |
|------------|-------------------------------|------------|
| `ok` | `RAG — CV Corpus` / `RAG — Business Corpus` | `msg-meta-pill source public` / `business` |
| `disabled` | `Verified Profile Pack — Public` / `— Business` | `msg-meta-pill source public` |
| any other | `Verified Profile Pack — Public` / `— Business` | `msg-meta-pill source fallback` |

### Card Edit Provenance (CV-CARD-CHANGELOG.md)

Every card edit in `public/index.html` logs to `docs/CV-CARD-CHANGELOG.md` with:

| Column | What |
|--------|------|
| Date | ISO date |
| Agent | Who made the edit |
| Card | Which project card |
| Change | What changed |
| Identity Source | Which file the claim came from |
| Project Source | Which identity boundary applies |

### Antigravity Assertions (against the SHIPPED contract)

- `rag_status` MUST be present on all 200 responses and MUST equal the `X-RAG-Status` header
- `rag_context_used` MUST be `true` iff `rag_status === 'ok'`
- `rag_attempts` MUST be an integer in `0..3`; MUST be `0` when `rag_status === 'disabled'`
- `answer_source` MUST start with `RAG —` iff `rag_status === 'ok'`
- `tokens_used` MUST be a positive integer
- Public-tier responses MUST NOT contain content from `business_*`, `internal_repos` or `recreational` partitions
- Card changelog entries MUST have non-empty Identity Source column
- Do NOT assert on `provenance.*` — see "PLANNED, NOT SHIPPED" above

---

## Lane Separation Enforcement

**Owner:** Acting Master (Windsurf/Cascade)
**Rule:** No agent crosses lanes. Period.

### Lane Map

| Lane | Owner | Files | Cannot Touch |
|------|-------|-------|-------------|
| **Backend** | Claude Code | `netlify/edge-functions/*`, `scripts/*`, `api_server.py` | `public/index.html` layout, UI components |
| **Frontend** | Codex | `public/index.html`, `public/data/*`, CSS/JS in HTML | Edge functions, Python scripts |
| **QA** | Antigravity | `plans/*` (reports only), test scripts | Any source code — read-only recon |
| **Orchestration** | Master (Cascade) | `plans/HANDOFF_*`, `docs/agent-contracts.md`, `AGENTS.md`, `justfile` | Backend logic, frontend UI, test code |
| **Operator** | Human (Scott) | Netlify Dashboard env vars, Cloud Run deploy, API keys | Code files — delegates to agents |

### Identity Boundary Lanes

| Boundary | Scope | Separation Rule |
|----------|-------|-----------------|
| `sirscott` | Professional CV, consulting | Default for CV chatbot responses |
| `sirtrav` | Personal studio, agent orchestration, music | Do NOT conflate with SeaTrace business |
| `seatrace` | Business, commercial marine traceability | Do NOT conflate with SirTrav personal |
| `sirjames` | Creative, family storytelling | NEVER wire to SirTrav or SeaTrace infra |
| `learnquest` | Educational gaming platform | Keep separate until architecture stabilizes |

### Enforcement Checks

Before any commit, the committing agent MUST verify:
1. Files touched are within their lane (see Lane Map)
2. Identity claims reference the correct boundary (see identity.json → identity_boundaries)
3. No cross-boundary wiring (SirJames ≠ SirTrav, SirTrav ≠ SeaTrace)
4. Provenance fields are populated (not placeholder)

### Violation Protocol

If an agent detects a lane violation:
1. STOP — do not commit
2. Log the violation in `plans/LANE_VIOLATIONS.md` (create if needed)
3. Notify Master via next handoff note
4. Master decides: revert, reassign, or approve exception
---

## FOR THE COMMONS GOOD

This contracts pattern (docs/agent-contracts.md) should exist in EVERY WSP001 repo
that has multiple agents working on it. Copy this structure to:
- WSP001/SirTrav-A2A-Studio/
- WSP001/SeaTrace002/ (when agents are added)
- WSP001/WAFC-Business/ (when agents are added)
