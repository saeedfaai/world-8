# JAAMAS Information Sheet — W8-P01 v0.1

Target journal: **Autonomous Agents and Multi-Agent Systems (JAAMAS)**  
Article type: **Regular Paper / Original Research**  
Working title: **A Governed Shared-Kernel Architecture for Persistent, Auditable Multi-Agent Societies Beyond the LLM Session**  
Author: **Saeed Farokhi**  
Status: **DRAFT / 1–2 PAGE SUBMISSION COMPANION / NOT SUBMITTED**

---

## 1. What is the main claim of the paper, and why is it important to the autonomous agents and multi-agent systems literature?

The paper's main claim is deliberately narrower than a general framework-superiority claim:

> A multi-agent system can treat logical Actor identity, authority, effect admission, stale-executor exclusion, governance evidence, and recovery gating as a shared contract that is independent of the underlying provider/session/runtime identity; in the frozen evaluation, the same contract preserves the selected invariants across two materially different Society adapters and can be layered over an independent AutoGen Core runtime.

This matters to autonomous-agent and MAS research because increasingly persistent agent applications combine transient LLM sessions, agent runtimes, tools, databases, and external effects. Runtime-level agent identifiers and saved state are valuable, but a runtime object is not necessarily the same thing as the durable organizational principal to which authority, responsibility, and evidence should be attributed. The paper evaluates one way to make that distinction explicit.

The paper does **not** claim to invent agents, roles, access control, leases, fencing tokens, CAS, idempotency, checkpoints, hash chains, or agent runtimes. Those mechanisms have established prior art. The candidate contribution is their particular governance composition and contract boundary: persistent logical Actor identity independent of provider/session/runtime identity; exact effect-time Actor/action/resource authorization; proposal/decision/effect separation; stale-effector fencing; tamper-evident governance evidence; and recovery-before-effect, all evaluated under one shared kernel and across different Society adapters.

## 2. What evidence supports the claim? Please be precise.

The evidence is staged and frozen at canonical commit:

`34ed68b6e04c548e7ee14aa16e0e3eecdb1b31f0`

with freeze ref:

`freeze/w8-p01-evidence-v0.1`.

**E1 — hardened reference baseline.** A 98,000-trial executable sweep compares the governed model with a deliberately strengthened session-scoped baseline. Once the baseline receives standard revoke checks, CAS/stale-write rejection, durable idempotency, approval scope, and durable audit, it matches World 8 on those generic mechanisms. This negative result narrows the differentiated reference mechanisms to persistent Actor-bound authorization, fencing/lease enforcement, and tamper-evident evidence verification rather than treating generic hardening as novelty.

**E2 — shared-kernel cross-Society conformance.** The exact same governed kernel and eight-invariant suite are applied to a Company Society (`quote proposal != purchase approval != supplier-order effect`) and a Trading Society (`forecast != trade decision != synthetic order`). Across 1,000 trials per Society, both adapters produce identical all-pass conformance vectors. No market-performance metric and no live external effect is used in this architecture experiment.

**E3 — canonical/runtime binding.** The experimental mechanisms are mapped to canonical SQL/migrations and a deployed PostgreSQL/Supabase runtime. Historical source gaps were recovered from authoritative migration history and byte-for-byte checked before admission. Read-only or rollback-safe runtime probes confirm default-DENY/explicit-DENY authorization, stale fencing-token rejection, immutable effect-receipt protection, append-only development evidence, actor/work mismatch rejection, and recovery-capsule reconstruction without retained experimental residue.

**E4 — mutation and compound faults.** Five controlled reference-model mutations are all killed (5/5; mutation score 1.0 for the frozen mutation set). Three frozen compound-fault schedules are executed for 1,000 trials each; the governed model reports safe rate 1.0 in all three while the hardened baseline exposes the targeted failure in the corresponding cases. The frozen valid normal/session-swap/restart paths have false-deny rate 0.0. The production PostgreSQL implementation is not destructively mutation-tested, and the paper states this limitation.

**E5 — independent executable runtime.** The external baseline uses real `autogen-core==0.7.5`, including `SingleThreadedAgentRuntime`, `AgentId`, and `RoutedAgent`, without an LLM/API key. The frozen matrix contains 2,000 runtime cases. Generic application hardening handles revocation, CAS, and idempotency. In the tested configuration, four additional frozen governance fault families—stolen approval, stale fence, audit tamper, and effect-before-recovery—remain exposed. Adding a transparent World-8-style governance wrapper over the same AutoGen runtime closes all four while preserving the frozen valid-path result. The interpretation is composability, **not** that World 8 generally beats AutoGen or that AutoGen is insecure.

## 3. What papers by other authors make the most closely related contributions, and how is this paper related to them?

The submission explicitly concedes substantial prior art.

- **Wooldridge & Jennings (1995), _Intelligent agents: theory and practice_, Knowledge Engineering Review.** Establishes intelligent-agent theory/architectures as a mature research area. W8-P01 does not claim to invent the agent abstraction.
- **Shoham (1993), _Agent-oriented programming_, Artificial Intelligence.** Establishes agent-oriented programming, capabilities, decisions, obligations and communication concepts. W8-P01 studies a narrower effect-governance contract.
- **Sandhu et al. (1996), _Role-Based Access Control Models_, Computer.** Establishes systematic role/permission models. W8-P01 does not claim to invent roles/access control; it evaluates persistent Actor binding and effect-time authorization across runtime replacement.
- **Gray & Cheriton (1989), _Leases_, SOSP; Burrows (2006), _The Chubby lock service_, OSDI.** Establish lease/lock coordination mechanisms. W8-P01 uses fencing/lease semantics as prior-art components inside a larger governance contract.
- **Haber & Stornetta (1991), _How to Time-Stamp a Digital Document_.** Establishes cryptographically linked/tamper-evident history concepts. W8-P01 evaluates such evidence as one governance component.
- **Chandy & Lamport (1985), _Distributed Snapshots_.** Establishes global-state/snapshot lineage. W8-P01 does not claim checkpoint/recovery novelty; it evaluates a recovery gate that withholds resumed effect capability until governed reconstruction passes.
- **Wu et al. (2024), _AutoGen: Enabling Next-Gen LLM Applications via Multi-Agent Conversation_, COLM.** Provides the most directly relevant modern multi-agent runtime comparison. W8-P01 executes a pinned real AutoGen Core runtime and tests whether the frozen governance controls are composable over it.

Current LangGraph persistence/checkpointing and OpenAI Agents SDK session/guardrail/tracing capabilities are also explicitly feature-mapped as related work so the manuscript does not imply uniqueness for persistence, recovery, guardrails, tracing, or orchestration.

The distinction claimed by W8-P01 is therefore **the tested governance composition and boundary**, not any individual primitive.

## 4. Have parts of this paper been published before? What significant contribution does this submission provide beyond previous work?

The flagship W8-P01 manuscript has **not** previously been submitted as this paper. However, a separate World 8 working paper, W8-P02, has been submitted to SSRN as Abstract ID `7359740` under the title:

**Forecast, Decision, and Order as Separate Objects: A Contract-Based Evaluation Architecture for Multi-Agent Market Systems**.

W8-P02 asks a different research question and owns separate empirical evidence: frozen historical market datasets, Brier/calibration evaluation, forecast-combination ablations, Decision/UOP historical replay, and non-crypto market-performance replication.

W8-P01 does **not** reuse those market-performance Results, tables, confidence intervals, or conclusions as its primary contribution. Its primary evidence is independently generated and consists of the governance reference model, hardened governance baseline, actor/authority/fencing/tamper/recovery failure injection, Company+Trading shared-kernel conformance without market metrics, runtime governance probes, mutation/compound-fault evaluation, and the executable AutoGen Core comparison.

The Trading Society appears in W8-P01 only as a governance/conformance adapter. `market_performance_evaluated=false` and `live_effects=false` are explicit frozen properties of the architecture experiment.

A formal W8-P01/W8-P02 ownership audit was completed before manuscript drafting and passed. A second **text-level** overlap audit is mandatory after the W8-P01 draft is finalized and before JAAMAS submission. Any repeated Results paragraph, primary table/figure, or primary conclusion is a submission blocker until removed or transparently justified as a cited cross-reference.

Thus, the significant added value of W8-P01 is not an extension of the W8-P02 market replay. It is a separate architecture/governance evaluation with separate primary evidence, a stronger external multi-agent-runtime comparator, a different research question, and a distinct main conclusion.
