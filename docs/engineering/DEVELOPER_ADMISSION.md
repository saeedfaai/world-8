# World 8 Developer Admission v0.1.1

Status: **IMPLEMENTED / TESTING / NOT PROMOTED**

This is an Engineering Fabric implementation slice, not a new plane and not a new authority truth.

## Goal

A developer/AI that joins World 8 must be bound to:

1. a persistent `actor_id`,
2. optional provider/session execution identity,
3. a governed Work Item,
4. an isolated canonical-Git workspace,
5. required qualification evidence,
6. explicit authorization evidence when authority is required,
7. a write Lease that is issued only after the applicable admission checks.

The admission result is an immutable receipt. It does not store secrets and it does not grant authority by itself.

## Core rule

**Qualification != Authorization.**

A qualification proves capability/training evidence. Authorization answers whether this subject may perform this action on this resource in this scope under current conditions.

Developer Admission must fail closed when authorization is requested but no unified authorization verifier can prove it.

## Correct lifecycle

`Re-entry -> Actor/Execution -> Preflight -> Work Claim -> isolated Workspace -> Qualification -> Authorization -> Admission Receipt -> Lease/Fencing/CAS -> Code -> PR/CI -> Merge -> Change Propagation -> Postflight -> Logbook/Experience`

A Work Claim identifies/reserves work. It is intentionally allowed to exist before Developer Admission because it grants no code-write authority by itself.

Admission is enforced before the write Lease, not before Work Claim creation.

## Runtime primitives

- `world8_dev_workspaces`
- `world8_dev_admission_receipts`
- `world8_dev_register_workspace_v1(...)`
- `world8_dev_release_workspace_v1(...)`
- `world8_dev_admission_check_v1(...)`
- `world8_dev_acquire_lease_v2(...)` — staged admission-bound lease path
- `world8_dev_create_work_claim_v3(...)` — **DEPRECATED** because the original ordering was circular

`world8_dev_create_work_claim_v2` remains the Work Claim path during this staged rollout.

## Ordering incident and repair

Incident: `incident-64fe289e33fad6cb6ed5e964b3a2f9aa`

The original v0.1 proposed `Work Claim v3` requiring an admission receipt. That was circular because the admission receipt itself is bound to an existing `work_id`, and it risked cross-work receipt reuse.

v0.1.1 repairs this by:

- deprecating `world8_dev_create_work_claim_v3`;
- keeping Work Claim before Admission;
- introducing `world8_dev_acquire_lease_v2`;
- requiring the Admission receipt actor/work/workspace to match before a Lease can be issued;
- optionally requiring explicit authorization evidence at the Lease gate.

## Workspace contract

For a WRITE workspace:

- repository must equal the DCP-registered canonical World 8 Git repository;
- branch must not be `main` or `master`;
- `base_commit` must equal the current canonical head recorded in DCP;
- workspace is bound to one Work Item and one Actor;
- raw credentials, API keys, passwords, tokens, or secret values are never stored in workspace evidence.

## Verified admission behavior

### Baseline Actor + Work + Workspace

No qualification requirement and no authorization request:

`PASS`

This only proves admission plumbing and workspace binding. It **does not** prove code-write authorization.

### Missing qualification

Required: `MASON_CORE@1.0`

Result:

`BLOCKED / QUALIFICATION_REQUIRED`

### Code-write authority requested

Required action: `CODE_WRITE` on a Shared Core artifact.

Result:

`BLOCKED`

Observed blockers:

- `ACCESS_IDENTITY_BINDING_REQUIRED`
- `AUTHORITY_REF_REQUIRED`
- `AUTHORIZATION_VERIFIER_NOT_IMPLEMENTED`

This is intentional. No permission is inferred from model capability, a Work Claim, possession of a Git branch, or a qualification.

## Lease v2 staging rule

`world8_dev_acquire_lease_v2` verifies:

- Admission exists, is PASS, and is unexpired;
- Actor matches the lease holder;
- Admission `work_id` exactly matches the lease Work;
- Admission workspace is still ACTIVE and matches Actor + Work;
- write lease requires a WRITE workspace;
- when `p_require_authorization=true`, explicit checked authorization evidence is mandatory.

Until the unified Identity & Authority Fabric is active, `p_require_authorization=true` correctly fails closed because the authorization verifier is not implemented. The flag exists only for staged bootstrap/testing; it must not be treated as a permanent bypass policy.

## Credentials

v0.1.1 does **not** implement credential vending. A future Credential Broker must provide scoped/temporary access only after successful authorization. Raw secrets must not be placed in Git, DCP, Work Capsules, Code Shadows, Dispatch, Experience Packs, or Admission receipts.

## Experience and error memory

Engineering lessons belong in the active Experience Pack `exp-world8-engineering-development-v1`.

Material errors belong in Diagnostic Memory as Incident -> Signature -> Playbook -> regression/compatibility evidence where applicable.

The admission-ordering incident is intentionally retained as project memory even after repair.

Do not use documentation as a substitute for machine evidence.
