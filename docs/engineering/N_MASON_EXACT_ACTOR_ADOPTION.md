# World 8 N-Mason Exact Existing Actor Adoption v0.2

Status: FEATURE-BRANCH CANDIDATE / NOT DEPLOYED / NOT CANONICAL

## Problem

A Work item can already be canonically bound to a persistent Actor before a Mason Assignment exists. The generic `world8_mason_pool_reserve_v1` chooses the lowest available pool member, so it cannot safely guarantee reservation of that Work's existing Actor. Calling the normal bind function after reserving a different Actor correctly fails with `ASSIGNMENT_WORK_ACTOR_MISMATCH`.

The repair must not change `Work.actor_ref`, fabricate an Assignment outside the canonical Mason subsystem, or steal a live Assignment from another Work.

## Contract

`world8_mason_pool_reserve_exact_work_actor_v1` adds one narrow adoption path inside the existing Mason Pool/Assignment subsystem.

The function:

1. loads the existing Work and treats `world8_dev_work_items.actor_ref` as the canonical Actor source;
2. requires that exact Actor to be an ACTIVE member of the requested Mason pool;
3. locks that pool-member row so the generic reservation path cannot concurrently select the same Actor;
4. preserves provider as routing metadata only;
5. reuses `world8_actor_qualifications` for required qualification checks;
6. allows idempotent replay only when the already-live Assignment matches the exact pool + Work + Actor tuple;
7. fails closed if the Actor has another live Assignment;
8. fails closed if the Work has a live Assignment bound to a different Actor or pool;
9. requires a canonical Git head;
10. creates the Assignment directly as `WORK_BOUND`, because Actor and Work binding already exist canonically.

## Non-negotiable conflict rule

A live Assignment is never released, stolen, overwritten, or rebound by this function.

Expected conflict:

`ACTOR_ACTIVE_ASSIGNMENT_CONFLICT`

This is especially important when the target Actor is concurrently executing another engineering lane. The caller must wait for that lane to complete/release or choose another governed scheduling decision; the exact-adoption function does not mutate Work identity to work around capacity.

## Concurrency

The exact pool-member row is locked `FOR UPDATE`. Existing active-assignment unique indexes remain the final database-level protection. A race that still reaches an insert uniqueness conflict fails as:

`ASSIGNMENT_CONCURRENCY_CONFLICT_RETRY`

The caller may re-read canonical state and retry; it must not fabricate rows.

## Scope boundary

This patch only adds the exact-existing-Actor Assignment adoption primitive. It does not:

- change Actor identity;
- change provider/execution identity rules;
- bypass Academy Entry, Developer Admission, Authority, Lease/Fencing/CAS, CI, READY_FOR_REVIEW, or Merge Queue;
- deploy the SQL migration to production;
- release another lane's live Assignment;
- create a parallel assignment registry.

Production application of the migration requires a separately governed DB_TOUCHING recovery/deployment path.
