from __future__ import annotations
import gzip
import json
import sys
from pathlib import Path

import pandas as pd
import yaml

ROOT = Path(__file__).resolve().parents[1]
EXPERIMENTS = ROOT.parent
PARENT = EXPERIMENTS / "ssrn_market_replay_v0_1"
RESULTS = ROOT / "results"
RESULTS.mkdir(parents=True, exist_ok=True)
sys.path.insert(0, str(ROOT))

from src.decision_uop import (
    build_decision_frame,
    build_receipts,
    canonical_json_bytes,
    canonicalize,
    evaluate_policy,
    load_forecast_contracts,
    load_market,
    policy_returns,
    sha256_bytes,
    sha256_file,
)
from src.robustness import moving_block_mean_delta

PROTOCOL_PATH = ROOT / "PROTOCOL.yaml"
PROTOCOL = yaml.safe_load(PROTOCOL_PATH.read_text())
FORECAST_PATH = PARENT / "results" / "forecast_contracts_test.jsonl.gz"
COSTS = PROTOCOL["cost_scenarios_bps_round_trip"]
POLICIES = ["decision_no_veto", "decision_with_volatility_veto", "always_long_non_overlapping"]


def write_jsonl_gz(rows, path: Path):
    raw = b"".join(canonical_json_bytes(r) for r in rows)
    path.write_bytes(gzip.compress(raw, compresslevel=9, mtime=0))


def main():
    protocol_sha = sha256_file(PROTOCOL_PATH)
    forecast_file_sha = sha256_file(FORECAST_PATH)
    forecasts = load_forecast_contracts(FORECAST_PATH, PROTOCOL["forecast_input"]["variant"])

    metric_rows = []
    bootstrap_rows = []
    configs = []
    receipts = []
    input_hashes = {
        "protocol_sha256": protocol_sha,
        "forecast_contracts_file_sha256": forecast_file_sha,
        "market_snapshots": {},
    }

    for symbol in PROTOCOL["data"]["symbols"] if "data" in PROTOCOL else ["BTCUSDT", "ETHUSDT", "SOLUSDT"]:
        market_path = PARENT / "data" / "frozen" / f"{symbol}_1h_2024-01_2025-12.csv.gz"
        input_hashes["market_snapshots"][symbol] = sha256_file(market_path)
        market = load_market(market_path)
        sf = forecasts[forecasts.symbol == symbol].copy()
        decision_df, config = build_decision_frame(
            sf,
            market,
            probability_threshold=float(PROTOCOL["decision"]["long_probability_threshold"]),
            risk_quantile=float(PROTOCOL["risk_veto"]["rv24_quantile"]),
        )
        config["symbol"] = symbol
        configs.append(config)
        receipts.extend(build_receipts(decision_df, symbol, protocol_sha, COSTS))

        for cost in COSTS:
            for policy in POLICIES:
                metric_rows.append({"symbol": symbol, **evaluate_policy(decision_df, policy, float(cost))})

            _, no_veto = policy_returns(decision_df, "decision_no_veto", float(cost))
            _, veto = policy_returns(decision_df, "decision_with_volatility_veto", float(cost))
            rb = moving_block_mean_delta(veto, no_veto, block_size=28, reps=2000, seed=7)
            bootstrap_rows.append(canonicalize({
                "symbol": symbol,
                "cost_bps_round_trip": cost,
                "candidate": "decision_with_volatility_veto",
                "baseline": "decision_no_veto",
                **rb,
            }))

    metrics = pd.DataFrame(metric_rows)
    boot = pd.DataFrame(bootstrap_rows)
    metrics.to_csv(RESULTS / "metrics.csv", index=False, float_format="%.12g", lineterminator="\n")
    boot.to_csv(RESULTS / "bootstrap_mean_return.csv", index=False, float_format="%.12g", lineterminator="\n")
    write_jsonl_gz(receipts, RESULTS / "decision_uop_receipts.jsonl.gz")

    summary = canonicalize({
        "schema": "WORLD8_SSRN_DECISION_UOP_RESULT/3.0",
        "status": "HISTORICAL_DECISION_UOP_COMPLETE",
        "live_orders": False,
        "configuration": configs,
        "inputs": input_hashes,
        "cost_scenarios_bps_round_trip": COSTS,
        "receipt_count": len(receipts),
    })
    (RESULTS / "summary.json").write_bytes(canonical_json_bytes(summary))

    evidence = {
        "schema": "WORLD8_SSRN_DECISION_UOP_EVIDENCE_MANIFEST/1.0",
        "files": {},
    }
    for name in ["metrics.csv", "bootstrap_mean_return.csv", "decision_uop_receipts.jsonl.gz", "summary.json"]:
        p = RESULTS / name
        evidence["files"][name] = {"bytes": p.stat().st_size, "sha256": sha256_file(p)}
    evidence["bundle_hash"] = sha256_bytes(canonical_json_bytes(evidence["files"]))
    (RESULTS / "evidence_manifest.json").write_bytes(canonical_json_bytes(evidence))
    print(json.dumps(summary, indent=2, sort_keys=True))


if __name__ == "__main__":
    main()
