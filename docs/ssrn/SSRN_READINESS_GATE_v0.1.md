# World 8 — SSRN Readiness Gate v0.1

Date: 2026-08-27
Status: ACTIVE / NOT SUBMITTED
Gate: EMPIRICAL EVIDENCE REQUIRED

## Why this gate exists

The current SSRN submission guidance requires a scholarly English full-text PDF, complete author metadata, an English abstract, and an AI disclosure when AI was used. SSRN also states that content types that are typically not accepted include framework-only submissions. Therefore World 8 must not submit a pure architecture description as if it were an empirical research paper.

Current SSRN guidance references:
- https://www.elsevier.support/ssrn/answer/get-started
- https://www.elsevier.support/ssrn/answer/what-is-needed-in-the-abstract-section-of-the-submission-form
- https://blog.ssrn.com/2026/07/20/ssrn-will-now-allow-you-to-choose-the-licence-thats-right-for-your-work/

## Exact publication binding

- Canonical repository: https://github.com/saeedfaai/world-8
- GitHub release: https://github.com/saeedfaai/world-8/releases/tag/V0.1.0
- Exact frozen commit: `b14f2feea0fa233851a774d6ebd295b63cde75c0`
- Zenodo record: https://zenodo.org/records/22127650
- DOI: https://doi.org/10.5281/zenodo.22127650
- Release classification: DEVELOPMENT PRE-RELEASE / NON-PRODUCTION

## Proposed scholarly paper

**Forecast, Decision, and Order as Separate Objects: A Contract-Based Evaluation Architecture for Multi-Agent Market Systems**

The paper should not argue that World 8 is already a profitable or production-ready trading system. It should test whether explicit separation of forecast, decision, and order objects produces more auditable and reproducible evaluation than conflated agent outputs, and whether calibration/correlation-aware ensemble rules outperform simpler aggregation baselines under a fixed replay protocol.

## Required technical spine

1. Forecast != Decision != Order.
2. Forecast Contract: target, horizon, issuance/data cutoff, lifecycle, type, immutable evidence references.
3. Market Data Node: normalization, cache/gap policy, source/time evidence.
4. Independent Evaluator / UOP: scoring and expected-value accounting outside the forecasting agent.
5. Risk / Portfolio veto outside Forecast Hall.
6. Weighted ensemble with calibration and correlation control; majority vote as a baseline, not the canonical rule.
7. Disagreement signal, independent regime detector, shadow cold-start.
8. Explicit evidence boundary and non-claims.

## Minimum empirical study before submission

### Dataset protocol
- use one or more liquid public market instruments;
- fixed historical date interval declared before evaluation;
- use 1h OHLCV as the first reproducible frequency;
- preserve raw source/time/snapshot evidence;
- enforce strict data cutoff to prevent look-ahead leakage;
- publish the exact train/calibration/test split and hashes.

### Forecast tasks
At minimum include:
- directional forecast;
- event-probability or threshold event forecast;
- optional volatility/relative-value task if evidence is sufficient.

### Baselines
- single-model/single-strategy baseline;
- simple majority-vote ensemble;
- uncalibrated weighted ensemble;
- calibrated weighted ensemble;
- calibrated + correlation-controlled ensemble.

### Ablations
Measure the effect of:
- calibration;
- correlation control;
- disagreement signal;
- regime detection;
- risk veto at decision layer;
- shadow cold-start policy.

### Metrics
Use metrics appropriate to forecast type, including where applicable:
- Brier score / calibration error for probabilistic events;
- log loss where probability support is valid;
- directional accuracy as a secondary descriptive metric;
- coverage by regime/horizon;
- correlation between analyst errors;
- transaction-cost-aware expected value only at the Decision/UOP layer;
- number of invalidated/expired/withdrawn forecasts and lifecycle integrity failures.

### Reproducibility requirements
- deterministic replay from an exact market-data snapshot;
- machine-readable Forecast Contracts;
- immutable raw forecasts;
- evaluator code separate from forecasting code;
- versioned strategy/model/feature identifiers;
- exact package hashes;
- no post-hoc deletion of failed forecasts;
- results table generated from machine-readable receipts.

## Submission gates

- [x] exact GitHub release frozen
- [x] dedicated Zenodo DOI published
- [x] author identity/affiliation available
- [x] AI disclosure requirement identified
- [x] non-production evidence boundary identified
- [x] SSRN current submission requirements checked on 2026-08-27
- [ ] empirical replay dataset frozen
- [ ] baseline implementations frozen
- [ ] World 8 forecast/ensemble variant implemented
- [ ] evaluator/UOP implementation frozen
- [ ] no-lookahead checks pass
- [ ] experiment run produces machine-readable results
- [ ] ablations complete
- [ ] statistical uncertainty / robustness analysis complete
- [ ] related-work references verified
- [ ] English manuscript complete
- [ ] AI disclosure included in abstract and PDF
- [ ] author reviews/approves final claims
- [ ] full-text PDF rendered and visually verified
- [ ] SSRN submission created

## Evidence ceiling

Until the empirical gates above pass, the SSRN paper remains **DRAFT / NOT SUBMITTED** and may describe testable architecture and protocol, but MUST NOT claim superior predictive performance, trading profitability, production readiness, or validated autonomous-market intelligence.
