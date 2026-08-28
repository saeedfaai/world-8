# Operational Guardian v0.1 — Worklog / Re-entry Checkpoint

Date: 2026-08-28
Branch: `guardian-contract-v0.1`
Base: `main`
Status: DESIGN FROZEN / EFFECTIVE CORRECTIVE DESIGN v0.1.2 / SCHEMA + TEST SPECS ONLY / NO RUNTIME MIGRATION APPLIED

## Completed

- Read `START_HERE.md` and confirmed Resume-first / Crash-Safe rules.
- Read existing `docs/engineering/ENGINEERING_GUARDIAN.md` and established that it is a distinct advisory companion with `authority_effect=NONE`.
- Read `docs/engineering/N_MASON_POOL.md` and runtime inventory; N-Mason reuses Actor/Execution/Authority/Admission/Lease truth and targets concurrent workers without parallel canonical truth.
- Read Engineering Guardian foundation conventions and retained append-only/audit patterns without conflating advisory Guardian with Operational Guardian.
- Read sequencer/lease conventions and retained expected-token CAS/fencing as an implementation pattern.
- Created isolated branch `guardian-contract-v0.1`; no normal work was written directly to `main`.
- Added/retained human-readable Operational Guardian contract with `DESIGN_FROZEN / NOT_IMPLEMENTED / NOT_EVIDENCED / NOT_DEPLOYED` status.
- Added machine-readable Operational Guardian contract, ADR boundary, state machines, Writer Matrix, schema candidate, adversarial/negative test specs and static validator.
- Reused `world8_mason_assignments` rather than creating a second assignment registry.
- Preserved `world8_dev_leases` as the authority-bearing developer write lease; Guardian capacity leases are explicitly non-authoritative.
- Draft PR #43 is open and remains Draft; it has not been merged.
- Added DCR-0001 after discovering parallel dispatch idempotency collision risk.
- Added corrective revision `guardian-operational-v0.1.1` plus state/schema/test deltas.
- Added DCR-0002 after discovering nullable BudgetEnvelope scope uniqueness risk.
- Added effective corrective revision `architecture/contracts/guardian-operational-v0.1.2.yaml`.
- Added `operational_guardian_schema_candidate_v0.1.2.sql` and `NEGATIVE_TEST_DELTA_v0.1.2.md` with OG-N64..OG-N73.
- Extended `scripts/validate_operational_guardian_contract.py` to check v0.1.2 and both DCRs.
- Read live runtime inventory through the connected Supabase path: Resume/Admission/Mason Pool/Engineering Guardian RPC families exist; no existing Workspace bound to branch `guardian-contract-v0.1` was found in the inspected state.

## Effective implementation baseline

Future implementation MUST be reviewed against the v0.1 family plus both corrective revisions:

1. historical/base Guardian v0.1 design artifacts;
2. `architecture/proposals/DCR-0001-operational-guardian-dispatch-idempotency.md`;
3. `architecture/contracts/guardian-operational-v0.1.1.yaml`;
4. `docs/engineering/guardian-operational/STATE_MACHINES_v0.1.1.md`;
5. `docs/engineering/guardian-operational/schema/operational_guardian_schema_candidate_v0.1.1.sql`;
6. `tests/guardian_operational/NEGATIVE_TEST_DELTA_v0.1.1.md`;
7. `architecture/proposals/DCR-0002-operational-guardian-budget-scope-identity.md`;
8. `architecture/contracts/guardian-operational-v0.1.2.yaml`;
9. `docs/engineering/guardian-operational/schema/operational_guardian_schema_candidate_v0.1.2.sql`;
10. `tests/guardian_operational/NEGATIVE_TEST_DELTA_v0.1.2.md`.

`v0.1.2` is the effective corrective revision for implementation. Runtime evidence remains NONE.

## Errors / diagnostics encountered

### 1. Runtime governed re-entry was initially unavailable, later partially resolved

Earlier in this session, the available connector path did not expose live Resume/Admission state and no runtime state was guessed.

Later, the connected Supabase path exposed the live World 8 RPC/table inventory. Read-only inspection confirmed the relevant Resume, Admission v2, Mason Pool and Engineering Guardian functions exist. It also showed no Workspace registered for `guardian-contract-v0.1` in the inspected state.

A separate active Engineering Supervisor Work/Workspace exists on `main`; it must NOT be reused as a fake branch binding for this implementation.

Remaining blocker: actual implementation still needs a governed branch-specific Mason assignment, Work, Workspace, Session, Authorization, Admission and Developer Lease before any runtime mutation/migration.

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

Repair:

- WorkAssignment/WorkControl core lifecycle excludes `QUARANTINED`;
- Soft Quarantine remains separate IMMEDIATE/DRAIN overlay in `world8_guardian_quarantine_decisions`;
- v0.1.1 explicitly forbids reintroducing quarantine as core lifecycle truth.

### 6. `DISPATCH_IDEMPOTENCY_PARALLEL_LANE_COLLISION`

Original natural key `(gap_id, policy_version, assignment_kind, attempt_no)` could collide with valid REDUNDANT_N or SHARDED parallel lanes.

Repair via DCR-0001 / v0.1.1:

- immutable deterministic `dispatch_slot_key` added;
- effective natural key becomes `(gap_id, policy_version, dispatch_slot_key, attempt_no)`;
- examples: `single`, `redundant:<ordinal>`, `shard:<work_order_id>`;
- policy/circuit breaker still limits valid slot creation;
- SHARDED x REDUNDANT_N remains forbidden in this contract family.

### 7. `FROZEN_ARTIFACT_RECONCILED_IN_PLACE_RISK`

Concurrent work reconciled DCR-0001 into current v0.1 contract/schema/state files after freeze.

Resolution:

- do not destructively roll back correct concurrent content;
- preserve DCR-0001 explicitly;
- use explicit revision markers (`v0.1.1`, then `v0.1.2`) for implementation/evidence attribution;
- future schema/trust-boundary changes require a new DCR/revision rather than silent in-place mutation.

### 8. `CI_RUNNER_OR_JOB_START_FAILURE`

Draft PR #43 repeatedly triggered `validate-architecture` and `W8-P01 E3 Validation Gate`, including later head `14f4012ac07fba00132f72a7b8331706167225e5`.

Observed facts on repeated runs:

- workflows concluded `failure` within a few seconds;
- jobs exposed no executable steps (`steps=[]`);
- no runner identity/log evidence showed the Python validator actually starting.

Do NOT classify these as validator-logic failures. They are currently execution-layer/runner-start failures. GitHub documentation notes that private-repository Actions can also be blocked by usage/billing or Actions configuration; exact account-level cause has not been proven from repository metadata.

### 9. `BUDGET_SCOPE_NULL_UNIQUENESS_RISK`

The base schema candidate used:

`UNIQUE(society_id, project_id, pool_id, dimension_class, dimension_key)`

Because `project_id` and `pool_id` are nullable, ordinary PostgreSQL UNIQUE semantics can permit multiple logical Society-level or Project-level envelopes with the same dimension.

Impact: duplicate budget truth can make reservation/CAS accounting ambiguous and permit oversubscription through parallel envelope identities.

Repair via DCR-0002 / v0.1.2:

- define deterministic non-null `scope_kind` + `scope_ref`;
- effective natural identity becomes `(society_id, scope_kind, scope_ref, dimension_class, dimension_key)`;
- nullable `project_id`/`pool_id` become routing/projection references, not uniqueness primitives;
- parent/child envelope Society must match;
- assignment/envelope Society must match before reservation;
- accounting invariant `S + R + A = C + O` is unchanged.

### 10. `GLOBAL_GUARDIAN_LEADER_SCOPE_REVIEW`

The current base schema candidate models `world8_operational_guardian_leader` with one global `guardian_key='operational-guardian'` row, while control/event state is Society-scoped and the contract requires Society isolation.

No repair has been applied yet. This is an open design-review question: decide whether one world-level leader is intentional or whether leadership/epoch must be partitioned by Society/control shard to avoid an unnecessary global serialization/failure domain. Do not silently alter this boundary without a DCR.

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

`DESIGN_ONLY / STATIC_CONFORMANCE_PENDING_EXECUTION`

Even a successful static validator is documentation/conformance evidence only; it is not runtime implementation evidence.

## Known constraints / do not do

- Do not overwrite or reinterpret existing Engineering Guardian as Operational Guardian.
- Do not create a sixth architectural Plane.
- Do not create second Actor/Work/Workspace/Authority/Assignment/Developer-Lease truth stores.
- Do not invent a Gap/Observation FK until that schema actually exists.
- Do not let Operational Guardian create/mutate/resolve GapSignal.
- Do not make Guardian a Candidate evaluator or Promotion/Authority engine.
- Do not treat external-effect allowance as authorization.
- Do not introduce a global Operational ledger head.
- Do not claim Spine and Operational Ledger are cross-ledger linearizable/atomic.
- Do not combine SHARDED and REDUNDANT_N in v0.1.x.
- Do not reset original deadline on provider switch.
- Do not treat Soft Quarantine as a WorkControl lifecycle truth state.
- Do not use the pre-DCR idempotency tuple for parallel dispatch.
- Do not use nullable project/pool routing columns as BudgetEnvelope identity.
- Do not apply a runtime migration before governed re-entry/admission/lease and live DB role inventory are resolved.

## Next safe action

1. Reconcile PR/static validator against effective v0.1.2 using latest branch SHA.
2. Resolve the open Guardian leader scope question; if schema identity/fencing semantics change, record DCR-0003 and v0.1.3.
3. Register a governed branch-specific Mason assignment + Work + Workspace + Session for `guardian-contract-v0.1`; do not borrow the active `main` Engineering Supervisor workspace.
4. Resolve exact live DB service-principal/role inventory before SECURITY DEFINER mutation RPCs or GRANT/RLS rules.
5. Convert negative specs (base + v0.1.1 + v0.1.2) into executable SQL tests against a disposable/dev database branch.
6. Generate a fresh executable migration candidate from the effective v0.1.2 model; do not promote/copy the historical base draft directly.
7. Only after executable forbidden-transition, concurrency and mutation gates pass should runtime migration/deployment be considered.

If interrupted here, start from this file plus `START_HERE.md`, `IMPLEMENTATION_CHECKPOINT.md`, DCR-0001, DCR-0002, v0.1.1 and v0.1.2 corrective contracts; do not reconstruct progress from chat memory.
