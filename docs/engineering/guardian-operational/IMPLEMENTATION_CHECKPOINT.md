# Operational Guardian v0.1 — Implementation Checkpoint

Checkpoint status: DESIGN FROZEN / SCHEMA CANDIDATE + TEST SPEC WRITTEN / IMPLEMENTATION NOT STARTED

Branch: `guardian-contract-v0.1`
Base: `main`
Repository: `saeedfaai/world-8`

## Completed

1. Read `START_HERE.md` and current architecture manifest.
2. Read existing `ENGINEERING_GUARDIAN.md` and confirmed it is a distinct advisory companion service with `authority_effect=NONE`.
3. Read current `N_MASON_POOL.md` and its live migration; existing provider-independent Mason identity/execution/work/workspace/lease truth must be reused.
4. Read Engineering Guardian foundation migration and reused its append-only/audit conventions without inheriting its advisory semantics as Operational authority.
5. Froze the new Operational Guardian design as a separate contract, not an overwrite of the existing Engineering Guardian.
6. Added machine-readable contract:
   - `architecture/contracts/guardian-operational-v0.1.yaml`
7. Added architecture decision:
   - `architecture/adr/ADR-0003-operational-guardian-boundary.md`
8. Added normative state-machine / forbidden-transition specification:
   - `docs/engineering/guardian-operational/STATE_MACHINES_v0.1.md`
9. Added writer/authority matrix:
   - `docs/engineering/guardian-operational/WRITER_MATRIX_v0.1.md`
10. Added schema candidate, intentionally outside `supabase/migrations`:
   - `docs/engineering/guardian-operational/schema/operational_guardian_schema_candidate_v0.1.sql`
11. Added negative/adversarial test matrix with 50 scenarios plus mutation families:
   - `tests/guardian_operational/NEGATIVE_TEST_MATRIX_v0.1.md`

## Current design/evidence status

`DESIGN_FROZEN / NOT_IMPLEMENTED / NOT_EVIDENCED / NOT_DEPLOYED`

No production migration, RPC, deployment, runtime PASS or scale/security claim has been made.

## Key implementation reuse decision

Do **not** create a second assignment registry.

- `world8_mason_assignments` remains the assignment identity/binding truth.
- `world8_guardian_work_controls` is designed as a one-to-one orchestration/control extension keyed by the existing assignment.

Do **not** create a second developer write-authority lease registry.

- `world8_dev_leases` remains authoritative for governed developer/code writes.
- proposed `world8_guardian_capacity_leases` cover only orchestration capacity/semantic resources and never grant code/canonical write authority.

These decisions prevent duplicate truth stores and preserve the current N-Mason / DCP boundary.

## Important existing-system boundary

Do not replace or silently widen the authority of `service-world8-engineering-guardian`.

- Engineering Guardian: advisory/context/evidence companion, authority NONE.
- Operational Guardian: deterministic resource/orchestration kernel under frozen policy; still not canonical authority.

## Known tool/runtime limitation encountered

During re-entry, live Resume Board access through the available connector path was not available in this session. Runtime Work/Session state was therefore NOT reconstructed or guessed from chat memory.

This limitation is recorded; it is not evidence that no active Work/Session exists.

## Errors / repaired assumptions recorded during this checkpoint

### Duplicate-assignment-truth risk

Initial abstract design used a new `WorkAssignment` object. Existing repository inspection showed `world8_mason_assignments` is already the assignment truth. Repair: model Operational WorkAssignment state as a one-to-one control extension instead of a new registry.

### Lease-name ambiguity risk

Abstract design used `ResourceLease`, which could be confused with authority-bearing Developer Lease v3. Repair: schema candidate names the new object `world8_guardian_capacity_leases` and explicitly states it grants no developer/canonical write authority.

These are retained as design diagnostics rather than erased after repair.

## Do not do next

- Do not apply the schema candidate to live Supabase yet.
- Do not move candidate SQL into `supabase/migrations` yet.
- Do not merge directly to `main`.
- Do not create a second Actor/Work/Workspace/Authority/Assignment/Developer-Lease registry.
- Do not let Guardian directly write accepted Spine authority/history.
- Do not make LLM Advisor required for liveness.
- Do not implement mutable Gap status on `GapSignal`.
- Do not add distributed 2PC between Operational Ledger and Spine.

## Next safe action

1. Open a Draft PR from `guardian-contract-v0.1` to `main` so the design/schema/test package is reviewable without merge.
2. Add a static contract validator for:
   - forbidden duplicate truth stores,
   - mandatory design status markers,
   - writer-matrix prohibitions,
   - presence of the negative test matrix.
3. Before executable migration, resolve live DB role inventory through the governed runtime path and define exact SECURITY DEFINER writer RPC boundaries.
4. Convert the 50 negative test specifications into executable SQL tests against a disposable/dev database branch.
5. Only after those tests exist should a real migration candidate be considered for governed application.

## Error / diagnostic logging rule

Every material implementation error, failed assumption, schema mismatch, migration failure, test failure, workaround and repair must be recorded while work happens. Do not erase repaired failures from history. Store concise operational facts and evidence; never store secrets or private chain-of-thought.
