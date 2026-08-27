# SSRN Market Replay v0.1 — Results

Status: EMPIRICAL + INDEPENDENT NON-CRYPTO REPLICATION COMPLETE / VERIFIED LITERATURE COMPLETE / MANUSCRIPT FREEZE NEXT

Run receipts:
- initial crypto snapshot + replay: https://github.com/saeedfaai/world-8/actions/runs/33075444264
- crypto bootstrap replay: https://github.com/saeedfaai/world-8/actions/runs/33075751224
- E4/E5 extensions: https://github.com/saeedfaai/world-8/actions/runs/33076953897
- independent non-crypto replication: https://github.com/saeedfaai/world-8/actions/runs/33077676106
- E4/E5 evidence commit: `e1ed508c92c64ccdc81a0e0fb5cebe726acf643e`
- non-crypto evidence commit: `8ef31c48244e87a6fa17d1c996573a877f642b65`

## Crypto data integrity

For BTCUSDT, ETHUSDT, and SOLUSDT, the frozen 1h snapshot contains exactly 17,544 rows per symbol covering 2024-01-01 through 2025-12-31 UTC. Each symbol is assembled from 24 monthly Binance Data Vision ZIP files. Every source ZIP passed its provider `.CHECKSUM`; normalized series have zero hourly discontinuities and zero row delta relative to the expected interval count.

## Crypto out-of-sample test

Test period: 2025-07-01 through 2025-12-31 UTC. Observations per symbol/variant: 4,410. Forecast event: `close[t+6h] > close[t]`.

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

The calibrated weighted ensemble reduced Brier score relative to equal-weight raw aggregation by approximately 6.18% for BTC, 5.14% for ETH, and 4.60% for SOL.

## Crypto paired moving-block bootstrap — primary calibration finding

24-hour blocks, 2,000 replicates, seed 7. Candidate-minus-baseline Brier deltas for calibrated weighted vs equal-weight raw:
- BTC: -0.016393; 95% CI [-0.021891, -0.011495]
- ETH: -0.013569; 95% CI [-0.020824, -0.005867]
- SOL: -0.012082; 95% CI [-0.016465, -0.007784]

This supports a robust calibration improvement in the frozen crypto replay.

## Correlation-control ablation — retained negative result

The tested correlation-control penalty does not show a useful improvement over calibrated weighting. BTC crosses zero; ETH and SOL are microscopically worse. No correlation-control superiority claim is supported.

## E4/E5 policy ablations

Candidate-minus-`calibrated_weighted` Brier < 0 means improvement.

### Disagreement shrink
- BTC: +0.00036677; 95% CI [-0.00007715, +0.00081018] — unsupported.
- ETH: -0.00112116; 95% CI [-0.00261829, +0.00022292] — unsupported.
- SOL: -0.00027081; 95% CI [-0.00052638, -0.00001457] — small supported improvement.

### Regime-weighted ensemble
- BTC: +0.00034598; 95% CI [+0.00001231, +0.00069583] — supported worsening.
- ETH: -0.00008209; 95% CI [-0.00016257, -0.00000756] — small supported improvement.
- SOL: -0.00035000; 95% CI [-0.00093204, +0.00024572] — unsupported.

### Shadow cold-start
- BTC: -0.00002876; 95% CI [-0.00006899, +0.00000255]
- ETH: +0.00001107; 95% CI [-0.00000054, +0.00002294]
- SOL: +0.00000475; 95% CI [-0.00002034, +0.00003700]

All shadow-policy CIs cross zero. The tested 30-day shadow policy is statistically neutral in this replay.

## Independent analyst-error correlation artifact

`results/analyst_error_correlation.csv` records the full 4 × 4 test-error correlation matrix for each crypto symbol (48 rows total), generated from machine-readable forecast/evaluation receipts.

## Forecast Contract v2 evidence binding

`results/forecast_contracts_test_v2.jsonl.gz` binds each extended forecast to `feature_set_hash`, aggregate `strategy_set_hash`, `model_id`, `replay_code_hash`, `extension_code_hash`, `protocol_hash`, and exact normalized snapshot SHA256. CI validates required hashes before committing evidence.

## Decision/UOP + risk-veto replay — retained negative result

Historical simulation only; no live trading. Fixed decision edge ±0.05 around 0.5, 10 bps round-trip cost, volatility veto above the calibration-period 90th percentile of `rv24`.

| Symbol | Decisions no veto | Decisions with veto | Veto count | Mean net return no veto | Mean net return with veto |
|---|---:|---:|---:|---:|---:|
| BTCUSDT | 89 | 80 | 148 | +0.00004932 | +0.00002762 |
| ETHUSDT | 1,758 | 1,653 | 135 | -0.00037778 | -0.00040868 |
| SOLUSDT | 4 | 4 | 48 | +0.00000624 | +0.00000624 |

The tested volatility veto does not improve the decision metric: BTC and ETH worsen; SOL is unchanged. No profitability claim is supported.

# Independent non-crypto replication

## Source and integrity

The first attempted independent source, Stooq, returned a JavaScript browser-verification page to GitHub-hosted CI rather than machine-readable CSV. The pipeline failed closed and no dataset was frozen from Stooq.

The replacement source was the no-key Yahoo Finance chart API. Probe run `33077473635` returned HTTP 200 JSON with the expected OHLCV schema for SPY, QQQ, and GLD. Each series contains 1,508 daily observations from 2020-01-02 through 2025-12-31.

Unlike Binance Data Vision, this endpoint does not provide provider-side checksum files. The replication therefore records both the exact HTTP response SHA256 and a deterministic normalized-gzip SHA256. This is a weaker provenance guarantee than the checksum-verified Binance source and is explicitly disclosed rather than treated as equivalent.

Normalized dataset hashes:
- SPY: `463ffaa6f9860fb499335cd7aa95d44d35914b20111e559b39cf99d9a9ae18f4`
- QQQ: `9ceb64581e590396056b0117d5a2c4c5056e42b76cee52f594cdf09119552ef9`
- GLD: `a48bd0b2d247219defa4dab5015a0936f588b1d7e561b76512b33e58231cc7c0`

The non-crypto pipeline includes a separate no-lookahead test and passed the full freeze/replay/evidence CI run `33077676106`.

## Protocol

Market class: US ETFs. Frequency: 1 trading day. Event: `close[t+5 trading bars] > close[t]`. Calibration: 2023-01-01 through 2024-12-31. Out-of-sample test: calendar year 2025. Test observations: 245 per symbol/variant.

## Non-crypto metrics

| Symbol | Variant | Brier | Log loss | Accuracy | ECE-10 |
|---|---|---:|---:|---:|---:|
| SPY | Majority vote | 0.309184 | 1.539661 | 0.5306 | 0.2571 |
| SPY | Equal-weight raw | 0.256552 | 0.707658 | 0.5265 | 0.1463 |
| SPY | Calibrated weighted | 0.232693 | 0.658135 | 0.6327 | 0.0024 |
| QQQ | Majority vote | 0.302806 | 1.937506 | 0.5837 | 0.2622 |
| QQQ | Equal-weight raw | 0.258656 | 0.712208 | 0.5143 | 0.1589 |
| QQQ | Calibrated weighted | 0.234116 | 0.661055 | 0.6245 | 0.0107 |
| GLD | Majority vote | 0.268622 | 1.658508 | 0.6327 | 0.1806 |
| GLD | Equal-weight raw | 0.238877 | 0.672285 | 0.5918 | 0.1387 |
| GLD | Calibrated weighted | 0.234576 | 0.662202 | 0.6939 | 0.1489 |

The calibrated weighted point estimate has lower Brier loss than equal-weight raw for all three ETFs.

## Non-crypto moving-block bootstrap

5-trading-bar blocks, 2,000 replicates, seed 29. Calibrated weighted minus equal-weight raw Brier:
- SPY: -0.02385937; 95% CI [-0.05628718, +0.00471344]
- QQQ: -0.02453994; 95% CI [-0.05929267, +0.00718939]
- GLD: -0.00430077; 95% CI [-0.02098326, +0.01395883]

All three point estimates are directionally consistent with the crypto calibration result, but every confidence interval crosses zero. Therefore the independent daily ETF replication is **directionally supportive but not statistically robust** under this limited 2025 test window. It must not be presented as proof of cross-market superiority.

# Overall interpretation

Supported by the current evidence:
- immutable Forecast Contracts plus separate evaluation enable deterministic, receipt-backed comparison;
- calibration materially and robustly improves the simple analyst ensemble in all three frozen crypto tests;
- the independent ETF replication has calibration-improvement point estimates in the same direction for SPY, QQQ, and GLD, but insufficient precision for a robust cross-market claim;
- majority vote is a weak probabilistic aggregator in these tested specifications;
- disagreement and regime policies are asset-dependent, not generally superior;
- shadow cold-start is neutral in the tested configuration;
- the tested error-correlation penalty is not useful;
- the tested volatility risk veto is not useful at the Decision/UOP layer.

Not supported:
- profitable trading;
- production readiness;
- universal or causal superiority of World 8;
- general superiority of disagreement, regime, correlation-control, shadow, or risk-veto rules;
- autonomous market intelligence;
- a statistically robust cross-market ETF replication claim.

# Remaining SSRN gates

1. [x] crypto empirical replay and no-lookahead controls
2. [x] calibration/correlation-control robustness
3. [x] disagreement/regime/shadow ablations
4. [x] Decision/UOP + risk-veto separation
5. [x] explicit analyst-error correlation artifact
6. [x] version/hash identifiers in Forecast Contract v2
7. [x] independent non-crypto replication
8. [x] verified related-work bibliography (`docs/ssrn/RELATED_WORK_VERIFIED_v0.1.md`)
9. [ ] freeze final experiment/manuscript evidence commit and package hashes
10. [ ] complete English manuscript with AI disclosure
11. [ ] render and visually verify final PDF
12. [ ] author claim review before SSRN submission
