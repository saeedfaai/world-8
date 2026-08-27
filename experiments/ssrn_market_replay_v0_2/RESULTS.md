# SSRN Market Replay v0.2 — Disagreement, Regime & Shadow Ablations

Status: ABLATIONS COMPLETE / EVIDENCE-BOUNDED / HISTORICAL REPLAY ONLY

Run receipt:
- https://github.com/saeedfaai/world-8/actions/runs/33076350858 — SUCCESS

Parent evidence:
- `../ssrn_market_replay_v0_1/`
- same checksum-frozen 2024–2025 Binance Spot 1h snapshot
- same 2025H1 calibration and 2025H2 out-of-sample test
- 4,410 resolved observations per symbol/variant

## Purpose

This extension tests three World 8 architecture rules without changing the frozen market dataset:

1. whether contemporaneous analyst disagreement should shrink forecast confidence;
2. whether a calibration-fitted volatility regime detector should use regime-specific analyst weights;
3. whether a newly introduced analyst should remain in Shadow with production weight zero until validated.

The canonical comparator is the v0.1 `calibrated_weighted` ensemble.

## Point estimates

| Symbol | Variant | Brier | Log loss | Accuracy | ECE-10 |
|---|---|---:|---:|---:|---:|
| BTCUSDT | calibrated weighted | 0.248866 | 0.690876 | 0.5363 | 0.0180 |
| BTCUSDT | disagreement shrink | 0.249360 | 0.691866 | 0.5363 | 0.0261 |
| BTCUSDT | regime weighted | 0.249212 | 0.691571 | 0.5184 | **0.0066** |
| BTCUSDT | shadow weight 0 | 0.248866 | 0.690876 | 0.5363 | 0.0180 |
| BTCUSDT | naive 20% shadow | 0.252222 | 0.697633 | 0.5000 | 0.0405 |
| ETHUSDT | calibrated weighted | 0.250563 | 0.694309 | 0.5245 | 0.0216 |
| ETHUSDT | disagreement shrink | **0.249411** | **0.691969** | 0.5245 | **0.0189** |
| ETHUSDT | regime weighted | 0.250481 | 0.694140 | **0.5247** | 0.0205 |
| ETHUSDT | shadow weight 0 | 0.250563 | 0.694309 | 0.5245 | 0.0216 |
| ETHUSDT | naive 20% shadow | 0.252737 | 0.698693 | 0.4900 | 0.0575 |
| SOLUSDT | calibrated weighted | 0.250645 | 0.694438 | 0.4966 | 0.0182 |
| SOLUSDT | disagreement shrink | **0.250261** | **0.693669** | 0.4966 | **0.0139** |
| SOLUSDT | regime weighted | 0.250295 | 0.693737 | **0.4980** | 0.0176 |
| SOLUSDT | shadow weight 0 | 0.250645 | 0.694438 | 0.4966 | 0.0182 |
| SOLUSDT | naive 20% shadow | 0.254188 | 0.701617 | 0.4900 | 0.0539 |

## Paired moving-block bootstrap

Method: 24-hour paired blocks, 2,000 replicates, seed 7. Reported delta is candidate loss minus canonical calibrated-weighted loss; negative is better.

### Disagreement shrink

- BTC Brier delta: `+0.0004934`, 95% CI `[-0.0000537, +0.0010826]` — no robust difference.
- ETH Brier delta: `-0.0011521`, 95% CI `[-0.0030135, +0.0006053]` — point improvement, not robust at 95%.
- SOL Brier delta: `-0.0003837`, 95% CI `[-0.0007813, -0.0000120]` — small robust improvement.

Conclusion: disagreement is potentially useful as a signal, but this fixed shrink rule is not a universal improvement. The architecture should preserve disagreement as an observable signal, not canonically force this exact probability transformation across regimes/assets.

### Volatility regime weighting

- BTC Brier delta: `+0.0003460`, 95% CI `[+0.0000149, +0.0006895]` — small robust worsening.
- ETH Brier delta: `-0.0000821`, 95% CI `[-0.0001610, -0.0000063]` — tiny robust improvement.
- SOL Brier delta: `-0.0003500`, 95% CI `[-0.0009048, +0.0002128]` — point improvement, not robust.

Conclusion: a simple median-`rv24` two-regime detector is asset-sensitive. It does not support a general claim that regime-specific weighting improves forecasts. Regime detection should remain independently testable and should require out-of-sample acceptance rather than automatic production activation.

### Shadow cold-start

The strict Shadow variant has production weight exactly zero. It is mathematically and empirically identical to the canonical ensemble for every tested observation:

- maximum absolute identity difference = `0.0` for every symbol;
- Brier delta = `0`; CI `[0,0]`;
- log-loss delta = `0`; CI `[0,0]`.

The deliberately naive alternative immediately mixes a new unvalidated raw analyst at 20% weight. It robustly worsens both Brier and log loss for all three symbols:

- BTC Brier delta: `+0.0033555`, 95% CI `[+0.0017363, +0.0050494]`.
- ETH Brier delta: `+0.0021740`, 95% CI `[+0.0001245, +0.0042375]`.
- SOL Brier delta: `+0.0035434`, 95% CI `[+0.0019940, +0.0051207]`.

This is evidence for the **safety/integrity property** of the World 8 Shadow cold-start rule: a new analyst can be evaluated without perturbing canonical production forecasts until an explicit promotion gate changes its weight from zero. It is not evidence that every future shadow analyst would be harmful; it shows why zero-weight isolation prevents unvalidated influence.

## Architecture consequences

Supported for the current architecture:
- keep Disagreement as a first-class observable signal;
- do not hard-code the tested disagreement-shrink transformation as universally beneficial;
- keep Regime Detector independent and require explicit validation before it changes ensemble weights;
- retain Shadow cold-start with canonical weight zero;
- require an explicit promotion gate before a new analyst can affect canonical ensemble output.

Not supported:
- universal superiority of disagreement shrink;
- universal superiority of regime-specific weighting;
- any claim that shadow analysts are intrinsically poor;
- live trading or profitability claims.

## Next evidence gate

The next independent experiment should move downstream from Forecast into Decision/UOP:
- keep the best accepted forecast object immutable;
- apply transaction-cost assumptions only in Decision/UOP;
- implement a separate risk veto;
- compare Decision with vs without risk veto under historical replay;
- do not convert this into live order authorization.
