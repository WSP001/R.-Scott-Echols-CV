# AGENT SKILL DISPATCH — One At A Time, Per Lane
<!-- machine-readable | grep-stable | replayable | MOVE-NOT-DELETE enforced -->
<!--
  What this file is:
  The "one-at-a-time" CLI command for each agent's specialty skill.
  Each entry is: agent → specialty → one command → what it does → accreditation.

  Why it exists:
  Agents that know their one command can cold-start without reading 800 lines.
  The justfile skill recipes are the wire harness. This is the wire label sheet.
  "Knowing where to find it again" = this file.

  Authored by: Claude Code (CC-IAM-OPS) — 2026-04-07
  For the Commons Good — reusable across all WSP001 repos
-->

---

## SYSTEM STATE AT TIME OF WRITING

```
PHASE:         5
CLOUD_RUN:     LIVE — 124 chunks, 17/17 smoke PASS
NEXT_GATE:     Antigravity 16/18 QA
ARCHIVE_RULE:  MOVE NOT DELETE — just archive-asset <file> <reason> before any structural write
```

---

## THE ONE-AT-A-TIME RULE

> Each agent has ONE entry-point command for their specialty.
> Run that one command first. Let it guide what comes next.
> Do not jump ahead. Do not skip the harness.
> The harness smells the smoke before you touch the wire.

---

## LANE 0: ACTING MASTER (Scott / Windsurf/Cascade)

**Specialty:** Governance, truth, phase approval, team orchestration

**One command:**
```bash
just master-cockpit
```

**What it does:**
- Shows branch, git status, stack truth key lines, active blockers
- Gives Scott the full governance view in < 5 seconds
- Links to NEXT_OWNER and NEXT_GATE from STACK_TRUTH.md

**When to use it:** Every session start. Before approving any merge. After any agent reports done.

**Accreditation:** `master-cockpit` — Windsurf/Cascade (Acting Master) — 2026-04-06

**Next command after:** `just master-lanes` → `just qa-ready` → approve or block

---

## LANE 1: CLAUDE CODE (Backend / Ops / Runtime)

**Specialty:** Backend scripts, edge functions, vector store, ops docs, justfile

**One command:**
```bash
just claude-orient
```

**What it does:**
- Shows repo + branch, phase status, active blockers
- Lists what Claude Code owns (write) and must NOT touch (read-only)
- Lists all available `claude-*` skill recipes

**When to use it:** Every session start. Before the first write. Before any ingest.

**Accreditation:** `claude-orient` — Claude Code (CC-IAM-OPS) — 2026-04-07

**One command per specialty task:**

| Specialty Task | Command | Accreditation |
|---|---|---|
| Session start / orient | `just claude-orient` | CC-IAM-OPS 2026-04-07 |
| Before ingest — verify truth | `just claude-truth-audit` | CC-IAM-OPS 2026-04-07 |
| After ticket done — prove it | `just claude-proof-of-work` | CC-IAM-OPS 2026-04-07 |
| Repo wiring check ($0) | `just claude-doctor` | Windsurf 2026-04-06 |
| Cloud Run health ($0) | `just claude-vector-probe` | Windsurf 2026-04-06 |
| Env var presence ($0) | `just claude-env-check` | Windsurf 2026-04-06 |
| Archive before rewrite | `just archive-asset <file> "<reason>"` | CC-IAM-OPS 2026-04-07 |
| See all archived assets | `just archive-list` | CC-IAM-OPS 2026-04-07 |

**Sequence for a typical Claude Code session:**
```bash
# Step 1 — orient
just claude-orient

# Step 2 — smell the smoke
just claude-doctor
just claude-vector-probe

# Step 3 — archive BEFORE any structural change
just archive-asset <file-you-are-about-to-change> "<ticket-id: reason>"

# Step 4 — do the work (write in your lane only)

# Step 5 — prove it
just claude-proof-of-work

# Step 6 — commit
git add <cc-lane-files-only>
git commit -m "ops(claude-code): <what + why> [TICKET-ID]"
```

---

## LANE 2: CODEX #2 (Frontend / UI Shell / Accessibility)

**Specialty:** public/index.html, public/assets/, static HTML shell

**One command:**
```bash
just codex-validate
```

**What it does:**
- Checks index.html line count
- Finds `[bracket placeholder]` stale content (the fires to fix)
- Checks Three.js references (IcosahedronGeometry, TorusGeometry, THREE.)

**When to use it:** Every session start. Before adding any new UI feature. After any index.html edit.

**Accreditation:** `codex-validate` — Windsurf/Cascade (original) — extended recipe reference 2026-04-07

**One command per specialty task:**

| Specialty Task | Command | Accreditation |
|---|---|---|
| Session start / validate | `just codex-validate` | Windsurf original |
| Read backend API contracts | `just codex-read-contracts` | Windsurf original |
| Read QA test surface | `just codex-read-qa` | Windsurf original |
| Run Python batch edit helper | `just codex-upgrade` | Windsurf original |
| Preview site locally | `just codex-preview` | Windsurf original |
| Frontend status summary | `just codex-status` | Windsurf 2026-04-06 |
| **Archive before rewrite** | **`just archive-asset public/index.html "<reason>"`** | **CC-IAM-OPS 2026-04-07 — MANDATORY** |
| Run interview harness | `cat plans/CODEX_INTERVIEW_PROMPT.md` | Windsurf 2026-04-10 |

**Sequence for a typical Codex session:**
```bash
# Step 1 — read before write (MANDATORY — all three in order)
just contracts          # API contracts between lanes
just handoffs           # cross-lane notes
just codex-read-contracts

# Step 2 — smell the smoke
just codex-validate     # find bracket placeholders = fires to fix

# Step 3 — ARCHIVE before any structural rewrite (MANDATORY)
just archive-asset public/index.html "CX-NNN: reason for this change"

# Step 4 — do the work (public/index.html and public/assets/ ONLY)

# Step 5 — validate again
just codex-validate

# Step 6 — report to Antigravity
# Write handoff note to AGENT_HANDOFFS.md before done
just handoff-note Codex antigravity "CX-NNN complete — ready for QA"
```

**DO NOT TOUCH:**
```
scripts/          → Claude Code lane
netlify/          → Claude Code lane
tests/            → Antigravity lane
e2e/              → Antigravity lane
justfile          → Acting Master + Claude Code lane
```

---

## LANE 3: ANTIGRAVITY (QA / Verification / Proof of Work)

**Specialty:** Test execution, pass/fail reporting, smoke tests, E2E

**One command:**
```bash
just antigravity-qa
```

**What it does:**
- Shows git status, current branch
- Reads phase status and next gate from STACK_TRUTH.md
- Shows last verification timestamps from STACK_TRUTH.md
- Tells Antigravity exactly what to verify and what passes/fails

**When to use it:** Every QA session start. Before writing any test. Before reporting to Scott.

**Accreditation:** `antigravity-qa` — Windsurf/Cascade (Acting Master) — 2026-04-06

**One command per specialty task:**

| Specialty Task | Command | Accreditation |
|---|---|---|
| Session start / QA orient | `just antigravity-qa` | Windsurf 2026-04-06 |
| Cloud smoke from QA lane | `just antigravity-smoke` | Windsurf 2026-04-06 |
| Proof report snapshot | `just antigravity-proof-report` | Windsurf 2026-04-06 |
| Read both lanes before writing test | `just qa-read-all` | Windsurf original |
| Run unit tests | `just test` | Windsurf original |
| Run chat E2E | `just test-e2e-chat` | Windsurf original |
| Run all tests | `just test-all` | Windsurf original |
| QA report | `just qa-report` | Windsurf original |
| Is repo QA-ready? | `just qa-ready` | Windsurf 2026-04-06 |

**Sequence for a typical Antigravity QA session:**
```bash
# Step 1 — read BOTH other lanes BEFORE writing any test (MANDATORY)
just qa-read-all

# Step 2 — orient
just antigravity-qa

# Step 3 — smoke the live services
just antigravity-smoke

# Step 4 — run tests
just test-all

# Step 5 — report
just antigravity-proof-report
# Then: report PASS/FAIL count to Scott via AGENT_HANDOFFS.md or direct message

# DO NOT:
# - write tests asserting against API shapes you haven't read in netlify/edge-functions/
# - call real Anthropic/Gemini APIs in tests (mock required)
# - write files in scripts/ netlify/ public/ (wrong lane)
```

**Current assignment (Phase 5):**
```bash
# Checkout the branch under QA
git checkout feat/phase5-ui-trust-layer

# Run the 16/18 QA checklist
cat plans/PHASE5_LIVE_STATUS_BOARD.md  # read the checklist first
just antigravity-qa                     # then run QA orient
just antigravity-smoke                  # cloud smoke

# Report 16/18 or final count to Scott
```

---

## ARCHIVE LANE (ALL AGENTS — non-negotiable)

**Specialty:** Preserving the Library of Assets — historical codebase evolution

**One command (run before ANY structural rewrite):**
```bash
just archive-asset <FILE> "<REASON>"
```

**Example:**
```bash
just archive-asset public/index.html "CX-019: phase5 trust-layer refactor"
just archive-asset scripts/embed_engine.py "CC-M10: migrating from ChromaDB to pgvector"
just archive-asset docs/agent-contracts.md "updating /retrieve endpoint shape for Phase 6"
```

**What it creates:**
```
archive/
  inspirational_scripts/
    20260407_143052/
      index.html        ← the preserved copy
      reason.txt        ← REASON, SOURCE, DATE, ARCHIVED_BY, GIT_BRANCH, GIT_COMMIT
```

**See your archive:**
```bash
just archive-list       # full Library of Assets index with reasons
```

**The rule:** No agent may overwrite or delete a structural file without first running `archive-asset`.
This is the physical enforcement of MOVE NOT DELETE.
The archive grows. History is preserved. Nothing is lost to "I'll just delete it."

**Accreditation:** Acting Master directive → Claude Code implementation (CC-IAM-OPS) — 2026-04-07

---

## THE WIRE HARNESS — HOW ALL LANES CONNECT

```
Scott (Master) ──────────────────────── just master-cockpit
         │ approves phase gates
         ▼
Claude Code ──────────────────────────── just claude-orient
         │ backend + ops + ingest        just claude-truth-audit
         │ wires the retrieval path      just claude-proof-of-work
         │ maintains justfile skills     just archive-asset (before rewrites)
         ▼
Codex #2 ─────────────────────────────── just codex-validate
         │ frontend shell + UI           just codex-read-contracts (READ FIRST)
         │ reads CC contracts            just archive-asset (MANDATORY before rewrite)
         ▼
Antigravity ──────────────────────────── just antigravity-qa
         │ QA + proof of work            just antigravity-smoke
         │ reads BOTH other lanes        just antigravity-proof-report
         ▼
Scott (Master) ──────────────────────── merge approval → Netlify deploy
```

**The smoke detector is `just preflight`.
The safety wire is `just archive-asset`.
The proof wire is `just claude-proof-of-work` / `just antigravity-proof-report`.
When all wires are live and preflight passes — the harness is connected.**

---

## WHAT "ACCREDITATION" MEANS IN THIS SYSTEM

Each justfile recipe carries attribution:
- **Who created it** (agent + date in the comment header)
- **What lane it belongs to** (the prefix: `claude-*`, `codex-*`, `antigravity-*`, `master-*`)
- **What it proves** (the output is the proof)

This is how skill work gets recorded permanently in the repo:
```
Windsurf/Cascade  →  master-cockpit, claude-doctor, antigravity-qa, verify-all
Claude Code       →  claude-orient, claude-truth-audit, claude-proof-of-work, archive-asset
Codex #2          →  public/index.html trust-layer (CX-019)
Antigravity       →  16/18 QA checklist (Phase 5 gate)
```

The justfile is the accreditation ledger. The skill recipe is the attribution.

---

## FINDING IT AGAIN

When you need to find a skill next time:
```bash
just --list                      # all available recipes grouped
grep "LANE:" justfile            # find lane boundaries
grep "Attribution" justfile      # find who wrote what and when
cat plans/AGENT_SKILL_DISPATCH-2026-04-07.md   # this file — one-at-a-time dispatch
```

---

*For the Commons Good* 🎬
**Architecture: Scott Echols / WSP001**
**Authored by: Claude Code (CC-IAM-OPS) — 2026-04-07**
