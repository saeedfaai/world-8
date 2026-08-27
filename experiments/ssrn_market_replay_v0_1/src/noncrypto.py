from __future__ import annotations

import math

import numpy as np
import pandas as pd

from src import replay as core
from src.extensions import moving_block_delta

DAILY_FEATURES = ["r1", "r5", "r20", "rv20", "volume_z20"]
DAILY_STRATEGIES = ["momentum5", "momentum20", "meanrev1", "volume_breakout"]
CAL_START = pd.Timestamp("2023-01-01", tz="UTC")
CAL_END = pd.Timestamp("2025-01-01", tz="UTC")
TEST_START = pd.Timestamp("2025-01-01", tz="UTC")
TEST_END = pd.Timestamp("2026-01-01", tz="UTC")
HORIZON_BARS = 5


def make_daily_features(df: pd.DataFrame, horizon_bars: int = HORIZON_BARS) -> pd.DataFrame:
    x = df.sort_values("open_time").copy()
    close = x["close"].astype(float)
    volume = x["volume"].astype(float)
    logc = np.log(close)
    x["r1"] = logc.diff(1)
    x["r5"] = logc.diff(5)
    x["r20"] = logc.diff(20)
    x["rv20"] = x["r1"].rolling(20, min_periods=20).std(ddof=0)
    vm = volume.rolling(20, min_periods=20).mean()
    vs = volume.rolling(20, min_periods=20).std(ddof=0).replace(0, np.nan)
    x["volume_z20"] = (volume - vm) / vs
    x["target_close"] = close.shift(-horizon_bars)
    x["target"] = (x["target_close"] > close).astype("float")
    x.loc[x["target_close"].isna(), "target"] = np.nan
    x["data_cutoff_at"] = x["open_time"]
    return x


def daily_strategy_scores(df: pd.DataFrame) -> pd.DataFrame:
    eps = 1e-9
    rv = df["rv20"].clip(lower=eps)
    out = pd.DataFrame(index=df.index)
    out["momentum5"] = df["r5"] / (rv * math.sqrt(5))
    out["momentum20"] = df["r20"] / (rv * math.sqrt(20))
    out["meanrev1"] = -df["r1"] / rv
    out["volume_breakout"] = (df["r5"] / (rv * math.sqrt(5))) * np.clip(df["volume_z20"], -3, 3) / 2.0
    return out.replace([np.inf, -np.inf], np.nan)


def run_daily_symbol(df: pd.DataFrame, symbol: str) -> dict:
    x = make_daily_features(df).dropna(subset=DAILY_FEATURES + ["target"]).copy()
    scores = daily_strategy_scores(x)
    raw = core.raw_probabilities(scores)
    cal_mask = (x.open_time >= CAL_START) & (x.open_time < CAL_END)
    test_mask = (x.open_time >= TEST_START) & (x.open_time < TEST_END)
    models = core.fit_platt(scores.loc[cal_mask], x.loc[cal_mask, "target"])
    cal = core.apply_platt(models, scores)
    weights = core.skill_weights(cal.loc[cal_mask], x.loc[cal_mask, "target"])
    calibrated_weighted = sum(cal[c] * weights[c] for c in cal.columns)
    majority = (raw >= 0.5).astype(float).mean(axis=1)
    equal_raw = raw.mean(axis=1)

    test_idx = x.index[test_mask]
    y = x.loc[test_idx, "target"].astype(int)
    variants = {
        "majority_vote": majority.loc[test_idx],
        "equal_weight_raw": equal_raw.loc[test_idx],
        "calibrated_weighted": calibrated_weighted.loc[test_idx],
    }
    metrics = [{"symbol": symbol, "variant": k, **core.metrics(y, p)} for k, p in variants.items()]
    bootstrap = moving_block_delta(
        y.to_numpy(),
        variants["calibrated_weighted"].to_numpy(),
        variants["equal_weight_raw"].to_numpy(),
        block=5,
        reps=2000,
        seed=29,
    )
    bootstrap.update({"symbol": symbol, "candidate": "calibrated_weighted", "baseline": "equal_weight_raw"})
    contracts = []
    for variant, p in variants.items():
        for idx in test_idx:
            contracts.append({
                "symbol": symbol,
                "market_class": "US_ETF",
                "frequency": "1d",
                "forecast_type": "EVENT_PROBABILITY",
                "variant": variant,
                "horizon_type": "bars",
                "horizon_bars": HORIZON_BARS,
                "issued_at": x.at[idx, "open_time"].isoformat(),
                "data_cutoff_at": x.at[idx, "data_cutoff_at"].isoformat(),
                "probability": float(p.loc[idx]),
                "resolved_target": int(x.at[idx, "target"]),
                "raw_immutable": True,
            })
    return {"metrics": metrics, "bootstrap": bootstrap, "weights": weights, "contracts": contracts}
