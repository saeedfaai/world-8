# World 8 — Paper Portfolio & Overlap Policy

Date: 2026-08-27
Status: CANONICAL / ACTIVE
Owner: Saeed Farrokhi

## Purpose
World 8 publications are managed as a small scientific portfolio, not as a stream of partially overlapping papers. Every paper must have a distinct research question, distinct primary evidence, distinct main contribution, and explicit overlap boundaries with the other papers.

## Portfolio size rule
- Maximum ACTIVE World 8 research papers at one time: **2**.
- Maximum planned World 8 research papers in the current generation: **4**.
- A RESERVED paper may not move to ACTIVE until it has independent evidence that is not merely reused from an ACTIVE paper.
- World 6 / World 7 publications remain historical lineage and are cited as predecessors; they do not count toward the active World 8 paper cap.

## W8-P01 — Flagship system/architecture paper
Status: **ACTIVE / NOT YET SUBMITTED**
Role: **Mother paper / overall World 8 paper**

Working title:
**World 8: A Governed Architecture for Persistent, Auditable Multi-Agent Systems Beyond the LLM Session**

Primary research question:
Can a multi-agent system maintain persistent identity, explicit authority, auditable state/evidence boundaries, and replaceable AI providers while keeping prediction, decision, execution, and development governance separable and inspectable?

Primary contribution:
- overall World 8 architecture;
- persistent identity independent of provider/session;
- authority/capability boundary;
- canonical state + evidence receipts;
- Development Control Plane / governed developer admission;
- society/runtime separation;
- Forecast != Decision != Order as one architectural example, not the paper's empirical centerpiece;
- failure modes, invariants, non-claims, and reproducibility architecture.

Evidence required before journal submission:
- architecture validator and identity/authority evidence;
- developer-admission/runtime receipts;
- at least one reproducible end-to-end multi-agent scenario beyond the market forecasting experiment;
- fault/failure injection showing fail-closed behavior;
- quantitative or clearly operational comparison against at least one conventional agent orchestration baseline;
- exact release/evidence package hashes.

Primary target:
**Autonomous Agents and Multi-Agent Systems (Springer / JAAMAS)**

Why:
The journal currently publishes work on multi-agent system testing, delegation/trust, hybrid intelligence teams, open-ended coordination, agent programming, and scalable/fault-tolerant MAS architectures. World 8's overall contribution belongs more naturally here than in a finance venue.

Secondary target if the final paper becomes more distributed-systems/runtime-centric:
**Future Generation Computer Systems (Elsevier)**

Reason:
FGCS explicitly covers distributed systems, collaborative infrastructures, complex workflows, protocols, emerging standards, security, and protocol verification.

Strict non-overlap with W8-P02:
- W8-P01 may summarize the market replay in one short validation/example subsection.
- It MUST NOT reuse W8-P02 as its main Results section.
- Detailed Brier/calibration/ablation tables belong only to W8-P02.
- W8-P01's novelty claim must be architectural/governance/system-level, not forecasting-performance superiority.

## W8-P02 — Forecast / Decision / Order empirical paper
Status: **ACTIVE / SUBMITTED / SSRN UNDER REVIEW**
SSRN Abstract ID: `7359740`
URL: https://papers.ssrn.com/sol3/papers.cfm?abstract_id=7359740

Title:
**Forecast, Decision, and Order as Separate Objects: A Contract-Based Evaluation Architecture for Multi-Agent Market Systems**

Primary research question:
Does separating forecast, decision, and order objects and using calibrated ensemble evaluation improve auditability and measured forecast quality under frozen historical replay?

Primary evidence:
- BTC/ETH/SOL frozen replay;
- SPY/QQQ/GLD replication;
- Brier/calibration analysis;
- bootstrap confidence intervals;
- disagreement/regime/shadow/correlation/risk-veto ablations;
- Forecast Contract lifecycle integrity: 52,920 RESOLVED / 0 failures.

Primary contribution:
Empirical market-evaluation architecture and measured forecasting results.

Non-overlap with W8-P01:
- architecture background limited to what is needed to explain the experiment;
- no claim to present the complete World 8 architecture;
- no full DCP/developer-admission/identity-authority treatment.

## W8-P03 — Persistent identity, authority & governed execution
Status: **RESERVED / DO NOT DRAFT YET**

Candidate research question:
What mechanisms are sufficient to preserve agent identity and authority across provider/session changes while preventing stale writes, unauthorized delegation, and replay/tamper failures?

Activation gate:
Requires an independent security/failure-injection benchmark and quantitative comparison against a simpler session/provider-bound baseline.

Likely venue class:
Multi-agent systems / dependable software / software architecture.

Overlap prohibition:
May cite the architecture paper, but must center on security/authority experiments, not restate the full World 8 architecture.

## W8-P04 — Development Control Plane for agent-built software
Status: **RESERVED / DO NOT DRAFT YET**

Candidate research question:
Can a governed Development Control Plane with admission, leases, fencing, diagnostic memory, experience packs, and immutable handoff receipts improve reproducibility and reduce repeated engineering failures in multi-agent software development?

Activation gate:
Requires measured engineering evidence: repeated tasks, failure recurrence, recovery time, handoff success, or controlled developer/agent comparison.

Likely venue class:
Software engineering / autonomous software systems.

Overlap prohibition:
May use World 8 as the case study, but contribution must be engineering-process evidence, not architecture description.

## Historical lineage — not new World 8 papers
- World v6.2 / v6.2.0-rc.3 — historical architecture/publication lineage.
- World 7 v0.2 / v7.0.0-rc.1 — historical Living Genome / review lineage.
- World 8 Z0-A — historical design baseline.

These artifacts must be cited where relevant but must not be repackaged as new papers with only cosmetic title changes.

## Duplicate / salami-slicing gate
Before any new manuscript is approved, answer all six:
1. Is the primary research question different from every ACTIVE paper?
2. Is the primary evidence independently generated rather than copied from another paper?
3. Is at least ~70% of the Results/Discussion contribution unique in substance?
4. Are repeated architecture/background sections minimized and cited rather than copied?
5. Does the paper have a different main conclusion?
6. Would a reviewer understand why this could not reasonably be one section of an existing paper?

If any answer is NO, the manuscript remains BLOCKED and is merged into an existing paper instead.

## Current publication strategy
1. Keep W8-P02 frozen while SSRN reviews it.
2. Build W8-P01 as the single flagship overall World 8 paper.
3. Do not activate W8-P03 or W8-P04 yet.
4. Target a total of **2 strong World 8 papers now**, with **3–4 total only after independent evidence exists**.
5. One artifact/release may support multiple papers, but the same experiment/result must not be presented as a new contribution twice.

## Canonical principle
**Few papers, distinct questions, separate evidence, stronger claims.**
