from __future__ import annotations

import gzip
import json
from pathlib import Path
import sys

import pandas as pd
import yaml

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from src.extensions import extend_symbol

PROTOCOL = yaml.safe_load((ROOT / "PROTOCOL.yaml").read_text())
RESULTS = ROOT / "results"
RESULTS.mkdir(parents=True, exist_ok=True)
MANIFEST = json.loads((ROOT / "data" / "frozen" / "snapshot_manifest.json").read_text())


def load_symbol(symbol: str) -> pd.DataFrame:
    p = ROOT / "data" / "frozen" / f"{symbol}_1h_2024-01_2025-12.csv.gz"
    df = pd.read_csv(p, compression="gzip")
    df["open_time"] = pd.to_datetime(df["open_time_us"], unit="us", utc=True)
    df["close_time"] = pd.to_datetime(df["close_time_us"], unit="us", utc=True)
    return df


def snapshot_hash(symbol: str) -> str | None:
    for row in MANIFEST["symbols"]:
        if row["symbol"] == symbol:
            return row.get("normalized_sha256") or row.get("sha256")
    return None


def write_jsonl_gz(rows, path: Path):
    raw = b"".join((json.dumps(r, sort_keys=True, separators=(",", ":")) + "\n").encode() for r in rows)
    path.write_bytes(gzip.compress(raw, compresslevel=9, mtime=0))


def main():
    metrics = []
    ablations = []
    correlations = []
    uop_frames = []
    uop_summary = []
    contracts = []
    versions = {}
    parameters = {}

    for symbol in PROTOCOL["data"]["symbols"]:
        out = extend_symbol(load_symbol(symbol), symbol, PROTOCOL, snapshot_hash(symbol))
        metrics.extend(out["metrics"])
        ablations.extend(out["ablations"])
        correlations.extend(out["error_correlations"])
        uop_frames.append(out["uop_rows"])
        uop_summary.append(out["uop_summary"])
        contracts.extend(out["contracts"])
        versions[symbol] = out["version_receipt"]
        parameters[symbol] = out["parameters"]

    pd.DataFrame(metrics).to_csv(RESULTS / "extended_metrics.csv", index=False, float_format="%.12g", lineterminator="\n")
    pd.DataFrame(ablations).to_csv(RESULTS / "extended_ablation_bootstrap.csv", index=False, float_format="%.12g", lineterminator="\n")
    pd.DataFrame(correlations).to_csv(RESULTS / "analyst_error_correlation.csv", index=False, float_format="%.12g", lineterminator="\n")
    pd.concat(uop_frames, ignore_index=True).to_csv(RESULTS / "decision_uop_replay.csv", index=False, float_format="%.12g", lineterminator="\n")
    pd.DataFrame(uop_summary).to_csv(RESULTS / "decision_uop_summary.csv", index=False, float_format="%.12g", lineterminator="\n")
    write_jsonl_gz(contracts, RESULTS / "forecast_contracts_test_v2.jsonl.gz")

    summary = {
        "schema": "WORLD8_SSRN_E4E5_RESULT/1.0",
        "status": "E4_E5_EXTENSIONS_COMPLETE",
        "variants": ["calibrated_weighted", "disagreement_shrink", "regime_weighted", "shadow_cold_start"],
        "ablation_interpretation_rule": "candidate-minus-baseline Brier < 0 is improvement; retain null/negative findings",
        "version_receipts": versions,
        "parameters": parameters,
        "uop": uop_summary,
        "files": {
            "metrics": "extended_metrics.csv",
            "ablation_bootstrap": "extended_ablation_bootstrap.csv",
            "analyst_error_correlation": "analyst_error_correlation.csv",
            "decision_replay": "decision_uop_replay.csv",
            "decision_summary": "decision_uop_summary.csv",
            "forecast_contracts_v2": "forecast_contracts_test_v2.jsonl.gz",
        },
    }
    (RESULTS / "extended_summary.json").write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n")
    print(json.dumps(summary, indent=2))


if __name__ == "__main__":
    main()
