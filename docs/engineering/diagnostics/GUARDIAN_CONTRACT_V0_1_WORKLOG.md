# Operational Guardian v0.1 — Worklog / Re-entry Checkpoint

Date: 2026-08-28
Branch: `guardian-contract-v0.1`
Base: `main`
Status: DESIGN FROZEN / CORRECTIVE DESIGN v0.1.1 ADDED / SCHEMA + TEST SPECS ONLY / NO RUNTIME MIGRATION APPLIED

## Completed

- Read `START_HERE.md` and confirmed Resume-first / Crash-Safe rules.
- Read existing `docs/engineering/ENGINEERING_GUARDIAN.md` and established that it is a distinct advisory companion with `authority_effect=NONE`.
- Read `docs/engineering/N_MASON_POOL.md` and its runtime migration; current architecture targets 100 concurrent Mason workers and already reuses Actor/Execution/Authority/Admission/Lease truth.
- Read Engineering Guardian foundation migration and retained append-only/audit conventions without conflating advisory Guardian with Operational Guardian.
- Read sequencer lease maintenance and retained expected-token CAS/fencing as an implementation pattern.
- Created isolated branch `guardian-contract-v0.1`; no normal work was written directly to `main`.
- Added/retained human-readable Operational Guardian contract with `DESIGN_FROZEN / NOT_IMPLEMENTED / NOT_EVIDENCED / NOT_DEPLOYED` status.
- Added machine-readable Operational Guardian contract, ADR boundary, state machines, Writer Matrix, schema candidate, adversarial/negative test specs and static validator.
- Reused `world8_mason_assignments` rather than creating a second assignment registry.
- Preserved `world8_dev_leases` as the authority-bearing developer write lease; Guardian capacity leases are explicitly non-authoritative.
- Draft PR #43 is open and remains Draft; it has not been merged.
- Added DCR-0001 after discovering parallel dispatch idempotency collision risk.
- Added effective corrective design revision `architecture/contracts/guardian-operational-v0.1.1.yaml`.
- Added `STATE_MACHINES_v0.1.1.md`, corrective schema overlay `operational_guardian_schema_candidate_v0.1.1.sql`, and `NEGATIVE_TEST_DELTA_v0.1.1.md`.

## Effective implementation baseline

Future implementation MUST be reviewed against:

1. historical/base Guardian v0.1 design artifacts;
2. `architecture/proposals/DCR-0001-operational-guardian-dispatch-idempotency.md`;
3. `architecture/contracts/guardian-operational-v0.1.1.yaml`;
4. `docs/engineering/guardian-operational/STATE_MACHINES_v0.1.1.md`;
5. `docs/engineering/guardian-operational/schema/operational_guardian_schema_candidate_v0.1.1.sql`;
6. `tests/guardian_operational/NEGATIVE_TEST_DELTA_v0.1.1.md`.

`v0.1.1` is the effective corrective revision for implementation. Runtime evidence remains NONE.

## Errors / diagnostics encountered

### 1. Resume Board runtime access unavailable in this connector session

Attempt to resolve live Resume Board / Supabase governed runtime state could not be completed through the available connector safety boundary. No runtime state was guessed and no migration/deploy was performed as a workaround.

Consequence: this branch contains design/schema/test artifacts only. Before runtime implementation, governed Resume/Work/Workspace/Admission/Lease state must be resolved through the live World 8 path.

### 2. Concurrent branch artifact overlap

Multiple workers modified the same isolated branch concurrently.

Observed failures:

- ADR create returned GitHub HTTP 422 (`sha wasn't supplied`) because the file already existed.
- schema update returned HTTP 409 SHA mismatch after another worker changed the file.
- static-validator update later returned another HTTP 409 SHA mismatch after concurrent modification.

Response: fetch current branch bytes/SHA before every reconciliation; never force-overwrite stale content.

### 3. `DUPLICATE_ASSIGNMENT_TRUTH_RISK`

An earlier draft proposed `public.world8_guardian_work_assignments` as a second assignment registry.

Repair:

- `world8_mason_assignments` remains assignment identity/binding truth;
- `world8_guardian_work_controls` is a 1:1 control/orchestration extension keyed by existing `assignment_id`;
- old draft is retained only as a `SUPERSEDED DRAFT` diagnostic marker.

### 4. `LEASE_NAME_AUTHORITY_AMBIGUITY_RISK`

Abstract ResourceLease naming could be confused with authority-bearing Developer Lease v3.

Repair:

- `world8_dev_leases` remains authoritative for governed developer/code writes;
- Guardian object is named `world8_guardian_capacity_leases` and grants no developer/canonical write authority.

### 5. `WORKCONTROL_QUARANTINE_STATE_DUPLICATION_RISK`

A draft represented `QUARANTINED` as WorkControl lifecycle state while frozen design defines Soft Quarantine as a separate aggregate/overlay.

Repair now present in branch artifacts:

- WorkAssignment/WorkControl core lifecycle excludes `QUARANTINED`;
- Soft Quarantine remains separate IMMEDIATE/DRAIN overlay in `world8_guardian_quarantine_decisions`;
- effective v0.1.1 explicitly forbids reintroducing quarantine as core lifecycle truth.

### 6. `DISPATCH_IDEMPOTENCY_PARALLEL_LANE_COLLISION`

Original natural key `(gap_id, policy_version, assignment_kind, attempt_no)` could collide with valid REDUNDANT_N or SHARDED parallel lanes.

Repair via DCR-0001 / v0.1.1:

- immutable deterministic `dispatch_slot_key` added;
- effective natural key becomes `(gap_id, policy_version, dispatch_slot_key, attempt_no)`;
- examples: `single`, `redundant:<ordinal>`, `shard:<work_order_id>`;
- policy/circuit breaker still limits valid slot creation;
- SHARDED x REDUNDANT_N remains forbidden in this contract family.

### 7. `FROZEN_ARTIFACT_RECONCILED_IN_PLACE_RISK`

Concurrent work reconciled DCR-0001 into current v0.1 contract/schema/state files even though the freeze rule says schema/trust-boundary changes require an explicit revision.

The content repair is correct, and Git history preserves the pre-reconciliation bytes, but relying only on in-place reconciliation would make the effective frozen revision ambiguous.

Resolution:

- do not attempt a destructive rollback of concurrent correct content;
- preserve DCR-0001 explicitly;
- create and use `guardian-operational-v0.1.1` as the effective implementation revision;
- future changes after this point require a new DCR/revision rather than silent in-place mutation.

### 8. `CI_RUNNER_OR_JOB_START_FAILURE`

Draft PR #43 triggered `validate-architecture` and `W8-P01 E3 Validation Gate` at earlier head `3a10d3cfe3c3651700e716795799249109fb759c`.

Observed facts:

- both concluded failure;
- jobs returned `steps=[]`, `runner_id=0`, empty runner name;
- job log retrieval returned `BlobNotFound`;
- no evidence exists that a Python validator step actually executed.

Do NOT classify that run as validator-logic failure. Re-check CI at a later head and distinguish runner-start failure from actual test failure.

## Explicitly not done

- No Supabase DDL/migration applied.
- No Operational Guardian runtime tables/RPCs created.
- No Guardian kernel implementation deployed.
- No Advisor integration deployed.
- No live budget/quarantine/failover behavior claimed.
- No adversarial or mutation test executed against runtime code.
- No runtime Gap/Observation FK invented.
- No merge to `main` performed.

## Current evidence ceiling

`DESIGN_ONLY / STATIC_CONFORMANCE_PENDING`

Even a successful static validator is documentation/conformance evidence only; it is not runtime implementation evidence.

## Known constraints / do not do

- Do not overwrite or reinterpret existing Engineering Guardian as Operational Guardian.
- Do not create a sixth architectural Plane.
- Do not create second Actor/Work/Workspace/Authority/Assignment/Developer-Lease truth stores.
- Do not invent a Gap/Observation FK until that schema actually exists.
- Do not let Operational Guardian create/mutate/resolve GapSignal.
- Do not make Guardian a Candidate evaluator or Promotion/Authority engine.
- Do not treat external-effect allowance as authorization.
- Do not introduce a global Operational head.
- Do not claim Spine and Operational Ledger are cross-ledger linearizable/atomic.
- Do not combine SHARDED and REDUNDANT_N in v0.1.x.
- Do not reset original deadline on provider switch.
- Do not treat Soft Quarantine as a WorkControl lifecycle truth state.
- Do not use the pre-DCR idempotency tuple for parallel dispatch.
- Do not apply a runtime migration before governed re-entry/admission/lease and live DB role inventory are resolved.

## Next safe action

1. Reconcile the static validator against effective v0.1.1 using the latest branch SHA; do not overwrite concurrent changes blindly.
2. Run/observe Draft PR #43 CI at the latest head and distinguish infrastructure-start failure from validator failure.
3. Re-enter through live World 8 Resume/Work path and resolve/create governed Work, isolated Workspace, Session, Authorization, Admission and write Lease for actual implementation.
4. Resolve live DB role inventory and exact service-principal names before SECURITY DEFINER mutation RPCs or GRANT/RLS rules.
5. Convert negative test specifications (including v0.1.1 delta) into executable SQL tests against a disposable/dev database branch.
6. Generate a fresh executable migration candidate from the effective v0.1.1 model; do not promote/copy the historical schema draft directly.
7. Only after executable forbidden-transition and mutation gates pass should runtime migration/deployment be considered.

If interrupted here, start from this file plus `START_HERE.md`, `IMPLEMENTATION_CHECKPOINT.md`, DCR-0001 and the v0.1.1 corrective contract; do not reconstruct progress from chat memory.
