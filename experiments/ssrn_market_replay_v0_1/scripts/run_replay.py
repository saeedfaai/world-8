from __future__ import annotations
import gzip
import json
from pathlib import Path

import pandas as pd
import yaml

ROOT = Path(__file__).resolve().parents[1]
PROTOCOL = yaml.safe_load((ROOT / "PROTOCOL.yaml").read_text())
RESULTS = ROOT / "results"
RESULTS.mkdir(parents=True, exist_ok=True)

import sys
sys.path.insert(0, str(ROOT))
from src.replay import run_symbol
from src.robustness import robustness_from_contracts


def load_symbol(symbol: str) -> pd.DataFrame:
    p = ROOT / "data" / "frozen" / f"{symbol}_1h_2024-01_2025-12.csv.gz"
    df = pd.read_csv(p, compression="gzip")
    df["open_time"] = pd.to_datetime(df["open_time_us"], unit="us", utc=True)
    df["close_time"] = pd.to_datetime(df["close_time_us"], unit="us", utc=True)
    return df


def write_jsonl_gz(rows, path: Path):
    raw = b"".join((json.dumps(r, sort_keys=True, separators=(",", ":")) + "\n").encode() for r in rows)
    path.write_bytes(gzip.compress(raw, compresslevel=9, mtime=0))


def main():
    metric_frames = []
    weights = {}
    corr_weights = {}
    contracts = []
    for symbol in PROTOCOL["data"]["symbols"]:
        metrics, w, wc, c = run_symbol(load_symbol(symbol), symbol)
        metric_frames.append(metrics)
        weights[symbol] = w
        corr_weights[symbol] = wc
        contracts.extend(c)

    m = pd.concat(metric_frames, ignore_index=True)
    m.to_csv(RESULTS / "metrics.csv", index=False, float_format="%.12g", lineterminator="\n")

    robustness = robustness_from_contracts(contracts)
    pd.DataFrame(robustness).to_csv(
        RESULTS / "bootstrap_robustness.csv",
        index=False,
        float_format="%.12g",
        lineterminator="\n",
    )

    summary = {
        "schema": "WORLD8_SSRN_MARKET_REPLAY_RESULT/1.1",
        "status": "EMPIRICAL_REPLAY_COMPLETE_WITH_BOOTSTRAP",
        "protocol": "PROTOCOL.yaml",
        "weights": weights,
        "correlation_controlled_weights": corr_weights,
        "best_by_symbol_brier": {},
        "bootstrap": {
            "method": "paired_moving_block_bootstrap",
            "block_size_hours": 24,
            "reps": 2000,
            "seed": 7,
            "result_file": "bootstrap_robustness.csv",
        },
    }
    for symbol in PROTOCOL["data"]["symbols"]:
        sub = m[m.symbol == symbol].sort_values("brier")
        summary["best_by_symbol_brier"][symbol] = {
            "variant": sub.iloc[0].variant,
            "brier": float(sub.iloc[0].brier),
        }
    (RESULTS / "summary.json").write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n")
    write_jsonl_gz(contracts, RESULTS / "forecast_contracts_test.jsonl.gz")
    print(json.dumps(summary, indent=2))


if __name__ == "__main__":
    main()
