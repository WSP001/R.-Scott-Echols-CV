# AGENT-OPS.md — R. Scott Echols CV Repo Agent Operations
**Version:** 1.1.0
**Last Updated:** 2026-04-05
**Signed by:** Claude Code (restart backup + IAM ops wiring) | Windsurf/Master (pgvector + ingest win)
**Repo:** C:\WSP001\R.-Scott-Echols-CV

> Read this file first after every reboot, branch switch, or agent session start.
> It is the single source of resume truth for this repo.

---

## MACHINE RESUME NOTE

```
STATUS: RESTART_PENDING
REASON: AMD Ryzen AI 9 HX / AMD 890 NPU driver update — 2026-04-05
REPO_WRITE_SOURCE: C:\WSP001\R.-Scott-Echols-CV (main branch, canonical)
DIRTY_FILES: CLAUDE.md | README.md | scripts/cv-smoke.ps1 (modified) | .snapshots/ | scripts/__pycache__/ | test_api_key.py (untracked)
LAST_COMMIT: e1d0f5b — docs: polished production README with badges, quickstart, and architecture
BEHIND_REMOTE: 1 commit behind origin/main — run git pull before any write
```

### Safe Resume Order (run these in sequence)

```powershell
# Step 1 — confirm you are in the right repo and state
git -C "C:\WSP001\R.-Scott-Echols-CV" status -sb
git -C "C:\WSP001\R.-Scott-Echols-CV" log --oneline -8

# Step 2 — pull latest (repo is 1 commit behind origin)
git -C "C:\WSP001\R.-Scott-Echols-CV" pull origin main

# Step 3 — read these files in order
cat MASTER_AGENT_IMPLEMENTATION_HANDOFF.md    # phase + mission
cat AGENT-OPS.md                              # this file — lane rules + blockers
cat STACK_TRUTH.md                            # Layer 1-4 canonical truth (NEW 2026-04-06)
cat DEPENDENCY_MAP.md                         # service dependency map (NEW 2026-04-06)
cat PHASE5_LIVE_STATUS_BOARD.md               # exact board state
cat plans\TEAM_ASSIGNMENT_SHEET.md            # who owns what

# Step 4 — continue ONLY in your assigned lane
```

---

## ACTIVE BLOCKERS

```
BLOCKER_1: STATUS=RED    OWNER=Scott        DESC="Run ingest with Python 3.13 + GEMINI_API_KEY — see below"
BLOCKER_2: STATUS=RED    OWNER=Antigravity  DESC="Blocked until Scott provides ingest proof (--stats + --query pass)"
BLOCKER_3: STATUS=GREEN  OWNER=Codex        DESC="Phase 5 trust-layer UI done — holding for Antigravity QA"
BLOCKER_4: STATUS=YELLOW OWNER=Scott        DESC="CV repo 1 commit behind origin/main — run git pull after restart"
```

### Ingest Command (Scott's job — COST: ~$0.01–$0.05 Gemini embeddings)

**✅ INGEST COMPLETE — 124 chunks live in pgvector on Supabase (2026-04-05)**

Smoke test result: **17/17 PASS — ALL GREEN** (Windsurf/Master session, 2026-04-05)
Chunks are durable — they survive Cloud Run restarts (pgvector + Supabase, not in-memory).

**Re-ingest guard (COST: ~$0.01–$0.05 — do NOT re-run without reason):**
```powershell
$env:VECTOR_ENGINE_URL = "https://rse-retrieval-22622354820.us-central1.run.app"
Invoke-RestMethod "$env:VECTOR_ENGINE_URL/health" | ConvertTo-Json -Compress
# chunks > 0 → SKIP. Re-ingest only if new files added or chunks = 0 after restart
```

**If re-ingest is needed (new CV files added):**
```powershell
# NEVER commit INGEST_SECRET — get value from Cloud Run console or Scott
$env:VECTOR_ENGINE_URL = "https://rse-retrieval-22622354820.us-central1.run.app"
$env:INGEST_SECRET     = "<from Cloud Run env console — ask Scott>"
python scripts\embed_engine.py --from-manifest 2>&1 | Select-Object -Last 10
```

### CV File #3 Copy Command (idempotent — COST: $0 — safe to re-run)

```powershell
Copy-Item `
  "C:\Users\Roberto002\OneDrive\Scott CV\092322CURRICULUM VITAE OF ROBERT SCOTT ECHOLS drive.docx" `
  "C:\WSP001\R.-Scott-Echols-CV\knowledge_base\public\cv\CURRICULUM VITAE OF ROBERT SCOTT ECHOLS (2) (1).docx" `
  -Force
# Verify: Test-Path "C:\WSP001\R.-Scott-Echols-CV\knowledge_base\public\cv\CURRICULUM VITAE OF ROBERT SCOTT ECHOLS (2) (1).docx"
```

---

## CURRENT PHASE

```
PHASE: 5
PHASE_STATUS: AWAITING_ANTIGRAVITY_QA
BRANCH: feat/phase5-ui-trust-layer (DO NOT merge until Antigravity 16/18 passes)
SMOKE_TEST: 17/17 PASS 2026-04-05 (live site only — trust-layer branch still needs QA)
NEXT_PHASE_GATE: Antigravity 16/18 QA pass → Scott merge approval → Netlify deploy feat/phase5-ui-trust-layer
```

---

## LANE RULES (ABSOLUTE — applies every session, no exceptions)

```
AGENTS MAY CROSS LANES TO READ.
AGENTS MAY NOT CROSS LANES TO WRITE.
```

| Agent | Lane | Owns | MUST NOT touch |
|-------|------|------|----------------|
| **Scott** | Human-Ops | env vars, keys, merge approval, phase gates | agent code |
| **Claude Code** | Backend | `api_server.py`, `scripts/`, `netlify/functions/` | `public/index.html`, trust-layer UI |
| **Codex #2** | Frontend | `public/index.html`, `src/` | backend files, `api_server.py` |
| **Antigravity** | QA | test execution, truth-serum reports | no code changes |

---

## DO NOT RESUME BLINDLY

```
⛔ Do NOT let Codex touch backend files
⛔ Do NOT let Claude Code touch public/index.html or trust-layer UI
⛔ Do NOT let Antigravity test before ingest proof exists (--stats + --query must pass first)
⛔ Do NOT merge feat/phase5-ui-trust-layer before Antigravity QA passes (16/18 threshold)
⛔ Do NOT re-run ingest without checking --stats first (wastes Gemini API budget)
⛔ Do NOT push from archive copies (OneDrive, Documents/GitHub) — WSP001 canonical only
⛔ Do NOT commit .env, raw API keys, or __pycache__/ contents
```

---

## HUMAN-OPS BLOCKER REGISTER

| Blocker | Status | Notes | Workaround |
|---------|--------|-------|-----------|
| GEMINI_API_KEY for ingest | 🔴 SCOTT ACTION | Must be set in local shell, never committed | Get from Google AI Studio |
| AWS activation | 🔴 OPEN | Phone verification stuck since 2026-03-19 | Not needed for this repo — Studio issue |
| feat/phase5-ui-trust-layer merge | 🔴 BLOCKED | Waiting on Antigravity QA | Do not merge without QA pass |
| CV repo 1 commit behind origin | 🟡 MINOR | Known state — pull after restart | `git pull origin main` |
| .chromadb/ untracked | 🟡 NOTE | Local runtime output — do not commit casually | Add to .gitignore if needed |

---

## REPO STRUCTURE (backend lane — Claude Code owns these)

```
C:\WSP001\R.-Scott-Echols-CV\
├── AGENT-OPS.md                              ← THIS FILE — resume contract
├── MASTER_AGENT_IMPLEMENTATION_HANDOFF.md    ← phase + mission (read first)
├── PHASE5_LIVE_STATUS_BOARD.md               ← exact board state
├── AGENT_HANDOFFS.md                         ← cross-lane async notes
│
├── netlify/functions/
│   └── chat.ts                               ← /api/chat edge function
│
├── scripts/
│   ├── embed_engine.py                       ← ingest engine (Claude Code)
│   └── api_server.py                         ← Cloud Run RAG server
│
├── knowledge_base/                           ← PARTITIONED — read the rules
│   ├── public/cv/                            ← public-safe (chatbot + brief export)
│   ├── business/                             ← PRIVATE — never in public brief
│   └── docs/                                 ← internal manifests + chatbot knowledge
│
└── plans/
    └── TEAM_ASSIGNMENT_SHEET.md              ← who does what, priority ranked
```

---

## PARTITION MAP (vector namespaces)

```
cv_verified_public   ← knowledge_base/public/cv/identity_verified.md
cv_projects_public   ← knowledge_base/public/cv/github_repos_live.md + seatrace pillars
seatrace_business    ← knowledge_base/business/ (NEVER in public brief or chat)
sirtrav_personal     ← personal studio work (Studio repo)
sirjames_creative    ← Sir James Adventures (creative)
internal_repos       ← AGENT_HANDOFFS.md (agent learning, not user-facing)
```

---

## TOKEN-EFFICIENT ORIENTATION

Every agent runs ONE command at session start:

```powershell
# Claude Code
cat MASTER_AGENT_IMPLEMENTATION_HANDOFF.md; cat AGENT-OPS.md; cat PHASE5_LIVE_STATUS_BOARD.md

# Scott (human check)
git status -sb; cat AGENT-OPS.md | Select-String "STATUS:|BLOCKER"
```

---

## PRODUCER BRIEF EXPORT (CV → Studio bridge)

This repo is the **truth source**. The Studio repo consumes from it.

```
knowledge_base/public/cv/ → scripts/seed-producer-brief.mjs (Studio) → artifacts/producer-brief.json
```

**Governance rule:** Only `knowledge_base/public/cv/` feeds the producer brief.
`knowledge_base/business/` is NEVER included in any public-facing output.

If adding new public CV content → add to `knowledge_base/public/cv/` only.
If adding business/SeaTrace content → add to `knowledge_base/business/` only.
They must never cross.

---

*For the Commons Good* 🎬
**Architecture: Scott Echols / WSP001 | Engineering: Claude Code | 2026-04-05**
