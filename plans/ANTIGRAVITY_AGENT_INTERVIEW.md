# ANTIGRAVITY AGENT INTERVIEW — Commons Good Manifest

> Architecture → Scott Echols / WSP001 (For the Commons Good)
> QA Gate → Antigravity

---

## Pre-Interview Metadata

```yaml
agent_name: Antigravity
platform: Google DeepMind Antigravity (Gemini-based)
model: Gemini 2.5 Pro (Advanced Agentic Coding)
repo_or_worktree: C:\WSP001\R.-Scott-Echols-CV
secondary_repo: C:\WSP001\SirTrav-A2A-Studio (read-only cross-reference)
rails_allowed: cold (QA reads cold rail; promotes to hot ONLY with explicit Master approval)
skills: browser-qa, live-site-verification, console-inspection, chat-interaction-testing, trust-layer-audit, deploy-diagnostic, proof-report-generation, RAG-grounding-validation
last_active_run_id: run_2026-04-07_002 (Phase 5 QA v2.1 — 18/18 PASS)
```

---

## SECTION 1: Universal CLI & Workspace Questions

### Q1. What is the exact command you run to validate manifest before any run, and what JSON manifest shape do you expect?

**Honest answer:** I don't currently have a `manifest.yaml` or `just validate-manifest` recipe. My validation is manual: I read `STACK_TRUTH.md`, `DEPENDENCY_MAP.md`, and `AGENT-OPS.md` in that order. The shape I expect is:

```yaml
# What I SHOULD validate against (proposed manifest shape)
run_id: run_YYYY-MM-DD_NNN
agent: antigravity
phase: 5
target_url: https://agent-69d43ad5f30b187eac00--robertoscottecholscv.netlify.app
checklist_threshold: 16/18
checks_required:
  - infrastructure_smoke
  - trust_layer_ui
  - rag_grounding
  - question_limit_gate
  - console_errors
approval_status: pending | approved | denied
cost_estimate: $0
```

**Gap:** No manifest.yaml exists yet. This interview should produce the spec for one.

### Q2. What is your first read order when entering a workspace?

```text
1. C:\WSP001\R.-Scott-Echols-CV\AGENT-OPS.md          → blockers, phase, lane rules
2. C:\WSP001\R.-Scott-Echols-CV\STACK_TRUTH.md         → system status, env vars, proof paths
3. C:\WSP001\R.-Scott-Echols-CV\DEPENDENCY_MAP.md      → service graph, what talks to what
4. C:\WSP001\R.-Scott-Echols-CV\PHASE5_LIVE_STATUS_BOARD.md → current phase checklist
5. C:\WSP001\R.-Scott-Echols-CV\plans\                 → any handoff docs or prior QA reports
6. git log --oneline -5                                → what changed since I last ran
```

### Q3. Which justfile recipes do you always run before touching code, and in what sequence?

```text
1. just antigravity-qa        → load the 18-item QA checklist (repo state + cloud health)
2. just antigravity-smoke      → probe Cloud Run /health and Netlify HTTP 200
3. just antigravity-proof-report → generate snapshot from STACK_TRUTH timestamps
```

**Important:** I do NOT run `claude-*` or `codex-*` recipes. Lane discipline — read across lanes, never write across lanes.

### Q4. How do you ensure you never write to a HOT rail without explicit human approval?

**My rule:** I am QA-only. I produce pass/fail reports and merge recommendations. I never:
- Edit `public/index.html` (Codex lane)
- Edit `netlify.toml`, `netlify/edge-functions/*`, or `scripts/*` (Claude lane)
- Create or modify branches (Master lane)
- Push to git (Master lane)

**The only files I write:**
- `plans/ANTIGRAVITY_QA_PROOF_REPORT_*.md` — QA reports in the repo
- Artifacts in my brain directory (screenshots, recordings, diagnostics)

**HOT rail promotion:** I report "RECOMMEND MERGE" or "DENY MERGE" — Scott (Master) executes. I never promote automatically.

### Q5. When you create outputs or artifacts, what filenames and folders do you write to?

```text
REPO OUTPUTS (auditable by all agents):
  C:\WSP001\R.-Scott-Echols-CV\plans\ANTIGRAVITY_QA_PROOF_REPORT_PHASE5.md
  C:\WSP001\R.-Scott-Echols-CV\plans\ANTIGRAVITY_AGENT_INTERVIEW.md (this file)

BRAIN OUTPUTS (session-specific, not in repo):
  C:\Users\Roberto002\.gemini\antigravity\brain\<conversation-id>\
    ANTIGRAVITY_QA_PROOF_REPORT.md
    STUDIO_DEPLOY_FAILURE_DIAGNOSTIC.md
    phase5_qa_test_*.webp (browser recordings)
    phase5_q2_q3_limit_*.webp (browser recordings)
    .system_generated\click_feedback\*.png (verification screenshots)
```

### Q6. How do you log cost and approval status after a run?

**Current state — honest:** I don't write a `cost.json` or `approval.log`. I embed cost in the proof report header.

**What I SHOULD log (proposed):**

```json
{
  "run_id": "run_2026-04-07_002",
  "agent": "antigravity",
  "cost_actual": "$0.00",
  "cost_reason": "No API calls — browser testing + file reads only",
  "approval_status": "recommended_merge",
  "approval_conditions": ["Claude Code fixes CSP font-src"],
  "timestamp": "2026-04-07T01:25:33Z"
}
```

### Q7. Where do you store pointers that future runs can reuse?

**Current:** I don't have a `pointers.yaml`. My "pointers" are embedded in the proof report:
- Deploy preview URL
- Cloud Run health endpoint URL
- Branch name
- Commit hash
- Screenshot paths

**Proposed pointers.yaml format:**

```yaml
run_id: run_2026-04-07_002
agent: antigravity
pointers:
  deploy_preview: https://agent-69d43ad5f30b187eac00--robertoscottecholscv.netlify.app
  cloud_run_health: https://cv-vector-api-867263134402.us-central1.run.app/health
  branch_tested: feat/phase5-ui-trust-layer
  commit_on_main: bd5d735
  proof_report: plans/ANTIGRAVITY_QA_PROOF_REPORT_PHASE5.md
  screenshots:
    - .system_generated/click_feedback/click_feedback_1775524765208.png
    - .system_generated/click_feedback/click_feedback_1775525068397.png
  recordings:
    - phase5_qa_test_1775523543984.webp
    - phase5_q2_q3_limit_1775524517729.webp
  reuse_recommended: true
```

### Q8. What CLI command do you use to query vector memory for context before answering?

**Honest:** I don't currently query the vector store directly. My RAG verification is end-to-end: I click a preload question in the chat widget and verify the response is grounded. I test the retrieval pipeline from the user's perspective, not from the backend.

**What I could use:** `curl https://cv-vector-api-867263134402.us-central1.run.app/retrieve -d '{"query":"Four Pillars","k":3}'` — but that's Claude Code's diagnostic tool, not mine.

### Q9. What is your policy when a command fails midway?

```text
1. DOCUMENT the failure (exact error, exact step)
2. REPORT the failure in the proof report (mark check as FAIL with evidence)
3. DO NOT attempt to fix it (not my lane)
4. DO NOT retry silently (that hides bugs)
5. RECOMMEND which lane should fix it
6. CONTINUE testing other checks that don't depend on the failed step
```

**Example from this session:** v1.0 tested the wrong target → I documented the miss honestly, did NOT pretend it passed, reran as v2.0 against the correct target.

### Q10. What tooling do you run to confirm you didn't break shared workspaces?

```text
1. git status → confirm no untracked changes outside plans/
2. git diff → confirm I only wrote to plans/ directory
3. I never modify files outside my lane
4. I never push to git
5. My proof reports are additive-only (new files, never overwrite source)
```

---

## SECTION 2: Antigravity-Specific Questions

### Q11. What is your QA-only mission scope prompt pattern?

```text
SCOPE: QA gate for Phase {N} on branch {branch_name}
TARGET: {deploy_preview_url}
THRESHOLD: {pass_count}/{total_count}
CHECKLIST: {list of specific checks}
OUTPUT: Pass/fail table + merge recommendation
LANE RULE: Read all lanes, write only to plans/
NEVER: Fix code, edit config, push commits, touch edge functions
```

### Q12. What CLI or script do you run to produce verify.md?

**Current:** I don't produce `runs/<run_id>/verify.md` — I produce `plans/ANTIGRAVITY_QA_PROOF_REPORT_PHASE5.md` directly.

**Proposed mapping to the manifest system:**

```text
Input:  just antigravity-qa → reads STACK_TRUTH.md + PHASE5 board
Do:     Browser tests (navigate, click, read, screenshot, console)
Output: runs/run_2026-04-07_002/verify.md
Update: runs/run_2026-04-07_002/manifest.yaml (approval_decision field)
```

### Q13. How do you read prior runs before making safety checks?

```text
1. Read plans/ANTIGRAVITY_QA_PROOF_REPORT_*.md (my own prior reports)
2. Read MASTER_AGENT_IMPLEMENTATION_HANDOFF.md (what phases are complete)
3. Read git log (what teammates committed since my last run)
4. Read PHASE5_LIVE_STATUS_BOARD.md (current phase checklist)
5. Check AGENT-OPS.md for active blockers
```

### Q14. Quality gates — in order:

| # | Gate | How I Check | Tool |
|---|------|-------------|------|
| 1 | `build_status` | Netlify HTTP 200 on deploy preview | `read_url_content` |
| 2 | `cloud_health` | Cloud Run `/health` returns `{"status":"ok","chunks":N}` | `read_url_content` |
| 3 | `rag_grounding` | Click preload Qs → verify specific domain content returned | `browser_subagent` |
| 4 | `trust_layer_ui` | Verify badges, source pills, counter, trust note | `browser_subagent` |
| 5 | `question_limit` | Send 3 Qs → verify Q4 triggers gate | `browser_subagent` |
| 6 | `negative_key_test` | Enter wrong key → verify rejection message | `browser_subagent` |
| 7 | `console_errors` | Open DevTools → count CSP/JS errors | `browser_subagent` |
| 8 | `cost_bounds` | $0 for QA (no API calls, browser-only) | Manual |
| 9 | `security_clear` | No secrets in console, no exposed env vars | `browser_subagent` |
| 10 | `data_integrity` | Response matches CV corpus (specific names, dates, patents) | Read response text |

### Q15. When trust_promotion=true, where do you copy files?

```text
I do NOT copy files to HOT rail automatically.
My promotion path:
  1. Write: plans/ANTIGRAVITY_QA_PROOF_REPORT_PHASE{N}.md
  2. Set: recommendation = "APPROVE" in report
  3. Report to Master: "RECOMMEND MERGE — {score}/{threshold} PASS"
  4. Master (Scott) executes: git merge, git push
  5. Netlify auto-deploys on push to main → that IS the HOT rail promotion

HOT rail = main branch deployed on Netlify
COLD rail = feature branch deploy preview
Promotion = Master merges branch → Netlify deploys
```

### Q16. How do you handle failures?

```text
MODE: report-only (never rollback, never partial commit)

On check failure:
  1. Mark check as ❌ FAIL in proof report with exact evidence
  2. Continue testing remaining checks (don't abort early)
  3. Calculate final score
  4. If score < threshold → recommendation = "DENY MERGE"
  5. If score >= threshold → recommendation = "CONDITIONAL MERGE" with blockers listed
  6. Assign fix to correct lane owner

I never:
  - Abort silently
  - Skip failed checks without recording them
  - Auto-fix and retest (that's not QA, that's engineering)
```

### Q17. Log format for approvals and trust promotion:

```yaml
# Proposed standard format
run_id: run_2026-04-07_002
agent: antigravity
phase: 5
target: feat/phase5-ui-trust-layer
deploy_url: https://agent-69d43ad5f30b187eac00--robertoscottecholscv.netlify.app
score: 18/18
threshold: 16/18
recommendation: CONDITIONAL_MERGE
conditions:
  - owner: claude-code
    fix: "Add cdn.fontshare.com to CSP font-src in netlify.toml"
    status: COMPLETED (commit 4598cad)
trust_promotion:
  ready: true
  promoted_by: Scott (Master)
  promoted_at: pending
  method: git merge feat/phase5-ui-trust-layer → main
timestamp: 2026-04-07T01:25:33Z
attribution: "Architecture → Scott Echols / WSP001 (For the Commons Good)"
```

---

## SECTION 3: Cross-Agent Questions

### Q18. Edit in-place vs draft files first?

**Rule:** I never edit in-place. I create new files only (`plans/ANTIGRAVITY_*.md`). My outputs are always additive — they don't modify existing source, config, or docs.

### Q19. How do I structure diffs?

I don't produce diffs. My output is proof reports (pass/fail tables with evidence). If I need to show what changed, I reference git commit hashes and let the reader `git show <hash>`.

### Q20. How do I avoid edits that affect teammates' worktrees?

```text
1. NEVER write to: public/, netlify/, scripts/, src/, *.toml, *.ts, *.json
2. NEVER push to git
3. ONLY write to: plans/ (repo-tracked QA reports)
4. Lane prefix: antigravity-* commands only
5. Cross-lane reads are fine; cross-lane writes are forbidden
```

### Q21. What single file records who owns a worktree?

`AGENT-OPS.md` — contains lane assignments, active blockers, and the resume order.

### Q22. How do I document "where to look next"?

In the proof report footer:
```text
NEXT MOVES:
1. Claude Code → [specific fix needed]
2. Scott → [approval/merge action]
3. Antigravity → [what to test next phase]
```

### Q23. Where do I write successful paths for reuse?

Currently in `plans/ANTIGRAVITY_QA_PROOF_REPORT_PHASE5.md`. Proposed: `runs/<run_id>/pointers.yaml` with `reuse_recommended: true`.

---

## SECTION 4: Antigravity Quality Gate JSON Response

```json
{
  "agent_name": "Antigravity",
  "platform": "Google DeepMind Antigravity",
  "model": "Gemini 2.5 Pro (Advanced Agentic Coding)",
  "worktree_path": "C:\\WSP001\\R.-Scott-Echols-CV",
  "rails_run": "cold",
  "checks": {
    "build_status": "pass",
    "cost_within_bounds": "pass",
    "data_integrity": "pass",
    "security_clear": "pass",
    "data_proof": "pass"
  },
  "recommendation": "approve",
  "approval_decision": "approved",
  "trust_promotion_ready": true,
  "artifacts_written": [
    "plans/ANTIGRAVITY_QA_PROOF_REPORT_PHASE5.md",
    "plans/ANTIGRAVITY_AGENT_INTERVIEW.md"
  ],
  "hot_rail_path": "main branch → Netlify auto-deploy",
  "successful_paths": [
    {
      "agent_sequence": [
        "claude-code:CSP-fix:4598cad",
        "claude-code:skills+truth:bd5d735",
        "antigravity:phase5-qa:18/18",
        "claude-code:studio-build-gate:461df110"
      ],
      "reuse_recommended": true
    }
  ],
  "next_human_decision": "Scott → merge feat/phase5-ui-trust-layer to main"
}
```

---

## SECTION 5: Known Gaps — What I Don't Have Yet

| Gap | What's Missing | Proposed Fix |
|-----|---------------|-------------|
| No `manifest.yaml` | No machine-readable run manifest | Create `runs/` directory + YAML schema |
| No `pointers.yaml` | No reusable pointer file for next agent | Add to proof report generation |
| No `cost.json` | Cost not logged separately | Add to `just antigravity-proof-report` |
| No `verify.md` format | Reports are freeform markdown | Standardize header + checks + JSON block |
| No vector store query | Can't query RAG backend directly | Not needed for QA (end-to-end testing is better) |
| No `rail-policy.yaml` | No formal rail policy file | Create in repo root |
| No `brain-claim` lock | No worktree claim mechanism | Add to justfile |

---

## Current Board Status (as of interview date)

| Item | Status | Commit |
|------|--------|--------|
| CV Phase 5 QA | ✅ 18/18 PASS | Report in plans/ |
| CV CSP fix | ✅ DONE | `4598cad` |
| CV truth update | ✅ DONE | `bd5d735` |
| CV RAG chunks | ✅ 124→166 | `551662e` |
| CV Phase 5 merge | ⏳ AWAITING Scott | — |
| Studio build-gate fix | ✅ DONE | `461df110` |
| Studio PR #29 | ✅ MERGED | `382e8112` |
| Studio site live | ✅ HTTP 200 | sirtrav-a2a-studio.netlify.app |

---

*Architecture → Scott Echols / WSP001 (For the Commons Good)*
*QA Gate → Antigravity*
*Interview Date: 2026-04-08*
