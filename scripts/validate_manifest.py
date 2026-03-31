#!/usr/bin/env python3
"""
validate_manifest.py — Manifest Validation Gate
FOR THE COMMONS GOOD — validates all manifest entries before ingest or snapshot

Checks:
  - Every source has required fields (id, title, source_path, access_tier, status)
  - Every normalized_markdown path resolves to a real file
  - No duplicate IDs
  - No orphan knowledge files (files not tracked by manifest)
  - Partition field (if present) maps to a known partition

Usage:
  python scripts/validate_manifest.py
  python scripts/validate_manifest.py --manifest data/rse_cv_manifest.json
  python scripts/validate_manifest.py --strict   # fail on warnings too

Exit codes:
  0 = all checks pass
  1 = errors found (blocks ingest/snapshot)
  2 = warnings only (passes unless --strict)
"""

from __future__ import annotations

import json
import sys
import os
from pathlib import Path

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

KNOWN_PARTITIONS = {
    "cv_personal", "cv_projects", "business_seatrace",
    "business_proposals", "internal_repos", "recreational",
}

REQUIRED_FIELDS = {"id", "title", "source_path", "access_tier", "status"}
VALID_TIERS = {"public", "business", "private"}
VALID_STATUSES = {"active", "draft", "archived"}


def validate(manifest_path: Path, strict: bool = False) -> int:
    errors: list[str] = []
    warnings: list[str] = []

    # ── Load manifest ─────────────────────────────────────────────
    if not manifest_path.exists():
        print(f"❌ FATAL: Manifest not found: {manifest_path}")
        return 1

    try:
        data = json.loads(manifest_path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as e:
        print(f"❌ FATAL: Invalid JSON in {manifest_path}: {e}")
        return 1

    sources = data.get("sources", [])
    if not sources:
        print("❌ FATAL: No sources found in manifest")
        return 1

    print(f"📋 Validating manifest v{data.get('version', '?')} — {len(sources)} sources")
    print(f"   Last updated: {data.get('last_updated', 'unknown')}")
    print()

    # ── Check each source ─────────────────────────────────────────
    seen_ids: set[str] = set()

    for i, src in enumerate(sources):
        src_id = src.get("id", f"[index {i}]")

        # Required fields
        missing = REQUIRED_FIELDS - set(src.keys())
        if missing:
            errors.append(f"[{src_id}] Missing required fields: {missing}")

        # Duplicate IDs
        if src_id in seen_ids:
            errors.append(f"[{src_id}] Duplicate ID")
        seen_ids.add(src_id)

        # Access tier validation
        tier = src.get("access_tier", "")
        if tier not in VALID_TIERS:
            errors.append(f"[{src_id}] Invalid access_tier: '{tier}' (must be {VALID_TIERS})")

        # Status validation
        status = src.get("status", "")
        if status not in VALID_STATUSES:
            warnings.append(f"[{src_id}] Unusual status: '{status}' (expected {VALID_STATUSES})")

        # Partition validation
        partition = src.get("partition")
        if partition and partition not in KNOWN_PARTITIONS:
            warnings.append(f"[{src_id}] Unknown partition: '{partition}' (known: {KNOWN_PARTITIONS})")

        # Normalized markdown file check
        md_path = src.get("normalized_markdown")
        if md_path:
            full_path = REPO_ROOT / md_path
            if full_path.exists():
                # Check it's not empty
                if full_path.stat().st_size == 0:
                    warnings.append(f"[{src_id}] Markdown exists but is empty: {md_path}")
            else:
                errors.append(f"[{src_id}] Markdown file not found: {md_path}")
        else:
            warnings.append(f"[{src_id}] No normalized_markdown — raw source only")

        # Topics check
        topics = src.get("topics", [])
        if not topics:
            warnings.append(f"[{src_id}] No topics defined")

    # ── Orphan check ──────────────────────────────────────────────
    tracked_md_files = set()
    for src in sources:
        md = src.get("normalized_markdown")
        if md:
            tracked_md_files.add(Path(md).name)

    kb_public_cv = REPO_ROOT / "knowledge_base" / "public" / "cv"
    if kb_public_cv.exists():
        for f in kb_public_cv.iterdir():
            if f.suffix in (".md", ".txt") and f.name not in tracked_md_files:
                # Skip directories and non-content files
                if f.is_file():
                    warnings.append(f"Orphan file not in manifest: knowledge_base/public/cv/{f.name}")

    # ── Report ────────────────────────────────────────────────────
    print("=" * 60)

    if errors:
        print(f"\n❌ ERRORS ({len(errors)}):")
        for e in errors:
            print(f"   ✗ {e}")

    if warnings:
        print(f"\n⚠️  WARNINGS ({len(warnings)}):")
        for w in warnings:
            print(f"   ⚠ {w}")

    if not errors and not warnings:
        print("✅ All checks pass — manifest is clean")

    print()
    print(f"   Sources: {len(sources)}")
    print(f"   Unique IDs: {len(seen_ids)}")
    print(f"   Errors: {len(errors)}")
    print(f"   Warnings: {len(warnings)}")
    print("=" * 60)

    if errors:
        print("\n🛑 BLOCKED — fix errors before ingest or snapshot")
        return 1
    elif warnings and strict:
        print("\n🛑 BLOCKED (--strict mode) — fix warnings too")
        return 2
    elif warnings:
        print("\n✅ PASS (with warnings) — safe to proceed")
        return 0
    else:
        print("\n✅ CLEAN PASS — ready for ingest and snapshot")
        return 0


def main() -> None:
    import argparse
    parser = argparse.ArgumentParser(description="Validate CV manifest before ingest/snapshot")
    parser.add_argument("--manifest", type=Path, default=DEFAULT_MANIFEST,
                        help="Path to manifest JSON")
    parser.add_argument("--strict", action="store_true",
                        help="Treat warnings as errors")
    args = parser.parse_args()

    exit_code = validate(args.manifest, strict=args.strict)
    sys.exit(exit_code)


if __name__ == "__main__":
    main()
