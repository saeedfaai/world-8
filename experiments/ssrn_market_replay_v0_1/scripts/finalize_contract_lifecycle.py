from __future__ import annotations

import gzip
import hashlib
import json
from collections import Counter
from datetime import datetime, timedelta
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
RESULTS = ROOT / "results"
INPUT = RESULTS / "forecast_contracts_test_v2.jsonl.gz"
OUTPUT = RESULTS / "forecast_contracts_test_v3.jsonl.gz"
RECEIPT = RESULTS / "lifecycle_integrity.json"


def sha256_file(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def parse_iso(value: str) -> datetime:
    return datetime.fromisoformat(value.replace("Z", "+00:00"))


def main() -> None:
    if not INPUT.exists():
        raise SystemExit(f"missing input: {INPUT}")

    rows = []
    counts = Counter()
    integrity_failures = Counter()

    with gzip.open(INPUT, "rt", encoding="utf-8") as f:
        for line in f:
            r = json.loads(line)
            issued = parse_iso(r["issued_at"])
            cutoff = parse_iso(r["data_cutoff_at"])
            valid_from = parse_iso(r["valid_from"])
            horizon = int(r["horizon_hours"])
            resolved_at = issued + timedelta(hours=horizon)

            if cutoff > issued:
                integrity_failures["cutoff_after_issue"] += 1
            if valid_from < issued:
                integrity_failures["valid_from_before_issue"] += 1
            if resolved_at <= valid_from:
                integrity_failures["resolved_not_after_valid_from"] += 1
            if r.get("resolved_target") not in (0, 1):
                integrity_failures["non_binary_target"] += 1
            p = float(r["probability"])
            if not (0.0 <= p <= 1.0):
                integrity_failures["probability_out_of_bounds"] += 1
            if r.get("raw_immutable") is not True:
                integrity_failures["raw_not_immutable"] += 1

            out = dict(r)
            out["contract_schema"] = "WORLD8_FORECAST_CONTRACT/3.0-REPLAY"
            out["lifecycle_status"] = "RESOLVED"
            out["resolved_at"] = resolved_at.isoformat()
            out["resolution_reason"] = "TARGET_OBSERVED"
            rows.append(out)
            counts["RESOLVED"] += 1

    if integrity_failures:
        raise SystemExit(f"lifecycle integrity failures: {dict(integrity_failures)}")

    raw = b"".join(
        (json.dumps(r, sort_keys=True, separators=(",", ":")) + "\n").encode("utf-8")
        for r in rows
    )
    OUTPUT.write_bytes(gzip.compress(raw, compresslevel=9, mtime=0))

    receipt = {
        "schema": "WORLD8_FORECAST_LIFECYCLE_INTEGRITY/1.0",
        "status": "PASS",
        "projection_only": True,
        "forecast_values_changed": False,
        "input": INPUT.name,
        "input_sha256": sha256_file(INPUT),
        "output": OUTPUT.name,
        "output_sha256": sha256_file(OUTPUT),
        "total_contracts": len(rows),
        "lifecycle_counts": dict(counts),
        "invalidated": 0,
        "expired": 0,
        "withdrawn": 0,
        "superseded": 0,
        "integrity_failures": dict(integrity_failures),
        "rules": {
            "data_cutoff_at_lte_issued_at": True,
            "valid_from_gte_issued_at": True,
            "resolved_at_gt_valid_from": True,
            "binary_resolved_target": True,
            "probability_in_0_1": True,
            "raw_immutable": True,
        },
    }
    RECEIPT.write_text(json.dumps(receipt, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(json.dumps(receipt, indent=2, sort_keys=True))


if __name__ == "__main__":
    main()
