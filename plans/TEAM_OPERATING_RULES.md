# TEAM_OPERATING_RULES.md — WSP001 Multi-Agent Operating Contract

**Version:** 1.1.0
**Last Updated:** 2026-04-14
**Signed by:** Windsurf/Cascade (Acting Master, WSP001)
**Human Admin:** Roberto Scott Echols
**Scope:** All WSP001 repos — CV, Studio, SeaTrace, Sir James

```text
STATUS: ACTIVE
OWNER: Scott / Acting Master
MODE: READ_FIRST
PROOF_RULE: PROOF_BEFORE_NARRATIVE
SAFETY_RULE: MOVE_NOT_DELETE
COMMAND_RULE: LIVE_COMMANDS_ONLY
NEXT_OWNER_RULE: REQUIRED
```

```text
RULE: Read first. Act in lane. Prove with CLI. Record truth. Hand off next owner.
```

---

## 1. The Core Operating Sequence

Every task follows this exact sequence. No exceptions.

```text
1. OWNER    — who is responsible for this task?
2. LANE     — which files/functions may they touch?
3. REPO     — which canonical path?
4. CLI      — which just commands to run?
5. DONE     — what observable proof signals completion?
```

If any one of these is missing, the task is not ready.

---

## 2. Lane Assignments

### Scott / Acting Master

```text
ROLE:       governance, priorities, merge approval, next-owner assignment
READS:      STACK_TRUTH.md, handoff files, PR state, repo status
WRITES:     truth files, env vars (Netlify/GCP), merge decisions
MUST NOT:   become the default implementer for every lane
```

**CLI:**

```powershell
just cockpit
just stack-truth
just qa-ready
git status -sb
git log --oneline -8
```

**Done signal:** next owner named, gate named, truth file current.

### Claude Code

```text
ROLE:       backend, ops, scripts, truth docs, runtime glue
LANE:       scripts/, netlify/edge-functions/, justfile, ops docs
WRITES:     backend code, justfile recipes, operational truth
MUST NOT:   drift into primary frontend src/ lane unless reassigned
```

**CLI:**

```powershell
just claude-orient
just doctor
just validate-manifest
just claude-truth-audit
just full-deploy
just archive-asset FILE=<path> REASON="<why>"
```

**Done signal:** build/probe/smoke passes, docs updated, proof artifact exists.

### Codex #2

```text
ROLE:       frontend shell, progress UI, touched accessibility
LANE:       public/index.html, public/assets/, src/ (Studio only)
WRITES:     UI code, display data, accessibility improvements
MUST NOT:   drift into runtime, storage, Netlify/cloud backend work
```

**CLI:**

```powershell
just codex-validate
just build-gate
just studio-status
```

**Done signal:** build passes, UI diff stays in lane, accessibility checks satisfied.

### Antigravity

```text
ROLE:       QA only — verify, do not implement
LANE:       verification, pass/fail reporting, merge recommendation
WRITES:     QA reports only
MUST NOT:   implement fixes or widen scope
```

**CLI:**

```powershell
just antigravity-qa
just build-gate
just verify-cloud
just cv-smoke-cloud
```

**Done signal:** PASS / PASS_WITH_NOTES / BLOCKED / FAIL with evidence.

### GitHub Copilot CLI

```text
ROLE:       execution helper inside a declared lane — NOT governance
VERIFIED:   gh v2.66.1, WSP001 authenticated, gh-copilot v1.2.0
TOKEN:      gho_**** (scopes: gist, read:org, repo, workflow)
```

**Best use:**

- review diffs before edits (`gh copilot suggest`)
- apply narrow PR fixes (`@copilot` in PR comments)
- summarize workflow runs (action run logs)
- assist with contained edits inside assigned lane

**Do NOT use as:**

- truth source
- lane owner
- architecture decider
- secret/config authority

**CLI:**

```powershell
gh copilot suggest "explain this error"
gh copilot explain "what does this function do"
gh pr create --title "fix: description" --body "evidence"
gh pr review --comment --body "QA notes"
```

**Integration rule:** Master assigns lane → agent reads truth → Copilot helps inside that lane → QA verifies → Master decides merge.

---

## 3. Canonical Paths

```text
CANONICAL PATHS — WSP001
CV:        C:\WSP001\R.-Scott-Echols-CV           WRITE here
Studio:    C:\WSP001\SirTrav-A2A-Studio            WRITE here
Sir James: C:\Users\Roberto002\OneDrive\Sir James  WRITE here

ARCHIVE (read-only, do not push from):
  C:\Users\Roberto002\Documents\GitHub\*
  C:\Users\Roberto002\OneDrive\*\SirTrav*

If your cwd is not one of the canonical paths above — STOP.
Ask Scott before proceeding.
```

---

## 4. Public vs Private Repo Rules

### Public Repos (CV, Studio, Sir James)

```text
PURPOSE:    patterns, contracts, justfile primitives, truth models, safe workflows
ALLOWED:    agent contracts, memory schema, task templates, smoke rules, success signatures
FORBIDDEN:  private data, vault secrets, internal endpoints, cross-repo secret imports
```

The public repos are the **training ground** — they teach the operating pattern.

### Private Repos (SeaTrace, WAFC, internal)

```text
PURPOSE:    sensitive data, vault integration, private endpoints, regulated logic
ALLOWED:    stricter smoke rules, data-bearing operations, internal patterns
FORBIDDEN:  public asset leakage, copying patterns outward without review,
            cross-zone edits without explicit handoff
MANDATORY:  smoke scan before touching data paths
```

The private repos are the **production execution zone**.

---

## 5. GitHub Copilot Feature Map → Lane Model

| Copilot Feature | Maps To | Team Rule |
|----------------|---------|-----------|
| Code Reviews in CLI | EYES + EARS before HANDS | agents review patches before touching files |
| Cloud Agent Logs | LEDGER + TASK_REPORT | subagent traces, startup behavior, delegation logs |
| Workflow Markdown in Summaries | evidence over confidence | inspect exact workflow config |
| Usage Metrics (which model) | MEMORY_SCHEMA signatures | track which model produced which pattern |
| Cloud Agent Faster Startup | minimal patch, fast recon | less wait, same discipline |
| Copilot Modifies PRs | HANDS minimal-patch execution | contained fixes only |
| Choose Model in PR Comments | multi-seat assignment | right model to right zone |
| GPT-5.3-Codex LTS | stable predictable patterns | guaranteed through 2027 |
| Security Risk Assessment | fiduciary duty | vulnerability scan for all repos |

**Team instruction:** Use Copilot features as execution helpers inside the lane system, not as replacements for the lane system.

---

## 6. NOFAKESUCCESS Standard

```text
Do not document commands that do not exist.
Do not claim runtime health without proof.
Do not widen scope silently.
Do not bypass archive-first safety.
Do not present placeholder output as production success.
Do not report confidence without evidence.
```

**Proof standard:** build passed, smoke passed, probe passed, QA passed, or artifact verified.

---

## 7. Operating Principles

```text
1. Read before write — every agent reads truth files before editing
2. Proof before praise — done = observable proof, not narrative
3. Archive first — move or archive before deleting (MOVE NOT DELETE)
4. Secrets never in repo — config may be documented, secrets named but never stored
5. Lane boundaries are system safety — read across, never write across
6. One trusted CLI surface — just commands over ad hoc shell history
7. Netlify-first thinking — start from the live delivery path, work backwards
8. Next owner every time — no task ends without naming who goes next
```

---

## 8. Session Start Protocol

Paste this at every desktop session start:

```powershell
# WSP001 SESSION START
Write-Host "=== WSP001 SESSION START ===" -ForegroundColor Cyan
Write-Host "CV repo:" -NoNewline
git -C "C:\WSP001\R.-Scott-Echols-CV" log --oneline -1
Write-Host "Studio:" -NoNewline
git -C "C:\WSP001\SirTrav-A2A-Studio" log --oneline -1
Write-Host "gh auth:" -NoNewline
gh auth status 2>&1 | Select-String "Logged in"
Write-Host "Copilot:" -NoNewline
gh copilot --version 2>$null
Write-Host "=== READY ===" -ForegroundColor Green
```

---

## 9. Commit Attribution Standard

```text
Architecture: Scott Echols / WSP001 — Commons Good
Engineering:  <agent name>
Co-Authored-By: <model> <noreply@provider.com>
```

---

## 10. Current Priority Queue

```text
P0: Scott merges CV Phase 5 trust-layer branch
P0: Verify CV live deploy after merge
P1: Studio fix render-progress parameter shape
P1: Studio fix Voice placeholder (ElevenLabs voice ID)
P1: Scott adds PERPLEXITY_API_KEY to Netlify env
P2: SeaTrace Netfirms API routing + SSL cert
P2: Full Studio Click2Kick pipeline run (all 7 agents chained)
P2: Codex executes CV trust-layer UI audit checklist
```

---

*For the Commons Good*
**Acting Master: Windsurf/Cascade | Human Admin: Roberto Scott Echols / WSP001 | 2026-04-14**
