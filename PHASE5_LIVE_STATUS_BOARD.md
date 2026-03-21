# Phase 5 Live Status Board
> Last updated: 2026-03-20 — Claude Code session
> Branch: `feat/phase5-ui-trust-layer`
> Rule: Each agent reads only their own section.

---

## 🔴 CURRENT BLOCKER

**Scott must copy 1 file before anything else moves.**

```powershell
Copy-Item "C:\Users\Roberto002\OneDrive\Scott CV\092322CURRICULUM VITAE OF ROBERT SCOTT ECHOLS drive.docx" `
  "C:\WSP001\R.-Scott-Echols-CV\knowledge_base\public\cv\CURRICULUM VITAE OF ROBERT SCOTT ECHOLS (2) (1).docx" -Force
```

If that filename doesn't match, inspect first:
```powershell
Get-ChildItem "C:\Users\Roberto002\OneDrive\Scott CV" | Select-Object Name
```

---

## Board

| Agent | Status | Blocker |
|-------|--------|---------|
| **Scott** | ⚠️ ACTIVE BLOCKER | Must copy file #3 |
| **Claude Code** | 🟡 IN PROGRESS | Waiting on file #3 |
| **Antigravity** | 🔴 BLOCKED | Waiting on ingest |
| **Codex #2** | 🟢 DONE / HOLD | Waiting on QA pass |

---

## Scott — Human Ops

Copy the file above. Then send Claude Code this dispatch:

> `Claude Code: Scott has placed file #3. Proceed with Phase 5.5 manifest-based ingest.`

---

## Claude Code — Backend

**Done this session:**
- `answer_source` added to all `/api/chat` 200 responses
- `verify-access.ts` and `embed.ts` confirmed complete
- `docs/agent-contracts.md` updated (answer_source + Antigravity assertions)
- `knowledge_base/public/cv/` created with 2 of 3 files:
  - ✅ `SeaTrace - Robert Scott Echols - CV.PDF`
  - ✅ `061722CURRICULUM VITAE OF ROBERT SCOTT ECHOLS (2)-1.docx`
  - ⏳ `CURRICULUM VITAE OF ROBERT SCOTT ECHOLS (2) (1).docx` — waiting on Scott

**Next session (after file #3 lands):**
1. Read `docs/RSE_CV_SOURCE_MAP_TEMPLATE.md` + `data/rse_cv_manifest.json`
2. Update `scripts/embed_engine.py` — ingest from manifest, not hardcoded paths
3. Implement section-based chunking (split on `##` headers, not token counts)
4. Preserve `access_tier` from manifest into ChromaDB metadata
5. Run ingest + stats + proof query:
   ```bash
   python scripts/embed_engine.py --ingest --partition cv_personal --source knowledge_base/public/cv/
   python scripts/embed_engine.py --stats
   python scripts/embed_engine.py --query "SeaTrace Four Pillars" --partition cv_personal
   ```
6. Report chunk count, query sample, next command for Antigravity

**Lane rule:** Do not touch `public/index.html` or any frontend file.

---

## Antigravity — QA

**Wait for:** Claude Code to confirm ingest + query proof.

**Then run 5 checks:**

1. **Preload questions** — query with each of the 3 preload questions. Each must return a non-empty, section-complete chunk (no mid-sentence cuts).
2. **Chunk integrity** — verify chunks start at a `##` section boundary.
3. **`answer_source` assertion** — every 200 response must contain one of exactly 4 values: `"RAG — CV Corpus"` / `"RAG — Business Corpus"` / `"Embedded CV — Public Profile"` / `"Embedded Knowledge — Business"`.
4. **Public limit** — 4 questions with `questionCount >= 3`, no key. Must return `limit_reached: true`.
5. **Fallback honesty** — kill `VECTOR_ENGINE_URL`. Must return `answer_source: "Embedded CV — Public Profile"`, no crash.

**Output:** Pass/Fail → post in `AGENT_HANDOFFS.md` → Codex merge cleared.

**Lane rule:** Do not write functional code.

---

## Codex #2 — Frontend

**Status:** Complete. Hold.

**Built:**
- Full trust-layer shell + tier/source/note pills (public / business / fallback)
- All `data-testid` hooks per `docs/agent-contracts.md`
- Per-message `source-pill` with mode class
- Preload question shell + access-gate visual states

**Do not:**
- Touch `chat.ts`, `embed_engine.py`, or any backend file
- Merge `feat/phase5-ui-trust-layer` into `main`

**Cleared to act when:** Antigravity issues Pass report.

---

## Sequence

```
Scott copies file #3
  → Claude Code: manifest ingest + section chunking + proof
    → Antigravity: 5-point QA gate
      → Codex #2: merge cleared
        → Scott: approves merge
          → Netlify: auto-deploys to production
```

---

*For the Commons Good* 🎬
