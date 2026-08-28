# Operational Guardian v0.1 — Worklog / Re-entry Checkpoint

Date: 2026-08-28
Branch: `guardian-contract-v0.1`
Base: `main`
Status: DESIGN FROZEN / SCHEMA CANDIDATE + TEST SPEC WRITTEN / NO RUNTIME MIGRATION APPLIED

## Completed

- Read `START_HERE.md` and confirmed Resume-first / Crash-Safe rules.
- Read existing `docs/engineering/ENGINEERING_GUARDIAN.md` and established that it is a distinct advisory companion with `authority_effect=NONE`.
- Read `docs/engineering/N_MASON_POOL.md` and its runtime migration; current architecture targets 100 concurrent Mason workers and already reuses Actor/Execution/Authority/Admission/Lease truth.
- Read Engineering Guardian foundation migration and retained append-only/audit conventions without conflating advisory Guardian with Operational Guardian.
- Read `architecture/WORLD8_ARCHITECTURE.yaml` and existing contract layout.
- Created isolated branch `guardian-contract-v0.1`; no normal work was written directly to `main`.
- Added/retained human-readable contract `docs/engineering/OPERATIONAL_GUARDIAN_CONTRACT_V0_1.md` with status `DESIGN_FROZEN / NOT_IMPLEMENTED / NOT_EVIDENCED / NOT_DEPLOYED`.
- Added machine-readable canonical contract `architecture/contracts/guardian-operational-v0.1.yaml`.
- Added/retained `architecture/adr/ADR-0003-operational-guardian-boundary.md`.
- Added `architecture/contracts/operational-guardian-state-machines-v0.1.yaml` as compact machine-readable state/forbidden-power map.
- Added normative extended state-machine specification `docs/engineering/guardian-operational/STATE_MACHINES_v0.1.md`.
- Added `docs/engineering/guardian-operational/WRITER_MATRIX_v0.1.md`.
- Added current schema candidate `docs/engineering/guardian-operational/schema/operational_guardian_schema_candidate_v0.1.sql`; it is intentionally outside `supabase/migrations`.
- Added `tests/guardian/OPERATIONAL_GUARDIAN_ADVERSARIAL_PLAN_V0_1.md` and `tests/guardian_operational/NEGATIVE_TEST_MATRIX_v0.1.md`. These are specifications only; no PASS claim is made.
- Added static validator `scripts/validate_operational_guardian_contract.py` and wired it into `validate-architecture.yml` on this branch.

## Errors / diagnostics encountered

### 1. Resume Board runtime access unavailable in this connector session

Attempt to resolve live Resume Board / Supabase governed runtime state could not be completed through the available connector safety boundary. No runtime state was guessed and no migration/deploy was performed as a workaround.

Consequence: this branch contains design/schema/test artifacts only. Before runtime implementation, governed Resume/Work/Workspace/Admission/Lease state must be resolved through the live World 8 path.

### 2. Concurrent branch artifact overlap

Branch comparison showed additional Operational Guardian artifacts had been written concurrently on the same isolated branch. Existing files were read before any replacement. This confirmed that concurrent work must be reconciled rather than blindly overwritten.

Lesson: branch-local file existence must be checked under concurrent Mason work; `main` directory listing alone is insufficient.

### 3. `DUPLICATE_ASSIGNMENT_TRUTH_RISK`

An earlier draft at `supabase/drafts/20260828_world8_operational_guardian_schema_candidate_v01.sql` proposed a separate `public.world8_guardian_work_assignments` registry.

Repository inspection confirmed `public.world8_mason_assignments` already owns assignment identity/binding truth. A second assignment registry creates avoidable divergence risk.

Repair:

- keep `world8_mason_assignments` authoritative;
- use `world8_guardian_work_controls` as a 1:1 control/orchestration extension keyed by existing `assignment_id`;
- replace the earlier draft DDL with a `SUPERSEDED DRAFT` tombstone that points to the current schema candidate;
- retain this diagnostic instead of deleting the historical mistake.

### 4. `LEASE_NAME_AUTHORITY_AMBIGUITY_RISK`

Abstract Guardian design used the name ResourceLease, but World 8 already has authority-bearing Developer Lease v3 in `world8_dev_leases`.

Repair:

- preserve `world8_dev_leases` as authoritative for governed developer/code writes;
- name the Guardian-only object `world8_guardian_capacity_leases`;
- explicitly state that Guardian capacity/semantic leases grant no developer/canonical write authority.

## Explicitly not done

- No Supabase DDL/migration applied.
- No Operational Guardian runtime tables/RPCs created.
- No Guardian kernel implementation written.
- No Advisor integration written.
- No live budget/quarantine/failover behavior claimed.
- No adversarial or mutation test executed against runtime code.
- No deploy performed.
- No merge to `main` performed.

## Current evidence ceiling

`DESIGN_ONLY`

Static contract validation, once CI runs, is documentation/conformance evidence only; it must not be described as runtime implementation evidence.

## Known constraints / do not do

- Do not overwrite or reinterpret existing Engineering Guardian as Operational Guardian.
- Do not create a sixth architectural Plane.
- Do not create second Actor/Work/Workspace/Authority/Assignment/Developer-Lease truth stores.
- Do not let Operational Guardian create/mutate/resolve GapSignal.
- Do not make Guardian a Candidate evaluator or Promotion/Authority engine.
- Do not treat external-effect allowance as authorization.
- Do not introduce a global Operational head.
- Do not claim Spine and Operational Ledger are cross-ledger linearizable/atomic.
- Do not combine SHARDED and REDUNDANT_N in v0.1.
- Do not reset original deadline on provider switch.
- Do not apply a runtime migration before governed re-entry/admission/lease is resolved.

## Next safe action

1. Open a Draft PR from `guardian-contract-v0.1` to `main` so CI/static contract validation can run without merge.
2. Review CI result; any validator failure becomes Diagnostic Memory/worklog evidence, not a silent patch.
3. Re-enter through live World 8 Resume/Work path and resolve/create governed Work, isolated Workspace, Session, Authorization, Admission and write Lease for actual implementation.
4. Resolve live DB role inventory and exact service-principal names before writing SECURITY DEFINER mutation RPCs or GRANT/RLS rules.
5. Convert negative test specifications into executable SQL tests against a disposable/dev database branch.
6. Only after executable forbidden-transition tests pass should the current schema candidate be promoted to a real migration candidate.

If interrupted here, start from this file plus `START_HERE.md` and `docs/engineering/guardian-operational/IMPLEMENTATION_CHECKPOINT.md`; do not reconstruct progress from chat memory.
