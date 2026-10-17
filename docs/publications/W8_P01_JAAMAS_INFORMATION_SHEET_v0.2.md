# JAAMAS Information Sheet — W8-P01 v0.2

Target journal: **Autonomous Agents and Multi-Agent Systems (JAAMAS)**  
Article type: **Regular Paper / Original Research**  
Working title: **A Governed Shared-Kernel Architecture for Persistent, Auditable Multi-Agent Societies Beyond the LLM Session**  
Author: **Saeed Farokhi**  
Status: **DRAFT / NOVELTY-HARDENED / NOT SUBMITTED**

## 1. Main claim and importance

The submission evaluates a particular **effect-governance composition** for multi-agent systems. A logical Actor is explicitly bound across transient provider/session/runtime contexts; exact Actor/action/resource authority is checked at the governed effect boundary; stale effectors are fenced; governance evidence is tamper-evident; and effect capability is withheld until the tested recovery boundary passes. The same frozen contract is exercised across two distinct Society adapters and is also composed over a real independent AutoGen Core runtime.

The paper does **not** claim that persistent agent identity, multi-agent governance, norms, permissions/obligations, leases, fencing, access control, provenance, checkpoints, or agent runtimes are individually new. A second close prior-art pass found direct work on normative governance in open MAS, distributed norm management, topology-independent agent identity, and verifiable delegation. The manuscript therefore treats novelty as **composition + contract boundary + falsification evidence**, not invention of those primitives.

The question is relevant to autonomous-agent/MAS engineering because persistent agent applications increasingly cross model providers, sessions, runtime instances, tools, and external-effect boundaries. The contribution is an experimentally bounded way to make authority/effect continuity explicit and testable rather than equating a transient runtime identity with the durable domain principal.

## 2. Precise evidence

Evidence is frozen at commit `34ed68b6e04c548e7ee14aa16e0e3eecdb1b31f0` and ref `freeze/w8-p01-evidence-v0.1`.

**E1 — hardened reference baseline:** 98,000 trials. Once the baseline receives standard revocation, CAS/stale-write protection, durable idempotency, approval scope, and durable audit, it matches World 8 on those generic mechanisms. This negative result removes them from the differentiated claim.

**E2 — shared-kernel conformance:** the same governed kernel and eight-invariant suite are executed for 1,000 Company-Society trials and 1,000 Trading-Society trials. Both produce identical all-pass conformance vectors. The Trading adapter is governance-only: no predictive performance and no live external effect are evaluated.

**E3 — canonical/runtime binding:** canonical migration/source lineage is reconciled to the deployed PostgreSQL/Supabase runtime. Read-only or rollback-safe probes confirm default-DENY/explicit-DENY authorization, stale fencing-token rejection, immutable effect receipts, append-only journal evidence, actor/work mismatch rejection, and recovery-capsule reconstruction without retained experimental residue.

**E4 — mutation/compound faults:** 5/5 controlled reference-model mutations are killed. Three compound-fault schedules × 1,000 trials each report safe rate 1.0 for the governed model; frozen valid normal/session-swap/restart paths have false-deny rate 0.0. The production database is not destructively mutation-tested and the paper states that scope limitation.

**E5 — real external runtime:** `autogen-core==0.7.5` is executed in 2,000 frozen runtime cases using real `SingleThreadedAgentRuntime`, `AgentId`, and `RoutedAgent`, with no LLM/API key. Generic hardening handles revocation, CAS, and idempotency. The tested hardened configuration remains exposed to stolen approval, stale fence, audit tamper, and effect-before-recovery. Adding the explicit World-8-style governance wrapper over the same runtime closes those four frozen families while preserving the frozen valid-path result. The interpretation is composability, not general superiority over AutoGen.

## 3. Closest related work and distinction

The close prior-art review identifies several important lines:

- **da Silva et al. (2007), _Governing multi-agent systems_, JBCS, DOI 10.1007/BF03192407.** Direct prior art for governance mechanisms and norms defining prohibited, permitted, and obligated actions in open MAS. W8-P01 therefore does not claim governance/norm enforcement as new.
- **Vasconcelos et al. (2012), _Distributed norm management for multi-agent systems_, ESWA, DOI 10.1016/j.eswa.2011.11.108.** Prior art for distributed run-time management of normative constraints and fault-tolerance/scalability motivations. W8-P01 does not claim distributed governance itself as new.
- **Sandhu et al. (1996), RBAC.** Prior art for systematic role/permission models. W8-P01 evaluates exact Actor/action/resource effect-time binding rather than inventing access control.
- **Gray & Cheriton (1989) and Burrows (2006).** Prior art for leases/lock coordination. Fencing is used as a component rather than claimed as an invention.
- **Haber & Stornetta (1991); Chandy & Lamport (1985).** Prior art for tamper-evident histories and distributed snapshot/recovery lineage.
- **Wu et al. (2024), AutoGen, COLM.** The principal executable external runtime comparison. W8-P01 tests a transparent governance composition over pinned real AutoGen Core rather than replacing AutoGen with a weak mock.
- **Rodriguez (2026), _Agent Identity URI Scheme_, arXiv:2601.14567.** Contemporary preprint directly studying topology/provider-independent stable agent identity. This removes any standalone “provider-independent identity is new” claim from W8-P01.
- **Prakash (2026), _AIP_, arXiv:2603.24775.** Contemporary preprint combining verifiable identity, delegated authorization, policy, and provenance. W8-P01 therefore does not claim identity+authorization+provenance as an unprecedented combination.
- **Rother et al. (2025), _Open-ended coordination for multi-agent systems using modular open policies_, JAAMAS, DOI 10.1007/s10458-025-09723-7.** Recent context for dynamic/open MAS; W8-P01 is an effect-governance architecture rather than a learning/coordination-policy contribution.

The remaining distinction is the **specific tested effect-governance composition** plus the evidence program: logical Actor binding, exact effect-time authority, proposal/decision/effect separation, stale-effector fencing, tamper-evident governance evidence, recovery-before-effect, identical cross-Society conformance, and executable composition over an independent runtime.

No “first” or “unique” claim is made.

## 4. Relation to previous/public work by the author

A separate World 8 working paper, W8-P02, was submitted to SSRN as Abstract ID `7359740` under the title **Forecast, Decision, and Order as Separate Objects: A Contract-Based Evaluation Architecture for Multi-Agent Market Systems**.

W8-P02 owns frozen market-performance evidence: historical crypto/non-crypto replay, Brier/calibration results, market forecasting ablations, Decision/UOP replay, and related market metrics.

W8-P01 does **not** reuse those market-performance Results, tables, confidence intervals, or conclusions as its primary contribution. Its evidence is independently generated: governance reference model, hardened governance baseline, actor/authority/fencing/tamper/recovery fault injection, Company+Trading conformance without market metrics, runtime governance probes, mutation/compound faults, and the executable AutoGen comparison.

The Trading Society appears in W8-P01 only as a governance/conformance adapter (`market_performance_evaluated=false`; `live_effects=false`). A pre-manuscript ownership audit passed, and a second text-level overlap audit is mandatory before submission.

Thus the submission is not a sliced extension of the W8-P02 market study. It addresses a different research question, uses separate primary evidence, has a different comparator, and supports a different main conclusion.
