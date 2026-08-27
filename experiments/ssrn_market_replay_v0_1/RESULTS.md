# SSRN Market Replay v0.1 — Results

Status: E0–E5 CRYPTO REPLAY COMPLETE / NON-CRYPTO REPLICATION + LITERATURE STILL OPEN / NOT YET SSRN-READY

Run receipts:
- initial full snapshot + replay: https://github.com/saeedfaai/world-8/actions/runs/33075444264
- bootstrap replay: https://github.com/saeedfaai/world-8/actions/runs/33075751224
- E4/E5 extensions: https://github.com/saeedfaai/world-8/actions/runs/33076953897
- E4/E5 evidence commit: `e1ed508c92c64ccdc81a0e0fb5cebe726acf643e`

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
| ETHUSDT | Majority vote | 0.314399 | 1.921751 | 0.4871 | 0.2007 |
| ETHUSDT | Equal-weight raw | 0.264132 | 0.723072 | 0.4812 | 0.0943 |
| ETHUSDT | Calibrated weighted | 0.250563 | 0.694309 | 0.5245 | 0.0216 |
| SOLUSDT | Majority vote | 0.311749 | 1.870408 | 0.4875 | 0.1923 |
| SOLUSDT | Equal-weight raw | 0.262727 | 0.719936 | 0.4857 | 0.0902 |
| SOLUSDT | Calibrated weighted | 0.250645 | 0.694438 | 0.4966 | 0.0182 |

The calibrated weighted ensemble reduced Brier score relative to equal-weight raw aggregation by approximately 6.18% for BTC, 5.14% for ETH, and 4.60% for SOL. Relative to majority vote, the reductions were approximately 20.94%, 20.30%, and 19.60% respectively. ECE-10 fell substantially versus equal-weight raw aggregation.

## Paired moving-block bootstrap — calibration finding

Method: paired moving-block bootstrap, 24-hour blocks, 2,000 replicates, seed 7.

Calibrated weighted vs equal-weight raw Brier candidate-minus-baseline deltas:
- BTC: -0.016393; 95% CI [-0.021891, -0.011495]
- ETH: -0.013569; 95% CI [-0.020824, -0.005867]
- SOL: -0.012082; 95% CI [-0.016465, -0.007784]

This supports a robust calibration improvement in the frozen replay.

## Correlation-control ablation — retained negative result

The original correlation-control penalty does not show a useful improvement over calibrated weighting. BTC crosses zero; ETH and SOL are microscopically worse. The evidence therefore supports calibration but not the tested correlation-penalty rule.

## E4/E5 extensions

The E4/E5 extension run added three pre-specified policy ablations plus an independent Decision/UOP replay. Candidate-minus-baseline Brier < 0 means improvement relative to `calibrated_weighted`.

### Disagreement shrink

- BTC: +0.00036677; 95% CI [-0.00007715, +0.00081018] — no supported improvement.
- ETH: -0.00112116; 95% CI [-0.00261829, +0.00022292] — point estimate improves but CI crosses zero.
- SOL: -0.00027081; 95% CI [-0.00052638, -0.00001457] — small supported improvement under this replay.

Conclusion: disagreement-aware probability shrink is not consistently supported across assets. It shows a small robust gain only for SOL in this specification.

### Regime-weighted ensemble

Regime is determined only from information available at the forecast cutoff. The high/low-volatility boundary is the calibration-period median of `rv24`; separate ensemble weights are learned on calibration data only.

- BTC: +0.00034598; 95% CI [+0.00001231, +0.00069583] — significantly worse.
- ETH: -0.00008209; 95% CI [-0.00016257, -0.00000756] — small supported improvement.
- SOL: -0.00035000; 95% CI [-0.00093204, +0.00024572] — CI crosses zero.

Conclusion: this simple two-regime weighting rule is asset-dependent and does not justify a general superiority claim.

### Shadow cold-start

`volume_breakout` is held at zero ensemble weight for the first 720 out-of-sample hours, then admitted using its frozen calibrated weight.

- BTC: -0.00002876; 95% CI [-0.00006899, +0.00000255]
- ETH: +0.00001107; 95% CI [-0.00000054, +0.00002294]
- SOL: +0.00000475; 95% CI [-0.00002034, +0.00003700]

All CIs cross zero. This replay does not show a reliable predictive advantage or penalty from the tested 30-day shadow policy.

## Independent analyst-error correlation artifact

`results/analyst_error_correlation.csv` records the full 4 x 4 test-error correlation matrix for each symbol (48 rows total). This artifact is generated from immutable test forecasts and resolved targets rather than hand-entered values.

## Forecast Contract v2 evidence binding

`results/forecast_contracts_test_v2.jsonl.gz` now binds every extended forecast to:
- `feature_set_hash`;
- aggregate `strategy_set_hash` derived from per-strategy version hashes;
- `model_id`;
- `replay_code_hash`;
- `extension_code_hash`;
- `protocol_hash`;
- exact normalized snapshot SHA256.

The CI validates that all required hashes are 64-character SHA256 values before committing evidence.

## Decision/UOP + risk-veto replay — retained negative result

This is a historical decision-layer simulation, not live trading. The forecast probability is converted to long/short only when it exceeds a fixed ±0.05 edge around 0.5. A 10 bps round-trip cost is charged to non-flat decisions. The risk veto suppresses decisions when `rv24` exceeds the calibration-period 90th percentile.

| Symbol | Decisions no veto | Decisions with veto | Veto count | Mean net return no veto | Mean net return with veto |
|---|---:|---:|---:|---:|---:|
| BTCUSDT | 89 | 80 | 148 | +0.00004932 | +0.00002762 |
| ETHUSDT | 1,758 | 1,653 | 135 | -0.00037778 | -0.00040868 |
| SOLUSDT | 4 | 4 | 48 | +0.00000624 | +0.00000624 |

The tested volatility veto does **not** improve this decision metric: BTC worsens, ETH worsens, and SOL is unchanged. This negative result is retained. No profitability claim is supported by these replay values, especially because the simple strategy/decision specification is not a production trading model and overlapping 6h outcomes are not an executable portfolio simulation.

## Interpretation

Supported by the frozen crypto replay:
- separating immutable forecast outputs from evaluation permits clean deterministic replay and paired comparison;
- probability calibration materially improves these simple analyst outputs across all three tested crypto symbols;
- the calibration gains survive paired moving-block bootstrap;
- majority vote is a weak probability aggregator in this setup;
- disagreement shrink has one small asset-specific supported gain (SOL), not a general gain;
- simple two-regime weighting has one small supported gain (ETH) and a supported loss (BTC), so no general gain;
- the tested 30-day shadow cold-start is statistically neutral in this replay;
- the tested correlation penalty adds no useful predictive benefit;
- the tested volatility risk veto adds no decision-layer benefit.

Not supported:
- profitable trading;
- production readiness;
- superiority across markets, frequencies, assets, or regimes not tested here;
- general superiority of disagreement, regime, correlation-control, shadow, or risk-veto policies;
- autonomous market intelligence;
- causal claims about why calibration improved performance.

## Remaining SSRN gates

Before manuscript submission:
1. add at least one non-crypto / independent market-data replication if feasible;
2. verify related-work literature and citations;
3. optionally extend robustness to an additional horizon;
4. freeze final experiment commit and archive the evidence package;
5. render the English paper with AI disclosure and exact release/DOI binding;
6. run final author claim review.
