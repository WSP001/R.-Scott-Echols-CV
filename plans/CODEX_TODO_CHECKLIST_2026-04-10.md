# CODEX_TODO_CHECKLIST_2026-04-10.md

**Owner:** Codex #2  
**Lane:** Frontend Trust / UI / Public Data  
**Repo:** `C:\WSP001\R.-Scott-Echols-CV`  
**Source Audit:** `C:\Users\Roberto002\My Drive\SirSCOTT\CV041026 CLI Agent One-by-One Assig.txt`  
**Status:** Audit first, then in-lane edits only

---

## Codex Lane Truth

Codex #2 may write only:

- `public/index.html`
- `public/assets/`
- `public/data/*` when needed for verified display data

Codex #2 must not write:

- `netlify/edge-functions/chat.ts`
- `scripts/api_server.py`
- `scripts/embed_engine.py`
- `scripts/vector_store.py`
- `scripts/upgrade_cv.py`

Important repo truth:

- Netlify publishes `public/`, so the live page is `public/index.html`
- `scripts/upgrade_cv.py` exists, but it is outside normal Codex lane and uses hardcoded non-portable paths
- Trust/provenance UI already exists in `public/index.html`
- Backend retrieval wiring already exists and must be reflected honestly in the frontend

---

## Audit Checklist

These items should be checked before any frontend write:

- [x] Confirm `public/index.html` is the live publish target from `netlify.toml`
  Evidence:
  `netlify.toml` → `[build] publish = "public"`
- [x] Compare frontend trust shell against `docs/agent-contracts.md`
  Evidence:
  `docs/agent-contracts.md:254` → `data-testid="source-pill"` MUST reflect `retrieval_mode`
  `docs/agent-contracts.md:258` → `vector-active` → `RAG — {project_source} Corpus`
  `docs/agent-contracts.md:278` → `provenance.retrieval_mode` MUST match `rag_context_used`
- [x] Verify `source-pill` behavior matches `retrieval_mode`
  Evidence:
  `public/index.html:3405` previously used `source ${metaInfo.mode}`
  `netlify/edge-functions/chat.ts:383-384` returns exact `answer_source` values:
  `RAG — Business Corpus`, `RAG — CV Corpus`, `Verified Profile Pack — Business`, `Verified Profile Pack — Public`
- [x] Verify `answer_source`, `provenance.retrieval_mode`, `provenance.project_source`, and `rag_context_used` are represented honestly in the UI
  Evidence:
  `public/index.html:3535` and `public/index.html:3545` use `data.answer_source`
  `docs/agent-contracts.md:240-246` defines `rag_context_used`, `answer_source`, `project_source`, `retrieval_mode`
- [x] Verify the `VECTOR_ENGINE_URL` status indicator requirement in `MASTER_AGENT_IMPLEMENTATION_HANDOFF.md`
  Evidence:
  `MASTER_AGENT_IMPLEMENTATION_HANDOFF.md:176` → `Add VECTOR_ENGINE_URL status indicator to chat panel (shows "RAG Active" when /api/retrieve is live)`
- [x] Verify current `data-testid` coverage for chat UI
  Evidence:
  `public/index.html:2654` → `data-testid="tier-badge"`
  `public/index.html:2655` → `data-testid="question-count"`
  `public/index.html:2708` → `data-testid="chat-input"`
  `public/index.html:2709` → `data-testid="chat-submit"`
  `public/index.html:2717` → `data-testid="access-gate"`
  `public/index.html:3406` → `data-testid="source-pill"`
- [x] Verify current ARIA labeling and keyboard behavior for chat input / submit / business unlock shell
  Evidence:
  `public/index.html:2633` → `aria-label="Open AI assistant"`
  `public/index.html:2641` → `role="dialog" aria-label="RSE Assistant"`
  `public/index.html:2709` → send button has `aria-label="Send"`
  `public/index.html:3670` → `handleChatKey(event)` exists
  Missing before edit: no ARIA label on access key input, no keyboard handler on business unlock input
- [x] Record lane drift note: `scripts/upgrade_cv.py` is outside Codex write lane
  Evidence:
  `plans/TEAM_ASSIGNMENT_SHEET.md` → Codex lane is `public/index.html`, `public/assets/`, `public/data/*`
  `scripts/upgrade_cv.py` exists in `scripts/`
- [x] Record lane drift note: repo-root `index.html` is not the Netlify publish target
  Evidence:
  `netlify.toml` → `publish = "public"`

Recommended audit commands:

```powershell
rg -n "source-pill|retrieval_mode|vector-active|RAG Active|answer_source|provenance|rag_context" public/index.html
rg -n "answer_source|retrieval_mode|project_source|rag_context_used" docs/agent-contracts.md
rg -n "VECTOR_ENGINE_URL|status indicator" MASTER_AGENT_IMPLEMENTATION_HANDOFF.md
rg -n "data-testid|aria-|keyboard|accessibility" public/index.html
Get-Content netlify.toml -First 20
```

---

## In-Lane Edit Checklist

Only after the audit above is complete:

- [x] Update `public/index.html` to show retrieval active / inactive more clearly
- [x] Align trust/source pill text and classes with actual `retrieval_mode` states
- [x] Keep `public`, `business`, and `fallback` states honest and visible
- [x] Add `VECTOR_ENGINE_URL` status indicator to the chat panel
- [x] Add or tighten `data-testid` attributes for test automation
- [x] Add or tighten ARIA labels for accessibility
- [x] Add or tighten keyboard support for the chat shell
- [ ] Update `public/data/*` only if verified display data requires it
- [x] If a structural rewrite is needed, run `just archive-asset public/index.html "<reason>"` first
  Evidence:
  `just archive-asset` failed in PowerShell due to POSIX shell syntax in the recipe.
  Preserved equivalent archive manually at:
  `archive/inspirational_scripts/20260414_170327/index.html`

---

## Audit Gaps Found

- `source-pill` classing was keyed to trust mode instead of backend `answer_source`
- no dedicated retrieval status pill existed in the trust shell
- chat subtitle incorrectly said `Powered by Gemini` instead of the live Claude Opus chat runtime
- business unlock input lacked an ARIA label
- business unlock input had no Enter-key handler
- business unlock controls lacked dedicated `data-testid` hooks
- `just codex-validate` is not Windows-safe in the current repo because it calls `wc`

---

## Not Codex Lane

These items belong to other agents and should not be edited by Codex #2:

- Studio `--build-gate` fix in `SirTrav-A2A-Studio`
- `chat.ts` retrieval behavior
- `api_server.py` `/retrieve` and `/query`
- `embed_engine.py` ingest / partitions / stats
- `vector_store.py` pgvector / Chroma implementation
- Netlify env var setup
- Cloud Run deploys

---

## Completion Markers

Mark these when done:

- [x] Audit complete
- [x] In-lane UI edits complete
- [ ] `just codex-validate` passes
  Blocked:
  `just codex-validate` fails under PowerShell because `wc` is not installed:
  `wc : The term 'wc' is not recognized as the name of a cmdlet`
- [x] Lane-drift notes documented
- [x] Ready for Scott review

---

## Attribution

Architecture -> Scott Echols / WSP001 (For the Commons Good)  
Engineering -> Codex (ChatGPT Business Seat #2)
