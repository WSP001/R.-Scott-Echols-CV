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
5. Chunks injected into Claude system prompt as context
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

## How Embeddings Get Smarter Over Time
Each time a business-tier user asks a question and Scott provides a good answer,
that Q&A pair can be added back to the vector KB as a new knowledge chunk.
This creates a flywheel: more usage → richer KB → better answers → more value.

The /api/embed endpoint accepts multimodal inputs — when Scott uploads a PDF resume,
project screenshots, or voice notes, they all map to the same 3072-dim space and
become searchable by the chatbot.
