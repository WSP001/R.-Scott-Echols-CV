# HANDOFF — Evidence-Lineage Round (R1)

**Issued:** 2026-08-21 · **Issued by:** Netlify Agent Runner (Lane 2, backend/DevOps)
**Site:** robertoscottecholscv.netlify.app · **Read first:** `CLAUDE.md`, `docs/agent-contracts.md`

---

## 0. Verified state of the system (measured, not assumed)

Everything below was reproduced against this repository and the live backend on 2026-08-21.

| # | Finding | Evidence | Status |
|---|---------|----------|--------|
| F1 | **Every production deploy since 2026-03-29 was canceled by one line of config.** `netlify.toml` carried `ignore = "exit 0"`. Netlify's ignore contract is inverted: exit **0** means "yes, ignore this build" → deploy canceled; a **non-zero** exit means "build it". | Added in commit `7dfb16b`, 2026-03-29 19:14, *"fix(netlify): ignore scripts/ and Python files at build time"*. Last successful publish: Mar 29. Canceled since: `f918dca`, `a77690f`, `6ea6717`, `5026cd8`. | **FIXED** in this change |
| F2 | **RAG has been returning nothing, silently.** Cloud Run `/health` → **200**, but `POST /retrieve` → **502**. `fetchRAGContext` caught every error and returned `""`, so a hard backend failure was indistinguishable from "no relevant context". The chatbot has been answering from the static prompt only. | Live probe + reproduced locally: `{"event":"rag_degraded","status":"upstream_error","detail":"HTTP 502","attempts":3}` | **Detection fixed** here. **Backend fix is Human-Ops** — see A4 |
| F3 | **The grounding corpus contradicts the regulatory framing.** `knowledge_base/public/cv/seatrace_four_pillars_summary.md` claims Pillar 1 uses "SIMP-compliant forms", Pillar 2 is "designed to meet NOAA SIMP", and Pillar 3 is "**Consumer-facing** traceability certificates and QR-code product labeling". NOAA states SIMP is **not** a consumer-facing program and SIMP-collected data is confidential. The same text is baked into `public/fallback_snapshot.json`. | `grep -w SIMP knowledge_base/ public/fallback_snapshot.json` | **UNRESOLVED — owner decision required, see A6** |
| F4 | **The corpus cannot support the lineage language at all.** Word-boundary search across the whole repo: `Magnuson` 0, `FSMA` 0, `CTE` 0, `KDE` 0, `TLC` 0, `ITDS` 0, `harvest ticket` 0. `SIMP` appears only as biography, never as a requirement. | full-repo grep | **UNRESOLVED — this is the research round, R1** |
| F5 | **API contract drift.** `docs/agent-contracts.md` documented `tokens_used` (never populated) and `answer_source` values `"Embedded CV — Public Profile"` / `"Embedded Knowledge — Business"` — the backend emits `"Verified Profile Pack — …"`. Any QA assertion on the documented strings was asserting a value the backend never sent. | doc vs. `chat.ts` | **FIXED** both sides |
| F6 | Publish directory is 29 MB; 28 MB is `public/audio/sir-james`. Audio is lazy-loaded via JS, so it does **not** affect Lighthouse, but several filenames contain spaces and apostrophes (`_Sir James' Adventure Song_.mp3`) — URL-encoding hazard. `index.html` is 188 KB with ~56 KB inline JS and ~55 KB inline CSS. | `du`, byte census | **ADVISORY — Codex, A5** |

> **The single most important sentence in this document:** the site has not been able to
> deploy for roughly five months, and the chatbot has been ungrounded for at least as long.
> No content or prompt work would have shown up in production. Fix the pipe before judging the water.

---

## 1. Answer to the question that was actually asked

> *"Did you find anything inside the database that has the potential to improve that language right there?"*

**No — and the corpus currently works against it.** Two separate problems:

1. **Absence.** There is no Magnuson-Stevens, FSMA 204, CTE/KDE/TLC, or ITDS/ACE material
   anywhere in the repository. The RAG store cannot ground a single sentence of the lineage
   framing. Asking the chatbot about FSMA 204 today produces model prior, not evidence.

2. **Contradiction.** What *is* there asserts the opposite of the framing. "Consumer-facing
   traceability certificates and QR-code product labeling" sitting next to "NOAA SIMP" is
   precisely the `DIRECT_REGULATORY_MATCH` overclaim the boundary rule exists to prevent.
   The retrieval layer, once repaired, will surface that text as grounded truth.

**Therefore the ordering is:** repair the pipe (done) → correct the corpus (A6) → run the
research round (A7) → populate the crosswalk → *then* rewrite public language. Running the
campaign rewrite before the crosswalk would harden the overclaim into the training fixtures.

**The framing sentence is already the strongest asset in the packet.** It survives scrutiny
because it claims parallel *reasoning*, not parallel *authority*:

> The government record already demonstrates that accountability and unrestricted public
> disclosure are not the same thing. SeaTrace is researching how to preserve evidence
> continuity across that boundary operationally.

Keep it. It is defensible with or without the crosswalk. Everything stronger than it needs R1 first.

---

## 2. The relational database — yes, and here is its shape

> *"is it the relational database THAT WE HAVE TO WRITE, right? … a public map compounded with a private graph"*

Correct, and that phrase is a precise specification. It is implemented as
**`db/evidence_lineage.sql`** (301 lines, parse-validated against the real PostgreSQL grammar
via `libpg_query`; 23 statements, 0 errors). Design intent:

- **Private graph** — `authority`, `authority_requirement`, `legacy_artifact`,
  `crosswalk_claim`, `lineage_edge`, `conflict_gap`, `source_citation`. Full detail,
  including `NO_SUPPORTED_MATCH` rows, which are recorded and never deleted.
- **Public map** — the view `v_public_map`. A claim surfaces only when the claim **and** its
  requirement **and** its artifact are all `PUBLIC`, the claim is `READY_FOR_CROSSWALK`, and at
  least one **primary** source supports it. Public safety is a property of the schema, not of
  application code someone can forget to write.

Two of the round's rules are enforced as database constraints, so a careless `INSERT` cannot
produce an indefensible claim:

| Rule | Enforcement |
|------|-------------|
| "Do not claim a historical WSP design complied with FSMA 204 before FSMA 204 existed" | `ck_no_anachronistic_compliance` — a `DIRECT_REGULATORY_MATCH` is rejected unless both dates are known **and** the artifact post-dates the authority |
| "Use *anticipated* / *functionally analogous* only where evidence supports it" | `temporal_claim` enum + `ck_complied_with_requires_direct` — `COMPLIED_WITH` is unavailable to any non-direct match |
| "SIMP is not consumer-facing" | `authority.is_consumer_facing`, defaulting to false and carrying a comment that SIMP must remain false |

`v_publication_blockers` tells the social-media manager exactly why any given claim is not yet
publishable, in one query.

**Deliberately not done:** the schema is *not* wired to Drizzle/`@netlify/database`. This site
is intentionally zero-build (`command = ""`, no `package.json`). Introducing npm + `drizzle-kit`
in the same change that repairs the deploy would risk re-breaking the thing being fixed, and the
tables would be empty until R1 completes. Wiring is assignment **A3**, to be done *after* the
first green deploy, with exact steps below.

---

## 3. Round sequencing — the whole completion flow

```
  R1-0  VERIFY DEPLOY IS ALIVE            ← gate. nothing proceeds until green.
        Human-Ops · confirm main deploys and publishes
                │
        ┌───────┴────────┐
        ▼                ▼
  R1-1 BACKEND      R1-2 CORPUS TRUTH
  Human-Ops fixes   Owner (Scott) rules on the Pillar 3
  /retrieve 502     consumer-facing claim  (BLOCKING for public language)
        │                │
        └───────┬────────┘
                ▼
  R1-3  RESEARCH DISPATCH  (5 agents, §4) → chronology, authority matrix,
        crosswalk, disclosure map, conflicts register, bibliography
                │
                ▼
  R1-4  LOAD  → populate db/evidence_lineage.sql; constraints reject bad claims
                │
                ▼
  R1-5  INGEST → re-embed corrected corpus + crosswalk into pgvector
                │
                ▼
  R1-6  QA GATE → Antigravity asserts rag_status='ok' and no overclaim survives
                │
                ▼
  R1-7  PUBLIC LANGUAGE → campaign rewrite, sourced ONLY from v_public_map
```

**Hard gate:** R1-7 may not begin before R1-6 passes. That single ordering rule is what keeps
fourteen years of legacy material from becoming fourteen years of unsourced claims.

---

## 4. Research dispatch — five bounded agents

Do **not** give this to one general researcher. Five lanes, one reconciler. Each returns one of
`READY_FOR_CROSSWALK` / `HOLD_SOURCE_GAP` / `HOLD_LEGAL_INTERPRETATION` / `HOLD_BOUNDARY_RISK`.

| Agent | Owns | Must establish before any SeaTrace comparison |
|-------|------|-----------------------------------------------|
| **RA-1 Statute** | Magnuson-Stevens: fisheries information collection and the confidentiality regime, including its defined exceptions | What may be collected, who may receive it, what is protected, and on what statutory basis |
| **RA-2 Import** | SIMP + ITDS/ACE: harvest-to-entry data, "May Proceed", recordkeeping | Which species, which data elements, retention duties, and NOAA's own statement that SIMP is confidential and not consumer-facing |
| **RA-3 Food safety** | FSMA 204: CTEs, KDEs, Traceability Lot Code, the Food Traceability List, and current implementation/enforcement posture including the July 20 2028 date | Forward vs. reverse trace, which records cross organizational boundaries, 24-hour production expectations, correction and retention duties |
| **RA-4 Legacy** | The WSP/SeaTrace corpus: harvest ticket, fish-ticket indexing, receiving weight, scale evidence, key/rail separation, packet switching, predecessor/backlink, lot transformation, recovery reconciliation, forward/reverse trace, retained audit records, correction/supersession | For each artifact: **a date and the evidence for that date**. Undated artifacts cannot support a direct match — the schema will reject them |
| **RA-5 Verifier** | Reconciles RA-1…RA-4 into one source-controlled crosswalk | Every row classified and cited; disagreements recorded in `conflict_gap` rather than smoothed over |

**Sequencing rule:** RA-1, RA-2, RA-3 run first and in parallel — the government record must
exist before comparison is possible. RA-4 may run concurrently but its output is *not* merged
until the three authority lanes report. RA-5 runs last, alone.

**Standing constraints for all five:**
- Primary sources first: statute, CFR, Federal Register, NOAA Fisheries, FDA, CBP/ACE, official guidance. Commentary may contextualise; it may never be the sole support for a `DIRECT_REGULATORY_MATCH`.
- Do not begin from a SeaTrace conclusion.
- Never surface private commercial figures, customer identities, exact positions, proprietary thresholds, recovery heuristics, settlement logic, credentials, or private-repo internals. On doubt, return `HOLD_BOUNDARY_RISK` and stop.
- Every claim carries a citation with a retrieval date and a verbatim excerpt.

---

## 5. Assignments by CLI

### A1 — Claude Code (Lane 2 · backend) — **DONE in this change, verify only**
- `netlify.toml`: removed `ignore = "exit 0"`, with the inverted contract documented inline so it is never re-added.
- `chat.ts`: retrieval now retries 3× with full-jitter exponential backoff (200 ms base, 4 s per-attempt timeout) and reports `rag_status` in the body, `X-RAG-Status` on the response, and a structured `rag_degraded` log line.
- `chat.ts`: the Anthropic call had **no retry at all** — a transient 429/529 became a user-visible failure. Now 3 attempts against a 45 s wall-clock deadline, honouring `Retry-After`, failing fast on 401/403/400.
- `chat.ts`: `tokens_used` is now genuinely returned from `usage.output_tokens`.
- Model lock intact: `claude-opus-4-6`.
- **Verify:** `deno check netlify/edge-functions/chat.ts` — clean apart from the runtime-provided `Netlify` global.

### A2 — Claude Code — next
- Add a static grounding fallback so a retrieval outage degrades to `public/fallback_snapshot.json` instead of to model prior. Select the top ~3 chunks by keyword overlap; do not inject all 16 KB. Emit `rag_status: 'fallback_local'` and extend the contract union.
- Add `GET /api/health` reporting `{ rag, model, corpus_version }` so uptime checks catch F2-class failures within minutes instead of five months. Document it in `docs/agent-contracts.md` **before** Codex or Antigravity consume it.

### A3 — Claude Code — after the first green deploy, not before
Wire `db/evidence_lineage.sql` to Netlify Database:
```bash
npm install @netlify/database drizzle-orm@beta
npm install -D drizzle-kit@beta
# translate db/evidence_lineage.sql into db/schema.ts (pgTable, snake_case columns)
npx drizzle-kit generate --name evidence_lineage_init
```
Keep the CHECK constraints and both views — Drizzle will not generate them from `pgTable`
definitions; carry them in a hand-written migration in `netlify/database/migrations/`.
Confirm the deploy is still green **immediately** after adding `package.json`: introducing a
build step to a previously zero-build site is exactly how F1 happened.

### A4 — Human-Ops (Scott) — **BLOCKING**
1. Confirm `main` now deploys and publishes. This unblocks every other lane.
2. Fix Cloud Run `/retrieve`: `/health` is 200 while `/retrieve` is 502, which points at the retrieval path itself — most likely the vector store connection or a missing/empty pgvector collection, not the container. Check the revision logs, then confirm the 121 chunks are actually present in Supabase.
3. Re-run ingest once the corpus corrections in A6 land.
4. Keep `VECTOR_ENGINE_URL` pointed at the working revision.

### A5 — Codex (Lane 1 · frontend) — do not start before A4.1
- Consume `rag_status`. The UI currently shows a "Trust Layer Ready" pill regardless of grounding; it should distinguish grounded, ungrounded-but-honest, and degraded. A trust badge that is always green is worse than no badge.
- `answer_source` strings changed in the contract — re-check the pill mapping against `docs/agent-contracts.md`.
- Advisory (F6): rename audio files to remove spaces and apostrophes; consider extracting the ~111 KB of inline CSS/JS from `index.html` once Lighthouse reports are flowing again.
- **Lighthouse is installed on this site** (`@netlify/plugin-lighthouse@6.0.1`) but has produced no report since March, because canceled deploys run no plugins. Treat the first post-fix report as the real baseline; anything older is stale.

### A6 — Owner decision (Scott) — **BLOCKING for public language**
Three claims in `knowledge_base/public/cv/seatrace_four_pillars_summary.md` need a ruling.
These are statements about your own product, so they are not mine to rewrite:

1. *"Consumer-facing traceability certificates and QR-code product labeling"* — is this shipped, roadmap, or aspiration? It reads as a SIMP-adjacent public-disclosure claim, which is the one thing NOAA says SIMP is not.
2. *"SIMP-compliant forms"* — compliant with the program's data elements, or merely modelled on them?
3. *"designed to meet NOAA SIMP, EU IUU, and GFW compliance standards"* — "designed to meet" is defensible; "meets" is not, absent an audit.

Suggested reframing that keeps the substance and survives scrutiny — Pillar 3 becomes a
*capability* claim rather than a *regulatory* one: traceability certificates and QR linkage are
a SeaTrace product feature (`SEATRACE_EXTENSION`), explicitly **not** a SIMP output. Once the
crosswalk exists, each pillar carries its own classification code.

Until this is settled, the corrected text should not be re-ingested — whatever is in the store
is what the chatbot will state as fact.

### A7 — Antigravity (Lane 3 · QA) — after A1 deploys
- Assert `rag_context_used === true` ⟺ `rag_status === 'ok'`.
- Assert `X-RAG-Status` equals the body's `rag_status`.
- **Fail the build** when production `rag_status` is `upstream_error` / `timeout` / `unreachable` / `malformed`. This is the check whose absence let F2 run for five months.
- Assert `answer_source` is one of the four values now documented — the old two strings were never emitted by the backend.
- Add a boundary test: ask the deployed bot *"Is SeaTrace SIMP compliant?"* and *"Does SeaTrace satisfy FSMA 204?"* Until R1 completes, the correct answer is a decline, not a claim. Today it will likely claim. Record the current answers as the pre-round baseline.

### A8 — Windsurf/Cascade (Master)
- Hold the R1-6 → R1-7 gate. That is the whole job this round.
- Land R1 findings in `AGENT_HANDOFFS.md` so the other lanes see F1–F6 before their next write.
- Note that the daily `auto: refresh GitHub repo context … [skip ci]` commits are a separate mechanism from F1 and were **not** the cause; do not "fix" them in response to this document.

---

## 6. Open-knowledge packet — what I need to go further

Ranked by how much each unblocks. Items 1–3 are the difference between advising and building.

1. **Cloud Run `/retrieve` revision logs and the pgvector row count.** F2 is diagnosable from
   outside only as far as "502 with a healthy container". The logs turn that into a fix.
2. **The ruling on A6.** Every downstream artifact — corpus, fixtures, campaign language —
   depends on which of those three claims survive.
3. **The legacy corpus itself, with dates.** RA-4 cannot classify what it cannot see, and
   `ck_no_anachronistic_compliance` will reject every undated artifact. For each: the artifact,
   the earliest defensible date, and *how* that date is established.
4. **The FastAPI retrieval source** (`scripts/api_server.py`, `vector_store.py` are here; the
   deployed revision may differ). Needed to align the Deno and Python retry semantics.
5. **Whether this site may acquire a build step.** Governs A3. If the answer is no, the schema
   lives in a service that already has one, and this site stays static.
6. **Supabase/pgvector connection details** — via Netlify environment variables only, never in
   a file, never in a prompt.

---

## 7. Gates

| Gate | Condition | Owner |
|------|-----------|-------|
| G1 | `main` deploys and publishes | Human-Ops |
| G2 | `/api/chat` returns `rag_status: 'ok'` in production | Human-Ops + Claude Code |
| G3 | A6 ruling recorded in `docs/CONTENT_SOURCE_OF_TRUTH.md` | Scott |
| G4 | All five research agents return `READY_FOR_CROSSWALK` | RA-5 |
| G5 | `v_public_map` non-empty; `v_publication_blockers` reviewed | Claude Code |
| G6 | Antigravity boundary tests pass on the deployed bot | Antigravity |
| G7 | Campaign rewrite cites only `v_public_map` rows | Social-media manager |

**FOR THE COMMONS GOOD** — the retry/observability pattern in `chat.ts` and the
public-map/private-graph schema in `db/evidence_lineage.sql` are both written to be lifted into
SeaTrace002 and SirTrav-A2A-Studio without modification.
