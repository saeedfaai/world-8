# World 8 v0.1 — Distribution Packet

Date: 2026-08-27
Status: READY / LINKEDIN PUBLISHED / OTHER SURFACES NOT YET PUBLISHED

## Canonical references

- Demo: https://huggingface.co/spaces/Saeedfa/world8-demo
- GitHub release: https://github.com/saeedfaai/world-8/releases/tag/V0.1.0
- Zenodo DOI: https://doi.org/10.5281/zenodo.22127650
- SSRN: https://papers.ssrn.com/sol3/papers.cfm?abstract_id=7359740 — submitted / under staff review
- LinkedIn: https://www.linkedin.com/feed/update/urn:li:share:7498768174612578304/

## Core message

**Forecast ≠ Decision ≠ Order.**

World 8 v0.1.0 is a development/research baseline for persistent multi-agent forecasting architecture with explicit evidence boundaries, immutable forecast receipts, deterministic replay, lifecycle-integrity checks, calibration-aware ensemble evaluation, independent Decision/UOP evaluation, and retained negative or mixed ablation results.

It is not a production trading system and makes no profitability claim.

## Medium article draft

### Title
Why Forecast, Decision, and Order Should Be Separate Objects in Multi-Agent Systems

### Subtitle
What World 8 v0.1.0 learned from building an evidence-backed forecasting architecture

### Opening
Most agent systems make a deceptively simple mistake: they collapse prediction, decision, and action into the same output.

That is convenient for demos. It is terrible for auditability.

If a trade, recommendation, or automated action fails, what exactly failed? Was the forecast wrong? Was the decision rule wrong? Was risk policy wrong? Was the execution layer wrong? If these objects are not separated, retrospective evaluation becomes ambiguous and every later improvement risks rewriting the meaning of the original output.

World 8 v0.1.0 explores a stricter alternative: **Forecast ≠ Decision ≠ Order.**

### Suggested structure
1. The problem with conflated agent outputs
2. Forecast as an immutable evidence-bearing object
3. Decision as a separate expected-value/risk object
4. Order as downstream execution
5. Why lifecycle state matters
6. Historical replay and no-lookahead controls
7. What actually improved in the frozen study
8. Negative findings we kept
9. Why reproducibility matters more than a single benchmark win
10. What World 8 does not claim
11. Public demo / DOI / SSRN

### Result paragraph
In the frozen BTC/ETH/SOL replay, calibrated weighted aggregation reduced Brier loss relative to equal-weight raw aggregation for all three symbols, with paired moving-block bootstrap intervals below zero. Other mechanisms were much less convincing: the tested correlation penalty did not show a useful general gain; disagreement shrink helped only SOL; simple regime weighting improved ETH slightly but worsened BTC; shadow cold-start was neutral; and the tested volatility risk veto did not improve the Decision/UOP metric. An independent SPY/QQQ/GLD replication produced point estimates in the same direction for calibration, but all three confidence intervals crossed zero.

### Closing
The point of World 8 v0.1.0 is not that one architecture has “solved” markets. The point is that a system should make it difficult to hide what it predicted, when it predicted it, what evidence it used, how it was evaluated, and where a later decision came from.

Demo: https://huggingface.co/spaces/Saeedfa/world8-demo

Software snapshot: https://doi.org/10.5281/zenodo.22127650

Working paper: https://papers.ssrn.com/sol3/papers.cfm?abstract_id=7359740

## Reddit technical post

### Candidate title
Can a multi-agent system stay auditable if Forecast, Decision, and Order are separate objects?

### Body
I’ve published the v0.1.0 research/demo baseline of World 8, a multi-agent forecasting architecture built around one rule:

**Forecast ≠ Decision ≠ Order.**

The goal is not to claim a profitable trading agent. The goal is to make evaluation harder to game after the fact.

The current baseline uses immutable forecast receipts, explicit data cutoffs, deterministic historical replay, lifecycle integrity, independent evaluation, and version/hash binding. The frozen study contains positive, negative, and mixed results rather than only favorable ablations.

A few measured findings:
- calibrated weighting improved Brier loss vs equal-weight raw in the frozen BTC/ETH/SOL replay;
- correlation control did not show a useful general improvement;
- disagreement shrink helped only SOL under the tested specification;
- regime weighting was mixed;
- shadow cold-start was neutral;
- the tested volatility risk veto did not improve the Decision/UOP metric;
- SPY/QQQ/GLD replication moved in the same direction for calibration, but all confidence intervals crossed zero.

I’m looking for criticism on:
1. failure modes in the Forecast Contract;
2. ways the replay/evaluation protocol could still leak information;
3. better baselines for ensemble calibration;
4. whether separating Forecast/Decision/Order materially improves reproducibility;
5. what experiment would most strongly falsify the architecture.

Demo:
https://huggingface.co/spaces/Saeedfa/world8-demo

DOI:
https://doi.org/10.5281/zenodo.22127650

SSRN submission:
https://papers.ssrn.com/sol3/papers.cfm?abstract_id=7359740

## Hacker News

### Title option A
Show HN: World 8 – auditable multi-agent forecasting with immutable receipts

### Title option B
Show HN: Separating Forecast, Decision, and Order in multi-agent systems

### Submission URL
https://huggingface.co/spaces/Saeedfa/world8-demo

### First comment
I’m the author. The project is a research/development baseline rather than a production trading system. The main design constraint is that forecasts are immutable evidence-bearing objects and cannot be silently rewritten when later decisions change. The public demo links to the frozen release, Zenodo DOI, replay evidence, lifecycle receipt, and the SSRN working-paper submission. I’d especially appreciate feedback on failure modes, replay leakage, calibration baselines, and whether the evidence model is actually useful outside this market-focused prototype.

## LinkedIn

Published 2026-08-27 through the connected personal LinkedIn account.
Receipt:
`docs/distribution/LINKEDIN_WORLD8_V0.1_RECEIPT.md`

## Publication guardrails

Do not publish variants that claim:
- profitability;
- production readiness;
- universal cross-market superiority;
- causal superiority of the architecture;
- general benefit from correlation/regime/disagreement/risk-veto mechanisms;
- AGI, consciousness, or autonomous economic agency.

If an external platform truncates or reframes the text, re-check the resulting post against the claim boundary before treating it as canonical distribution.