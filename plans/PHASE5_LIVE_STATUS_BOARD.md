# RSE CV BOT — LIVE TEAM STATUS BOARD (PHASE 5)

This board establishes absolute clarity. We do not tell everyone everything at once; we tell each agent their status, their exact blocker, and their single next move.

---

## 🚦 TRUE SEQUENCE
**The simplest, real command chain:**
1. **Scott** copies the 3rd CV file.
2. **Claude** ingests the manifest.
3. **Antigravity** verifies the boundary and chunk integrity.
4. **Codex** holds position.
5. **Scott** approves the merge.

---

## 🛑 1. Scott (Human Ops / Critical Path)
**Status:** ACTIVE BLOCKER
**What Scott must do now:**
Copy the missing 3rd CV file into the `cv` folder so the ingestion engine can run.

**Exact Action:**
Open PowerShell and run:
`Copy-Item "C:\Users\Roberto002\OneDrive\Scott CV\092322CURRICULUM VITAE OF ROBERT SCOTT ECHOLS drive.docx" "C:\WSP001\R.-Scott-Echols-CV\knowledge_base\public\cv\CURRICULUM VITAE OF ROBERT SCOTT ECHOLS (2) (1).docx" -Force`

*(If the filename in OneDrive has changed, manually drag and drop it into `knowledge_base/public/cv/`)*

---

## 🟡 2. Claude Code (Backend / Retrieval)
**Status:** IN PROGRESS / BLOCKED
**Completed:** Added `answer_source` contract and bridged 2 of 3 CV files.
**Blocker:** Waiting on Scott to place the 3rd CV file.

**Next Dispatch (Once Scott clears the blocker):**
1. Read `data/rse_cv_manifest.json`
2. Update `scripts/embed_engine.py` to implement section-based chunking by markdown/document headers.
3. Ingest: `python scripts/embed_engine.py --ingest --partition cv_personal --source knowledge_base/public/cv/`
4. Report: Ingest Success / Failure to Antigravity.

---

## 🔴 3. Antigravity (QA / Verification)
**Status:** READY / BLOCKED
**Completed:** Generated the Phase 5 QA docs, chunk testing parameters, and tier boundary blueprints.
**Blocker:** Waiting for Claude to state that Ingestion is 100% complete and the Vector Server is spinning.

**Next Dispatch (My Name - Antigravity):**
As soon as Claude reports the ingest is live, I execute the Phase 5 QA gates:
1. Run the `test-phase5-rag-prompts.json` preload questions.
2. Verify all retrieved chunks are section-complete (no mid-sentence cuts).
3. Validate that `answer_source` passes the correct metadata value to the UI.
4. Verify the 4-question public limit fires correctly.
5. Test fallback honesty (if the vector DB is simulated as down).
**Outcome:** Issue final Pass/Fail report.

---

## 🟢 4. Codex #2 (Frontend Trust Layer)
**Status:** DONE / HOLD
**Completed:** The Phase 5 UI "Trust Layer" is built on branch `feat/phase5-ui-trust-layer`.
**Blocker:** Waiting for Antigravity's QA Pass and Claude's final metadata schema.

**Next Dispatch:**
**HOLD POSITION.** Absolutely no more frontend feature work. Only wake up if Antigravity's QA pass exposes a specific visual alignment issue requiring one narrow polish commit. Do not touch routing or backend files.
