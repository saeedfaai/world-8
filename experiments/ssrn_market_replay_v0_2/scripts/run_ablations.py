from __future__ import annotations
import json
import sys
from pathlib import Path

import pandas as pd
import yaml

ROOT = Path(__file__).resolve().parents[1]
EXPERIMENTS = ROOT.parent
sys.path.insert(0, str(EXPERIMENTS))

from ssrn_market_replay_v0_2.src.ablations import run_ablations

PROTOCOL = yaml.safe_load((ROOT / "PROTOCOL.yaml").read_text())
PARENT = EXPERIMENTS / "ssrn_market_replay_v0_1"
RESULTS = ROOT / "results"
RESULTS.mkdir(parents=True, exist_ok=True)


def load_symbol(symbol: str) -> pd.DataFrame:
    p = PARENT / "data" / "frozen" / f"{symbol}_1h_2024-01_2025-12.csv.gz"
    df = pd.read_csv(p, compression="gzip")
    df["open_time"] = pd.to_datetime(df["open_time_us"], unit="us", utc=True)
    df["close_time"] = pd.to_datetime(df["close_time_us"], unit="us", utc=True)
    return df


def main():
    metrics = []
    boots = []
    configs = []
    for symbol in PROTOCOL["data"]["symbols"]:
        m, b, c = run_ablations(load_symbol(symbol), symbol)
        metrics.append(m)
        boots.append(b)
        configs.append(c)

    m = pd.concat(metrics, ignore_index=True)
    b = pd.concat(boots, ignore_index=True)
    m.to_csv(RESULTS / "metrics.csv", index=False, float_format="%.12g", lineterminator="\n")
    b.to_csv(RESULTS / "bootstrap_robustness.csv", index=False, float_format="%.12g", lineterminator="\n")

    findings = {}
    for symbol in PROTOCOL["data"]["symbols"]:
        sub = m[m.symbol == symbol].sort_values("brier")
        findings[symbol] = {"best_variant": sub.iloc[0].variant, "best_brier": float(sub.iloc[0].brier)}

    summary = {
        "schema": "WORLD8_SSRN_MARKET_ABLATION_RESULT/2.0",
        "status": "ABLATIONS_COMPLETE",
        "parent_experiment": "../ssrn_market_replay_v0_1",
        "findings": findings,
        "configuration": configs,
        "bootstrap": {"method": "paired_moving_block_bootstrap", "block_size_hours": 24, "reps": 2000, "seed": 7},
    }
    (RESULTS / "summary.json").write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n")
    print(json.dumps(summary, indent=2))


if __name__ == "__main__":
    main()
