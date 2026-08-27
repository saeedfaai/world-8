from __future__ import annotations

import hashlib
import inspect
import json
from dataclasses import dataclass

import numpy as np
import pandas as pd

from src import replay as core


EXTENSION_VERSION = "WORLD8_SSRN_E4E5/1.0"
DISAGREEMENT_ALPHA = 0.50
SHADOW_HOURS = 30 * 24
DECISION_EDGE = 0.05
ROUND_TRIP_COST_BPS = 10.0
RISK_VETO_QUANTILE = 0.90


def sha256_text(text: str) -> str:
    return hashlib.sha256(text.encode("utf-8")).hexdigest()


def stable_json_hash(value) -> str:
    return sha256_text(json.dumps(value, sort_keys=True, separators=(",", ":"), default=str))


def version_receipt(protocol: dict, snapshot_sha256: str | None = None) -> dict:
    strategy_hashes = {
        name: sha256_text(name + "\n" + inspect.getsource(core.strategy_scores))
        for name in core.STRATEGIES
    }
    return {
        "extension_version": EXTENSION_VERSION,
        "feature_set_hash": stable_json_hash({"features": core.FEATURES, "source": inspect.getsource(core.make_features)}),
        "strategy_version_hashes": strategy_hashes,
        "replay_code_hash": sha256_text(inspect.getsource(core)),
        "extension_code_hash": sha256_text(inspect.getsource(inspect.getmodule(version_receipt))),
        "protocol_hash": stable_json_hash(protocol),
        "snapshot_sha256": snapshot_sha256,
        "model_id": "platt-logistic-regression-v1",
        "evaluator_id": "world8-independent-evaluator-v0.1",
    }


def weighted_mean(frame: pd.DataFrame, weights: dict[str, float]) -> pd.Series:
    cols = [c for c in frame.columns if c in weights]
    if not cols:
        raise ValueError("no weighted columns")
    denom = sum(float(weights[c]) for c in cols)
    return sum(frame[c] * float(weights[c]) for c in cols) / denom


def weighted_disagreement(frame: pd.DataFrame, weights: dict[str, float]) -> pd.Series:
    cols = [c for c in frame.columns if c in weights]
    w = np.asarray([weights[c] for c in cols], dtype=float)
    w = w / w.sum()
    arr = frame[cols].to_numpy(dtype=float)
    mu = np.nansum(arr * w, axis=1)
    var = np.nansum(((arr - mu[:, None]) ** 2) * w, axis=1)
    return pd.Series(np.sqrt(np.maximum(var, 0.0)), index=frame.index)


def disagreement_shrink(base_p: pd.Series, disagreement: pd.Series, calibration_scale: float) -> pd.Series:
    scale = max(float(calibration_scale), 1e-9)
    intensity = np.clip(disagreement.to_numpy(float) / scale, 0.0, 1.0)
    p = 0.5 + (base_p.to_numpy(float) - 0.5) * (1.0 - DISAGREEMENT_ALPHA * intensity)
    return pd.Series(np.clip(p, 1e-6, 1 - 1e-6), index=base_p.index)


def regime_weights(cal_p: pd.DataFrame, y: pd.Series, regime: pd.Series) -> dict[str, dict[str, float]]:
    out = {}
    for label in ("low_vol", "high_vol"):
        mask = (regime == label) & y.notna()
        out[label] = core.skill_weights(cal_p.loc[mask], y.loc[mask])
    return out


def apply_regime_weights(cal_p: pd.DataFrame, regime: pd.Series, weights_by_regime: dict) -> pd.Series:
    out = pd.Series(index=cal_p.index, dtype=float)
    for label, weights in weights_by_regime.items():
        mask = regime == label
        if mask.any():
            out.loc[mask] = weighted_mean(cal_p.loc[mask], weights)
    return out


def shadow_cold_start(cal_p: pd.DataFrame, base_weights: dict[str, float], shadow_strategy: str = "volume_breakout", shadow_hours: int = SHADOW_HOURS) -> pd.Series:
    if shadow_strategy not in base_weights:
        raise KeyError(shadow_strategy)
    live_weights = dict(base_weights)
    shadow_weights = {k: v for k, v in base_weights.items() if k != shadow_strategy}
    shadow_total = sum(shadow_weights.values())
    shadow_weights = {k: v / shadow_total for k, v in shadow_weights.items()}
    p = weighted_mean(cal_p, live_weights)
    n = min(int(shadow_hours), len(cal_p))
    if n:
        p.iloc[:n] = weighted_mean(cal_p.iloc[:n], shadow_weights)
    return p


def analyst_error_correlation(cal_p: pd.DataFrame, y: pd.Series, split: str, symbol: str) -> list[dict]:
    err = cal_p.subtract(y, axis=0).dropna()
    corr = err.corr()
    rows = []
    for a in corr.columns:
        for b in corr.columns:
            rows.append({"symbol": symbol, "split": split, "analyst_a": a, "analyst_b": b, "error_correlation": float(corr.loc[a, b])})
    return rows


def decision_uop(x: pd.DataFrame, p: pd.Series, calib_mask: pd.Series, test_mask: pd.Series) -> tuple[pd.DataFrame, dict]:
    rv_threshold = float(x.loc[calib_mask, "rv24"].quantile(RISK_VETO_QUANTILE))
    test = x.loc[test_mask].copy()
    probs = p.loc[test.index]
    side = np.where(probs >= 0.5 + DECISION_EDGE, 1, np.where(probs <= 0.5 - DECISION_EDGE, -1, 0))
    veto = test["rv24"].to_numpy(float) > rv_threshold
    realized_return = test["target_close"].to_numpy(float) / test["close"].to_numpy(float) - 1.0
    cost = ROUND_TRIP_COST_BPS / 10000.0
    gross_no_veto = side * realized_return
    net_no_veto = np.where(side != 0, gross_no_veto - cost, 0.0)
    side_veto = np.where(veto, 0, side)
    gross_veto = side_veto * realized_return
    net_veto = np.where(side_veto != 0, gross_veto - cost, 0.0)
    rows = pd.DataFrame({
        "open_time": test["open_time"].astype(str).to_numpy(),
        "probability": probs.to_numpy(float),
        "side_no_veto": side,
        "risk_veto": veto.astype(int),
        "side_with_veto": side_veto,
        "realized_6h_return": realized_return,
        "net_return_no_veto": net_no_veto,
        "net_return_with_veto": net_veto,
    })
    summary = {
        "risk_veto_quantile": RISK_VETO_QUANTILE,
        "rv24_threshold": rv_threshold,
        "decision_edge": DECISION_EDGE,
        "round_trip_cost_bps": ROUND_TRIP_COST_BPS,
        "n": int(len(rows)),
        "decisions_no_veto": int(np.count_nonzero(side)),
        "decisions_with_veto": int(np.count_nonzero(side_veto)),
        "veto_count": int(veto.sum()),
        "mean_net_return_no_veto": float(np.mean(net_no_veto)),
        "mean_net_return_with_veto": float(np.mean(net_veto)),
        "sum_net_return_no_veto": float(np.sum(net_no_veto)),
        "sum_net_return_with_veto": float(np.sum(net_veto)),
    }
    return rows, summary


def moving_block_delta(y: np.ndarray, candidate: np.ndarray, baseline: np.ndarray, *, block: int = 24, reps: int = 2000, seed: int = 19) -> dict:
    y = np.asarray(y, float)
    candidate = np.asarray(candidate, float)
    baseline = np.asarray(baseline, float)
    n = len(y)
    rng = np.random.default_rng(seed)
    loss_delta = (candidate - y) ** 2 - (baseline - y) ** 2
    observed = float(loss_delta.mean())
    starts = np.arange(max(1, n - block + 1))
    sims = np.empty(reps, dtype=float)
    blocks_needed = int(np.ceil(n / block))
    for r in range(reps):
        idx = []
        for s in rng.choice(starts, size=blocks_needed, replace=True):
            idx.extend(range(int(s), min(int(s) + block, n)))
        sims[r] = float(loss_delta[np.asarray(idx[:n], dtype=int)].mean())
    lo, hi = np.quantile(sims, [0.025, 0.975])
    return {"delta_brier": observed, "ci95_low": float(lo), "ci95_high": float(hi), "block_hours": block, "reps": reps, "seed": seed}


def extend_symbol(df: pd.DataFrame, symbol: str, protocol: dict, snapshot_sha256: str | None = None) -> dict:
    x = core.make_features(df).dropna(subset=core.FEATURES + ["target"]).copy()
    scores = core.strategy_scores(x)
    raw = core.raw_probabilities(scores)
    calib_mask = (x.open_time >= pd.Timestamp("2025-01-01", tz="UTC")) & (x.open_time < pd.Timestamp("2025-07-01", tz="UTC"))
    test_mask = (x.open_time >= pd.Timestamp("2025-07-01", tz="UTC")) & (x.open_time < pd.Timestamp("2026-01-01", tz="UTC"))

    models = core.fit_platt(scores.loc[calib_mask], x.loc[calib_mask, "target"])
    cal = core.apply_platt(models, scores)
    base_weights = core.skill_weights(cal.loc[calib_mask], x.loc[calib_mask, "target"])
    base_p = weighted_mean(cal, base_weights)

    cal_disagreement = weighted_disagreement(cal.loc[calib_mask], base_weights)
    disagreement_scale = float(cal_disagreement.quantile(0.90))
    disagreement = weighted_disagreement(cal, base_weights)
    p_disagreement = disagreement_shrink(base_p, disagreement, disagreement_scale)

    rv_threshold = float(x.loc[calib_mask, "rv24"].median())
    regime = pd.Series(np.where(x["rv24"] > rv_threshold, "high_vol", "low_vol"), index=x.index)
    rw = regime_weights(cal.loc[calib_mask], x.loc[calib_mask, "target"], regime.loc[calib_mask])
    p_regime = apply_regime_weights(cal, regime, rw)

    p_shadow = shadow_cold_start(cal.loc[test_mask], base_weights)

    test_index = x.index[test_mask]
    y_test = x.loc[test_index, "target"].astype(int)
    variants = {
        "calibrated_weighted": base_p.loc[test_index],
        "disagreement_shrink": p_disagreement.loc[test_index],
        "regime_weighted": p_regime.loc[test_index],
        "shadow_cold_start": p_shadow,
    }
    metric_rows = [{"symbol": symbol, "variant": name, **core.metrics(y_test, p)} for name, p in variants.items()]
    ablations = []
    for name in ("disagreement_shrink", "regime_weighted", "shadow_cold_start"):
        ablations.append({"symbol": symbol, "candidate": name, "baseline": "calibrated_weighted", **moving_block_delta(y_test.to_numpy(), variants[name].to_numpy(), variants["calibrated_weighted"].to_numpy())})

    corr_rows = analyst_error_correlation(cal.loc[test_index], y_test, "test", symbol)
    uop_rows, uop_summary = decision_uop(x, base_p, calib_mask, test_mask)
    uop_rows.insert(0, "symbol", symbol)

    receipt = version_receipt(protocol, snapshot_sha256)
    extended_contracts = []
    for variant, p in variants.items():
        for idx in test_index:
            extended_contracts.append({
                "symbol": symbol,
                "forecast_type": "EVENT_PROBABILITY",
                "variant": variant,
                "horizon_hours": 6,
                "issued_at": x.at[idx, "close_time"].isoformat(),
                "data_cutoff_at": x.at[idx, "data_cutoff_at"].isoformat(),
                "valid_from": x.at[idx, "valid_from"].isoformat(),
                "probability": float(p.loc[idx]),
                "resolved_target": int(x.at[idx, "target"]),
                "raw_immutable": True,
                "feature_set_hash": receipt["feature_set_hash"],
                "strategy_set_hash": stable_json_hash(receipt["strategy_version_hashes"]),
                "model_id": receipt["model_id"],
                "replay_code_hash": receipt["replay_code_hash"],
                "extension_code_hash": receipt["extension_code_hash"],
                "protocol_hash": receipt["protocol_hash"],
                "snapshot_sha256": receipt["snapshot_sha256"],
            })

    return {
        "metrics": metric_rows,
        "ablations": ablations,
        "error_correlations": corr_rows,
        "uop_rows": uop_rows,
        "uop_summary": {"symbol": symbol, **uop_summary},
        "contracts": extended_contracts,
        "version_receipt": receipt,
        "parameters": {
            "disagreement_alpha": DISAGREEMENT_ALPHA,
            "disagreement_scale_calibration_q90": disagreement_scale,
            "regime_rv24_calibration_median": rv_threshold,
            "shadow_hours": SHADOW_HOURS,
            "regime_weights": rw,
            "base_weights": base_weights,
        },
    }
