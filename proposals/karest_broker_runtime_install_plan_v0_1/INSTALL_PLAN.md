# KAREST Broker Runtime Installation Plan v0.3

Status: PLAN_ONLY / NOT_EXECUTED / NO_RUNTIME_MUTATION

## Purpose
Define the exact gated path from the tested proposal chain to a reversible World 8 runtime candidate without silently crossing review, authority, secret, RLS/service-role, canonical-resource, or Production boundaries.

## Fresh runtime preflight corrections
A direct read-only runtime preflight on 2026-09-09 changed the plan in two material ways:

1. `world8_dev_create_work_claim_v3` is a deprecated fail-closed stub raising `DEPRECATED_USE_WORK_CLAIM_V2_THEN_ADMISSION_THEN_LEASE_V2`; it MUST NOT be used.
2. World 8 initially had no canonical Git resource for `saeedfaai/Company-runtime`, while `world8_dev_register_workspace_v2` requires one. A raw INSERT is forbidden. Exact narrow Actor/resource registrars are therefore provided by hardened PR #81.

For this READ_ONLY advisory service lane no code/artifact write lease is required for provider enqueue. Provider enqueue requires ACTIVE Actor + matching Work + ACTIVE Workspace. Work creation uses current canonical `search receipt -> Mason preflight -> world8_dev_create_work_claim_v2`, followed by canonical Workspace registration. Admission/lease machinery remains mandatory only when a later operation actually requests the corresponding governed authorization/write lease; this plan does not manufacture a write lease for a READ_ONLY broker workspace.

## Immutable dependency heads
The installation candidate must be rebuilt/re-reviewed if any deployment dependency head changes.

- Broker base concept PR #64: `5c8f87f535a32b56b24579a3f34c564b2ba7335a` — reviewed BASE_CONCEPT_ONLY, not deployment contract.
- Broker implementation base PR #66: `c6d4d66f7fa19f3d15937f67407efe635bfab0eb` — reviewed BASE_ONLY, direct deploy blocked.
- Hardened broker Edge PR #78: `806110c00808aed1aa844890fa6ffe7d3096cf95` — deployment candidate.
- Enrollment contract PR #67: `b00164aeea119f00de9fe3e6e9e8d79c3003cbdc`.
- Enrollment implementation inventory PR #70: `c324123a930963f9cab97d84fe33121805e1da65`.
- SERVICE actor registrar design PR #71: `e33716771898993ba32155cd4c2041b1d762e8be` — design only; install hardened descendant #81.
- Disposable actor PostgreSQL proof PR #73: `fab68b004317c95d396ccf6d752a79cc96b098a7`.
- Hardened runtime prerequisite registrars PR #81: `cc251f05911d5b9dd09ca3ac16102b32b1ab1111`.
- KAREST Company-runtime observed production-branch head: `3fc5535ef2ab8eafe3fbb227e236bd1dc6f2779e`.

## Review dispositions required before runtime mutation
- Issue #65: `BLOCKED_AS_CURRENT_RUNTIME_CONTRACT / BASE_CONCEPT_ONLY`; exact #64 head is not a deployment dependency.
- Issue #68: `PASS_FOR_IMPLEMENTATION` on enrollment contract.
- Issue #69: `BLOCKED_FOR_DIRECT_DEPLOYMENT / BASE_ONLY`; exact #66 head must not deploy directly.
- Issue #72: `PASS_FOR_IMPLEMENTATION_CANDIDATE_WITH_HARDENED_DESCENDANT_REQUIRED`; install #81, not raw #71 reference SQL.
- Issue #74: `PASS_AS_DISPOSABLE_RUNTIME_PROOF`.
- Issue #82: `PASS_AS_RUNTIME_PREREQUISITE_CANDIDATE` on PR #81 exact head `cc251f05911d5b9dd09ca3ac16102b32b1ab1111` with PostgreSQL run `34367985755` SUCCESS and architecture run `34367985883` SUCCESS.
- Issue #77: `RESOLVED_FOR_DEPLOYMENT_WITH_SIGNED_EDGE_CONTAINMENT`; no blanket RLS change applied.
- Issue #80: `PASS_AS_HARDENED_EDGE_CANDIDATE` on PR #78 exact head `806110c00808aed1aa844890fa6ffe7d3096cf95`; architecture `34368313635`, hardening `34368313754`, implementation `34368313685`, and Deno compile `34368313734` all SUCCESS.

PENDING, silence, approval on another SHA, generic PR mergeability, or a platform advisory without reviewed disposition is not PASS.

## Preflight before any runtime write
1. Re-read exact deployment dependency heads and review dispositions.
2. Re-read current World 8 actor/work/workspace/resource schema and canonical writer signatures.
3. Confirm no existing conflicting `service-karest-advisory-broker-001` Actor, KAREST Work, Workspace, or canonical Company-runtime resource.
4. Confirm Groq route remains ACTIVE + LIVE_READY with credential binding and transport VERIFIED, using opaque credential reference only; never read/export raw provider secret.
5. Confirm broker policy remains advisory-only, provider-tools=false, consequential-effects=false, paid-fallback=false.
6. Re-read broker-critical table grants/RLS posture. Fresh preflight observed RLS disabled on the reviewed subset with grants only to `postgres,service_role`; no `anon`/`authenticated` grants and no policies. Signed Edge containment is the reviewed deployment boundary; any grant widening reopens Issue #77.
7. Confirm hardened Edge exact head still enforces bounded body, exact envelope keys, exact operation shape, public Ed25519 verification key only, positive current TTL <=60s, and explicit `raw_secret_returned=false` readiness.
8. Verify current writer drift: `world8_dev_create_work_claim_v2`, `world8_dev_register_workspace_v2`, `world8_dev_release_workspace_v1`, `world8_provider_execution_enqueue_v2`, and `world8_provider_execution_dispatch_via_worker_v1` exact runtime fingerprints.
9. Confirm KAREST signer public-key enrollment design separately; private key must never enter World 8, GitHub, Drive, chat, or source.
10. Produce a pre-write evidence receipt containing exact heads, schema/writer fingerprints, RLS/grant snapshot, readiness result, and zero/conflict counts.

## Runtime installation order
No step may be skipped.

### A. Install hardened prerequisite registrars
- Apply only reviewed exact `runtime_prereqs.sql` from PR #81 through the governed World 8 migration mechanism.
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
- Only after Actor + Work + Workspace postchecks pass and the reviewed #77/#80 dispositions still match current security state/head.
- Deploy only reviewed hardened candidate PR #78 exact head `806110c00808aed1aa844890fa6ffe7d3096cf95` or a re-reviewed descendant.
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
Immediately stop on: review mismatch, deployment dependency SHA drift, loss of #77 signed-edge security posture, actor/resource identity conflict, inactive actor/resource, schema/writer drift, deprecated writer use, route not LIVE_READY/VERIFIED, missing canonical Work/Workspace dependency, unexpected anon/authenticated grants, service-role confused-deputy path, signature/policy widening, non-positive or >60s TTL acceptance, unknown envelope acceptance, oversized-body acceptance, replay redispatch, secret exposure, provider-tool request, consequential-effect request, paid fallback, or inability to provision signing material without exposing the private key.

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
