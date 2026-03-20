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
  tokens_used: number;       // output tokens consumed
}
```

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

---

## FOR THE COMMONS GOOD

This contracts pattern (docs/agent-contracts.md) should exist in EVERY WSP001 repo
that has multiple agents working on it. Copy this structure to:
- WSP001/SirTrav-A2A-Studio/
- WSP001/SeaTrace002/ (when agents are added)
- WSP001/WAFC-Business/ (when agents are added)
