#!/usr/bin/env python3
"""
truth_audit.py - Truth-first audit gate for the R. Scott Echols CV repo.

Scans active public/runtime surfaces before ingest or retrieval work is allowed.
Outputs PASS / WARN / FAIL and can emit JSON for orchestration.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from dataclasses import asdict, dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[1]

REQUIRED_FILES = [
    "docs/CONTENT_SOURCE_OF_TRUTH.md",
    "knowledge_base/public/cv/identity_verified.md",
    "public/data/identity.json",
    "public/data/voice.json",
    "public/data/hashtags.json",
    "public/api/identity.json",
    "references/env-schema.md",
    "references/file-map.md",
]

ACTIVE_SURFACES = [
    "public/index.html",
    "netlify/edge-functions/chat.ts",
    "public/api/identity.json",
]

MIXED_TRUST_SURFACE = "knowledge_base/docs/CHATBOT_KNOWLEDGE_BRIEF.md"

CONTAMINATED_PATTERNS = [
    r"\bALOHA(?:-net)?\b",
    r"Pearl Harbor",
    r"Norman Abramson",
    r"\bHonolulu\b",
    r"\bHawaii\b",
]

LIVE_CLAIM_PATTERNS = {
    "title_rotation": r"Solutions Architect",
    "hero_title": r"Senior Software Developer\s*&(?:amp;)?\s*Technical Lead",
    "seatrace_value": r"\$4\.2M",
    "four_pillars": r"SeaTrace Four Pillars",
    "sirtrav_d2a": r"D2A \(Doc-to-Agent\)",
    "claude_opus": r"Claude Opus 4\.6",
    "gemini_embed": r"Gemini Embedding 2",
}


@dataclass
class CheckResult:
    name: str
    status: str
    severity: str
    message: str
    evidence: list[str]


def read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def rel(path: Path) -> str:
    return str(path.relative_to(ROOT)).replace("\\", "/")


def find_pattern_lines(text: str, pattern: str) -> list[str]:
    regex = re.compile(pattern, re.IGNORECASE)
    hits = []
    for idx, line in enumerate(text.splitlines(), start=1):
        if regex.search(line):
            hits.append(f"line {idx}: {line.strip()[:180]}")
    return hits


def add_result(results: list[CheckResult], name: str, status: str, severity: str,
               message: str, evidence: list[str] | None = None) -> None:
    results.append(CheckResult(name, status, severity, message, evidence or []))


def audit_required_files(results: list[CheckResult]) -> None:
    missing = [p for p in REQUIRED_FILES if not (ROOT / p).exists()]
    if missing:
        add_result(
            results,
            "required-files",
            "FAIL",
            "error",
            "Required truth-pack files are missing.",
            missing,
        )
    else:
        add_result(
            results,
            "required-files",
            "PASS",
            "info",
            "All required truth-pack files are present.",
            REQUIRED_FILES,
        )


def audit_active_surfaces(results: list[CheckResult]) -> None:
    contaminated = []
    for rel_path in ACTIVE_SURFACES:
        path = ROOT / rel_path
        if not path.exists():
            continue
        text = read_text(path)
        for pattern in CONTAMINATED_PATTERNS:
            lines = find_pattern_lines(text, pattern)
            if lines:
                contaminated.append(f"{rel_path} :: /{pattern}/ :: {lines[0]}")
    if contaminated:
        add_result(
            results,
            "active-surface-contamination",
            "FAIL",
            "error",
            "Unsupported legacy claims were found in active public/runtime surfaces.",
            contaminated,
        )
    else:
        add_result(
            results,
            "active-surface-contamination",
            "PASS",
            "info",
            "Active public/runtime surfaces are free of blocked legacy claims.",
            ACTIVE_SURFACES,
        )


def audit_mixed_trust_note(results: list[CheckResult]) -> None:
    path = ROOT / MIXED_TRUST_SURFACE
    if not path.exists():
        add_result(
            results,
            "mixed-trust-brief",
            "WARN",
            "warn",
            "Legacy brief is missing; mixed-trust status could not be verified.",
            [MIXED_TRUST_SURFACE],
        )
        return
    text = read_text(path).splitlines()
    ok = len(text) >= 2 and "mixed-trust historical draft" in text[1]
    if ok:
        add_result(
            results,
            "mixed-trust-brief",
            "PASS",
            "info",
            "Legacy brief is explicitly marked mixed-trust.",
            [f"{MIXED_TRUST_SURFACE}:2"],
        )
    else:
        add_result(
            results,
            "mixed-trust-brief",
            "FAIL",
            "error",
            "Legacy brief is not marked mixed-trust at the top of the file.",
            [MIXED_TRUST_SURFACE],
        )


def audit_env_contract(results: list[CheckResult]) -> None:
    chat = read_text(ROOT / "netlify/edge-functions/chat.ts")
    embed = read_text(ROOT / "netlify/edge-functions/embed.ts")
    netlify_toml = read_text(ROOT / "netlify.toml")

    errors = []
    if "ANTHROPIC_API_KEY" not in chat:
        errors.append("chat.ts does not reference ANTHROPIC_API_KEY")
    if "GEMINI_API_KEY" not in embed:
        errors.append("embed.ts does not reference GEMINI_API_KEY")
    if "ANTHROPIC_API_KEY" not in netlify_toml or "GEMINI_API_KEY" not in netlify_toml:
        errors.append("netlify.toml env comments are out of sync with runtime files")

    if errors:
        add_result(
            results,
            "env-contract",
            "FAIL",
            "error",
            "Chat/embed env schema is inconsistent.",
            errors,
        )
    else:
        add_result(
            results,
            "env-contract",
            "PASS",
            "info",
            "Chat/embed env schema matches the runtime contract.",
            [
                "chat.ts -> ANTHROPIC_API_KEY",
                "embed.ts -> GEMINI_API_KEY",
                "netlify.toml -> matching env docs",
            ],
        )


def _dict_literal_block(text: str, start_marker: str) -> str:
    """
    Return the source of the dict literal that follows `start_marker`, using
    brace matching rather than the first closing brace — the ingest engine's
    registry maps each partition to a nested dict, so a naive scan stops at
    the first inner value and reports the inner keys as partition names.
    """
    idx = text.find(start_marker)
    if idx == -1:
        return ""
    open_idx = text.find("{", idx)
    if open_idx == -1:
        return ""
    depth = 0
    for i in range(open_idx, len(text)):
        if text[i] == "{":
            depth += 1
        elif text[i] == "}":
            depth -= 1
            if depth == 0:
                return text[open_idx : i + 1]
    return ""


def _extract_partitions(text: str, start_marker: str) -> set[str]:
    """Top-level quoted keys of the dict literal following the marker."""
    block = _dict_literal_block(text, start_marker)
    if not block:
        return set()
    # Only keys at nesting depth 1 are partition names.
    keys: set[str] = set()
    depth = 0
    for match in re.finditer(r'[{}]|"([a-z_]+)"\s*:', block):
        token = match.group(0)
        if token == "{":
            depth += 1
        elif token == "}":
            depth -= 1
        elif depth == 1 and match.group(1):
            keys.add(match.group(1))
    return keys


def _public_partitions(text: str, start_marker: str) -> set[str]:
    """Partitions declared public inside the given dict literal."""
    block = _dict_literal_block(text, start_marker)
    return set(re.findall(r'"([a-z_]+)":\s*"public"', block)) | set(
        re.findall(r'"([a-z_]+)":\s*\{[^{}]*?"tier":\s*"public"', block, re.S)
    )


def audit_partition_registry(results: list[CheckResult]) -> None:
    """
    The partition registry is duplicated in three places by necessity — the
    retrieval service, the ingest engine, and the SQL schema. If they drift,
    the tier boundary silently stops matching in one of them, which is a
    content-leak shaped bug rather than a crash. This gate is the reason a
    drift cannot merge quietly.
    """
    server = read_text(ROOT / "scripts/api_server.py")
    engine = read_text(ROOT / "scripts/embed_engine.py")
    schema = read_text(ROOT / "scripts/schema/wsp001_knowledge.sql")

    server_parts = _extract_partitions(server, "PARTITION_TIERS: dict[str, str] = {")
    engine_parts = _extract_partitions(engine, "PARTITIONS = {")
    schema_parts = set(re.findall(r"\('([a-z_]+)',\s*'(?:public|business|private)'", schema))

    errors: list[str] = []
    if not server_parts:
        errors.append("could not read PARTITION_TIERS from scripts/api_server.py")
    if not engine_parts:
        errors.append("could not read PARTITIONS from scripts/embed_engine.py")
    if not schema_parts:
        errors.append("could not read the partition registry from the SQL schema")

    if server_parts and engine_parts and server_parts != engine_parts:
        only_server = sorted(server_parts - engine_parts)
        only_engine = sorted(engine_parts - server_parts)
        errors.append(
            f"api_server.py vs embed_engine.py mismatch — "
            f"server only: {only_server or 'none'}; engine only: {only_engine or 'none'}"
        )
    if server_parts and schema_parts and server_parts != schema_parts:
        errors.append(
            f"api_server.py vs SQL schema mismatch — "
            f"server only: {sorted(server_parts - schema_parts) or 'none'}; "
            f"schema only: {sorted(schema_parts - server_parts) or 'none'}"
        )

    # The tier boundary itself: a public partition must be declared public in
    # BOTH the server and the schema. CLAUDE.md: public never sees business.
    public_in_server = _public_partitions(server, "PARTITION_TIERS: dict[str, str] = {")
    public_in_schema = set(re.findall(r"\('([a-z_]+)',\s*'public'", schema))
    if public_in_server and public_in_schema and public_in_server != public_in_schema:
        errors.append(
            f"PUBLIC tier disagreement — server: {sorted(public_in_server)}, "
            f"schema: {sorted(public_in_schema)}"
        )
    for leaked in sorted(p for p in public_in_server if p.startswith(("business_", "internal_"))):
        errors.append(f"TIER LEAK: '{leaked}' is marked public in api_server.py")

    if errors:
        add_result(results, "partition-registry", "FAIL", "error",
                   "Partition registries disagree across the retrieval stack.", errors)
    else:
        add_result(results, "partition-registry", "PASS", "info",
                   "Partition registry and tier boundary agree across all three sources.",
                   [f"{len(server_parts)} partitions",
                    f"public tier: {sorted(public_in_server)}",
                    "api_server.py == embed_engine.py == wsp001_knowledge.sql"])


def audit_vector_backend_contract(results: list[CheckResult]) -> None:
    """
    Guards the drift repaired on 2026-09-13: the committed retrieval service
    said ChromaDB while production ran pgvector. Committed code that misstates
    the deployed backend is worse than no documentation, because every agent
    downstream reasons from it.
    """
    server_path = ROOT / "scripts/api_server.py"
    server = read_text(server_path)
    reqs = read_text(ROOT / "scripts/requirements.txt")

    errors: list[str] = []
    # Match ChromaDB USAGE, not prose. The header note names ChromaDB on
    # purpose, to warn the next agent off reintroducing it; a substring search
    # would flag that warning as the very thing it warns about.
    chroma_usage = find_pattern_lines(
        server,
        r"(?i)(import\s+chromadb|chromadb\.|PersistentClient|CHROMADB_PATH|get_chroma_collection)",
    )
    if chroma_usage:
        errors.append(
            f"scripts/api_server.py still USES ChromaDB: {chroma_usage[:3]}"
        )
    # Ignore comment lines — requirements.txt records why chromadb was dropped.
    req_deps = [
        line.strip()
        for line in reqs.splitlines()
        if line.strip() and not line.strip().startswith("#")
    ]
    if any("chromadb" in dep.lower() for dep in req_deps):
        errors.append("scripts/requirements.txt still installs chromadb for the service")
    if "pgvector" not in server.lower():
        errors.append("scripts/api_server.py does not identify pgvector as its backend")
    if "DATABASE_URL" not in server:
        errors.append("scripts/api_server.py does not read DATABASE_URL")
    if not (ROOT / "scripts/schema/wsp001_knowledge.sql").exists():
        errors.append("scripts/schema/wsp001_knowledge.sql is missing")

    if errors:
        add_result(results, "vector-backend-contract", "FAIL", "error",
                   "Committed retrieval code does not match the deployed pgvector backend.",
                   errors)
    else:
        add_result(results, "vector-backend-contract", "PASS", "info",
                   "Committed retrieval code matches the deployed pgvector backend.",
                   ["scripts/api_server.py -> pgvector + DATABASE_URL",
                    "scripts/schema/wsp001_knowledge.sql present",
                    "no chromadb in the service dependency set"])


def audit_public_api_identity(results: list[CheckResult]) -> None:
    data_path = ROOT / "public/data/identity.json"
    api_path = ROOT / "public/api/identity.json"
    data = json.loads(read_text(data_path))
    api = json.loads(read_text(api_path))

    required_api_keys = [
        "profile_id",
        "title",
        "identity_boundaries",
        "trust_policy",
        "source_status",
        "verified_live_claims",
    ]
    missing = [k for k in required_api_keys if k not in api]
    if missing:
        add_result(
            results,
            "identity-endpoint-shape",
            "FAIL",
            "error",
            "public/api/identity.json is missing required truth-pack keys.",
            missing,
        )
    else:
        add_result(
            results,
            "identity-endpoint-shape",
            "PASS",
            "info",
            "public/api/identity.json exposes the expected truth-pack shape.",
            required_api_keys,
        )

    mismatches = []
    if api.get("profile_id") != data.get("profile_id"):
        mismatches.append("profile_id differs from public/data/identity.json")
    api_email = (api.get("contact") or {}).get("email")
    data_email = (data.get("contact") or {}).get("email")
    if api_email != data_email:
        mismatches.append("contact.email differs from public/data/identity.json")

    if mismatches:
        add_result(
            results,
            "identity-endpoint-consistency",
            "FAIL",
            "error",
            "public/api/identity.json conflicts with the truth-pack identity data.",
            mismatches,
        )
    else:
        add_result(
            results,
            "identity-endpoint-consistency",
            "PASS",
            "info",
            "public/api/identity.json is aligned with the truth-pack identity data.",
            [rel(api_path)],
        )


def audit_live_claim_map(results: list[CheckResult]) -> None:
    text = read_text(ROOT / "public/index.html")
    missing = []
    for name, pattern in LIVE_CLAIM_PATTERNS.items():
        if not re.search(pattern, text, re.IGNORECASE):
            missing.append(name)
    if missing:
        add_result(
            results,
            "live-claim-map",
            "WARN",
            "warn",
            "Some expected public-site claims are missing from local public/index.html.",
            missing,
        )
    else:
        add_result(
            results,
            "live-claim-map",
            "PASS",
            "info",
            "Local public/index.html contains the expected verified public claims.",
            list(LIVE_CLAIM_PATTERNS.keys()),
        )


def _allowed_partitions() -> set[str]:
    """
    The partition allowlist as the retrieval service sees it.

    api_server.py derives ALLOWED_PARTITIONS from the PARTITION_TIERS registry
    (`set(PARTITION_TIERS)`) so the name/tier pairing has one home, so read the
    registry itself. The literal-set form is still accepted as a fallback for
    older copies of the service.
    """
    text = read_text(ROOT / "scripts/api_server.py")
    for pattern in (
        r"PARTITION_TIERS[^=]*=\s*\{(.*?)\n\}",
        r"ALLOWED_PARTITIONS\s*=\s*\{(.*?)\}",
    ):
        match = re.search(pattern, text, re.DOTALL)
        if match:
            names = set(re.findall(r"\"([a-z_]+)\"", match.group(1)))
            if names:
                return names
    return set()


def audit_partition_contract(results: list[CheckResult]) -> None:
    allowed = _allowed_partitions()
    if not allowed:
        add_result(results, "partition-contract", "FAIL", "blocker",
                   "Could not parse ALLOWED_PARTITIONS from scripts/api_server.py.")
        return

    consumers = sorted((ROOT / "scripts").glob("ingest-*.mjs"))
    sirtrav_seed = ROOT.parent / "SirTrav-A2A-Studio" / "netlify" / "functions" / "lib" / "content-seed.ts"
    if sirtrav_seed.exists():
        consumers.append(sirtrav_seed)

    partition_ref = re.compile(
        r"(?:PARTITION\s*=\s*|partition\s*[:=]\s*|fetchPartition\([^,]+,[^,]+,\s*)['\"]([a-z_]+)['\"]"
    )
    unknown: list[str] = []
    scanned: list[str] = []
    for path in consumers:
        text = read_text(path)
        label = rel(path) if path.is_relative_to(ROOT) else str(path)
        scanned.append(label)
        for idx, line in enumerate(text.splitlines(), start=1):
            for name in partition_ref.findall(line):
                if name not in allowed:
                    unknown.append(f"{label}:{idx} -> '{name}' not in ALLOWED_PARTITIONS")

    if unknown:
        add_result(results, "partition-contract", "FAIL", "blocker",
                   "Consumers reference partitions the retrieval service rejects (silent-empty on /query, HTTP 400 on /ingest).",
                   unknown)
    else:
        add_result(results, "partition-contract", "PASS", "info",
                   "Every partition referenced by ingest/retrieval consumers is in ALLOWED_PARTITIONS.",
                   scanned)


def summarize(results: list[CheckResult]) -> str:
    statuses = {r.status for r in results}
    if "FAIL" in statuses:
        return "FAIL"
    if "WARN" in statuses:
        return "WARN"
    return "PASS"


def emit_text(results: list[CheckResult], final_status: str) -> None:
    print(f"TRUTH-AUDIT: {final_status}")
    for result in results:
        print(f"[{result.status}] {result.name}: {result.message}")
        for item in result.evidence[:5]:
            print(f"  - {item}")


def emit_json(results: list[CheckResult], final_status: str) -> dict[str, Any]:
    return {
        "status": final_status,
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "checks": [asdict(r) for r in results],
    }


def main() -> int:
    parser = argparse.ArgumentParser(description="Truth-first audit gate")
    parser.add_argument("--format", choices=["text", "json"], default="text")
    parser.add_argument("--output", type=str, default="")
    parser.add_argument("--gate", type=str, default="")
    args = parser.parse_args()

    results: list[CheckResult] = []
    audit_required_files(results)
    audit_active_surfaces(results)
    audit_mixed_trust_note(results)
    audit_env_contract(results)
    audit_partition_registry(results)
    audit_vector_backend_contract(results)
    audit_public_api_identity(results)
    audit_live_claim_map(results)
    audit_partition_contract(results)

    final_status = summarize(results)
    payload = emit_json(results, final_status)

    if args.output:
        output_path = Path(args.output)
        if not output_path.is_absolute():
            output_path = ROOT / output_path
        output_path.parent.mkdir(parents=True, exist_ok=True)
        output_path.write_text(json.dumps(payload, indent=2), encoding="utf-8")

    if args.format == "json":
        print(json.dumps(payload, indent=2))
    else:
        emit_text(results, final_status)
        if args.gate:
            print(f"GATE: {args.gate}")

    return 1 if final_status == "FAIL" else 0


if __name__ == "__main__":
    raise SystemExit(main())
