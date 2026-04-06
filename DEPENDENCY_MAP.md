# DEPENDENCY_MAP.md — R. Scott Echols CV Repo Service Dependencies

**Version:** 1.0.0
**Last Updated:** 2026-04-06
**Signed by:** Windsurf/Cascade (Acting Master, WSP001)

> Machine-readable service dependency map for the CV repo.
> Shows what depends on what, which env vars each service needs,
> and what happens when a dependency is missing.

---

## Dependency Graph

```text
User Browser
    |
    v
Netlify CDN (robertoscottecholscv.netlify.app)
    |
    +---> public/index.html (static — Three.js, GSAP, chat UI)
    |
    +---> /api/chat (edge function: chat.ts)
    |         |
    |         +--- ANTHROPIC_API_KEY .................. [SECRET, REQUIRED]
    |         +--- VECTOR_ENGINE_URL .................. [CONFIG, OPTIONAL]
    |         |         |
    |         |         v
    |         |    Cloud Run (rse-retrieval / FastAPI)
    |         |         |
    |         |         +--- GEMINI_API_KEY ........... [SECRET, REQUIRED]
    |         |         +--- DATABASE_URL ............. [SECRET, REQUIRED, ?sslmode=require]
    |         |         +--- INGEST_SECRET ............ [SECRET, REQUIRED for /ingest]
    |         |         |
    |         |         v
    |         |    Supabase pgvector (wsp001_knowledge table)
    |         |         |
    |         |         +--- 124 chunks (durable, survives restarts)
    |         |         +--- cosine similarity search (3072-dim)
    |         |
    |         v
    |    Claude Opus 4.6 (Anthropic API)
    |         +--- RAG context injected into system prompt
    |         +--- Returns grounded answer
    |
    +---> /api/embed (edge function: embed.ts)
    |         +--- GEMINI_API_KEY .................... [SECRET, REQUIRED]
    |         +--- BUSINESS_ACCESS_KEY ............... [SECRET, REQUIRED — gates access]
    |
    +---> /api/verify-access (edge function: verify-access.ts)
              +--- BUSINESS_ACCESS_KEY ............... [SECRET, REQUIRED]
```

---

## Service Dependency Table

| Service | Depends On | Env Vars Needed | Fallback When Missing |
|---------|-----------|-----------------|----------------------|
| **Netlify frontend** | CDN, DNS | (none — static files) | N/A — always available |
| **chat.ts** | `ANTHROPIC_API_KEY` | `ANTHROPIC_API_KEY` | Returns 503 |
| **chat.ts (RAG path)** | `VECTOR_ENGINE_URL`, Cloud Run | `VECTOR_ENGINE_URL` | Falls back to embedded CV system prompt |
| **embed.ts** | `GEMINI_API_KEY`, `BUSINESS_ACCESS_KEY` | Both required | Returns 503 / 401 |
| **verify-access.ts** | `BUSINESS_ACCESS_KEY` | `BUSINESS_ACCESS_KEY` | Rejects all business requests |
| **Cloud Run api_server.py** | `GEMINI_API_KEY`, `DATABASE_URL` | Both required | `/health` returns "degraded" |
| **Cloud Run /ingest** | `INGEST_SECRET`, `GEMINI_API_KEY`, `DATABASE_URL` | All three | Returns 503 / 401 |
| **Supabase pgvector** | `DATABASE_URL` with `?sslmode=require` | `DATABASE_URL` | Cloud Run cannot store/retrieve vectors |
| **Local ChromaDB** | `chromadb` pip package | (none — local filesystem) | Not production — dev/test only |
| **embed_engine.py (local)** | `GEMINI_API_KEY`, `chromadb` | `GEMINI_API_KEY` | Exits with error |
| **embed_engine.py (remote)** | `VECTOR_ENGINE_URL`, `INGEST_SECRET` | Both required | Falls back to local ChromaDB mode |

---

## Critical Path (Production)

```text
ANTHROPIC_API_KEY → chat.ts → Claude Opus 4.6 → answer
                                    ^
                                    |
VECTOR_ENGINE_URL → Cloud Run → pgvector → RAG context (optional, enriches answer)
                        ^
                        |
               GEMINI_API_KEY + DATABASE_URL
```

**Minimum viable production:** `ANTHROPIC_API_KEY` + `BUSINESS_ACCESS_KEY` in Netlify.
**Full RAG production:** Above + `VECTOR_ENGINE_URL` pointing to healthy Cloud Run.

---

## Local Dev Dependencies

| Tool | Purpose | Install |
|------|---------|---------|
| Python 3.13+ | `embed_engine.py`, `api_server.py` | System install |
| `chromadb` | Local vector store | `pip install chromadb` |
| `google-genai` | Gemini embedding client | `pip install google-genai` |
| `pypdf` | PDF extraction for ingest | `pip install pypdf` (optional) |
| `fastapi` + `uvicorn` | Local API server | `pip install fastapi uvicorn` |
| `psycopg[binary]` | pgvector connection | `pip install "psycopg[binary]"` |
| `just` | Trusted CLI surface | `cargo install just` or `winget install just` |
| `deno` | Edge function type-checking | Optional — runs at Netlify deploy |
| `gcloud` CLI | Cloud Run deploy/manage | `gcloud auth login` required |

---

## Non-Blocking / Optional Dependencies

| Dependency | Status | Impact If Missing |
|-----------|--------|-------------------|
| Remotion / AWS | PARKED | Zero impact on CV pipeline |
| ElevenLabs | NOT_WIRED | No voice features — not blocking |
| OpenAI API | RESERVED | Not used by any CV runtime code |
| Headless browser | FUTURE | No automated UI verification yet |

---

## Ingest Pipeline Dependencies

```text
data/rse_cv_manifest.json (source list)
    |
    v
knowledge_base/public/cv/*.md + *.docx  (source files)
    |
    v
embed_engine.py --from-manifest
    |
    +--- Local mode: GEMINI_API_KEY → chromadb (local .chromadb/)
    |
    +--- Remote mode: VECTOR_ENGINE_URL + INGEST_SECRET → Cloud Run /ingest → pgvector
```

---

## Cross-Repo Dependencies (CV → Studio bridge)

```text
CV Repo (this repo)
    |
    +--- knowledge_base/public/cv/  ← truth source
    |
    v
Studio Repo (WSP001/SirTrav-A2A-Studio)
    |
    +--- scripts/seed-producer-brief.mjs
    |         |
    |         +--- VECTOR_ENGINE_URL (same Cloud Run instance)
    |         v
    +--- artifacts/producer-brief.json
```

**Rule:** Only `knowledge_base/public/cv/` feeds the Studio producer brief.
`knowledge_base/business/` is NEVER included in any public-facing Studio output.

---

*For the Commons Good* 🎬
