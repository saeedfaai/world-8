# A Governed Shared-Kernel Architecture for Persistent, Auditable Multi-Agent Societies Beyond the LLM Session

**Working manuscript — W8-P01 v0.1**  
Status: **DRAFT / NOT SUBMITTED / EVIDENCE-BOUND**  
Evidence freeze: `freeze/w8-p01-evidence-v0.1`  
Frozen canonical commit: `34ed68b6e04c548e7ee14aa16e0e3eecdb1b31f0`

**Saeed Farokhi**  
Mechanical Engineering, University of Tehran  
Saeed.farokhi@ut.ac.ir

---

## Abstract

Large-language-model agent systems increasingly combine multiple agents, tools, persistent state, and external effects, yet the identity and authority of an agent are often entangled with transient runtime objects, sessions, or provider-specific execution contexts. This paper studies a narrower architectural question: whether a shared governance kernel can preserve a logical Actor identity, explicit effect-time authority, tamper-evident evidence, stale-executor exclusion, and recovery-before-effect invariants across materially different multi-agent domains while remaining independent of the underlying model provider or session identity.

We evaluate **World 8**, an experimental governed multi-agent architecture, through a staged falsification-oriented evidence program rather than a production or performance claim. First, a hardened session-scoped baseline is introduced specifically to remove advantages attributable to generic mechanisms such as revocation checks, compare-and-swap versioning, durable idempotency, approval scope, and durable audit. In a 98,000-trial reference-model sweep, that hardened baseline matches the governed system on those generic mechanisms, narrowing the differentiated mechanisms to persistent Actor-bound authorization, fencing/lease enforcement, and tamper-evident evidence verification. Second, the same governed kernel and the same eight-invariant conformance suite are applied to two distinct domain adapters: a Company Society (`proposal != approval != effect`) and a Trading Society (`forecast != decision != synthetic order`). Across 1,000 trials per Society, both adapters produce identical all-pass conformance vectors; no market-performance metric and no live trading effect is evaluated in this architecture experiment.

Third, the reference mechanisms are bound to canonical source and a deployed PostgreSQL/Supabase runtime. Read-only or rollback-safe behavioral probes confirm default-deny/explicit-deny authorization, stale fencing-token rejection, immutable effect receipts, append-only development evidence, actor/work mismatch rejection, and recovery-capsule reconstruction without retained experimental residue. A scoped mutation and compound-fault stage kills 5/5 controlled reference-model mutations and reports zero false-deny rate on the frozen valid paths. Finally, we execute an external baseline on real `autogen-core==0.7.5`. Generic hardening closes revocation, CAS, and idempotency faults; four additional frozen governance fault families—stolen approval, stale fencing, audit tamper, and effect-before-recovery—remain exposed in the tested baseline configuration. Adding a transparent World-8-style governance wrapper over the same AutoGen runtime closes all four frozen families while preserving the frozen valid paths.

The result is intentionally bounded. The evidence does not establish that World 8 is generally superior to AutoGen or other agent frameworks, nor that leases, access control, checkpoints, hash chains, or agent runtimes are novel. Instead, it supports a narrower architectural contribution: a tested composition of provider-independent logical Actor identity, effect-time authorization, fencing, tamper-evident governance evidence, recovery gating, and cross-Society conformance that can be layered over an independent multi-agent runtime.

**Keywords:** multi-agent systems; agent identity; authorization; governance; fencing; fault recovery; tamper-evident evidence; agent runtime; AutoGen; reproducibility

---

## 1. Introduction

Modern multi-agent applications increasingly connect language-model agents to tools, databases, workflows, external services, and other agents. As these systems become more persistent, the distinction between a transient execution context and the logical entity that is authorized to act becomes operationally important. A model provider may change, a process may restart, a session may be replaced, or an agent runtime may recreate an instance. None of those events necessarily imply that the logical Actor represented by the system should change. Conversely, possession of a runtime object or a copied approval token should not automatically grant durable authority to produce an external effect.

This paper considers the following research question:

> **Can one governed multi-agent kernel preserve persistent identity, explicit authority, auditable evidence/effect boundaries, and recovery invariants across materially different Societies while remaining independent of provider/session identity?**

The system studied here is called **World 8**. The name refers to an experimental architecture, not a claim of a new class of intelligence. The paper does not attempt to demonstrate general autonomous intelligence, profitability, production readiness, or universal security. Its focus is narrower: the composition and falsification of governance mechanisms around multi-agent effects.

The central architectural distinction is between a **logical Actor** and the transient provider/session/runtime context that executes on its behalf. The governed effect path then combines four additional boundaries: explicit effect-time authorization, stale-executor exclusion through fencing, tamper-evident evidence, and recovery gating before new effect capability. Domain-specific semantics are introduced through Society adapters, but the governance kernel remains shared.

A key methodological choice is to avoid treating generic distributed-systems mechanisms as evidence of architectural novelty. Leases, version checks, idempotency, access control, checkpoints, append-only logs, hash chaining, actor runtimes, and tracing all have substantial prior art. Accordingly, the evaluation deliberately strengthens the baseline with several of these mechanisms. If the hardened baseline matches World 8 on a mechanism, that mechanism is removed from the paper's differentiated claim.

The paper makes four bounded contributions:

1. **A governed shared-kernel contract.** The architecture separates logical Actor identity from provider/session/runtime identity and separates domain proposal or prediction from approval or decision and from effect execution.
2. **A falsification-oriented evaluation.** A hardened baseline, ablations, mutation tests, compound faults, negative controls, and valid-path false-deny checks are used to narrow rather than inflate the claim.
3. **Cross-Society conformance evidence.** The same governed kernel and invariant suite are exercised across two materially different domain adapters without using domain-performance metrics as architecture evidence.
4. **External-runtime composability evidence.** The frozen governance controls are layered over a pinned real AutoGen Core runtime, demonstrating that the evaluated controls do not require an exclusive World 8 execution engine.

The remainder of the paper defines the architecture and threat/failure model, describes the staged evaluation protocol, reports both positive and negative results, relates the design to established prior art, and states the limits of the current evidence.

---

## 2. Problem Definition and Design Goals

### 2.1 Logical Actor versus execution identity

We define a **logical Actor** as the persistent domain identity to which authority, responsibility, and evidence attribution are bound. A provider model, API credential, session, process, worker, or runtime `AgentId` may participate in executing work for that Actor but does not by itself define the Actor.

This distinction is motivated by two failure directions:

- **identity loss:** replacing a provider/session/runtime accidentally creates a new effective identity and breaks continuity of authority or attribution;
- **identity capture:** possession of a transient execution context is incorrectly treated as sufficient proof of the persistent Actor's authority.

The architecture therefore requires an explicit binding from execution context to logical Actor and evaluates authorization against the Actor and governed resource/action boundary.

### 2.2 Proposal, decision, and effect are different objects

A domain object that expresses information, prediction, or intent is not authority to produce an external effect. The generic contract is:

`PROPOSAL/PREDICTION != APPROVAL/DECISION != EFFECT/EXECUTION`

Two concrete adapters are used in the conformance experiment:

- **Company Society:** `QUOTE_PROPOSAL != PURCHASE_APPROVAL != SUPPLIER_ORDER_EFFECT`
- **Trading Society:** `FORECAST != TRADE_DECISION != SYNTHETIC_ORDER`

The Trading adapter is used only as a governance/conformance domain in this paper. Predictive accuracy, calibration, market returns, risk-veto performance, and crypto/non-crypto forecasting results belong to a separate domain-specific paper (W8-P02; SSRN Abstract ID 7359740) and are not reused here as primary evidence.

### 2.3 Effect-time authorization

Authority is evaluated at the governed effect boundary against the relevant Actor/action/resource context. A proposal or prior approval object is therefore evidence used by the decision path, not a universal bearer capability that automatically authorizes future effects.

### 2.4 Fencing stale effectors

A stale executor may retain credentials, local state, or previously valid coordination information after a lease or ownership transition. The architecture uses lease-generation/fencing semantics to reject the tested stale-executor cases. Fencing tokens and leases are established distributed-systems mechanisms; this paper does not claim to invent them.

### 2.5 Tamper-evident evidence

Governed decisions and effects produce evidence receipts. The evaluated runtime includes append-only/chained development evidence and immutable effect-receipt guards. Hash chains and tamper-evident histories are established prior art; the paper studies their role inside the composed governance contract.

### 2.6 Recovery before resumed effect capability

A restarted or reconstructed system should not immediately regain effect capability merely because a process is alive. The evaluated contract requires recovery/reconstruction of the governed state/evidence boundary before the tested resumed-effect path is considered valid.

---

## 3. Architecture

### 3.1 Shared governance kernel

The evaluated kernel is intentionally domain-thin. It owns the mechanisms that should remain invariant across Societies:

- persistent Actor identity and execution binding;
- authorization at the effect boundary;
- governed version/staleness checks;
- lease/fencing boundary;
- durable idempotency where required;
- evidence receipts and integrity checks;
- reconstruction/recovery gate.

Domain adapters provide Society-specific object labels and workflow semantics but do not redefine those invariants.

### 3.2 Society adapters

A Society adapter maps domain objects into the shared governance stages. The E2 experiment uses two adapters that are deliberately different in domain semantics but structurally comparable at the governance boundary.

The Company adapter models a synthetic procurement/operational path. The Trading adapter models a synthetic forecast/decision/order path. Neither adapter performs a live external business effect in the frozen experiment.

### 3.3 Canonical source and runtime boundary

The architecture is not evaluated only as a Python reference model. E3 maps the measured mechanisms to canonical SQL/migration sources and deployed runtime functions. During this process, historical migration-source gaps were discovered. The missing authoritative migration statements were recovered from `supabase_migrations.schema_migrations.statements`, restored to canonical Git, and checked byte-for-byte against their stored authoritative source before being admitted into the evidence base.

This source/runtime reconciliation is treated as part of the reproducibility evidence rather than hidden implementation cleanup.

---

## 4. Prior Art and Novelty Boundary

The contribution of this paper is not the invention of the primitive mechanisms used in the architecture.

Intelligent-agent theory and agent architectures predate modern LLM systems [1]. Agent-oriented programming, capabilities, decisions, obligations, and typed inter-agent communication are established research topics [2]. Role-based access control provides systematic role/permission models [3]. Leases and distributed lock services are established fault-tolerance and coordination mechanisms [4,5]. Cryptographically linked/tamper-evident histories have a long lineage [6], and distributed snapshots/checkpointing are foundational distributed-systems techniques [7].

Modern frameworks further narrow the novelty boundary. AutoGen provides a multi-agent runtime, `AgentId`, asynchronous messaging, lifecycle management, and state save/load APIs [8]. LangGraph documents persistent checkpoints, durable stores, and fault-recovery-oriented persistence [9]. The OpenAI Agents SDK provides orchestration, sessions, guardrails, human-in-the-loop mechanisms, and tracing [10].

Accordingly, W8-P01 does **not** claim novelty for agents, roles, access control, leases, locks, CAS/version checks, idempotency, checkpoints, restart/recovery, hash chains, tracing, guardrails, or multi-agent runtime/orchestration individually.

The candidate contribution is the tested **composition and contract boundary**:

1. a logical Actor identity not defined by provider/session/runtime identity;
2. effect-time authorization bound to that Actor and the exact action/resource;
3. explicit proposal/decision/effect separation;
4. fencing of stale effectors;
5. tamper-evident governance evidence;
6. recovery gating before resumed effect capability;
7. the same conformance contract across materially different Societies; and
8. evidence that these controls can be layered over an independent external multi-agent runtime.

Even this composition is presented as a scoped architectural contribution, not an exhaustive universal novelty claim.

---

## 5. Evaluation Method

### 5.1 Evidence ladder

The evaluation is staged to make stronger claims contingent on stronger evidence:

- **E1:** reference-model falsification, hardened baseline, and ablations;
- **E2:** cross-Society shared-kernel conformance;
- **E3:** canonical-source/runtime binding and behavioral negative controls;
- **E4:** controlled mutation, compound faults, recovery, and valid-path false-deny measurement;
- **E5:** independent external-runtime comparison using a pinned real AutoGen Core runtime.

The evidence used by this manuscript is frozen at canonical commit `34ed68b6e04c548e7ee14aa16e0e3eecdb1b31f0` and reference `freeze/w8-p01-evidence-v0.1`.

### 5.2 E1: hardened baseline and mechanism falsification

An initial weak baseline made several World 8 mechanisms appear uniformly advantageous. That result was explicitly rejected as insufficient evidence. A hardened session-scoped baseline was then constructed with:

- revoke checks;
- compare-and-swap/stale-write rejection;
- durable idempotency;
- approval scoping;
- durable audit.

The strong E1 run executes 98,000 trials across the governed model, hardened baseline, and controlled ablations/variants.

The purpose is not to maximize the number of World 8 wins. It is to eliminate differences that can be explained by generic hardening.

### 5.3 E2: two-Society conformance

The same governed kernel and the same eight invariants are executed for 1,000 trials per Society.

The frozen invariant families include:

1. proposal/prediction does not grant effect authority;
2. valid approved effect succeeds;
3. session/runtime replacement preserves logical Actor attribution;
4. stale writer is rejected;
5. duplicate effect is suppressed;
6. invalid/stale fence is rejected;
7. evidence tamper is detected;
8. restart/reconstruction preserves governed state before resumed effect.

No market-performance metric is evaluated in this stage.

### 5.4 E3: source/runtime binding

E3 maps the experimental mechanisms to canonical source and deployed runtime objects. Behavioral probes are intentionally read-only or rollback-safe and do not perform a live business effect.

The frozen probes cover:

- default-DENY and explicit-DENY authorization behavior;
- stale fencing-token rejection;
- effect-receipt mutation blocking;
- append-only development-journal enforcement;
- actor/work mismatch rejection;
- recovery-capsule reconstruction.

### 5.5 E4: mutation and compound faults

Five controlled mutations target the reference mechanisms for actor binding, version/CAS protection, fencing, idempotency, and evidence integrity. Mutation score is reported only for this executable reference model; production PostgreSQL functions are not deliberately mutated.

A separate compound-fault gate executes three frozen multi-fault schedules at 1,000 trials each and also measures false denial on valid normal, session-swap, and restart/reconstruct paths.

### 5.6 E5: external AutoGen baseline

The external baseline pins `autogen-core==0.7.5` and uses real `SingleThreadedAgentRuntime`, `AgentId`, and `RoutedAgent` execution. No LLM call or API key is required.

Two configurations are evaluated on the same frozen cases:

- **Hardened AutoGen + generic application controls:** revoke, version/CAS, durable idempotency, approval scope, and durable mutable audit.
- **The same AutoGen runtime + explicit World-8-style governance wrapper:** persistent domain-Actor binding, effect-time Actor authorization, fencing, tamper-evident evidence, and recovery-before-effect.

The E5 matrix comprises 100 trials per case × 10 scenarios × 2 variants = 2,000 runtime cases. Runtime recreation is real in the recovery cases.

This comparison is designed to test composability and the frozen governance fault families, not general framework performance.

---

## 6. Results

### 6.1 E1: generic hardening removes several apparent advantages

The hardened baseline matches World 8 on revocation at effect time, CAS/stale-write rejection, durable idempotency, missing-approval rejection, and concurrent single-winner behavior in the frozen reference experiment.

This is an important negative result. Those mechanisms are therefore not treated as differentiated World 8 contributions.

The mechanisms that remain differentiated in the frozen reference model are:

- persistent Actor/authorization binding under session/runtime replacement and impersonation-oriented fault families;
- fencing/lease enforcement in stale-effector cases;
- tamper-evident receipt verification.

The frozen valid-path reference instrumentation records approximately 7 policy checks and 9 evidence records for World 8 versus 6 checks and 8 evidence records for the hardened baseline. These counts are governance-operation counts, not wall-clock latency or production throughput measurements.

### 6.2 E2: identical conformance over Company and Trading adapters

| Metric | Company Society | Trading Society |
|---|---:|---:|
| Trials | 1,000 | 1,000 |
| Invariants | 8 | 8 |
| All invariant pass rates | 1.0 | 1.0 |
| Market performance evaluated | No | No |
| Live external effects | No | No |

The conformance vectors are identical. Within the frozen protocol, the same governed kernel therefore preserves the same selected invariants across the two adapters.

This result does not establish universal domain generality. It establishes cross-domain conformance for exactly two tested adapters and eight frozen invariants.

### 6.3 E3: canonical/runtime behavioral checks

The source/runtime reconciliation and behavioral probes support the following bounded observations:

- default-deny and explicit-deny authorization paths behaved as expected;
- a stale fencing token was rejected in the deployed runtime;
- mutation of an effect receipt was blocked;
- mutation/deletion of append-only development-journal evidence was blocked;
- an actor/work mismatch was rejected without retained experimental residue;
- recovery-capsule reconstruction returned the tested closed/reconstructable state before resumed work.

A limitation remains: the canonical `world8_mason_pool_bind_execution_v1` path is source+runtime backed, but the frozen runtime did not contain a suitable active execution/assignment for a clean behavioral probe of that exact function. The paper therefore does not upgrade that specific binding path beyond its actual evidence level.

### 6.4 E4: mutations killed and compound faults contained in the tested model

The controlled reference mutation gate kills 5/5 mutations, for a mutation score of 1.0 under the frozen mutation set.

The compound-fault gate executes three frozen compound cases × 1,000 trials. The governed model reports a safe rate of 1.0 in each case, while the hardened baseline exposes the targeted failure in each corresponding case. Across the frozen valid normal, session-swap, and restart/reconstruct paths, the measured false-deny rate is 0.0.

The mutation score must not be read as a mutation score of the production PostgreSQL system; destructive mutation of the deployed production database was intentionally not performed.

### 6.5 E5: external-runtime composability

The successful external run executes 2,000 cases on a real pinned AutoGen Core 0.7.5 runtime.

| Frozen scenario family | Hardened AutoGen + generic controls | Same AutoGen + World-8-style governance |
|---|---:|---:|
| Valid paths | safe = 1.0 | safe = 1.0 |
| Revocation | safe = 1.0 | safe = 1.0 |
| Stale version / CAS | safe = 1.0 | safe = 1.0 |
| Duplicate / idempotency | safe = 1.0 | safe = 1.0 |
| Stolen approval | safe = 0.0 | safe = 1.0 |
| Stale fence | safe = 0.0 | safe = 1.0 |
| Audit tamper | safe = 0.0 | safe = 1.0 |
| Effect before recovery | safe = 0.0 | safe = 1.0 |

The governance-wrapped AutoGen configuration also preserves the frozen valid-path false-deny rate of 0.0 and records runtime-swap Actor continuity at 1.0 in the tested configuration.

The correct interpretation is composability: the tested World 8 governance controls can be layered over AutoGen Core and close the four frozen governance fault families. The result is not evidence that AutoGen is generally insecure, that AutoGen cannot implement equivalent application-level controls, or that World 8 generally outperforms AutoGen.

---

## 7. Discussion

### 7.1 What remains after a strong baseline

The evaluation deliberately makes the claim smaller. Once the baseline receives standard revocation, CAS, durable idempotency, approval checks, and durable audit, several apparent advantages disappear. This is a desirable result because it distinguishes a system-specific governance contribution from ordinary engineering hardening.

The remaining claim is therefore about a composition boundary: a persistent logical Actor independent of runtime identity, effect-time authority, fencing, tamper-evident evidence, and recovery gating, applied consistently across Society adapters.

### 7.2 Why the AutoGen result matters

If the World 8 controls only worked inside a proprietary execution engine, it would be difficult to distinguish architecture from implementation lock-in. E5 instead layers the frozen controls over an independent multi-agent runtime. This does not make AutoGen a weak baseline; on the contrary, its generic hardening already handles several fault families. The result suggests that the governance kernel can be treated as an orthogonal control layer rather than a replacement for the underlying agent runtime.

### 7.3 Identity continuity is narrower than identity theory

The paper does not attempt to solve philosophical or semantic identity. Logical Actor identity here is an engineering contract: an authority and attribution principal that survives permitted provider/session/runtime replacement. This narrower definition is testable and avoids conflating operational continuity with claims about personhood or consciousness.

### 7.4 Evidence integrity is not external trust

Tamper-evident receipts can expose the tested local mutation cases, but they do not create an external trust anchor by themselves. A stronger deployment could use external notarization, trusted timestamping, independent replicas, or hardware-backed keys; those are outside the frozen evaluation.

---

## 8. Threat and Failure Model

The frozen evaluation focuses on architectural and operational failure families rather than a complete adversarial-security proof.

Included families:

- provider/session/runtime replacement;
- actor-binding mismatch or impersonation-oriented execution;
- revoked or missing authority;
- stale writer/version;
- stale fencing token;
- duplicate externally visible intent;
- missing approval;
- evidence tamper;
- restart/recovery before new effect capability;
- selected compound combinations of these failures.

Not established by the current evidence:

- compromise of the database administrator or underlying cloud control plane;
- cryptographic key theft outside the tested binding model;
- arbitrary network partitions and distributed-consensus safety/liveness;
- Byzantine collusion among multiple infrastructure components;
- malicious model behavior that remains fully authorized by policy;
- semantic correctness of a domain decision;
- production-scale availability, latency, throughput, or cost.

---

## 9. Limitations

First, two Society adapters are insufficient to establish universal domain generality. The E2 result should be read as a conformance demonstration over two materially different tested adapters.

Second, E1/E2/E4 rely partly on an executable reference model. E3 narrows the source/runtime gap with canonical binding and behavioral probes, but the production PostgreSQL implementation was not destructively mutation-tested.

Third, the external baseline is pinned to AutoGen Core 0.7.5 and a frozen configuration. It does not characterize all AutoGen deployments, later versions, distributed AutoGen configurations, LangGraph, the OpenAI Agents SDK, or other frameworks.

Fourth, the current cost measurement counts governance checks and evidence records; it does not quantify wall-clock latency, throughput, storage amplification, or operating cost at production scale.

Fifth, the evidence concerns governance of effects, not the semantic quality of model reasoning. A fully authorized but poor decision can still be wrong.

Sixth, the current evidence does not establish formal completeness of the authorization policy, cryptographic non-repudiation against infrastructure compromise, or recovery under arbitrary storage corruption.

Finally, this paper is intentionally separated from W8-P02, which owns market forecasting/performance evidence. No market-performance result should be interpreted as evidence for the flagship architecture claims reported here.

---

## 10. Reproducibility and Evidence Governance

The paper uses an explicit evidence freeze rather than referring to a continuously moving development branch.

Frozen evidence base:

`34ed68b6e04c548e7ee14aa16e0e3eecdb1b31f0`

Freeze ref:

`freeze/w8-p01-evidence-v0.1`

The manuscript-side manifest is:

`docs/publications/W8_P01_EVIDENCE_FREEZE_v0.1.yaml`

The claim ledger is:

`docs/publications/W8_P01_CLAIM_LEDGER_v0.1.md`

Key frozen executions include:

- E1 hardened baseline: run `33103617400`;
- E2 two-Society conformance: run `33103973441`;
- E3 source integrity: run `33107476738`;
- E3 reconciled validators: run `33107662002`;
- E4 mutation: run `33107646035`;
- E4 compound faults: run `33108000278`;
- E5 external AutoGen baseline: public run `33109497608`.

Post-freeze project development is not automatically manuscript evidence. Any new numerical result must be explicitly admitted through a revised freeze rather than silently replacing a frozen result.

---

## 11. Conclusion

This paper evaluates a governed shared-kernel architecture for multi-agent systems under a deliberately bounded question: preserving logical Actor identity, authority, evidence integrity, stale-executor exclusion, and recovery invariants across runtime replacement and different Society adapters.

The strongest finding is not that every World 8 mechanism outperforms a baseline. In fact, once the baseline is hardened with standard revocation, CAS, idempotency, approval, and durable-audit mechanisms, several apparent advantages disappear. The remaining tested distinction lies in the composition of provider-independent Actor binding, effect-time authority, fencing, tamper-evident governance evidence, and recovery-before-effect.

The same frozen governance contract passes the selected invariant suite across Company and Trading adapters. Runtime probes bind several mechanisms to deployed canonical infrastructure, and scoped mutation/compound-fault tests exercise their failure boundaries. A pinned AutoGen Core experiment further shows that the evaluated governance controls can be composed over an independent multi-agent runtime, closing the four frozen governance fault families without changing the frozen valid-path result.

These findings support a scoped architectural contribution, not a universal superiority or production-security claim. Future work should expand the number of independently implemented Society adapters, evaluate isolated runtime mutations in disposable database environments, measure latency/storage/throughput costs, and subject the novelty boundary and failure model to external review.

---

## References

[1] M. Wooldridge and N. R. Jennings, “Intelligent agents: theory and practice,” *The Knowledge Engineering Review*, 10(2), 115–152, 1995. DOI: `10.1017/S0269888900008122`.

[2] Y. Shoham, “Agent-oriented programming,” *Artificial Intelligence*, 60(1), 51–92, 1993. DOI: `10.1016/0004-3702(93)90034-9`.

[3] R. S. Sandhu, E. J. Coyne, H. L. Feinstein, and C. E. Youman, “Role-Based Access Control Models,” *Computer*, 29(2), 38–47, 1996. DOI: `10.1109/2.485845`.

[4] C. G. Gray and D. R. Cheriton, “Leases: An Efficient Fault-Tolerant Mechanism for Distributed File Cache Consistency,” *SOSP 1989*, 202–210. DOI: `10.1145/74850.74870`.

[5] M. Burrows, “The Chubby lock service for loosely-coupled distributed systems,” *OSDI 2006*, 2006.

[6] S. Haber and W. S. Stornetta, “How to Time-Stamp a Digital Document,” *LNCS 537*, 437–455, 1991. DOI: `10.1007/3-540-38424-3_32`.

[7] K. M. Chandy and L. Lamport, “Distributed Snapshots: Determining Global States of Distributed Systems,” *ACM Transactions on Computer Systems*, 3(1), 63–75, 1985. DOI: `10.1145/214451.214456`.

[8] Q. Wu et al., “AutoGen: Enabling Next-Gen LLM Applications via Multi-Agent Conversation,” *COLM 2024*, 2024; arXiv:2308.08155. Current runtime documentation used by the experiment: AutoGen Core stable Python reference.

[9] LangChain, “LangGraph Persistence,” official LangGraph documentation. Feature-mapped as prior art for checkpoints, durable stores, and fault recovery; not used as a second executable baseline in the frozen manuscript.

[10] OpenAI, “OpenAI Agents SDK,” official documentation for agents, sessions, guardrails, human-in-the-loop mechanisms, and tracing. Feature-mapped as related work; not used as the primary executable baseline.

---

## AI-Assisted Work Disclosure — draft

AI-assisted tools were used for structured drafting, language editing, software/documentation support, literature discovery, experiment orchestration support, and consistency checking. The author reviewed the resulting material and remains responsible for the research design, claims, code, data choices, interpretation, citations, and final manuscript.
