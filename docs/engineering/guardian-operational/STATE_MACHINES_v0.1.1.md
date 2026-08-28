# World 8 Operational Guardian — State Machine Corrective Revision v0.1.1

Status: DESIGN_FROZEN / NOT IMPLEMENTED / NOT EVIDENCED / NOT DEPLOYED
Base: `STATE_MACHINES_v0.1.md`
DCR: `architecture/proposals/DCR-0001-operational-guardian-dispatch-idempotency.md`

This file is a narrow corrective overlay. All v0.1 rules remain in force except where explicitly replaced below.

## 1. Effective WorkAssignment core lifecycle

Unchanged:

`PLANNED -> ASSIGNED -> ACTIVE -> COMPLETED | FAILED | CANCELLED | EXPIRED`

Soft Quarantine remains a separate operational overlay/aggregate. `QUARANTINED` is not a core WorkAssignment lifecycle state.

## 2. Effective dispatch-slot identity

Replace the v0.1 natural idempotency key:

`(gap_id, policy_version, assignment_kind, attempt_no)`

with:

`(gap_id, policy_version, dispatch_slot_key, attempt_no)`

`dispatch_slot_key` is immutable and deterministic.

Required forms for v0.1.1 implementation:

- SINGLE: `single`
- REDUNDANT_N: `redundant:<ordinal>`
- SHARDED: `shard:<work_order_id>`

`assignment_kind` remains descriptive/policy metadata and is not the unique lane identity.

## 3. Admission invariants

Before creating/binding a parallel WorkControl:

1. `dispatch_slot_key` must match the chosen dispatch mode.
2. The same Gap + policy + slot + attempt replay is idempotent.
3. A different valid redundant/shard slot must not collide with another slot.
4. REDUNDANT_N ordinal must be within the policy-approved `N` and circuit-breaker ceiling.
5. SHARDED slot must reference a WorkOrder in the validated decomposition plan.
6. v0.1 family still forbids combining SHARDED with REDUNDANT_N.

## 4. Quarantine projection invariant

A live SoftQuarantine may make an Assignment effectively blocked/draining without changing its core lifecycle state.

Derived views may expose labels such as `QUARANTINED_IMMEDIATE` or `QUARANTINED_DRAIN`, but these are projection labels, not WorkAssignment source-of-truth states.

## 5. Required additional negative tests

- replay same `dispatch_slot_key` -> no second assignment/control lane;
- create `redundant:1` and `redundant:2` under same Gap/attempt -> both allowed when policy N>=2;
- create redundant ordinal above approved N -> reject;
- create shard slot not present in validated decomposition -> reject;
- mutate `dispatch_slot_key` after creation -> reject;
- represent SoftQuarantine by changing WorkControl lifecycle to `QUARANTINED` -> conformance fail.

## Evidence ceiling

Design correction only. No runtime PASS claim.
