# R. Scott Echols — CV RAG Stack + Offline-Safe Bridge

[![Netlify Status](https://api.netlify.com/api/v1/badges/your-site-id/deploy-status)](https://robertoscottecholscv.netlify.app)
![Python 3.11+](https://img.shields.io/badge/python-3.11+-blue.svg)
![pgvector](https://img.shields.io/badge/vector--store-pgvector%2FSupabase-3ECF8E.svg)
![Gemini Embedding 2](https://img.shields.io/badge/embeddings-Gemini%20Embedding%202-4285F4.svg)
![License](https://img.shields.io/badge/license-proprietary-lightgrey.svg)

**A manifest-driven pgvector RAG system for a public-facing CV and knowledge experience.**

Canonical knowledge lives in Git-managed source folders and manifests. Supabase pgvector provides durable indexed retrieval (121 chunks, `SirStudio-to-CV` project). The API server exposes stable query endpoints. A public-safe fallback snapshot keeps the frontend usable when the live vector stack is unavailable.

> **Production vector store is Supabase pgvector — NOT ChromaDB.**
> ChromaDB code remains in the repo as a local dev/offline fallback only.

> **FOR THE COMMONS GOOD** — R. Scott Echols / WorldSeafoodProducers.com

**Live site:** [robertoscottecholscv.netlify.app](https://robertoscottecholscv.netlify.app)
**Retrieval API:** Cloud Run (rse-retrieval)

---

## Getting Started in 5 Minutes

### Prerequisites

- Python 3.11+
- A [Google AI Studio](https://aistudio.google.com) API key (`GEMINI_API_KEY`)
- Git

### 1. Clone and configure

```bash
git clone https://github.com/WSP001/R.-Scott-Echols-CV.git
cd R.-Scott-Echols-CV
cp infra/.env.example .env
# Edit .env — add your GEMINI_API_KEY
```

### 2. Install dependencies

```bash
pip install psycopg[binary] google-genai fastapi uvicorn
# For local dev/offline fallback only: pip install chromadb
```

### 3. Validate your manifest

```bash
python scripts/validate_manifest.py
```

### 4. Ingest knowledge into pgvector (production)

```bash
# Requires VECTOR_ENGINE_URL and INGEST_SECRET set in environment
VECTOR_ENGINE_URL="https://rse-retrieval-zrmkhygpwa-uc.a.run.app" \
INGEST_SECRET="<secret>" \
python scripts/embed_engine.py --from-manifest
```

### 5. Query it

```bash
python scripts/embed_engine.py --query "What are the Four Pillars of SeaTrace?"
```

That's it. You now have a working RAG pipeline.

---

## Architecture

```
Source Docs (Git)                    ← Canonical truth
    │
    ▼
Manifest (rse_cv_manifest.json)
    │
    ▼
Embed Engine (Gemini Embedding 2, 3072 dims, partition-aware)
    │
    ▼
Cloud Run api_server.py (FastAPI)    ← rse-retrieval-zrmkhygpwa-uc.a.run.app
    │
    ▼
Supabase pgvector                    ← PRODUCTION: durable, 121 chunks, SirStudio-to-CV
    (ChromaDB local path available as dev/offline fallback only)
    │
    ▼
Netlify Edge Function /api/chat      ← RAG context injected into Claude Opus 4.6 prompt
    │
    ▼
Browser (robertoscottecholscv.netlify.app)
    │
    ▼
fallback_snapshot.json               ← Offline safety net (no vector store needed)
```

### Live Architecture Truth

| Layer | Tool | Role |
|-------|------|------|
| **Vector store (production)** | Supabase pgvector | 121 chunks, durable, partition-aware |
| **Vector store (dev/fallback)** | ChromaDB (local) | Offline dev only — NOT used in production |
| **Embedding model** | Gemini Embedding 2 (3072 dims) | All ingestion and query embedding |
| **Retrieval bridge** | Cloud Run FastAPI | Converts query → embedding → pgvector search |
| **Chat AI** | Claude Opus 4.6 | Non-negotiable. RAG context injected as system prompt |
| **Canonical Truth** | Git | Source docs, manifests, version control |

---

## Three Operating Modes

### 1. Live Mode (production)

```
Browser → Netlify Edge /api/chat → Cloud Run /retrieve → Supabase pgvector
```

The production path. Netlify edge function calls Cloud Run, which queries pgvector on Supabase and returns sourced RAG chunks injected into Claude Opus 4.6.

**Requires:** `VECTOR_ENGINE_URL` (Netlify env), `DATABASE_URL` + `GEMINI_API_KEY` (Cloud Run secrets via GCP Secret Manager).

### 2. Local Mode (dev fallback)

```
Frontend → Local API → Local ChromaDB (./chromadb_data/)
```

For laptop development and offline testing. ChromaDB auto-selected when `DATABASE_URL` is not set.

```bash
python scripts/api_server.py  # Starts local FastAPI server on port 8080
```

**Requires:** Local `.env` with `GEMINI_API_KEY`, ingested Chroma data (`python scripts/embed_engine.py --from-manifest` with no `DATABASE_URL` set).

### 3. Fallback Mode

```
Frontend → fallback_snapshot.json (static)
```

No network, no API, no vector store. The frontend loads a pre-exported public-safe JSON snapshot and performs simple text matching.

```bash
python scripts/export_fallback_snapshot.py  # Generate snapshot
```

**Requires:** Nothing at runtime. Just the JSON file.

---

## Repository Layout

```
R.-Scott-Echols-CV/
├── index.html                              # Full CV site (single-file, production-ready)
├── netlify.toml                            # Edge Functions routing, security headers, CORS
├── data/
│   └── rse_cv_manifest.json                # Source manifest v2.1 (15 sources, 6 partitions)
├── knowledge_base/
│   ├── public/cv/                          # Public-tier source docs (.md, .pdf, .docx)
│   ├── business/seatrace/                  # Business-tier (SeaTrace architecture)
│   └── docs/                               # Chatbot knowledge briefs
├── public/
│   └── fallback_snapshot.json              # Offline-safe snapshot (auto-generated)
├── scripts/
│   ├── embed_engine.py                     # RAG ingest engine (Gemini Embedding 2)
│   ├── api_server.py                       # FastAPI retrieval server
│   ├── validate_manifest.py                # Manifest validation gate
│   ├── export_fallback_snapshot.py         # Offline snapshot exporter
│   ├── truth_audit.py                      # Source coverage audit
│   └── vector_store.py                     # Vector store utilities
├── netlify/edge-functions/
│   ├── chat.ts                             # /api/chat — AI assistant (public + business tiers)
│   ├── embed.ts                            # /api/embed — Gemini Embedding 2 endpoint
│   └── verify-access.ts                    # /api/verify-access — Business tier validation
├── docs/
│   └── COMMONS_SNAPSHOT_2026-03-31.md      # State of the union memorial
├── scripts/Dockerfile                      # Container for retrieval API
└── plans/                                  # Agent handoff tickets
```

---

## Manifest System

The manifest (`data/rse_cv_manifest.json`) is the single registry of all knowledge sources.

```json
{
  "version": "2.1",
  "sources": [
    {
      "id": "cv_projects_001",
      "title": "SeaTrace Four Pillars — Public Summary",
      "source_path": "seatrace_four_pillars_summary.md",
      "normalized_markdown": "knowledge_base/public/cv/seatrace_four_pillars_summary.md",
      "access_tier": "public",
      "partition": "cv_projects",
      "topics": ["SeaTrace", "Four Pillars", "fisheries traceability"],
      "chunk_strategy": "heading",
      "priority": 1,
      "status": "active"
    }
  ]
}
```

### Validation

```bash
python scripts/validate_manifest.py          # Standard check
python scripts/validate_manifest.py --strict  # Treat warnings as errors
```

Checks: required fields, duplicate IDs, file resolution, partition validity, orphan detection.

---

## ChromaDB Strategy

### Collections (6 partitions)

| Collection | Tier | Content |
|------------|------|---------|
| `cv_personal` | public | Resume, skills, career timeline |
| `cv_projects` | public | SirTrav, SeaTrace, WAFC project details |
| `business_seatrace` | business | Four Pillars API docs, pricing |
| `business_proposals` | business | Client proposals, engagements |
| `internal_repos` | business | GitHub repo summaries, architecture |
| `recreational` | private | Personal interests, background |

### Metadata Contract

Every chunk carries structured metadata for filtering:

```json
{
  "project": "seatrace",
  "module": "dockside",
  "visibility": "public",
  "doc_type": "card",
  "status": "approved",
  "source_ref": "knowledge_base/public/cv/seatrace_four_pillars_summary.md",
  "version": "2026-03-31"
}
```

This enables the retrieval layer to enforce `visibility == public` and `status == approved` — turning semantic search into a **controlled knowledge system**.

---

## AI Chatbot: Two-Tier Access

| Tier | Access | Capabilities |
|------|--------|-------------|
| **Public** | Anyone | CV questions, background, projects, SeaTrace Four Pillars |
| **Business** | Access key required | Full knowledge base, technical blueprints, enterprise details |

The chatbot defaults to Public mode with RAG-powered answers from the CV corpus. Business mode unlocks the full knowledge base with extended context.

---

## Environment Variables

### Netlify (production)

Set in **Netlify → Site Settings → Environment Variables**:

| Variable | Description |
|----------|-------------|
| `ANTHROPIC_API_KEY` | Claude API key (chatbot) |
| `GEMINI_API_KEY` | Google AI Studio key (embeddings + vision) |
| `BUSINESS_ACCESS_KEY` | Passphrase for business tier |

### Local development (`.env`)

```env
GEMINI_API_KEY=your_google_key_here
VECTOR_ENGINE_URL=http://localhost:8080
CHROMA_PATH=./chroma/local-data
INGEST_SECRET=your_ingest_secret
```

### Supabase

| Variable | Description |
|----------|-------------|
| `SUPABASE_URL` | Auto-provided by Supabase Edge Functions |
| `SUPABASE_ANON_KEY` | Auto-provided (public read) |
| `SUPABASE_SERVICE_ROLE_KEY` | Admin writes only — never expose in frontend |

---

## Scripts Reference

| Script | Purpose | Usage |
|--------|---------|-------|
| `validate_manifest.py` | Gate check before ingest | `python scripts/validate_manifest.py` |
| `embed_engine.py` | Ingest manifest into ChromaDB | `python scripts/embed_engine.py --from-manifest` |
| `export_fallback_snapshot.py` | Generate offline snapshot | `python scripts/export_fallback_snapshot.py` |
| `api_server.py` | Local retrieval API server | `python scripts/api_server.py` |
| `truth_audit.py` | Audit source coverage | `python scripts/truth_audit.py` |

### Common commands

```bash
# Query the knowledge base
python scripts/embed_engine.py --query "What is SeaTrace?" --partition cv_projects

# List all partitions and their stats
python scripts/embed_engine.py --list-partitions
python scripts/embed_engine.py --stats

# Ingest to remote Cloud Run
VECTOR_ENGINE_URL="https://your-cloud-run-url" \
INGEST_SECRET="your_secret" \
python scripts/embed_engine.py --from-manifest
```

---

## Readiness Gates

The system is not production-ready until all gates pass:

| Gate | Check | Command |
|------|-------|---------|
| **Manifest** | All source refs resolve, no duplicates | `python scripts/validate_manifest.py` |
| **Ingest** | Chunk counts match, deterministic IDs | `python scripts/embed_engine.py --stats` |
| **Retrieval** | Sample queries return expected docs | `python scripts/embed_engine.py --query "Four Pillars"` |
| **Fallback** | Snapshot builds, frontend loads it | `python scripts/export_fallback_snapshot.py` |
| **Live API** | Health endpoint passes | `curl https://your-api/health` |
| **RLS** | Supabase policies active | Check Supabase dashboard |

---

## Checkpoint Workflow

Before shutdown, handoff, or major changes:

```bash
python scripts/validate_manifest.py
python scripts/embed_engine.py --from-manifest
python scripts/export_fallback_snapshot.py
git add .
git commit -m "Checkpoint: validated ingest + fallback snapshot"
git tag last-known-good-$(date +%Y-%m-%d)
```

---

## Deploy

### Netlify (frontend + edge functions)

1. Push to GitHub
2. Connect repo in [Netlify](https://app.netlify.com)
3. Build command: `echo 'Static site — no build step'`
4. Publish directory: `.`
5. Add environment variables
6. Deploy

### Cloud Run (retrieval API)

```bash
cd scripts
docker build -t rse-retrieval -f Dockerfile .
gcloud run deploy rse-retrieval --image rse-retrieval --allow-unauthenticated
```

---

## Related Projects

| Project | Purpose | Status |
|---------|---------|--------|
| [SirTrav-A2A-Studio](https://github.com/WSP001/SirTrav-A2A-Studio) | D2A video production pipeline (7-agent) | M9 active |
| SeaTrace | Fisheries traceability platform (Four Pillars) | Architecture phase |
| WorldSeafoodProducers.com | Parent organization | Live |

---

## Current State (March 31, 2026)

See [`docs/COMMONS_SNAPSHOT_2026-03-31.md`](docs/COMMONS_SNAPSHOT_2026-03-31.md) for the full state of the union.

| Component | Status |
|-----------|--------|
| CV chatbot | **Live** — RAG answers from ChromaDB corpus |
| Manifest | v2.1, 15 sources, 14 public |
| ChromaDB | 6 collections, Cloud Run deployed |
| Supabase RLS | Applied — public read, admin write |
| Fallback snapshot | Generated — 14 items, 15.1 KB |
| Validator | Built — found 5 missing .md files to convert |

---

**FOR THE COMMONS GOOD** — R. Scott Echols / WSP001

*Architecture: Scott Echols | Engineering: Claude (Anthropic)*
