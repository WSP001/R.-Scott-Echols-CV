# TEAM_ASSIGNMENT_SHEET.md — Finish-Line Dispatch

**Version:** 2.0.0
**Last Updated:** 2026-04-11
**Signed by:** Windsurf/Cascade (Acting Master, WSP001)
**Owner of truth:** Scott / Acting Master
**Previous version:** Archived to archive/inspirational_scripts/20260411_team_sheet/

```text
MODE:   Read first, then execute by lane
RULE:   One lane at a time. Proof before narrative. Move not delete.
PURPOSE: Give every teammate a clear assignment, command surface, and done signal.
```

---

## 1. Shared Operating Rules

### Read-First Rule

Before writing anything, read:

1. repo status (`git status -sb`)
2. recent commits (`git log --oneline -8`)
3. stack truth (`STACK_TRUTH.md`)
4. current board / next gate (`AGENT-OPS.md`, `PHASE5_LIVE_STATUS_BOARD.md`)
5. your lane only

### Lane Rule

- One row = one lane
- Read across lanes if needed
- Write only in your assigned lane
- Do not widen scope without a new dispatch

### Proof Rule

A task is only done when there is observable proof:

- build passed
- smoke passed
- probe passed
- QA passed
- artifact written
- PR opened / merge completed

### Archive Rule

Before destructive structural changes:

- archive first, record reason, then replace
- `just archive-asset FILE=<path> REASON="<why>"`
- `just archive-list`

---

## 2. Shared CLI Surface

### Master Favorites

```text
just cockpit
just stack-truth
just qa-ready
```

### Claude Code Favorites

```text
just claude-orient
just doctor
just claude-truth-audit
just validate-manifest
just claude-vector-probe
just claude-env-check
just cold-start
just full-deploy
```

### Codex Favorites

```text
just codex-validate
just codex-build
just codex-status
```

### Antigravity Favorites

```text
just antigravity-qa
just antigravity-smoke
just antigravity-proof-report
just cv-smoke-cloud
```

### Archive (all lanes)

```text
just archive-asset FILE=<path> REASON="<why>"
just archive-list
```

---

## 3. CV Repo Assignments

**Repo:** `C:\WSP001\R.-Scott-Echols-CV`

### Read-First Order

```powershell
git status -sb
git log --oneline -8
type AGENT-OPS.md
type STACK_TRUTH.md
type PHASE5_LIVE_STATUS_BOARD.md
```

### Scott / Acting Master

```text
LANE:       governance / merge / truth / env vars / phase gates
FILES:      AGENT-OPS.md, STACK_TRUTH.md, PHASE5_LIVE_STATUS_BOARD.md
CLI:        just cockpit, just stack-truth, just qa-ready
```

**Do next:**

1. Merge `feat/phase5-ui-trust-layer` branch
2. Add `PERPLEXITY_API_KEY` to Netlify env (enables Layer 2 research)
3. Verify live state after deploy
4. Name next owner for Phase 6 work

**Done signal:** Phase 5 merged, Netlify deploy verified, next owner named.

### Claude Code

```text
LANE:       backend / ops / scripts / justfile / truth gates
FILES:      justfile, scripts/, netlify/edge-functions/, AGENT-OPS.md, STACK_TRUTH.md
CLI:        just claude-orient, just validate-manifest, just claude-truth-audit,
            just doctor, just claude-env-check, just claude-proof-of-work, just full-deploy
```

**Do next:**

1. Keep truth-audit local, cached, and enforced (pre-commit hook installed)
2. Maintain justfile recipes thin and replayable
3. Do not replace free truth-audit with paid LLM logic
4. Only touch backend/ops/docs lane

**Done signal:** Truth audit passes, hooks work, justfile commands verified.

### Codex #2

```text
LANE:       frontend only if explicitly assigned
FILES:      public/index.html, public/assets/, public/data/*
CLI:        just codex-validate, just codex-build, just codex-status
```

**Do next:**

1. Execute audit checklist (`plans/CODEX_TODO_CHECKLIST_2026-04-10.md`) BEFORE any edits
2. Touch frontend only when specifically dispatched
3. Archive before structural rewrite (`just archive-asset`)

**Done signal:** Assigned frontend diff exists and stays in lane.

### Antigravity

```text
LANE:       QA only — verify, do not implement
FILES:      QA proof docs, live verification results
CLI:        just antigravity-qa, just antigravity-smoke, just cv-smoke-cloud, just claude-vector-probe
```

**Do next:**

1. Run post-deploy smoke after Phase 5 merge
2. Verify CV trust-layer displays correct RAG state
3. Return PASS / PASS_WITH_NOTES / BLOCKED / FAIL

**Done signal:** QA report with evidence, not narrative.

---

## 4. Studio Repo Assignments

**Repo:** `C:\WSP001\SirTrav-A2A-Studio`

### Read-First Order

```powershell
git status -sb
git log --oneline -8
type STACK_TRUTH.md
type plans\SESSION-TRUTH-2026-04-05.md
type plans\HANDOFF_CODEX2_CX-019.md
type plans\TEAM_HANDOFF_BOARD_CODEX2_APP_PROGRESS.md
```

### Scott / Acting Master

```text
LANE:       governance / PR / next owner / merge approval
CLI:        just cockpit, just stack-truth, just qa-ready, just studio-status
```

**Do next:**

1. Check PR #29 state and branch state
2. Confirm Stack Truth is current
3. Approve merge only after Claude Code fixes `--build-gate`

**Done signal:** PR state understood, next owner named, merge decision grounded.

### Claude Code

```text
LANE:       backend / ops / scripts / gates / netlify.toml
CLI:        just claude-orient, just doctor, just studio-status, just seed-brief,
            just sanity-test-local, just build-gate, just verify-cloud, just netlify-gate
```

**Do next:**

1. Fix `scripts/sanity-test.mjs` — add `--build-gate` flag that skips function endpoint fetches during Netlify build
2. Update `netlify.toml` build command: `npm run build && node scripts/sanity-test.mjs --build-gate`
3. Keep seed bridge and operational docs machine-readable

**Done signal:** `npm run build && node scripts/sanity-test.mjs --build-gate` passes, PR #29 deploy succeeds.

### Codex #2

```text
LANE:       frontend shell / progress UI / accessibility in touched lane
FILES:      src/App.jsx, src/components/PipelineProgress.tsx, related UI files only
CLI:        just codex-validate, just build-gate, just studio-status
```

**Do next:**

1. Implement assigned UI work only
2. Keep progress honest and in-place
3. Preserve existing transport — do not invent new polling/API flows

**Done signal:** Build passes, UI diff stays in lane.

### Antigravity

```text
LANE:       QA only
CLI:        just antigravity-qa, just build-gate, just verify-cloud, just studio-status
```

**Do next:**

1. Validate PR #29 scope after Claude Code fix lands
2. Return merge recommendation
3. Do not code

**Done signal:** QA output returns PASS / PASS_WITH_NOTES / BLOCKED / FAIL.

---

## 5. Finish-Line Priorities

### CV Repo

```text
P0: Scott merges Phase 5 trust-layer branch
P0: Verify live deploy (just cv-smoke-cloud)
P1: Scott adds PERPLEXITY_API_KEY to Netlify env
P1: Claude Code maintains truth-audit hooks + cache
P2: Codex executes audit checklist then patches trust UI
```

### Studio Repo

```text
P0: Claude Code fixes --build-gate in sanity-test.mjs
P0: Scott approves PR #29 after fix + QA
P1: Keep shared-kernel truth current
P2: Route frontend work only to Codex lane
```

---

## 6. Horizon Architecture Directive (2026-04-11)

```text
COMPRESSION SHIFT: 6-8x context expansion coming (TurboQuant KV cache).
  ACTION: Stop aggressive chunking. Keep source docs whole in knowledge_base/.
  The CV Truth Pack will load in entirety as persistent session context.

COMPUTE SHIFT: Native Wasm in transformer weights coming.
  ACTION: Keep justfile commands thin — orchestration only.
  Agents will handle heavy compute internally during inference.

DIRECTIVE: Maintain strict lane discipline today so we are ready to scale tomorrow.
  Move not delete. Archive for inspiration. Build for the Commons Good.
```

---

## 7. Final Team Standard

```text
We work by:
  - truth first
  - one lane at a time
  - stable CLI rails
  - archive before destructive change
  - proof before claim
  - next owner named every time
```

*For the Commons Good*
**Acting Master: Windsurf/Cascade | Human Admin: Roberto Scott Echols / WSP001 | 2026-04-11**
