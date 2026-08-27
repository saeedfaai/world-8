import numpy as np
import pandas as pd

from src.replay import FEATURES, make_features, normalize_epoch, run_symbol
from src.robustness import moving_block_bootstrap_delta


def synth(n=15000):
    t = pd.date_range("2024-01-01", periods=n, freq="h", tz="UTC")
    rng = np.random.default_rng(7)
    r = rng.normal(0, 0.002, n) + 0.0001 * np.sin(np.arange(n) / 50)
    close = 100 * np.exp(np.cumsum(r))
    return pd.DataFrame({
        "open_time": t,
        "close_time": t + pd.Timedelta(hours=1) - pd.Timedelta(milliseconds=1),
        "open": close,
        "high": close * 1.001,
        "low": close * 0.999,
        "close": close,
        "volume": rng.lognormal(5, 0.5, n),
    })


def test_timestamp_units():
    ms = pd.Series([1704067200000, 1704070800000])
    us = pd.Series([1735689600000000, 1735693200000000])
    assert normalize_epoch(ms).iloc[0].year == 2024
    assert normalize_epoch(us).iloc[0].year == 2025


def test_features_no_lookahead():
    d = synth(300)
    full = make_features(d)
    cut = make_features(d.iloc[:200])
    for c in FEATURES:
        a, b = full.loc[199, c], cut.loc[199, c]
        assert (pd.isna(a) and pd.isna(b)) or np.isclose(a, b, equal_nan=True)


def test_target_is_not_feature():
    assert "target" not in FEATURES
    assert "target_close" not in FEATURES


def test_replay_smoke():
    m, w, wc, contracts = run_symbol(synth(), "TEST")
    assert len(m) == 5
    assert abs(sum(w.values()) - 1) < 1e-9
    assert abs(sum(wc.values()) - 1) < 1e-9
    assert (m["n"] > 100).all()
    assert contracts
    assert all(c["raw_immutable"] for c in contracts[:100])
    assert all(c["data_cutoff_at"] == c["issued_at"] for c in contracts[:100])


def test_bootstrap_identical_forecasts_have_zero_delta():
    y = np.array([0, 1] * 100, dtype=int)
    p = np.array([0.4, 0.6] * 100, dtype=float)
    r = moving_block_bootstrap_delta(y, p, p, "brier", block_size=12, reps=200, seed=7)
    assert abs(r["delta_candidate_minus_baseline"]) < 1e-15
    assert abs(r["ci95_low"]) < 1e-15
    assert abs(r["ci95_high"]) < 1e-15


def test_bootstrap_detects_better_candidate():
    y = np.array([0, 1] * 200, dtype=int)
    candidate = np.array([0.2, 0.8] * 200, dtype=float)
    baseline = np.array([0.45, 0.55] * 200, dtype=float)
    r = moving_block_bootstrap_delta(y, candidate, baseline, "brier", block_size=24, reps=300, seed=7)
    assert r["delta_candidate_minus_baseline"] < 0
    assert r["ci95_high"] < 0
    assert r["prob_candidate_better"] == 1.0
