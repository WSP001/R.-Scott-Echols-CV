# Operator Handoff — 2026-09-08

**From:** Acting Master (Windsurf/Cascade)
**To:** Scott (Human-Ops) → then `just ops-bootstrap` → then every CLI agent lane
**Plan of record:** WSP001 Engineering Execution Plan, 2026-09-05 (§9 sequence)
**Machine-readable twin:** `plans/handoff_operator_2026-09-08.json`

This document has exactly one purpose: list what is left, prove *why* it needs you and not an
agent, and hand you the single command that does everything after that.

---

## 0. Where the sequence stands

| §9 step | State | Evidence |
|---|---|---|
| 1 Merge CV PR #3 → **G1** | ✅ **GREEN** | `main@0f01b77`, prod deploy `6a9c9f81` published 2026-09-05T23:03:03Z — first since Mar 29 |
| 2 Merge SirTrav PR #30 + file follow-ups | ✅ | `main@d8655095`; issues SirTrav #31, #32, #33 |
| 3 Fix Cloud Run `/retrieve` | 🔴 **needs you** | root cause below |
| 4 `linkedin_history` + re-ingest | ⏸ code on `main`; blocked by 3 | `PUBLIC_PARTITIONS` in `api_server.py`; gate `partition-contract` in `truth_audit.py` |
| 5 Verify **G2** in production | ⏸ blocked by 3 + Anthropic key | `just keys-verify grounded=1` is the proof |
| 6 Provenance contract drift | ✅ | `docs/agent-contracts.md` now documents the *shipped* contract; `provenance` marked PLANNED, NOT SHIPPED with the reason |
| 7 SirTrav retrieval observability | ✅ PR **SirTrav #34** | `RetrievalStatus` port; verified live — shows `timeout ×3` + `linkedin_history: empty/200` |
| 8 Apply evidence-lineage schema | ⏸ after 3 (same database) | `db/evidence_lineage.sql` + `db/evidence_lineage.test.sql` 8/8 on PG 16.15 |
| 9 Your two rulings (A6, tier) | 🟡 tier defaulted to `public`; A6 open | see §2 |
| 10–12 Abacus.AI | ⏸ by design — not before G2 | §8.4 of the plan |

---

## 1. What only you can do — and exactly why

Each item names the credential or authority boundary an agent cannot cross. There is no other
reason any of these are on your list.

### 1.1 Provision a PostgreSQL database with pgvector `[BLOCKS 3, 4, 5, 8]`

**Why you:** The Supabase project behind Cloud Run's `DATABASE_URL` (`ghhsuofktprawkwabrfi`) returns
**NXDOMAIN** on both its API and DB hostnames — it has been deleted, not paused. Creating a
replacement is a billing/account action on a provider console. No CLI on this machine is
authenticated to any Postgres provider, and I will not create billable resources under your account.

**Consequence you should know:** the vector corpus went with it. That is *not* data loss — every
source document is in `knowledge_base/` and `data/rse_cv_manifest.json`; only the embeddings need
regenerating, which the bootstrap does.

**Options, in order of fit:**
1. **Netlify DB** (Neon under the hood, pgvector available). `db/evidence_lineage.sql` already names
   this as its target. Console: Netlify → site → *Extensions* → Neon. Do **not** run `netlify db init`
   from the repo — it adds `package.json` to a zero-build site, which is how the March deploy
   outage happened.
2. New Supabase project → *Settings → Database → Connection string (URI)*. Use the **Session pooler**
   host (`aws-0-<region>.pooler.supabase.com:5432`, user `postgres.<ref>`) — Cloud Run egress is
   IPv4 and Supabase direct hosts are IPv6-only.
3. Neon directly.

**Hand me / the bootstrap:** the DSN as `WSP001_DATABASE_URL`. The service runs
`CREATE EXTENSION IF NOT EXISTS vector` itself on first boot (`vector_store.py:173`).

### 1.2 Rotate `ANTHROPIC_API_KEY` `[BLOCKS 5]`

**Why you:** Production `/api/chat` returns **502 on every request**, on the new code too. The code
distinguishes: missing key → 503, key rejected by Anthropic → 502. So the key on Netlify is revoked
or invalid. Generating a key requires your console.anthropic.com login. Netlify will accept the new
value from the bootstrap (`netlify env:set`) — you only have to create it.

### 1.3 Rotate `GEMINI_API_KEY` and `INGEST_SECRET` `[SECURITY — F7]`

**Why you:** Cloud Run revision `00019-w2z` stores `DATABASE_URL`, `INGEST_SECRET` and
`GEMINI_API_KEY` as **plaintext env values**. `gcloud run services describe` prints them, and it did
so into my tool output on 2026-09-05. Additionally `scripts/setup-pgvector.ps1` carried the
`INGEST_SECRET` value hardcoded (removed in `de9a54b`, but it is in git history forever). Treat both
as burned.

- `GEMINI_API_KEY`: needs your Google AI Studio login.
- `INGEST_SECRET`: **no action needed** — the bootstrap generates a fresh 32-hex value if
  `WSP001_INGEST_SECRET` is unset and stores it in Secret Manager.
- The deploy script now uses `--set-env-vars` (replaces the whole plaintext set) + `--set-secrets`
  (Secret Manager refs only) and **hard-fails** if any of the three secrets is missing from Secret
  Manager. It is no longer possible to deploy with a pasted secret.

### 1.4 LinkedIn `Shares.csv` export `[UNBLOCKS the SirTrav voice pack]`

**Why you:** LinkedIn → *Settings → Data privacy → Get a copy of your data → Posts*. It is your
account. No copy exists in either repo (`ingest-linkedin-posts.mjs` expects `--csv` or `--md`).
Set `WSP001_LINKEDIN_CSV` to the path and the bootstrap ingests it into `linkedin_history`.
Without it the partition is *allowed* but *empty* — SirTrav PR #34 now makes that visible as
`linkedin_history: empty/200` instead of silence.

### 1.5 Ruling A6 — the three SeaTrace claims `[GATE G3]`

**Why you:** `knowledge_base/public/cv/seatrace_four_pillars_summary.md` states a consumer-facing
traceability certificate / QR labeling claim, "SIMP-compliant forms", and "designed to meet NOAA
SIMP, EU IUU, and GFW compliance standards." These are claims about *your* product. The ruling
goes in `docs/CONTENT_SOURCE_OF_TRUTH.md`. An agent recording a ruling on your behalf is exactly the
class of ungrounded claim the whole system exists to prevent.

**Note:** the bootstrap's ingest stage runs regardless. If you want the ruling in *before* the corpus
is embedded, record it first, then run the bootstrap. Otherwise re-run `just ops-bootstrap "-Only ingest,verify"`
after the ruling — ingest is idempotent by content hash.

### 1.6 Confirm `linkedin_history` tier `[decision already defaulted]`

I set it to **`public`** (posts are already public). One-line flip in `scripts/api_server.py`
`PUBLIC_PARTITIONS` if you disagree. Redeploy Cloud Run after changing.

---

## 2. The one command

Once you have 1.1, 1.2, 1.3 (Gemini) in hand — and optionally 1.4:

```powershell
Set-Location "$env:USERPROFILE\OneDrive\DevHub\R.-Scott-Echols-CV"
git checkout main; git pull

$env:WSP001_DATABASE_URL      = '<postgresql://...>'
$env:WSP001_GEMINI_API_KEY    = '<new key>'
$env:WSP001_ANTHROPIC_API_KEY = '<new key>'
$env:WSP001_LINKEDIN_CSV      = 'C:\path\to\Shares.csv'   # optional

just ops-bootstrap                    # preflight → secrets → cloudrun → ingest → netlify → verify
Remove-Item Env:\WSP001_*
```

What it does, stage by stage, and what "done" looks like:

| Stage | Action | Proof it passed |
|---|---|---|
| preflight | tools + auth + `main` clean + `truth_audit.py` | `OK truth-audit PASS` |
| secrets | upsert 3 secrets into GCP Secret Manager; grant Cloud Run SA `secretAccessor` | `OK ... stored (Secret Manager, version latest)` |
| cloudrun | build image from `main`, deploy with secret refs + `VECTOR_STORE_BACKEND=pgvector` | `/health ok backend=pgvector` **and** `/partitions includes linkedin_history` |
| ingest | `embed_engine.py --from-manifest` (+ LinkedIn CSV) → Cloud Run `/ingest` | `chunks in pgvector: N` with N > 0 |
| netlify | `env:set` Anthropic + `VECTOR_ENGINE_URL`; clear-cache build from git `main`; wait `ready` | `production deploy ready: https://robertoscottecholscv.netlify.app @ <sha>` |
| verify | `just keys-verify grounded=1` | **`KEYS-VERIFY: PASS`** with `rag_status ok` → **G2 GREEN** |

Resume after a partial failure with `just ops-bootstrap "-Only <stage>,<stage>"`.
Rehearse with `just ops-bootstrap "-DryRun"` — it mutates nothing.

**Secrets never leave your shell.** The script reads env only, never echoes values, and clears
`INGEST_SECRET`/`GEMINI_API_KEY` from its own env in a `finally`.

---

## 3. For the CLI agents — historical reference and what to fix next

Read `AGENT_HANDOFFS.md` entries F1–F8 first. Then:

**Pattern that caused every outage here:** silent degradation. Canceled deploys reported as
"ignored"; empty retrieval reported as HTTP 200; a deleted database behind a 200 `/health`; a
partition the service never knew about returning `[]`. Every fix this round makes the next failure
*loud*: `rag_status` + `X-RAG-Status` (CV), `RetrievalStatus` + `retrieval_degraded` (SirTrav),
`partition-contract` gate (truth audit), `keys-verify` (live proof), `deploy-cloud-run.ps1` hard-fail
on missing secrets. **When you add a new integration, add its failure signal in the same PR.**

**Open work, in order:**

1. **SirTrav #34** — merge when checks are green. Then in `run-pipeline-background.ts` surface
   `pack.status` on the pipeline result object so the UI can show "voice pack: empty" instead of
   inferring it.
2. **SirTrav #31 / #32 / #33** — the pwsh follow-ups. #31 is the real work (23 `@powershell`
   lines + hardcoded `WSP2agent` path at 8 lines).
3. **§9 step 8** — apply `db/evidence_lineage.sql` to the *same* database from 1.1, run
   `db/evidence_lineage.test.sql`, expect 8/8 and `SELECT * FROM v_stale_claims` → 0 rows. Then
   `v_publication_blockers` becomes the A6 worklist.
4. **`provenance` object** — ships when `/retrieve` results carry a `boundary` tag so
   `project_source` is read from metadata, not guessed from the question. Add `boundary` to the
   ingest metadata in `embed_engine.py` first.
5. **Cloud Run `/health`** — currently returns HTTP 200 with `status: degraded`, which satisfies
   Cloud Run's probe while the service is useless. Decide: return 503 when degraded (probe restarts
   the container, which will not help a bad DSN) or keep 200 and alert on the body. `keys-verify`
   already reads the body; a monitor should too. That is §8.3 / step 12.
6. **`docs/A2A_MANIFEST_SCHEMA.md`** is zero bytes (plan §4.5). The schema lives in
   `netlify/functions/lib/d2a-parser.ts`. Write it from the parser, not from memory.
7. **Abacus.AI** — §8.1 fallback mode in `api_server.py /retrieve` behind an env flag, *only after*
   G2 is green. `postman/WSP001-Stack-Verify.postman_collection.json` already has the auth smoke
   test (`listProjects`) and the environment file has `abacus_api_key` as a secret-type variable.

**Truth-audit cadence** (plan §10): before any PR touching `public/`, `netlify/`,
`knowledge_base/`; after A6 lands; on every push in CI with `--format json --output`.

---

## 4. Evidence trail

| Artifact | Repo / path | State |
|---|---|---|
| Squash merge PR #3 | CV `0f01b77` | on `main` |
| Sourcery re-review | CV PR #3, 4 threads | all resolved ✅ |
| `keys-verify`, Postman | CV `0afd7eb` | on `main` |
| Handoff F1–F8 | CV `AGENT_HANDOFFS.md` `b55fdbc` | on `main` |
| `ops-bootstrap`, deploy hardening, secret purge | CV `de9a54b` | on `main` |
| Contract doc fix (§4.4) + this handoff | CV (this commit) | on `main` |
| PR #30 squash | SirTrav `d8655095` | on `main` |
| Follow-ups | SirTrav #31, #32, #33 | open |
| Retrieval observability (§4.3) | SirTrav PR #34 | open, checks pending |
| Cloud Run diagnosis | `gcloud run services describe rse-retrieval` rev `00019-w2z`; `Resolve-DnsName` NXDOMAIN ×2 | measured 2026-09-05 |
| Live `/api/chat` | HTTP 502, body `"I'm having trouble connecting..."` | measured 2026-09-05 & -08 |

Nothing in this document is predicted. Every row above was executed or measured in this session.
