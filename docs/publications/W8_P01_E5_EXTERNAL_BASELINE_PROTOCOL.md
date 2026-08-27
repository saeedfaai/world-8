# W8-P01 — E5 External Framework Comparison Protocol

Date: 2026-08-27
Status: **FROZEN-CANDIDATE / IMPLEMENTATION NEXT**

## Objective

Test whether the remaining W8-P01 governance contribution survives comparison with an externally recognizable, non-trivial multi-agent runtime rather than a deliberately weak session-only baseline.

The comparison is **not** “World 8 beats framework X.” It asks which invariants are supplied by the runtime, which require application-level governance, and what failure modes remain when equivalent controls are added fairly.

## Primary executable external baseline: Microsoft AutoGen Core

Reason for selection:
- AutoGen Core is explicitly a multi-agent runtime rather than only a prompt-chain abstraction.
- Its official documentation describes an Actor-model runtime with agent identity/lifecycle management, asynchronous messaging, local/distributed runtimes, and security/privacy boundaries.
- Its distributed runtime manages communication and agent lifecycle across process boundaries.
- This makes it a materially stronger and more relevant external baseline for W8-P01 than a simple session-scoped orchestrator.

Comparison label in experiments:
`autogen_core_hardened_baseline`

### Fairness rule

We MUST NOT count absence of a World-8-specific control as an AutoGen “bug.”

Where AutoGen does not claim to provide application authorization, idempotency, CAS, or tamper-evident audit semantics, the baseline is allowed an explicit application-level hardened wrapper implementing those generic controls.

The comparison then asks whether the remaining World 8 mechanisms still differ:
- persistent domain Actor identity vs runtime execution/provider identity;
- actor-bound effect authorization;
- explicit lease/fencing boundary for stale executor exclusion;
- append-only tamper-evident governance evidence;
- recovery gate before regaining effect/write capability.

## Secondary durability baseline / related work: LangGraph

LangGraph is not treated as a weak baseline. Official documentation explicitly provides:
- checkpointer-backed thread persistence;
- restart from successful checkpoints after faults;
- human-in-the-loop interrupts/resume;
- pending-write handling;
- Agent Server task queue with a worker lease and at-most-one active run per thread.

Therefore W8-P01 MUST NOT claim that checkpointing, generic fault recovery, durable workflow state, or lease-based run scheduling are unique to World 8.

LangGraph will be used in E5 in one of two ways:
1. executable secondary baseline if implementation cost remains small and methodologically clean; or
2. explicit strong related-work comparator with feature/invariant mapping if executable parity would require proprietary/server infrastructure unrelated to the research question.

## Related orchestration reference: OpenAI Agents SDK

Official documentation provides agents, handoffs, sessions, guardrails, human-in-the-loop mechanisms, and tracing. It is useful related work for orchestration boundaries and observable agent workflows.

It is not the primary baseline because W8-P01's main question is a governed multi-agent kernel spanning persistent identity, authority, effect boundaries and recovery, while the Agents SDK deliberately exposes a smaller orchestration primitive set.

No inference should be made that the SDK lacks application-level controls that a developer can add externally.

## Shared test contract

The same domain-neutral test semantics will be applied wherever meaningful:

### Valid paths
- V1 normal approved effect
- V2 runtime/session replacement with same logical Actor
- V3 restart/recovery then valid effect

### Invalid/fault paths
- X1 stolen approval after identity/runtime swap
- X2 explicit revocation before effect
- X3 stale state/version write
- X4 duplicate effect retry
- X5 stale lease/fence after executor replacement
- X6 evidence tamper after commit
- X7 recovery attempt before governance state is reconstructed

## Required baseline hardening

Before comparing failure rates, AutoGen baseline receives generic controls that are not claimed as framework-native World 8 contributions:
- explicit approval token scoped to action/resource;
- revoke-at-effect-time check;
- CAS/version check;
- durable idempotency key;
- durable audit log.

These match the hardened conventional baseline already used in E1.

The following must NOT be silently added under another name unless explicitly reported as an experimental variant:
- persistent actor-bound authorization independent of runtime identity;
- fencing token tied to executor lease generation;
- hash-chained immutable governance receipt verification;
- recovery gate that withholds effect capability until canonical governance reconstruction passes.

If we add any of those, it becomes an ablation/augmented-baseline variant and must be labeled as such.

## Metrics

Primary:
- unauthorized effect rate
- stale effect/write acceptance rate
- duplicate effect rate
- tamper detection rate
- identity/attribution continuity rate
- recovery correctness rate
- false-deny rate on valid paths

Secondary cost:
- number of application-level governance controls added around the external runtime
- evidence records emitted per valid effect
- policy/guard checks per valid effect

Do not compare raw throughput/latency unless execution environments are controlled and the measurement is separately protocolized.

## Claim ceiling

Allowed if supported:
- identify which invariants are runtime-native, wrapper-supplied, or World-8-specific in the tested configuration;
- report bounded failure rates under the frozen schedules;
- report negative results if the external hardened baseline matches World 8.

Not allowed:
- “World 8 is superior to AutoGen/LangGraph/OpenAI Agents SDK” as a general statement;
- security claims outside tested fault families;
- production reliability claims;
- claims that a framework cannot implement the World 8 controls at application level.

## Exit criteria

- [ ] exact package/version frozen
- [ ] deterministic no-LLM AutoGen test fixture implemented
- [ ] same seed/fault schedules used
- [ ] baseline hardening documented
- [ ] valid-path false-deny measured
- [ ] negative/equal results retained
- [ ] machine-readable result + SHA256 receipt
- [ ] external-source citations captured in related-work registry
