# STACK_TRUTH.md — R. Scott Echols CV / WSP001 Canonical Operating Truth

**Version:** 2.0.0
**Last Updated:** 2026-04-06
**Signed by:** Windsurf/Cascade (Acting Master, WSP001)
**Human Admin:** Roberto Scott Echols
**Canonical Path:** C:\WSP001\R.-Scott-Echols-CV
**Live Site:** <https://robertoscottecholscv.netlify.app>

> This is the **single operational truth file** for the CV repo.
> Every agent reads this at session start.
> It answers — without guessing — what is live, what is blocked,
> what is optional, who owns the next move, what costs money,
> and what is safe to rerun.

---

## IDENTITY AND MISSION

```text
HUMAN_ADMIN:        Roberto Scott Echols
WORKSPACE:          WSP001
STACK_VALUATION:    $4.2M USD
MODE:               Netlify-first, retrieval-grounded, merge-safe, restart-safe
```

Build and operate a durable, auditable, restart-safe multi-agent stack where:
- curated CV truth is grounded and partitioned
- retrieval is durable and production-safe
- deploys are gated through Netlify
- lane ownership is explicit
- all critical actions are replayable through trusted CLI primitives

---

## NETLIFY-FIRST PERSPECTIVE

The primary public delivery surface is Netlify. The team thinks in this order:

1. What is the **live Netlify path**?
2. What **runtime contract** does that path depend on?
3. What **storage and retrieval** system feeds that path?
4. What **proof** confirms the path is working?
5. What can be **improved** without breaking lane ownership?

```text
Netlify          = public web/runtime edge layer (PRODUCTION)
Cloud Run        = retrieval/service layer (PRODUCTION)
Supabase pgvector = durable production vector store (PRODUCTION)
ChromaDB         = local/dev/fallback only (LOCAL_DEV_ONLY)
just + scripts   = human/agent control layer (AUTOMATION)
```

---

## LAYER 1 — SYSTEM TRUTH

```text
STACK_STATUS:           GREEN_WITH_GATED_OPTIONALS
PHASE:                  5
PHASE_STATUS:           AWAITING_ANTIGRAVITY_QA
NEXT_OWNER:             Antigravity -> Scott (merge approval)
NEXT_GATE:              QA_REVIEW (16/18 threshold)
BRANCH_IN_REVIEW:       feat/phase5-ui-trust-layer
SMOKE_TEST:             17/17 PASS — 2026-04-05
VECTOR_CHUNKS:          124 (durable — pgvector on Supabase)
CLOUD_RUN_URL:          https://rse-retrieval-22622354820.us-central1.run.app
CLOUD_RUN_STATUS:       ok
NETLIFY_SITE:           robertoscottecholscv.netlify.app
INGEST_STATUS:          COMPLETE — 124 chunks via --from-manifest
LAST_INGEST:            2026-04-05
```

### What Is Live

- **Netlify frontend** — robertoscottecholscv.netlify.app — LIVE
- **Cloud Run retrieval** — rse-retrieval-22622354820.us-central1.run.app — LIVE
- **Supabase pgvector** — wsp001_knowledge table, 124 chunks — LIVE
- **Edge functions** — /api/chat, /api/embed, /api/verify-access — LIVE

### What Is Blocked

- Phase 5 merge — blocked on Antigravity QA gate (16/18 threshold)
- feat/phase5-ui-trust-layer deploy — blocked on Scott merge approval after QA

### What Is Optional

- Remotion / AWS rendering — PARKED_NON_BLOCKING
- ElevenLabs voice — NOT_WIRED (future Phase 3+)
- OpenAI API — RESERVED, not used
- Headless browser automation — FUTURE, after truth + gates stable

### Who Owns Next Move

```text
CURRENT:   Antigravity -> run QA gate against live system
THEN:      Scott -> approve merge of feat/phase5-ui-trust-layer
THEN:      Netlify auto-deploys on push to main
THEN:      Phase 6 planning begins
```

### What Costs Money

- Re-ingest (Gemini embeddings): ~$0.01-$0.05 — check --stats first
- Cloud Run retrieval queries: ~$0.00 (scales to zero)
- Anthropic chat (Claude Opus 4.6): ~$0.01-$0.05/query — rate-limited
- Netlify edge functions: Free tier

### What Is Safe To Rerun

- `just cockpit` — YES, $0, read-only
- `just cv-smoke-cloud` — YES, $0, read-only health probe
- `just master-cockpit` — YES, $0, read-only
- `just claude-vector-probe` — YES, $0, read-only
- `just vector-health` — YES, $0, local ChromaDB stats
- `python embed_engine.py --stats` — YES, $0, read-only
- `python embed_engine.py --from-manifest` — CAUTION, ~$0.01-$0.05

---

## LAYER 2 — RUNTIME CONTRACT

### Authoritative Services

- **Netlify** — frontend hosting, edge function routing, build gate — PRODUCTION
- **Cloud Run (FastAPI)** — /retrieve, /query, /ingest, /health — PRODUCTION
- **Supabase pgvector** — wsp001_knowledge table, 124 chunks, durable — PRODUCTION
- **ChromaDB (.chromadb/)** — local dev/test only — LOCAL_DEV_ONLY
- **GitHub Actions** — ingest-knowledge.yml, refresh-gh-context.yml — AUTOMATION

### Environment Variables — Netlify (Dashboard)

```text
ANTHROPIC_API_KEY      SECRET    chat.ts (Claude Opus 4.6)          REQUIRED
GEMINI_API_KEY         SECRET    embed.ts (Gemini Embedding 2)      REQUIRED
BUSINESS_ACCESS_KEY    SECRET    verify-access.ts (invitation key)  REQUIRED
VECTOR_ENGINE_URL      CONFIG    chat.ts (Cloud Run URL)            OPTIONAL — fallback to embedded prompt
ELEVENLABS_API_KEY     SECRET    future voice.ts                    NOT YET WIRED
OPENAI_API_KEY         SECRET    reserved                           NOT USED
```

### Environment Variables — Cloud Run (GCP Console)

```text
GEMINI_API_KEY         SECRET    api_server.py (query embedding)    REQUIRED
INGEST_SECRET          SECRET    api_server.py (/ingest auth)       REQUIRED
DATABASE_URL           SECRET    vector_store.py (pgvector)         REQUIRED — must include ?sslmode=require
PORT                   CONFIG    Cloud Run auto-sets                AUTO
```

### Config vs Secret Rule

```text
RULE: URLs are config unless they grant privileged access by themselves.
RULE: VECTOR_ENGINE_URL is PLAIN CONFIG, not a secret.
RULE: INGEST_SECRET, DATABASE_URL, all *_API_KEY vars are SECRETS.
RULE: Write secrets only into approved secret stores (Netlify Dashboard, GCP Console).
RULE: Never commit secrets to repo. Never log secret values — boolean presence only.
```

### Storage Truth

- **Supabase pgvector** — PRODUCTION, DURABLE (survives Cloud Run restarts), 124 chunks
- **ChromaDB (.chromadb/)** — LOCAL_DEV_ONLY, NOT DURABLE
- **knowledge_base/** — git-tracked source corpus, partitioned: public/cv/, business/, docs/
- **data/rse_cv_manifest.json** — git-tracked ingest manifest

### Fallback Path

```text
1. VECTOR_ENGINE_URL set + Cloud Run healthy -> full RAG retrieval
2. VECTOR_ENGINE_URL unset OR Cloud Run down -> chat.ts uses embedded CV system prompt only
3. GEMINI_API_KEY missing on Cloud Run -> /health returns "degraded", /retrieve returns 503
4. ANTHROPIC_API_KEY missing -> /api/chat returns 503
5. BUSINESS_ACCESS_KEY missing -> /api/verify-access rejects all business-tier requests
```

---

## LAYER 3 — AGENT LANE CONTRACT

```text
AGENTS MAY CROSS LANES TO READ.
AGENTS MAY NOT CROSS LANES TO WRITE.
```

### Lane Ownership

```text
LANE: SCOTT / ACTING MASTER (Human-Ops)
  OWNS: env vars, keys, merge approval, phase gates, final truth calls
  MUST NOT: become the default implementer for every lane

LANE: CLAUDE CODE (Backend)
  OWNS: scripts/, netlify/edge-functions/, design.md, .github/workflows/
  MUST NOT: touch public/index.html or trust-layer UI

LANE: CODEX #2 (Frontend)
  OWNS: public/index.html, public/assets/
  MUST NOT: touch backend files, scripts/

LANE: ANTIGRAVITY (QA)
  OWNS: test execution, pass/fail reports, merge recommendations
  MUST NOT: make code changes

LANE: WINDSURF/CASCADE (Acting Master)
  OWNS: orchestration, truth docs, justfile, QA review, merges
```

### Agent Prompts (drop into handoff docs)

#### CASE: MASTER-OPS-TRUTH

```text
AGENT:         Scott / Acting Master
PREFERRED_CLI: just master-cockpit, just master-truth, just qa-ready
TODO:
  - confirm current truth before giving new work
  - assign next owner
  - verify config vs secret placement
  - approve merge only after proof, not vibes
```

#### CASE: CLAUDE-RUNTIME-WIRING

```text
AGENT:         Claude Code
PREFERRED_CLI: just claude-doctor, just claude-vector-probe, just claude-env-check
TODO:
  - keep scripts idempotent
  - preserve machine-readable truth
  - fix runtime/reliability issues in Claude lane only
  - avoid frontend drift
  - document fallback paths clearly
```

#### CASE: CODEX-FRONTEND-SHELL

```text
AGENT:         Codex #2
PREFERRED_CLI: just codex-validate, just codex-preview
TODO:
  - HOLD — waiting on Antigravity QA
  - implement assigned public/index.html work only
  - preserve accessibility in touched UI
  - do not invent new backend transport
```

#### CASE: ANTIGRAVITY-QA-GATE

```text
AGENT:         Antigravity
PREFERRED_CLI: just antigravity-qa, just antigravity-smoke, just qa-ready
TODO:
  - run QA checklist (16/18 threshold)
  - validate preload questions against live retrieval
  - return pass/fail evidence
  - recommend merge or hold
  - do NOT implement fixes
```

---

## LAYER 4 — VERIFICATION CONTRACT

Every major claim has a proof path. No more "it should work."

### Build Proof

```text
GATE:   just codex-validate -> index.html structure check
GATE:   just backend-typecheck -> Deno check edge functions (when deno installed)
RESULT: build_passed: true | false
```

### Smoke Proof

```text
GATE:   just cv-smoke-cloud -> Cloud Run /health returns { status: "ok", chunks: 124+ }
GATE:   Live site loads at robertoscottecholscv.netlify.app
GATE:   /api/chat returns 200 with { reply, tier } on test POST
RESULT: smoke_passed: true | false
LAST:   17/17 PASS — 2026-04-05
```

### Vector Proof

```text
GATE:   python embed_engine.py --stats -> chunks > 0
GATE:   python embed_engine.py --query "Scott background" -> results returned
GATE:   Cloud Run /health -> { status: "ok", chunks: 124, durable: true }
RESULT: vector_passed: true | false
LAST:   124 chunks durable — 2026-04-05
```

### Pipeline Proof

```text
GATE:   python embed_engine.py --from-manifest -> ingest completes without error
GATE:   Cloud Run /retrieve POST -> returns scored chunks
GATE:   Netlify /api/chat POST with business tier -> RAG-grounded answer
RESULT: pipeline_passed: true | false
LAST:   PASS — 2026-04-05
```

### Deploy Proof

```text
GATE:   git push origin main -> Netlify auto-deploy triggers
GATE:   Netlify deploy log shows "Published"
GATE:   Live site responds 200
GATE:   /api/chat edge function responds
RESULT: deploy_passed: true | false
LAST:   PASS — main branch live
```

### QA Proof

```text
GATE:   Antigravity runs 16/18 checklist
GATE:   Preload questions return grounded answers
GATE:   answer_source field present on /api/chat responses
GATE:   Public question-limit enforced (3 free, then key prompt)
GATE:   Fallback honesty when retrieval unavailable
RESULT: qa_passed: true | false
LAST:   PENDING — awaiting Antigravity
```

---

## DATA BOUNDARY TRUTH

### Partition Map

```text
cv_personal          public     knowledge_base/public/cv/     Resume, skills, career
cv_projects          public     knowledge_base/public/cv/     SirTrav, SeaTrace, WAFC
business_seatrace    business   knowledge_base/business/      SeaTrace API, Four Pillars
business_proposals   business   knowledge_base/business/      Proposals, pricing
internal_repos       business   AGENT_HANDOFFS.md             GitHub repo architecture
recreational         private    —                             Personal interests
```

### Partition Boundary Rules

```text
RULE: Retrieval must respect partition boundaries.
RULE: Public tier searches cv_personal + cv_projects only.
RULE: Business tier may search all partitions.
RULE: Producer brief seeding must never leak business-only context into public output.
RULE: knowledge_base/public/cv/ feeds public. knowledge_base/business/ feeds business only.
RULE: They must never cross.
```

---

## TRUSTED CLI SURFACE

```text
RULE: Prefer stable named commands over ad hoc shell history.
RULE: The prefix IS the lane boundary. Agents run their own prefix.
RULE: Commands must be safe to re-run, cheap by default, explicit about cost.
```

### Shared / Operator Commands (any agent)

- `just cockpit` — fast session resume
- `just stack-truth` — print this file
- `just dependency-map` — print service dependency map
- `just doctor` — repo wiring check ($0)
- `just qa-ready` — QA readiness check
- `just cv-status` — CV identity + corpus stats
- `just cv-smoke-cloud` — Cloud Run + Netlify health probe ($0)
- `just verify-all` — full verification gate

### Lane-Prefixed Commands (agent-specific)

- `just master-cockpit` — Acting Master session resume
- `just master-truth` — print STACK_TRUTH.md for governance review
- `just claude-doctor` — Claude Code diagnostic check
- `just claude-vector-probe` — vector store health from Claude lane
- `just claude-env-check` — env var presence check (boolean only)
- `just codex-build` — frontend build gate (npm run build)
- `just codex-status` — frontend status summary
- `just antigravity-qa` — QA checklist runner
- `just antigravity-smoke` — cloud smoke from QA lane

---

## OPERATIONAL PRINCIPLES

```text
1. Read before write — every agent reads truth files before editing
2. Proof before praise — a feature is done when its proof path passes
3. Archive first — move or archive before deleting whenever practical
4. Secrets never in repo — config may be documented, secrets may be named, never stored
5. Lane boundaries are system safety — read across, never write across
6. One trusted CLI surface — repo-local just commands over ad hoc shell history
7. Netlify-first thinking — start from the live delivery path, work backwards
```

---

## RECOVERY PATTERN

```text
RECOVERY_PATTERN: Diagnose -> Archive-First -> Fix -> Verify -> Record Truth -> Commit
RULE: MOVE not DELETE — destructive cleanup must archive/move first
RULE: Re-ingest only if --stats shows 0 chunks or new CV files added
RULE: When Cloud Run drops env vars: --remove-secrets first, then --set-env-vars
RULE: DATABASE_URL must include ?sslmode=require for Supabase
```

---

## AUDITABILITY RULES

All important operational files must be:
- **Grep-stable** — machine-readable KEY: VALUE lines
- **Version-stamped** — Version: header in every truth file
- **Cost-annotated** — every action that calls an API notes its cost
- **Idempotent** — safe to rerun where marked
- **Lane-owned** — attributed to the agent/owner who wrote it
- **Restart-safe** — any agent can cold-start from this file

---

## ACTING MASTER DECISION LOOP

```text
1. Read truth files first
2. Identify what is live vs local vs optional
3. Identify stale docs and mismatched runtime claims
4. Choose the smallest truthful edit that improves safety
5. Assign work by lane, not by impulse
6. Require proof before merge
7. Record the new truth after verification
```

---

## WHAT WE DO NEXT

1. Antigravity runs QA gate (16/18) against live system
2. Scott approves merge of feat/phase5-ui-trust-layer after QA pass
3. Netlify auto-deploys on push to main
4. Update this file with QA results and deploy proof
5. Begin Phase 6 planning (Gemini multimodal pivot)
6. Keep optional lanes optional — do not block core on Remotion/AWS
7. Standardize justfile commands across repos
8. Push proof artifacts, not just narrative confidence

---

*For the Commons Good*
**Human Admin: Roberto Scott Echols / WSP001**
**Engineering: Windsurf/Cascade (Acting Master) | 2026-04-06**
