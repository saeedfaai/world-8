# KAREST SERVICE Actor Registrar v0.1 — Proposal Only

Status: PROPOSAL_ONLY / NOT_APPLIED / NO_RUNTIME_MUTATION

## Purpose
Resolve the Actor-writer ownership gap blocking KAREST advisory-broker enrollment without introducing raw application-side INSERTs into `world8_actor_registry`.

## Canonical ownership
The proposed registrar is the sole enrollment writer for this KAREST SERVICE identity. Callers must not write `world8_actor_registry` directly.

Stable identity:
- `actor_id = service-karest-advisory-broker-001`
- `actor_kind = SERVICE`
- `display_name = KAREST Advisory Broker`
- `home_scope = COMPANY`
- `authority_ref = NULL`
- `status = ACTIVE` only at initial enrollment
- identity is persistent and independent of provider/model/session, consistent with ADR-0002.

## Non-authority invariant
Registration creates identity only. It MUST NOT create or imply:
- business/economic authority
- Effect Gateway authority
- provider-tool authority
- code-write authority
- spend authority
- credential access
- role/membership grants

Metadata must explicitly preserve `authority_effect=NONE`, `consequential_effects=false`, `provider_tools=false`, `credential_access=NONE`, `code_write=false`, `spend=false`.

## Admission
The registrar accepts only the exact stable KAREST identity above. Any widened actor kind, scope, authority_ref, capability, or identity field is rejected.

## Idempotency
Registration is keyed by stable `actor_id`.
- Absent actor: create exact row and return `RECORDED`.
- Existing exact actor: no mutation; return `REPLAY`.
- Existing actor with any protected-field mismatch: reject `IDENTITY_CONFLICT`; never overwrite.

## Concurrency
The implementation must serialize on the stable actor identity before deciding absent/existing. Concurrent duplicate enrollment may produce one `RECORDED` and one `REPLAY`, never two divergent identities.

## Evidence / receipt
A successful call must return a deterministic structured receipt containing at minimum:
- actor_id
- disposition (`RECORDED` or `REPLAY`)
- actor_kind
- home_scope
- authority_ref
- identity_version
- recorded_at for first creation when available

The receipt is evidence of identity registration only; it is not authorization evidence.

## Revocation boundary
Registration MUST NOT be used to revoke, suspend, reactivate, rename, widen scope, or change authority. Those are separate lifecycle operations with separate review/evidence. A non-ACTIVE existing actor is not silently reactivated by replay.

## Downstream enrollment order
Only after this Actor writer is governed and implemented may KAREST enrollment proceed:
1. register/replay exact SERVICE Actor through canonical registrar;
2. create Work only through `world8_dev_create_work_claim_v3` and its normal search/preflight/admission dependencies;
3. register Workspace only through `world8_dev_register_workspace_v2` with `READ_ONLY / REMOTE_WORKSPACE` and exact Company-runtime scope;
4. broker execution remains readiness -> enqueue_v2 -> dispatch_via_worker_v1.

## Explicit exclusions
This proposal does not apply DDL, create the function in runtime, insert/update any Actor/Work/Workspace row, provision signing keys, move provider secrets, invoke a provider, deploy Edge code, merge any PR, or authorize Production.
