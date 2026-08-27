# W8-P01 — Verified Related-Work / Prior-Art Registry

Date: 2026-08-27
Status: **VERIFIED-CORE / PRE-MANUSCRIPT**
Purpose: prevent novelty inflation and keep W8-P01 claims narrower than established agent/distributed-systems prior art.

## Binding rule

A mechanism appearing below under **Prior art / not ours** MUST NOT be presented as a World 8 invention or as evidence of general superiority.

W8-P01's candidate contribution is the **specific governed composition and contract boundary** tested in E1–E5, not the invention of agents, roles, leases, checkpoints, hash chains, or agent orchestration.

---

## 1. Intelligent-agent theory and architecture

**Wooldridge, M.; Jennings, N. R. (1995). _Intelligent agents: theory and practice_. The Knowledge Engineering Review 10(2):115–152.**
DOI: `10.1017/S0269888900008122`
Verified source: https://doi.org/10.1017/S0269888900008122

Prior art / not ours:
- the concept of intelligent agents;
- agent theory, agent architectures, and agent languages as established research categories;
- the general engineering problem of implementing properties specified for agents.

What W8-P01 may still study:
- whether a particular governed kernel preserves selected identity/authority/evidence/recovery invariants across materially different Society adapters and runtime replacements.

---

## 2. Agent-oriented programming, capabilities, decisions and obligations

**Shoham, Y. (1993). _Agent-oriented programming_. Artificial Intelligence 60(1):51–92.**
DOI: `10.1016/0004-3702(93)90034-9`
Verified source: https://www.sciencedirect.com/science/article/pii/0004370293900349

Prior art / not ours:
- agent-oriented programming;
- capabilities, decisions and obligations as agent-state/programming concepts;
- typed communication between agents.

What W8-P01 may still study:
- explicit separation of domain proposal/decision/effect objects under a shared governance contract, without claiming those abstract concepts themselves are new.

---

## 3. Role-based access control

**Sandhu, R. S.; Coyne, E. J.; Feinstein, H. L.; Youman, C. E. (1996). _Role-Based Access Control Models_. Computer 29(2):38–47.**
DOI: `10.1109/2.485845`
Verified sources:
- https://doi.org/10.1109/2.485845
- https://csrc.nist.gov/csrc/media/projects/role-based-access-control/documents/sandhu96.pdf

Prior art / not ours:
- roles as permission-management abstractions;
- role/permission association and role membership;
- systematic RBAC reference models.

What W8-P01 may still study:
- persistent Actor identity and exact effect-time subject/action/resource authorization binding across provider/runtime replacement.
- This is a narrower claim than inventing roles or access control.

---

## 4. Leases in distributed systems

**Gray, C. G.; Cheriton, D. R. (1989). _Leases: An Efficient Fault-Tolerant Mechanism for Distributed File Cache Consistency_. SOSP 1989:202–210.**
Preferred DOI: `10.1145/74850.74870`
Verified sources:
- https://dblp.org/rec/conf/sosp/GrayC89.html
- Crossref/OpenAIRE also exposes `10.1145/74851.74870` for the proceedings object; do not silently treat the two identifiers as separate works.

Prior art / not ours:
- time-bounded leases;
- lease-based fault-tolerance/consistency mechanisms;
- the general idea of lease expiry and reacquisition.

What W8-P01 may still study:
- the tested composition of lease generation/fencing with persistent Actor-bound authority and effect admission.

---

## 5. Distributed lock services

**Burrows, M. (2006). _The Chubby lock service for loosely-coupled distributed systems_. OSDI 2006.**
Verified source: https://research.google/pubs/the-chubby-lock-service-for-loosely-coupled-distributed-systems/

Prior art / not ours:
- distributed lock services;
- coarse-grained locking and reliable coordination storage for distributed systems;
- practical lease/lock coordination services.

What W8-P01 may still study:
- governance semantics layered around effect authorization, fencing and evidence; not the invention of distributed locks.

---

## 6. Cryptographic tamper-evident document chaining / timestamping

**Haber, S.; Stornetta, W. S. (1991; CRYPTO 1990). _How to Time-Stamp a Digital Document_. LNCS 537:437–455.**
DOI: `10.1007/3-540-38424-3_32`
Verified source: https://doi.org/10.1007/3-540-38424-3_32

Prior art / not ours:
- cryptographically linked/tamper-evident document histories;
- hash-based integrity evidence and secure timestamping lineage.

What W8-P01 may still study:
- using tamper-evident receipts as one component of a governed multi-agent effect/recovery contract.

---

## 7. Distributed snapshots and checkpoint/recovery lineage

**Chandy, K. M.; Lamport, L. (1985). _Distributed Snapshots: Determining Global States of Distributed Systems_. ACM TOCS 3(1):63–75.**
DOI: `10.1145/214451.214456`
Verified sources:
- https://www.microsoft.com/en-us/research/publication/distributed-snapshots-determining-global-states-distributed-system/
- https://doi.org/10.1145/214451.214456

Prior art / not ours:
- distributed snapshot/global-state algorithms;
- checkpointing as a distributed-systems technique;
- recovery/state reconstruction as a general problem.

What W8-P01 may still study:
- a governance recovery gate that withholds effect/write capability until the required governed state/evidence boundary reconstructs successfully.

---

## 8. AutoGen — modern multi-agent framework/runtime

**Wu, Q. et al. (2024). _AutoGen: Enabling Next-Gen LLM Applications via Multi-Agent Conversation(s)_. COLM 2024.**
Verified source: https://www.microsoft.com/en-us/research/publication/autogen-enabling-next-gen-llm-applications-via-multi-agent-conversation-framework/
Preprint lineage: arXiv `2308.08155`.

Current AutoGen Core documentation:
https://microsoft.github.io/autogen/stable/reference/python/autogen_core.html

Verified prior capabilities relevant to W8-P01:
- multi-agent composition/runtime;
- `AgentId` uniquely identifies an agent instance within a runtime, including distributed runtime;
- binding Agent instances to an `AgentRuntime`;
- agent save/load state APIs;
- asynchronous direct messaging and runtime-managed agent factories/lifecycle.

Prior art / not ours:
- modern multi-agent orchestration/runtime;
- runtime agent identifiers;
- agent state save/load;
- asynchronous message-driven multi-agent execution.

W8-P01 empirical relation:
- E5 executed a pinned real `autogen-core==0.7.5` runtime.
- Generic application hardening (revoke, CAS, idempotency) closed the corresponding generic fault families.
- Adding explicit Actor-bound authority, fencing, tamper-evident receipts and recovery-before-effect closed four additional frozen fault families.

Bounded interpretation:
- World 8 controls are **composable over AutoGen Core** in the tested configuration.
- Do NOT claim “World 8 beats AutoGen,” “AutoGen is insecure,” or that AutoGen cannot implement these controls at application level.

Evidence receipt:
`experiments/flagship_governance_v0_1/E5_AUTOGEN_EXTERNAL_BASELINE_RECEIPT.md`

---

## 9. LangGraph — persistence/checkpointing/fault recovery

Official persistence documentation:
https://docs.langchain.com/oss/python/langgraph/persistence

Verified prior capabilities:
- checkpointers persist thread graph state as checkpoints;
- stores provide cross-thread durable application data;
- persistence supports conversation continuity, human-in-the-loop, time travel and fault tolerance;
- persistent checkpointers are used when state must survive process restarts;
- Agent Server handles persistence infrastructure automatically.

Prior art / not ours:
- workflow checkpoints;
- thread-scoped persistence;
- durable application stores;
- generic fault recovery/resume after interruption;
- human-in-the-loop persistence.

Decision for W8-P01:
**No second executable LangGraph baseline is required for the current manuscript unless venue/reviewer feedback specifically demands it.**

Rationale:
1. AutoGen Core already provides a strong executable multi-agent-runtime baseline for the flagship research question.
2. W8-P01 is not a checkpoint-throughput or workflow-persistence benchmark.
3. LangGraph's documented persistence/fault-tolerance features are explicitly conceded as prior art, so excluding a second executable benchmark does not support a uniqueness claim about checkpointing/recovery.
4. A second framework implementation would materially expand scope without changing the frozen primary question.

This decision may be revisited if the final manuscript makes a claim specifically about workflow-persistence semantics beyond what the current related-work mapping supports.

---

## 10. OpenAI Agents SDK — orchestration, sessions, guardrails and tracing

Official documentation:
- overview: https://openai.github.io/openai-agents-python/
- sessions: https://openai.github.io/openai-agents-python/sessions/
- guardrails: https://openai.github.io/openai-agents-python/guardrails/
- tracing: https://openai.github.io/openai-agents-python/tracing/

Verified prior capabilities:
- agents, handoffs / agents-as-tools;
- guardrails around workflow inputs/outputs and tool calls;
- Sessions as persistent conversation-history memory across agent runs;
- human-in-the-loop mechanisms;
- built-in tracing covering model generations, tool calls, handoffs, guardrails and custom events.

Prior art / not ours:
- multi-agent delegation/handoffs;
- persistent session memory;
- guardrail concepts around agent/tool execution;
- workflow tracing/observability.

What W8-P01 may still study:
- a narrower governed effect contract in which persistent Actor identity, effect-time authorization, fencing and tamper-evident evidence remain distinct from LLM/session/runtime orchestration.

Do not imply these World 8 mechanisms are impossible to implement with the Agents SDK or another orchestration layer.

---

# Novelty boundary after related-work review

W8-P01 MUST NOT claim novelty for any single item below:
- agents / multi-agent systems;
- agent roles/capabilities/decisions;
- RBAC;
- leases;
- distributed locks;
- CAS/version checks;
- idempotency;
- checkpoints/snapshots;
- generic restart/recovery;
- hash chains/tamper evidence;
- session memory;
- tracing;
- guardrails;
- multi-agent runtime/orchestration.

## Candidate contribution that remains testable

The defensible contribution is the **governed composition** of:

1. persistent logical Actor identity that is not defined by provider/session/runtime identity;
2. effect-time authorization bound to that Actor and exact action/resource;
3. an explicit proposal/decision/effect separation that does not let domain proposals grant effect authority;
4. lease-generation/fencing semantics excluding stale effectors;
5. tamper-evident governance receipts;
6. a recovery gate withholding effect capability until governed state/evidence reconstruction passes;
7. the same conformance contract applied across materially different Societies;
8. evidence that the above controls can be composed over an independent external multi-agent runtime (AutoGen Core) rather than requiring an exclusive World 8 execution engine.

Even this composition is a **candidate architectural contribution**, not a universal novelty claim. The manuscript must compare it carefully against additional literature found during peer review and must phrase novelty as scoped/empirical unless a formal exhaustive prior-art review supports stronger language.

# Venue/scoping implication

For JAAMAS, frame the paper around:
- persistent agent identity vs runtime execution identity;
- governance of authority/effect boundaries across multi-agent Societies;
- cross-Society conformance;
- failure-mode experiments and external-runtime composability.

Do not frame the paper as a new distributed locking/checkpointing system.

For FGCS fallback, emphasize:
- control-plane/runtime composition;
- reproducibility/source-runtime binding;
- recovery/fencing/evidence integration;
- externally hosted runtime composition.

# Registry status

- classic agent foundations: VERIFIED
- access-control prior art: VERIFIED
- lease/lock prior art: VERIFIED
- tamper-evidence prior art: VERIFIED
- snapshot/recovery prior art: VERIFIED
- AutoGen modern framework: VERIFIED + EXECUTABLE E5 BASELINE
- LangGraph persistence/fault recovery: VERIFIED / FEATURE-MAPPED
- OpenAI Agents SDK orchestration/session/guardrail/tracing: VERIFIED / FEATURE-MAPPED

Overall: **PASS FOR MANUSCRIPT PREPARATION, subject to continued citation verification and post-draft novelty review.**
