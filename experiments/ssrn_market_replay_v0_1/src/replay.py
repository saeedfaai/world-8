from __future__ import annotations
import math
import numpy as np
import pandas as pd
from sklearn.linear_model import LogisticRegression

FEATURES = ["r1", "r6", "r24", "rv24", "volume_z24"]
STRATEGIES = ["momentum6", "momentum24", "meanrev1", "volume_breakout"]
VARIANTS = [
    "single_momentum6",
    "majority_vote",
    "equal_weight_raw",
    "calibrated_weighted",
    "calibrated_corr_controlled",
]


def normalize_epoch(values: pd.Series) -> pd.Series:
    v = pd.to_numeric(values, errors="raise").astype("int64")
    med = int(v.dropna().abs().median())
    unit = "us" if med >= 10**15 else "ms"
    return pd.to_datetime(v, unit=unit, utc=True)


def make_features(df: pd.DataFrame, horizon_hours: int = 6) -> pd.DataFrame:
    x = df.sort_values("open_time").copy()
    close = x["close"].astype(float)
    volume = x["volume"].astype(float)
    logc = np.log(close)
    x["r1"] = logc.diff(1)
    x["r6"] = logc.diff(6)
    x["r24"] = logc.diff(24)
    x["rv24"] = x["r1"].rolling(24, min_periods=24).std(ddof=0)
    vm = volume.rolling(24, min_periods=24).mean()
    vs = volume.rolling(24, min_periods=24).std(ddof=0).replace(0, np.nan)
    x["volume_z24"] = (volume - vm) / vs
    x["target_close"] = close.shift(-horizon_hours)
    x["target"] = (x["target_close"] > close).astype("float")
    x.loc[x["target_close"].isna(), "target"] = np.nan
    x["data_cutoff_at"] = x["close_time"]
    x["valid_from"] = x["close_time"]
    return x


def _sigmoid(z):
    z = np.clip(np.asarray(z, dtype=float), -10.0, 10.0)
    return 1.0 / (1.0 + np.exp(-z))


def strategy_scores(df: pd.DataFrame) -> pd.DataFrame:
    eps = 1e-9
    rv = df["rv24"].clip(lower=eps)
    out = pd.DataFrame(index=df.index)
    out["momentum6"] = df["r6"] / (rv * math.sqrt(6))
    out["momentum24"] = df["r24"] / (rv * math.sqrt(24))
    out["meanrev1"] = -df["r1"] / rv
    out["volume_breakout"] = (
        df["r6"] / (rv * math.sqrt(6))
    ) * np.clip(df["volume_z24"], -3, 3) / 2.0
    return out.replace([np.inf, -np.inf], np.nan)


def raw_probabilities(scores: pd.DataFrame) -> pd.DataFrame:
    return pd.DataFrame({c: _sigmoid(scores[c]) for c in scores.columns}, index=scores.index)


def fit_platt(scores: pd.DataFrame, y: pd.Series):
    models = {}
    for c in scores.columns:
        mask = scores[c].notna() & y.notna()
        m = LogisticRegression(C=1e6, solver="lbfgs", random_state=0, max_iter=1000)
        m.fit(scores.loc[mask, [c]].values, y.loc[mask].astype(int).values)
        models[c] = m
    return models


def apply_platt(models, scores: pd.DataFrame) -> pd.DataFrame:
    out = pd.DataFrame(index=scores.index)
    for c, model in models.items():
        mask = scores[c].notna()
        out[c] = np.nan
        if mask.any():
            out.loc[mask, c] = model.predict_proba(scores.loc[mask, [c]].values)[:, 1]
    return out


def brier(y, p) -> float:
    y = np.asarray(y, float)
    p = np.asarray(p, float)
    return float(np.mean((p - y) ** 2))


def skill_weights(cal_p: pd.DataFrame, y: pd.Series):
    skills = {}
    for c in cal_p.columns:
        mask = cal_p[c].notna() & y.notna()
        bs = brier(y[mask], cal_p.loc[mask, c])
        skills[c] = max(1e-6, 0.25 - bs)
    total = sum(skills.values())
    return {c: v / total for c, v in skills.items()} if total > 0 else {c: 1 / len(skills) for c in skills}


def correlation_controlled_weights(cal_p: pd.DataFrame, y: pd.Series, base_weights):
    err = cal_p.subtract(y, axis=0).dropna()
    corr = err.corr().abs()
    adjusted = {}
    for c, w in base_weights.items():
        others = [x for x in corr.columns if x != c]
        penalty = 1.0 + (float(corr.loc[c, others].mean()) if others else 0.0)
        adjusted[c] = w / penalty
    total = sum(adjusted.values())
    return {c: v / total for c, v in adjusted.items()}


def combine(raw_p, cal_p, w, wc):
    out = pd.DataFrame(index=raw_p.index)
    out["single_momentum6"] = raw_p["momentum6"]
    out["majority_vote"] = (raw_p >= 0.5).astype(float).mean(axis=1)
    out["equal_weight_raw"] = raw_p.mean(axis=1)
    out["calibrated_weighted"] = sum(cal_p[c] * w[c] for c in cal_p.columns)
    out["calibrated_corr_controlled"] = sum(cal_p[c] * wc[c] for c in cal_p.columns)
    return out


def ece(y, p, bins=10) -> float:
    y = np.asarray(y, float)
    p = np.asarray(p, float)
    edges = np.linspace(0, 1, bins + 1)
    total = 0.0
    for i in range(bins):
        lo, hi = edges[i], edges[i + 1]
        mask = (p >= lo) & ((p < hi) if i < bins - 1 else (p <= hi))
        if mask.any():
            total += mask.mean() * abs(p[mask].mean() - y[mask].mean())
    return float(total)


def metrics(y, p):
    y = np.asarray(y, int)
    p = np.clip(np.asarray(p, float), 1e-12, 1 - 1e-12)
    return {
        "n": int(len(y)),
        "brier": brier(y, p),
        "log_loss": float(-np.mean(y * np.log(p) + (1 - y) * np.log(1 - p))),
        "accuracy": float(np.mean((p >= 0.5) == y)),
        "ece10": ece(y, p, 10),
    }


def run_symbol(df: pd.DataFrame, symbol: str):
    x = make_features(df).dropna(subset=FEATURES + ["target"]).copy()
    scores = strategy_scores(x)
    raw = raw_probabilities(scores)
    calib_mask = (x.open_time >= pd.Timestamp("2025-01-01", tz="UTC")) & (x.open_time < pd.Timestamp("2025-07-01", tz="UTC"))
    test_mask = (x.open_time >= pd.Timestamp("2025-07-01", tz="UTC")) & (x.open_time < pd.Timestamp("2026-01-01", tz="UTC"))
    models = fit_platt(scores.loc[calib_mask], x.loc[calib_mask, "target"])
    cal = apply_platt(models, scores)
    w = skill_weights(cal.loc[calib_mask], x.loc[calib_mask, "target"])
    wc = correlation_controlled_weights(cal.loc[calib_mask], x.loc[calib_mask, "target"], w)
    combos = combine(raw, cal, w, wc)
    results = []
    contracts = []
    for variant in VARIANTS:
        mask = test_mask & combos[variant].notna()
        results.append({"symbol": symbol, "variant": variant, **metrics(x.loc[mask, "target"], combos.loc[mask, variant])})
        for idx in x.index[mask]:
            contracts.append({
                "symbol": symbol,
                "forecast_type": "EVENT_PROBABILITY",
                "variant": variant,
                "horizon_hours": 6,
                "issued_at": x.at[idx, "close_time"].isoformat(),
                "data_cutoff_at": x.at[idx, "data_cutoff_at"].isoformat(),
                "valid_from": x.at[idx, "valid_from"].isoformat(),
                "probability": float(combos.at[idx, variant]),
                "resolved_target": int(x.at[idx, "target"]),
                "raw_immutable": True,
            })
    return pd.DataFrame(results), w, wc, contracts
