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
    audit_public_api_identity(results)
    audit_live_claim_map(results)

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
