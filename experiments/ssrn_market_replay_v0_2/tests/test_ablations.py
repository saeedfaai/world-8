import sys
from pathlib import Path

import numpy as np
import pandas as pd

EXPERIMENTS = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(EXPERIMENTS))

from ssrn_market_replay_v0_2.src.ablations import run_ablations


def synth(n=15000):
    t = pd.date_range("2024-01-01", periods=n, freq="h", tz="UTC")
    rng = np.random.default_rng(7)
    r = rng.normal(0, 0.002, n) + 0.0002 * np.sin(np.arange(n) / 100)
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


def test_ablation_smoke_and_shadow_identity():
    m, b, cfg = run_ablations(synth(), "TEST")
    assert set(m.variant) == {
        "calibrated_weighted",
        "disagreement_shrink",
        "regime_weighted",
        "shadow_zero_weight",
        "naive_immediate_shadow",
    }
    assert cfg["shadow_identity_max_abs"] == 0.0
    assert len(b) == 8
    assert (m.n > 100).all()


def test_regime_weights_are_normalized():
    _, _, cfg = run_ablations(synth(), "TEST")
    assert abs(sum(cfg["low_regime_weights"].values()) - 1.0) < 1e-9
    assert abs(sum(cfg["high_regime_weights"].values()) - 1.0) < 1e-9
    assert cfg["regime_threshold_rv24_median"] > 0


def test_disagreement_scale_is_calibration_derived_positive():
    _, _, cfg = run_ablations(synth(), "TEST")
    assert cfg["disagreement_scale_q75"] > 0
