# W8-P01 ↔ W8-P02 Overlap / Claim Ownership Audit

Date: 2026-08-27
Status: **PASS / PRE-MANUSCRIPT OWNERSHIP FROZEN**

## Purpose

Prevent duplicate publication, self-plagiarism by repeated Results/Discussion, and accidental expansion of the submitted W8-P02 market paper into the W8-P01 flagship architecture paper.

Binding sources:
- `docs/publications/WORLD8_PAPER_REGISTRY.yaml`
- `docs/ssrn/SSRN_CLAIM_AUDIT_v0.1.md`
- W8-P02 SSRN Abstract ID `7359740`
- W8-P01 E1–E4 receipts under `experiments/flagship_governance_v0_1/`

## Ownership rule

### W8-P02 exclusively owns detailed market-performance evidence

W8-P01 MUST NOT reproduce as primary Results, tables, figures, or novelty claims:
- BTCUSDT / ETHUSDT / SOLUSDT replay results;
- exact Brier/log-loss/ECE tables;
- calibrated-vs-raw bootstrap deltas or confidence intervals;
- disagreement/regime/shadow-cold-start predictive ablation tables;
- analyst-error correlation results;
- Decision/UOP risk-veto performance tables;
- SPY/QQQ/GLD replication metrics/intervals;
- Forecast Contract lifecycle count `52,920 RESOLVED / 0 integrity failures` as a flagship result;
- any profitability, market-superiority, or universal-calibration claim.

W8-P02 exact positive numeric results therefore remain outside W8-P01, including:
- BTC delta `-0.016393`;
- ETH delta `-0.013569`;
- SOL delta `-0.012082`;
- SPY/QQQ/GLD numeric replication deltas and intervals.

### W8-P01 exclusively owns flagship architecture/governance evidence

W8-P02 MUST NOT be expanded later to claim the following as its empirical contribution:
- hardened governance baseline comparison from W8-P01 E1;
- persistent Actor vs provider/session identity failure families;
- actor-bound authorization contribution;
- fencing/lease contribution;
- tamper-evident governance evidence contribution;
- Company/Trading shared-kernel two-Society conformance result;
- W8-P01 98,000-trial mechanism sweep;
- W8-P01 mutation score / compound-fault gate;
- canonical/runtime source-recovery and behavioral governance probes.

## Shared material allowed in both papers

Only bounded background/architecture cross-reference is allowed:
- World 8 is a governed multi-agent architecture;
- provider/session identity is distinct from persistent Actor identity;
- proposal/prediction, decision/approval, and effect/execution are separate governance stages;
- Trading Society may be named as one example Society;
- W8-P01 may cite W8-P02 as a separate domain-specific empirical evaluation;
- W8-P02 may cite W8-P01 later as the architecture paper if/when published.

Shared text should be freshly written for each paper and kept short. No copy/paste of full paragraphs from the other manuscript.

## Trading Society boundary inside W8-P01

Allowed:
`FORECAST != TRADE_DECISION != SYNTHETIC_ORDER`

Purpose:
Demonstrate that the same governance kernel applies to a materially different Society adapter.

Not allowed in W8-P01 Results:
- forecast predictive accuracy;
- calibration superiority;
- market-return interpretation;
- risk-veto performance;
- crypto/non-crypto comparison.

E2 explicitly records:
- `market_performance_evaluated=false`
- `live_effects=false`

## Primary research-question separation

W8-P01:
> Can a shared governed kernel preserve persistent identity, explicit authority, auditable evidence/effect boundaries, and recovery invariants across materially different Societies while remaining independent of provider/session identity?

W8-P02:
> Under a frozen historical market replay, how do separated Forecast/Decision/Order objects and specified forecast-combination variants behave under calibration, ablation, robustness, and replication evaluation?

These questions are materially distinct.

## Evidence separation

W8-P01 primary evidence:
- governance reference model;
- hardened session-scoped baseline;
- failure injection;
- mechanism ablation/mutation;
- Company + Trading conformance without market metrics;
- runtime identity/authorization/fencing/tamper/recovery negative controls;
- source/runtime lineage reconciliation.

W8-P02 primary evidence:
- frozen market datasets;
- market replay;
- forecasting/calibration metrics;
- block bootstrap;
- forecasting ablations;
- Decision/UOP historical replay;
- non-crypto replication.

There is no shared primary dataset or shared primary Results table.

## Duplicate gate result

- distinct primary research question: PASS
- independently generated primary evidence: PASS
- majority unique Results/Discussion: PASS by construction; must be rechecked after manuscript draft
- minimized repeated background: PASS as policy; text-level audit pending draft
- distinct main conclusion: PASS by claim ownership
- cannot reasonably be only a section of W8-P02: PASS

Overall: **PASS / PRE-MANUSCRIPT**

## Mandatory pre-submission recheck

After W8-P01 manuscript exists, run a text-level overlap audit against the submitted W8-P02 manuscript. Any exact Results-number reuse, repeated Results paragraph, or duplicated primary conclusion is a BLOCKER until removed or explicitly justified as a cited cross-reference.
