# World 8 Identity & Authority Fabric v0.1.1

Status: IMPLEMENTED IN RUNTIME / UNDER CI REVIEW / NOT YET PROMOTED

Work: `work-d47f0925ba693b1c8def85d5add0`

## Contract

Authorization is evaluated as:

`Subject × Action × Resource × Scope × Condition -> ALLOW | DENY + reason_code + evidence`

Security defaults:

- DENY by default.
- Explicit DENY/REVOKE wins.
- Qualification is evidence of competence, never authority.
- Access identity, authorization, and credentials remain separate.
- Positive specialized evidence is not terminal when additional conditions were requested.
- Authority rules and authorization receipts are append-only.

## Reused authority sources

The verifier does not replace existing specialized authority stores. It reuses them as evidence:

- `world8_actor_registry`: persistent human/machine/service actor identity.
- `world8_access_identity_bindings`: channel identity and assurance evidence.
- `principal_route_grants`: route-specific GRANT/REVOKE truth.
- `w0_boot_authorizations`, `w1_running_authorizations`, `w2_external_effect_authorizations`: World lifecycle/effect approvals.
- governance approvals/challenges: explicit governed approval evidence.
- `world8_owner_step_up_grants`: temporary high-assurance owner evidence.
- `world8_binding_artifacts.permissions`: capability/binding permission ceiling; not copied into a second registry.

## General authority ledger

`world8_authority_rules` is used only for action/resource/scope decisions that are not already represented by a specialized authority store. Rules are versioned, scoped, time-bounded where appropriate, and append-only. Revocation is a new ledger row, never mutation of prior evidence.

`world8_authorization_receipts` records immutable decisions including matched rules, identity evidence, specialized evidence, request hash, decision, reason, evaluation time, and expiry.

## Developer Admission integration

Normal governed code write now uses:

`Work -> Workspace -> Qualification -> world8_authorize_v1 -> Admission v0.2 -> Lease v3 -> CAS Write`

`world8_dev_admission_check_v2` embeds the exact Work and active Workspace into authorization scope. `world8_dev_acquire_lease_v3` requires a PASS admission with `authorization_checked=true`. The old `p_require_authorization=false` Lease v2 bypass is closed.

## v0.1.1 security repairs

Runtime tests of v0.1 found and repaired three policy defects:

1. Rule `conditions` were stored but not included in effective-rule matching.
2. `ROUTE_USE` could finalize ALLOW immediately after a route grant and skip later W0/W1/W2/governance/step-up requirements.
3. `request_hash` omitted identity-assurance parameters.

v0.1.1 requires both request scope and request conditions to contain the rule requirements, defers route ALLOW until all requested conditions pass, and hashes every security-relevant request input.

Reusable diagnostic knowledge:

- `sig-authority-rule-conditions-ignored-v1`
- `sig-authorization-request-hash-incomplete-v1`
- `sig-route-grant-condition-bypass-v1`
- `playbook-authorization-policy-regression-v1`

## Current deliberate limits

- General ROLE authority is not evaluated yet because World 8 does not currently have a trustworthy general actor-to-role membership authority. A caller-supplied role must not be treated as proof of role membership.
- Credential Broker is not implemented by this change.
- GitHub protected-main / required-review enforcement remains an infrastructure blocker; parallel Mason coding stays disabled until that gate is externally enforced and re-verified.
- Authority v0.1.1 is not promoted until PR CI passes and DCP/Postflight evidence is complete.
