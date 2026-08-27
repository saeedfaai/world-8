from __future__ import annotations
import math
import sys
from pathlib import Path

import numpy as np
import pandas as pd

EXPERIMENTS = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(EXPERIMENTS))

from ssrn_market_replay_v0_1.src.replay import (
    FEATURES,
    make_features,
    strategy_scores,
    raw_probabilities,
    fit_platt,
    apply_platt,
    skill_weights,
    metrics,
)
from ssrn_market_replay_v0_1.src.robustness import moving_block_bootstrap_delta

VARIANTS = [
    "calibrated_weighted",
    "disagreement_shrink",
    "regime_weighted",
    "shadow_zero_weight",
    "naive_immediate_shadow",
]


def _sigmoid(z):
    z = np.clip(np.asarray(z, dtype=float), -10.0, 10.0)
    return 1.0 / (1.0 + np.exp(-z))


def weighted(cal_p: pd.DataFrame, weights: dict[str, float]) -> pd.Series:
    return sum(cal_p[c] * weights[c] for c in cal_p.columns)


def run_ablations(df: pd.DataFrame, symbol: str):
    x = make_features(df).dropna(subset=FEATURES + ["target"]).copy()
    scores = strategy_scores(x)
    raw = raw_probabilities(scores)
    calib = (x.open_time >= pd.Timestamp("2025-01-01", tz="UTC")) & (x.open_time < pd.Timestamp("2025-07-01", tz="UTC"))
    test = (x.open_time >= pd.Timestamp("2025-07-01", tz="UTC")) & (x.open_time < pd.Timestamp("2026-01-01", tz="UTC"))

    models = fit_platt(scores.loc[calib], x.loc[calib, "target"])
    cal_p = apply_platt(models, scores)
    base_w = skill_weights(cal_p.loc[calib], x.loc[calib, "target"])
    base = weighted(cal_p, base_w)

    # Disagreement ablation: shrink the calibrated ensemble toward 0.5 as
    # contemporaneous analyst disagreement rises. Scale is frozen on calibration only.
    disagreement = cal_p.std(axis=1, ddof=0)
    disagreement_scale = max(1e-9, float(disagreement.loc[calib].quantile(0.75)))
    shrink = 1.0 / (1.0 + disagreement / disagreement_scale)
    disagreement_p = 0.5 + (base - 0.5) * shrink

    # Regime detector: threshold and regime-specific weights are fit only on calibration.
    regime_threshold = float(x.loc[calib, "rv24"].median())
    low_cal = calib & (x.rv24 <= regime_threshold)
    high_cal = calib & (x.rv24 > regime_threshold)
    low_w = skill_weights(cal_p.loc[low_cal], x.loc[low_cal, "target"])
    high_w = skill_weights(cal_p.loc[high_cal], x.loc[high_cal, "target"])
    low_p = weighted(cal_p, low_w)
    high_p = weighted(cal_p, high_w)
    regime_p = pd.Series(np.where(x.rv24 <= regime_threshold, low_p, high_p), index=x.index)

    # Shadow cold-start integrity test. The new analyst has no validated production weight.
    # Strict shadow policy must leave the canonical ensemble exactly unchanged.
    rv = x.rv24.clip(lower=1e-9)
    shadow_score = (x.r6 - 3.0 * x.r1) / (rv * math.sqrt(6))
    shadow_raw = pd.Series(_sigmoid(shadow_score), index=x.index)
    shadow_zero = base.copy()
    naive_shadow = 0.8 * base + 0.2 * shadow_raw

    probs = pd.DataFrame({
        "calibrated_weighted": base,
        "disagreement_shrink": disagreement_p,
        "regime_weighted": regime_p,
        "shadow_zero_weight": shadow_zero,
        "naive_immediate_shadow": naive_shadow,
    }, index=x.index)

    metric_rows = []
    for variant in VARIANTS:
        mask = test & probs[variant].notna()
        metric_rows.append({"symbol": symbol, "variant": variant, **metrics(x.loc[mask, "target"], probs.loc[mask, variant])})

    bootstrap_rows = []
    comparisons = [
        ("disagreement_shrink", "calibrated_weighted"),
        ("regime_weighted", "calibrated_weighted"),
        ("shadow_zero_weight", "calibrated_weighted"),
        ("naive_immediate_shadow", "calibrated_weighted"),
    ]
    for candidate, baseline in comparisons:
        mask = test & probs[candidate].notna() & probs[baseline].notna()
        for metric in ("brier", "log_loss"):
            r = moving_block_bootstrap_delta(
                x.loc[mask, "target"].to_numpy(),
                probs.loc[mask, candidate].to_numpy(),
                probs.loc[mask, baseline].to_numpy(),
                metric,
                block_size=24,
                reps=2000,
                seed=7,
            )
            bootstrap_rows.append({"symbol": symbol, "candidate": candidate, "baseline": baseline, **r})

    shadow_identity_max_abs = float((shadow_zero.loc[test] - base.loc[test]).abs().max())
    configuration = {
        "symbol": symbol,
        "base_weights": base_w,
        "disagreement_scale_q75": disagreement_scale,
        "regime_threshold_rv24_median": regime_threshold,
        "low_regime_weights": low_w,
        "high_regime_weights": high_w,
        "shadow_identity_max_abs": shadow_identity_max_abs,
    }
    return pd.DataFrame(metric_rows), pd.DataFrame(bootstrap_rows), configuration
