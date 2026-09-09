# KAREST Broker Enrollment Implementation Plan v0.1

Status: PROPOSAL_ONLY / NOT APPLIED / BLOCKED_ON_ACTOR_WRITER

## Dependency

This plan depends on the reviewed enrollment contract in PR #67. It does not alter that contract and does not authorize runtime enrollment.

## Runtime writer inventory

Observed World 8 runtime provides canonical functions for later enrollment stages:

- Work creation: `world8_dev_create_work_claim_v3(...)`
- Workspace registration: `world8_dev_register_workspace_v2(...)`
- Workspace release: `world8_dev_release_workspace_v1(...)`

No public/general Actor registration function was identified for `world8_actor_registry` during the runtime writer inventory. Existing SERVICE actors demonstrate the intended identity semantics, but that does not establish a reusable canonical writer for a new SERVICE identity.

Therefore:

`ACTOR_ENROLLMENT_WRITER = UNRESOLVED`

and the implementation gate is:

`RUNTIME_ENROLLMENT = BLOCKED_ON_ACTOR_WRITER`

A direct INSERT into `world8_actor_registry` must not be introduced merely to unblock KAREST. Writer ownership must be explicitly resolved first.

## Required sequence after Actor writer resolution

1. Create or resolve exactly one Actor `service-karest-advisory-broker-001` through the governed canonical Actor writer.
2. Verify postconditions: SERVICE, COMPANY, ACTIVE, authority_ref NULL, authority/effect NONE, no code/spend/promotion/provider-tool/credential capability.
3. Create Work through `world8_dev_create_work_claim_v3`, using normal search/preflight/admission dependencies rather than bypassing them.
4. Verify Work is bound to the exact KAREST Actor and advisory-broker goal.
5. Register Workspace through `world8_dev_register_workspace_v2` only after the Work prerequisites are satisfied.
6. Require exact repo `saeedfaai/Company-runtime`, exact branch `karest/auth-account-session-shell-v0-1`, access_mode READ_ONLY, isolation_mode REMOTE_WORKSPACE.
7. Perform a read-only postcondition audit of Actor + Work + Workspace.
8. Only after all three bindings are ACTIVE and exact may PR #66 broker runtime be considered for a separate deployment gate.

## Forbidden shortcuts

- no borrowed Mason/SERVICE Actor;
- no direct INSERT into Actor Registry while writer ownership is unresolved;
- no hand-created Work row;
- no hand-created Workspace row;
- no WRITE Workspace;
- no provider invocation as an enrollment test;
- no Groq secret movement;
- no signing-key provisioning as part of enrollment;
- no authority rule/grant minted by enrollment;
- no KAREST consequential Effect permission.

## Required Actor-writer review questions

Before implementation, independent review must determine:

1. Is there an existing governed Actor writer not surfaced by the current public-function inventory?
2. If not, which existing World 8 component owns Actor creation?
3. Is a one-purpose SECURITY DEFINER Actor enrollment function required, or is another governed path canonical?
4. What idempotency/fencing/replay contract must Actor enrollment use?
5. What evidence/receipt must prove creation or idempotent replay?
6. What roles must have EXECUTE revoked?
7. How is retirement/revocation performed without deleting history?

## Evidence ceiling

The current evidence supports only:

- enrollment architecture proposal tested 9/9;
- Work/Workspace canonical writer inventory observed;
- Actor writer unresolved;
- no runtime enrollment performed.

No claim of runtime readiness or enrollment completion is permitted.
