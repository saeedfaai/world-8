# DCR-0001 — Operational Guardian dispatch-slot idempotency repair

Status: ACCEPTED FOR v0.1 ARTIFACT RECONCILIATION
Date: 2026-08-28
Affects: `guardian-operational-contract-v0.1` schema/idempotency representation
Authority/trust boundary change: NO
Schema compatibility change: YES

## Discovery

During physical schema review, the proposed natural idempotency key was represented as:

`(gap_id, policy_version, assignment_kind, attempt_no)`

That key is insufficient for the already-frozen dispatch modes:

- `REDUNDANT_N` intentionally creates multiple independent solution assignments for the same Gap and attempt.
- `SHARDED` intentionally creates multiple WorkOrders under the same parent Gap.

Without an explicit dispatch/work slot identity, a valid parallel assignment can collide with another valid assignment and be incorrectly treated as a replay duplicate.

## Decision

Add immutable `dispatch_slot_key` to Operational WorkControl identity semantics.

Examples:

- SINGLE: `single`
- REDUNDANT_N: `redundant:1`, `redundant:2`, ...
- SHARDED: `shard:<work_order_id>`

The natural idempotency key becomes:

`(gap_id, policy_version, dispatch_slot_key, attempt_no)`

`assignment_kind` remains descriptive/policy metadata and is not relied on as the unique parallel slot identifier.

## Invariants

1. `dispatch_slot_key` is immutable after creation.
2. Within one Gap + policy version + attempt, each intended parallel lane has a distinct deterministic slot key.
3. Replaying the same semantic lane returns/rejects idempotently; it does not create a second assignment.
4. Guardian cannot invent an unbounded number of redundant slot keys beyond dispatch/circuit-breaker policy.
5. v0.1 still forbids `SHARDED x REDUNDANT_N` composition.

## Related artifact consistency repair

Soft Quarantine remains an orthogonal `QuarantineDecision` aggregate/overlay. `QUARANTINED` must not be used as a second core WorkAssignment lifecycle truth state.

## Evidence status

Design/schema correction only. No runtime migration, test PASS, or deployment evidence is implied.
