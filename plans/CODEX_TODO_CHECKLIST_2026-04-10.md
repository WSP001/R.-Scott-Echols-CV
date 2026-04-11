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

- [ ] Confirm `public/index.html` is the live publish target from `netlify.toml`
- [ ] Compare frontend trust shell against `docs/agent-contracts.md`
- [ ] Verify `source-pill` behavior matches `retrieval_mode`
- [ ] Verify `answer_source`, `provenance.retrieval_mode`, `provenance.project_source`, and `rag_context_used` are represented honestly in the UI
- [ ] Verify the `VECTOR_ENGINE_URL` status indicator requirement in `MASTER_AGENT_IMPLEMENTATION_HANDOFF.md`
- [ ] Verify current `data-testid` coverage for chat UI
- [ ] Verify current ARIA labeling and keyboard behavior for chat input / submit / business unlock shell
- [ ] Record lane drift note: `scripts/upgrade_cv.py` is outside Codex write lane
- [ ] Record lane drift note: repo-root `index.html` is not the Netlify publish target

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

- [ ] Update `public/index.html` to show retrieval active / inactive more clearly
- [ ] Align trust/source pill text and classes with actual `retrieval_mode` states
- [ ] Keep `public`, `business`, and `fallback` states honest and visible
- [ ] Add `VECTOR_ENGINE_URL` status indicator to the chat panel
- [ ] Add or tighten `data-testid` attributes for test automation
- [ ] Add or tighten ARIA labels for accessibility
- [ ] Add or tighten keyboard support for the chat shell
- [ ] Update `public/data/*` only if verified display data requires it
- [ ] If a structural rewrite is needed, run `just archive-asset public/index.html "<reason>"` first

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

- [ ] Audit complete
- [ ] In-lane UI edits complete
- [ ] `just codex-validate` passes
- [ ] Lane-drift notes documented
- [ ] Ready for Scott review

---

## Attribution

Architecture -> Scott Echols / WSP001 (For the Commons Good)  
Engineering -> Codex (ChatGPT Business Seat #2)
