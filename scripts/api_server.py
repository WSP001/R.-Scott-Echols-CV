#!/usr/bin/env python3
"""
api_server.py — WSP001 Vector Retrieval Service (Cloud Run)
FOR THE COMMONS GOOD — reusable across WSP001 repos

This is the production retrieval bridge between Netlify Edge Functions
and the knowledge base. It runs as a lightweight FastAPI server
on Google Cloud Run (scales to zero between requests).

Architecture:
  Netlify /api/chat (Deno edge)
      ↓  POST /retrieve { query, partition, top_k }
  Cloud Run api_server.py (FastAPI + vector store)
      ↓  cosine similarity search
  pgvector or ChromaDB (3072-dim Gemini Embedding 2 vectors)
      ↓  top-K chunks
  back to chat.ts → injected into Claude system prompt as RAG context

Endpoints:
  GET  /health         → liveness check
  POST /retrieve       → semantic search, returns top-K chunks
  POST /ingest         → ingest a text chunk into the active vector store (authenticated)
  GET  /partitions     → list available partitions

Environment variables:
  GEMINI_API_KEY       → required for embedding queries
  INGEST_SECRET        → required for POST /ingest (set in Cloud Run secrets)
  PORT                 → Cloud Run sets this automatically (default 8080)
  CHROMADB_PATH        → local path to ChromaDB data (default ./chromadb_data)
  DATABASE_URL         → optional durable PostgreSQL/pgvector backend
  VECTOR_STORE_BACKEND → auto | chroma | pgvector

Run locally:
  pip install fastapi uvicorn chromadb google-genai
  export GEMINI_API_KEY=your_key
  uvicorn scripts.api_server:app --reload --port 8080

Deploy to Cloud Run:
  docker build -t rse-retrieval -f scripts/Dockerfile .
  docker push gcr.io/YOUR_PROJECT/rse-retrieval
  gcloud run deploy rse-retrieval --image gcr.io/YOUR_PROJECT/rse-retrieval
  OR: just run scripts/deploy-cloud-run.ps1 from Windows
"""

import os
import hashlib
from typing import Optional
from fastapi import FastAPI, HTTPException, Header, Request
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from vector_store import create_vector_store

# ── Config ────────────────────────────────────────────────────────────────────
EMBED_MODEL   = "models/gemini-embedding-2-preview"  # 3072-dim, matches embed_engine.py
EMBED_DIMS    = 3072
CHUNK_SIZE    = 800
COLLECTION    = "wsp001_knowledge"
INGEST_SECRET = os.environ.get("INGEST_SECRET", "")
PORT          = int(os.environ.get("PORT", 8080))

ALLOWED_PARTITIONS = {
    "cv_personal", "cv_projects", "business_seatrace",
    "business_proposals", "internal_repos", "recreational"
}

# ── FastAPI app ────────────────────────────────────────────────────────────────
app = FastAPI(
    title="WSP001 Vector Retrieval API",
    description="Semantic search over RSE/SeaTrace/SirTrav knowledge base",
    version="1.0.0",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "https://robertoscottecholscv.netlify.app",
        "https://sirtrav-a2a-studio.netlify.app",
        "http://localhost:8888",
        "http://localhost:3000",
    ],
    allow_methods=["GET", "POST", "OPTIONS"],
    allow_headers=["Content-Type", "X-Ingest-Secret"],
)

# ── Lazy-loaded clients ───────────────────────────────────────────────────────
_genai = None
_genai_types = None
_store = None

def get_genai():
    global _genai, _genai_types
    if _genai is None:
        api_key = os.environ.get("GEMINI_API_KEY")
        if not api_key:
            raise HTTPException(503, "GEMINI_API_KEY not configured")
        from google import genai as _genai_module
        from google.genai import types
        _genai = _genai_module.Client(api_key=api_key)
        _genai_types = types
    return _genai

def get_store():
    global _store
    if _store is None:
        _store = create_vector_store()
    return _store

# ── Request/Response models ───────────────────────────────────────────────────

class RetrieveRequest(BaseModel):
    query: str
    partition: Optional[str] = None   # None = search all partitions
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

# ── Endpoints ─────────────────────────────────────────────────────────────────

@app.get("/health")
def health():
    """Liveness check — Cloud Run uses this for startup probes."""
    try:
        store = get_store()
        return store.health_payload()
    except Exception as e:
        return {"status": "degraded", "error": str(e)}


@app.get("/partitions")
def list_partitions():
    """List all partition names and their tiers."""
    partitions = {
        "cv_personal":         {"tier": "public",   "desc": "Resume, skills, career timeline"},
        "cv_projects":         {"tier": "public",   "desc": "SirTrav, SeaTrace, WAFC details"},
        "business_seatrace":   {"tier": "business", "desc": "SeaTrace API docs, Four Pillars"},
        "business_proposals":  {"tier": "business", "desc": "Client proposals, pricing"},
        "internal_repos":      {"tier": "business", "desc": "GitHub repo summaries, architecture"},
        "recreational":        {"tier": "private",  "desc": "Personal interests, stories"},
    }
    return {"partitions": partitions}


@app.post("/retrieve", response_model=list[RetrieveResult])
def retrieve(req: RetrieveRequest):
    """
    Semantic search over the knowledge base.
    
    Tier-aware: public tier only searches cv_personal + cv_projects.
    Business tier can search all partitions.
    
    Called by Netlify chat.ts when VECTOR_ENGINE_URL is configured.
    """
    if not req.query or len(req.query.strip()) < 2:
        raise HTTPException(400, "Query must be at least 2 characters")

    # Tier-based partition gating
    if req.tier == "public":
        allowed = {"cv_personal", "cv_projects"}
        if req.partition and req.partition not in allowed:
            raise HTTPException(403, f"Partition '{req.partition}' requires business tier access")
        search_partitions = [req.partition] if req.partition else list(allowed)
    else:
        # Business tier — respect explicit partition or search all
        if req.partition:
            if req.partition not in ALLOWED_PARTITIONS:
                raise HTTPException(400, f"Unknown partition: {req.partition}")
            search_partitions = [req.partition]
        else:
            search_partitions = None  # search everything

    genai = get_genai()
    store = get_store()

    # Embed the query
    try:
        result = genai.models.embed_content(
            model=EMBED_MODEL,
            contents=req.query.strip(),
            config=_genai_types.EmbedContentConfig(task_type="RETRIEVAL_QUERY")
        )
        query_embedding = list(result.embeddings[0].values)
    except Exception as e:
        raise HTTPException(502, f"Embedding failed: {str(e)}")

    # Search ChromaDB
    try:
        rows = store.similarity_search(
            query_embedding=query_embedding,
            n_results=min(req.top_k, 10),
            partitions=search_partitions,
        )
    except Exception as e:
        raise HTTPException(502, f"Vector search failed: {str(e)}")

    if not rows:
        return []

    output = []
    for row in rows:
        doc = row["document"]
        meta = row["metadata"]
        score = round(float(row["score"]), 4)
        output.append(RetrieveResult(
            content=doc,
            score=score,
            source=meta.get("source", "unknown"),
            partition=meta.get("partition", "unknown"),
        ))

    # Sort by score descending
    output.sort(key=lambda x: x.score, reverse=True)
    return output


class QueryRequest(BaseModel):
    """SirTrav calling contract — matches content-seed.ts queryVectorEngine()."""
    query: str
    partitions: list[str] = ["cv_personal", "cv_projects"]
    n_results: int = 4

class QueryResponse(BaseModel):
    context_chunks: list[str]

@app.post("/query", response_model=QueryResponse)
def query(req: QueryRequest):
    """
    SirTrav adapter endpoint — called by content-seed.ts queryVectorEngine().

    Accepts { query, partitions[], n_results } — multi-partition fan-out.
    Returns { context_chunks: string[] } — plain text ready for prompt injection.

    Deduplicates across partitions, sorts by score, returns top n_results.
    """
    if not req.query or len(req.query.strip()) < 2:
        raise HTTPException(400, "Query must be at least 2 characters")

    safe_partitions = [p for p in req.partitions if p in ALLOWED_PARTITIONS]
    if not safe_partitions:
        return QueryResponse(context_chunks=[])

    genai = get_genai()
    store = get_store()

    try:
        embedding_result = genai.models.embed_content(
            model=EMBED_MODEL,
            contents=req.query.strip(),
            config=_genai_types.EmbedContentConfig(task_type="RETRIEVAL_QUERY")
        )
        query_embedding = list(embedding_result.embeddings[0].values)
    except Exception as e:
        raise HTTPException(502, f"Embedding failed: {str(e)}")

    try:
        rows = store.similarity_search(
            query_embedding=query_embedding,
            n_results=min(req.n_results * len(safe_partitions), 20),
            partitions=safe_partitions,
        )
    except Exception as e:
        raise HTTPException(502, f"Vector search failed: {str(e)}")

    if not rows:
        return QueryResponse(context_chunks=[])

    # Build scored list, deduplicate by content, return top n_results as plain strings
    scored = sorted(
        ((row["document"], row["distance"]) for row in rows),
        key=lambda x: x[1]
    )
    seen: set[str] = set()
    chunks: list[str] = []
    for doc, _ in scored:
        normalized = doc.strip()
        if normalized and normalized not in seen:
            seen.add(normalized)
            chunks.append(normalized)
            if len(chunks) >= req.n_results:
                break

    console_count = len(chunks)
    print(f"[/query] Retrieved {console_count} chunks from {safe_partitions}")
    return QueryResponse(context_chunks=chunks)


@app.post("/ingest")
def ingest(req: IngestRequest, x_ingest_secret: Optional[str] = Header(None)):
    """
    Ingest a text chunk into ChromaDB.
    Requires X-Ingest-Secret header matching INGEST_SECRET env var.
    
    Used by the GitHub Actions workflow and local embed_engine.py.
    """
    if not INGEST_SECRET:
        raise HTTPException(503, "INGEST_SECRET not configured — ingest disabled")
    if x_ingest_secret != INGEST_SECRET:
        raise HTTPException(401, "Invalid ingest secret")
    if req.partition not in ALLOWED_PARTITIONS:
        raise HTTPException(400, f"Unknown partition: {req.partition}")

    genai = get_genai()
    store = get_store()

    # Deterministic ID
    chunk_id = hashlib.sha256(
        f"{req.partition}::{req.source}::{req.content[:80]}".encode()
    ).hexdigest()[:16]

    if store.has_id(chunk_id):
        return {"status": "skipped", "id": chunk_id, "reason": "already ingested"}

    embedding = list(genai.models.embed_content(
        model=EMBED_MODEL,
        contents=req.content,
        config=_genai_types.EmbedContentConfig(task_type="RETRIEVAL_DOCUMENT")
    ).embeddings[0].values)

    metadata = {
        "partition": req.partition,
        "source": req.source,
        "modality": req.modality,
        "tier": "public" if req.partition in {"cv_personal", "cv_projects"} else "business",
    }
    store.add_document(
        doc_id=chunk_id,
        embedding=embedding,
        document=req.content,
        metadata=metadata,
    )

    return {"status": "ingested", "id": chunk_id, "partition": req.partition}


# ── Run locally ────────────────────────────────────────────────────────────────
if __name__ == "__main__":
    import uvicorn
    print(f"Starting WSP001 Retrieval API on port {PORT}")
    print(f"Vector store backend: {get_store().backend_name}")
    uvicorn.run("api_server:app", host="0.0.0.0", port=PORT, reload=True)
