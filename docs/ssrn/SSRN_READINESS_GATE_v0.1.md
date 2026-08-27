# World 8 — SSRN Readiness Gate v0.1

Date: 2026-08-27
Status: READY FOR AUTHOR APPROVAL / NOT SUBMITTED

## Submission principle

World 8 is not being submitted as a framework-only description. The paper is supported by frozen historical replay, explicit baselines, negative ablations, Decision/UOP separation, lifecycle-integrity receipts, an independent non-crypto replication, verified related work, a claim-to-evidence audit, and a visually verified full-text PDF. Submission is blocked only by the author's final responsibility/approval, provider-side account authentication/metadata choices, and the final SSRN Submit action.

## Exact publication binding
- Canonical repository: https://github.com/saeedfaai/world-8
- GitHub release: https://github.com/saeedfaai/world-8/releases/tag/V0.1.0
- Exact release commit: `b14f2feea0fa233851a774d6ebd295b63cde75c0`
- Zenodo record: https://zenodo.org/records/22127650
- DOI: https://doi.org/10.5281/zenodo.22127650
- Release classification: DEVELOPMENT PRE-RELEASE / NON-PRODUCTION

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
- SPY, QQQ, GLD daily OHLCV, 2020–2025 source freeze; 2025 out-of-sample test
- independent no-lookahead test
- calibrated-weighted Brier point estimate improves vs equal-weight raw for all three ETFs
- all three 95% moving-block bootstrap CIs cross zero; replication is directional but not statistically robust
- Yahoo endpoint lacks provider-side checksum files; exact source-response and normalized hashes are preserved and limitation disclosed

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
- separate Decision/UOP replay
- frozen non-crypto source/normalization hashes

Lifecycle validation run:
https://github.com/saeedfaai/world-8/actions/runs/33079452232

## Frozen evidence package
- evidence commit: `917dd82ed87a3470acfdb9175905ec7c8727c096`
- deterministic archive: `world8-ssrn-evidence-v0.1.tar.gz`
- archive SHA256: `100484ffba683111622377703e836728817fd6cbb45f53d62e45a5a3766ece70`
- freeze workflow: https://github.com/saeedfaai/world-8/actions/runs/33079638287
- classification: RESEARCH EVIDENCE / HISTORICAL REPLAY / NO LIVE TRADING

## Final manuscript candidate
- source: `docs/ssrn/manuscript/WORLD8_SSRN_WORKING_PAPER_v0.1.md`
- receipt: `docs/ssrn/manuscript/WORLD8_SSRN_WORKING_PAPER_v0.1_RECEIPT.md`
- claim audit: `docs/ssrn/SSRN_CLAIM_AUDIT_v0.1.md` — PASS
- submission packet: `docs/ssrn/SSRN_SUBMISSION_PACKET_v0.1.md`
- provider preflight: `docs/ssrn/SSRN_PROVIDER_PREFLIGHT_v0.1.md`

Drive archives:
- PDF: https://drive.google.com/file/d/15b2XrL8mqix6gBEnWXm6VTxtoCCgCi59/view
- DOCX: https://drive.google.com/file/d/1tNIMdqCBJ6a8dRDR60TkccWCoF-8G4MM/view

Final canonical provider/download hashes:
- PDF SHA256: `9df120062da98c5ded5468745d290d8abcd2663abcc8f1569c3b3a4bda863ec7`
- DOCX SHA256: `345164e825abc887ae0e26de745c6705a512193e42ca25985871f46d94c69386`
- Markdown SHA256: `7a1f11cd3ee75d2f974f41bac5341367408fede2f75e3bbf16642902393a6c19`
- PDF bytes: `231243`
- DOCX bytes: `22730`
- PDF pages: 9
- PDF preflight: PASS
- visual QA: PASS, all 9 pages inspected after final re-render

The pre-provider QA render PDF and the provider/download PDF have different byte hashes because of PDF serialization/metadata, but a nine-page pixel comparison found `0` changed pages and `0` changed pixels. For SSRN upload verification, the provider/download hash above is canonical.

## Submission checklist
- [x] exact GitHub release frozen
- [x] dedicated Zenodo DOI published
- [x] author identity/affiliation available
- [x] AI disclosure requirement identified and embedded
- [x] non-production evidence boundary identified
- [x] SSRN requirements checked on 2026-08-27
- [x] empirical datasets/baselines/evaluator/ablations frozen
- [x] no-lookahead checks pass
- [x] lifecycle-integrity evidence complete
- [x] independent non-crypto replication complete
- [x] related-work bibliography verified
- [x] evidence package frozen with SHA256
- [x] English manuscript complete
- [x] full-text PDF visually verified
- [x] machine/receipt claim-to-evidence audit complete
- [x] SSRN form packet prepared
- [x] provider duplicate/account-recovery preflight completed
- [x] final rendered-file transport integrity rechecked and corrected
- [ ] author explicitly approves final claims and assumes submission responsibility
- [ ] SSRN account/profile authenticated/verified
- [ ] provider licence/taxonomy choices completed
- [ ] SSRN submission created

## Evidence ceiling
Allowed claims are limited to measured replay findings. The manuscript MUST NOT claim trading profitability, production readiness, universal cross-market superiority, causal superiority, AGI/autonomous intelligence, or general benefit from disagreement/regime/correlation/shadow/risk-veto mechanisms.
