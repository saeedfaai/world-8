# Forecast, Decision, and Order as Separate Objects: A Contract-Based Evaluation Architecture for Multi-Agent Market Systems

**Saeed Farrokhi**  
Mechanical Engineering, University of Tehran  
Saeed.farokhi@ut.ac.ir

**Working Paper — 27 August 2026**  
Status: DRAFT FOR AUTHOR CLAIM REVIEW / NOT SUBMITTED

Canonical software release: https://github.com/saeedfaai/world-8/releases/tag/V0.1.0  
Release commit: `b14f2feea0fa233851a774d6ebd295b63cde75c0`  
Zenodo software snapshot: https://doi.org/10.5281/zenodo.22127650  
Frozen empirical-evidence commit: `ba6250ae71255a5cc9d55e7d06dd8d37d305eff0`  
Evidence package SHA256: `c799a36db30973713fd0dcb3cc5a20caf57e1326ec4e222df769769ba3165f37`

## Abstract

Multi-agent market systems often collapse prediction, action selection, and execution into a single agent output, obscuring the provenance and independent evaluation of errors. This study evaluates a contract-based architecture in which **Forecast**, **Decision**, and **Order** are distinct objects with separate lifecycles and evidence boundaries. Forecasts are immutable probability-bearing objects bound to explicit targets, horizons, data cutoffs, strategy/model identifiers, and replay evidence; decision utility and execution are evaluated downstream.

The empirical study uses a frozen historical replay. The primary experiment contains hourly BTCUSDT, ETHUSDT, and SOLUSDT data from 2024–2025 with a six-hour event target and a 2025H2 out-of-sample test. Relative to equal-weight raw aggregation, calibrated weighting reduced Brier loss by 0.01639 for BTC, 0.01357 for ETH, and 0.01208 for SOL; paired 24-hour moving-block bootstrap 95% intervals were entirely below zero for all three comparisons. Additional ablations did **not** support general superiority for correlation penalties, disagreement shrinkage, regime-specific weighting, shadow cold-start, or a volatility-based decision veto; these negative findings are retained. An independent daily replication on SPY, QQQ, and GLD produced calibration-improvement point estimates in the same direction, but all 95% moving-block bootstrap intervals crossed zero.

The evidence supports explicit probabilistic calibration and receipt-backed forecast evaluation in the frozen replay. It does not support claims of trading profitability, production readiness, universal cross-market superiority, causal superiority of the architecture, or autonomous market intelligence.

**Keywords:** multi-agent systems; probabilistic forecasting; forecast evaluation; calibration; forecast combination; decision architecture; reproducibility; market data; AI agents.

## 1. Introduction

Forecasting systems increasingly combine multiple models, strategies, or agents. In many implementations, however, a model's prediction, an action recommendation, and an executable order are represented as one output. This creates a measurement problem. When a realized outcome is poor, it can become unclear whether the failure was a forecasting error, a decision-rule error, a risk-policy intervention, a transaction-cost effect, or an execution effect.

World 8 addresses this by making **Forecast ≠ Decision ≠ Order** an architectural invariant. A Forecast is a claim about a future target under an explicit information cutoff. A Decision consumes one or more forecasts together with costs, constraints, portfolio state, and policy. An Order is a downstream execution artifact. The separation is intended to make forecast quality measurable without retrospectively rewriting forecast objects to match later decisions.

This paper does not test whether World 8 is a profitable trading system. It asks a narrower question: can a contract-based separation of forecasts and downstream actions support reproducible probabilistic evaluation, and what do simple ensemble/calibration policies actually do under a fixed historical replay?

The study makes four bounded contributions:

1. It specifies a machine-readable Forecast Contract with immutable data-cutoff and version/hash evidence.
2. It evaluates simple aggregation and calibrated weighting under deterministic replay using proper probabilistic loss.
3. It retains negative ablation results for correlation control, disagreement, regime weighting, shadow cold-start, and a risk veto rather than reporting only favorable variants.
4. It provides an independent non-crypto replication to test whether the direction of the primary calibration result persists outside the original crypto setting.

## 2. Related Work

### 2.1 Proper probabilistic scoring

The primary outcome is an event probability, so the main evaluation metric is the Brier score introduced by Brier [1]. Proper scoring rules provide a principled basis for evaluating probabilistic forecasts independently of downstream decisions; Gneiting and Raftery [2] give a general treatment of strictly proper scoring rules, prediction, and estimation.

This distinction is important for the present architecture: the forecast should be evaluated for probabilistic quality before transaction costs, risk vetoes, or portfolio choices are introduced.

### 2.2 Probability calibration

Probability estimates produced by predictive systems need not be calibrated. Niculescu-Mizil and Caruana [3] evaluated probability-quality behavior and calibration methods for supervised classifiers. Guo et al. [4] later documented calibration problems in modern neural networks and showed that simple post-processing calibration can be effective.

World 8 does not claim novelty for calibration. Calibration is treated as a separately versioned component whose contribution must be measured against raw aggregation.

### 2.3 Forecast combination

Forecast combination has a long literature. Clemen's review [5] emphasized both the value of combining forecasts and the robustness of relatively simple combination methods. A recent review by Wang, Hyndman, Li, and Kang [6] surveys more than fifty years of forecast-combination research, including probabilistic combinations, weighting, correlation, and time-varying approaches.

Accordingly, majority vote in this study is only a simple baseline. It is not intended to represent the state of the forecast-combination literature.

### 2.4 Comparative predictive evaluation

Diebold and Mariano [7] established a framework for comparing predictive accuracy when forecast loss differences may be serially dependent. The present study reports paired moving-block bootstrap intervals rather than claiming a Diebold–Mariano significance test. The bootstrap is used because observations and forecast losses are temporally dependent and because the goal is a transparent finite-sample robustness check under a frozen replay.

## 3. Architecture and Evidence Model

### 3.1 Forecast object

For this study, a Forecast Contract contains at least:

- target object and forecast type;
- forecast horizon;
- `issued_at`;
- `data_cutoff_at`;
- validity timing;
- probability or other forecast payload;
- strategy/model identifiers;
- feature-set hash;
- code/protocol hashes;
- immutable source snapshot reference;
- resolved target after the horizon completes.

The data cutoff is part of the forecast evidence. The evaluator is not permitted to use future observations to create features or calibration parameters for a prior forecast.

### 3.2 Decision object

Decision is downstream from forecast. It may incorporate transaction costs, risk limits, portfolio state, and policy. In the Decision/UOP ablation in this paper, probability is converted to a simple long/short/flat decision only after forecast scoring has been completed.

### 3.3 Order object

Order is an execution artifact and is intentionally outside the empirical scope of this paper. No live trading or autonomous capital deployment is authorized or evaluated here.

### 3.4 Evidence receipts

Forecast Contract v2 binds test forecasts to SHA256 identifiers for the feature set, strategy set, replay code, extension code, experiment protocol, and exact normalized snapshot. The evidence pipeline generates result tables from machine-readable outputs rather than using hand-entered result values as the source of record.

## 4. Primary Crypto Experiment

### 4.1 Data

The primary replay uses Binance Data Vision Spot monthly kline archives for BTCUSDT, ETHUSDT, and SOLUSDT at one-hour frequency. The frozen interval is 2024-01-01 through 2025-12-31 UTC.

Each asset contains exactly 17,544 hourly observations assembled from 24 monthly ZIP archives. Every provider archive was verified against its published `.CHECKSUM`. The normalized datasets have zero hourly discontinuities and zero row difference relative to the expected interval count.

### 4.2 Target and splits

The event target is:

`close[t + 6 hours] > close[t]`.

The calibration period is 2025-01-01 through 2025-06-30. The out-of-sample test period is 2025-07-01 through 2025-12-31. After resolving the six-hour horizon, each symbol/variant has 4,410 test observations.

### 4.3 Analyst strategies

Four deterministic analyst scores are used:

- short-horizon momentum;
- longer-horizon momentum;
- mean reversion;
- volume-conditioned breakout.

They are intentionally simple. The objective is to test the evaluation architecture and aggregation/calibration layers rather than to optimize trading alpha.

### 4.4 Aggregation variants

The main variants are:

1. majority vote;
2. equal-weight raw probability aggregation;
3. calibrated weighted aggregation;
4. calibrated weighting with a tested error-correlation penalty.

Additional E4/E5 ablations test disagreement-aware shrinkage, regime-specific weighting, and a 30-day shadow cold-start policy.

### 4.5 Metrics and robustness

Primary metrics are Brier score, log loss, ECE-10, and descriptive directional accuracy. Brier and log loss are the principal probabilistic-quality metrics.

For paired comparisons, the study uses a moving-block bootstrap with 24-hour blocks and 2,000 replicates. The bootstrap operates on paired loss differences so the same resolved forecast times are compared for candidate and baseline.

## 5. Primary Results

### 5.1 Out-of-sample probabilistic results

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

Calibration reduces Brier loss relative to equal-weight raw aggregation for all three crypto assets.

### 5.2 Paired bootstrap result

Calibrated weighted minus equal-weight raw Brier loss:

- BTC: -0.016393; 95% CI [-0.021891, -0.011495]
- ETH: -0.013569; 95% CI [-0.020824, -0.005867]
- SOL: -0.012082; 95% CI [-0.016465, -0.007784]

All three confidence intervals are below zero in the frozen replay. This is the strongest positive finding in the study.

### 5.3 Correlation-control result

The tested error-correlation penalty does not produce a useful gain over calibrated weighting. BTC is statistically inconclusive, while ETH and SOL are microscopically worse under the tested rule. No general correlation-control benefit is claimed.

## 6. Policy Ablations and Negative Results

### 6.1 Disagreement shrinkage

Disagreement-aware shrinkage moves ensemble probabilities toward 0.5 as weighted analyst dispersion increases.

Relative to calibrated weighting:

- BTC Brier delta: +0.00036677; CI crosses zero.
- ETH: -0.00112116; CI crosses zero.
- SOL: -0.00027081; 95% CI [-0.00052638, -0.00001457].

Only SOL shows a small supported improvement. The method is not generally supported across the three assets.

### 6.2 Regime-specific weighting

The simple regime detector divides observations using calibration-period median 24-hour realized volatility and learns separate ensemble weights for low/high-volatility regimes.

- BTC: +0.00034598; 95% CI [+0.00001231, +0.00069583], a supported worsening.
- ETH: -0.00008209; 95% CI [-0.00016257, -0.00000756], a small supported improvement.
- SOL: -0.00035000; CI crosses zero.

The effect is asset dependent and does not support a general regime-weighting claim.

### 6.3 Shadow cold-start

The volume-breakout analyst receives zero ensemble weight during the first 720 out-of-sample hours and is then admitted with its frozen calibrated weight. All three candidate-minus-baseline bootstrap intervals cross zero. The tested shadow policy is neutral.

## 7. Decision/UOP and Risk Veto

To preserve Forecast ≠ Decision, forecast scoring is completed before a simple downstream decision simulation. A long/short action requires probability at least 0.05 away from 0.5; active decisions incur a fixed 10-basis-point round-trip cost. The tested risk veto suppresses decisions when 24-hour realized volatility exceeds the calibration-period 90th percentile.

| Symbol | Decisions no veto | Decisions with veto | Veto count | Mean net return no veto | Mean net return with veto |
|---|---:|---:|---:|---:|---:|
| BTCUSDT | 89 | 80 | 148 | +0.00004932 | +0.00002762 |
| ETHUSDT | 1,758 | 1,653 | 135 | -0.00037778 | -0.00040868 |
| SOLUSDT | 4 | 4 | 48 | +0.00000624 | +0.00000624 |

The veto does not improve this decision metric: BTC and ETH worsen and SOL is unchanged. These values are not a portfolio backtest and do not support a profitability claim. The exercise demonstrates why a risk-policy result should not be attributed to the underlying forecast object.

## 8. Independent Non-Crypto Replication

### 8.1 Data source and provenance

An initial Stooq source probe failed closed because the GitHub CI runner received a JavaScript browser-verification page instead of machine-readable CSV. No Stooq dataset was frozen.

The replacement source is the no-key Yahoo Finance chart API for SPY, QQQ, and GLD. Each normalized daily series contains 1,508 observations from 2020-01-02 through 2025-12-31. The endpoint does not provide provider-side checksum files equivalent to Binance Data Vision, so the pipeline preserves the exact source-response SHA256 and a deterministic normalized-gzip SHA256. This provenance is explicitly weaker than provider-checksum verification.

### 8.2 Replication protocol

Daily features are computed using only information available at the forecast cutoff. The event is `close[t+5 trading bars] > close[t]`. Calibration uses 2023–2024 and the out-of-sample test is calendar year 2025. A separate no-lookahead unit test is required by CI.

### 8.3 Replication results

| Symbol | Variant | Brier | Log loss | Accuracy | ECE-10 |
|---|---|---:|---:|---:|---:|
| SPY | Equal-weight raw | 0.256552 | 0.707658 | 0.5265 | 0.1463 |
| SPY | Calibrated weighted | 0.232693 | 0.658135 | 0.6327 | 0.0024 |
| QQQ | Equal-weight raw | 0.258656 | 0.712208 | 0.5143 | 0.1589 |
| QQQ | Calibrated weighted | 0.234116 | 0.661055 | 0.6245 | 0.0107 |
| GLD | Equal-weight raw | 0.238877 | 0.672285 | 0.5918 | 0.1387 |
| GLD | Calibrated weighted | 0.234576 | 0.662202 | 0.6939 | 0.1489 |

Calibrated weighting has a lower Brier point estimate for all three ETFs. However, with 245 test observations per asset, the paired five-trading-bar moving-block bootstrap intervals all cross zero:

- SPY delta -0.02385937; 95% CI [-0.05628718, +0.00471344]
- QQQ delta -0.02453994; 95% CI [-0.05929267, +0.00718939]
- GLD delta -0.00430077; 95% CI [-0.02098326, +0.01395883]

The replication is directionally consistent with the crypto result but statistically inconclusive. It therefore limits rather than expands the allowable generalization claim.

## 9. Reproducibility and Frozen Evidence

The empirical evidence is frozen independently of the evolving manuscript.

- evidence commit: `ba6250ae71255a5cc9d55e7d06dd8d37d305eff0`
- deterministic evidence archive: `world8-ssrn-evidence-v0.1.tar.gz`
- archive SHA256: `c799a36db30973713fd0dcb3cc5a20caf57e1326ec4e222df769769ba3165f37`
- release commit: `b14f2feea0fa233851a774d6ebd295b63cde75c0`
- software DOI: `10.5281/zenodo.22127650`

The frozen package contains protocol/environment files, source code, tests, frozen snapshots, result artifacts, Forecast Contracts, related-work verification, and the evidence report.

## 10. Discussion

The central empirical finding is modest but clear: probability calibration improves the simple analyst ensemble in the frozen crypto replay, while several intuitively attractive architectural policies do not produce consistent predictive gains. This is useful for two reasons.

First, it demonstrates the value of separating architectural necessity from empirical superiority. A regime detector, risk veto, or disagreement signal may be architecturally useful for governance or safety without improving Brier loss in a given forecast task. The Forecast/Decision separation permits such components to be tested in the layer where their effect actually occurs.

Second, negative ablations constrain the design. The present evidence does not justify adding correlation penalties, regime-specific weights, or volatility vetoes on the premise that they improve performance generally. They remain candidate policies requiring task-specific evidence.

The independent ETF replication adds an important limitation. The same direction of calibration improvement appears in SPY, QQQ, and GLD point estimates, but statistical uncertainty is large. The strongest claim therefore remains confined to the checksum-verified crypto replay.

## 11. Limitations

This study has several material limitations.

1. The analyst strategies are deliberately simple and are not optimized production predictors.
2. The primary empirical evidence covers only three crypto assets, one one-hour frequency, and one six-hour event definition.
3. The ETF replication uses daily data and a different five-bar horizon; it is a conceptual independent replication rather than an exact-frequency replication.
4. Yahoo chart data lacks provider checksum files; local source/normalized hashes improve traceability but do not provide the same source-integrity guarantee as Binance Data Vision checksums.
5. Bootstrap choices (block sizes and replicate counts) are fixed study decisions and do not exhaust all dependence assumptions.
6. The Decision/UOP experiment is not an executable portfolio backtest; overlapping horizons, liquidity, slippage, market impact, and execution constraints are not fully modeled.
7. No live trading, production security, load, chaos, distributed-atomicity, or autonomous-operation validation is included.

## 12. Conclusion

This paper evaluated a contract-based separation of Forecast, Decision, and Order under frozen historical replay. The evidence supports two narrow conclusions. First, immutable forecast evidence and an independent evaluator make probabilistic comparisons reproducible without contaminating them with downstream decision/execution effects. Second, calibrated weighted aggregation materially improves Brier loss in the three tested crypto assets under the frozen protocol.

The broader ablations are intentionally less favorable: correlation control, disagreement handling, regime weighting, shadow cold-start, and volatility risk veto do not show consistent general gains. Independent ETF results point in the same calibration direction but remain statistically inconclusive. These limitations are part of the result rather than exceptions to it.

World 8 v0.1.0 should therefore be interpreted as an evidence-bound development architecture and experimental protocol, not as a production trading system or a claim of autonomous market intelligence.

## AI-Assisted Work Disclosure

AI-assisted tools were used for structured drafting, language editing, software/documentation support, and consistency checking. The author reviewed the resulting material and remains responsible for the research design, claims, code, data choices, interpretation, and final manuscript.

## Data, Code, and Evidence Availability

Canonical repository: https://github.com/saeedfaai/world-8  
Software release: https://github.com/saeedfaai/world-8/releases/tag/V0.1.0  
Zenodo release DOI: https://doi.org/10.5281/zenodo.22127650  
Frozen empirical evidence commit: `ba6250ae71255a5cc9d55e7d06dd8d37d305eff0`  
Frozen evidence package SHA256: `c799a36db30973713fd0dcb3cc5a20caf57e1326ec4e222df769769ba3165f37`

## References

[1] Brier, G. W. (1950). Verification of forecasts expressed in terms of probability. *Monthly Weather Review, 78*(1), 1–3. https://doi.org/10.1175/1520-0493(1950)078%3C0001:VOFEIT%3E2.0.CO;2

[2] Gneiting, T., & Raftery, A. E. (2007). Strictly proper scoring rules, prediction, and estimation. *Journal of the American Statistical Association, 102*(477), 359–378. https://doi.org/10.1198/016214506000001437

[3] Niculescu-Mizil, A., & Caruana, R. (2005). Predicting good probabilities with supervised learning. In *Proceedings of the 22nd International Conference on Machine Learning*, 625–632. https://doi.org/10.1145/1102351.1102430

[4] Guo, C., Pleiss, G., Sun, Y., & Weinberger, K. Q. (2017). On calibration of modern neural networks. *Proceedings of the 34th International Conference on Machine Learning*, PMLR 70, 1321–1330. https://proceedings.mlr.press/v70/guo17a.html

[5] Clemen, R. T. (1989). Combining forecasts: A review and annotated bibliography. *International Journal of Forecasting, 5*(4), 559–583. https://doi.org/10.1016/0169-2070(89)90012-5

[6] Wang, X., Hyndman, R. J., Li, F., & Kang, Y. (2023). Forecast combinations: An over 50-year review. *International Journal of Forecasting, 39*(4), 1518–1547. https://doi.org/10.1016/j.ijforecast.2022.11.005

[7] Diebold, F. X., & Mariano, R. S. (1995). Comparing predictive accuracy. *Journal of Business & Economic Statistics, 13*(3), 253–263. https://doi.org/10.1080/07350015.1995.10524599
