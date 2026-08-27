# World 8 N-Mason Pool v0.1

Status: IMPLEMENTED IN RUNTIME / VALIDATION IN PROGRESS / NOT YET CANONICAL-MERGED

## Purpose

World 8 must support **N concurrent engineering workers**. The design is not limited to 3 workers; 3 lanes are only the first pilot reservation. The current live pool is configured for target concurrency 100 and max members 500. Runtime contracts allow pools up to 1,000 target concurrency and 10,000 members.

Core rule:

> Parallelize work; serialize truth.

Workers may analyze and code concurrently. Canonical truth is still serialized through Work, Workspace, Authority, Admission, Lease/Fencing/CAS, PR/CI and the Merge Queue.

## Identity is not provider

A Mason Actor is persistent and provider-independent. `world8_actor_registry` remains the canonical Actor registry.

**Provider belongs to Execution, not Actor.** Provider/model/session belong to `world8_actor_executions`.

Therefore the same persistent worker identity can execute through OpenAI, xAI/Grok or another provider without changing identity. `provider_hint` on a pool assignment is routing metadata only; it does not prove that a provider execution exists.

Never claim a lane is live until an ACTIVE `world8_actor_executions` row has been created and bound to that assignment.

## Reused canonical systems

N-Mason does not create parallel truth stores for:

- Actor identity — reuse `world8_actor_registry`
- Provider execution — reuse `world8_actor_executions`
- qualification — reuse `world8_actor_qualifications`
- Work — reuse `world8_dev_work_items`
- Workspace — reuse `world8_dev_workspaces`
- Authorization — reuse `world8_authority_rules` + `world8_authorize_v1`
- Admission — reuse `world8_dev_admission_check_v2`
- Lease/Fencing/CAS — reuse Developer Lease v3 and DCP CAS
- Dispatch — reuse `world8_dispatch_*`
- Diagnostic Memory — reuse World 8 Diagnostic Knowledge Memory

The pool adds only capacity reservation/binding and a serialized merge queue.

## Per-worker lifecycle

1. Reserve an available Mason slot from a pool.
2. Connect the real provider/session and create an Actor Execution.
3. Run Mason Preflight and Diagnostic search.
4. Create Search Receipt and Work Claim.
5. Bind the Work to the reserved assignment.
6. Create an isolated Git branch/Workspace from current canonical head.
7. Bind the Workspace to the assignment.
8. Check required qualifications.
9. Obtain scoped authorization evidence.
10. Pass Developer Admission v0.2.
11. Acquire Lease v3 with fencing token.
12. Code only inside the isolated workspace.
13. Run tests and CI.
14. Mark the assignment READY_FOR_REVIEW.
15. Enqueue the candidate in the Merge Queue.
16. Rebase/refresh if canonical head advanced.
17. Serialize canonical merge through one merge claim.
18. Record immutable merge receipt.
19. Change Propagation, Handoff, Postflight, release leases/execution/assignment.
20. Record errors and reusable experience in Diagnostic Memory.

## Pool contracts

Runtime tables:

- `world8_mason_pools`
- `world8_mason_pool_members`
- `world8_mason_assignments`

Important RPCs:

- `world8_mason_pool_create_v1`
- `world8_mason_pool_provision_v1`
- `world8_mason_pool_reserve_v1`
- `world8_mason_pool_bind_work_v1`
- `world8_mason_pool_bind_execution_v1`
- `world8_mason_pool_bind_workspace_v1`
- `world8_mason_pool_mark_ready_v1`
- `world8_mason_pool_release_assignment_v1`
- `world8_mason_pool_snapshot_v1`

Reservation uses `FOR UPDATE SKIP LOCKED`, active-assignment uniqueness and TTL expiry. Required qualifications are checked against active, non-expired qualification evidence before a slot can be reserved.

A Workspace on `main` or `master` is forbidden.

## Serialized Merge Queue

Runtime tables:

- `world8_merge_queue`
- `world8_merge_receipts`

Important RPCs:

- `world8_merge_enqueue_v1`
- `world8_merge_refresh_v1`
- `world8_merge_claim_next_v1`
- `world8_merge_complete_v1`
- `world8_merge_queue_snapshot_v1`

Rules:

- candidate must be READY_FOR_REVIEW
- exact Actor/Work/Workspace binding is required
- CI PASS is required for QUEUED state
- stale canonical base becomes `STALE_REBASE_REQUIRED`
- overlapping `touches` are recorded as conflict references
- canonical merge uses an advisory single-writer lock
- after one merge advances canonical head, other old-base candidates become stale
- successful canonical merges create immutable append-only receipts

## GitHub branch-protection hard gate

The runtime Merge Queue intentionally refuses a merge claim when the canonical Git resource does not report branch protection/ruleset enforcement.

Current expected failure while protection is absent:

`GITHUB_BRANCH_PROTECTION_REQUIRED`

This is not a warning. It is a fail-closed merge gate.

Workers may still be provisioned, admitted and code on isolated branches, but the N-Mason automatic canonical merge path must remain locked until GitHub protection is independently enabled and re-verified.

## Credentials

No raw passwords, API keys, OAuth tokens, secret values or credential values may be stored in Pool/Assignment/Merge Queue rows.

Future external-provider execution must use a separate scoped Credential Broker / secret reference mechanism. Credentials must be least-privilege, temporary and revocable. A provider hint is never a credential.

## Live scale checkpoint — 2026-08-27

Pool: `pool-world8-engineering-main`

- target concurrency: 100
- max members: 500
- provisioned provider-independent Actor slots: 100
- pilot reserved slots: 3
- remaining available at pilot snapshot: 97

Pilot reservations:

- `W8-ROOM-A` -> OpenAI hint
- `W8-ROOM-B` -> OpenAI hint
- `W8-GROK` -> xAI hint

These three are **pilot reservations, not an architectural limit**. They are not proof of live provider execution. The xAI/Grok lane remains RESERVED until a real xAI execution is created and bound.

## Evidence checkpoint

Runtime checks already passed:

- 100 Actor slots provisioned in canonical Actor Registry
- provider stored as assignment hint, not Actor identity
- nonexistent required qualification fails closed
- Merge Queue claim fails closed while GitHub branch protection is UNCONFIGURED

## Non-negotiable invariants

1. Identity != provider/session/channel.
2. Qualification != authorization.
3. No second identity, authority, workspace or dispatch truth store.
4. No worker writes directly to canonical main.
5. Every write path uses Admission v0.2 + Lease v3 + fencing/CAS where applicable.
6. Concurrent coding is allowed; canonical merge is serialized.
7. Stale branches are re-evaluated after every canonical advance.
8. CI evidence is mandatory before merge eligibility.
9. Raw credentials are forbidden.
10. Every failure, workaround and reusable lesson enters Diagnostic Memory / Handoff / Postflight.
