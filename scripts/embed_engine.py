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
import re
import sys
import hashlib
import json
import zipfile
from datetime import datetime, timezone
import xml.etree.ElementTree as ET
from pathlib import Path

# ── Allowed partitions (from design.md) ──────────────────────────────
PARTITIONS = {
    "cv_personal": {
        "tier": "public",
        "desc": "Resume history, skills, career timeline"
    },
    "cv_projects": {
        "tier": "public",
        "desc": "SirTrav, SeaTrace, WAFC, project details"
    },
    "business_seatrace": {
        "tier": "business",
        "desc": "SeaTrace Four Pillars API docs, pricing"
    },
    "business_proposals": {
        "tier": "business",
        "desc": "Client proposals, pricing, engagements"
    },
    "internal_repos": {
        "tier": "business",
        "desc": "GitHub repo summaries, code architecture"
    },
    "recreational": {
        "tier": "private",
        "desc": "Personal interests, background stories"
    },
}

# Gemini Embedding
EMBED_MODEL = os.environ.get(
    "GEMINI_EMBED_MODEL",
    "models/gemini-embedding-2-preview"
)
EMBED_FALLBACK_MODEL = os.environ.get(
    "GEMINI_EMBED_FALLBACK_MODEL",
    "models/embedding-001"
)
EMBED_DIMS = 3072
CHUNK_SIZE = 800   # Characters per chunk (tunable)
CHUNK_OVERLAP = 100

REPO_ROOT = Path(__file__).resolve().parents[1]
REPO_NAME = REPO_ROOT.name
DB_PATH = os.path.join(os.path.dirname(__file__), "..", ".chromadb")
COLLECTION_NAME = "wsp001_knowledge"


class EmbedEngineError(RuntimeError):
    """Raised when the embed/query pipeline should fail without a traceback."""


def get_gemini_client():
    """Initialize Gemini client — fail fast if key not set."""
    api_key = os.environ.get("GEMINI_API_KEY")
    if not api_key:
        print(
            "✗ GEMINI_API_KEY not set — "
            "run: export GEMINI_API_KEY=your_key_here"
        )
        sys.exit(1)
    try:
        import google.generativeai as genai
        genai.configure(api_key=api_key)
        return genai
    except ImportError:
        print(
            "✗ google-generativeai not installed — "
            "run: pip install google-generativeai"
        )
        sys.exit(1)


def get_chroma_collection():
    """Initialize ChromaDB persistent collection."""
    try:
        import chromadb
    except ImportError:
        print("✗ chromadb not installed — run: pip install chromadb")
        sys.exit(1)

    client = chromadb.PersistentClient(path=DB_PATH)
    return client.get_or_create_collection(
        name=COLLECTION_NAME,
        metadata={"hnsw:space": "cosine"}
    )


def describe_embedding_error(exc: Exception) -> str:
    """Return an operator-friendly error message for embedding failures."""
    text = str(exc)
    if "API_KEY_INVALID" in text or "API Key not found" in text:
        return (
            "GEMINI_API_KEY is present but rejected by the Google "
            "Generative Language API. Move a valid Gemini key into this "
            "environment before running ingest or search."
        )
    return f"Embedding request failed: {text}"


def ensure_ingest_prereqs(file_paths: list[Path]) -> None:
    """Fail early when local ingest prerequisites are missing."""
    if any(path.suffix.lower() == ".pdf" for path in file_paths):
        try:
            import pypdf  # noqa: F401
        except ImportError as exc:
            raise EmbedEngineError(
                "pypdf not installed — run: python -m pip install pypdf"
            ) from exc


def run_embedding_preflight(genai) -> None:
    """Validate the active Gemini key before iterating the corpus."""
    embed_with_fallback(genai, "preflight check", "retrieval_document")


def embed_with_fallback(genai, content: str, task_type: str) -> list[float]:
    """Embed using the configured model, with a safe fallback for local tooling."""
    try:
        result = genai.embed_content(
            model=EMBED_MODEL,
            content=content,
            task_type=task_type
        )
        return result["embedding"]
    except Exception as exc:
        if EMBED_MODEL == EMBED_FALLBACK_MODEL:
            raise EmbedEngineError(describe_embedding_error(exc)) from exc
        print(
            f"  ! Warning: {EMBED_MODEL} failed ({exc}). "
            f"Falling back to {EMBED_FALLBACK_MODEL}."
        )
        try:
            result = genai.embed_content(
                model=EMBED_FALLBACK_MODEL,
                content=content,
                task_type=task_type
            )
            return result["embedding"]
        except Exception as fallback_exc:
            raise EmbedEngineError(
                describe_embedding_error(fallback_exc)
            ) from fallback_exc


def embed_text(genai, text: str) -> list[float]:
    """Embed a single text chunk using Gemini."""
    return embed_with_fallback(genai, text, "retrieval_document")


def chunk_text(
    text: str,
    chunk_size: int = CHUNK_SIZE,
    overlap: int = CHUNK_OVERLAP
) -> list[str]:
    """Split text into overlapping character chunks (fixed strategy)."""
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


def chunk_by_sections(text: str, min_chars: int = 80) -> list[str]:
    """Split text on markdown headers for section-based chunking.
    Falls back to chunk_text() if no headers found.
    """
    parts = re.split(r"(?m)^(#{1,3} )", text)
    chunks, current = [], ""
    for part in parts:
        if re.match(r"^#{1,3} $", part):
            if current.strip() and len(current.strip()) >= min_chars:
                chunks.append(current.strip())
            current = part
        else:
            current += part
    if current.strip() and len(current.strip()) >= min_chars:
        chunks.append(current.strip())
    return chunks or chunk_text(text)


def extract_text_from_docx(path: Path) -> str:
    """Extract plain text from DOCX using stdlib only."""
    ns = "{http://schemas.openxmlformats.org/wordprocessingml/2006/main}"
    try:
        with zipfile.ZipFile(path) as z:
            with z.open("word/document.xml") as f:
                tree = ET.parse(f)
        paragraphs = []
        for para in tree.iter(f"{ns}p"):
            texts = [
                node.text for node in para.iter(f"{ns}t") if node.text
            ]
            if texts:
                paragraphs.append("".join(texts))
        return "\n\n".join(paragraphs)
    except Exception as e:
        print(f"  ✗ DOCX extract failed: {e}")
        return ""


def extract_text_from_pdf(path: Path) -> str:
    """Extract plain text from PDF using pypdf."""
    try:
        from pypdf import PdfReader
    except ImportError:
        print("  ✗ pypdf not installed — run: pip install pypdf")
        return ""
    try:
        reader = PdfReader(str(path))
        pages = [page.extract_text() or "" for page in reader.pages]
        return "\n\n".join(p for p in pages if p.strip())
    except Exception as e:
        print(f"  ✗ PDF extract failed: {e}")
        return ""


def infer_modality(path: Path) -> str:
    """Map file suffix to a metadata modality."""
    suffix = path.suffix.lower()
    if suffix in {".md", ".txt", ".json"}:
        return "text"
    if suffix == ".docx":
        return "docx"
    if suffix == ".pdf":
        return "pdf"
    return "unknown"


def ingest_file(
    genai,
    collection,
    file_path: str,
    partition: str,
    chunk_strategy: str = "fixed"
) -> int:
    """Ingest a single file into ChromaDB.
    Supports .md .txt .json .docx .pdf
    """
    path = Path(file_path)
    if not path.exists():
        print(f"  ✗ File not found: {file_path}")
        return 0

    suffix = path.suffix.lower()
    supported = [".md", ".txt", ".json", ".docx", ".pdf"]
    if suffix not in supported:
        print(f"  → Skipping {path.name} (unsupported type: {suffix})")
        return 0

    if suffix == ".docx":
        text = extract_text_from_docx(path)
    elif suffix == ".pdf":
        text = extract_text_from_pdf(path)
    else:
        text = path.read_text(encoding="utf-8")

    if not text.strip():
        print(f"  ✗ No text extracted from {path.name}")
        return 0

    if chunk_strategy == "section":
        chunks = chunk_by_sections(text)
        print(f"  → Section chunking: {len(chunks)} sections")
    else:
        chunks = chunk_text(text)
    
    ingested = 0
    for i, chunk in enumerate(chunks):
        # Deterministic ID based on file content
        chunk_hash = hashlib.sha256(
            f"{file_path}::{i}::{chunk[:50]}".encode()
        ).hexdigest()[:16]
        doc_id = f"{partition}::{path.name}::{chunk_hash}"

        # Check if already ingested
        existing = collection.get(ids=[doc_id])
        if existing["ids"]:
            print(f"  → Skipping chunk {i+1}/{len(chunks)} (already ingested)")
            continue

        embedding = embed_text(genai, chunk)

        try:
            relative_path = path.resolve().relative_to(REPO_ROOT.resolve())
        except ValueError:
            relative_path = path

        collection.add(
            ids=[doc_id],
            embeddings=[embedding],
            documents=[chunk],
            metadatas=[{
                "partition": partition,
                "repo": REPO_NAME,
                "source": str(path.name),
                "path": str(relative_path).replace("\\", "/"),
                "source_path": str(file_path),
                "modality": infer_modality(path),
                "chunk_index": i,
                "tier": PARTITIONS[partition]["tier"],
                "indexed_at": datetime.now(timezone.utc).isoformat(),
            }]
        )
        ingested += 1
        print(f"  ✓ Chunk {i+1}/{len(chunks)} ingested (id: {doc_id[:12]}...)")

    return ingested


MANIFEST_PATH = os.path.join(
    os.path.dirname(__file__), "..", "data", "rse_cv_manifest.json"
)
KB_ROOT = os.path.join(os.path.dirname(__file__), "..", "knowledge_base")


def cmd_ingest_manifest(args):  # noqa: ARG001
    """Ingest all active sources listed in data/rse_cv_manifest.json."""
    manifest_path = Path(MANIFEST_PATH)
    if not manifest_path.exists():
        print(f"✗ Manifest not found: {manifest_path}")
        sys.exit(1)

    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    sources = [
        s for s in manifest.get("sources", [])
        if s.get("status") == "active"
    ]
    manifest_ver = manifest.get('version', '?')
    print(f"Manifest v{manifest_ver} — {len(sources)} active sources\n")

    resolved_sources = []

    for src in sources:
        tier = src.get("access_tier", "public")
        chunk_strategy = src.get("chunk_strategy", "section")
        source_file = src.get("source_path", "")
        title = src.get("title", source_file)
        partition = (
            "cv_personal" if tier == "public" else "business_seatrace"
        )

        # Search: knowledge_base/{tier}/cv/ first, then docs/
        candidates = [
            Path(KB_ROOT) / tier / "cv" / source_file,
            Path(os.path.dirname(__file__), "..", "docs") / source_file,
        ]
        file_path = next((p for p in candidates if p.exists()), None)

        if not file_path:
            print(f"✗ [{src['id']}] '{source_file}' not found — skipping")
            continue

        resolved_sources.append(
            (src, file_path, partition, chunk_strategy, title)
        )

    try:
        ensure_ingest_prereqs([item[1] for item in resolved_sources])
        genai = get_gemini_client()
        run_embedding_preflight(genai)
    except EmbedEngineError as exc:
        print(f"ERROR: {exc}")
        sys.exit(1)

    collection = get_chroma_collection()
    total = 0

    for src, file_path, partition, chunk_strategy, title in resolved_sources:
        print(f"\n[{src['id']}] {title}")
        file_info = (
            f"  File: {file_path.name}  |  Partition: {partition}  |  "
            f"Strategy: {chunk_strategy}"
        )
        print(file_info)
        count = ingest_file(
            genai, collection, str(file_path), partition, chunk_strategy
        )
        total += count

    complete_msg = (
        f"\n✓ Manifest ingest complete — {total} new chunks added to "
        f"'{COLLECTION_NAME}'"
    )
    print(complete_msg)
    print(f"  DB path: {DB_PATH}")


def cmd_ingest(args):
    """Ingest files into ChromaDB."""
    partition = args.partition
    source = args.source
    
    if partition not in PARTITIONS:
        allowed = list(PARTITIONS.keys())
        print(f"✗ Unknown partition '{partition}'. Allowed: {allowed}")
        sys.exit(1)
    
    partition_info = PARTITIONS[partition]
    tier_info = partition_info['tier']
    print(f"Ingesting into partition:  {partition} ({tier_info} tier)")

    source_path = Path(source)
    total = 0

    if source_path.is_file():
        files = [source_path]
    elif source_path.is_dir():
        md_files = list(source_path.glob("**/*.md"))
        txt_files = list(source_path.glob("**/*.txt"))
        json_files = list(source_path.glob("**/*.json"))
        docx_files = list(source_path.glob("**/*.docx"))
        pdf_files = list(source_path.glob("**/*.pdf"))
        files = md_files + txt_files + json_files + docx_files + pdf_files
        print(f"Found {len(files)} files in {source_path}")
    else:
        print(f"✗ Source not found: {source}")
        sys.exit(1)

    try:
        ensure_ingest_prereqs(files)
        genai = get_gemini_client()
        run_embedding_preflight(genai)
    except EmbedEngineError as exc:
        print(f"ERROR: {exc}")
        sys.exit(1)

    collection = get_chroma_collection()
    
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
    query_embedding = embed_with_fallback(
        genai,
        query,
        "retrieval_query"
    )
    
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
        source_line = (
            f"  Source: {meta['source']} | Repo: {meta.get('repo', '?')} "
            f"| Path: {meta.get('path', meta.get('source_path', '?'))}"
        )
        print(source_line)
        print(
            f"  Partition: {meta['partition']} | Tier: {meta['tier']} "
            f"| Modality: {meta.get('modality', 'text')}"
        )
        print(f"  Content: {doc[:300]}{'...' if len(doc) > 300 else ''}")
        print(f"{'─'*60}")


def cmd_list_partitions(args):  # noqa: ARG001
    """List all partitions and their descriptions."""
    print("Available Partitions:\n")
    for name, info in PARTITIONS.items():
        print(f"  {name}")
        print(f"    Tier: {info['tier']}")
        print(f"    Desc: {info['desc']}")
        print()


def cmd_stats(args):  # noqa: ARG001
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
    group.add_argument(
        "--ingest",
        action="store_true",
        help="Ingest documents into ChromaDB"
    )
    group.add_argument(
        "--from-manifest",
        action="store_true",
        help="Ingest all active sources from data/rse_cv_manifest.json"
    )
    group.add_argument(
        "--query",
        type=str,
        metavar="QUERY",
        help="Semantic search query"
    )
    group.add_argument(
        "--list-partitions",
        action="store_true",
        help="List all partitions"
    )
    group.add_argument(
        "--stats",
        action="store_true",
        help="Show collection statistics"
    )

    parser.add_argument(
        "--partition",
        type=str,
        default="cv_projects",
        help="Knowledge partition"
    )
    parser.add_argument(
        "--source",
        type=str,
        default="docs/",
        help="Source file or directory"
    )
    parser.add_argument(
        "--top-k",
        type=int,
        default=3,
        help="Number of results to return"
    )

    args = parser.parse_args()
    
    try:
        if args.from_manifest:
            cmd_ingest_manifest(args)
        elif args.ingest:
            cmd_ingest(args)
        elif args.query:
            cmd_query(args)
        elif args.list_partitions:
            cmd_list_partitions(args)
        elif args.stats:
            cmd_stats(args)
    except EmbedEngineError as exc:
        print(f"ERROR: {exc}")
        sys.exit(1)


if __name__ == "__main__":
    main()
