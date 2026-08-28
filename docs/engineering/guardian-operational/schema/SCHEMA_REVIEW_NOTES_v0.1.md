# Operational Guardian v0.1 — Schema Review Notes

Status: REVIEW IN PROGRESS / NO RUNTIME MIGRATION
Date: 2026-08-28
Branch: `guardian-contract-v0.1`

## Reuse findings

1. `public.world8_mason_assignments` is already the authoritative Mason pool assignment/binding registry. Operational Guardian MUST NOT create a second assignment identity registry.
2. `public.world8_dev_leases` is already the governed developer write-authority lease system. Guardian capacity/semantic leases MUST NOT grant code/canonical write authority.
3. Actor, Execution, Work, Workspace, Qualification, Authorization and Admission truth already exist and must be referenced/reused.
4. Existing Engineering Guardian is a distinct advisory companion with `authority_effect=NONE`; it is not automatically the DB writer principal for Operational Guardian.
5. Existing sequencer maintenance already demonstrates expected-token CAS + fencing semantics that should be reused as a pattern for Guardian epoch/lease code.

## Observation integration gap

Repository search did not find an implemented `GapSignal` / Observation Contract table matching the frozen Guardian design.

Decision for v0.1 schema candidate:

- retain `gap_id` / `originating_gap_id` as evidence references;
- DO NOT invent a foreign key to a table that is not implemented;
- DO NOT create mutable Gap truth inside Operational Guardian;
- add a separate integration migration only after the Observation schema exists and is reviewed.

## Duplicate-truth diagnostic

An earlier draft proposed `public.world8_guardian_work_assignments`. This was superseded because it would duplicate the existing `public.world8_mason_assignments` assignment registry.

Current model:

`world8_mason_assignments` -> authoritative pool/Actor/Work/Execution/Workspace binding

`world8_guardian_work_controls` -> 1:1 Operational Guardian orchestration extension keyed by existing `assignment_id`

Diagnostic class: `DUPLICATE_ASSIGNMENT_TRUTH_RISK`

## Open consistency repair before executable migration

The current schema candidate still includes `QUARANTINED` in the `world8_guardian_work_controls.state` CHECK.

The frozen state-machine reconciliation defines Soft Quarantine as an orthogonal `QuarantineDecision` aggregate/overlay, not a second WorkAssignment lifecycle truth.

Required repair before migration promotion:

- remove `QUARANTINED` from WorkControl core lifecycle state;
- retain `ACTIVE/ASSIGNED/...` core state;
- derive quarantine/block status by joining/applying active `world8_guardian_quarantine_decisions`;
- IMMEDIATE/DRAIN enforcement must fence/limit operations without rewriting assignment lifecycle into a second quarantine truth.

This is an artifact consistency repair, not a new design decision.

## Privilege blocker

Exact Operational Guardian DB/service role inventory was not available through the governed runtime connector path in this session.

Therefore the candidate correctly omits final GRANT/RLS policy.

Before executable migration:

- resolve the actual service principal/role;
- deny direct anon/authenticated/Brain/Mason mutation;
- expose only narrow SECURITY DEFINER RPCs;
- re-check Society scope, policy version, guardian epoch/fencing, CAS, idempotency and state transition legality at commit time;
- do not treat broad service-role access as application authority.

## Required next schema step

Write/implement transactional RPCs in this order, on isolated branch only:

1. Guardian leader lease acquire/renew/takeover with expected epoch/fencing CAS.
2. Generic per-aggregate control append: expected aggregate version + current Guardian epoch + event/projection atomic transaction.
3. Budget envelope allocate/shrink and reservation reserve/settle/release with `S+R+A=C+O` invariant.
4. Capacity lease all-or-none acquisition/release with deterministic resource ordering.
5. WorkControl activation that requires valid reservation/capacity evidence and circuit-breaker allowance.
6. Soft quarantine IMMEDIATE/DRAIN enforcement as a separate overlay.
7. Failover stale-assignment audit/inherit path.

No PASS/evidence claim is allowed until executable negative tests exercise these paths and mutation tests kill the corresponding bypasses.
