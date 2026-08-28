# World 8 Operational Guardian — State Machines v0.1

Status: DESIGN_FROZEN / NOT IMPLEMENTED / NOT EVIDENCED / NOT DEPLOYED

This document is normative for schema and tests under `guardian-operational-contract-v0.1`.

Reconciliation note: DCR-0001 replaces the original parallel-lane idempotency representation with an immutable deterministic `dispatch_slot_key`. This is a schema compatibility repair, not a trust-boundary change.

## 1. WorkAssignment

Core lifecycle states:

`PLANNED -> ASSIGNED -> ACTIVE -> COMPLETED | FAILED | CANCELLED | EXPIRED`

Soft quarantine is an **orthogonal control overlay**, represented by the separate SoftQuarantine aggregate. `QUARANTINED` is not a second WorkAssignment truth state. A UI/projection may derive a blocked/quarantined display state from an active SoftQuarantine, but the WorkAssignment aggregate itself keeps its core lifecycle state.

Allowed transitions:

- `PLANNED -> ASSIGNED` only after deterministic policy validation.
- `ASSIGNED -> ACTIVE` only if all required BudgetReservation and capacity/resource-lease references are valid and fenced to the current Guardian epoch.
- `ACTIVE -> COMPLETED` only after worker completion evidence exists.
- `ACTIVE -> FAILED` on typed deterministic failure or exhausted retry policy.
- `ACTIVE -> CANCELLED` on governed/allowed cancellation.
- `ASSIGNED|ACTIVE -> EXPIRED` when assignment lease/deadline expires.
- Soft quarantine does not rewrite the lifecycle state; it changes allowed operations through the separate quarantine policy/aggregate.

Forbidden:

- activation without reservation/lease evidence;
- reactivation from terminal state;
- changing `gap_id` after creation;
- changing `society_id` after creation;
- changing `dispatch_slot_key` after creation;
- changing dispatch mode after activation;
- resetting original deadline on provider switch;
- creating a second assignment with the same natural idempotency key;
- using a WorkAssignment status mutation as a substitute for the SoftQuarantine aggregate.

Dispatch slot identity:

- SINGLE: `dispatch_slot_key=single`
- REDUNDANT_N: deterministic `dispatch_slot_key=redundant:<ordinal>`
- SHARDED: deterministic `dispatch_slot_key=shard:<work_order_id>`

The Guardian may not mint redundant slot keys beyond current redundancy/circuit-breaker policy.

Natural idempotency key:

`(gap_id, policy_version, dispatch_slot_key, attempt_no)`

`assignment_kind` remains descriptive/policy metadata; it is not the parallel-lane identity.

## 2. BudgetReservation

States:

`REQUESTED -> RESERVED -> ACTIVE -> SETTLED | RELEASED | FAILED | CANCELLED | EXPIRED`

Rules:

- Reserve requires CAS against the exact child-envelope version.
- Every reservation carries TTL and fencing token.
- Extension is dimension-specific.
- A stale fencing token cannot settle or extend.
- Provider switch never resets Deadline budget.
- Under envelope overhang, no new reservation is admitted.

Forbidden:

- reserve beyond child envelope without governed ceiling change;
- convert Spend into Capacity or Deadline budget;
- break an otherwise valid live reservation solely because Governance shrank the ceiling;
- settle more than reserved plus explicitly granted extension;
- reclaim already settled consumption.

## 3. ChildEnvelope accounting

Symbols:

- `C`: hard ceiling
- `S`: settled
- `R`: reserved
- `A`: available
- `O`: overhang

Invariant:

`S + R + A = C + O`

with:

`A >= 0`

`O >= 0`

New dispatch is allowed only when:

`O == 0` and sufficient `A` exists for the requested dimension.

Shrink semantics:

- settled history is immutable;
- live reservations remain valid until normal settlement/release/expiry;
- shrink increments envelope version;
- stale reserve CAS fails;
- released reservation under overhang returns to parent first until overhang is reduced;
- settled overhang requires governed ceiling increase or governed write-off.

## 4. Capacity / semantic resource lease

States:

`REQUESTED -> GRANTED -> ACTIVE -> RELEASED | EXPIRED | FENCED | FAILED`

This Guardian lease is an orchestration/capacity object only. It does **not** replace or grant the authority carried by existing governed Developer Lease v3 / `world8_dev_leases`.

Rules:

- acquire the full declared resource set atomically or acquire nothing;
- resource ordering key is global and deterministic;
- lock modes are READ / WRITE / EXCLUSIVE;
- semantic resource domains may be declared in addition to file/object resources;
- deadlock cycle detection is a second-line defense, not a substitute for ordered all-or-none acquisition.

Forbidden:

- partial lock acquisition followed by worker execution;
- stale epoch grant;
- treating a Guardian capacity lease as code/canonical write authority;
- lease extension after DRAIN quarantine;
- write/effect use after IMMEDIATE quarantine fencing.

## 5. Gap lifecycle

`GapSignal` itself is immutable and has no mutable status column.

Lifecycle is append-only through `GapLifecycleEvent` and projected into two axes.

Resolution axis:

- `OPEN`
- `STILL_VIOLATED`
- `RESOLVED`
- `SUPERSEDED`

Actionability axis:

- `ACTIVE`
- `SUSPENDED`
- `EXPIRED`

Only Observer may emit measurement-based resolution events. Governance may establish Observation Contract succession, but Guardian never resolves or supersedes a Gap by itself.

Rules:

- Work completion does not imply Gap resolution.
- Promotion does not imply Gap resolution.
- Re-measurement under the original predicate is required for `RESOLVED`.
- `BREAKING` Observation Contract succession may lead to `SUPERSEDED`.
- `STRICTER` or `RELAXED` succession does not auto-resolve the old Gap.
- A successor Gap is minted only after a fresh violating measurement under the successor contract.

## 6. Dispatch modes

### SINGLE

One deterministic dispatch slot (`single`) per Gap attempt.

### REDUNDANT_N

- parallel independent assignments use deterministic `redundant:<ordinal>` slots;
- default governed maximum N is 3 unless a later policy revision changes it;
- Guardian never selects the winning Candidate;
- `SelectionDecision` belongs to Evidence/Governance;
- Promotion cites the SelectionDecision.

### SHARDED

- one immutable parent Gap;
- decomposition creates WorkOrders, not new Gaps;
- each WorkOrder retains the same `parent_gap_id`;
- each shard assignment uses deterministic `shard:<work_order_id>` slot identity;
- dependency graph must be a DAG;
- decomposition must pass deterministic Guardian policy validation;
- v0.1 forbids REDUNDANT_N inside SHARDED execution.

## 7. Integrator Mason

Integrator remains proposal-only Development/Mason behavior.

Preconditions:

- shard completion contract satisfied;
- required shard candidates exist;
- required pre-gates complete;
- integration policy version fixed.

Output Candidate must contain `derived_from_candidate_ids`.

If semantic integration cannot be completed, produce `INTEGRATION_FAILED`; Guardian may re-dispatch or escalate according to deterministic policy.

Evaluator still evaluates the final Integrated Candidate independently.

## 8. Guardian leader / epoch

Guardian HA uses leader lease + monotonically advancing `guardian_epoch`.

Every control write carries the epoch and a fencing token.

On takeover, before new dispatch:

1. replay Operational Control Ledger from snapshot + later events;
2. restore still-valid soft quarantines;
3. audit stale assignments;
4. inherit assignments with valid lease, current policy and valid fencing;
5. fence expired/stale assignments;
6. refuse duplicate recreation when the natural idempotency key already exists.

Forbidden:

- accepting stale epoch writes;
- kill-all purely because of failover;
- losing quarantine state on takeover;
- allowing old Guardian replica to dispatch after a newer epoch exists.

## 9. Soft quarantine

Soft quarantine is a separate overlay/aggregate and never becomes a second WorkAssignment lifecycle state.

Modes:

### IMMEDIATE

- new dispatch: denied
- new writes: denied
- external effects: denied
- active write/effect leases: fenced now
- read/handoff: bounded TTL only

### DRAIN

- new dispatch: denied
- current safe work may continue within current lease
- lease extension: denied
- new resource acquisition: denied unless explicitly required for bounded safe handoff policy

Soft quarantine requires TTL and max-renewal policy. Permanent authority change is not a Guardian action.

`HARD_REVOKE` belongs to governed canonical authority paths.

## 10. Typed failure classes

Kernel failure classification uses a closed enum. Free-text LLM classifications are non-authoritative.

Initial design classes include:

- `PROVIDER_TRANSIENT`
- `PROVIDER_SECURITY`
- `MASON_DETERMINISTIC_FAIL`
- `MASON_POLICY_VIOLATION`
- `MASON_CREDENTIAL_SUSPECT`
- `RESOURCE_LOCK_TIMEOUT`
- `DEADLOCK_DETECTED`
- `BUDGET_EXHAUSTED`
- `DEADLINE_EXPIRED`

Unknown class in v0.1 => refuse unsafe continuation + Advisory/Escalation to Governance. Guardian does not invent a new class at runtime.

## 11. Retry budgets

Every WorkAssignment freezes distinct budgets at assignment creation:

- `repair_retry_budget`
- `provider_switch_budget`
- `timeout_budget`

Provider failure consumes provider-switch budget, not repair budget.

Original wall-time/deadline budget never resets because of provider switching.

Per-Gap circuit breaker additionally limits:

- `max_assignments`
- `max_concurrent_assignments`
- `max_failed_attempts`

Exceeding the circuit breaker produces escalation; it does not spawn unlimited Mason attempts.

## 12. Advisor

Advisor is optional.

`Advisor = NULL` must still permit deterministic Guardian operation.

`AdvisoryReceipt` is append-only and may only affect fields explicitly whitelisted and bounded by the current Guardian policy.

Forbidden advisory effects include:

- hard budget ceiling change;
- authority change;
- hard revoke;
- promotion;
- policy mutation;
- Observer suppression;
- external-effect authorization.

## 13. Cross-ledger citation

Spine and Operational Control never use distributed 2PC/XA and do not claim cross-ledger linearizability.

For any Spine action that relies on Operational evidence, the Spine record must cite exact Operational event/object bytes by ID, aggregate version and SHA-256.

Required assertion:

> At Spine append time, the cited committed Operational bytes with these hashes existed and formed the recorded decision basis.

Not asserted:

> Spine and Operational formed one globally linearizable snapshot.

Any cited Operational bytes must remain preserved in the Evidence Bundle after cold archival.

## 14. Society isolation

Default Operational Guardian queries are scoped to the current Society.

Forbidden:

- cross-Society budget borrowing;
- cross-Society quarantine expansion by a normal Guardian;
- world-wide Guardian query without explicit World governance scope.

Human Root / explicit World Governance may have wider visibility, but that wider visibility does not implicitly grant Guardian authority.

## 15. Forbidden-transition test requirements

Implementation is not eligible for evidence claims until negative tests demonstrate at minimum:

1. stale Guardian epoch write rejected;
2. duplicate natural dispatch-slot key rejected/idempotently returned;
3. activation without valid BudgetReservation rejected;
4. activation without required capacity/resource evidence rejected;
5. reservation with stale envelope version rejected;
6. reservation during overhang rejected;
7. settled spend cannot be reclaimed;
8. provider switch cannot reset deadline;
9. Advisor absence does not block deterministic dispatch;
10. Advisor cannot change hard ceiling/authority/promotion;
11. Guardian cannot resolve Gap;
12. Guardian cannot suppress Observer;
13. effect allowance cannot authorize effect;
14. HARD_REVOKE cannot be produced by Guardian role;
15. `SHARDED x REDUNDANT_N` rejected in v0.1;
16. failover inherits valid assignment without duplicate creation;
17. expired/fenced assignment cannot write;
18. cross-Society budget/quarantine operation rejected;
19. cited Operational bytes remain verifiable after archival simulation;
20. projection lag/corruption cannot create an accepted control transition inconsistent with committed ledger events;
21. two valid REDUNDANT_N slots for the same Gap/attempt do not collide;
22. two valid SHARDED slots for different WorkOrders do not collide;
23. replay of the same dispatch slot does not create duplicate Work;
24. SoftQuarantine enforcement does not rewrite core WorkAssignment lifecycle into `QUARANTINED`.

## 16. Evidence ceiling

This document is design evidence only.

No PASS, runtime deployment, security guarantee, scale guarantee or recovery claim may be inferred until executable schema, tests and runtime receipts exist.
