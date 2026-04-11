# CODEX_INTERVIEW_PROMPT.md — File-Backed Agent Interview Template

**Version:** 1.1.0
**Last Updated:** 2026-04-10
**Verified by:** Perplexity Computer (live disk + GitHub API check)
**Purpose:** Reusable, file-grounded prompt for Codex #2 interview sessions in the CV repo.
**Improvement over Windsurf v1.0.0 draft:** Corrected recipe count (64 not 78), removed 11 non-existent recipes, corrected public/assets/ status, removed brain-*/cold-start/full-deploy/ingest-remote/validate-manifest claims that do not exist in this justfile.

---

## AGENT IDENTITY

```text
You are Codex (ChatGPT Business Seat #2).
Your lane in this repo is frontend/UI shell truth and file-backed repo verification.

Mission: answer with file-backed truth only.
No "I usually." No invented paths.
Every claim must map to an exact file, path, just recipe, git fact, or command output.
```

---

## REPO CONTEXT (verified on disk — do not invent beyond these)

```text
REPO:            C:\WSP001\R.-Scott-Echols-CV
HUMAN_ADMIN:     Roberto Scott Echols
WORKSPACE:       WSP001
JUSTFILE:        justfile (780 lines, 64 recipes)
TRUTH_FILES:     STACK_TRUTH.md | AGENT-OPS.md | DEPENDENCY_MAP.md
LANE_RULE:       Agents may cross lanes to READ. May NOT cross lanes to WRITE.
```

### Codex Write Lane (verified)

```text
public/index.html              EXISTS — Codex primary write target
public/assets/                 MISSING — directory does not currently exist (codex-status reports "no assets/")
scripts/upgrade_cv.py          EXISTS — Python batch-edit helper (NOT public/upgrade_cv.py)
```

### Codex Read-Only Cross-Lane (verified)

```text
netlify/edge-functions/chat.ts          EXISTS — understand API contract
netlify/edge-functions/embed.ts         EXISTS — embedding edge function
netlify/edge-functions/verify-access.ts EXISTS — access gate
docs/agent-contracts.md                 EXISTS — test surface and API shapes
AGENT_HANDOFFS.md                       EXISTS — cross-lane async notes
MASTER_AGENT_IMPLEMENTATION_HANDOFF.md  EXISTS — phase + mission
STACK_TRUTH.md                          EXISTS — canonical operating truth
AGENT-OPS.md                            EXISTS — machine resume contract
DEPENDENCY_MAP.md                       EXISTS — service dependency graph
CLAUDE.md                               EXISTS — orient context
design.md                               EXISTS — architecture reference
```

---

## DO THIS IN ORDER

### 1. Read order (mandatory — read ALL before first write)

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

### 2. Preflight (run before any write)

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

### 3. Answer SECTION 1 — Observed Current State

For each item below, mark: `implemented` | `missing` | `recommended`

Include:
- **Exact files read** — path verified on disk
- **Exact just recipes present** relevant to Codex lane:
  - `codex-validate` (line 111) — index.html structure check
  - `codex-preview` (line 106) — local HTTP server on :8080
  - `codex-upgrade` (line 102) — Python batch-edit via scripts/upgrade_cv.py
  - `codex-read-contracts` (line 88) — read-only cross-lane
  - `codex-read-qa` (line 96) — read-only cross-lane
  - `codex-build` (line 754) — delegates to codex-validate (no npm build — static site)
  - `codex-status` (line 764) — frontend status summary
- **Exact artifacts or lock files** written by recipes:
  - `AGENT_HANDOFFS.md` — appended by `handoff-note` recipe (line 400)
- **Exact approval/merge gates** found in repo files:
  - STACK_TRUTH.md Layer 4 Verification Contract
  - MASTER_AGENT_IMPLEMENTATION_HANDOFF.md Phase Gates
  - AGENT-OPS.md BLOCKER register

Include missing primitives assessment:

```text
PRIMITIVE                STATUS
brain-claim recipe       MISSING — no lock/claim system exists in this justfile
brain-release recipe     MISSING — no lock/claim system exists in this justfile
brain-status recipe      MISSING — no lock/claim system exists in this justfile
cold-start recipe        MISSING — not present; orient + preflight serve orientation purposes
full-deploy recipe       MISSING — not present; deploy recipe handles git add/commit reminder
ingest-remote recipe     MISSING — not present in justfile
validate-manifest recipe MISSING — not present in justfile
manifest.yaml            MISSING — not present; data/rse_cv_manifest.json may serve this role
pointers.yaml            MISSING — not present in repo
cost.json                MISSING — cost annotations exist inline in justfile comments, no standalone file
rail-policy.yaml         MISSING — cold/hot rail policy exists in justfile comments, no standalone file
WORKTREE_TRUTH.md        MISSING — not present
RUN_MANIFEST schema      MISSING — no formal schema; no brain-claim mechanism exists
PROVEN_PATHS.md          MISSING — not present; golden-path recipes do not exist in this justfile
public/assets/           MISSING — directory does not exist (codex-status handles gracefully)
```

### 4. Answer SECTION 2 — Recommended Target State

Propose only repo-grounded standards:
- Commands to standardize across WSP001 repos
- Artifact schema to standardize (manifest, cost, rail-policy)
- Brain-claim/lock behavior: whether to add it, and at what recipe complexity
- Cold→hot approval behavior formalization
- Retrieval/pointer behavior for CV→Studio bridge

### 5. Do NOT perform HOT actions

```text
FORBIDDEN:
  - just embed-ingest            (modifies vector store)
  - just deploy                  (triggers git push reminder + modify)
  - just deploy-cloud-run        (deploys to Cloud Run)
  - git push                     (modifies remote)
  - git merge                    (modifies branch)
  - Any write outside Codex lane
```

### 6. Return JSON

Output must conform to the schema below.

---

## JSON RESPONSE SCHEMA

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "title": "CodexInterviewResponse",
  "description": "File-backed agent interview output — separates current truth from proposed future state.",
  "type": "object",
  "required": ["agent", "repo", "run_id", "timestamp", "observed_from_files", "observed_from_commands", "missing_primitives", "recommended_standards"],
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
      "description": "Run identifier — e.g. run_2026-04-10_001"
    },
    "timestamp": {
      "type": "string",
      "format": "date-time",
      "description": "ISO 8601 timestamp of interview completion"
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
            "description": "Name of the missing primitive — e.g. brain-claim recipe"
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

## RECIPE REFERENCE (all 64 recipes in justfile — verified)

### Orientation (all agents)

```text
default            (line 19)  — list recipes
orient             (line 27)  — cat CLAUDE.md
contracts          (line 31)  — cat docs/agent-contracts.md
handoffs           (line 35)  — cat AGENT_HANDOFFS.md
master             (line 39)  — cat MASTER_AGENT_IMPLEMENTATION_HANDOFF.md
architecture       (line 53)  — cat design.md
cloud-status       (line 43)  — gcloud describe rse-retrieval
cloud-deploy       (line 47)  — deploy reminder
status             (line 57)  — control plane status
log                (line 279) — git log -20
agent-history      (line 406) — git log with author info
handoff-note       (line 400) — append note to AGENT_HANDOFFS.md
```

### Codex Lane

```text
codex-read-contracts  (line 88)  — read-only cross-lane (API contracts + chat.ts)
codex-read-qa         (line 96)  — read-only cross-lane (test specs)
codex-upgrade         (line 102) — python scripts/upgrade_cv.py
codex-preview         (line 106) — http server on :8080
codex-validate        (line 111) — index.html structure check
codex-build           (line 754) — delegates to codex-validate (static site)
codex-status          (line 764) — frontend status summary
```

### Claude Code / Backend Lane

```text
backend-read-ui          (line 126)
backend-read-qa          (line 131)
backend-typecheck        (line 136)
embed-ingest             (line 143)
embed-query              (line 149)
backend-check-env        (line 153)
backend-validate-models  (line 163)
claude-doctor            (line 640)
claude-vector-probe      (line 666)
claude-env-check         (line 680)
```

### Antigravity Lane

```text
qa-read-all              (line 190)
test                     (line 202)
test-e2e-video           (line 207)
test-e2e-chat            (line 212)
test-e2e                 (line 217)
test-all                 (line 222)
qa-report                (line 227)
test-vector-handoff      (line 243)
antigravity-qa           (line 694)
antigravity-smoke        (line 714)
antigravity-proof-report (line 730)
```

### Master / Shared

```text
cockpit                  (line 425)
stack-truth              (line 451)
dependency-map           (line 455)
doctor                   (line 459)
qa-ready                 (line 506)
cv-status                (line 527)
cv-smoke-cloud           (line 547)
verify-all               (line 567)
preflight                (line 252)
master-cockpit           (line 597)
master-truth             (line 619)
master-lanes             (line 623)
deploy                   (line 265)
add-dep                  (line 274)
clean-test               (line 411)
```

### RAG Pipeline

```text
pip-install              (line 287)
ingest-all               (line 291)
search                   (line 297)
persona-check            (line 305)
truth-check              (line 317)
truth-audit              (line 321)
ingest-identity          (line 325)
partitions               (line 333)
vector-health            (line 345)
cv-search                (line 354)
test-rag-local           (line 358)
deploy-cloud-run         (line 377)
cloud-check              (line 383)
test-cloud-retrieve      (line 387)
```

---

## CORRECTIONS TABLE — Windsurf v1.0.0 vs. Disk Reality

| Windsurf Draft Claimed | Actual (GitHub API + disk verified 2026-04-10) |
|---|---|
| `public/upgrade_cv.py` | `scripts/upgrade_cv.py` — EXISTS at scripts/ |
| `public/assets/` EXISTS | MISSING — directory does not exist |
| 78 recipes in justfile | 64 recipes verified |
| `brain-claim` recipe EXISTS | DOES NOT EXIST in justfile |
| `brain-release` recipe EXISTS | DOES NOT EXIST in justfile |
| `brain-status` recipe EXISTS | DOES NOT EXIST in justfile |
| `cold-start` recipe EXISTS | DOES NOT EXIST in justfile |
| `full-deploy` recipe EXISTS | DOES NOT EXIST in justfile |
| `ingest-and-verify` recipe EXISTS | DOES NOT EXIST in justfile |
| `ingest-remote` recipe EXISTS | DOES NOT EXIST in justfile |
| `validate-manifest` recipe EXISTS | DOES NOT EXIST in justfile |
| `claude-orient` recipe EXISTS | DOES NOT EXIST in justfile |
| `claude-proof-of-work` recipe EXISTS | DOES NOT EXIST in justfile |
| `claude-truth-audit` recipe EXISTS | DOES NOT EXIST in justfile |
| `just health` exists | DOES NOT EXIST as standalone recipe |
| `just diff` exists | DOES NOT EXIST as standalone recipe |
| `just read-order` exists | DOES NOT EXIST as standalone recipe |
| `preflight runs validate-manifest + health + diff` | preflight runs: status + backend-check-env + backend-validate-models + codex-validate + qa-report |
| justfile is 991 lines | justfile is 780 lines |
| codex-build is line 755 | codex-build is line 754 |

Codex was correct about: preflight recipe exists, codex-validate/preview/upgrade/read-contracts/read-qa/build/status recipes, docs/agent-contracts.md exists, STACK_TRUTH.md/AGENT-OPS.md/DEPENDENCY_MAP.md/MASTER_AGENT_IMPLEMENTATION_HANDOFF.md/AGENT_HANDOFFS.md all exist.

---

*For the Commons Good*
**Verified by: Perplexity Computer (live GitHub API) | Human Admin: Roberto Scott Echols / WSP001 | 2026-04-10**
