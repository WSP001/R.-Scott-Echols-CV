# Blessed Env Schema

As of 2026-03-27, this is the current runtime contract for the `R.-Scott-Echols-CV` repo.

## Required

- `ANTHROPIC_API_KEY`
  Current chat runtime for `netlify/edge-functions/chat.ts`.
- `GEMINI_API_KEY`
  Current embedding runtime for `netlify/edge-functions/embed.ts` and local ingest flows.
- `BUSINESS_ACCESS_KEY`
  Business-tier gate for `/api/embed` and `/api/verify-access`.

## Optional

- `VECTOR_ENGINE_URL`
  Shared retriever endpoint for RAG. When unset, chat falls back to the verified profile pack.
- `DATABASE_URL`
  Durable PostgreSQL/pgvector backend for the Cloud Run retriever. When absent, the service falls back to local Chroma storage, which is not durable across Cloud Run revisions.
- `OPENAI_API_KEY`
  Legacy or experimental only. Not part of the CV repo's primary runtime contract.
- `ELEVENLABS_*`
  Voice-only integrations. Not used for retrieval.

## Not In Scope For This Repo

These belong to other repos or other runtime layers and should not be treated as blessed CV repo env vars unless explicitly added later:

- `VAULT_PATH`
- `STORAGE_BACKEND`

## Evidence

- `netlify/edge-functions/chat.ts`
- `netlify/edge-functions/embed.ts`
- `netlify.toml`
