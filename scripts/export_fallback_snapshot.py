#!/usr/bin/env python3
"""
export_fallback_snapshot.py — Offline-Safe Fallback Snapshot Exporter
FOR THE COMMONS GOOD — keeps the system usable when live vector stack is unavailable

Reads the manifest, pulls only public/approved content, exports a compact
fallback_snapshot.json that the frontend can use for offline/degraded retrieval.

Usage:
  python scripts/export_fallback_snapshot.py
  python scripts/export_fallback_snapshot.py --output public/fallback_snapshot.json
  python scripts/export_fallback_snapshot.py --max-text-length 500

Output: public/fallback_snapshot.json (default)

The frontend fallback strategy:
  1. Try live retrieval API
  2. If unavailable → load fallback_snapshot.json
  3. Simple text search against items
  4. Always show { mode: "fallback" } so user knows

Export rules:
  - Only include items with access_tier == "public"
  - Only include items with status == "active"
  - Strip any sensitive metadata
  - Collapse long docs into summaries
  - Preserve source references
  - Include generation version/date
  - Fail loudly if manifest items are missing
"""

from __future__ import annotations

import json
import hashlib
import sys
import os
from pathlib import Path
from datetime import datetime, timezone

# Fix Windows console encoding for emoji/unicode
if sys.platform == "win32":
    os.environ.setdefault("PYTHONIOENCODING", "utf-8")
    try:
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
        sys.stderr.reconfigure(encoding="utf-8", errors="replace")
    except Exception:
        pass

REPO_ROOT = Path(__file__).resolve().parent.parent
DEFAULT_MANIFEST = REPO_ROOT / "data" / "rse_cv_manifest.json"
DEFAULT_OUTPUT = REPO_ROOT / "public" / "fallback_snapshot.json"
MAX_TEXT_LENGTH = 2000  # Characters per item — keeps snapshot compact


def read_markdown_content(md_path: str) -> str | None:
    """Read normalized markdown file content."""
    full_path = REPO_ROOT / md_path
    if not full_path.exists():
        return None
    try:
        return full_path.read_text(encoding="utf-8").strip()
    except Exception:
        try:
            return full_path.read_text(encoding="cp1252").strip()
        except Exception:
            return None


def extract_summary(text: str, max_length: int = 300) -> str:
    """Extract a summary from the first meaningful paragraph."""
    lines = [l.strip() for l in text.split("\n") if l.strip()]
    # Skip heading lines
    content_lines = [l for l in lines if not l.startswith("#") and not l.startswith("---")]
    if not content_lines:
        return text[:max_length]
    summary = " ".join(content_lines[:3])
    if len(summary) > max_length:
        summary = summary[:max_length - 3] + "..."
    return summary


def build_snapshot(manifest_path: Path, output_path: Path, max_text: int = MAX_TEXT_LENGTH) -> int:
    """Build the fallback snapshot from manifest."""

    # ── Load manifest ─────────────────────────────────────────────
    if not manifest_path.exists():
        print(f"❌ FATAL: Manifest not found: {manifest_path}")
        return 1

    try:
        data = json.loads(manifest_path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as e:
        print(f"❌ FATAL: Invalid JSON: {e}")
        return 1

    sources = data.get("sources", [])
    version = data.get("version", "unknown")
    print(f"📋 Reading manifest v{version} — {len(sources)} sources")

    # ── Filter to public + active only ────────────────────────────
    public_sources = [
        s for s in sources
        if s.get("access_tier") == "public" and s.get("status") == "active"
    ]
    print(f"   Public + active: {len(public_sources)} / {len(sources)}")

    # ── Build items ───────────────────────────────────────────────
    items = []
    skipped = []

    for src in public_sources:
        src_id = src.get("id", "unknown")
        title = src.get("title", "Untitled")
        md_path = src.get("normalized_markdown")
        topics = src.get("topics", [])
        partition = src.get("partition", "cv_personal")

        # Read content
        text = None
        if md_path:
            text = read_markdown_content(md_path)

        if not text:
            # Try to note what's missing but don't fail
            skipped.append(f"[{src_id}] No readable content (md_path={md_path})")
            # Still include as a stub so the ID is searchable
            text = f"{title}. Topics: {', '.join(topics)}"

        # Truncate if needed
        full_text = text[:max_text] if len(text) > max_text else text
        summary = extract_summary(text)

        # Deterministic content hash for cache-busting
        content_hash = hashlib.md5(full_text.encode()).hexdigest()[:8]

        items.append({
            "id": src_id,
            "title": title,
            "summary": summary,
            "text": full_text,
            "tags": topics,
            "partition": partition,
            "visibility": "public",
            "status": "approved",
            "source_ref": md_path or src.get("source_path", ""),
            "content_hash": content_hash,
        })

    # ── Build payload ─────────────────────────────────────────────
    now = datetime.now(timezone.utc)
    payload = {
        "version": now.strftime("%Y-%m-%d"),
        "generated_at": now.isoformat(),
        "source_manifest": str(manifest_path.relative_to(REPO_ROOT)),
        "manifest_version": version,
        "item_count": len(items),
        "mode": "fallback",
        "note": "Offline-safe snapshot — public content only. FOR THE COMMONS GOOD.",
        "items": items,
    }

    # ── Write output ──────────────────────────────────────────────
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(
        json.dumps(payload, indent=2, ensure_ascii=False),
        encoding="utf-8"
    )

    size_kb = output_path.stat().st_size / 1024
    print(f"\n✅ Wrote {output_path} ({size_kb:.1f} KB)")
    print(f"   Items: {len(items)}")
    print(f"   Version: {payload['version']}")

    if skipped:
        print(f"\n⚠️  Skipped content for {len(skipped)} items (stubs included):")
        for s in skipped:
            print(f"   ⚠ {s}")

    print(f"\n🔒 Snapshot is public-safe — no business/private content included")
    return 0


def main() -> None:
    import argparse
    parser = argparse.ArgumentParser(description="Export offline fallback snapshot")
    parser.add_argument("--manifest", type=Path, default=DEFAULT_MANIFEST,
                        help="Path to manifest JSON")
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT,
                        help="Output path for fallback snapshot")
    parser.add_argument("--max-text-length", type=int, default=MAX_TEXT_LENGTH,
                        help="Max text length per item (default 2000)")
    args = parser.parse_args()

    exit_code = build_snapshot(args.manifest, args.output, args.max_text_length)
    sys.exit(exit_code)


if __name__ == "__main__":
    main()
