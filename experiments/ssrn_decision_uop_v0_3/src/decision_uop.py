from __future__ import annotations
import gzip
import hashlib
import json
from pathlib import Path

import numpy as np
import pandas as pd

CANONICAL_DECIMALS = 12


def canonicalize(value):
    if isinstance(value, (float, np.floating)):
        return round(float(value), CANONICAL_DECIMALS)
    if isinstance(value, (int, np.integer)):
        return int(value)
    if isinstance(value, dict):
        return {k: canonicalize(v) for k, v in value.items()}
    if isinstance(value, list):
        return [canonicalize(v) for v in value]
    return value


def canonical_json_bytes(obj) -> bytes:
    return (json.dumps(canonicalize(obj), sort_keys=True, separators=(",", ":")) + "\n").encode("utf-8")


def sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def sha256_file(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def load_forecast_contracts(path: Path, variant: str = "calibrated_weighted") -> pd.DataFrame:
    rows = []
    with gzip.open(path, "rt", encoding="utf-8") as fh:
        for line in fh:
            r = json.loads(line)
            if r.get("variant") == variant:
                raw = canonical_json_bytes(r)
                r["forecast_ref_sha256"] = sha256_bytes(raw)
                rows.append(r)
    df = pd.DataFrame(rows)
    df["issued_at"] = pd.to_datetime(df["issued_at"], utc=True)
    df["data_cutoff_at"] = pd.to_datetime(df["data_cutoff_at"], utc=True)
    return df


def load_market(path: Path) -> pd.DataFrame:
    df = pd.read_csv(path, compression="gzip")
    df["open_time"] = pd.to_datetime(df["open_time_us"], unit="us", utc=True)
    df["close_time"] = pd.to_datetime(df["close_time_us"], unit="us", utc=True)
    close = pd.to_numeric(df["close"], errors="raise").astype(float)
    df["close"] = close
    df["r1"] = np.log(close).diff()
    df["rv24"] = df["r1"].rolling(24, min_periods=24).std(ddof=0)
    df["exit_close_6h"] = close.shift(-6)
    return df


def calibration_risk_threshold(market: pd.DataFrame, q: float = 0.90) -> float:
    mask = (market.open_time >= pd.Timestamp("2025-01-01", tz="UTC")) & (
        market.open_time < pd.Timestamp("2025-07-01", tz="UTC")
    )
    return float(market.loc[mask, "rv24"].quantile(q))


def build_decision_frame(
    forecasts: pd.DataFrame,
    market: pd.DataFrame,
    probability_threshold: float = 0.55,
    risk_quantile: float = 0.90,
) -> tuple[pd.DataFrame, dict]:
    risk_threshold = calibration_risk_threshold(market, risk_quantile)
    cols = ["open_time", "close_time", "close", "exit_close_6h", "rv24"]
    joined = forecasts.merge(market[cols], left_on="issued_at", right_on="close_time", how="inner", validate="one_to_one")
    joined = joined.sort_values("open_time").copy()
    # Non-overlapping 6h decision cadence, frozen by UTC open-hour modulo.
    joined = joined[joined.open_time.dt.hour % 6 == 0].copy()
    joined = joined[joined.exit_close_6h.notna()].copy()
    joined["action_pre_veto"] = np.where(joined.probability >= probability_threshold, "LONG", "FLAT")
    joined["risk_veto"] = (joined.action_pre_veto == "LONG") & (joined.rv24 > risk_threshold)
    joined["action_with_veto"] = np.where(joined.risk_veto, "FLAT", joined.action_pre_veto)
    joined["gross_long_return"] = joined.exit_close_6h / joined.close - 1.0
    config = {
        "probability_threshold": probability_threshold,
        "risk_quantile": risk_quantile,
        "risk_threshold_rv24": risk_threshold,
        "eligible_decisions": int(len(joined)),
    }
    return joined, canonicalize(config)


def max_drawdown(simple_returns: np.ndarray) -> float:
    wealth = np.cumprod(1.0 + np.asarray(simple_returns, float))
    if len(wealth) == 0:
        return 0.0
    peaks = np.maximum.accumulate(np.r_[1.0, wealth])[:-1]
    dd = wealth / peaks - 1.0
    return float(dd.min())


def policy_returns(df: pd.DataFrame, policy: str, cost_bps: float) -> tuple[np.ndarray, np.ndarray]:
    if policy == "decision_no_veto":
        long_mask = (df.action_pre_veto == "LONG").to_numpy()
    elif policy == "decision_with_volatility_veto":
        long_mask = (df.action_with_veto == "LONG").to_numpy()
    elif policy == "always_long_non_overlapping":
        long_mask = np.ones(len(df), dtype=bool)
    else:
        raise ValueError(policy)
    gross = np.where(long_mask, df.gross_long_return.to_numpy(float), 0.0)
    cost = cost_bps / 10000.0
    net = np.where(long_mask, gross - cost, 0.0)
    return long_mask, net


def evaluate_policy(df: pd.DataFrame, policy: str, cost_bps: float) -> dict:
    long_mask, net = policy_returns(df, policy, cost_bps)
    long_returns = net[long_mask]
    gross_long = df.gross_long_return.to_numpy(float)[long_mask]
    compounded = float(np.prod(1.0 + net) - 1.0)
    return canonicalize({
        "policy": policy,
        "cost_bps_round_trip": cost_bps,
        "eligible_decisions": len(df),
        "long_decisions": int(long_mask.sum()),
        "veto_count": int(df.risk_veto.sum()) if policy == "decision_with_volatility_veto" else 0,
        "hit_rate_on_long": float(np.mean(gross_long > 0)) if len(gross_long) else None,
        "mean_net_return_per_eligible_decision": float(np.mean(net)) if len(net) else 0.0,
        "mean_net_return_per_long_decision": float(np.mean(long_returns)) if len(long_returns) else None,
        "compounded_path_return": compounded,
        "max_drawdown": max_drawdown(net),
        "p05_net_return": float(np.quantile(net, 0.05)) if len(net) else 0.0,
        "p95_net_return": float(np.quantile(net, 0.95)) if len(net) else 0.0,
    })


def build_receipts(df: pd.DataFrame, symbol: str, protocol_sha256: str, cost_scenarios=(5, 10, 20)) -> list[dict]:
    receipts = []
    for _, r in df.iterrows():
        base = {
            "symbol": symbol,
            "forecast_ref_sha256": r.forecast_ref_sha256,
            "forecast_probability": float(r.probability),
            "forecast_issued_at": r.issued_at.isoformat(),
            "forecast_data_cutoff_at": r.data_cutoff_at.isoformat(),
            "decision_at": r.issued_at.isoformat(),
            "action_pre_veto": r.action_pre_veto,
            "risk_veto": bool(r.risk_veto),
            "action_with_veto": r.action_with_veto,
            "entry_close_assumption": float(r.close),
            "exit_close_6h_assumption": float(r.exit_close_6h),
            "gross_long_return": float(r.gross_long_return),
            "protocol_sha256": protocol_sha256,
            "live_order": False,
        }
        base = canonicalize(base)
        decision_id = sha256_bytes(canonical_json_bytes(base))
        for cost_bps in cost_scenarios:
            for policy in ("decision_no_veto", "decision_with_volatility_veto", "always_long_non_overlapping"):
                if policy == "decision_no_veto":
                    is_long = r.action_pre_veto == "LONG"
                elif policy == "decision_with_volatility_veto":
                    is_long = r.action_with_veto == "LONG"
                else:
                    is_long = True
                net = (float(r.gross_long_return) - cost_bps / 10000.0) if is_long else 0.0
                receipt = {
                    **base,
                    "decision_id": decision_id,
                    "policy": policy,
                    "cost_bps_round_trip": cost_bps,
                    "net_return": net,
                }
                receipts.append(canonicalize(receipt))
    return receipts
