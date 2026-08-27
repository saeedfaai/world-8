# World 8 — SSRN Readiness Gate v0.1

Date: 2026-08-27
Status: FINAL CANDIDATE / AUTHOR CLAIM REVIEW / NOT SUBMITTED

## Submission principle

World 8 is not being submitted as a framework-only description. The paper is supported by frozen historical replay, explicit baselines, negative ablations, Decision/UOP separation, lifecycle-integrity receipts, an independent non-crypto replication, verified related work, and a visually verified full-text PDF. Submission is now blocked only by the author's final claim review and explicit approval.

## Exact publication binding

- Canonical repository: https://github.com/saeedfaai/world-8
- GitHub release: https://github.com/saeedfaai/world-8/releases/tag/V0.1.0
- Exact release commit: `b14f2feea0fa233851a774d6ebd295b63cde75c0`
- Zenodo record: https://zenodo.org/records/22127650
- DOI: https://doi.org/10.5281/zenodo.22127650
- Release classification: DEVELOPMENT PRE-RELEASE / NON-PRODUCTION

## Proposed paper

**Forecast, Decision, and Order as Separate Objects: A Contract-Based Evaluation Architecture for Multi-Agent Market Systems**

## Empirical evidence

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

## Reproducibility and lifecycle evidence

- deterministic crypto replay
- provider checksums for every Binance monthly ZIP
- normalized snapshot hashes
- machine-readable Forecast Contracts
- Forecast Contract v2 hash/version binding
- Forecast Contract v3 deterministic lifecycle projection
- lifecycle integrity: 52,920 RESOLVED / 0 invalidated / 0 expired / 0 withdrawn / 0 superseded / 0 integrity failures
- v3 projection changes no forecast probability or resolved target
- independent evaluator outputs
- analyst error-correlation matrices
- generated metrics/robustness tables
- separate Decision/UOP replay with explicit cost/veto parameters
- frozen non-crypto source/normalization hashes

Lifecycle validation run:
https://github.com/saeedfaai/world-8/actions/runs/33079452232

## Frozen evidence package

- evidence commit: `917dd82ed87a3470acfdb9175905ec7c8727c096`
- deterministic archive: `world8-ssrn-evidence-v0.1.tar.gz`
- archive SHA256: `100484ffba683111622377703e836728817fd6cbb45f53d62e45a5a3766ece70`
- freeze workflow: https://github.com/saeedfaai/world-8/actions/runs/33079638287
- classification: RESEARCH EVIDENCE / HISTORICAL REPLAY / NO LIVE TRADING

## Verified related work

`docs/ssrn/RELATED_WORK_VERIFIED_v0.1.md`

Coverage:
- proper probabilistic scoring
- probability calibration
- forecast combination
- comparative forecast evaluation

## Final manuscript candidate

Source:
`docs/ssrn/manuscript/WORLD8_SSRN_WORKING_PAPER_v0.1.md`

Receipt:
`docs/ssrn/manuscript/WORLD8_SSRN_WORKING_PAPER_v0.1_RECEIPT.md`

Drive archives:
- PDF: https://drive.google.com/file/d/15b2XrL8mqix6gBEnWXm6VTxtoCCgCi59/view
- DOCX: https://drive.google.com/file/d/1tNIMdqCBJ6a8dRDR60TkccWCoF-8G4MM/view

Final candidate hashes:
- PDF SHA256: `acee536968f1fb9e527469d2125600b03587ce2e5a211ffdfadb6fe85f24ba7a`
- DOCX SHA256: `8de4a3bc137882181add32cb3884dc355e4fe77ca5d680bb60ae20fb1aa57a18`
- Markdown SHA256: `7a1f11cd3ee75d2f974f41bac5341367408fede2f75e3bbf16642902393a6c19`
- PDF pages: 9
- visual QA: PASS, all pages inspected
- AI-assisted work disclosure: embedded in PDF

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
- [x] Forecast Contract v3 lifecycle-integrity evidence complete
- [x] independent non-crypto replication complete
- [x] related-work bibliography verified
- [x] final experiment evidence package frozen with package SHA256
- [x] English manuscript complete
- [x] AI disclosure embedded in manuscript/PDF
- [x] full-text PDF rendered and visually verified
- [ ] author reviews/approves final claims
- [ ] SSRN submission created

## Evidence ceiling

Allowed claims are limited to measured replay findings. The manuscript MUST NOT claim trading profitability, production readiness, universal cross-market superiority, causal superiority, AGI/autonomous intelligence, or general benefit from disagreement/regime/correlation/shadow/risk-veto mechanisms.
