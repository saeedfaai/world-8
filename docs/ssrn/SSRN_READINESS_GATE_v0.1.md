# World 8 — SSRN Readiness Gate v0.1

Date: 2026-08-27
Status: MANUSCRIPT PREPARATION / EMPIRICAL GATE PASSED / NOT SUBMITTED

## Submission principle

World 8 is not being submitted as a framework-only description. The paper is now supported by historical replay, explicit baselines, negative ablations, Decision/UOP separation, and an independent non-crypto replication. Submission remains blocked until the manuscript/PDF and author claim-review gates pass.

## Exact publication binding

- Canonical repository: https://github.com/saeedfaai/world-8
- GitHub release: https://github.com/saeedfaai/world-8/releases/tag/V0.1.0
- Exact release commit: `b14f2feea0fa233851a774d6ebd295b63cde75c0`
- Zenodo record: https://zenodo.org/records/22127650
- DOI: https://doi.org/10.5281/zenodo.22127650
- Release classification: DEVELOPMENT PRE-RELEASE / NON-PRODUCTION

## Proposed paper

**Forecast, Decision, and Order as Separate Objects: A Contract-Based Evaluation Architecture for Multi-Agent Market Systems**

## Empirical evidence now available

### Crypto replay
- BTCUSDT, ETHUSDT, SOLUSDT
- 1h OHLCV, 2024-01-01 through 2025-12-31 UTC
- checksum-verified Binance Data Vision monthly archives
- 4,410 out-of-sample forecasts per symbol/variant
- paired 24h moving-block bootstrap, 2,000 replicates
- calibrated weighting robustly improves Brier loss vs equal-weight raw for all three crypto symbols

### Negative/limiting findings retained
- tested correlation penalty: no useful predictive improvement
- disagreement shrink: supported small gain only for SOL
- simple regime weighting: small supported gain for ETH, supported worsening for BTC, inconclusive SOL
- 30-day shadow cold-start: neutral
- tested volatility risk veto: no Decision/UOP benefit

### Independent non-crypto replication
- SPY, QQQ, GLD
- daily OHLCV, Yahoo Finance chart API
- 2020–2025 source freeze; 2025 out-of-sample test
- independent no-lookahead test
- calibrated-weighted Brier point estimate improves vs equal-weight raw for all three ETFs
- all three 95% moving-block bootstrap CIs cross zero; replication is directional but not statistically robust
- provider does not publish checksum files for this endpoint; exact source-response SHA256 and deterministic normalized-gzip SHA256 are preserved and this provenance limitation is disclosed

## Reproducibility evidence

- deterministic crypto replay
- provider checksums for every Binance monthly ZIP
- normalized snapshot hashes
- machine-readable Forecast Contracts
- Forecast Contract v2 hash/version binding
- independent evaluator outputs
- analyst error-correlation matrices
- generated metrics/robustness tables
- separate Decision/UOP replay with explicit cost/veto parameters
- frozen non-crypto source/normalization hashes

## Verified related work

`docs/ssrn/RELATED_WORK_VERIFIED_v0.1.md`

Coverage:
- proper probabilistic scoring
- probability calibration
- forecast combination
- comparative forecast evaluation

## Submission checklist

- [x] exact GitHub release frozen
- [x] dedicated Zenodo DOI published
- [x] author identity/affiliation available
- [x] AI disclosure requirement identified
- [x] non-production evidence boundary identified
- [x] SSRN submission requirements checked on 2026-08-27
- [x] empirical replay dataset frozen
- [x] baseline implementations frozen
- [x] calibrated World 8 ensemble variant implemented
- [x] evaluator/UOP implementation frozen for the study
- [x] no-lookahead checks pass
- [x] experiment produces machine-readable results
- [x] calibration/correlation-control robustness analysis complete
- [x] disagreement/regime/shadow ablations complete
- [x] independent Decision/UOP + risk-veto study complete
- [x] analyst error-correlation artifact complete
- [x] Forecast Contract v2 version/hash evidence complete
- [x] independent non-crypto replication complete
- [x] related-work bibliography verified
- [ ] final experiment evidence package frozen with package SHA256
- [ ] English manuscript complete
- [ ] AI disclosure embedded in manuscript/PDF
- [ ] author reviews/approves final claims
- [ ] full-text PDF rendered and visually verified
- [ ] SSRN submission created

## Evidence ceiling

Allowed claims are limited to measured replay findings. The manuscript MUST NOT claim trading profitability, production readiness, universal cross-market superiority, causal superiority, AGI/autonomous intelligence, or general benefit from disagreement/regime/correlation/shadow/risk-veto mechanisms.
