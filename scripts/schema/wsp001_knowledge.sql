-- wsp001_knowledge.sql — PostgreSQL + pgvector schema for the WSP001 corpus
-- FOR THE COMMONS GOOD — reusable pattern, candidate for shared WSP001 library
--
-- Target: the database behind Cloud Run `rse-retrieval` (DATABASE_URL).
-- Apply with:  psql "$DATABASE_URL" -f scripts/schema/wsp001_knowledge.sql
-- Idempotent: safe to re-run.
--
-- Embedding contract (must match scripts/embed_engine.py and api_server.py):
--   model      gemini-embedding-2-preview
--   dimensions 3072
--   distance   cosine  (operator <=>)

CREATE EXTENSION IF NOT EXISTS vector;

CREATE TABLE IF NOT EXISTS wsp001_knowledge (
    id            BIGSERIAL PRIMARY KEY,
    chunk_id      TEXT        NOT NULL,
    content       TEXT        NOT NULL,
    content_hash  TEXT        NOT NULL,
    partition     TEXT        NOT NULL,
    source        TEXT        NOT NULL DEFAULT 'api',
    modality      TEXT        NOT NULL DEFAULT 'text',
    tier          TEXT        NOT NULL DEFAULT 'business',
    metadata      JSONB       NOT NULL DEFAULT '{}'::jsonb,
    embedding     VECTOR(3072) NOT NULL,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Deduplication: the same text in the same partition is ingested once.
-- scripts/api_server.py POST /ingest relies on this for ON CONFLICT DO NOTHING.
CREATE UNIQUE INDEX IF NOT EXISTS wsp001_knowledge_dedupe
    ON wsp001_knowledge (partition, content_hash);

CREATE INDEX IF NOT EXISTS wsp001_knowledge_partition
    ON wsp001_knowledge (partition);

CREATE INDEX IF NOT EXISTS wsp001_knowledge_tier
    ON wsp001_knowledge (tier);

-- ── Why there is no ANN index on `embedding` ─────────────────────────────────
-- pgvector's ivfflat and hnsw indexes both cap the `vector` type at 2000
-- dimensions. Our vectors are 3072-dim, so NEITHER index can be built on this
-- column — attempting it fails with:
--   ERROR: column cannot have more than 2000 dimensions for hnsw index
--
-- At the current corpus size (~10^2 chunks) an exact sequential scan is the
-- correct answer anyway: it is fast, and it returns true nearest neighbours
-- rather than approximate ones. Do not "fix" this by reducing dimensions —
-- that would silently invalidate every stored vector.
--
-- UPGRADE PATH (only needed past ~10k chunks, requires pgvector >= 0.7.0):
-- halfvec supports HNSW up to 4000 dimensions. Build an expression index and
-- change the ORDER BY in api_server.py to match it exactly, or the planner
-- will ignore the index:
--
--   CREATE INDEX wsp001_knowledge_embedding_hnsw
--       ON wsp001_knowledge
--       USING hnsw ((embedding::halfvec(3072)) halfvec_cosine_ops);
--
--   -- and in api_server.py:
--   ORDER BY embedding::halfvec(3072) <=> %(q)s::halfvec(3072)
--
-- Half-precision costs a small amount of recall. Measure before adopting.

-- ── Partition registry ───────────────────────────────────────────────────────
-- Kept in SQL so the tier boundary is auditable outside the application code.
-- MUST stay in sync with ALLOWED_PARTITIONS / PUBLIC_PARTITIONS in
-- scripts/api_server.py. scripts/truth_audit.py gates this.
CREATE TABLE IF NOT EXISTS wsp001_partitions (
    partition   TEXT PRIMARY KEY,
    tier        TEXT NOT NULL,
    description TEXT NOT NULL
);

INSERT INTO wsp001_partitions (partition, tier, description) VALUES
    ('cv_personal',        'public',   'Resume, skills, career timeline'),
    ('cv_projects',        'public',   'SirScottA2A, SeaTrace, WAFC details'),
    ('linkedin_history',   'public',   'Scott''s own published LinkedIn posts — voice corpus'),
    ('social_published',   'public',   'Posts published by SirScottA2A + engagement metrics'),
    ('business_seatrace',  'business', 'SeaTrace API docs, Four Pillars, operational milestones'),
    ('business_proposals', 'business', 'Client proposals, pricing'),
    ('internal_repos',     'business', 'GitHub repo summaries, architecture'),
    ('recreational',       'private',  'Personal interests, stories')
ON CONFLICT (partition) DO UPDATE
    SET tier = EXCLUDED.tier, description = EXCLUDED.description;
