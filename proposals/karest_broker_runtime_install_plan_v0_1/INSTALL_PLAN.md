# KAREST Broker Runtime Installation Plan v0.2

Status: PLAN_ONLY / NOT_EXECUTED / NO_RUNTIME_MUTATION

## Purpose
Define the exact gated path from the tested proposal chain to a reversible World 8 runtime candidate without silently crossing review, authority, secret, RLS/service-role, canonical-resource, or Production boundaries.

## Fresh runtime preflight corrections
A direct read-only runtime preflight on 2026-09-09 changed the plan in two material ways:

1. `world8_dev_create_work_claim_v3` is currently a deprecated fail-closed stub that raises `DEPRECATED_USE_WORK_CLAIM_V2_THEN_ADMISSION_THEN_LEASE_V2`. It MUST NOT be used.
2. World 8 has no canonical Git resource for `saeedfaai/Company-runtime`, while `world8_dev_register_workspace_v2` requires a canonical resource. A raw INSERT is forbidden. The exact, narrow canonical resource registrar is therefore part of PR #81.

For this READ_ONLY advisory service lane no code/artifact write lease is required for provider enqueue. Provider enqueue itself requires ACTIVE Actor + matching Work + ACTIVE Workspace. Work creation therefore uses current canonical `search receipt -> Mason preflight -> world8_dev_create_work_claim_v2`, followed by canonical Workspace registration. Admission/lease machinery remains mandatory only when a later operation actually requires the corresponding governed authorization/write lease; this plan does not manufacture a write lease for a READ_ONLY broker workspace.

## Immutable dependency heads
The installation candidate must be rebuilt/re-reviewed if any dependency head changes.

- Broker contract PR #64: `5c8f87f535a32b56b24579a3f34c564b2ba7335a`
- Broker implementation base PR #66: `c6d4d66f7fa19f3d15937f67407efe635bfab0eb`
- Hardened broker Edge PR #78: `4cee1cf38e923c0919633ab2b7d6ead854dfd4cc`
- Enrollment contract PR #67: `b00164aeea119f00de9fe3e6e9e8d79c3003cbdc`
- Enrollment implementation inventory PR #70: `c324123a930963f9cab97d84fe33121805e1da65`
- SERVICE actor registrar design PR #71: `e33716771898993ba32155cd4c2041b1d762e8be`
- Disposable actor PostgreSQL proof PR #73: `fab68b004317c95d396ccf6d752a79cc96b098a7`
- Hardened runtime prerequisite registrars PR #81: `cc251f05911d5b9dd09ca3ac16102b32b1ab1111`
- KAREST Company-runtime observed production-branch head: `3fc5535ef2ab8eafe3fbb227e236bd1dc6f2779e`

## Mandatory review gates before runtime mutation
All must have an explicit disposition bound to the exact head or security state:
- Issue #65 broker contract: PASS_FOR_IMPLEMENTATION required.
- Issue #68 enrollment contract: PASS_FOR_IMPLEMENTATION required.
- Issue #69 original broker implementation: reviewed as BASE_ONLY; it MUST NOT be deployed directly after the service-role hardening finding. Deployment authority comes only from Issue #80 on hardened descendant PR #78.
- Issue #72 actor registrar design: design/proof disposition required; runtime installation must use hardened descendant PR #81, not raw `reference.sql` from #71.
- Issue #74 disposable actor SQL proof: PASS_AS_DISPOSABLE_RUNTIME_PROOF required.
- PR #81 exact head: disposable PostgreSQL hardening gate PASS and exact-source review required before runtime DDL.
- Issue #77 broker-critical RLS/service-role security posture: RESOLVED_FOR_DEPLOYMENT required.
- Issue #80 hardened broker Edge: PASS_AS_HARDENED_EDGE_CANDIDATE required on exact head `4cee1cf38e923c0919633ab2b7d6ead854dfd4cc`.

PENDING, silence, approval on another SHA, generic PR mergeability, or a platform advisory without reviewed disposition is not PASS.

## Preflight before any runtime write
1. Re-read exact dependency heads and review dispositions.
2. Re-read current World 8 actor/work/workspace/resource schema and canonical writer signatures.
3. Confirm no existing conflicting `service-karest-advisory-broker-001` Actor, KAREST Work, Workspace, or canonical Company-runtime resource.
4. Confirm Groq route remains ACTIVE + LIVE_READY with credential binding and transport VERIFIED, using opaque credential reference only; never read/export raw provider secret.
5. Confirm broker policy remains advisory-only, provider-tools=false, consequential-effects=false, paid-fallback=false.
6. Re-read broker-critical table grants/RLS posture. Fresh preflight observed RLS disabled on the reviewed subset with grants only to `postgres,service_role`; no `anon`/`authenticated` grants and no policies were observed. This is not public-exposure proof and does not by itself authorize deployment because the Edge uses service_role and must not become a confused deputy.
7. Confirm hardened Edge exact head still enforces bounded body, exact envelope keys, exact operation shape, public Ed25519 verification key only, and explicit `raw_secret_returned=false` readiness.
8. Verify current writer drift: `world8_dev_create_work_claim_v2`, `world8_dev_register_workspace_v2`, `world8_dev_release_workspace_v1`, `world8_provider_execution_enqueue_v2`, and `world8_provider_execution_dispatch_via_worker_v1` exact runtime fingerprints.
9. Confirm KAREST signer public-key enrollment design separately; private key must never enter World 8, GitHub, Drive, chat, or source.
10. Produce a pre-write evidence receipt containing exact heads, schema/writer fingerprints, RLS/grant snapshot, readiness result, and zero/conflict counts.

## Runtime installation order
No step may be skipped.

### A. Install hardened prerequisite registrars
- Apply only the reviewed exact `runtime_prereqs.sql` from PR #81 through the governed World 8 migration mechanism.
- This installs the exact KAREST SERVICE Actor registrar and exact KAREST Company-runtime canonical-resource registrar.
- Both functions must be SECURITY DEFINER with fixed `pg_catalog, public` search_path.
- EXECUTE must remain denied to PUBLIC/anon/authenticated and granted only to service_role.
- Verify installed function-definition fingerprints and ACLs after migration.

### B. Register/replay canonical Company-runtime resource
- Invoke only `world8_register_karest_company_runtime_resource_v1` with exact observed head `3fc5535ef2ab8eafe3fbb227e236bd1dc6f2779e`.
- Required resource: `resource-github-karest-company-runtime-production`.
- provider_ref = `github:saeedfaai/Company-runtime`.
- canonical branch = `karest/auth-account-session-shell-v0-1`.
- owner_scope = COMPANY; authority_effect = NONE; write_authority = NONE.
- Any protected-field/head conflict or inactive resource = STOP.

### C. Register/replay SERVICE Actor
- Invoke only `world8_register_karest_advisory_service_actor_v1`.
- Expected result: RECORDED if absent, REPLAY if exact existing identity.
- Any conflict or non-ACTIVE state = STOP.
- Verify SERVICE / COMPANY / authority_ref NULL and no-authority/no-effect/no-provider-tool/no-credential/no-code-write/no-spend metadata.

### D. Create Work through current canonical development-control path
- Record a scoped search receipt through `world8_dev_record_search_receipt_v1`.
- Run `world8_mason_preflight_v1` for the no-code-write KAREST advisory enrollment scope.
- Require preflight PASS on the current rulebase.
- Create the Work only through `world8_dev_create_work_claim_v2`.
- Work purpose is `KAREST_ADVISORY_AI_BROKER_INTEGRATION` / advisory provider-execution attribution only.
- No code-write/economic/effect/provider-secret authority.
- `world8_dev_create_work_claim_v3` is explicitly forbidden because current runtime marks it deprecated.

### E. Register Workspace through canonical writer
- Resolve the canonical Company-runtime resource through `world8_dev_canonical_git_resource_current_v1`.
- Use `world8_dev_register_workspace_v2` only.
- repo_ref = `saeedfaai/Company-runtime`
- branch_ref = `karest/auth-account-session-shell-v0-1`
- base_commit = exact registered canonical head.
- access_mode = `READ_ONLY`
- isolation_mode = `REMOTE_WORKSPACE`
- canonical mutation = false.
- No write lease is created for this READ_ONLY workspace.

### F. Install hardened broker Edge candidate
- Only after Actor + Work + Workspace postchecks pass and Issues #77/#80 have deployment-safe dispositions.
- Deploy only the reviewed hardened candidate from PR #78 exact head.
- Exact broker flow remains signature/time/hash/policy admission -> readiness_v2 -> enqueue_v2 -> replay/race suppression -> dispatch_via_worker_v1 -> canonical status/output reads.
- Request bodies remain bounded and exact-schema; unknown fields fail closed.
- Verification material is public Ed25519 only; private `d` is rejected.
- No direct generic-worker/provider endpoint.
- Service-role credentials remain internal and must never be returned.

### G. Signer/public-key boundary
- World 8 stores public verification material only.
- KAREST private signing material stays KAREST server-side in a secret manager, never GitHub/Drive/chat/source.
- Real key provisioning must be observable and separately evidenced; absence of secret-manager capability is a STOP for live proof, not permission to inline a private key.

### H. First live proof ceiling
The first permitted live proof, after all prior gates, is one bounded advisory request with:
- no tools;
- no consequential effect;
- no paid fallback;
- no provider secret exposure;
- exact signed envelope;
- evidence of request_id, canonical enqueue, worker challenge/claim, output and receipt.

A successful provider response is not FULL_RELEASE_PASS.

## Stop conditions
Immediately stop on: review mismatch, dependency SHA drift, unresolved Issue #77, actor/resource identity conflict, inactive actor/resource, schema/writer drift, deprecated writer use, route not LIVE_READY/VERIFIED, missing canonical Work/Workspace dependency, unexpected anon/authenticated grants, service-role confused-deputy path, signature/policy widening, unknown envelope acceptance, oversized-body acceptance, replay redispatch, secret exposure, provider-tool request, consequential-effect request, paid fallback, or inability to provision signing material without exposing the private key.

## Rollback / containment
- Before live traffic, broker Edge can remain undeployed or disabled.
- Workspace release must use `world8_dev_release_workspace_v1`.
- Actor and canonical resource identities are persistent evidence: do not DELETE them as rollback.
- Registrar must never reactivate lifecycle state or silently change canonical resource head.
- Do not delete canonical evidence/receipts.
- Any installed registrar-function rollback must use the same governed DDL mechanism that installed it and must not remove Actor/resource evidence/state.
- RLS/grant changes, if later approved, require their own tested rollback/compatibility plan; this plan does not apply blanket RLS changes.

## Explicit non-actions in this plan
This file itself performs no World 8 runtime DDL, RLS/grant mutation, Actor/resource/Work/Workspace write, Edge deploy, KAREST Production change, Company-runtime migration 046, signing-key generation, secret movement, provider call, merge, or FULL RELEASE PASS claim.
