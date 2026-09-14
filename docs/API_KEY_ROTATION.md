# API Key Runbook — R. Scott Echols CV / Smart Chat Bot

> **Lane**: Claude Code (Backend / API / RAG / DevOps)
> **Audience**: Human-Ops (Scott) + any agent touching credentials
> **Last verified**: 2026-09-08 against live Netlify config for `robertoscottecholscv`

This is the authoritative answer to *"how do we change the API key for the database
smart chat bot?"* Read the key map first — **which** key you rotate changes **how many
places** you have to touch.

---

## 1. Key Map — what each key does and where it lives

| Key | Powers | Read at | Netlify scope |
|-----|--------|---------|---------------|
| `ANTHROPIC_API_KEY` | Claude Opus — the chatbot's brain | `netlify/edge-functions/chat.ts:347` | **Account-level (shared)** |
| `GEMINI_API_KEY` | Gemini Embedding 2 — the **vector database** key | `embed.ts:60`, `scripts/embed_engine.py:90`, `scripts/api_server.py:90` | **Account-level (shared)** |
| `BUSINESS_ACCESS_KEY` | Business-tier invitation passphrase (not a vendor key) | `verify-access.ts:28`, `chat.ts:306`, `embed.ts:52`, `abacus.ts` | **Account-level (shared)** |
| `ABACUS_API_KEY` | Abacus.AI — `/api/abacus` side channel, business tier only | `netlify/edge-functions/abacus.ts` | Set at site level |
| `ABACUS_MODEL` | Optional RouteLLM model name (default `route-llm`) | `netlify/edge-functions/abacus.ts` | Site level, optional |
| `VECTOR_ENGINE_URL` | Cloud Run `/retrieve` endpoint (a URL, not a key) | `chat.ts:357` | Site-level |
| `INGEST_SECRET` | Protects Cloud Run ingest route | `scripts/api_server.py:56` | **Not in Netlify** — GCP Secret Manager only |
| `DATABASE_URL` | PostgreSQL + pgvector DSN — **the corpus itself** | `scripts/api_server.py` | **Not in Netlify** — Cloud Run secret only (see §12) |

**"Database" key = `GEMINI_API_KEY`.** It is the credential that turns text into the
3072-dim vectors used for retrieval. It is also the *only* key that lives in **three
separate systems**, so it is the one most likely to be rotated incompletely.

---

## 2. This project uses Edge Functions — `process.env` does NOT apply

Generic Netlify advice says to read keys with `process.env.MY_KEY`. **That is wrong for
this repo.** There is no `netlify/functions/` directory. All four endpoints are
**Deno edge functions** declared in `netlify.toml`, and they read config with:

```ts
const key = Netlify.env.get("ANTHROPIC_API_KEY");   // correct here
// const key = process.env.ANTHROPIC_API_KEY;       // WRONG — undefined in Deno edge runtime
```

`process.env` would silently return `undefined`, and `chat.ts` would answer every
request with a `503 "AI service not configured"`. Use `Netlify.env.get()`.

The server-side rule in the generic advice **is** correct and this repo already follows
it: no key value appears in `public/index.html` or any client asset (verified by scan —
the only match is a fallback *message* that names the variable, never its value).

---

## 3. Change a key in Netlify (the general procedure)

Dashboard → **Site settings → Environment variables** → pick the key → **Edit** →
paste the new value → Save. Or by CLI:

```bash
netlify env:set ANTHROPIC_API_KEY "<new-value>"
```

Then **redeploy** — see §7. That step is not optional.

> **Blast radius warning.** `ANTHROPIC_API_KEY`, `GEMINI_API_KEY` and
> `BUSINESS_ACCESS_KEY` are stored at **account level**, shared with every other site on
> the team. Rotating one breaks any sibling WSP001 site reading the same variable.
> Rotate deliberately, or add a site-level override first.

---

## 4. Rotate `GEMINI_API_KEY` (the database key) — all 3 places

Issue the replacement at <https://aistudio.google.com/apikey>, then:

**4a. Netlify** (powers `/api/embed`) — per §3.

**4b. GCP Secret Manager** (powers Cloud Run `/retrieve`). `scripts/deploy-cloud-run.ps1`
mounts this from Secret Manager, not from a literal:

```powershell
echo "<new-value>" | gcloud secrets versions add GEMINI_API_KEY --data-file=-
gcloud run services update rse-retrieval --region=us-central1 `
  --update-secrets GEMINI_API_KEY=GEMINI_API_KEY:latest
```

**4c. Local shell** (powers `embed_engine.py` ingest):

```powershell
$env:GEMINI_API_KEY = "<new-value>"   # current session
just backend-check-env               # confirm presence
```

> **Re-ingest is NOT required.** Vectors already stored stay valid — rotating the
> credential does not change the embedding math. Only a change of *model*
> (`GEMINI_EMBED_MODEL`) invalidates the store and forces
> `python scripts/embed_engine.py --from-manifest` again.

---

## 5. Rotate `ANTHROPIC_API_KEY` (the chatbot brain) — 1 place

Issue the replacement at <https://console.anthropic.com/settings/keys>, set it in Netlify
per §3, redeploy. Nothing else consumes it — Cloud Run does not call Claude.

**Reading the failure mode matters here:** `chat.ts` returns **503** when the key is
*missing* and **502** when the upstream call *fails*. A 502 therefore means the variable
is set but its value was rejected — rotate it. (This is exactly the state found on
2026-09-08: Anthropic returned `401 authentication_error — invalid x-api-key`.)

`CLAUDE.md` locks the chatbot to Claude Opus 4.6 (`claude-opus-4-6`) — a valid current
model ID. Do not "fix" a 502 by changing the model string.

## 6. Set or rotate `ABACUS_API_KEY` — 1 place

Generate it in the Abacus.AI console → **API Keys Dashboard** → *Generate new API Key*.
Set it in Netlify per §3, redeploy, then verify with `just abacus-test`.

Two Abacus.AI surfaces are reachable through `/api/abacus`, and **they authenticate
differently** — this is the most common integration mistake:

| op | Upstream | Auth header |
|----|----------|-------------|
| `health`, `projects` | `https://api.abacus.ai/api/v0/listProjects` | `apiKey: <key>` |
| `chat` | `https://routellm.abacus.ai/v1/chat/completions` | `Authorization: Bearer <key>` |

RouteLLM is OpenAI-compatible; the management API is not — it uses a bare `apiKey`
header, **not** `Authorization: Bearer`. An upstream **401** means the key is invalid; an
upstream **403** usually means the account lacks the required paid subscription.

## 7. Rotate `BUSINESS_ACCESS_KEY` (invitation passphrase) — 1 place

This is a self-chosen passphrase, not a vendor credential. Changing it **immediately
invalidates every invitation key already handed out**, so notify recipients first. It
also gates `/api/abacus`, so rotating it locks that endpoint until callers are updated.

---

## 8. Redeploy — required, not optional

Netlify env changes do **not** reach already-published edge functions. After any change:

```bash
netlify deploy --build --prod
```

Or Dashboard → **Deploys → Trigger deploy → Clear cache and deploy site**.

---

## 9. Verify after rotating

```bash
just keys-verify              # /api/chat reachable + rag_status reported
just keys-verify grounded=1   # same, but EXITS NON-ZERO unless rag_status == "ok"
just abacus-test              # Abacus.AI key accepted (op=health)
just vector-test              # Cloud Run retrieval
```

A `503` means the variable is missing or the redeploy did not happen. A `502` on
`/api/chat` means the key was rejected upstream.

**Check `rag_status`, not just the HTTP status.** The chatbot falls back to its embedded
profile pack when retrieval is down rather than erroring, so a 200 with a fluent answer
proves nothing about grounding. As of 2026-09-13 the response reports which of six
things actually happened:

| `rag_status` | Meaning | What to do |
|--------------|---------|------------|
| `ok` | retrieval fed the answer | nothing — this is green |
| `not_configured` | `VECTOR_ENGINE_URL` unset | set it (§1), redeploy |
| `upstream_error` | Cloud Run reachable but failing | check `DATABASE_URL` (§12) |
| `timeout` | Cloud Run too slow / cold start | re-test; check min-instances |
| `empty` | corpus has zero rows | run an ingest (§12) |
| `below_threshold` | rows exist, nothing relevant | relevance problem, not plumbing |

`rag_context_used` is retained and equals `rag_status === "ok"`, so old checks still work.

Use `just keys-verify grounded=1` in CI or after any database work — it fails loudly
instead of letting an ungrounded chatbot look healthy.

---

## 10. Netlify CLI and the Abacus.AI CLI do not talk to each other

A reasonable question, and the answer is no — there is no CLI-to-CLI integration:

- **Netlify CLI** manages Netlify resources: `netlify env:set`, `netlify deploy`,
  `netlify dev`. It has no knowledge of Abacus.AI.
- **The Abacus.AI CLI** (`npm i @abacus-ai/cli`, or the `install.sh` script) is a
  *terminal coding agent* — a peer of Claude Code, not an API transport. It needs an
  Abacus Pro/Teams subscription.
- **The `abacusai` Python SDK** is the programmatic client and ships **no** CLI entry point.

The two toolchains meet at exactly one point — the environment variable:

```
netlify env:set ABACUS_API_KEY "<key>"   →   Netlify stores it
                                         →   abacus.ts reads Netlify.env.get("ABACUS_API_KEY")
                                         →   calls api.abacus.ai / routellm.abacus.ai over HTTPS
```

So the integration is **env var + REST at runtime**, never one CLI shelling into the
other. Don't try to invoke the Abacus CLI from a build or an edge function: edge
functions run in a Deno sandbox with no shell, and build-time CLI calls cannot serve
per-request traffic.

---

## 12. `DATABASE_URL` — the corpus DSN (Cloud Run secret, **not** Netlify)

Added 2026-09-13, when `scripts/api_server.py` was synced from ChromaDB to
PostgreSQL + pgvector to match what Cloud Run was already running.

**Do not put this in Netlify.** No edge function reads it and no edge function should:
it is a database superuser-grade credential, and edge functions are the
internet-facing layer. The only consumer is the `rse-retrieval` Cloud Run service.
`just keys-map` shows this explicitly.

### Set it

```bash
# 1. Store the DSN in Secret Manager (never as a plain --set-env-vars value)
printf '%s' 'postgresql://USER:PASSWORD@HOST:5432/DBNAME?sslmode=require' \
  | gcloud secrets create DATABASE_URL --data-file=-

# Rotating an existing one instead:
printf '%s' '<new dsn>' | gcloud secrets versions add DATABASE_URL --data-file=-

# 2. Point the service at it
gcloud run services update rse-retrieval \
  --region=us-central1 \
  --update-secrets=DATABASE_URL=DATABASE_URL:latest

# 3. Create the schema (idempotent — safe to re-run)
export DATABASE_URL='<dsn>'   # local shell only, for this one command
just db-schema

# 4. Confirm
curl -s https://<service-url>/health | jq
```

`?sslmode=require` is **mandatory** — managed Postgres providers reject or silently
downgrade unencrypted connections, and psycopg will not add it for you.

`just db-schema` runs `scripts/schema/wsp001_knowledge.sql`: creates the `vector`
extension, the `wsp001_knowledge` table with `embedding VECTOR(3072)`, the
`(partition, content_hash)` dedupe index, and seeds the `wsp001_partitions` tier
registry.

### Verify

`GET /health` returns `status: "degraded"`, never `"ok"`, whenever the database is
unreachable. A green health check on a dead corpus is how silent RAG failure survives
for weeks, so this endpoint is deliberately pessimistic. Errors it returns are passed
through `safe_error()`, which redacts anything DSN-shaped — psycopg exceptions embed
the full connection string **including the password**, and `/health` is
unauthenticated.

### After setting it, the corpus is still empty

A working `DATABASE_URL` gives you `rag_status: "empty"`, not `"ok"`. Re-ingest:

```bash
python scripts/embed_engine.py --ingest --remote   # posts content to /ingest
just linkedin-ingest Shares.csv commit             # voice corpus
just seatrace-sync milestones.json commit          # business_seatrace
just published-sync published.json commit          # feedback loop
```

`--remote` matters. Without it, `embed_engine.py` writes to a **local** store that
production does not read, and prints green checkmarks while the live corpus stays
empty. Local mode now labels its output `(LOCAL — not visible to production)`.

`/ingest` is guarded by `INGEST_SECRET` and dedupes on `ON CONFLICT (partition,
content_hash) DO NOTHING`, so re-running is safe and reports only genuinely new chunks.

### Do not reduce the embedding dimensions

`embedding` is `VECTOR(3072)`. pgvector caps **both** `ivfflat` and `hnsw` at 2000
dimensions, so no ANN index can exist on this column — retrieval is an exact
sequential scan, which is correct and fast at this corpus size. The temptation is to
"fix" the missing index by shrinking to 1536. **Don't.** Changing the embedding model
or width invalidates every stored vector, and retrieval degrades without erroring.
Past roughly 10k chunks, the documented path is `halfvec(3072)` + HNSW
(pgvector ≥ 0.7.0) — see the comment block in `scripts/schema/wsp001_knowledge.sql`.

### Known blocker (2026-09-13)

The previous Supabase project was deleted; its host is NXDOMAIN. `DATABASE_URL` is
unset and retrieval cannot return `rag_status: "ok"` until a new
Postgres + pgvector database exists and the corpus is re-ingested. Any provider works
— Supabase, Neon, Cloud SQL, or Netlify's managed Postgres — the only requirements are
pgvector support and TLS. `just blockers` prints the current list.

---

## 13. Walkthrough: bring the chatbot back online (2026-09-13 state)

The owner-side sequence, in order. Steps 1–3 cannot be done by an agent: they need the
Anthropic console and the Netlify dashboard. Every command below is safe to re-run.

**1. Rotate `ANTHROPIC_API_KEY`** — `/api/chat` currently returns **502**, meaning the
variable is set but its value is rejected upstream (503 would mean missing). Issue a
replacement at <https://console.anthropic.com/settings/keys>, revoke the old one, set
the new value per §3. Do not change the model string; `claude-opus-4-6` is valid and
locked by `CLAUDE.md`.

**2. Set `ABACUS_API_KEY`** (site level) — Abacus.AI console → *API Keys Dashboard* →
*Generate new API Key*. Read in edge functions as
`Netlify.env.get("ABACUS_API_KEY")` — **never `process.env`**, which is undefined in
Deno (§2). Optionally set `ABACUS_MODEL` (default `route-llm`).

**3. Redeploy with the cache cleared** — Dashboard → **Deploys → Trigger deploy →
Clear cache and deploy site**.

> This step is load-bearing and was skipped last time. The prior batch landed as
> `c05e7e8 "Applied patch via Netlify [skip ci]"`; `[skip ci]` meant **no build ran**,
> which is why `/api/abacus` returns the SPA 404 page despite existing in the repo.
> `/api/social-generate` is in the same state. Env changes never reach
> already-published edge functions, so a rotation without a redeploy changes nothing.

**4. Verify the keys**
```bash
just keys-verify     # expect HTTP 200; rag_status will still be honest about the DB
just abacus-test     # expect op=health ok, abacus_key_present true
```
Expect `rag_status: "not_configured"` or `"upstream_error"` here — that is correct
until step 5. A 200 from `/api/chat` proves the Anthropic key; it says nothing about
grounding.

**5. Stand up `DATABASE_URL` and re-ingest** — §12. This is the only remaining step
between "the chatbot answers" and "the chatbot answers from Scott's actual corpus".

**6. Prove grounding**
```bash
just keys-verify grounded=1   # exits non-zero unless rag_status == "ok"
```
This is the gate. Until it passes, the chatbot is generating from its embedded profile
pack rather than from retrieved knowledge — fluent, plausible, and not grounded.

---

## 11. Non-negotiables

- Never commit a key. `.env` and `credentials.json` are already gitignored.
- Never log a value — boolean presence checks only: `!!Netlify.env.get("KEY")`.
- Never move a key into `public/` or any client-side script; keys stay in edge functions.
- None of these keys are currently flagged **secret** in Netlify (`is_secret: false`), so
  values stay readable in the UI and CLI. Consider re-adding them as secrets.
- `/api/abacus` is a **side channel**. The CV chatbot at `/api/chat` stays on Claude
  Opus 4.6 for all tiers. Do not route the chatbot through Abacus.

<!-- FOR THE COMMONS GOOD — reusable pattern, candidate for shared WSP001 library -->
