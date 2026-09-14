# NEXT TEAM ASSIGNMENT — 2026-04-07
<!-- machine-readable | grep-stable | repo-committed | replayable -->

**Authored by:** Claude Code (CC-IAM-OPS)
**Date:** 2026-04-07
**Phase:** 5 → 6 transition
**Repo:** C:\WSP001\R.-Scott-Echols-CV (main branch)

---

## SYSTEM STATE AT HANDOFF

```
PHASE:          5
PHASE_STATUS:   AWAITING_ANTIGRAVITY_QA
SITE_STATUS:    LIVE  — https://robertoscottecholscv.netlify.app
CLOUD_RUN:      LIVE  — https://rse-retrieval-22622354820.us-central1.run.app
VECTOR_CHUNKS:  124   — Supabase pgvector, durable
SMOKE_TEST:     17/17 PASS (2026-04-05)
BRANCH_MAIN:    CLEAN (this commit)
BRANCH_FEAT:    feat/phase5-ui-trust-layer — DO NOT merge without Antigravity QA
```

---

## LANE ASSIGNMENTS — IMMEDIATE NEXT ACTIONS

### 🔴 ANTIGRAVITY — ACTION REQUIRED (blocks Phase 5 close)

**Task:** Run 16/18 QA checklist on `feat/phase5-ui-trust-layer`

```powershell
# Step 1 — orient
git -C "C:\WSP001\R.-Scott-Echols-CV" checkout feat/phase5-ui-trust-layer
just antigravity-qa

# Step 2 — run full checklist from PHASE5_LIVE_STATUS_BOARD.md
# Pass threshold: 16/18 checks green

# Step 3 — smoke the live site (backend already passing 17/17)
just antigravity-smoke

# Step 4 — deliver proof report
just antigravity-proof-report
# Then: report PASS/FAIL + item count to Scott

# DO NOT run until PHASE5_LIVE_STATUS_BOARD.md Antigravity section is read first
cat PHASE5_LIVE_STATUS_BOARD.md
```

**Gate:** 16/18 ≥ threshold → report to Scott → Scott approves merge

---

### 🟡 SCOTT — APPROVAL NEEDED (after Antigravity QA clears)

**Task 1:** Approve trust-layer merge
```powershell
# After Antigravity delivers 16/18 PASS:
git -C "C:\WSP001\R.-Scott-Echols-CV" checkout main
git -C "C:\WSP001\R.-Scott-Echols-CV" merge feat/phase5-ui-trust-layer
git -C "C:\WSP001\R.-Scott-Echols-CV" push origin main
# Netlify auto-deploys on push to main
```

**Task 2:** Review Studio PR #29
```
URL: https://github.com/WSP001/SirTrav-A2A-Studio/pull/29
Branch: claude/stupefied-matsumoto → main
Contains: seed-producer-brief.mjs | CX-019 handoff | netlify gate | lane-check hook
```

**Task 3:** Verify Netlify env var parity
```powershell
# These must be set in Netlify dashboard (NOT in code):
# ANTHROPIC_API_KEY    → chat.ts (Claude Opus 4.6)
# GEMINI_API_KEY       → embed.ts (embeddings)
# BUSINESS_ACCESS_KEY  → verify-access.ts
# VECTOR_ENGINE_URL    → https://rse-retrieval-22622354820.us-central1.run.app
# INGEST_SECRET        → Cloud Run env (never Netlify)
```

---

### 🟢 CLAUDE CODE — STANDBY + MONITORING

**Current state:** All Phase 4–5 backend work is DONE. Holding for merge.

**Active monitoring (run anytime, $0):**
```powershell
just claude-vector-probe    # Cloud Run + pgvector health
just claude-doctor          # repo wiring
just claude-orient          # phase + blockers snapshot
```

**After trust-layer merges (Phase 6 prep):**
```powershell
# 1. Update AGENT-OPS.md phase status:
#    PHASE_STATUS: AWAITING_ANTIGRAVITY_QA → PHASE6_READY
# 2. Update STACK_TRUTH.md PHASE: 5 → 6
# 3. Update MASTER_AGENT_IMPLEMENTATION_HANDOFF.md Phase 6 gate
# 4. Wire VECTOR_ENGINE_URL for Studio if not already in Netlify env
# 5. Monitor Studio PR #29 for any backend-side conflicts
```

**DO NOT TOUCH:**
- `public/index.html` — Codex lane
- `feat/phase5-ui-trust-layer` changes — Antigravity QA in progress
- Any merge before Antigravity clears

---

### 🔵 CODEX — STANDBY

**Current state:** Trust-layer UI is complete on `feat/phase5-ui-trust-layer`. Waiting for QA.

**While waiting:**
- DO NOT push new commits to `feat/phase5-ui-trust-layer` during Antigravity QA
- Read-only: you may run `just codex-validate` and `just codex-status` anytime

**After trust-layer merges:**
- Studio PR #29 frontend items (if any survive QA)
- Phase 6: emblem harness for SeaTrace002 if Scott green-lights

---

## PROOF COMMANDS (verify system state before acting)

```powershell
# Full system state — run before any write
just cockpit

# Live cloud proof
just cv-smoke-cloud

# Claude Code skills
just claude-orient
just claude-truth-audit
just claude-proof-of-work

# QA orientation
just antigravity-qa
```

---

## PREVENTION RULES (permanent — never violate)

```
RULE_1: feat/phase5-ui-trust-layer must NOT merge without Antigravity 16/18 QA pass
RULE_2: Do not re-run ingest without checking /health chunks first ($0.01–$0.05 cost)
RULE_3: MOVE not DELETE — archive to C:\WSP001\Archives\ before removing anything
RULE_4: Archive destination OUTSIDE the source tree (no recursive nesting)
RULE_5: Never commit .env, raw API key values, or __pycache__/ contents
RULE_6: Proof = working smoke test, not "no error"
RULE_7: Two repos = two commits = two independent recovery points
```

---

## NEXT OWNER

```
NEXT_OWNER:   Antigravity
NEXT_TASK:    16/18 QA checklist — feat/phase5-ui-trust-layer
COMMAND:      just antigravity-qa → read PHASE5_LIVE_STATUS_BOARD.md → run checklist
BLOCKING:     QA gate not run — feat/phase5-ui-trust-layer held
UNBLOCKS:     Scott merge approval → Netlify deploy → Phase 6 start
```

---

*For the Commons Good* 🎬
**Architecture: Scott Echols / WSP001**
**Team assignment authored by: Claude Code (CC-IAM-OPS)**
**2026-04-07**
