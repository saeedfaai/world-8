# A Governed Shared-Kernel Architecture for Persistent, Auditable Multi-Agent Societies Beyond the LLM Session

**JAAMAS working manuscript — W8-P01 v0.3**  
Status: **DRAFT / NOT SUBMITTED / EVIDENCE-BOUND / NOVELTY-HARDENED**  
Article type: **Regular Paper / Original Research**  
Evidence freeze: `freeze/w8-p01-evidence-v0.1`  
Frozen canonical commit: `34ed68b6e04c548e7ee14aa16e0e3eecdb1b31f0`

**Saeed Farokhi**  
Mechanical Engineering, University of Tehran, Tehran, Iran  
Corresponding author: Saeed.farokhi@ut.ac.ir

---

## Abstract

Large-language-model agent systems increasingly combine multiple agents, tools, persistent state, and external effects, while logical identity and authority may remain entangled with transient runtime or session objects. We evaluate World 8, an experimental shared governance kernel that separates a logical Actor from provider/session/runtime identity and combines effect-time authorization, fencing, tamper-evident evidence, and recovery-before-effect constraints. A falsification-oriented program first strengthens a session-scoped baseline with revocation checks, compare-and-swap versioning, durable idempotency, approval scope, and audit. In 98,000 reference-model trials, the hardened baseline matches World 8 on those generic mechanisms, narrowing the differentiated tested composition. The same kernel and eight-invariant suite are then applied to Company and Trading Society adapters for 1,000 trials each, producing identical all-pass conformance vectors without market-performance evaluation or live effects. Canonical-source/runtime probes confirm selected authorization, fencing, immutability, actor/work binding, and recovery behavior. A scoped mutation stage kills 5/5 controlled mutations, and compound-fault tests preserve the frozen valid paths without false denials. Finally, 2,000 cases execute on real AutoGen Core 0.7.5. Generic hardening closes revocation, CAS, and idempotency faults; a transparent World-8-style governance wrapper additionally closes the frozen stolen-approval, stale-fence, audit-tamper, and effect-before-recovery cases. The evidence supports a bounded, composable effect-governance architecture, not standalone novelty for agent identity/governance primitives, general framework superiority, or production readiness.

**Keywords:** multi-agent systems; agent identity; authorization; governance; fault recovery; agent runtime

---

## 1. Introduction

Modern multi-agent applications increasingly connect language-model agents to tools, databases, workflows, external services, and other agents. As these systems become more persistent, the distinction between a transient execution context and the logical entity to which authority and evidence are attributed becomes operationally important. A model provider may change, a process may restart, a session may be replaced, or an agent runtime may recreate an instance. None of those events necessarily implies that the domain principal represented by the system should change. Conversely, possession of a runtime object or copied approval material should not automatically grant durable authority to produce an external effect.

This paper considers the following research question:

> **Can one governed multi-agent kernel preserve persistent identity, explicit authority, auditable evidence/effect boundaries, and recovery invariants across materially different Societies while remaining independent of provider/session identity?**

The system studied here is called **World 8**. The name refers to an experimental architecture, not a claim of a new class of intelligence. The paper does not attempt to demonstrate general autonomous intelligence, profitability, production readiness, or universal security. Its focus is narrower: the composition and falsification of governance mechanisms around multi-agent effects.

The central architectural distinction is between a **logical Actor** and the transient provider/session/runtime context that executes on its behalf. The governed effect path combines explicit effect-time authorization, stale-executor exclusion through fencing, tamper-evident evidence, and recovery gating before new effect capability. Domain-specific semantics are introduced through Society adapters, while the governance kernel remains shared.

The novelty boundary is deliberately conservative. Governance and normative constraints in multi-agent systems have long-standing prior art; leases, access control, checkpoints, append-only/tamper-evident histories, actor runtimes, and orchestration are also established. Contemporary work additionally addresses topology-independent agent identity and verifiable delegation. The paper therefore does not claim to invent persistent agent identity, multi-agent governance, norms, authorization, fencing, provenance, recovery, or agent runtimes individually. The candidate architectural contribution is the **specific tested composition and effect contract**, together with a falsification-oriented evidence program that attempts to remove weaker apparent advantages.

The paper makes four bounded contributions:

1. **An effect-governance contract.** The evaluated architecture explicitly binds a logical Actor to effect-time Actor/action/resource authority and separates proposal or prediction from approval or decision and effect execution.
2. **A falsification-oriented evaluation.** A hardened baseline, ablations, mutation tests, compound faults, runtime negative controls, and valid-path false-deny checks narrow rather than inflate the claim.
3. **Cross-Society conformance evidence.** The same governed kernel and invariant suite are exercised across two materially different domain adapters without using domain-performance metrics as architecture evidence.
4. **External-runtime composability evidence.** The frozen controls are layered over a pinned real AutoGen Core runtime, testing whether the governance composition can remain orthogonal to the underlying multi-agent runtime.

---

## 2. Problem Definition and Design Goals

### 2.1 Logical Actor versus execution identity

A **logical Actor** is the domain principal to which authority, responsibility, and evidence attribution are bound in the evaluated architecture. A provider model, API credential, session, process, worker, or runtime `AgentId` may participate in executing work for that Actor but does not by itself define that Actor in World 8.

This is an architectural choice and evaluated property, not a claim that provider-independent identity is unprecedented. Contemporary identity work explicitly studies topology/provider-independent agent identity and cryptographically bound capabilities [13,14]. W8-P01 instead evaluates how a logical-Actor binding participates in a broader effect-governance composition.

Two failure directions motivate the tested contract:

- **identity loss:** replacing a provider/session/runtime accidentally breaks continuity of authority or attribution;
- **identity capture:** possession of a transient execution context is incorrectly treated as sufficient proof of the logical Actor's authority.

### 2.2 Proposal, decision, and effect are different objects

A domain object expressing information, prediction, or intent is not authority to produce an external effect. The generic contract is:

`PROPOSAL/PREDICTION != APPROVAL/DECISION != EFFECT/EXECUTION`

Two adapters are used in the conformance experiment:

- **Company Society:** `QUOTE_PROPOSAL != PURCHASE_APPROVAL != SUPPLIER_ORDER_EFFECT`
- **Trading Society:** `FORECAST != TRADE_DECISION != SYNTHETIC_ORDER`

The Trading adapter is used only as a governance/conformance domain. Predictive accuracy, calibration, market returns, risk-veto performance, and crypto/non-crypto forecasting results belong to a separate domain-specific paper (W8-P02; SSRN Abstract ID 7359740) and are not reused here as primary evidence.

### 2.3 Effect-time authorization

Authority is evaluated at the governed effect boundary against the relevant Actor/action/resource context. A proposal or prior approval object is evidence used by the governed path, not a universal bearer capability automatically authorizing future effects.

Authorization and normative governance are not claimed as new. Open MAS governance and norms expressing prohibited, permitted, and obligated actions are established research topics [11,12]. The question here is how effect-time authority participates in the evaluated composition.

### 2.4 Fencing stale effectors

A stale executor may retain credentials, local state, or previously valid coordination information after a lease or ownership transition. The evaluated architecture uses lease-generation/fencing semantics to reject the frozen stale-executor cases. Leases, locks, and fencing-style coordination are established distributed-systems mechanisms [4,5].

### 2.5 Tamper-evident evidence

Governed decisions and effects produce evidence receipts. The evaluated runtime includes append-only/chained development evidence and immutable effect-receipt guards. Hash-linked integrity histories have established prior art [6]; the paper studies their role inside the composed governance contract.

### 2.6 Recovery before resumed effect capability

A restarted or reconstructed system should not regain effect capability merely because a process is alive. The tested contract requires reconstruction of the governed state/evidence boundary before the frozen resumed-effect path is considered valid. Checkpointing and distributed recovery are established prior art [7]; the evaluated property is the **effect gate around recovery**, not checkpoint invention.

---

## 3. Architecture

### 3.1 Shared governance kernel

The evaluated kernel is intentionally domain-thin. It owns mechanisms intended to remain invariant across Societies:

- logical Actor/execution binding;
- authorization at the effect boundary;
- governed version/staleness checks;
- lease/fencing boundary;
- durable idempotency where required;
- evidence receipts and integrity checks;
- reconstruction/recovery gate.

Domain adapters provide Society-specific object labels and workflow semantics without redefining those invariants.

### 3.2 Society adapters

A Society adapter maps domain objects into shared governance stages. The E2 experiment uses two adapters deliberately different in domain semantics but structurally comparable at the governance boundary.

The Company adapter models a synthetic procurement/operational path. The Trading adapter models a synthetic forecast/decision/order path. Neither adapter performs a live external business effect in the frozen experiment.

### 3.3 Canonical source and runtime boundary

The architecture is not evaluated only as a Python reference model. E3 maps the measured mechanisms to canonical SQL/migration sources and deployed runtime functions. During this process, historical migration-source gaps were discovered. Missing authoritative migration statements were recovered from `supabase_migrations.schema_migrations.statements`, restored to canonical Git, and checked byte-for-byte against their authoritative stored source before admission into the evidence base.

This source/runtime reconciliation is treated as reproducibility evidence rather than hidden implementation cleanup.

---

## 4. Related Work and Novelty Boundary

### 4.1 Agent architectures and agent-oriented programming

Intelligent-agent theory and agent architectures predate modern LLM systems [1]. Agent-oriented programming, capabilities, decisions, obligations, and typed inter-agent communication are established topics [2]. W8-P01 therefore does not claim novelty for the agent abstraction, capabilities, decisions, obligations, or inter-agent organization.

### 4.2 Access control, governance, and normative multi-agent systems

Role-based access control provides systematic role/permission models [3]. More directly, da Silva et al. describe governance mechanisms for open multi-agent systems based on norms that specify actions agents are prohibited, permitted, or obligated to perform [11]. Vasconcelos et al. study distributed norm management, including run-time conflict handling and fault-tolerance/scalability motivations [12].

These works materially narrow the W8-P01 novelty boundary. The paper does not claim to introduce governance, normative constraints, permission/prohibition/obligation models, or distributed governance to MAS. Effect-time authorization is instead one component of the tested World 8 contract.

### 4.3 Leases, locks, evidence integrity, and recovery

Leases and distributed lock services are established fault-tolerance and coordination mechanisms [4,5]. Cryptographically linked/tamper-evident histories have a long lineage [6], while distributed snapshots/checkpointing are foundational recovery techniques [7]. None is claimed as an individual World 8 invention.

### 4.4 Modern multi-agent runtimes and persistence

AutoGen provides a multi-agent runtime, runtime agent identifiers, asynchronous messaging, lifecycle management, and state save/load APIs [8]. LangGraph documents persistent checkpoints, durable stores, and fault-recovery-oriented persistence [9]. The OpenAI Agents SDK provides orchestration, sessions, guardrails, human-in-the-loop mechanisms, and tracing [10].

The external E5 experiment therefore treats AutoGen as a real runtime on which application/governance controls may be layered, not as a straw-man framework.

### 4.5 Contemporary agent identity and verifiable delegation

Recent contemporaneous preprints directly address assumptions that would otherwise make the W8-P01 identity framing appear stronger than justified. Rodriguez proposes an `agent://` URI scheme intended to decouple agent identity from network topology/provider location, including stable references under migration and capability attestation [13]. Prakash's AIP combines verifiable agent identity, delegated/attenuated authorization, chained policy, transport bindings, and provenance-oriented completion records [14].

These preprints are not treated as peer-reviewed archival equivalents, but they are highly relevant contemporary prior work. Consequently, W8-P01 does **not** claim provider-independent identity, capability-bound identity, delegated agent authorization, or provenance as standalone novelty.

### 4.6 Open-ended coordination context in JAAMAS

Recent JAAMAS work studies coordination in open environments with changing partners and tasks using modular open policies [15]. That work is primarily a learning/coordination contribution rather than an effect-governance architecture, but it reinforces that open/changing-agent settings are established current research contexts. W8-P01 therefore does not claim novelty for “open MAS” or dynamic composition as such.

### 4.7 Revised contribution boundary

After the close prior-art review, the strongest defensible framing is the **evaluated composition and contract boundary**:

1. a logical Actor explicitly bound across transient execution contexts;
2. exact Actor/action/resource authorization at the governed effect boundary;
3. proposal/prediction separated from approval/decision and effect/execution;
4. stale effectors excluded by fencing;
5. governance evidence made tamper-evident;
6. effect capability withheld until the tested recovery boundary passes;
7. the same frozen conformance contract applied across distinct Societies; and
8. the controls composed over an independent AutoGen Core runtime.

The empirical contribution is the falsification-oriented evaluation of that composition. The paper does not make a universal “first,” “unique,” or exhaustive novelty claim.

---

## 5. Evaluation Method

### 5.1 Evidence ladder and freeze

The evaluation is staged to make stronger claims contingent on stronger evidence:

- **E1:** reference-model falsification, hardened baseline, and ablations;
- **E2:** cross-Society shared-kernel conformance;
- **E3:** canonical-source/runtime binding and behavioral negative controls;
- **E4:** controlled mutation, compound faults, recovery, and valid-path false-deny measurement;
- **E5:** independent external-runtime comparison using a pinned real AutoGen Core runtime.

The evidence used by this manuscript is frozen at canonical commit `34ed68b6e04c548e7ee14aa16e0e3eecdb1b31f0` and reference `freeze/w8-p01-evidence-v0.1`.

### 5.2 E1: hardened baseline and mechanism falsification

An initial weak baseline made several World 8 mechanisms appear uniformly advantageous. That result was explicitly rejected as insufficient evidence. A hardened session-scoped baseline was then constructed with revoke checks, compare-and-swap/stale-write rejection, durable idempotency, approval scoping, and durable audit.

The strong E1 run executes 98,000 trials across the governed model, hardened baseline, and controlled ablations/variants. The objective is to eliminate differences explained by generic hardening rather than maximize the number of World 8 wins.

### 5.3 E2: two-Society conformance

The same governed kernel and the same eight invariants are executed for 1,000 trials per Society. The frozen invariant families cover proposal-not-authority, valid approved effect, runtime/session replacement with logical-Actor continuity, stale-writer rejection, duplicate suppression, fencing, evidence-tamper detection, and restart/reconstruction before resumed effect. No market-performance metric is evaluated in this stage.

### 5.4 E3: source/runtime binding

E3 maps the experimental mechanisms to canonical source and deployed runtime objects. Behavioral probes are intentionally read-only or rollback-safe and do not perform a live business effect. The frozen probes cover default-DENY/explicit-DENY authorization behavior, stale fencing-token rejection, effect-receipt mutation blocking, append-only development-journal enforcement, actor/work mismatch rejection, and recovery-capsule reconstruction.

### 5.5 E4: mutation and compound faults

Five controlled mutations target the reference mechanisms for actor binding, version/CAS protection, fencing, idempotency, and evidence integrity. Mutation score is reported only for this executable reference model; production PostgreSQL functions are not deliberately mutated.

A separate compound-fault gate executes three frozen multi-fault schedules at 1,000 trials each and also measures false denial on valid normal, session-swap, and restart/reconstruct paths.

### 5.6 E5: external AutoGen baseline

The external baseline pins `autogen-core==0.7.5` and uses real `SingleThreadedAgentRuntime`, `AgentId`, and `RoutedAgent` execution. No LLM call or API key is required.

Two configurations are evaluated on the same frozen cases:

- **Hardened AutoGen + generic application controls:** revoke, version/CAS, durable idempotency, approval scope, and durable mutable audit.
- **The same AutoGen runtime + explicit World-8-style governance wrapper:** logical Actor binding, effect-time Actor authorization, fencing, tamper-evident evidence, and recovery-before-effect.

The E5 matrix comprises 100 trials per case × 10 scenarios × 2 variants = 2,000 runtime cases. Runtime recreation is real in the recovery cases. This comparison tests composability and frozen governance fault families, not general framework performance.

### 5.7 AI-assisted research and manuscript support

AI-assisted tools were used for structured drafting, language editing, software/documentation support, literature discovery, experiment-orchestration support, and consistency checking. The author reviewed the resulting material and remains responsible for the research design, claims, code, data choices, interpretation, citations, and final manuscript. No AI system is listed as an author. Frozen results are tied to executable receipts, code, runs, and hashes rather than accepted from generative output as evidence.

---

## 6. Results

### 6.1 E1: generic hardening removes several apparent advantages

The hardened baseline matches World 8 on revocation at effect time, CAS/stale-write rejection, durable idempotency, missing-approval rejection, and concurrent single-winner behavior in the frozen reference experiment. These mechanisms are therefore not treated as differentiated World 8 contributions.

The mechanisms that remain differentiated in the frozen reference model are logical Actor/authorization binding under session/runtime replacement and impersonation-oriented fault families, fencing/lease enforcement in stale-effector cases, and tamper-evident receipt verification.

The frozen valid-path reference instrumentation records approximately 7 policy checks and 9 evidence records for World 8 versus 6 checks and 8 evidence records for the hardened baseline. These counts are governance-operation counts, not wall-clock latency or production throughput measurements.

### 6.2 E2: identical conformance over Company and Trading adapters

**Table 1. Frozen two-Society conformance result**

| Metric | Company Society | Trading Society |
|---|---:|---:|
| Trials | 1,000 | 1,000 |
| Invariants | 8 | 8 |
| All invariant pass rates | 1.0 | 1.0 |
| Market performance evaluated | No | No |
| Live external effects | No | No |

The conformance vectors are identical. Within the frozen protocol, the same governed kernel preserves the selected invariants across the two adapters. This does not establish universal domain generality; it establishes cross-domain conformance for exactly two tested adapters and eight frozen invariants.

### 6.3 E3: canonical/runtime behavioral checks

The source/runtime reconciliation and behavioral probes support the following bounded observations: default-deny and explicit-deny authorization paths behaved as expected; a stale fencing token was rejected in the deployed runtime; mutation of an effect receipt was blocked; mutation/deletion of append-only development-journal evidence was blocked; an actor/work mismatch was rejected without retained experimental residue; and recovery-capsule reconstruction returned the tested closed/reconstructable state before resumed work.

A limitation remains: the canonical `world8_mason_pool_bind_execution_v1` path is source+runtime backed, but the frozen runtime did not contain a suitable active execution/assignment for a clean behavioral probe of that exact function.

### 6.4 E4: mutations killed and compound faults contained in the tested model

The controlled reference mutation gate kills 5/5 mutations, for a mutation score of 1.0 under the frozen mutation set.

The compound-fault gate executes three frozen compound cases × 1,000 trials. The governed model reports a safe rate of 1.0 in each case, while the hardened baseline exposes the targeted failure in each corresponding case. Across frozen valid normal, session-swap, and restart/reconstruct paths, the measured false-deny rate is 0.0.

The mutation score must not be read as a mutation score of the production PostgreSQL system; destructive mutation of the deployed production database was intentionally not performed.

### 6.5 E5: external-runtime composability

The successful external run executes 2,000 cases on a real pinned AutoGen Core 0.7.5 runtime.

**Table 2. Frozen external-runtime fault-family comparison**

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

The governance-wrapped AutoGen configuration also preserves frozen valid-path false denial at 0.0 and records runtime-swap Actor continuity at 1.0 in the tested configuration.

The correct interpretation is composability: the tested World 8 controls can be layered over AutoGen Core and close the four frozen governance fault families. The result is not evidence that AutoGen is generally insecure, that AutoGen cannot implement equivalent controls, or that World 8 generally outperforms AutoGen.

---

## 7. Discussion

### 7.1 The contribution becomes smaller as baselines and prior art become stronger

The evaluation deliberately makes the claim smaller twice. First, hardening the experimental baseline removes apparent advantages attributable to standard revoke, CAS, idempotency, approval, and audit mechanisms. Second, the close prior-art review removes standalone novelty claims for normative governance and provider/topology-independent agent identity.

What remains is not a single new primitive. It is an experimentally bounded **effect-governance composition** and the evidence program used to test it.

### 7.2 Why the AutoGen result matters

If the controls only worked inside an exclusive execution engine, architecture and implementation lock-in would be difficult to separate. E5 instead layers the frozen controls over an independent multi-agent runtime. AutoGen's generic hardening already handles several fault families; the World-8-style wrapper is evaluated only on the additional frozen effect-governance cases.

### 7.3 Actor continuity is an engineering contract, not a theory of identity

The paper does not attempt to solve philosophical or semantic identity. Logical Actor identity here is an engineering principal for authority and attribution under permitted runtime replacement. Contemporary provider/topology-independent identity work reinforces the need to describe this as an implementation/evaluation choice rather than an unprecedented identity concept.

### 7.4 Evidence integrity is not external trust

Tamper-evident receipts can expose the tested local mutation cases, but they do not create an external trust anchor by themselves. Stronger deployments could use external notarization, trusted timestamping, independent replicas, or hardware-backed keys; those are outside the frozen evaluation.

---

## 8. Threat and Failure Model

The frozen evaluation focuses on architectural and operational failure families rather than a complete adversarial-security proof.

Included families are provider/session/runtime replacement; actor-binding mismatch or impersonation-oriented execution; revoked or missing authority; stale writer/version; stale fencing token; duplicate externally visible intent; missing approval; evidence tamper; restart/recovery before new effect capability; and selected compound combinations.

The current evidence does not establish protection against compromise of the database administrator or underlying cloud control plane, cryptographic key theft outside the tested binding model, arbitrary network partitions and distributed-consensus safety/liveness, Byzantine collusion, malicious model behavior that remains fully authorized by policy, semantic correctness of a domain decision, or production-scale availability/latency/throughput/cost.

---

## 9. Limitations

Two Society adapters are insufficient to establish universal domain generality. E2 is a conformance demonstration over two materially different tested adapters.

E1/E2/E4 rely partly on an executable reference model. E3 narrows the source/runtime gap with canonical binding and behavioral probes, but the production PostgreSQL implementation was not destructively mutation-tested.

The external baseline is pinned to AutoGen Core 0.7.5 and a frozen configuration. It does not characterize all AutoGen deployments, later versions, distributed AutoGen configurations, LangGraph, the OpenAI Agents SDK, or other frameworks.

The cost measurement counts governance checks and evidence records; it does not quantify wall-clock latency, throughput, storage amplification, or operating cost at production scale.

The evidence concerns governance of effects, not semantic quality of model reasoning. A fully authorized but poor decision can still be wrong.

The current evidence does not establish formal completeness of authorization policy, cryptographic non-repudiation against infrastructure compromise, or recovery under arbitrary storage corruption.

The novelty review is not an exhaustive systematic literature review. In particular, the 2026 identity/delegation papers cited here are contemporaneous preprints. They are included to avoid overstating novelty, not to imply archival consensus.

Finally, this paper is intentionally separated from W8-P02, which owns market forecasting/performance evidence. No market-performance result should be interpreted as evidence for the flagship architecture claims reported here.

---

## 10. Reproducibility and Evidence Governance

The paper uses an explicit evidence freeze rather than referring to a continuously moving development branch.

Frozen evidence base: `34ed68b6e04c548e7ee14aa16e0e3eecdb1b31f0`  
Freeze ref: `freeze/w8-p01-evidence-v0.1`

The manuscript-side manifest is `docs/publications/W8_P01_EVIDENCE_FREEZE_v0.1.yaml`. The active novelty-hardened claim ledger is `docs/publications/W8_P01_CLAIM_LEDGER_v0.2.md`.

Key frozen executions include E1 hardened baseline run `33103617400`; E2 two-Society conformance run `33103973441`; E3 source-integrity run `33107476738`; E3 reconciled-validator run `33107662002`; E4 mutation run `33107646035`; E4 compound-fault run `33108000278`; and E5 external AutoGen public run `33109497608`.

Post-freeze development is not automatically manuscript evidence. Any new numerical result must be explicitly admitted through a revised freeze rather than silently replacing a frozen result.

---

## 11. Conclusion

This paper evaluates a governed shared-kernel architecture for multi-agent systems under a bounded question: preserving logical Actor attribution/authority, effect-boundary control, evidence integrity, stale-executor exclusion, and recovery invariants across runtime replacement and different Society adapters.

The strongest result is not that every mechanism outperforms a baseline or is individually new. A strong generic baseline removes several apparent advantages, and a close prior-art review removes standalone novelty claims for governance, normative control, and provider-independent identity. The remaining tested object is the composition of logical Actor binding, effect-time authority, fencing, tamper-evident governance evidence, and recovery-before-effect.

The frozen contract passes the selected invariant suite across Company and Trading adapters. Runtime probes bind selected mechanisms to deployed canonical infrastructure, scoped mutation/compound-fault tests exercise failure boundaries, and a pinned AutoGen Core experiment shows that the tested controls can be composed over an independent runtime while closing the four frozen governance fault families.

These findings support a scoped architectural/evaluation contribution, not a universal superiority, identity-first, governance-first, or production-security claim. Future work should expand independently implemented Society adapters, evaluate isolated runtime mutations in disposable database environments, measure latency/storage/throughput costs, and subject the contract and novelty boundary to external review.

---

## Statements and Declarations

### Author Contributions

Saeed Farokhi conceived the architecture and research question, defined the evaluation program, reviewed the software and evidence, interpreted the results, and takes responsibility for the manuscript. AI-assisted tools supported structured drafting, software/documentation work, literature discovery, experiment-orchestration support, and consistency checking under author review.

### Competing Interests

`[AUTHOR CONFIRMATION REQUIRED BEFORE SUBMISSION]`

### Funding

`[AUTHOR CONFIRMATION REQUIRED BEFORE SUBMISSION]`

### Data Availability

The W8-P01 evaluation uses synthetic governance scenarios rather than private operational or live-market data. Frozen evidence is identified by exact commit, workflow-run, artifact, and SHA256 receipts. A submission-ready public archival evidence package must be confirmed and linked before provider submission.

### Code Availability

A public, citable review package containing the manuscript-relevant experiment code and frozen receipts is required before JAAMAS submission so that reviewers do not depend on access to the private development repository.

---

## References

[1] Wooldridge, M., & Jennings, N. R. (1995). Intelligent agents: theory and practice. *The Knowledge Engineering Review*, 10(2), 115–152. https://doi.org/10.1017/S0269888900008122

[2] Shoham, Y. (1993). Agent-oriented programming. *Artificial Intelligence*, 60(1), 51–92. https://doi.org/10.1016/0004-3702(93)90034-9

[3] Sandhu, R. S., Coyne, E. J., Feinstein, H. L., & Youman, C. E. (1996). Role-Based Access Control Models. *Computer*, 29(2), 38–47. https://doi.org/10.1109/2.485845

[4] Gray, C. G., & Cheriton, D. R. (1989). Leases: An Efficient Fault-Tolerant Mechanism for Distributed File Cache Consistency. *Proceedings of SOSP 1989*, 202–210. https://doi.org/10.1145/74850.74870

[5] Burrows, M. (2006). The Chubby lock service for loosely-coupled distributed systems. *OSDI 2006*.

[6] Haber, S., & Stornetta, W. S. (1991). How to Time-Stamp a Digital Document. *Lecture Notes in Computer Science*, 537, 437–455. https://doi.org/10.1007/3-540-38424-3_32

[7] Chandy, K. M., & Lamport, L. (1985). Distributed Snapshots: Determining Global States of Distributed Systems. *ACM Transactions on Computer Systems*, 3(1), 63–75. https://doi.org/10.1145/214451.214456

[8] Wu, Q., Bansal, G., Zhang, J., Wu, Y., Li, B., Zhu, E., Jiang, L., Zhang, X., Zhang, S., Liu, J., Awadallah, A. H., White, R. W., Burger, D., & Wang, C. (2024). AutoGen: Enabling Next-Gen LLM Applications via Multi-Agent Conversations. *Conference on Language Modeling (COLM 2024)*. arXiv:2308.08155.

[9] LangChain. LangGraph Persistence, official documentation. `[FINAL ACCESS-DATE/FORMAT REQUIRED]`

[10] OpenAI. OpenAI Agents SDK documentation: agents, sessions, guardrails, human-in-the-loop, and tracing. `[FINAL ACCESS-DATE/FORMAT REQUIRED]`

[11] da Silva, V. T., Duran, F., Guedes, J., & de Lucena, C. J. P. (2007). Governing multi-agent systems. *Journal of the Brazilian Computer Society*, 13, 19–34. https://doi.org/10.1007/BF03192407

[12] Vasconcelos, W. W., García-Camino, A., Gaertner, D., Rodríguez-Aguilar, J. A., & Noriega, P. (2012). Distributed norm management for multi-agent systems. *Expert Systems with Applications*, 39(5), 5990–5999. https://doi.org/10.1016/j.eswa.2011.11.108

[13] Rodriguez, R. R. Jr. (2026). Agent Identity URI Scheme: Topology-Independent Naming and Capability-Based Discovery for Multi-Agent Systems. *arXiv preprint* arXiv:2601.14567. https://arxiv.org/abs/2601.14567

[14] Prakash, S. (2026). AIP: Agent Identity Protocol for Verifiable Delegation Across MCP and A2A. *arXiv preprint* arXiv:2603.24775. https://arxiv.org/abs/2603.24775

[15] Rother, D., Pajarinen, J., Peters, J., & Weisswange, T. H. (2025). Open-ended coordination for multi-agent systems using modular open policies. *Autonomous Agents and Multi-Agent Systems*, 39, 40. https://doi.org/10.1007/s10458-025-09723-7
