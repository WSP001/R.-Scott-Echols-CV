# Phase 5 Live Status Board
> Last updated: 2026-04-05 — updated after AMD/NPU restart backup pass
> Previous update: 2026-03-20
> Branch: `feat/phase5-ui-trust-layer`
> Rule: Each agent reads only their own section.

---

## ⚡ MACHINE RESTART NOTE — 2026-04-05

```
STATUS: RESTART_PENDING
REASON: AMD Ryzen AI 9 HX / AMD 890 NPU driver update
REPO_STATE: DIRTY — CLAUDE.md | README.md | scripts/cv-smoke.ps1 modified; .snapshots/ | __pycache__/ | test_api_key.py untracked
BEHIND_REMOTE: 1 commit — run git pull origin main after restart BEFORE any write
```

**After restart, run in order:**
1. `git -C "C:\WSP001\R.-Scott-Echols-CV" pull origin main`
2. `cat AGENT-OPS.md` — read lane rules and blockers
3. `cat PHASE5_LIVE_STATUS_BOARD.md` — read this file for board state
4. Check ingest cost guard below BEFORE running embed_engine.py

---

---

## Current Truth — 2026-04-05 UPDATE (Windsurf/Master session)

```
CLOUD_RUN:    https://rse-retrieval-22622354820.us-central1.run.app
STATUS:       ok
CHUNKS:       124 (durable — pgvector on Supabase, survives restarts)
BACKEND:      pgvector
TABLE:        wsp001_knowledge
SMOKE_TEST:   17/17 PASS — ALL GREEN (live site robertoscottecholscv.netlify.app)
INGEST:       ✅ COMPLETE — 124 chunks via embed_engine.py --from-manifest
VECTOR_URL:   Set in Netlify for CV site ✅ | Verify sirtrav-a2a-studio ⚠️
```

**What Windsurf proved (best-case session pattern to replay):**
1. `psycopg.connect()` to Supabase requires `?sslmode=require` on the connection string
2. Local test first — `python -c "import psycopg; conn = psycopg.connect(...)"` — before debugging Cloud Run
3. `echo | gcloud secrets versions add` adds trailing whitespace — use direct `--set-env-vars` for critical secrets
4. When Cloud Run drops env vars: `--remove-secrets` first, then `--set-env-vars` for the value
5. Health endpoint shows wrapper error — get real Python exception from `gcloud logging read`
6. After INGEST_SECRET was dropped → 0 chunks pushed; restored → 124 chunks in one run

**What changed from old board:**
- ~~BLOCKED_ON_INGEST~~ → ✅ INGEST DONE
- ~~GEMINI_API_KEY missing~~ → ✅ Set in Cloud Run env vars
- ~~DATABASE_URL without SSL~~ → ✅ Fixed with `?sslmode=require` direct env var
- Smoke test: previously untested → ✅ 17/17 PASS including RAG — CV Corpus

**Previous board truth (still valid):**
- Phase 5 trust-layer UI built on `feat/phase5-ui-trust-layer`
- `answer_source` wired into `/api/chat`
- Manifest-based ingest wired into `scripts/embed_engine.py`
- All 3 public CV files present in `knowledge_base/public/cv/`

---

## Ingest Cost Guard — READ BEFORE RUNNING INGEST

**COST: ~$0.01–$0.05 per full run (Gemini text-embedding-004). Do NOT re-run casually.**

Check if already done first:

```powershell
& "C:\Python313\python.exe" scripts\embed_engine.py --stats
```

- If output shows **>0 documents** in `cv_personal` partition → **SKIP re-ingest** — already done.
- Re-ingest **only if**: new CV file added, schema changed, or `--stats` shows 0 docs.

---

## Current Blocker — UPDATED 2026-04-05

**Previous blocker (RESOLVED):** Scott running ingest with GEMINI_API_KEY
**Current blocker:** Antigravity QA — run 16/18 checklist against live trust-layer branch

```
NEXT ACTION: Antigravity — run QA gate
COMMAND:     See Antigravity section below
THRESHOLD:   16/18 pass
UNBLOCKS:    Scott merge approval → Netlify deploy feat/phase5-ui-trust-layer
```

**Verify live system before QA (costs $0, read-only):**
```powershell
$r = Invoke-RestMethod "https://rse-retrieval-22622354820.us-central1.run.app/health" -TimeoutSec 15
Write-Host "STATUS: $($r.status) | CHUNKS: $($r.chunks) | DURABLE: $($r.durable)"
# Expected: STATUS: ok | CHUNKS: 124+ | DURABLE: True
```

---

## Board

| Agent | Status | Blocker |
|-------|--------|---------|
| **Scott** | ✅ UNBLOCKED | Ingest complete. Next: set `VECTOR_ENGINE_URL` in Netlify for sirtrav-a2a-studio if not done |
| **Windsurf/Master** | ✅ WIN — DONE | pgvector healthy, 124 chunks durable, smoke test 17/17 PASS |
| **Claude Code** | ✅ COMPLETE / STANDBY | All code done. Waiting for Antigravity QA result |
| **Antigravity** | 🔴 ACTION REQUIRED | Run 16/18 QA checklist NOW — ingest proof exists, live system is ready |
| **Codex #2** | 🟢 DONE / HOLD | Waiting on Antigravity QA pass before merge |

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
