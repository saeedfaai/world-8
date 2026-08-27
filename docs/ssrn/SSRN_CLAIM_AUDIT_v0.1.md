# World 8 — SSRN Claim Audit v0.1

Date: 2026-08-27
Status: MACHINE/RECEIPT AUDIT COMPLETE / AUTHOR APPROVAL OPEN
Manuscript: `docs/ssrn/manuscript/WORLD8_SSRN_WORKING_PAPER_v0.1.md`

## Binding

- Software release: https://github.com/saeedfaai/world-8/releases/tag/V0.1.0
- Release commit: `b14f2feea0fa233851a774d6ebd295b63cde75c0`
- Zenodo DOI: https://doi.org/10.5281/zenodo.22127650
- Frozen empirical evidence commit: `917dd82ed87a3470acfdb9175905ec7c8727c096`
- Frozen evidence package SHA256: `100484ffba683111622377703e836728817fd6cbb45f53d62e45a5a3766ece70`
- Lifecycle integrity: PASS — 52,920 RESOLVED / 0 integrity failures

## Claim ledger

| ID | Manuscript claim | Evidence | Audit |
|---|---|---|---|
| C01 | Forecast, Decision, and Order are represented as separate architectural objects in the study. | manuscript §3; release architecture; Forecast Contract receipts; Decision/UOP replay | PASS / architectural-study claim only |
| C02 | Primary replay uses BTCUSDT, ETHUSDT, SOLUSDT, 1h data, 2024-01-01 through 2025-12-31 UTC. | `data/frozen/snapshot_manifest.json`; `PROTOCOL.yaml` | PASS |
| C03 | Each primary symbol contains 17,544 hourly rows assembled from 24 monthly provider archives with zero discontinuity and provider checksum verification. | `data/frozen/snapshot_manifest.json` | PASS |
| C04 | Out-of-sample test has 4,410 resolved observations per symbol/variant. | `results/metrics.csv`; replay receipts | PASS |
| C05 | Calibrated weighted aggregation reduces Brier loss vs equal-weight raw for BTC, ETH, SOL. | `results/metrics.csv` | PASS |
| C06 | Crypto calibrated-vs-raw Brier deltas are BTC -0.016393, ETH -0.013569, SOL -0.012082 and all paired 95% moving-block bootstrap intervals are below zero. | `results/bootstrap_robustness.csv` | PASS |
| C07 | The tested error-correlation penalty does not show a useful general predictive gain. | correlation-control rows in bootstrap/metrics evidence | PASS / negative result retained |
| C08 | Disagreement shrink has a small supported gain only for SOL under this specification; no general gain. | `results/extended_ablation_bootstrap.csv` | PASS / bounded claim |
| C09 | Simple regime weighting improves ETH slightly, worsens BTC, and is inconclusive for SOL; no general gain. | `results/extended_ablation_bootstrap.csv` | PASS / mixed result retained |
| C10 | The tested 30-day shadow cold-start is statistically neutral. | `results/extended_ablation_bootstrap.csv` | PASS |
| C11 | The tested volatility risk veto does not improve the Decision/UOP metric. | `results/decision_uop_summary.csv` | PASS / negative result retained |
| C12 | Independent non-crypto replication uses SPY, QQQ, GLD daily data from 2020–2025 with 2025 out-of-sample evaluation. | `data/noncrypto_frozen/snapshot_manifest.json`; non-crypto protocol/results | PASS |
| C13 | SPY, QQQ, GLD calibrated-weighted Brier point estimates are lower than equal-weight raw, but all three 95% moving-block bootstrap intervals cross zero. | `results/noncrypto_metrics.csv`; `results/noncrypto_bootstrap.csv` | PASS / directional replication only |
| C14 | Yahoo source provenance is weaker than Binance checksum provenance because provider-side checksum files are unavailable for the used endpoint; local response/normalized hashes are preserved. | `data/noncrypto_frozen/snapshot_manifest.json` | PASS / limitation disclosed |
| C15 | Forecast Contract v3 lifecycle projection changes no forecast values/targets and contains 52,920 RESOLVED records with zero integrity failures. | `results/lifecycle_integrity.json`; run `33079452232` | PASS |
| C16 | No live trading or autonomous capital deployment occurred in the study. | experiment protocol; Decision/UOP replay classification; evidence freeze classification | PASS |
| C17 | The evidence does not support trading-profitability, production-readiness, universal cross-market superiority, causal architectural superiority, or autonomous-market-intelligence claims. | measured scope and retained negative/uncertain results | PASS / required evidence ceiling |

## Numerical guardrails

The following values are allowed to appear as primary positive results only with their stated scope:

- BTC calibrated-vs-raw Brier delta: `-0.016393`, 95% CI `[-0.021891, -0.011495]`
- ETH calibrated-vs-raw Brier delta: `-0.013569`, 95% CI `[-0.020824, -0.005867]`
- SOL calibrated-vs-raw Brier delta: `-0.012082`, 95% CI `[-0.016465, -0.007784]`

Non-crypto replication must remain qualified:

- SPY: `-0.02385937`, CI crosses zero
- QQQ: `-0.02453994`, CI crosses zero
- GLD: `-0.00430077`, CI crosses zero

## Prohibited claim transformations

The final SSRN submission MUST NOT transform the evidence into any of the following:

- “World 8 is profitable.”
- “World 8 beats markets.”
- “World 8 is production ready.”
- “Calibration is universally superior across markets.”
- “Correlation control improves performance.”
- “Regime detection improves performance generally.”
- “Risk veto improves returns.”
- “The architecture causally caused the measured calibration gains.”
- “The system demonstrates AGI, consciousness, autonomous intelligence, or autonomous economic agency.”

## AI disclosure audit

Current SSRN guidance checked 2026-08-27 requires AI disclosure when AI is used in manuscript preparation. The disclosure is present in the manuscript/PDF and attributes final responsibility to the author.

## PDF/form audit

- English full-text PDF: PASS
- title visible in PDF: PASS
- author visible in PDF: PASS
- affiliation visible in PDF: PASS
- AI disclosure visible in PDF: PASS
- PDF openable/not encrypted/not scanned: PASS
- 9-page visual QA: PASS
- abstract ready for copy/paste into SSRN form: PASS
- keywords ready: PASS
- author metadata ready: PASS

## Final state

Scientific/technical claim audit: **PASS**.

Remaining gate is intentionally human: the author must read/accept responsibility for these bounded claims and explicitly approve submission. Until that approval, status remains **NOT SUBMITTED**.
