import sys
from pathlib import Path

import numpy as np
import pandas as pd

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from src.decision_uop import build_decision_frame, canonical_json_bytes, policy_returns, sha256_bytes
from src.robustness import moving_block_mean_delta


def synthetic(n=15000):
    t = pd.date_range("2024-01-01", periods=n, freq="h", tz="UTC")
    rng = np.random.default_rng(7)
    ret = rng.normal(0, 0.002, n)
    close = 100 * np.exp(np.cumsum(ret))
    market = pd.DataFrame({
        "open_time": t,
        "close_time": t + pd.Timedelta(hours=1) - pd.Timedelta(milliseconds=1),
        "close": close,
    })
    market["r1"] = np.log(market.close).diff()
    market["rv24"] = market.r1.rolling(24, min_periods=24).std(ddof=0)
    market["exit_close_6h"] = market.close.shift(-6)

    test = (market.open_time >= pd.Timestamp("2025-07-01", tz="UTC")) & (market.open_time < pd.Timestamp("2026-01-01", tz="UTC"))
    f = market.loc[test, ["close_time"]].copy()
    f["symbol"] = "TEST"
    f["issued_at"] = f.close_time
    f["data_cutoff_at"] = f.close_time
    f["probability"] = 0.5 + 0.1 * np.sin(np.arange(len(f)) / 20)
    f["forecast_ref_sha256"] = [sha256_bytes(canonical_json_bytes({"i": int(i)})) for i in range(len(f))]
    return market, f


def test_decision_cadence_is_non_overlapping_and_forecast_immutable():
    market, forecasts = synthetic()
    before = forecasts[["probability", "forecast_ref_sha256"]].copy(deep=True)
    d, _ = build_decision_frame(forecasts, market)
    hours = d.open_time.diff().dropna() / pd.Timedelta(hours=1)
    assert (hours == 6).all()
    pd.testing.assert_frame_equal(before, forecasts[["probability", "forecast_ref_sha256"]])


def test_risk_veto_only_removes_long_actions():
    market, forecasts = synthetic()
    d, _ = build_decision_frame(forecasts, market)
    assert ((d.action_with_veto == "LONG") <= (d.action_pre_veto == "LONG")).all()
    assert ((d.risk_veto) <= (d.action_pre_veto == "LONG")).all()


def test_cost_is_monotone_for_long_decisions():
    market, forecasts = synthetic()
    d, _ = build_decision_frame(forecasts, market)
    long5, r5 = policy_returns(d, "decision_no_veto", 5)
    long20, r20 = policy_returns(d, "decision_no_veto", 20)
    assert np.array_equal(long5, long20)
    assert np.all(r20[long5] < r5[long5])
    assert np.all(r20[~long5] == 0)


def test_always_long_has_all_eligible_decisions():
    market, forecasts = synthetic()
    d, _ = build_decision_frame(forecasts, market)
    mask, _ = policy_returns(d, "always_long_non_overlapping", 10)
    assert mask.all()


def test_return_bootstrap_identity():
    x = np.array([0.0, 0.01, -0.02, 0.005] * 100)
    r = moving_block_mean_delta(x, x, block_size=20, reps=200, seed=7)
    assert r["delta_candidate_minus_baseline_mean_return"] == 0.0
    assert r["ci95_low"] == 0.0
    assert r["ci95_high"] == 0.0
