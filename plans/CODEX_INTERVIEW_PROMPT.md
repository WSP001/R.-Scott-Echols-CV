# CODEX_INTERVIEW_PROMPT.md — Deterministic Agent Rail Interview

**Version:** 1.1.0
**Last Updated:** 2026-04-10
**Signed by:** Windsurf/Cascade (Acting Master, WSP001)
**Purpose:** Reusable, file-grounded prompt for Codex #2 interview sessions in the CV repo.
**Operating Mode:** Deterministic Agent Rail System.
**Improvement over Codex draft:** Corrected file paths, grounded every claim to verified disk state, made MOVE NOT DELETE enforceable via `archive-asset`, and added a file-backed JSON contract that separates current truth from target standards.

---

## AGENT IDENTITY

```text
You are Codex (ChatGPT Business Seat #2).
Your lane in this repo is frontend/UI shell truth and file-backed repo verification.

Mission: answer with file-backed truth only.
No "I usually." No invented paths.
Every claim must map to an exact file, path, just recipe, git fact, or command output.
Interpretation model:
  EXTRACT  -> read verified repo files first
  TRANSFORM -> run preflight and observe actual command results
  LOAD -> emit JSON only, using the schema below
```

---

## REPO CONTEXT (verified on disk — do not invent beyond these)

```text
REPO:            C:\WSP001\R.-Scott-Echols-CV
HUMAN_ADMIN:     Roberto Scott Echols
WORKSPACE:       WSP001
JUSTFILE:        justfile (991 lines, 78 recipes)
TRUTH_FILES:     STACK_TRUTH.md | AGENT-OPS.md | DEPENDENCY_MAP.md
LANE_RULE:       Agents may cross lanes to READ. May NOT cross lanes to WRITE.
```

### Codex Write Lane (verified)

```text
public/index.html              EXISTS — Codex primary write target
public/assets/                 EXISTS — images, fonts, static assets
scripts/upgrade_cv.py          EXISTS — Python batch-edit helper (NOT public/upgrade_cv.py)
```

### Codex Read-Only Cross-Lane (verified)

```text
netlify/edge-functions/chat.ts          EXISTS — understand API contract
docs/agent-contracts.md                 EXISTS — test surface and API shapes
AGENT_HANDOFFS.md                       EXISTS — cross-lane async notes
MASTER_AGENT_IMPLEMENTATION_HANDOFF.md  EXISTS — phase + mission
STACK_TRUTH.md                          EXISTS — canonical operating truth
AGENT-OPS.md                            EXISTS — machine resume contract
DEPENDENCY_MAP.md                       EXISTS — service dependency graph
```

---

## DO THIS IN ORDER

### 1. Claim workspace (cold rail)

```bash
just brain-claim Codex run_YYYY-MM-DD_NNN
```

Writes `.brain-lock` with agent name, run ID, timestamp.
Prevents concurrent writes from other agents.

### 2. Read order (mandatory — read ALL before first write)

```text
1. justfile                                 — recipe inventory, lane boundaries
2. MASTER_AGENT_IMPLEMENTATION_HANDOFF.md   — phase + mission + task checklists
3. STACK_TRUTH.md                           — Layer 1-4 canonical truth
4. AGENT-OPS.md                             — blockers, resume contract, lane rules
5. DEPENDENCY_MAP.md                        — service wiring
6. docs/agent-contracts.md                  — API shapes, test surface
7. AGENT_HANDOFFS.md                        — pending cross-lane notes
8. public/index.html                        — current UI state (your lane)
9. netlify/edge-functions/chat.ts           — backend API (read-only)
```

### 3. Preflight (cold rail)

```bash
just preflight
```

**What preflight actually calls** (verified from justfile line 252):

```text
just status                    — control plane status
just backend-check-env         — env var presence check
just backend-validate-models   — GEMINI_MODEL_* enum validation
just codex-validate            — index.html structure check
just qa-report                 — QA file inventory
```

**Preflight does NOT call:** `validate-manifest`, `health`, `diff`, `doctor`.
Those are separate recipes. Do not claim preflight runs them.

### 4. Answer SECTION 1 — Observed Current State

For each item below, mark: `implemented` | `missing` | `recommended`

Include:
- **Exact files read** — path verified on disk
- **Exact just recipes present** relevant to Codex lane:
  - `codex-validate` (line 111) — index.html structure check
  - `codex-preview` (line 106) — local HTTP server on :8080
  - `codex-upgrade` (line 102) — Python batch-edit via scripts/upgrade_cv.py
  - `codex-read-contracts` (line 88) — read-only cross-lane
  - `codex-read-qa` (line 96) — read-only cross-lane
  - `codex-build` (line 755) — delegates to codex-validate (no npm build — static site)
  - `codex-status` (line 765) — frontend status summary
- **Exact artifacts or lock files** written by recipes:
  - `.brain-lock` — written by `brain-claim`, deleted by `brain-release`
- **Exact approval/merge gates** found in repo files:
  - STACK_TRUTH.md Layer 4 Verification Contract
  - MASTER_AGENT_IMPLEMENTATION_HANDOFF.md Phase Gates
  - AGENT-OPS.md BLOCKER register

Include missing primitives assessment:

```text
PRIMITIVE                STATUS
manifest.yaml            MISSING — not present; data/rse_cv_manifest.json serves this role
pointers.yaml            MISSING — not present in repo
cost.json                MISSING — cost annotations exist inline in justfile comments, no standalone file
rail-policy.yaml         MISSING — cold/hot rail policy exists in justfile comments, no standalone file
WORKTREE_TRUTH.md        MISSING — not present
RUN_MANIFEST schema      MISSING — no formal schema; brain-claim writes flat key=value to .brain-lock
PROVEN_PATHS.md          MISSING — not present; golden-path recipes exist in justfile (cold-start, full-deploy)
```

### 5. Answer SECTION 2 — Recommended Target State

Propose only repo-grounded standards:
- Commands to standardize across WSP001 repos
- Artifact schema to standardize (manifest, cost, rail-policy)
- Claim/lock behavior improvements
- Cold→hot approval behavior formalization
- Retrieval/pointer behavior for CV→Studio bridge

### 6. Do NOT perform HOT actions

```text
FORBIDDEN:
  - just ingest-remote           (posts to Cloud Run)
  - just full-deploy             (golden path HOT)
  - git push                     (modifies remote)
  - git merge                    (modifies branch)
  - Any write outside Codex lane
  - Overwriting or deleting any structural file without first running:
      just archive-asset <filepath> "<reason>"
    This includes: public/index.html, public/assets/*, docs/agent-contracts.md,
    and any file in knowledge_base/. MOVE NOT DELETE — no exceptions.
    Run archive-asset → confirm ARCHIVED output → THEN modify active file.
```

**Archive mandate — the physical enforcement of MOVE NOT DELETE:**
Before ANY structural rewrite, Codex must run:
```bash
just archive-asset public/index.html "Codex CX-NNN: reason for this refactor"
```
This creates `archive/inspirational_scripts/<timestamp>/index.html` + `reason.txt`.
The Library of Assets grows. Nothing is lost. Only then may you modify the active file.

### 7. Release lock

```bash
just brain-release
```

### 8. Return JSON

Output must conform to the schema below.

---

## JSON RESPONSE SCHEMA

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "title": "CodexInterviewResponse",
  "description": "File-backed agent interview output — separates current truth from proposed future state.",
  "type": "object",
  "required": ["agent", "repo", "run_id", "timestamp", "rail_contract", "attribution", "observed_from_files", "observed_from_commands", "missing_primitives", "recommended_standards"],
  "properties": {
    "agent": {
      "type": "string",
      "description": "Agent name — e.g. Codex"
    },
    "repo": {
      "type": "string",
      "description": "Canonical repo path — e.g. C:\\WSP001\\R.-Scott-Echols-CV"
    },
    "run_id": {
      "type": "string",
      "description": "Run identifier from brain-claim — e.g. run_2026-04-10_001"
    },
    "timestamp": {
      "type": "string",
      "format": "date-time",
      "description": "ISO 8601 timestamp of interview completion"
    },
    "rail_contract": {
      "type": "object",
      "description": "The non-destructive rail rules active for this session.",
      "required": ["write_scope", "hot_actions_allowed", "archive_required_before_structural_write"],
      "properties": {
        "write_scope": {
          "type": "array",
          "items": { "type": "string" },
          "description": "Files or folders Codex may write in this repo"
        },
        "hot_actions_allowed": {
          "type": "boolean",
          "description": "Whether HOT actions were permitted in this interview session"
        },
        "archive_required_before_structural_write": {
          "type": "boolean",
          "description": "Whether archive-asset must run before overwriting structural files"
        }
      }
    },
    "attribution": {
      "type": "object",
      "description": "Commons attribution metadata for artifacts produced from this prompt.",
      "required": ["architecture", "engineering"],
      "properties": {
        "architecture": {
          "type": "string",
          "description": "Architecture attribution line"
        },
        "engineering": {
          "type": "string",
          "description": "Engineering attribution line"
        }
      }
    },
    "observed_from_files": {
      "type": "array",
      "description": "Facts observed by reading actual repo files. Each item cites source file + line/section.",
      "items": {
        "type": "object",
        "required": ["fact", "source_file", "status"],
        "properties": {
          "fact": {
            "type": "string",
            "description": "What was observed — plain language"
          },
          "source_file": {
            "type": "string",
            "description": "Exact file path where this fact lives"
          },
          "source_line": {
            "type": ["integer", "null"],
            "description": "Line number if applicable, null otherwise"
          },
          "status": {
            "type": "string",
            "enum": ["implemented", "missing", "stale", "recommended"],
            "description": "Current state of this fact"
          }
        }
      }
    },
    "observed_from_commands": {
      "type": "array",
      "description": "Facts observed by running just recipes or shell commands.",
      "items": {
        "type": "object",
        "required": ["fact", "command", "exit_code"],
        "properties": {
          "fact": {
            "type": "string",
            "description": "What was observed — plain language"
          },
          "command": {
            "type": "string",
            "description": "Exact command run — e.g. just preflight"
          },
          "exit_code": {
            "type": "integer",
            "description": "Exit code of the command"
          },
          "output_summary": {
            "type": "string",
            "description": "Key output lines (truncated if long)"
          }
        }
      }
    },
    "missing_primitives": {
      "type": "array",
      "description": "Primitives that do not exist in the repo but would improve the operating model.",
      "items": {
        "type": "object",
        "required": ["primitive", "purpose", "current_workaround"],
        "properties": {
          "primitive": {
            "type": "string",
            "description": "Name of the missing primitive — e.g. manifest.yaml"
          },
          "purpose": {
            "type": "string",
            "description": "What it would do if it existed"
          },
          "current_workaround": {
            "type": "string",
            "description": "How the repo handles this today without it"
          },
          "priority": {
            "type": "string",
            "enum": ["high", "medium", "low"],
            "description": "How important is adding this"
          }
        }
      }
    },
    "recommended_standards": {
      "type": "array",
      "description": "Proposed standards to adopt across WSP001 repos — each grounded to an existing pattern.",
      "items": {
        "type": "object",
        "required": ["standard", "grounded_in", "applies_to"],
        "properties": {
          "standard": {
            "type": "string",
            "description": "What the standard is — plain language"
          },
          "grounded_in": {
            "type": "string",
            "description": "Which existing repo file/recipe/pattern this extends"
          },
          "applies_to": {
            "type": "array",
            "items": { "type": "string" },
            "description": "Which WSP001 repos this should apply to"
          },
          "effort": {
            "type": "string",
            "enum": ["trivial", "small", "medium", "large"],
            "description": "Implementation effort"
          }
        }
      }
    },
    "verdict": {
      "type": "object",
      "description": "Overall interview verdict",
      "properties": {
        "lane_health": {
          "type": "string",
          "enum": ["green", "yellow", "red"],
          "description": "Health of the Codex lane"
        },
        "blockers": {
          "type": "array",
          "items": { "type": "string" },
          "description": "Anything blocking Codex from doing useful work"
        },
        "next_action": {
          "type": "string",
          "description": "What Codex should do next"
        }
      }
    }
  }
}
```

---

## RECIPE REFERENCE (all 78 recipes in justfile, grouped by lane)

### Orientation (all agents)

```text
orient             — cat CLAUDE.md
contracts          — cat docs/agent-contracts.md
handoffs           — cat AGENT_HANDOFFS.md
master             — cat MASTER_AGENT_IMPLEMENTATION_HANDOFF.md
architecture       — cat design.md
status             — control plane status
cloud-status       — gcloud describe rse-retrieval
cloud-deploy       — deploy reminder
log                — git log -20
agent-history      — git log with author info
```

### Codex Lane

```text
codex-read-contracts  — read-only cross-lane (API contracts + chat.ts)
codex-read-qa         — read-only cross-lane (test specs)
codex-upgrade         — python scripts/upgrade_cv.py
codex-preview         — http server on :8080
codex-validate        — index.html structure check
codex-build           — delegates to codex-validate (static site)
codex-status          — frontend status summary
```

### Archive Lane (ALL AGENTS — mandatory before structural rewrites)

```text
archive-asset FILE REASON   — MOVE NOT DELETE: cp to archive/inspirational_scripts/<ts>/ + reason.txt
archive-list                — Library of Assets index: show all archived files with reasons
```

### Claude Code Lane

```text
backend-read-ui          backend-read-qa          backend-typecheck
embed-ingest             backend-check-env        backend-validate-models
claude-doctor            claude-vector-probe      claude-env-check
claude-truth-audit       claude-proof-of-work     claude-orient
validate-manifest        ingest-remote
```

### Antigravity Lane

```text
qa-read-all              test                     test-all
qa-report                test-vector-handoff      test-e2e-chat
test-e2e-video           test-e2e
antigravity-qa           antigravity-smoke        antigravity-proof-report
```

### Master / Shared

```text
cockpit                  stack-truth              dependency-map
doctor                   qa-ready                 cv-status
cv-smoke-cloud           verify-all               preflight
master-cockpit           master-truth             master-lanes
deploy                   add-dep
```

### RAG Pipeline

```text
pip-install              ingest-all               search
persona-check            truth-check              truth-audit
ingest-identity          partitions               vector-health
cv-search                test-rag-local
deploy-cloud-run         cloud-check              test-cloud-retrieve
```

### Brain / Golden Path

```text
brain-claim AGENT RUN    — write .brain-lock
brain-release            — delete .brain-lock
brain-status             — show lock state
cold-start               — orient + truth-audit + doctor + env-check ($0)
ingest-and-verify        — ingest-remote + claude-vector-probe (HOT)
full-deploy              — truth-audit + preflight + ingest-remote + vector-probe (HOT)
```

### Cleanup

```text
clean-test               — rm snapshots/tmp/debug logs
```

---

## ATTRIBUTION RULE

If Codex writes a markdown or text artifact during an interview run, append:

```text
Architecture -> Scott Echols / WSP001 (For the Commons Good)
Engineering -> Codex (ChatGPT Business Seat #2)
```

If the output must be JSON only, put those same values in the `attribution` object and do not add free text outside the payload.

---

## CORRECTIONS TO CODEX DRAFT

| Codex Claimed | Actual (disk-verified) |
|--------------|----------------------|
| `public/upgrade_cv.py` | `scripts/upgrade_cv.py` — EXISTS at scripts/, NOT public/ |
| `just health` exists | DOES NOT EXIST as standalone recipe |
| `just diff` exists | DOES NOT EXIST as standalone recipe |
| `just read-order` exists | DOES NOT EXIST as standalone recipe |
| `preflight runs validate-manifest + health + diff` | preflight runs: status + backend-check-env + backend-validate-models + codex-validate + qa-report |

Codex was correct about: brain-claim, brain-release, brain-status, preflight, validate-manifest, cold-start, full-deploy existing. Those are all verified present.

---

*For the Commons Good*
**Acting Master: Windsurf/Cascade | Human Admin: Roberto Scott Echols / WSP001 | 2026-04-10**
**Updated: Claude Code (CC-IAM-OPS) — added archive-asset mandate to Section 6 + Archive Lane to recipe ref — 2026-04-07**
