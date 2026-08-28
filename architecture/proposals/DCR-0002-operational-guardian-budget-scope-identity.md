# DCR-0002 — Operational Guardian budget-scope identity repair

Status: ACCEPTED FOR v0.1 FAMILY ARTIFACT RECONCILIATION
Date: 2026-08-28
Affects: Operational Guardian BudgetEnvelope physical identity semantics
Trust/authority boundary change: NO
Schema identity change: YES

## Discovery

The current schema candidate identifies an envelope with:

`UNIQUE(society_id, project_id, pool_id, dimension_class, dimension_key)`

This is not a safe identity rule in PostgreSQL when `project_id` or `pool_id` is NULL. Ordinary UNIQUE semantics treat NULL values as distinct, so two rows representing the same Society-level or Project-level budget dimension can coexist.

That can create duplicate budget truth for one scope and dimension, which would make reservation/CAS accounting ambiguous.

## Decision

BudgetEnvelope identity MUST use a deterministic non-null scope identity rather than nullable foreign-key columns as the unique key.

Required logical fields:

- `society_id`
- `scope_kind` = `SOCIETY | PROJECT | POOL`
- `scope_ref` = canonical non-empty identifier for that scope
- `dimension_class`
- `dimension_key`

Effective natural identity:

`(society_id, scope_kind, scope_ref, dimension_class, dimension_key)`

`project_id` and `pool_id` may remain as routing/projection references, but they are not the uniqueness primitive.

Implementation may use an equivalent null-safe representation only if it is proven by executable negative tests. Plain nullable-column UNIQUE is forbidden.

## Invariants

1. Exactly one active logical envelope identity exists per Society + scope + dimension.
2. Cross-Society envelopes remain distinct even when `scope_ref` strings match.
3. `scope_ref` is non-empty and immutable for an envelope lineage.
4. Parent and child envelopes MUST belong to the same Society unless explicit World Governance creates a separately governed cross-Society transfer object; ordinary Guardian allocation cannot cross Society.
5. Reservation RPC MUST verify assignment Society equals envelope Society.
6. Changing nullable routing metadata (`project_id`, `pool_id`) cannot mint a second envelope for the same canonical scope identity.
7. Existing accounting invariant remains unchanged: `S + R + A = C + O`.

## Non-changes

This DCR does NOT change:

- Guardian authority;
- hard-ceiling ownership;
- Society isolation policy;
- accounting equations;
- Gap ownership;
- Selection/Promotion/HARD_REVOKE boundaries;
- external-effect authorization boundary.

## Evidence status

Design/schema correction only. No runtime migration, test PASS, or deployment evidence is implied.
