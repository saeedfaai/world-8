# World 8 — SSRN Phase 2

Priority: P2
Status: ACTIVE / EMPIRICAL EVIDENCE GATE / NOT SUBMITTED
Last requirements check: 2026-08-27

## Current decision

Do **not** submit World 8 as a framework-only paper. Current SSRN guidance requires a scholarly English full-text PDF and states that framework-only content is typically not accepted. The World 8 paper will therefore be held until a reproducible empirical market-replay study produces original results.

Readiness gate:
`docs/ssrn/SSRN_READINESS_GATE_v0.1.md`

Submission metadata draft:
`docs/ssrn/SSRN_SUBMISSION_METADATA_v0.1.yaml`

## Working paper scope
A World 8 technical Working Paper centered on forecasting, trading, market-data, risk, and decision architecture, tested through deterministic historical replay rather than presented as a purely conceptual architecture.

Proposed title:
**Forecast, Decision, and Order as Separate Objects: A Contract-Based Evaluation Architecture for Multi-Agent Market Systems**

## Required technical spine
- Forecast != Decision != Order
- Forecast Contract lifecycle and evidence
- Market Data Node / normalization / gap filling / policy gate
- independent Evaluator and UOP / expected-value accounting
- Risk / Portfolio veto outside Forecast Hall
- weighted ensemble, calibration, correlation control, disagreement signal
- regime detector and shadow cold-start
- reproducibility, evidence boundary, failure modes
- explicit baselines and ablation study
- strict no-lookahead replay protocol

## Publication binding
The SSRN paper is bound to:
- GitHub release: https://github.com/saeedfaai/world-8/releases/tag/V0.1.0
- exact frozen commit: `b14f2feea0fa233851a774d6ebd295b63cde75c0`
- Zenodo record: https://zenodo.org/records/22127650
- DOI: https://doi.org/10.5281/zenodo.22127650
- canonical repository: https://github.com/saeedfaai/world-8

SSRN is a distribution/publication surface, not canonical source of truth.

## Current SSRN submission requirements captured
- free SSRN user account with complete author profile;
- paper title in English;
- date written;
- English abstract;
- complete author names, current affiliations, and valid emails;
- English full-text PDF showing title/authors/affiliations;
- AI disclosure in the submission abstract and PDF when AI was used;
- copyright permission where applicable;
- scholarly content with rigorous methodology/original findings;
- license selection is now available in the web submission flow.

Current requirement sources:
- https://www.elsevier.support/ssrn/answer/get-started
- https://www.elsevier.support/ssrn/answer/what-is-needed-in-the-abstract-section-of-the-submission-form
- https://blog.ssrn.com/2026/07/20/ssrn-will-now-allow-you-to-choose-the-licence-thats-right-for-your-work/

## Evidence boundary
No superior forecasting, profitability, production-readiness, or autonomous-market-intelligence claim is allowed until the empirical, robustness, and reproducibility gates pass.
