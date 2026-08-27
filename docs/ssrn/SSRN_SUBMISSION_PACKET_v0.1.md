# World 8 — SSRN Submission Packet v0.1

Date prepared: 2026-08-27
Status: READY FOR AUTHOR APPROVAL / NOT SUBMITTED

This file is the copy/paste packet for the current SSRN web submission form. It is bound to the final candidate PDF and frozen empirical evidence. Do not edit claims in the web form beyond this packet without re-running the claim audit.

## Paper title

**Forecast, Decision, and Order as Separate Objects: A Contract-Based Evaluation Architecture for Multi-Agent Market Systems**

## Date written

27 August 2026

## Author

**Saeed Farrokhi**  
Affiliation: Mechanical Engineering, University of Tehran  
Email: Saeed.farokhi@ut.ac.ir

## Abstract

Multi-agent market systems often collapse prediction, action selection, and execution into a single agent output, obscuring the provenance and independent evaluation of errors. This study evaluates a contract-based architecture in which Forecast, Decision, and Order are distinct objects with separate lifecycles and evidence boundaries. Forecasts are immutable probability-bearing objects bound to explicit targets, horizons, data cutoffs, strategy/model identifiers, and replay evidence; decision utility and execution are evaluated downstream.

The empirical study uses a frozen historical replay. The primary experiment contains hourly BTCUSDT, ETHUSDT, and SOLUSDT data from 2024–2025 with a six-hour event target and a 2025H2 out-of-sample test. Relative to equal-weight raw aggregation, calibrated weighting reduced Brier loss by 0.01639 for BTC, 0.01357 for ETH, and 0.01208 for SOL; paired 24-hour moving-block bootstrap 95% intervals were entirely below zero for all three comparisons. Additional ablations did not support general superiority for correlation penalties, disagreement shrinkage, regime-specific weighting, shadow cold-start, or a volatility-based decision veto; these negative findings are retained. An independent daily replication on SPY, QQQ, and GLD produced calibration-improvement point estimates in the same direction, but all 95% moving-block bootstrap intervals crossed zero.

The evidence supports explicit probabilistic calibration and receipt-backed forecast evaluation in the frozen replay. It does not support claims of trading profitability, production readiness, universal cross-market superiority, causal superiority of the architecture, or autonomous market intelligence.

## Keywords

- multi-agent systems
- probabilistic forecasting
- forecast evaluation
- calibration
- forecast combination
- decision architecture
- reproducibility
- market data
- AI agents

## AI disclosure

AI-assisted tools were used for structured drafting, language editing, software/documentation support, literature discovery, and consistency checking. The author reviewed the resulting material and remains responsible for the research design, claims, code, data choices, interpretation, citations, and final manuscript.

## Full-text PDF

Drive final candidate:
https://drive.google.com/file/d/15b2XrL8mqix6gBEnWXm6VTxtoCCgCi59/view

File: `World8_SSRN_Working_Paper_v0.1.pdf`

PDF SHA256:
`acee536968f1fb9e527469d2125600b03587ce2e5a211ffdfadb6fe85f24ba7a`

Pages: 9

Preflight: OPENABLE / NOT ENCRYPTED / NOT SCANNED / VISUAL QA PASS

## Editable source

DOCX:
https://drive.google.com/file/d/1tNIMdqCBJ6a8dRDR60TkccWCoF-8G4MM/view

DOCX SHA256:
`8de4a3bc137882181add32cb3884dc355e4fe77ca5d680bb60ae20fb1aa57a18`

Canonical Markdown:
`docs/ssrn/manuscript/WORLD8_SSRN_WORKING_PAPER_v0.1.md`

## Research artifact binding

Canonical software repository:
https://github.com/saeedfaai/world-8

Software release:
https://github.com/saeedfaai/world-8/releases/tag/V0.1.0

Release commit:
`b14f2feea0fa233851a774d6ebd295b63cde75c0`

Zenodo software snapshot:
https://doi.org/10.5281/zenodo.22127650

Frozen empirical evidence commit:
`917dd82ed87a3470acfdb9175905ec7c8727c096`

Evidence package SHA256:
`100484ffba683111622377703e836728817fd6cbb45f53d62e45a5a3766ece70`

Lifecycle receipt:
52,920 RESOLVED / 0 integrity failures

## Claim audit

`docs/ssrn/SSRN_CLAIM_AUDIT_v0.1.md`

Status: PASS / AUTHOR APPROVAL OPEN

## Current SSRN submission requirements verified on 2026-08-27

Official SSRN/Elsevier guidance requires:
- a free SSRN account with complete author profile;
- English paper title;
- date written;
- English abstract;
- author names, current affiliations, and valid emails;
- English full-text PDF displaying title/authors/affiliations;
- AI disclosure when AI was used, included with the abstract and in the PDF;
- appropriate copyright permission where applicable.

Current guidance:
- https://www.elsevier.support/ssrn/answer/get-started
- https://www.elsevier.support/ssrn/answer/what-is-needed-in-the-abstract-section-of-the-submission-form
- https://www.elsevier.support/ssrn/answer/AI

SSRN entry point:
https://papers.ssrn.com/

## Do not submit until author approval

The final form must preserve the bounded evidence language. In particular, do not introduce claims of profitability, production readiness, universal superiority, causal superiority, or autonomous intelligence.
