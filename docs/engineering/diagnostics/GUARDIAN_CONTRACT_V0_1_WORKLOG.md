# Operational Guardian v0.1 — Worklog / Re-entry Checkpoint

Date: 2026-08-28
Branch: `guardian-contract-v0.1`
Base: `main`
Status: ACTIVE DESIGN ARTIFACT WORK / NO RUNTIME MIGRATION APPLIED

## Completed

- Read `START_HERE.md` and confirmed Resume-first / Crash-Safe rules.
- Read existing `docs/engineering/ENGINEERING_GUARDIAN.md` and established that it is a distinct advisory companion with `authority_effect=NONE`.
- Read `docs/engineering/N_MASON_POOL.md`; current architecture targets 100 concurrent Mason workers and already reuses Actor/Execution/Authority/Admission/Lease truth.
- Read `architecture/WORLD8_ARCHITECTURE.yaml` and existing contract layout.
- Created isolated branch `guardian-contract-v0.1`; no normal work was written directly to `main`.
- Added `docs/engineering/OPERATIONAL_GUARDIAN_CONTRACT_V0_1.md` with status `DESIGN_FROZEN / NOT_IMPLEMENTED / NOT_EVIDENCED / NOT_DEPLOYED`.
- Added machine-readable `architecture/contracts/operational-guardian-v0.1.yaml`.
- Confirmed/retained `architecture/adr/ADR-0003-operational-guardian-boundary.md` on the branch.
- Added `architecture/contracts/operational-guardian-state-machines-v0.1.yaml` defining objects, writers, state machines, accounting invariants and forbidden powers.
- Added `tests/guardian/OPERATIONAL_GUARDIAN_ADVERSARIAL_PLAN_V0_1.md` with adversarial and mutation obligations. Tests are SPECIFIED only; none are claimed PASS.

## Errors / diagnostics encountered

### 1. Resume Board runtime access unavailable in this connector session

Attempt to resolve live Resume Board / Supabase governed runtime state could not be completed through the available connector safety boundary. No runtime state was guessed and no migration/deploy was performed as a workaround.

Consequence: this branch contains design artifacts only. Before runtime implementation, governed Resume/Work/Workspace/Admission/Lease state must be resolved through the live World 8 path.

### 2. ADR create returned GitHub HTTP 422 / `sha wasn't supplied`

Attempted to create `architecture/adr/ADR-0003-operational-guardian-boundary.md` and GitHub returned 422 indicating the path already existed / update required SHA. The branch was read instead of overwriting blindly. The existing ADR-0003 was found with the intended Operational-vs-Engineering Guardian boundary and was retained unchanged.

Lesson: always fetch a target path on the active branch before replacing architecture artifacts; do not assume main-branch directory listing is sufficient under concurrent work.

## Explicitly not done

- No Supabase DDL/migration applied.
- No Operational Guardian runtime tables/RPCs created.
- No Guardian kernel implementation written.
- No Advisor integration written.
- No live budget/quarantine/failover behavior claimed.
- No adversarial or mutation test executed.
- No deploy performed.
- No merge to `main` performed.

## Current evidence ceiling

`DESIGN_ONLY`

Do not upgrade this to implementation/runtime evidence because files exist in Git.

## Known constraints / do not do

- Do not overwrite or reinterpret existing Engineering Guardian as Operational Guardian.
- Do not create a sixth architectural Plane.
- Do not let Operational Guardian create/mutate/resolve GapSignal.
- Do not make Guardian a Candidate evaluator or Promotion/Authority engine.
- Do not treat external-effect allowance as authorization.
- Do not introduce a global Operational head.
- Do not claim Spine and Operational Ledger are cross-ledger linearizable/atomic.
- Do not combine SHARDED and REDUNDANT_N in v0.1.
- Do not reset original deadline on provider switch.
- Do not apply a runtime migration before governed re-entry/admission/lease is resolved.

## Next safe action

1. Re-enter through the live World 8 Resume/Work path and resolve/create the governed Work Item, isolated Workspace binding, Session, Authorization, Admission and write Lease for Operational Guardian implementation.
2. Validate the frozen design artifacts against the current canonical Git head in case `main` advanced after branch creation; rebase/refresh if stale.
3. Translate the frozen object/state-machine contract into a **draft SQL migration on the isolated branch only**. The migration must remain unapplied until review.
4. Add schema-level negative tests for writer separation, CAS, guardian_epoch fencing, budget overhang, idempotency, Society isolation and forbidden transitions.
5. Review the draft migration against existing N-Mason/Authority/Lease/Effect schemas to reuse existing truth and avoid second registries.
6. Only after tests/review and governed admission should a migration be considered for a development/runtime environment.

If interrupted here, start from this file plus `START_HERE.md`; do not reconstruct progress from chat memory.
