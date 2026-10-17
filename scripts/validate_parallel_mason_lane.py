#!/usr/bin/env python3
"""Validate the canonical N-Mason parallel-engineering contract.

This validator is intentionally independent from the Academy/Access/Cockpit
validator in the other pilot lane. It checks only canonical N-Mason invariants
that must remain true before parallel coding can be called governed.
"""

from __future__ import annotations

from pathlib import Path
import sys


ROOT = Path(__file__).resolve().parents[1]
N_MASON_DOC = ROOT / "docs" / "engineering" / "N_MASON_POOL.md"


REQUIRED_MARKERS = (
    "Parallelize work; serialize truth.",
    "Provider belongs to Execution, not Actor.",
    "A Workspace on `main` or `master` is forbidden.",
    "candidate must be READY_FOR_REVIEW",
    "CI PASS is required for QUEUED state",
    "GITHUB_BRANCH_PROTECTION_REQUIRED",
    "Raw credentials are forbidden.",
    "Qualification != authorization.",
    "Concurrent coding is allowed; canonical merge is serialized.",
    "Every failure, workaround and reusable lesson enters Diagnostic Memory / Handoff / Postflight.",
)

REQUIRED_LIFECYCLE_MARKERS = (
    "Reserve an available Mason slot from a pool.",
    "Run Mason Preflight and Diagnostic search.",
    "Create Search Receipt and Work Claim.",
    "Create an isolated Git branch/Workspace from current canonical head.",
    "Obtain scoped authorization evidence.",
    "Pass Developer Admission v0.2.",
    "Code only inside the isolated workspace.",
    "Run tests and CI.",
    "Serialize canonical merge through one merge claim.",
    "Record immutable merge receipt.",
)

FORBIDDEN_DRIFT_MARKERS = (
    "workers may write directly to canonical main",
    "provider hint proves live provider execution",
    "qualification implies authorization",
)


def require_markers(text: str, markers: tuple[str, ...], label: str) -> list[str]:
    return [f"{label}: missing {marker!r}" for marker in markers if marker not in text]


def main() -> int:
    if not N_MASON_DOC.is_file():
        print(f"FAIL: canonical N-Mason contract missing: {N_MASON_DOC}")
        return 1

    text = N_MASON_DOC.read_text(encoding="utf-8")
    errors: list[str] = []
    errors.extend(require_markers(text, REQUIRED_MARKERS, "invariant"))
    errors.extend(require_markers(text, REQUIRED_LIFECYCLE_MARKERS, "lifecycle"))

    lowered = text.lower()
    for marker in FORBIDDEN_DRIFT_MARKERS:
        if marker.lower() in lowered:
            errors.append(f"forbidden drift marker present: {marker!r}")

    if errors:
        print("FAIL: parallel Mason governance contract drift detected")
        for error in errors:
            print(f" - {error}")
        return 1

    print(
        "PASS: parallel Mason lane contract preserves isolated work, "
        "provider-independent identity, scoped authority, CI gating, "
        "serialized canonical merge, and diagnostic continuity"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
