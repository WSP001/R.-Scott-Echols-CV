# Phase 5 Live Status Board

Verified from the local CV repo on 2026-03-20.

## Current Truth

- Branch in play: `feat/phase5-ui-trust-layer`
- Current HEAD: `3973d84` `feat(backend): add answer_source field to /api/chat response [CC-PHASE5]`
- `answer_source` is present in `netlify/edge-functions/chat.ts`
- `answer_source` is registered in `docs/agent-contracts.md`
- `data/rse_cv_manifest.json` exists and expects 3 public CV source files
- `knowledge_base/public/cv/` currently contains 2 files, not 3

This means the backend contract is moving, but the public CV corpus is not complete enough for final ingest and QA.

## Lane Board

### Codex #2

Status: DONE / HOLD

Verified complete:
- Phase 5 trust-layer UI is on this branch
- Chat trust shell is ready for `Public Profile`, `Business Knowledge`, and `Fallback Mode`
- Source-aware answer container is live
- Business unlock states are visually clearer
- Antigravity selectors are present in the chat UI

Do not do now:
- Do not edit `chat.ts`
- Do not edit `embed_engine.py`
- Do not merge yet

Next move:
- Hold position until Claude finishes ingest proof and Antigravity issues a pass
- Only re-enter if QA finds a frontend-only issue

### Claude Code

Status: PARTIALLY DONE / BLOCKED BY FILE #3

Verified complete:
- Added `answer_source` to `/api/chat` responses
- Registered the field in `docs/agent-contracts.md`
- `data/rse_cv_manifest.json` exists on `main`
- `docs/RSE_CV_SOURCE_MAP_TEMPLATE.md` exists on `main`
- `knowledge_base/public/cv/` has 2 of the 3 planned files

Still required:
- Get the 3rd CV file into `knowledge_base/public/cv/`
- Update `scripts/embed_engine.py` to ingest from `data/rse_cv_manifest.json`
- Implement section-based chunking by document heading/section map
- Run ingest for `cv_personal`
- Run stats and query proof
- Hand off to Antigravity with exact QA-ready commands

### Antigravity

Status: READY / BLOCKED BY INGEST

Ready inputs:
- Phase 5 QA docs exist
- Prompt pack exists at `scripts/test-phase5-rag-prompts.json`
- Trust-layer selectors are now in the frontend
- `answer_source` contract now exists

Do not start yet:
- Do not run Phase 5 vector QA until Claude confirms ingest completed

Next QA targets after ingest:
- Preload-question truthfulness
- Section-complete chunk retrieval
- `answer_source` assertions
- Public question-limit behavior
- Fallback honesty

### Scott

Status: CRITICAL PATH

Immediate task:
- Copy the 3rd CV file into `knowledge_base/public/cv/`

Exact command:

```powershell
Copy-Item "C:\Users\Roberto002\OneDrive\Scott CV\092322CURRICULUM VITAE OF ROBERT SCOTT ECHOLS drive.docx" "C:\WSP001\R.-Scott-Echols-CV\knowledge_base\public\cv\CURRICULUM VITAE OF ROBERT SCOTT ECHOLS (2) (1).docx" -Force
```

If that fails:

```powershell
Get-ChildItem "C:\Users\Roberto002\OneDrive\Scott CV" | Select-Object Name
```

Then match the real filename and copy it manually.

## Strict Sequence

1. Scott copies file #3 into `knowledge_base/public/cv/`
2. Claude updates `scripts/embed_engine.py` for manifest-based section chunking
3. Claude runs ingest and stats
4. Claude reports ingest success and query proof
5. Antigravity runs Phase 5 QA
6. Codex stays on hold unless QA finds a frontend-only issue
7. Scott approves merge

## Dispatches

### Dispatch to Scott

Human-Ops assignment:

- Copy the 3rd CV file into `knowledge_base/public/cv/`
- If the exact command fails, list the OneDrive filenames and copy the correct file manually
- This is the only blocker before Claude can finish ingest

### Dispatch to Claude Code

Claude Code: Scott has cleared the file blocker once the 3rd CV file is present.

Your next mission:

1. Read `docs/RSE_CV_SOURCE_MAP_TEMPLATE.md`
2. Read `data/rse_cv_manifest.json`
3. Update `scripts/embed_engine.py` to ingest from the manifest
4. Implement section-based chunking by document headings or section map, not raw token limits alone
5. Preserve access tier metadata in the vector records
6. Run:

```powershell
python scripts/embed_engine.py --ingest --partition cv_personal --source knowledge_base/public/cv/
```

7. Run:

```powershell
python scripts/embed_engine.py --stats
```

8. Report back:
- ingest success or failure
- query success or failure
- exact next QA command for Antigravity

Do not touch frontend files.

### Dispatch to Antigravity

Antigravity: Hold until Claude confirms ingest completed.

When Claude reports ready:

1. Test the 3 preload questions
2. Verify section-complete chunk retrieval
3. Assert `answer_source` on successful responses
4. Assert question-limit behavior
5. Assert fallback honesty
6. Issue a Pass or Fail report for Phase 5

Do not request frontend changes unless the backend contract is stable and the issue is actually frontend-owned.

### Dispatch to Codex #2

Codex: Hold position.

Your trust-layer work is complete enough for Phase 5 backend/QA to proceed.

Do not add more UI work until:

1. Claude completes ingest and retrieval proof
2. Antigravity passes Phase 5 QA

Only return if QA exposes a frontend-only bug or a final metadata-label polish task.

## One-Line Master Summary

File #3 is still the blocker. Once Scott copies it, Claude finishes manifest-based ingest, Antigravity runs Phase 5 QA, and Codex remains on hold unless QA finds a frontend-only issue.
