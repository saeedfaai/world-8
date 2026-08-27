from __future__ import annotations
import numpy as np
import pandas as pd


def _loss(y, p, metric: str):
    y = np.asarray(y, float)
    p = np.clip(np.asarray(p, float), 1e-12, 1 - 1e-12)
    if metric == "brier":
        return (p - y) ** 2
    if metric == "log_loss":
        return -(y * np.log(p) + (1 - y) * np.log(1 - p))
    raise ValueError(metric)


def moving_block_bootstrap_delta(
    y,
    candidate_p,
    baseline_p,
    metric: str,
    block_size: int = 24,
    reps: int = 2000,
    seed: int = 7,
):
    y = np.asarray(y)
    c = np.asarray(candidate_p)
    b = np.asarray(baseline_p)
    if not (len(y) == len(c) == len(b)):
        raise ValueError("paired arrays must have identical length")
    diff = _loss(y, c, metric) - _loss(y, b, metric)
    n = len(diff)
    rng = np.random.default_rng(seed)
    starts = np.arange(max(1, n - block_size + 1))
    out = np.empty(reps, dtype=float)
    blocks_needed = int(np.ceil(n / block_size))
    for r in range(reps):
        chosen = rng.choice(starts, size=blocks_needed, replace=True)
        idx = np.concatenate([np.arange(s, min(s + block_size, n)) for s in chosen])[:n]
        out[r] = float(diff[idx].mean())
    point = float(diff.mean())
    lo, hi = np.quantile(out, [0.025, 0.975])
    return {
        "metric": metric,
        "delta_candidate_minus_baseline": point,
        "ci95_low": float(lo),
        "ci95_high": float(hi),
        "prob_candidate_better": float(np.mean(out < 0)),
        "block_size_hours": int(block_size),
        "bootstrap_reps": int(reps),
        "n": int(n),
    }


def robustness_from_contracts(contracts: list[dict]):
    df = pd.DataFrame(contracts)
    comparisons = [
        ("calibrated_weighted", "majority_vote"),
        ("calibrated_weighted", "equal_weight_raw"),
        ("calibrated_corr_controlled", "calibrated_weighted"),
    ]
    rows = []
    for symbol, g in df.groupby("symbol"):
        p = g.pivot(index="issued_at", columns="variant", values="probability")
        y = g.groupby("issued_at")["resolved_target"].first().reindex(p.index)
        for candidate, baseline in comparisons:
            mask = p[candidate].notna() & p[baseline].notna() & y.notna()
            for metric in ("brier", "log_loss"):
                r = moving_block_bootstrap_delta(
                    y[mask].to_numpy(),
                    p.loc[mask, candidate].to_numpy(),
                    p.loc[mask, baseline].to_numpy(),
                    metric,
                )
                rows.append({"symbol": symbol, "candidate": candidate, "baseline": baseline, **r})
    return rows
