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
                             // UNCHANGED — existing UI and tests keep working
  rag_status: RagStatus;     // ADDED 2026-09-13 — why retrieval did or did not
                             // ground this answer (see below)
  rag_attempts: number;      // ADDED 2026-09-13 — retrieval attempts actually
                             // made (0 when disabled)
  sources_used: string[];    // ADDED 2026-09-13 — source labels of the chunks that
                             // fed the answer; [] whenever rag_status !== 'ok'
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

#### `RagStatus` — why a boolean was not enough

`rag_context_used: false` conflated several different situations, so "retrieval
is switched off", "retrieval timed out" and "retrieval ran and found nothing
relevant" were indistinguishable from the outside. That is how a dead corpus
goes unnoticed for weeks. `rag_status` names which one it actually is, and both
`/api/chat` and `/api/social-generate` report it.

**Also returned as a response header:** `X-RAG-Status: <RagStatus>` — so uptime checks and
Antigravity smoke tests can assert grounding health without parsing the body.

**Invariant:** `rag_context_used === (rag_status === 'ok')`. The boolean is
derived from the enum, never set independently. Antigravity should assert the
identity rather than the two fields separately.

Score floor is `0.3` cosine similarity. Below it, chunks are discarded rather
than passed to the model, because a low-similarity chunk is a licence to
hallucinate with a citation attached.

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

**Added 2026-09-13 (the `rag_status` change).** These 23 assertions were verified
against the patched `chat.ts` before it shipped; Antigravity should encode them in
`tests/`, which Claude Code may not write (lane rule):
- `rag_status` MUST be present on every 200 response and MUST be one of the 8 enum values
- `rag_context_used === (rag_status === 'ok')` MUST hold on every 200 response
- `sources_used` MUST be an array on every 200 response, and MUST be `[]` whenever
  `rag_status !== 'ok'` — a non-empty source list with a failed retrieval is a lie
- With `VECTOR_ENGINE_URL` unset → `rag_status === 'disabled'` (NOT `'upstream_error'`), and
  `rag_attempts === 0`
- With the retrieve mock returning `[]` → `rag_status === 'empty'`
- With the retrieve mock returning chunks all scoring `< 0.3` → `rag_status === 'below_threshold'`
  and `reply` MUST still be produced (degraded, not failed)
- With the retrieve mock hanging past the timeout → `rag_status === 'timeout'`, and the
  request MUST still return 200 — a slow corpus must never take the chatbot down
- With the retrieve mock returning HTTP 500 → `rag_status === 'upstream_error'`
- `limit_reached`, `tier`, `tokens_used`, `answer_source` and the `claude-opus-4-6`
  model lock MUST be byte-identical to their pre-change behaviour (regression set)

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

## API Contract: POST /api/abacus

**Owner:** Claude Code (backend)
**Consumers:** Antigravity (E2E tests). Codex: **do not** wire this into the chat UI.
**Added:** 2026-09-08, by explicit owner request (Roberto).

> ⚠️ **MODEL LOCK IS UNCHANGED.** This endpoint is an *additive side channel* for
> Abacus.AI platform/agent work. It does **not** serve `/api/chat`, and it must not be
> substituted into the chatbot path. The CV chatbot remains Claude Opus 4.6
> (`claude-opus-4-6`) for all tiers per `CLAUDE.md`.

**Access:** BUSINESS TIER ONLY. Abacus.AI bills a paid subscription, so there is no
public path to this endpoint. `X-Access-Key` is validated server-side against
`BUSINESS_ACCESS_KEY`; a missing or wrong key returns **403** (not 401), and no
Abacus.AI call is made.

**Rate limit:** 30 requests/minute per IP (in-edge sliding window).

### Request Shape
```typescript
{
  op?: 'health' | 'projects' | 'chat';  // default: 'health'
  // op='chat' only:
  message?: string;          // required for op='chat', non-empty
  history?: Array<{ role: 'user' | 'assistant'; content: string }>;  // last 10 kept
  model?: string;            // overrides ABACUS_MODEL; default 'route-llm'
  max_tokens?: number;       // default 1024
}

// Header (required):
X-Access-Key: <BUSINESS_ACCESS_KEY value>
```

### Response Shape — op='health' (200)
```typescript
{
  ok: boolean;
  abacus_key_present: boolean;  // presence only — the value is NEVER returned
  key_valid: boolean;
  upstream_status: number;      // Abacus.AI HTTP status (401 = bad key, 403 = no subscription)
  note: string;
}
```
Returns **502** with the same shape when Abacus.AI rejects the key.

### Response Shape — op='projects' (200)
```typescript
{
  projects: Array<{ projectId: string | null; name: string | null; useCase: string | null }>;
  count: number;
}
```

### Response Shape — op='chat' (200)
```typescript
{
  reply: string;
  provider: 'abacus.ai';
  surface: 'routellm';
  model: string;
  note: string;      // states that /api/chat is still Claude Opus 4.6
}
```

### Response Shape — Errors
| Status | Cause |
|--------|-------|
| 400 | invalid JSON, unsupported `op`, or missing `message` on `op='chat'` |
| 403 | missing/invalid `X-Access-Key` |
| 405 | non-POST method |
| 429 | rate limit exceeded (`retry_after_seconds` included) |
| 503 | `ABACUS_API_KEY` not set (`abacus_key_present: false`) |
| 502 | Abacus.AI upstream failure or rejected key |

### Upstream surfaces (they authenticate differently — do not conflate)
| op | Upstream | Auth header |
|----|----------|-------------|
| `health`, `projects` | `https://api.abacus.ai/api/v0/listProjects` | `apiKey: <key>` |
| `chat` | `https://routellm.abacus.ai/v1/chat/completions` | `Authorization: Bearer <key>` |

RouteLLM is OpenAI-compatible; the management API is not.

### Antigravity Test Assertions
- No `X-Access-Key` → **403**, and the response MUST NOT contain `reply` or `projects`
- Wrong `X-Access-Key` → **403** (never 200, never a partial result)
- `op` not in the allowlist → **400**, and no upstream call is made
- `op='chat'` with empty/missing `message` → **400**
- `op='health'` MUST report `abacus_key_present` as a **boolean**; no response field on
  any op may ever contain the key value or any substring of it
- `/api/chat` responses MUST still report Claude provenance — asserting that this
  endpoint did not leak into the chatbot path is a required regression test

---
## API Contract: POST /api/social-generate

**Owner:** Claude Code (backend)
**Consumers:** SirScottA2A-STUDIO (publisher), Antigravity (E2E tests).
Codex: **do not** wire this into the CV chat UI — it is not a chat endpoint.
**Added:** 2026-09-13, per the owner's "Netlify Agent Runner — Instructions v2".

> ⚠️ **THIS ENDPOINT NEVER PUBLISHES.** `published: false` is hard-coded in the
> response and there is no code path that sets it true. Publishing is
> SirScottA2A-STUDIO's sole responsibility (THE VOICE). This is THE BRAIN
> handing over a draft. Any future publish capability belongs in that repo, not
> here — an endpoint that can both generate and publish can post a
> hallucination without a human in the loop.

> **MODEL LOCK APPLIES.** `claude-opus-4-6`, same constant as `/api/chat`, per
> `CLAUDE.md` ("Claude Opus 4.6 is the ONLY model for the chatbot — NO
> EXCEPTIONS"). Social copy speaks in Scott's voice and is therefore in scope.

**Access:** public tier allowed (5 req/min per IP). Business tier (30 req/min)
required for anything touching SeaTrace. See the tier boundary below.

### Request Shape
```typescript
{
  topic: string;                     // required, 3–500 characters
  platform?: 'linkedin' | 'twitter' | 'general';   // default: 'linkedin'
  tone?: Tone;                       // default: taken from public/data/voice.json
  identity?: 'sirscott' | 'sirtrav' | 'seatrace' | 'sirjames';  // default: 'sirscott'
  include_seatrace?: boolean;        // default: false — business tier ONLY
}

// Header (business tier / any SeaTrace request):
X-Access-Key: <BUSINESS_ACCESS_KEY value>
```

### Platform ceilings (hard, not advisory)
| platform | character limit | max hashtags |
|----------|-----------------|--------------|
| `linkedin` | 3000 | 5 |
| `twitter` | 280 | 2 |
| `general` | 1200 | 4 |

### Response Shape — Success (200)
```typescript
{
  content: string;            // the draft post body — NEVER truncated (see below)
  hashtags: string[];         // allowlist-filtered server-side, capped at the platform max
  character_count: number;    // content.length
  platform: 'linkedin' | 'twitter' | 'general';
  platform_limit: number;     // the ceiling from the table above
  platform_formatted: boolean;// false when the model overran the ceiling
  identity: string;
  tone: string;
  tier: 'public' | 'business';
  sources_used: string[];     // source labels of retrieved chunks ([] unless rag_status='ok')
  rag_status: RagStatus;      // own 6-value enum — see social-generate.ts.
                              // NOTE: /api/chat reports the unconfigured case as
                              // 'disabled'; this endpoint calls it 'not_configured'.
  rag_chunks_used: number;
  claims: string[];           // factual claims the model asserted — for human review
  model: 'claude-opus-4-6';
  published: false;           // ALWAYS false. Not a variable.
}
```

**`platform_formatted: false` is reported, not repaired.** An over-length post is
returned in full with the flag false, so the caller can retry or edit. Silently
truncating would cut a post mid-sentence and publish it — worse than a visible failure.

**Hashtags are filtered twice.** The prompt is given the approved pool from
`public/data/hashtags.json`; the response is then re-filtered against that same pool
server-side. The prompt *asks*; the filter *guarantees*. A hallucinated hashtag can
therefore never reach a published post.

### Identity → hashtag pool mapping
`public/api/identity.json` carries the `trust_policy` rule *"Keep SirTrav personal work
separate from SeaTrace business work."* That is enforced structurally, not requested politely:

| identity | pools drawn from |
|----------|------------------|
| `sirscott` | `core` |
| `sirtrav` | `core`, `personal_studio`, `creative_producer` |
| `seatrace` | `core`, `business` |
| `sirjames` | `creative` |

### Tier boundary
`include_seatrace: true` **or** `identity: 'seatrace'` without a valid `X-Access-Key`
returns **403**. It is *not* quietly downgraded to a public post — a silent downgrade
produces content that looks authorised but is not. Public callers also never see
`business_proposals` or `internal_repos` chunks; partition filtering happens
server-side in the Cloud Run service, not here.

### Response Shape — Errors
| Status | Cause |
|--------|-------|
| 400 | invalid JSON; `topic` missing / under 3 chars / over 500 chars; unknown `platform`, `tone` or `identity` |
| 403 | SeaTrace content requested without a valid `X-Access-Key` |
| 405 | non-POST method |
| 429 | rate limit exceeded (`retry_after_seconds` included; `Retry-After` header set) |
| 503 | `ANTHROPIC_API_KEY` not set |
| 502 | Anthropic upstream failure, rejected key, or an unparseable model draft |

The 503/502 split is the same diagnostic as `/api/chat`: **503 = key missing,
502 = key rejected upstream.** Do not collapse them.

### Truth packs
The generator fetches `/data/voice.json`, `/data/hashtags.json` and
`/api/identity.json` **same-origin at request time**, so it reads exactly what
`scripts/truth_audit.py` audits. Neither can drift from the other without the audit
failing. If a pack fails to load, generation continues with the remaining packs and
the missing constraints are simply absent — it does not invent substitutes.

### Antigravity Test Assertions
- `published` MUST be `false` on every 200 response — assert the literal, not truthiness
- `model` MUST be `claude-opus-4-6` on every 200 response
- `include_seatrace: true` with no `X-Access-Key` → **403**, and the body MUST NOT
  contain `content` or `hashtags`
- `identity: 'seatrace'` with no `X-Access-Key` → **403** (the identity is a second
  door to the same content; both must be locked)
- Every returned hashtag MUST exist in the pool set for the requested identity —
  inject a hallucinated tag into the model mock and assert it is stripped
- `hashtags.length <= hashtagMax` for the requested platform
- `platform: 'twitter'` with a mocked 400-char draft → `platform_formatted: false`
  AND `content.length === 400` (assert it was NOT truncated)
- `topic` of 2 chars → **400**; `topic` of 501 chars → **400**
- Missing `ANTHROPIC_API_KEY` → **503**; invalid key → **502** (never the same code)
- 6th public request inside 60s from one IP → **429** with `retry_after_seconds`
- `sources_used` MUST be `[]` whenever `rag_status !== 'ok'`
- `claims` MUST be an array on every 200 response (empty is valid; absent is not)
- A public request MUST NOT return any chunk sourced from `business_proposals`,
  `internal_repos`, `business_seatrace` or `recreational`

30 harness assertions covering the above were run green against the implementation
on 2026-09-13. Claude Code cannot commit them — `tests/` is Antigravity's lane —
so they are recorded here as the canonical list to encode.

---

## API Contract: Cloud Run vector service (`rse-retrieval`)

**Owner:** Claude Code (backend) — `scripts/api_server.py`
**Consumers:** `chat.ts`, `social-generate.ts`, the ingest scripts in `scripts/`.
Never called from the browser; there is no public route to it.

> ⚠️ **BACKEND CHANGED 2026-09-13: ChromaDB → PostgreSQL + pgvector.**
> The deployed service had already moved to pgvector; the committed code still
> said ChromaDB. The repo now matches production. **The HTTP contract below is
> deliberately unchanged** — request and response shapes are byte-compatible, so
> `chat.ts` and SirScottA2A needed no edits for this migration. Do not
> reintroduce `chromadb`; `just truth-audit` fails the build if it reappears
> as *usage* (imports, `PersistentClient`, `CHROMADB_PATH`).

### Endpoints
| Method | Path | Auth | Purpose |
|--------|------|------|---------|
| GET | `/health` | none | liveness + corpus reachability |
| POST | `/retrieve` | none | tier-scoped similarity search (what `chat.ts` calls) |
| POST | `/query` | none | alias of `/retrieve`, kept for older callers |
| POST | `/ingest` | `X-Ingest-Secret` | write chunks (guarded by `INGEST_SECRET`) |

### POST /retrieve
```typescript
// Request
{ query: string; tier?: 'public'|'business'; partition?: string|null; k?: number; }

// Response (200)
Array<{ content: string; score: number; source: string; partition: string; }>
```
`score` is `1 - cosine_distance`, so higher is better and `1.0` is identical.

### GET /health
```typescript
{
  status: 'ok' | 'degraded';   // 'degraded' whenever the database is unreachable
  backend: 'pgvector';
  chunks: number | null;
  partitions: string[];
  error?: string;              // class + message, DSN and password REDACTED
}
```
**`status` is never `'ok'` when the corpus is unreachable.** A green health check on a
dead corpus is how silent RAG failure survives for weeks. Cloud Run's liveness probe
treats `degraded` as alive-but-broken, which is the truth.

### Partitions and tiers (the boundary, in one table)
| partition | tier | added |
|-----------|------|-------|
| `cv_personal` | public | — |
| `cv_projects` | public | — |
| `linkedin_history` | public | **2026-09-13** |
| `social_published` | public | **2026-09-13** |
| `business_seatrace` | business | — |
| `business_proposals` | business | — |
| `internal_repos` | business | — |
| `recreational` | private | — |

Public requests are filtered to the `public` rows **in SQL**, not in the caller.
This table is duplicated in three places on purpose — `api_server.py`
(`PARTITION_TIERS`), `scripts/schema/wsp001_knowledge.sql`
(`wsp001_partitions` registry), and here — and
`scripts/truth_audit.py::audit_partition_contract` fails if they disagree. A tier
boundary that lives in only one file is one careless edit from a leak.

### Schema and the 3072-dimension constraint
`scripts/schema/wsp001_knowledge.sql` is idempotent DDL (`just db-schema`).
`embedding` is `VECTOR(3072)` (Gemini Embedding 2).

**There is deliberately no ANN index on `embedding`.** pgvector caps both `ivfflat`
and `hnsw` at **2000 dimensions**, so no approximate index can exist on a 3072-dim
`vector` column. Retrieval is an exact sequential scan, which is correct and fast at
this corpus size. **Do not "fix" this by reducing dimensions** — changing the
embedding model or width silently invalidates every stored vector and retrieval
degrades without erroring. The documented upgrade path past roughly 10k chunks is
`halfvec(3072)` + HNSW (pgvector ≥ 0.7.0), which requires the matching
`ORDER BY embedding::halfvec(3072) <=> $1::halfvec(3072)` in the query. See the
comment block in the SQL file.

### Ingest and deduplication
`POST /ingest` upserts with `ON CONFLICT (partition, content_hash) DO NOTHING
RETURNING id`, so re-running an ingest is safe and reports how many chunks were
genuinely new. The unique index is per-partition: the same text may legitimately
exist in both `linkedin_history` and `social_published`.

Server-side re-embedding is authoritative. `scripts/embed_engine.py --remote` sends
**content**, not vectors, and discards the locally computed embedding, so ingest and
retrieval always use the same model version. Local mode writes to a local store that
**production does not read** and now says so in its output.

### Environment
| Var | Set where | Notes |
|-----|-----------|-------|
| `DATABASE_URL` | **Cloud Run secret** | NOT Netlify. Needs `?sslmode=require` |
| `GEMINI_API_KEY` | Cloud Run secret | embedding model |
| `INGEST_SECRET` | Cloud Run secret | guards `POST /ingest` |
| `VECTOR_ENGINE_URL` | Netlify env | the edge functions' pointer to this service |

Errors surfaced by `/health` pass through `safe_error()`, which redacts anything
DSN-shaped. psycopg exceptions embed the full connection string including the
password, and `/health` is unauthenticated — that combination leaked credentials
before 2026-09-13.

### Antigravity Test Assertions
- `/health` with an unreachable database → `status: 'degraded'`, never `'ok'`
- `/health` error text MUST NOT contain `://`, `password=`, or any DSN substring
- `/retrieve` with `tier: 'public'` MUST NOT return rows whose `partition` is
  `business_*`, `internal_*` or `recreational` — assert on the returned `partition` field
- `/retrieve` with an unknown `partition` → the request is rejected, not silently widened
- `/ingest` without `X-Ingest-Secret` → **401**, and no row is written
- Re-posting an identical chunk to `/ingest` → accepted, `0` new rows (dedupe)
- `score` MUST be in `[0, 1]` and ordered descending

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
