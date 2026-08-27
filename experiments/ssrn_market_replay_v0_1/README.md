# SSRN Market Replay Experiment v0.1

Status: E0 protocol frozen / historical replay only / no live trading.

This experiment provides the empirical gate for the World 8 SSRN working paper. It tests forecast evaluation architecture without authorizing orders or capital deployment.

## Frozen question
Does separating Forecast, Decision, and Order while evaluating forecasts through calibration- and correlation-aware ensemble rules improve auditability and out-of-sample forecast evaluation relative to simple aggregation baselines?

## Data
- Official Binance Public Data / Data Vision monthly Spot klines.
- BTCUSDT, ETHUSDT, SOLUSDT.
- 1h bars, 2024-01-01 through 2025-12-31 UTC.
- Every provider ZIP must pass its colocated `.CHECKSUM` before use.
- Normalizer handles the Binance Spot timestamp change from milliseconds to microseconds beginning 2025-01-01.

Provider documentation: https://github.com/binance/binance-public-data

## Forecast task
At the close of bar t, estimate P(close[t+6h] > close[t]). Features use only information available by the close of bar t. The target is held outside the feature path.

Analysts:
1. 6h momentum
2. 24h momentum
3. 1h mean reversion
4. volume-confirmed 6h breakout

Compared variants:
1. single momentum analyst
2. simple majority vote
3. equal-weight raw probabilities
4. calibrated skill-weighted ensemble
5. calibrated skill-weighted ensemble with error-correlation penalty

Calibration: 2025-01-01 through 2025-06-30.
Out-of-sample test: 2025-07-01 through 2025-12-31.

Primary metrics: Brier score, log loss, ECE-10. Accuracy is secondary.

## Reproducibility artifacts
Generated artifacts are kept under `data/frozen/` and `results/` on this experiment branch:
- deterministic normalized CSV.GZ snapshots;
- provider source URL + SHA256 manifest;
- dataset continuity/gap report;
- aggregate metric table;
- calibration and correlation-control weights;
- compressed machine-readable Forecast Contract outputs.

## Evidence boundary
No result from this experiment is a live-trading recommendation. Transaction-cost-aware EV, risk veto, portfolio decisions, and order execution belong to downstream Decision/UOP experiments and are not inferred from forecast accuracy alone.
