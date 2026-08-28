# DCR-0004 — Operational Guardian Hierarchical Envelope Allocation

Status: ACCEPTED FOR EFFECTIVE IMPLEMENTATION REVISION v0.1.4
Scope: schema/accounting realization only; no trust-boundary or authority expansion.

## Problem

The frozen design requires pre-funded child Budget Envelopes and reclaim to the same hierarchy. The v0.1-v0.1.3 schema family defines parent/child envelopes and `S + R + A = C + O`, but it has no explicit object representing the parent funds encumbered by a child allocation.

Without an allocation lineage, either:

1. child ceiling is created while parent available remains unchanged, allowing double allocation; or
2. parent `reserved` is changed without an auditable object explaining the encumbrance/reclaim.

Both are non-conformant with evidence-driven accounting.

## Decision

Add an Operational `EnvelopeAllocation` aggregate/projection.

An active child allocation is an encumbrance inside the parent `R` bucket. The parent accounting invariant remains unchanged:

`S + R + A = C + O`

where parent `R` includes both direct operational reservations and active child-envelope allocation encumbrances.

Required allocation identity:

- `allocation_id`
- `parent_envelope_id`
- `child_envelope_id`
- `society_id`
- `dimension_class`
- `dimension_key`
- `allocated_amount`
- `reclaimed_amount`
- `finalized_spend_amount`
- `state`
- `parent_envelope_version_at_allocate`
- `policy_version`
- Guardian epoch/fencing evidence

## Scalability rule

Child task settlement MUST NOT lock/update ancestors on every reservation/settlement.

While an allocation is ACTIVE, the parent keeps the full unfinalized allocation amount encumbered in `R`. Exact spend is tracked inside the child envelope.

Parent reconciliation occurs only on explicit allocation resize/reclaim/finalize operations, which are rare parent-level CAS operations:

- unused returned amount: parent `R -> A` (or reduces parent overhang first);
- finalized child spend: parent `R -> S`;
- allocation remains ACTIVE for any residual child funding.

This preserves the pre-funded hot-row avoidance property.

## Isolation and authority

- parent and child MUST have the same `society_id`;
- dimension class/key/unit MUST match;
- ordinary Guardian may allocate/reclaim only inside a pre-authorized parent ceiling;
- hard ceiling increases remain Governance-only;
- cross-Society allocation is forbidden;
- allocation does not grant developer/canonical write authority.

## Reconciliation invariant

For each active allocation:

`allocated_amount = reclaimed_amount + finalized_spend_amount + remaining_encumbered`

and `remaining_encumbered >= 0`.

The sum of active `remaining_encumbered` allocation amounts contributes to the parent envelope `reserved` bucket.

## Evidence / event sourcing

Allocation changes are fenced Operational Control Ledger events with per-allocation aggregate CAS/idempotency. Projection rows are derived operational state, not canonical Spine history.

## Consequences

- No silent double-counting of parent/child budget.
- No ancestor lock on every Mason spend.
- Reclaim/finalization becomes auditable and replayable.
- Runtime implementation gains one operational accounting object but no new authority boundary.
