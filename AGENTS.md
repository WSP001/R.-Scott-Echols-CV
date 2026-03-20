# AGENTS.md — R. Scott Echols CV & RAG Chatbot Team Lineup

> **Purpose**: Master registry of all agents, their domains, instruction files, and current task assignments.
> **Version**: 3.0.0 (Phase 4-6 Operations)
> **Owner**: Windsurf/Cascade (Acting Master, WSP001)
> **Last Updated**: 2026-03-19
> **Canonical Path**: `c:\WSP001\R.-Scott-Echols-CV`

---

## 📁 Project Info

| Field | Value |
|-------|-------|
| **Canonical Path** | `c:\WSP001\R.-Scott-Echols-CV` ← **ALL writes happen here** |
| **GitHub** | `github.com/WSP001/R.-Scott-Echols-CV` |
| **Purpose** | High-velocity 3D Portfolio + Tiered RAG Chatbot |
| **Stack** | HTML/Three.js/GSAP (frontend), Netlify Edge (middleware), FastAPI/Cloud Run (vector backend) |
| **North Star** | `MASTER_AGENT_IMPLEMENTATION_HANDOFF.md` — milestones, rules, architecture |

---

## 🤖 Agent Directory & Instruction Files

Every agent reads **three files** on entry:

1. **MASTER_AGENT_IMPLEMENTATION_HANDOFF.md** — the North Star
2. **AGENT_HANDOFFS.md** — Cross-lane communication board
3. **Their own instruction file** — agent-specific rules and boundaries

### 🚨 THE GEMINI PIVOT RULE (Effective 2026-03-19)
**New Priority:** Integrate Google's new multimodal `gemini-embedding-2-preview` model into the ChromaDB pipeline (Phase 6).

| # | Agent | Platform | Instruction File | Domain | Memory |
|---|-------|----------|-----------------|--------|--------|
| 0 | **Windsurf/Cascade** (Acting Master) | Windsurf IDE | `MASTER_AGENT_IMPLEMENTATION_HANDOFF.md` | Orchestration, QA review, merges, Knowledge Graph | ✅ Cross-session |
| 1 | **Claude Code** | Terminal (`claude`) | `CLAUDE.md` + `plans/HANDOFF_PHASE5_CLAUDE.md` | Backend: `netlify/edge-functions/`, `scripts/` | Worktree-scoped |
| 2 | **Codex #2** | OpenAI Codex CLI | `plans/HANDOFF_PHASE4.md` | Frontend: `public/index.html` (3D/GSAP) | ❌ Per-session |
| 3 | **Antigravity** | Gemini CLI / QA | `plans/HANDOFF_PHASE5_QA_GATES.md` | QA: boundary tests, fallback smoke tests | ❌ Per-session |
| 4 | **Human-Ops** (Scott) | Manual | `AGENTS.md` | API keys, Cloud Run deploy, Netlify Dashboard | N/A |

---

## 📋 Current Task Lineup (as of 2026-03-19)

### Master (Windsurf/Cascade) — ACTIVE

| Priority | Task | Status |
|----------|------|--------|
| — | Orchestrate all agents, merge branches, update milestones | Ongoing |
| DONE | Avert Git Collision on `main` vs Codex Phase 4 | ✅ Master reset to `origin/main` |
| DONE | Draft Phase 5 Backend Router Handoff | ✅ `plans/HANDOFF_PHASE5_CLAUDE.md` |
| DONE | Draft Phase 6 Multimodal Handoff | ✅ `plans/HANDOFF_PHASE6_MULTIMODAL.md` |

### Claude Code — ACTIVE (Backend Engineering)

| Priority | Task | Status |
|----------|------|--------|
| **NEXT** | **Phase 5: Implement Tier-Safe Routing (Netlify Bridge)** | 🟢 UNBLOCKED |
| FUTURE | Phase 6: Upgrade to `gemini-embedding-2-preview` multimodal ingest | ⏳ Pending Phase 5 success |

**Session start**: Read `plans/HANDOFF_PHASE5_CLAUDE.md`

### Codex #2 — STANDBY (Frontend / WebGL)

| Priority | Task | Status |
|----------|------|--------|
| DONE | Phase 4 WebGL Glass Draft (Branch: `feat/phase4-high-velocity-glass`) | ✅ Pushed |
| **WAIT** | **Hold merge until Antigravity tests chat UI on `main`** | ⏳ Blocked |
| FUTURE | Phase 5 UI trust badges (after Claude finishes router) | ⏳ Pending Phase 5 success |

**Session start**: Do nothing until QA completes.

### Antigravity — ACTIVE (QA & Boundaries)

| Priority | Task | Status |
|----------|------|--------|
| DONE | Define Phase 5 boundary conditions | ✅ Generated `docs/PHASE5_*` |
| **NEXT** | **Review Codex Phase 4 fallback behavior (WebGL loss)** | 🟢 UNBLOCKED |
| FUTURE | Test Claude Code's Phase 5 backend router | ⏳ After Claude push |

### Human-Ops (Scott) — ACTION REQUIRED

| Priority | Task | Status |
|----------|------|--------|
| **HIGH** | Run local ingest: `python scripts/embed_engine.py --ingest` | ⏳ Pending |
| **HIGH** | Deploy to Cloud Run: `.\scripts\deploy-cloud-run.ps1` | ⏳ Pending |
| **HIGH** | Set `VECTOR_ENGINE_URL` in Netlify Dashboard | ⏳ Pending |

---

## 🔗 The Harness Chain (Wire-to-Wire)

```
MASTER.md (North Star — everyone reads this)
    │
    ├── CLAUDE.md (Claude Code's instructions)
    ├── AGENT-OPS.md (all agents' operational rules + tasks)
    ├── AGENTS.md (THIS FILE — registry + lineup)
    │
    ├── plans/HANDOFF_CLAUDECODE_*.md (Claude Code's tickets)
    ├── plans/HANDOFF_CODEX2_*.md (Codex #2's tickets)
    ├── plans/HANDOFF_NETLIFY_AGENT.md (Netlify Agent's ticket)
    │
    └── justfile (60+ recipes — the operating system)
        ├── just orient-claude-m9
        ├── just orient-codex-m9
        ├── just orient-antigravity-m9
        ├── just orient-netlify
        └── just orient-human-m9
```

Every agent enters through the same door:
1. Read `MASTER.md` (milestones, rules)
2. Read their instruction file (boundaries, commands)
3. Run their `just orient-*` command (current context)
4. Read their handoff ticket in `plans/` (exact task)
5. Work → gates → commit → report to Master

---

## 🎯 Core Patterns (All Agents Must Follow)

| Pattern | Description | Implementation |
|---------|-------------|----------------|
| **No Fake Success** | Disabled services report `{ success: false, disabled: true }` | All publishers |
| **Click2Kick** | Read Before Execute + prereq check + verification | justfile commands |
| **Commons Good** | 20% markup on API costs | `cost.markup: 0.20` |
| **runId Threading** | Trace every agent call | `{ projectId, runId, ...payload }` |
| **Gate Before Merge** | `npm run build` + `just sanity-test-local` + `just control-plane-gate` | Every commit |

---

## 🛡️ Security Rules (All Agents)

1. **Never commit secrets** — `.gitignore` includes `.env`, `credentials.json`
2. **Always dry-run first** — `just x-dry`, `just linkedin-dry`, `just youtube-dry`
3. **No local FFmpeg in Functions** — Use Remotion Lambda
4. **Boolean presence checks only** — Never log env var values, only `!!process.env.KEY`
5. **Canonical workspace only** — Push only from `c:\WSP001\SirTrav-A2A-Studio`

---

## � Agent Contributions (Commit Log)

| Date | Agent | Contribution | Commit |
|------|-------|--------------|--------|
| 2026-01 | Claude Code | Remotion Lambda architecture | — |
| 2026-01 | Claude Code | IntroSlate + EmblemComposition | — |
| 2026-01-27 | Windsurf/Cascade | justfile (30+ commands) | — |
| 2026-02 | Windsurf/Cascade | Control plane, split verdicts, repo hygiene | v3.0.0 |
| 2026-03-02 | Windsurf/Cascade | M7 backend: control-plane.ts + AG-014 | `88d7fe69` |
| 2026-03-02 | Codex #2 | CX-016: Diagnostics UI | `21728664` |
| 2026-03-03 | Codex #2 | CX-017: PlatformToggle.tsx | `16cf32c9` |
| 2026-03-03 | Claude Code | CC-019: Editor graceful degradation | `9f076332` |
| 2026-03-04 | Claude Code | CC-M9-CP: checkRemotion() | `2e4fdd50` |
| 2026-03-04 | Claude Code | CC-M9-E2E: test-remotion-e2e.mjs | `a3362ff1` |
| 2026-03-05 | Windsurf/Cascade | CX-018: Render Pipeline section | `91faaae4` |
| 2026-03-05 | Claude Code | CC-M9-METRICS: SSE cost tracking | `0c37cab9` |
| 2026-03-05 | Windsurf/Cascade | Merge CC-M9-METRICS | `face3aee` |
| 2026-03-06 | Windsurf/Cascade | CLAUDE.md rewrite + AGENT-OPS v1.3.0 | `6836785d` |
| 2026-03-06 | Windsurf/Cascade | AGENTS.md v2.0.0 (this update) | — |

---

## 🔄 Session Handoff Protocol

When starting a new session with ANY agent, provide this context:

```
Project: SirTrav-A2A-Studio
Path: c:\WSP001\SirTrav-A2A-Studio  ← ONLY this path
Read: MASTER.md, AGENTS.md, AGENT-OPS.md
Run: just orient-<your-agent>-m9
Then: cat plans/HANDOFF_<YOUR_AGENT>_<TICKET>.md
```

---

*This file is the team registry. All agents read it before starting work.*

**For the Commons Good** 🎬
