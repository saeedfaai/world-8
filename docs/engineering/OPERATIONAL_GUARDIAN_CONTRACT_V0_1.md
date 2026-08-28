# World 8 Operational Guardian Contract v0.1

Status: **DESIGN_FROZEN / NOT_IMPLEMENTED / NOT_EVIDENCED / NOT_DEPLOYED**

## 1. Purpose and boundary

Operational Guardian is the deterministic control service that answers **"What may run?"** for governed multi-Mason work. It is not a sixth World 8 plane. It operates inside the existing Operational / Evidence-Governance boundaries and must not collapse the separation between Observer, Mason, Evaluator, Promotion Authority, and Canonical Spine.

This contract is distinct from `docs/engineering/ENGINEERING_GUARDIAN.md`. The existing Engineering Guardian remains a session companion with `authority_effect=NONE`; Operational Guardian is a deterministic orchestration/resource-governance contract. Neither is Canonical Authority.

Core path:

`Telemetry -> Observer -> immutable GapSignal -> Operational Guardian -> WorkAssignment -> Mason/Integrator -> Candidate -> Evaluator -> Selection/Promotion -> Spine -> Runtime -> Observer re-measurement`

## 2. Roles and rights

- **Observer — What happened?** Emits immutable GapSignal and append-only GapLifecycleEvent. Guardian cannot suppress telemetry, pause detectors, mint, mutate, resolve, supersede, suspend, or expire GapSignal.
- **Operational Guardian — What may run?** May triage, reserve resources, dispatch, pause/drain, soft-quarantine, select provider routing, enforce deterministic policy, and emit control events. It cannot create GapSignal, judge Candidate quality, select the winning REDUNDANT_N Candidate, promote, hard-revoke, change authority, authorize external effects, or hot-patch its policy.
- **Planner/Advisor — What might be a good plan?** Proposal-only. AdvisoryReceipt is optional, bounded, attributable, append-only, and non-authoritative. Kernel must remain fully live with Advisor absent.
- **Mason — How do we build/fix it?** Proposal-only Candidate production.
- **Integrator Mason — How do shard outputs become one Candidate?** Proposal-only. Deterministic assembler is preferred for mechanical composition; semantic integration uses Integrator Mason. Independence is risk-based.
- **Evaluator — Is it acceptable?** Independent quality verdict and EvaluationReceipt.
- **Evidence/Governance — Which accepted option may advance?** Owns SelectionDecision and governed changes including hard-ceiling changes and HARD_REVOKE.
- **Canonical Spine — What was accepted?** Accepted identity/authority/history/revision only.

## 3. Immutable Gap and lifecycle

`GapSignal` bytes are immutable and bind:
- `gap_id`
- `objective_version`
- `observation_contract_version`
- `resolution_predicate_hash`
- detector/version
- observation/data window
- evidence refs
- severity/risk metadata

Gap lifecycle is separate:
- `ResolutionStatus = OPEN | STILL_VIOLATED | RESOLVED | SUPERSEDED`
- `ActionabilityStatus = ACTIVE | SUSPENDED | EXPIRED`

Lifecycle is represented by append-only `GapLifecycleEvent` plus a derived view. Work completion never resolves a Gap. Only Observer may emit resolution results after re-measurement using the bound predicate/contract. Contract compatibility is versioned as `STRICTER | RELAXED | BREAKING`; no contract change auto-resolves historical GapSignal.

## 4. Dispatch modes

`SINGLE | REDUNDANT_N | SHARDED`

v0.1 rule: `SHARDED x REDUNDANT_N` is forbidden.

- SINGLE: one active solution lineage by default.
- REDUNDANT_N: policy-controlled, default max N=3 unless Governance allows higher. Guardian does not choose the winner. `SelectionDecision` belongs to Evidence/Governance.
- SHARDED: decomposition creates WorkOrders under one `parent_gap_id`; it does not create new GapSignals. Decomposition plan is proposal-only and must pass deterministic WorkOrder policy validation before dispatch.

Shard contracts freeze interface/resource/dependency/acceptance requirements before dispatch. Integration may start only after its CompletionContract is satisfied. Integrated Candidate records `derived_from[]`. `INTEGRATION_FAILED` returns to operational handling and never implies Gap resolution.

## 5. Operational Control Ledger

Operational truth uses a **partitioned append-only Operational Control Ledger**, not one global operational head.

Each aggregate has:
- `aggregate_type`
- `aggregate_id`
- monotonic `aggregate_version`
- CAS on expected version
- append-only events
- replayable state
- snapshots/projections as derived state

Control events include at least:
- `event_id`
- `aggregate_type`
- `aggregate_id`
- `aggregate_version`
- `event_type`
- `guardian_epoch`
- `policy_version`
- `correlation_id`
- `causation_event_ref`
- `issued_at`
- `recorded_at`
- `canonical_bytes_hash`
- `idempotency_key`

Ledger contains material control transitions, not high-rate telemetry, heartbeats, raw Mason logs, or raw latency samples.

When event store and projection are in the same PostgreSQL transaction: append + CAS + projection update are atomic. External projection uses transactional outbox + idempotent projector. Non-atomic dual-write is forbidden.

## 6. Cross-ledger consistency

Spine and Operational Ledger are never treated as one linearizable/atomic ledger. No logical distributed 2PC/XA is part of this contract.

Bridge = **citation + stable bytes/hash/version**.

A Spine decision depending on operational evidence must cite a `SpineCitationPack` containing exact operational event/object identifiers, versions, canonical-byte hashes, policy version, and relevant provenance. Frozen evidence bytes must remain available in the evidence bundle even after operational cold archival.

Claim allowed: "this Spine decision cited these committed operational bytes/versions."
Claim forbidden: "Spine and Operational state formed one atomic cross-ledger snapshot."

## 7. Guardian leadership, failover and fencing

Operational Guardian is deterministic and may be replicated.

- one active leader lease
- monotonic `guardian_epoch`
- every control write carries current epoch/fencing evidence
- stale epoch writes fail closed
- takeover performs stale-assignment audit before new dispatch
- valid assignments with valid leases and current policy are inherited, not killed by default
- expired/stale-fenced work is blocked
- idempotent assignment natural key prevents duplicate replay dispatch

Kernel must not depend on LLM Advisor availability.

## 8. Budget model

Three classes:
- **Spend**: money, tokens, compute units, external-effect allowance
- **Capacity**: Mason slots, Evaluator slots, Integrator slots, provider/resource/concurrency slots
- **Deadline**: max wall time, idle timeout, lease deadline

Provider switch never resets the original wall-time/deadline budget.

Hierarchical budgets use pre-funded, society-isolated child envelopes. Per-dispatch ancestor locking is forbidden. Parent allocation/extension may use infrequent CAS at parent level.

Hard ceiling increases are Governance-only. Guardian may approve WorkAssignment extension only inside an already authorized child envelope and only for the requested dimension/field.

### Envelope accounting

Let:
- `C = ceiling`
- `S = settled`
- `R = reserved`
- `A = available`
- `O = overhang`

Invariant:

`S + R + A = C + O`, with `A >= 0`, `O >= 0`.

New dispatch requires `O = 0` and sufficient `A`.

On shrink below `S + R`, live reservations remain valid until their lease semantics end; dispatch is blocked and overhang is explicit. Released reservation first repairs overhang/returns appropriately to parent policy; settled consumption is never silently undone. Settled overhang requires governed ceiling increase or governed write-off.

## 9. Reservation and retry

Budget/resource reservation is lease-based with TTL + fencing and is dimension-aware.

Reservation lifecycle and WorkAssignment lifecycle are separate aggregates.

Suggested WorkAssignment lifecycle:
`PLANNED -> ASSIGNED -> ACTIVE -> COMPLETED | FAILED | CANCELLED | EXPIRED`

Suggested reservation lifecycle:
`REQUESTED -> RESERVED -> ACTIVE -> SETTLED | RELEASED | EXPIRED`

Retry controls are frozen at assignment creation:
- `repair_retry_budget`
- `provider_switch_budget`
- `timeout_budget`
- `max_assignments`
- `max_concurrent_assignments`
- `max_failed_attempts`

Circuit-breaker breach escalates; it does not create unbounded retries.

## 10. Resource locking and deadlock prevention

Guardian acquires declared resource sets atomically using a deterministic global sort key. If all required locks cannot be acquired, no partial lock set is retained. Resource declarations may include file/repository areas, DB/schema objects, services, deployments, and semantic domains.

Cycle detection is a second-line detector for dependency deadlocks that could not be prevented by ordered acquisition.

## 11. Quarantine and authority boundary

`SOFT_QUARANTINE` is operational and temporary. `HARD_REVOKE` is governed/canonical.

Modes:
- `IMMEDIATE`: fence new write/effect/resource leases now; bounded read/handoff may remain.
- `DRAIN`: no new assignments or lease extensions; existing safe work may finish within its current lease.

Failure classification is a closed typed enum from deterministic error/gate/evaluator codes. LLM suggested class is advisory only.

Quarantine scope is a replay-deterministic pure function of `(failure_class, subject, policy_version, ledger_snapshot)`; Guardian does not invent blast radius.

Default queries and budget/quarantine scope are Society-isolated. Provider != Actor. Guardian cannot infer collusion without separately typed evidence. Guardian cannot hard-revoke identity/RoleBinding/credentials/authority ceiling.

Soft quarantine has TTL, review deadline, and bounded renewals. Human absence must fail closed only for new privileged/spend-expanding decisions; existing authorized work inside valid envelopes/leases need not globally hang.

## 12. External effects

`external_effect_allowance` is capacity/budget only. It is **not authorization**.

Actual external-effect authorization remains in the governed Effect/Spine path with its own authorization, outbox, attempt, receipt, reconciliation and idempotency rules.

## 13. Advisor contract

Advisor is optional. `Advisor = NULL` is valid.

`AdvisoryReceipt`:
- immutable/append-only
- provider/model/build attribution
- prompt-contract version
- input hash
- recommendation
- allowed field
- bounded range/confidence
- timestamp/expiry

Advisor cannot change policy, hard budget ceiling, authority, quarantine lifting, effect authorization, Gap lifecycle, Candidate verdict, or Promotion.

## 14. Policy location

Operational Guardian policy is versioned/governed truth. Guardian only reads the active `policy_version`; it cannot hot-patch itself. Policy change follows Proposal -> Review -> ADR -> Approval -> Frozen Policy Revision -> Runtime Projection.

## 15. Retention and recovery

Hot operational ledger may archive terminal aggregates according to a retention policy, but:
- append-only audit integrity must remain
- Spine-cited bytes stay in frozen evidence bundles
- replay/recovery remains possible from snapshot + subsequent events
- archive must not break citation verification

## 16. Forbidden transitions / powers

Forbidden in v0.1:
- Guardian creates/mutates/closes GapSignal
- Guardian suppresses Observer telemetry or Detector output
- Guardian evaluates Candidate quality
- Guardian creates SelectionDecision or promotes Candidate
- Guardian performs HARD_REVOKE
- Guardian increases a child hard ceiling
- Guardian treats effect allowance as effect authorization
- Guardian writes with stale `guardian_epoch`
- Guardian accepts LLM advice outside whitelisted bounded fields
- Guardian dispatches `SHARDED x REDUNDANT_N`
- provider switch resets timeout/deadline
- non-atomic dual write across event/projection systems
- cross-ledger linearizability/2PC claim
- cross-Society budget/quarantine by ordinary Guardian scope
- retry/assignment beyond circuit-breaker limits

## 17. Evidence status

This document freezes design only.

- Implementation: NOT_IMPLEMENTED
- Runtime migration: NOT_APPLIED
- Adversarial tests: NOT_RUN
- Mutation tests: NOT_RUN
- Deployment: NOT_DEPLOYED
- Evidence ceiling for this artifact: DESIGN_ONLY

Any implementation-discovered trust-boundary/schema change requires an explicit Design Change Request; the frozen contract must not be silently mutated.
