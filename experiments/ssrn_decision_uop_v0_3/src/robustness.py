from __future__ import annotations
import numpy as np


def moving_block_mean_delta(candidate, baseline, block_size: int = 28, reps: int = 2000, seed: int = 7):
    """Paired moving-block bootstrap for mean return delta on 6h decisions.

    block_size=28 corresponds to one week of 6-hour decision observations.
    """
    c = np.asarray(candidate, float)
    b = np.asarray(baseline, float)
    if len(c) != len(b):
        raise ValueError("paired arrays must have equal length")
    d = c - b
    n = len(d)
    if n == 0:
        raise ValueError("empty paired arrays")
    rng = np.random.default_rng(seed)
    starts = np.arange(max(1, n - block_size + 1))
    blocks_needed = int(np.ceil(n / block_size))
    out = np.empty(reps, dtype=float)
    for r in range(reps):
        chosen = rng.choice(starts, size=blocks_needed, replace=True)
        idx = np.concatenate([np.arange(s, min(s + block_size, n)) for s in chosen])[:n]
        out[r] = float(d[idx].mean())
    lo, hi = np.quantile(out, [0.025, 0.975])
    return {
        "delta_candidate_minus_baseline_mean_return": float(d.mean()),
        "ci95_low": float(lo),
        "ci95_high": float(hi),
        "prob_candidate_higher_mean_return": float(np.mean(out > 0)),
        "block_size_decisions": int(block_size),
        "bootstrap_reps": int(reps),
        "n": int(n),
    }
