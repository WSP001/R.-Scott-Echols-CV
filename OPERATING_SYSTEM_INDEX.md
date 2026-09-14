# OPERATING_SYSTEM_INDEX.md — WSP001 Agent Operating System

**Version:** 1.0.0
**Last Updated:** 2026-04-14
**Signed by:** Windsurf/Cascade (Acting Master, WSP001)
**Human Admin:** Roberto Scott Echols

```text
STATUS: ACTIVE
OWNER: Scott / Acting Master
MODE: READ_FIRST
PROOF_RULE: PROOF_BEFORE_NARRATIVE
SAFETY_RULE: MOVE_NOT_DELETE
```

> Read these three files in order at every session start.
> Together they form one coherent operating system.

---

## The Trio

### 1. TEAM_OPERATING_RULES.md — Permanent Contract

```text
LOCATION: plans/TEAM_OPERATING_RULES.md
PURPOSE:  durable rules that do not change per session
CONTAINS: lane assignments, CLI surfaces, public/private repo rules,
          Copilot CLI integration, NOFAKESUCCESS standard,
          session start protocol, commit attribution
VERSION:  1.1.0
```

Read this first. It tells every agent what they may and may not do.

### 2. STACK_TRUTH.md — Current System Truth

```text
LOCATION: STACK_TRUTH.md (repo root)
PURPOSE:  current reality — what is live, blocked, optional, next
CONTAINS: production services, env var contracts, data boundaries,
          verification proofs, recovery patterns, session truth block
VERSION:  2.1.0
```

Read this second. It tells every agent what is actually true right now.

### 3. TEAM_ASSIGNMENT_SHEET.md — Active Work Distribution

```text
LOCATION: plans/TEAM_ASSIGNMENT_SHEET.md
PURPOSE:  who is doing what right now, by repo and lane
CONTAINS: CV assignments, Studio assignments, agent CLI favorites,
          finish-line priorities, Horizon Architecture directive,
          handoff rule format
VERSION:  2.1.0
```

Read this third. It tells every agent what their specific task is.

---

## Read Order

```text
1. plans/TEAM_OPERATING_RULES.md    — the permanent rules
2. STACK_TRUTH.md                   — the current truth
3. plans/TEAM_ASSIGNMENT_SHEET.md   — the active assignments
```

---

## Supporting Files

These are referenced by the trio but are not part of the core operating loop:

```text
AGENT-OPS.md                        — machine resume contract (legacy, still valid)
DEPENDENCY_MAP.md                   — service dependency graph
MASTER_AGENT_IMPLEMENTATION_HANDOFF.md — phase gates and task checklists
PHASE5_LIVE_STATUS_BOARD.md         — Phase 5 specific board state
docs/agent-contracts.md             — API shapes and test surface
AGENT_HANDOFFS.md                   — cross-lane async notes
plans/CODEX_INTERVIEW_PROMPT.md     — Codex interview template
plans/CODEX_TODO_CHECKLIST_2026-04-10.md — Codex audit checklist
docs/WSP001_REPO_MAP.md             — full repo inventory and identity boundaries
references/env-schema.md            — blessed env vars for CV repo
references/file-map.md              — exact file locations
```

---

## Canonical Paths

```text
CV:        C:\WSP001\R.-Scott-Echols-CV
Studio:    C:\WSP001\SirTrav-A2A-Studio
Sir James: C:\Users\Roberto002\OneDrive\Sir James
```

---

## GitHub CLI Status

```text
gh:         v2.66.1
gh-copilot: v1.2.0
Account:    WSP001 (authenticated)
Scopes:     gist, read:org, repo, workflow
```

---

*For the Commons Good*
**Acting Master: Windsurf/Cascade | Human Admin: Roberto Scott Echols / WSP001 | 2026-04-14**
