# World 8 Developer Admission v0.1

Status: **IMPLEMENTED / TESTING / NOT PROMOTED**

This is an Engineering Fabric implementation slice, not a new plane and not a new authority truth.

## Goal

A developer/AI that joins World 8 must be bound to:

1. a persistent `actor_id`,
2. optional provider/session execution identity,
3. a governed Work Item,
4. an isolated canonical-Git workspace,
5. required qualification evidence,
6. explicit authorization evidence when authority is required.

The admission result is an immutable receipt. It does not store secrets and it does not grant authority by itself.

## Core rule

**Qualification != Authorization.**

A qualification proves capability/training evidence. Authorization answers whether this subject may perform this action on this resource in this scope under current conditions.

Developer Admission must fail closed when authorization is requested but no unified authorization verifier can prove it.

## Runtime primitives

- `world8_dev_workspaces`
- `world8_dev_admission_receipts`
- `world8_dev_register_workspace_v1(...)`
- `world8_dev_release_workspace_v1(...)`
- `world8_dev_admission_check_v1(...)`
- `world8_dev_create_work_claim_v3(...)`

`world8_dev_create_work_claim_v2` remains the compatibility path during staged rollout. v3 requires a current PASS admission receipt.

## Workspace contract

For a WRITE workspace:

- repository must equal the DCP-registered canonical World 8 Git repository;
- branch must not be `main` or `master`;
- `base_commit` must equal the current canonical head recorded in DCP;
- workspace is bound to one Work Item and one Actor;
- raw credentials, API keys, passwords, tokens, or secret values are never stored in workspace evidence.

Current first workspace evidence:

- repo: `saeedfaai/world-8`
- branch: `work/developer-admission-v0.1`
- base: `37461e316c3c609103160c2a2eb981515d26e08c`
- workspace: `workspace-05390dc859c51ed1fa2a0ca73dfe8058`

## Verified tests

### Baseline workspace/identity admission

No qualification requirement and no authorization request:

`PASS`

This proves Actor + Work + canonical workspace validation. It **does not** prove code-write authorization.

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

This is intentional. No permission is inferred from model capability, a Work Claim, or possession of a Git branch.

## Credentials

v0.1 does **not** implement credential vending. A future Credential Broker must provide scoped/temporary access after successful authorization. Raw secrets must not be placed in Git, DCP, Work Capsules, Code Shadows, Dispatch, or Experience Packs.

## Rollout

Current order:

`Re-entry -> Actor -> Preflight -> Work -> isolated workspace -> qualification check -> authorization check -> admission receipt`

Target order after Identity & Authority Fabric is active:

`Re-entry -> Actor/Execution -> Qualification -> Authorization -> scoped credential/workspace -> Work Claim v3 -> Lease/Fencing/CAS -> Code -> PR/CI -> Merge -> Change Propagation -> Postflight -> Logbook/Experience`

## Experience and error memory

Engineering lessons belong in the active Experience Pack `exp-world8-engineering-development-v1`.

Material errors belong in Diagnostic Memory as Incident -> Signature -> Playbook -> regression/compatibility evidence where applicable.

Do not use documentation as a substitute for machine evidence.
