# Phase 5 Live Status Board
> Last updated: 2026-03-20 — reconciled to local repo state
> Branch: `feat/phase5-ui-trust-layer`
> Rule: Each agent reads only their own section.

---

## Current Truth

- The Phase 5 trust-layer UI is already built on this branch.
- `answer_source` is already wired into `/api/chat`.
- Manifest-based ingest is already wired into `scripts/embed_engine.py`.
- Section-based chunking is already wired into `scripts/embed_engine.py`.
- PDF and DOCX extraction are already wired into `scripts/embed_engine.py`.
- All 3 public CV files are now present in `knowledge_base/public/cv/`.
- The manifest ingest run reached the Gemini embedding call and failed only because `GEMINI_API_KEY` was not set in the current shell.
- Windows console encoding also needs UTF-8 forced for clean manifest output.

This means the main code work is ahead of the old board. The live blocker is now runtime environment, not missing files.

---

## Current Blocker

Scott must run the ingest from a shell that has:

- Python 3.13, not the default Python 3.14 shell interpreter
- `PYTHONIOENCODING=utf-8`
- `GEMINI_API_KEY` set to a valid Google AI Studio key

Exact PowerShell sequence:

```powershell
cd C:\WSP001\R.-Scott-Echols-CV
$env:PYTHONIOENCODING = "utf-8"
$env:GEMINI_API_KEY = "your_key_here"
& "C:\Python313\python.exe" scripts\embed_engine.py --from-manifest
& "C:\Python313\python.exe" scripts\embed_engine.py --stats
& "C:\Python313\python.exe" scripts\embed_engine.py --query "Who is Scott and what does he specialize in?" --partition cv_personal
```

If the key is invalid, the run will fail at Google embeddings again.

---

## Board

| Agent | Status | Blocker |
|-------|--------|---------|
| **Scott** | ⚠️ ACTIVE BLOCKER | Must run ingest with valid `GEMINI_API_KEY` in the current shell |
| **Claude Code** | 🟡 CODE COMPLETE / STANDBY | Waiting for env-backed ingest proof or runtime bug report |
| **Antigravity** | 🔴 BLOCKED | Waiting for successful ingest + stats + query proof |
| **Codex #2** | 🟢 DONE / HOLD | Waiting on QA pass |

---

## Scott — Human Ops

Your job is no longer file copy. Your job is runtime activation.

Do this now:

```powershell
cd C:\WSP001\R.-Scott-Echols-CV
$env:PYTHONIOENCODING = "utf-8"
$env:GEMINI_API_KEY = "your_key_here"
& "C:\Python313\python.exe" scripts\embed_engine.py --from-manifest
& "C:\Python313\python.exe" scripts\embed_engine.py --stats
& "C:\Python313\python.exe" scripts\embed_engine.py --query "What experience does Scott have in software, AI, and marine operations?" --partition cv_personal
```

Then send this dispatch:

> `Claude Code: ingest was run with Python 3.13 + UTF-8 + GEMINI_API_KEY. Report whether the vector store populated cleanly.`

Note:
- `.chromadb/` is currently untracked local runtime output. Do not commit it casually.

---

## Claude Code — Backend

Done:
- `answer_source` added to `/api/chat`
- `docs/agent-contracts.md` updated with `answer_source`
- Manifest ingestion added to `scripts/embed_engine.py`
- `--from-manifest` flag added
- Section-based chunking added
- PDF extraction added
- DOCX extraction added
- Public CV corpus files are present locally

Still responsible for:
1. Confirm ingest succeeds once Scott provides a valid `GEMINI_API_KEY`
2. Review the resulting chunk count and query proof
3. Fix any runtime bug if ingest still fails after the env is correct
4. Hand Antigravity an exact QA-ready command sequence

Nice-to-have, not blocker:
- Replace deprecated `google.generativeai` with `google.genai` in a later cleanup pass
- Remove Unicode arrow output if Windows shell compatibility remains a problem without UTF-8 forcing

Do not:
- Touch `public/index.html`
- Rework frontend trust-layer behavior

---

## Antigravity — QA

Wait for this exact proof from Scott or Claude:

- manifest ingest succeeded
- `--stats` succeeded
- at least one `--query ... --partition cv_personal` succeeded

Then run these checks:

1. Preload question: `Who is Scott and what does he specialize in?`
2. Preload question: `What experience does Scott have in software, AI, and marine operations?`
3. Preload question: `What projects and business systems has Scott built?`
4. Verify retrieved chunks are section-complete, not mid-sentence fragments
5. Verify `answer_source` appears on successful `/api/chat` responses
6. Verify public question-limit behavior
7. Verify fallback honesty when retrieval is unavailable

Important note:
- The older QA docs and prompt-pack files are not present in the local repo right now, so use the checks above directly unless those docs are reintroduced by the QA lane.

Output:
- Pass or Fail report
- If fail, identify whether the defect is backend, runtime, or frontend

Do not:
- Ask Codex for UI changes unless the issue is clearly frontend-owned

---

## Codex #2 — Frontend

Status: complete. Hold.

Already built:
- trust-layer shell
- tier badge states
- source attribution pill
- fallback state shell
- preload question presentation
- business unlock visual states
- `data-testid` hooks including `source-pill`

Do not:
- edit backend files
- merge to `main`
- add more UI features before QA

Only re-enter if:
- Antigravity identifies a frontend-only bug
- Scott requests a final metadata-polish pass after QA

---

## Sequence

```text
Scott sets GEMINI_API_KEY and runs ingest with Python 3.13 + UTF-8
  → Claude Code confirms chunk/store/query proof
    → Antigravity runs QA gate
      → Codex stays on hold unless QA finds a UI issue
        → Scott approves merge
          → Netlify deploy path resumes
```

---

*For the Commons Good* 🎬
