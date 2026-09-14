#!/usr/bin/env python3
"""
api_server.py — WSP001 Vector Retrieval Service (Cloud Run)
FOR THE COMMONS GOOD — reusable across WSP001 repos

BACKEND: PostgreSQL + pgvector.

  ⚠️  DRIFT REPAIR (2026-09-13): this file previously used ChromaDB while the
  deployed `rse-retrieval` Cloud Run service had already moved to pgvector.
  The committed code and production disagreed, so nothing here could be
  trusted as a description of the live system. This version matches the
  deployed backend. Do not reintroduce ChromaDB — see docs/agent-contracts.md.

Architecture:
  Netlify /api/chat, /api/social-generate (Deno edge)
      ↓  POST /retrieve { query, partition, top_k, tier }
  Cloud Run api_server.py (FastAPI + pgvector)
      ↓  cosine distance search (operator <=>)
  PostgreSQL table wsp001_knowledge (3072-dim Gemini Embedding 2 vectors)
      ↓  top-K chunks
  back to the caller → injected into the Claude system prompt as RAG context

Endpoints (HTTP contract is UNCHANGED from the ChromaDB version — callers in
other lanes must keep working without edits):
  GET  /health         → liveness + backend + chunk count
  POST /retrieve       → semantic search, returns top-K chunks (array)
  POST /query          → SirScottA2A adapter, returns { context_chunks: [...] }
  POST /ingest         → ingest a text chunk (authenticated)
  GET  /partitions     → list available partitions and their tiers

Environment variables:
  DATABASE_URL         → required. PostgreSQL DSN with pgvector installed.
                         Must include sslmode=require for Neon/Supabase.
                         Never logged, never returned in a response body.
  GEMINI_API_KEY       → required for embedding queries
  INGEST_SECRET        → required for POST /ingest
  PORT                 → Cloud Run sets this automatically (default 8080)

Schema:
  scripts/schema/wsp001_knowledge.sql  (apply before first run)

Run locally:
  pip install -r scripts/requirements.txt
  export DATABASE_URL='postgresql://...?sslmode=require'
  export GEMINI_API_KEY=your_key
  uvicorn scripts.api_server:app --reload --port 8080

Deploy to Cloud Run:
  ./scripts/deploy-cloud-run.ps1        (from Windows)
  DATABASE_URL must be set as a Cloud Run secret, NOT a plain env var.
"""

import os
import re
import hashlib
from typing import Any, Optional

from fastapi import FastAPI, HTTPException, Header
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel

# ── Config ────────────────────────────────────────────────────────────────────
EMBED_MODEL   = "models/gemini-embedding-2-preview"  # matches embed_engine.py
EMBED_DIMS    = 3072
TABLE         = "wsp001_knowledge"
DATABASE_URL  = os.environ.get("DATABASE_URL", "")
INGEST_SECRET = os.environ.get("INGEST_SECRET", "")
PORT          = int(os.environ.get("PORT", 8080))

# Partition registry — MUST stay in sync with scripts/schema/wsp001_knowledge.sql
PARTITION_TIERS: dict[str, str] = {
    "cv_personal":        "public",
    "cv_projects":        "public",
    "linkedin_history":   "public",
    "social_published":   "public",
    "business_seatrace":  "business",
    "business_proposals": "business",
    "internal_repos":     "business",
    "recreational":       "private",
}
ALLOWED_PARTITIONS = set(PARTITION_TIERS)

# Tier boundary. A public request may NEVER see business or private content.
# This is enforced here, server-side, not in the caller. See CLAUDE.md.
PUBLIC_PARTITIONS = {p for p, t in PARTITION_TIERS.items() if t == "public"}

PARTITION_DESCRIPTIONS = {
    "cv_personal":        "Resume, skills, career timeline",
    "cv_projects":        "SirScottA2A, SeaTrace, WAFC details",
    "linkedin_history":   "Scott's own published LinkedIn posts — voice corpus",
    "social_published":   "Posts published by SirScottA2A + engagement metrics",
    "business_seatrace":  "SeaTrace API docs, Four Pillars, operational milestones",
    "business_proposals": "Client proposals, pricing",
    "internal_repos":     "GitHub repo summaries, architecture",
    "recreational":       "Personal interests, stories",
}


# ── Error sanitising ──────────────────────────────────────────────────────────
# Postgres driver exceptions can embed the whole connection string, password
# included. /health returns its error text to an unauthenticated caller, so
# every exception that reaches a response body goes through here first.
# AGENTS.md: "Never log env var values."
_DSN_RE = re.compile(r"\b\w+://[^\s'\"]+")
_KV_RE = re.compile(r"(password|pwd|sslpassword)\s*=\s*[^\s'\"]+", re.IGNORECASE)


def safe_error(exc: BaseException) -> str:
    """Exception class + message with anything DSN-shaped redacted."""
    msg = str(exc)
    msg = _DSN_RE.sub("<redacted-dsn>", msg)
    msg = _KV_RE.sub(r"\1=<redacted>", msg)
    if DATABASE_URL:
        msg = msg.replace(DATABASE_URL, "<redacted-dsn>")
    return f"{type(exc).__name__}: {msg[:300]}"


# ── FastAPI app ────────────────────────────────────────────────────────────────
app = FastAPI(
    title="WSP001 Vector Retrieval API",
    description="Semantic search over RSE/SeaTrace/SirScottA2A knowledge base (pgvector)",
    version="2.0.0",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "https://robertoscottecholscv.netlify.app",
        # Both names kept during the SirTrav → SirScottA2A rename transition.
        "https://sirtrav-a2a-studio.netlify.app",
        "https://sirscotta2a-studio.netlify.app",
        "https://packethander.netlify.app",
        "http://localhost:8888",
        "http://localhost:3000",
    ],
    allow_methods=["GET", "POST", "OPTIONS"],
    allow_headers=["Content-Type", "X-Ingest-Secret"],
)

# ── Lazy-loaded clients ───────────────────────────────────────────────────────
_genai = None
_pool = None


def get_genai():
    global _genai
    if _genai is None:
        api_key = os.environ.get("GEMINI_API_KEY")
        if not api_key:
            raise HTTPException(503, "GEMINI_API_KEY not configured")
        import google.generativeai as genai
        genai.configure(api_key=api_key)
        _genai = genai
    return _genai


def get_pool():
    """
    Connection pool, opened on first use. Cloud Run scales to zero, so
    min_size=0 keeps cold starts cheap and avoids holding idle Postgres
    connections open against a serverless database's connection cap.
    """
    global _pool
    if _pool is None:
        if not DATABASE_URL:
            raise HTTPException(
                503,
                "DATABASE_URL not configured — pgvector backend unavailable. "
                "Set it as a Cloud Run secret, then redeploy.",
            )
        from psycopg_pool import ConnectionPool
        _pool = ConnectionPool(
            DATABASE_URL,
            min_size=0,
            max_size=4,
            timeout=10.0,
            max_idle=60.0,
            open=True,
        )
    return _pool


def to_vector_literal(embedding: list[float]) -> str:
    """
    pgvector text input format: '[0.1,0.2,...]'.
    Formatted by hand and cast with ::vector so the service does not need the
    `pgvector` Python package or numpy — one less dependency in the image.
    """
    return "[" + ",".join(f"{float(x):.7g}" for x in embedding) + "]"


def embed_query(text: str) -> list[float]:
    genai = get_genai()
    try:
        result = genai.embed_content(
            model=EMBED_MODEL,
            content=text.strip(),
            task_type="retrieval_query",
        )
        embedding = result["embedding"]
    except Exception as e:
        raise HTTPException(502, f"Embedding failed: {safe_error(e)}")

    if len(embedding) != EMBED_DIMS:
        # A dimension mismatch means the embedding model changed. Every stored
        # vector is now incomparable — fail loudly instead of returning
        # nonsense similarity scores.
        raise HTTPException(
            502,
            f"Embedding dimension mismatch: got {len(embedding)}, expected {EMBED_DIMS}. "
            "The corpus must be re-ingested after an embedding model change.",
        )
    return embedding


# ── Request/Response models ───────────────────────────────────────────────────

class RetrieveRequest(BaseModel):
    query: str
    partition: Optional[str] = None   # None = all partitions allowed by tier
    top_k: int = 3
    tier: str = "public"              # "public" | "business"


class RetrieveResult(BaseModel):
    content: str
    score: float
    source: str
    partition: str


class IngestRequest(BaseModel):
    content: str
    partition: str
    source: str = "api"
    modality: str = "text"
    metadata: dict[str, Any] = {}


# ── Endpoints ─────────────────────────────────────────────────────────────────

@app.get("/health")
def health():
    """
    Liveness check — Cloud Run uses this for startup probes.

    Reports the real backend state. A reachable service with an unreachable
    database returns status "degraded", never "ok": a green health check on a
    dead corpus is how silent RAG failure goes unnoticed for weeks.
    """
    if not DATABASE_URL:
        return {
            "status": "degraded",
            "backend": "pgvector",
            "error": "DATABASE_URL not configured",
        }
    try:
        with get_pool().connection() as conn:
            with conn.cursor() as cur:
                cur.execute(f"SELECT count(*) FROM {TABLE}")
                count = cur.fetchone()[0]
                cur.execute(
                    f"SELECT partition, count(*) FROM {TABLE} GROUP BY partition ORDER BY partition"
                )
                by_partition = {row[0]: row[1] for row in cur.fetchall()}
        return {
            "status": "ok",
            "backend": "pgvector",
            "chunks": count,
            "by_partition": by_partition,
            "embed_model": EMBED_MODEL,
            "dimensions": EMBED_DIMS,
        }
    except Exception as e:
        return {
            "status": "degraded",
            "backend": "pgvector",
            "error": f"pgvector backend initialization failed: {safe_error(e)}",
        }


@app.get("/partitions")
def list_partitions():
    """List all partition names and their tiers."""
    return {
        "partitions": {
            name: {"tier": PARTITION_TIERS[name], "desc": PARTITION_DESCRIPTIONS[name]}
            for name in sorted(PARTITION_TIERS)
        }
    }


def resolve_partitions(tier: str, partition: Optional[str]) -> list[str]:
    """
    Resolve the partition allowlist for a request. Single source of truth for
    the tier boundary — /retrieve and /query both go through it.
    """
    if tier != "business":
        if partition and partition not in PUBLIC_PARTITIONS:
            raise HTTPException(
                403, f"Partition '{partition}' requires business tier access"
            )
        return [partition] if partition else sorted(PUBLIC_PARTITIONS)

    if partition:
        if partition not in ALLOWED_PARTITIONS:
            raise HTTPException(400, f"Unknown partition: {partition}")
        return [partition]
    # Business tier sees everything except the private partition.
    return sorted(p for p, t in PARTITION_TIERS.items() if t != "private")


def search(query: str, partitions: list[str], limit: int) -> list[RetrieveResult]:
    """Exact cosine nearest-neighbour search. See the schema file on indexing."""
    vector = to_vector_literal(embed_query(query))
    sql = f"""
        SELECT content, source, partition,
               1 - (embedding <=> %(q)s::vector) AS score
        FROM {TABLE}
        WHERE partition = ANY(%(parts)s)
        ORDER BY embedding <=> %(q)s::vector
        LIMIT %(k)s
    """
    try:
        with get_pool().connection() as conn:
            with conn.cursor() as cur:
                cur.execute(sql, {"q": vector, "parts": partitions, "k": limit})
                rows = cur.fetchall()
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(502, f"Vector search failed: {safe_error(e)}")

    return [
        RetrieveResult(
            content=row[0],
            source=row[1] or "unknown",
            partition=row[2] or "unknown",
            score=round(float(row[3]), 4),
        )
        for row in rows
    ]


@app.post("/retrieve", response_model=list[RetrieveResult])
def retrieve(req: RetrieveRequest):
    """
    Semantic search over the knowledge base.

    Tier-aware: public tier only searches the public partitions.
    Business tier can search all non-private partitions.

    Called by Netlify chat.ts and social-generate.ts when VECTOR_ENGINE_URL is set.
    Response shape is a bare JSON array — chat.ts parses it directly.
    """
    if not req.query or len(req.query.strip()) < 2:
        raise HTTPException(400, "Query must be at least 2 characters")

    partitions = resolve_partitions(req.tier, req.partition)
    results = search(req.query.strip(), partitions, min(max(req.top_k, 1), 10))
    results.sort(key=lambda r: r.score, reverse=True)
    return results


class QueryRequest(BaseModel):
    """SirScottA2A calling contract — matches content-seed.ts queryVectorEngine()."""
    query: str
    partitions: list[str] = ["cv_personal", "cv_projects"]
    n_results: int = 4
    tier: str = "public"


class QueryResponse(BaseModel):
    context_chunks: list[str]


@app.post("/query", response_model=QueryResponse)
def query(req: QueryRequest):
    """
    SirScottA2A adapter endpoint — called by content-seed.ts queryVectorEngine().

    Accepts { query, partitions[], n_results } — multi-partition fan-out.
    Returns { context_chunks: string[] } — plain text ready for prompt injection.

    Tier boundary applies here too: a public caller asking for a business
    partition gets it dropped from the allowlist, not honoured.
    """
    if not req.query or len(req.query.strip()) < 2:
        raise HTTPException(400, "Query must be at least 2 characters")

    allowed = ALLOWED_PARTITIONS if req.tier == "business" else PUBLIC_PARTITIONS
    safe_partitions = sorted({p for p in req.partitions if p in allowed})
    if not safe_partitions:
        return QueryResponse(context_chunks=[])

    n = min(max(req.n_results, 1), 20)
    results = search(req.query.strip(), safe_partitions, min(n * len(safe_partitions), 40))

    seen: set[str] = set()
    chunks: list[str] = []
    for r in sorted(results, key=lambda r: r.score, reverse=True):
        normalized = r.content.strip()
        if normalized and normalized not in seen:
            seen.add(normalized)
            chunks.append(normalized)
            if len(chunks) >= n:
                break

    print(f"[/query] Retrieved {len(chunks)} chunks from {safe_partitions}")
    return QueryResponse(context_chunks=chunks)


@app.post("/ingest")
def ingest(req: IngestRequest, x_ingest_secret: Optional[str] = Header(None)):
    """
    Ingest a text chunk into pgvector.
    Requires X-Ingest-Secret header matching INGEST_SECRET env var.

    Used by the GitHub Actions auto-ingest workflow, scripts/embed_engine.py,
    scripts/ingest-linkedin-posts.mjs and the sync-* scripts.

    Idempotent: deduplicated on (partition, content_hash) by a unique index, so
    re-running an ingest is safe and reports "skipped" rather than duplicating.
    """
    if not INGEST_SECRET:
        raise HTTPException(503, "INGEST_SECRET not configured — ingest disabled")
    if x_ingest_secret != INGEST_SECRET:
        raise HTTPException(401, "Invalid ingest secret")
    if req.partition not in ALLOWED_PARTITIONS:
        raise HTTPException(400, f"Unknown partition: {req.partition}")
    if not req.content or not req.content.strip():
        raise HTTPException(400, "Content is required")

    content = req.content.strip()
    content_hash = hashlib.sha256(content.encode()).hexdigest()
    chunk_id = hashlib.sha256(
        f"{req.partition}::{req.source}::{content[:80]}".encode()
    ).hexdigest()[:16]

    genai = get_genai()
    try:
        embedding = genai.embed_content(
            model=EMBED_MODEL,
            content=content,
            task_type="retrieval_document",
        )["embedding"]
    except Exception as e:
        raise HTTPException(502, f"Embedding failed: {safe_error(e)}")

    if len(embedding) != EMBED_DIMS:
        raise HTTPException(
            502,
            f"Embedding dimension mismatch: got {len(embedding)}, expected {EMBED_DIMS}",
        )

    import json as _json

    sql = f"""
        INSERT INTO {TABLE}
            (chunk_id, content, content_hash, partition, source, modality, tier, metadata, embedding)
        VALUES
            (%(chunk_id)s, %(content)s, %(hash)s, %(partition)s, %(source)s,
             %(modality)s, %(tier)s, %(metadata)s::jsonb, %(embedding)s::vector)
        ON CONFLICT (partition, content_hash) DO NOTHING
        RETURNING id
    """
    params = {
        "chunk_id": chunk_id,
        "content": content,
        "hash": content_hash,
        "partition": req.partition,
        "source": req.source,
        "modality": req.modality,
        "tier": PARTITION_TIERS[req.partition],
        "metadata": _json.dumps(req.metadata or {}),
        "embedding": to_vector_literal(embedding),
    }
    try:
        with get_pool().connection() as conn:
            with conn.cursor() as cur:
                cur.execute(sql, params)
                row = cur.fetchone()
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(502, f"Ingest failed: {safe_error(e)}")

    if row is None:
        return {"status": "skipped", "id": chunk_id, "reason": "already ingested"}
    return {"status": "ingested", "id": chunk_id, "partition": req.partition}


# ── Run locally ────────────────────────────────────────────────────────────────
if __name__ == "__main__":
    import uvicorn
    print(f"Starting WSP001 Retrieval API on port {PORT}")
    print(f"Backend: pgvector | table: {TABLE} | dims: {EMBED_DIMS}")
    print(f"DATABASE_URL configured: {bool(DATABASE_URL)}")  # presence only, never the value
    uvicorn.run("api_server:app", host="0.0.0.0", port=PORT, reload=True)
