#!/usr/bin/env python3
"""
vector_store.py - backend adapter for retrieval storage.

Supports:
  - ChromaDB local persistence (legacy fallback)
  - PostgreSQL + pgvector (durable production path)
"""

from __future__ import annotations

import json
import os
from typing import Any


COLLECTION_NAME = "wsp001_knowledge"
DB_PATH = os.environ.get("CHROMADB_PATH", "./chromadb_data")
DATABASE_URL = os.environ.get("DATABASE_URL", "")
VECTOR_STORE_BACKEND = os.environ.get("VECTOR_STORE_BACKEND", "auto").lower()
PGVECTOR_TABLE = os.environ.get("PGVECTOR_TABLE", COLLECTION_NAME)


def vector_literal(values: list[float]) -> str:
    """Return a pgvector literal like [0.1,0.2,...]."""
    return "[" + ",".join(f"{value:.12g}" for value in values) + "]"


class BaseVectorStore:
    backend_name = "unknown"
    durable = False

    def health_payload(self) -> dict[str, Any]:
        raise NotImplementedError

    def count(self) -> int:
        raise NotImplementedError

    def has_id(self, doc_id: str) -> bool:
        raise NotImplementedError

    def add_document(
        self,
        *,
        doc_id: str,
        embedding: list[float],
        document: str,
        metadata: dict[str, Any],
    ) -> None:
        raise NotImplementedError

    def similarity_search(
        self,
        *,
        query_embedding: list[float],
        n_results: int,
        partitions: list[str] | None = None,
    ) -> list[dict[str, Any]]:
        raise NotImplementedError


class ChromaVectorStore(BaseVectorStore):
    backend_name = "chroma"
    durable = False

    def __init__(self, db_path: str = DB_PATH, collection_name: str = COLLECTION_NAME):
        try:
            import chromadb
        except ImportError as exc:
            raise RuntimeError("chromadb not installed") from exc

        client = chromadb.PersistentClient(path=db_path)
        self.collection = client.get_or_create_collection(
            name=collection_name,
            metadata={"hnsw:space": "cosine"},
        )
        self.db_path = db_path

    def health_payload(self) -> dict[str, Any]:
        return {
            "status": "ok",
            "chunks": self.count(),
            "db_path": self.db_path,
            "backend": self.backend_name,
            "durable": self.durable,
        }

    def count(self) -> int:
        return self.collection.count()

    def has_id(self, doc_id: str) -> bool:
        existing = self.collection.get(ids=[doc_id])
        return bool(existing["ids"])

    def add_document(
        self,
        *,
        doc_id: str,
        embedding: list[float],
        document: str,
        metadata: dict[str, Any],
    ) -> None:
        self.collection.add(
            ids=[doc_id],
            embeddings=[embedding],
            documents=[document],
            metadatas=[metadata],
        )

    def similarity_search(
        self,
        *,
        query_embedding: list[float],
        n_results: int,
        partitions: list[str] | None = None,
    ) -> list[dict[str, Any]]:
        kwargs: dict[str, Any] = {
            "query_embeddings": [query_embedding],
            "n_results": n_results,
            "include": ["documents", "metadatas", "distances"],
        }
        if partitions:
            kwargs["where"] = {"partition": {"$in": partitions}}

        results = self.collection.query(**kwargs)
        if not results["ids"][0]:
            return []

        rows: list[dict[str, Any]] = []
        for document, metadata, distance in zip(
            results["documents"][0],
            results["metadatas"][0],
            results["distances"][0],
        ):
            rows.append(
                {
                    "document": document,
                    "metadata": metadata,
                    "distance": float(distance),
                    "score": 1.0 - float(distance),
                }
            )
        return rows


class PgVectorStore(BaseVectorStore):
    backend_name = "pgvector"
    durable = True

    def __init__(self, database_url: str = DATABASE_URL, table_name: str = PGVECTOR_TABLE):
        if not database_url:
            raise RuntimeError("DATABASE_URL not configured")
        try:
            import psycopg
        except ImportError as exc:
            raise RuntimeError("psycopg not installed") from exc

        self.psycopg = psycopg
        self.database_url = database_url
        self.table_name = table_name
        self._schema_ready = False

    def _connect(self):
        return self.psycopg.connect(self.database_url)

    def _ensure_schema(self) -> None:
        if self._schema_ready:
            return

        try:
            with self._connect() as conn:
                with conn.cursor() as cur:
                    cur.execute("CREATE EXTENSION IF NOT EXISTS vector")
                    cur.execute(
                        f"""
                        CREATE TABLE IF NOT EXISTS {self.table_name} (
                            id TEXT PRIMARY KEY,
                            partition TEXT NOT NULL,
                            source TEXT NOT NULL,
                            modality TEXT NOT NULL DEFAULT 'text',
                            tier TEXT NOT NULL,
                            content TEXT NOT NULL,
                            embedding vector(3072) NOT NULL,
                            metadata JSONB NOT NULL DEFAULT '{{}}'::jsonb,
                            indexed_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
                        )
                        """
                    )
                    cur.execute(
                        f"""
                        CREATE INDEX IF NOT EXISTS idx_{self.table_name}_partition
                        ON {self.table_name} (partition)
                        """
                    )
                conn.commit()
        except Exception as exc:
            raise RuntimeError(
                "pgvector backend initialization failed. Ensure DATABASE_URL "
                "is reachable and the vector extension is enabled."
            ) from exc

        self._schema_ready = True

    def health_payload(self) -> dict[str, Any]:
        return {
            "status": "ok",
            "chunks": self.count(),
            "db_path": "pgvector",
            "backend": self.backend_name,
            "durable": self.durable,
            "table": self.table_name,
        }

    def count(self) -> int:
        self._ensure_schema()
        with self._connect() as conn:
            with conn.cursor() as cur:
                cur.execute(f"SELECT COUNT(*) FROM {self.table_name}")
                row = cur.fetchone()
        return int(row[0] if row else 0)

    def has_id(self, doc_id: str) -> bool:
        self._ensure_schema()
        with self._connect() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    f"SELECT 1 FROM {self.table_name} WHERE id = %s LIMIT 1",
                    (doc_id,),
                )
                row = cur.fetchone()
        return row is not None

    def add_document(
        self,
        *,
        doc_id: str,
        embedding: list[float],
        document: str,
        metadata: dict[str, Any],
    ) -> None:
        self._ensure_schema()
        vector_value = vector_literal(embedding)
        with self._connect() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    f"""
                    INSERT INTO {self.table_name}
                    (id, partition, source, modality, tier, content, embedding, metadata, indexed_at)
                    VALUES (%s, %s, %s, %s, %s, %s, %s::vector, %s::jsonb, NOW())
                    ON CONFLICT (id) DO NOTHING
                    """,
                    (
                        doc_id,
                        metadata.get("partition", "unknown"),
                        metadata.get("source", "unknown"),
                        metadata.get("modality", "text"),
                        metadata.get("tier", "public"),
                        document,
                        vector_value,
                        json.dumps(metadata),
                    ),
                )
            conn.commit()

    def similarity_search(
        self,
        *,
        query_embedding: list[float],
        n_results: int,
        partitions: list[str] | None = None,
    ) -> list[dict[str, Any]]:
        self._ensure_schema()
        vector_value = vector_literal(query_embedding)
        params: list[Any] = [vector_value]
        where_sql = ""
        if partitions:
            where_sql = "WHERE partition = ANY(%s)"
            params.append(partitions)
        params.extend([vector_value, n_results])

        with self._connect() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    f"""
                    SELECT content, metadata, (embedding <=> %s::vector) AS distance
                    FROM {self.table_name}
                    {where_sql}
                    ORDER BY embedding <=> %s::vector
                    LIMIT %s
                    """,
                    params,
                )
                rows = cur.fetchall()

        output: list[dict[str, Any]] = []
        for content, metadata, distance in rows:
            output.append(
                {
                    "document": content,
                    "metadata": metadata if isinstance(metadata, dict) else {},
                    "distance": float(distance),
                    "score": 1.0 - float(distance),
                }
            )
        return output


def create_vector_store() -> BaseVectorStore:
    """Select the runtime vector backend."""
    backend = VECTOR_STORE_BACKEND
    if backend not in {"auto", "chroma", "pgvector"}:
        raise RuntimeError(
            "Unknown VECTOR_STORE_BACKEND. Use auto, chroma, or pgvector."
        )

    if backend in {"auto", "pgvector"} and DATABASE_URL:
        return PgVectorStore()
    if backend == "pgvector":
        raise RuntimeError("VECTOR_STORE_BACKEND=pgvector but DATABASE_URL is not set")
    return ChromaVectorStore()
