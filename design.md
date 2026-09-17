# RSE Knowledge Architecture — design.md

## Overview
This document defines the vector knowledge base architecture powering the RSE-Assistant chatbot
on robertoscottecholscv.netlify.app

## Two-Tier Access Model

### Public Tier (Free — 3 questions)
- Answers questions about Scott's CV, background, skills, projects
- Knowledge source: embedded system prompt in chat.ts
- No vector DB required for basic CV questions
- After 3 questions: prompts visitor to request invitation key

### Business Tier (Invitation Key Required)
- Full access to Scott's knowledge base
- Routes to Claude Opus 4.6 with expanded context
- Accesses vector KB via /api/embed endpoint
- Business key set as BUSINESS_ACCESS_KEY in Netlify env vars

## Vector Knowledge Base Architecture

### Embedding Model
- Model: gemini-embedding-2-preview
- Dimensions: 3072
- Input modalities: text, image, audio, PDF, video (unified vector space)
- Endpoint: POST /api/embed (business tier only, requires X-Access-Key header)

### Data Partitions

| Partition | Content | Access |
|-----------|---------|--------|
| `cv_personal` | Resume history, skills, career timeline, education | Public (3 free Q) |
| `cv_projects` | SirTrav, SeaTrace, WAFC, other project details | Public (3 free Q) |
| `business_seatrace` | SeaTrace Four Pillars API docs, endpoints, pricing | Business tier |
| `business_proposals` | Client proposals, pricing, engagement models | Business tier |
| `internal_repos` | GitHub repo summaries, code architecture | Business tier |
| `recreational` | Personal interests, background stories | Invitation only |

### Recommended Vector Database Options
1. **Supabase pgvector** (recommended for Netlify) — Postgres + pgvector extension, free tier available, native Netlify extension
2. **Weaviate Cloud** — managed, multimodal-native, generous free tier
3. **BigQuery Vector Search** — Google Cloud native, pairs perfectly with Gemini Embedding 2, SQL-based

### BigQuery Schema (when using Google Cloud)
```sql
CREATE TABLE `your_project.rse_knowledge.cv_vectors` (
  id STRING,
  partition STRING,  -- 'cv_personal', 'cv_projects', 'business_seatrace', etc.
  content TEXT,      -- original text chunk
  source STRING,     -- file path or URL origin
  embedding ARRAY<FLOAT64>,  -- 3072-dim vector from gemini-embedding-2-preview
  access_tier STRING,  -- 'public' or 'business'
  created_at TIMESTAMP
);
```

### RAG Query Flow
1. User sends question to /api/chat
2. chat.ts checks tier (public/business) and questionCount
3. For business tier: question is embedded via Gemini Embedding 2
4. Vector search finds top-3 closest knowledge chunks
5. Top 2 chunks above the score floor injected as an uncached system block after the cached static prompt
6. Claude generates answer grounded in Scott's actual data

### Ingestion Script
See: scripts/ingest-kb.py
Run: `python scripts/ingest-kb.py --partition cv_personal --source ./docs/cv/`

## External vs Internal Content

### External (Free / Public)
- General CV facts, career history, skills, public project descriptions
- SeaTrace public API documentation
- Contact information

### Internal (Business / Monetized)
- Detailed project specs and code architecture
- Client proposals and pricing
- SeaTrace enterprise integration details
- SirTrav-A2A-Studio internal architecture
- GitHub repository access patterns

## SeaTrace Public → Business Packet Switch

Public proof published by `WSP001/MARKETING-SeaTrace-MSC-v007` (the `#CATCH` / `#HARVEST`
scenario fixtures in `data/fixtures/*.public.json`) is the only SeaTrace data allowed to cross
into this repo's knowledge base. It lands in the `business_seatrace` partition, so the public
chatbot tier never sees it and the business tier sees a plain-language projection of the public
rail — never `$CHECK` / `$BOOK` private records.

```
MSC-v007 data/fixtures/*.public.json        (public rail, scenario-safe)
    ↓ scripts/ingest-seatrace-public-packet.mjs
    ↓   boundary gate: PRIVATE_FIELD_NAMES + BLOCKED_PUBLIC_PATTERNS (mirrors MSC-v007 gate)
    ↓   any hit → exit 2, nothing pushed (fail closed, no silent scrubbing)
Cloud Run POST /ingest  { content, partition: "business_seatrace", source: "seatrace-msc-v007/public/<fixture>#<pillar>" }
    ↓ server-side Gemini Embedding 2 (no client model call → $0 model cost)
pgvector → /retrieve (business tier only) → /api/chat RAG block
```

Run: `node scripts/ingest-seatrace-public-packet.mjs --fixtures ../MARKETING-SeaTrace-MSC-v007/data/fixtures --dry-run`
Push requires `VECTOR_ENGINE_URL` + `INGEST_SECRET`; missing either exits 3 (never a fake success).
`source` carries the fixture and pillar so every grounded answer is traceable back to the exact
public artefact. Private repos (SeaTrace002/003, ODOO) are **not** inputs to this script.

## Cost Tiers (2026-09)

| Workload | Model / provider | Rule |
|---|---|---|
| `/api/chat` (all tiers) | **Claude Opus 4.6** with prompt caching | Model lock. Static prefix cached (`cache_control: ephemeral`), RAG tail uncached, capped at 2 chunks × 1 500 chars. Cache outcome is reported per response as `prompt_cache` — `miss` means the optimisation is not engaging and must be investigated, not assumed. |
| Ingestion (`/ingest`, packet scripts) | Gemini Embedding 2 server-side, no LLM | Embedding lock. Zero generation cost. |
| Social generation / narration (future `/api/social-generate`) | Abacus.AI RouteLLM — additive side channel | Never `/api/chat`. Deferred until G2 (production `/retrieve`) is green per `plans/HANDOFF_OPERATOR_2026-09-08.md`; needs `ABACUS_API_KEY` as a secret env var and a `listProjects` smoke test first. |
| Local prompt iteration | LM Studio (OpenAI-compatible, localhost) | Dev only; cannot serve Netlify Edge. |
| AskYourPDF | **Not adopted for retrieval.** | Its public API (`/v1/api/upload`, `/v1/api/download_pdf`, `/v1/api/chat/{doc_id}`) returns answers generated by *its* model (`AIModelType` enum: GPT/Gemini/Claude 1–2) — a raw chunk-retrieval endpoint that would let Opus 4.6 do generation was not found in its docs. Using it would break the model lock and give a second, unobservable retrieval path. Revisit only if a retrieval-only endpoint is confirmed. |

## How Embeddings Get Smarter Over Time
Each time a business-tier user asks a question and Scott provides a good answer,
that Q&A pair can be added back to the vector KB as a new knowledge chunk.
This creates a flywheel: more usage → richer KB → better answers → more value.

The /api/embed endpoint accepts multimodal inputs — when Scott uploads a PDF resume,
project screenshots, or voice notes, they all map to the same 3072-dim space and
become searchable by the chatbot.
