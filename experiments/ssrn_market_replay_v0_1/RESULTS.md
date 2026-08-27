# SSRN Market Replay v0.1 — Results

Status: EMPIRICAL REPLAY COMPLETE / BOOTSTRAP COMPLETE / NOT YET SSRN-READY

Run receipts:
- initial full snapshot + replay: https://github.com/saeedfaai/world-8/actions/runs/33075444264
- bootstrap replay: https://github.com/saeedfaai/world-8/actions/runs/33075751224

## Data integrity

For BTCUSDT, ETHUSDT, and SOLUSDT, the frozen 1h snapshot contains exactly 17,544 rows per symbol covering 2024-01-01 through 2025-12-31 UTC. Each symbol is assembled from 24 monthly Binance Data Vision ZIP files. Every source ZIP passed its provider `.CHECKSUM` and the normalized time series has zero hourly discontinuities and zero row delta relative to the expected interval count.

## Out-of-sample test

Test period: 2025-07-01 through 2025-12-31 UTC.
Observations per symbol/variant after horizon resolution: 4,410.
Forecast event: `close[t+6h] > close[t]`.

| Symbol | Variant | Brier | Log loss | Accuracy | ECE-10 |
|---|---|---:|---:|---:|---:|
| BTCUSDT | Majority vote | 0.314796 | 1.871447 | 0.4882 | 0.2052 |
| BTCUSDT | Equal-weight raw | 0.265259 | 0.725453 | 0.4689 | 0.1062 |
| BTCUSDT | Calibrated weighted | 0.248866 | 0.690876 | 0.5363 | 0.0180 |
| BTCUSDT | Calibrated + correlation control | **0.248866** | **0.690876** | 0.5365 | 0.0182 |
| ETHUSDT | Majority vote | 0.314399 | 1.921751 | 0.4871 | 0.2007 |
| ETHUSDT | Equal-weight raw | 0.264132 | 0.723072 | 0.4812 | 0.0943 |
| ETHUSDT | Calibrated weighted | **0.250563** | **0.694309** | 0.5245 | **0.0216** |
| ETHUSDT | Calibrated + correlation control | 0.250563 | 0.694309 | 0.5245 | 0.0216 |
| SOLUSDT | Majority vote | 0.311749 | 1.870408 | 0.4875 | 0.1923 |
| SOLUSDT | Equal-weight raw | 0.262727 | 0.719936 | 0.4857 | 0.0902 |
| SOLUSDT | Calibrated weighted | **0.250645** | **0.694438** | 0.4966 | 0.0182 |
| SOLUSDT | Calibrated + correlation control | 0.250645 | 0.694438 | 0.4966 | **0.0182** |

The calibrated weighted ensemble reduced Brier score relative to equal-weight raw aggregation by approximately 6.18% for BTC, 5.14% for ETH, and 4.60% for SOL. Relative to majority vote, the reductions were approximately 20.94%, 20.30%, and 19.60% respectively. ECE-10 fell by roughly 77–83% versus equal-weight raw aggregation.

## Paired moving-block bootstrap

Method: paired moving-block bootstrap, 24-hour blocks, 2,000 replicates, seed 7.

### Calibrated weighted vs equal-weight raw
All Brier and log-loss 95% confidence intervals are below zero for candidate-minus-baseline loss, supporting a robust improvement in this fixed replay:

- BTC Brier delta: -0.016393; 95% CI [-0.021891, -0.011495]
- ETH Brier delta: -0.013569; 95% CI [-0.020824, -0.005867]
- SOL Brier delta: -0.012082; 95% CI [-0.016465, -0.007784]

The corresponding log-loss intervals are also entirely below zero.

### Calibrated weighted vs majority vote
All Brier and log-loss intervals are entirely below zero for all three symbols. This is a strong result for the tested replay, but log-loss comparisons to majority vote should be interpreted cautiously because the majority baseline can emit coarse extreme probabilities (including 0 or 1 before metric clipping).

### Correlation control ablation
Correlation control does **not** show a useful improvement over calibrated weighting in this experiment:

- BTC Brier delta: -1.25e-7; 95% CI crosses zero [-2.74e-7, +1.62e-8].
- ETH Brier delta: +9.74e-8; 95% CI entirely above zero [+1.07e-8, +1.87e-7].
- SOL Brier delta: +8.04e-8; 95% CI entirely above zero [+1.09e-8, +1.52e-7].

Therefore the current evidence supports **calibration**, but does not support a claim that this correlation-control weighting rule improves predictive quality. For ETH and SOL it is microscopically worse under the frozen replay.

## Interpretation

What is supported:
- separating immutable forecast outputs from evaluation permits clean replay and paired comparison;
- probability calibration materially improves these simple analyst outputs under the frozen test protocol;
- calibration gains are robust under 24-hour paired block bootstrap for all three tested symbols;
- majority vote is a weak probability aggregator in this setup;
- the tested correlation-control penalty adds no meaningful predictive benefit.

What is not supported:
- profitable trading;
- production readiness;
- superiority across markets, frequencies, assets, or regimes not tested here;
- superiority of correlation control as a general method;
- autonomous market intelligence;
- causal claims about why calibration improved performance.

## Remaining SSRN gates

Before manuscript submission:
1. add at least one non-crypto / independent market-data replication if feasible;
2. add regime and disagreement ablations;
3. add Decision/UOP and risk-veto experiment separately from forecast scoring;
4. verify related-work literature and citations;
5. produce a robustness section covering multiple horizons or assets;
6. freeze the final experiment commit and archive the evidence package;
7. render the English paper with AI disclosure and exact release/DOI binding.
