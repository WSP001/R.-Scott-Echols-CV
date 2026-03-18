#!/usr/bin/env python3
"""
embed_engine.py — WSP001 RAG Ingest & Query Engine
FOR THE COMMONS GOOD — reusable across WSP001 repos

Uses:
  - ChromaDB (local persistent vector store)
  - Google Gemini Embedding 2 (gemini-embedding-2-preview, 3072 dims)
  - Partition-aware ingestion matching design.md data model

Usage:
  python scripts/embed_engine.py --ingest --partition cv_personal --source docs/
  python scripts/embed_engine.py --ingest --partition cv_projects --source docs/WSP_SeaTrace_Overview.md
  python scripts/embed_engine.py --query "SeaTrace Four Pillars"
  python scripts/embed_engine.py --query "SirTrav agents" --partition cv_projects --top-k 5
  python scripts/embed_engine.py --list-partitions
  python scripts/embed_engine.py --stats

Environment:
  GEMINI_API_KEY — required for embedding (get from Google AI Studio)

Dependencies:
  pip install chromadb google-generativeai
"""

import argparse
import os
import sys
import hashlib
import json
from pathlib import Path
from typing import Optional

# ── Allowed partitions (from design.md) ──────────────────────────────────────
PARTITIONS = {
    "cv_personal":          {"tier": "public",   "desc": "Resume history, skills, career timeline"},
    "cv_projects":          {"tier": "public",   "desc": "SirTrav, SeaTrace, WAFC, project details"},
    "business_seatrace":    {"tier": "business", "desc": "SeaTrace Four Pillars API docs, pricing"},
    "business_proposals":   {"tier": "business", "desc": "Client proposals, pricing, engagements"},
    "internal_repos":       {"tier": "business", "desc": "GitHub repo summaries, code architecture"},
    "recreational":         {"tier": "private",  "desc": "Personal interests, background stories"},
}

EMBED_MODEL = "models/embedding-001"  # Gemini Embedding — use text-embedding-004 or gemini-embedding-2-preview when available
EMBED_DIMS  = 3072  # Target for gemini-embedding-2-preview
CHUNK_SIZE  = 800   # Characters per chunk (tunable)
CHUNK_OVERLAP = 100

DB_PATH = os.path.join(os.path.dirname(__file__), "..", ".chromadb")
COLLECTION_NAME = "wsp001_knowledge"


def get_gemini_client():
    """Initialize Gemini client — fail fast if key not set."""
    api_key = os.environ.get("GEMINI_API_KEY")
    if not api_key:
        print("✗ GEMINI_API_KEY not set — run: export GEMINI_API_KEY=your_key_here")
        sys.exit(1)
    try:
        import google.generativeai as genai
        genai.configure(api_key=api_key)
        return genai
    except ImportError:
        print("✗ google-generativeai not installed — run: pip install google-generativeai")
        sys.exit(1)


def get_chroma_collection():
    """Initialize ChromaDB persistent collection."""
    try:
        import chromadb
    except ImportError:
        print("✗ chromadb not installed — run: pip install chromadb")
        sys.exit(1)
    
    client = chromadb.PersistentClient(path=DB_PATH)
    collection = client.get_or_create_collection(
        name=COLLECTION_NAME,
        metadata={"hnsw:space": "cosine"}
    )
    return collection


def embed_text(genai, text: str) -> list[float]:
    """Embed a single text chunk using Gemini."""
    result = genai.embed_content(
        model=EMBED_MODEL,
        content=text,
        task_type="retrieval_document"
    )
    return result["embedding"]


def chunk_text(text: str, chunk_size: int = CHUNK_SIZE, overlap: int = CHUNK_OVERLAP) -> list[str]:
    """Split text into overlapping chunks."""
    chunks = []
    start = 0
    while start < len(text):
        end = start + chunk_size
        chunk = text[start:end]
        if chunk.strip():
            chunks.append(chunk.strip())
        start = end - overlap
        if start >= len(text):
            break
    return chunks


def ingest_file(genai, collection, file_path: str, partition: str) -> int:
    """Ingest a single file into ChromaDB."""
    path = Path(file_path)
    if not path.exists():
        print(f"  ✗ File not found: {file_path}")
        return 0

    suffix = path.suffix.lower()
    if suffix not in [".md", ".txt", ".json"]:
        print(f"  → Skipping {path.name} (unsupported type: {suffix})")
        return 0

    text = path.read_text(encoding="utf-8")
    chunks = chunk_text(text)
    
    ingested = 0
    for i, chunk in enumerate(chunks):
        # Deterministic ID based on file content
        chunk_id = hashlib.sha256(f"{file_path}::{i}::{chunk[:50]}".encode()).hexdigest()[:16]
        doc_id = f"{partition}::{path.name}::{chunk_id}"
        
        # Check if already ingested
        existing = collection.get(ids=[doc_id])
        if existing["ids"]:
            print(f"  → Skipping chunk {i+1}/{len(chunks)} (already ingested)")
            continue
        
        embedding = embed_text(genai, chunk)
        
        collection.add(
            ids=[doc_id],
            embeddings=[embedding],
            documents=[chunk],
            metadatas=[{
                "partition": partition,
                "source": str(path.name),
                "source_path": str(file_path),
                "chunk_index": i,
                "tier": PARTITIONS[partition]["tier"],
            }]
        )
        ingested += 1
        print(f"  ✓ Chunk {i+1}/{len(chunks)} ingested (id: {doc_id[:12]}...)")
    
    return ingested


def cmd_ingest(args):
    """Ingest files into ChromaDB."""
    partition = args.partition
    source = args.source
    
    if partition not in PARTITIONS:
        print(f"✗ Unknown partition '{partition}'. Allowed: {list(PARTITIONS.keys())}")
        sys.exit(1)
    
    print(f"Ingesting into partition: {partition} ({PARTITIONS[partition]['tier']} tier)")
    
    genai = get_gemini_client()
    collection = get_chroma_collection()
    
    source_path = Path(source)
    total = 0
    
    if source_path.is_file():
        files = [source_path]
    elif source_path.is_dir():
        files = list(source_path.glob("**/*.md")) + list(source_path.glob("**/*.txt")) + list(source_path.glob("**/*.json"))
        print(f"Found {len(files)} files in {source_path}")
    else:
        print(f"✗ Source not found: {source}")
        sys.exit(1)
    
    for file_path in files:
        print(f"\nIngesting: {file_path.name}")
        count = ingest_file(genai, collection, str(file_path), partition)
        total += count
    
    print(f"\n✓ Ingested {total} chunks into '{partition}' partition")
    print(f"  DB path: {DB_PATH}")


def cmd_query(args):
    """Semantic search across the knowledge base."""
    query = args.query
    partition = args.partition  # optional filter
    top_k = args.top_k
    
    print(f"Querying: '{query}'")
    if partition:
        print(f"  Partition filter: {partition}")
    print(f"  Top-K: {top_k}\n")
    
    genai = get_gemini_client()
    collection = get_chroma_collection()
    
    # Embed the query
    query_embedding = genai.embed_content(
        model=EMBED_MODEL,
        content=query,
        task_type="retrieval_query"
    )["embedding"]
    
    where = {"partition": partition} if partition else None
    
    results = collection.query(
        query_embeddings=[query_embedding],
        n_results=top_k,
        where=where,
        include=["documents", "metadatas", "distances"]
    )
    
    if not results["ids"][0]:
        print("No results found. Run --ingest first.")
        return
    
    print(f"{'─'*60}")
    for i, (doc, meta, dist) in enumerate(zip(
        results["documents"][0],
        results["metadatas"][0],
        results["distances"][0]
    )):
        score = 1 - dist  # cosine similarity
        print(f"\nResult {i+1} (similarity: {score:.3f})")
        print(f"  Source: {meta['source']} | Partition: {meta['partition']} | Tier: {meta['tier']}")
        print(f"  Content: {doc[:300]}{'...' if len(doc) > 300 else ''}")
        print(f"{'─'*60}")


def cmd_list_partitions(args):
    """List all partitions and their descriptions."""
    print("Available Partitions:\n")
    for name, info in PARTITIONS.items():
        print(f"  {name}")
        print(f"    Tier: {info['tier']}")
        print(f"    Desc: {info['desc']}")
        print()


def cmd_stats(args):
    """Show collection statistics."""
    collection = get_chroma_collection()
    count = collection.count()
    print(f"ChromaDB Collection: {COLLECTION_NAME}")
    print(f"  Total chunks: {count}")
    print(f"  DB path: {DB_PATH}")
    
    if count > 0:
        # Sample metadata to show partition breakdown
        sample = collection.get(limit=1000, include=["metadatas"])
        partition_counts: dict = {}
        for meta in sample["metadatas"]:
            p = meta.get("partition", "unknown")
            partition_counts[p] = partition_counts.get(p, 0) + 1
        
        print("\nChunks by partition:")
        for p, c in sorted(partition_counts.items()):
            tier = PARTITIONS.get(p, {}).get("tier", "?")
            print(f"  {p} ({tier}): {c} chunks")


def main():
    parser = argparse.ArgumentParser(
        description="WSP001 RAG Embed Engine — ChromaDB + Gemini Embedding 2"
    )
    
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument("--ingest", action="store_true", help="Ingest documents into ChromaDB")
    group.add_argument("--query", type=str, metavar="QUERY", help="Semantic search query")
    group.add_argument("--list-partitions", action="store_true", help="List all partitions")
    group.add_argument("--stats", action="store_true", help="Show collection statistics")
    
    parser.add_argument("--partition", type=str, default="cv_projects", help="Knowledge partition")
    parser.add_argument("--source", type=str, default="docs/", help="Source file or directory")
    parser.add_argument("--top-k", type=int, default=3, help="Number of results to return")
    
    args = parser.parse_args()
    
    if args.ingest:
        cmd_ingest(args)
    elif args.query:
        cmd_query(args)
    elif args.list_partitions:
        cmd_list_partitions(args)
    elif args.stats:
        cmd_stats(args)


if __name__ == "__main__":
    main()
