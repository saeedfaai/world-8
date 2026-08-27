import numpy as np
import pandas as pd

from src.extensions import (
    analyst_error_correlation,
    disagreement_shrink,
    shadow_cold_start,
    stable_json_hash,
    weighted_disagreement,
)


def test_disagreement_shrink_moves_probability_toward_half():
    base = pd.Series([0.9, 0.1, 0.7])
    d = pd.Series([1.0, 1.0, 0.0])
    out = disagreement_shrink(base, d, 1.0)
    assert 0.5 < out.iloc[0] < 0.9
    assert 0.1 < out.iloc[1] < 0.5
    assert out.iloc[2] == base.iloc[2]


def test_weighted_disagreement_zero_when_analysts_agree():
    f = pd.DataFrame({"a": [0.7, 0.2], "b": [0.7, 0.2]})
    d = weighted_disagreement(f, {"a": 0.4, "b": 0.6})
    assert np.allclose(d.to_numpy(), 0.0)


def test_shadow_cold_start_excludes_new_strategy_during_shadow_window():
    p = pd.DataFrame({
        "a": [0.8, 0.8, 0.8],
        "volume_breakout": [0.2, 0.2, 0.2],
    })
    out = shadow_cold_start(p, {"a": 0.5, "volume_breakout": 0.5}, shadow_hours=2)
    assert np.isclose(out.iloc[0], 0.8)
    assert np.isclose(out.iloc[1], 0.8)
    assert np.isclose(out.iloc[2], 0.5)


def test_analyst_error_correlation_is_explicit_matrix():
    p = pd.DataFrame({"a": [0.1, 0.9, 0.2, 0.8], "b": [0.2, 0.8, 0.3, 0.7]})
    y = pd.Series([0, 1, 0, 1])
    rows = analyst_error_correlation(p, y, "test", "BTCUSDT")
    assert len(rows) == 4
    assert {r["analyst_a"] for r in rows} == {"a", "b"}
    assert all(r["symbol"] == "BTCUSDT" for r in rows)


def test_hashes_are_deterministic_sha256():
    a = stable_json_hash({"b": 2, "a": 1})
    b = stable_json_hash({"a": 1, "b": 2})
    assert a == b
    assert len(a) == 64
