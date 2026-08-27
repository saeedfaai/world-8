import numpy as np
import pandas as pd

from src.noncrypto import DAILY_FEATURES, make_daily_features


def synthetic_daily(n=80):
    t = pd.date_range("2024-01-01", periods=n, freq="B", tz="UTC")
    close = 100 * np.exp(np.linspace(0, 0.2, n) + 0.01 * np.sin(np.arange(n)))
    return pd.DataFrame({
        "open_time": t,
        "open": close * 0.999,
        "high": close * 1.005,
        "low": close * 0.995,
        "close": close,
        "volume": 1_000_000 + np.arange(n) * 1000,
    })


def test_daily_features_do_not_use_future_prices():
    a = synthetic_daily()
    b = a.copy()
    cutoff = 50
    b.loc[cutoff + 1 :, "close"] *= 5.0
    fa = make_daily_features(a)
    fb = make_daily_features(b)
    for col in DAILY_FEATURES:
        xa = fa.loc[:cutoff, col].to_numpy(float)
        xb = fb.loc[:cutoff, col].to_numpy(float)
        assert np.allclose(xa, xb, equal_nan=True), col


def test_target_uses_future_bars_but_features_remain_at_cutoff():
    x = make_daily_features(synthetic_daily(), horizon_bars=5)
    i = 40
    assert x.loc[i, "data_cutoff_at"] == x.loc[i, "open_time"]
    assert np.isfinite(x.loc[i, "target_close"])
    assert set(x.loc[i, DAILY_FEATURES].index) == set(DAILY_FEATURES)
