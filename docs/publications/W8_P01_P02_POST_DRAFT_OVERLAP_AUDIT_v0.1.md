# W8-P01 ↔ W8-P02 Post-Draft Overlap Audit v0.1

Date: 2026-08-27
Status: **PASS / DIRECT CANONICAL-SOURCE FALLBACK / AUTOMATED PRIVATE RUNNER UNAVAILABLE**

## Scope

W8-P01 manuscript reviewed:
`docs/publications/manuscript/W8_P01_MANUSCRIPT_JAAMAS_v0.3.md`

Observed blob SHA:
`5763d90f90078026a0f43bd0c2a1276724caddf6`

W8-P02 manuscript reviewed:
`docs/ssrn/manuscript/WORLD8_SSRN_WORKING_PAPER_v0.1.md`

Observed blob SHA:
`5eb898e0524e5637afafad6dcab143aae9fab661`

The ownership policy remains:
`docs/publications/W8_P01_P02_OVERLAP_AUDIT.md`

## Automated gate status

An executable post-draft audit was added:
`tools/publications/w8_p01_p02_overlap_audit.py`

Workflow:
`.github/workflows/w8-p01-p02-overlap-audit.yml`

Workflow run:
`33113620266`

The initial run and one explicit rerun both failed **before any workflow step was allocated** (`steps=null`). This matches the previously observed private GitHub-hosted runner/provider incident and is not evidence of manuscript overlap or script failure.

The script remains in the repository for later execution when a private runner is available. It checks long exact paragraph reuse, high-similarity long paragraphs, shared numeric table rows, and forbidden W8-P02 result markers.

## Direct canonical-source fallback review

Because the manuscript cannot be published merely to obtain a public runner, the two canonical source texts were reviewed directly through the authenticated repository connector.

### W8-P02-exclusive result leakage

No W8-P02-exclusive market result was found in W8-P01 v0.3.

Direct marker checks on W8-P01 returned no occurrence for, among others:
- `BTCUSDT`
- `ETHUSDT`
- `SOLUSDT`
- `SPY`
- `-0.016393`
- `-0.02385937`
- `52,920`
- `Brier`

The W8-P01 text explicitly states that predictive accuracy, calibration, market returns, risk-veto performance, and crypto/non-crypto forecasting results belong to W8-P02 and are not reused as W8-P01 primary evidence.

### Results-table ownership

W8-P02 Results tables contain market symbols, forecast variants and metrics such as Brier/log loss/accuracy/ECE, plus Decision/UOP and ETF replication numbers.

W8-P01 Results tables instead contain governance/conformance/fault-family outcomes such as Society invariant pass rates, hardened-vs-governed failure families, mutation/compound-fault results and AutoGen governance cases.

No W8-P02 primary Results row is reused in the directly reviewed W8-P01 tables.

### Primary Results narrative

W8-P02's primary empirical conclusion concerns calibrated probabilistic forecast aggregation under frozen historical replay and preserves negative market-policy ablations.

W8-P01's primary empirical conclusion concerns a bounded governance composition: logical Actor binding, effect-time authority, fencing, tamper-evident evidence, recovery gating, cross-Society conformance and external-runtime composability.

The reviewed Results/Discussion sections are materially distinct in research question, dataset/evidence source, metrics and interpretation.

### Conclusion ownership

W8-P02 concludes that calibration improves the tested frozen crypto ensemble while broader market ablations are mixed/negative and ETF replication is inconclusive.

W8-P01 concludes that stronger generic baselines erase several apparent mechanism advantages and that the remaining tested governance composition passes the frozen conformance/fault cases and composes over the pinned AutoGen runtime.

These are distinct primary conclusions.

### Permitted unavoidable overlap

The following may legitimately recur in bounded form and are not treated as duplicate Results:
- the system name `World 8`;
- the architectural background statement that Forecast/Decision/Order are separated;
- author/affiliation information;
- required AI-use disclosure themes;
- short statements that no live trading/production claim is made;
- a short cross-citation explaining that W8-P02 owns market evidence.

No full Results paragraph or Results table is intentionally copied between the papers.

## Gate result

- distinct primary research question: **PASS**
- distinct primary evidence: **PASS**
- W8-P02-exclusive numeric market-result leakage into W8-P01: **PASS / none observed**
- primary Results table reuse: **PASS / none observed**
- primary conclusion duplication: **PASS / materially distinct**
- bounded shared background only: **PASS**
- automated script execution: **OPEN due private-runner allocation incident, not content failure**

Overall publication-ethics gate: **PASS WITH EXECUTION LIMITATION**.

## Mandatory final check

Before provider submission, re-run the automated audit if a private runner becomes available and perform the publisher's own similarity/plagiarism screening. Any future W8-P01 manuscript revision that introduces W8-P02-exclusive market numbers, tables, Results prose or primary conclusions reopens this gate.
