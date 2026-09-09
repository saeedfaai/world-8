# KAREST Broker Runtime Installation Plan v0.1

Status: PLAN_ONLY / NOT_EXECUTED / NO_RUNTIME_MUTATION

## Purpose
Define the exact gated path from the already-tested proposal chain to a reversible World 8 runtime candidate without silently crossing review, authority, secret, RLS/service-role, or Production boundaries.

## Immutable dependency heads
The installation candidate must be rebuilt/re-reviewed if any dependency head changes.

- Broker contract PR #64: `5c8f87f535a32b56b24579a3f34c564b2ba7335a`
- Broker implementation PR #66: `c6d4d66f7fa19f3d15937f67407efe635bfab0eb`
- Hardened broker Edge PR #78: `4cee1cf38e923c0919633ab2b7d6ead854dfd4cc`
- Enrollment contract PR #67: `b00164aeea119f00de9fe3e6e9e8d79c3003cbdc`
- Enrollment implementation plan PR #70: `c324123a930963f9cab97d84fe33121805e1da65`
- SERVICE actor registrar PR #71: `e33716771898993ba32155cd4c2041b1d762e8be`
- Disposable PostgreSQL proof PR #73: `fab68b004317c95d396ccf6d752a79cc96b098a7`

## Mandatory review gates before runtime mutation
All must have an explicit disposition bound to the exact head or security state:
- Issue #65 broker contract: PASS required.
- Issue #68 enrollment contract: PASS required.
- Issue #69 broker implementation: PASS required.
- Issue #72 actor registrar: PASS required.
- Issue #74 disposable SQL proof: PASS required.
- Issue #77 broker-critical RLS/service-role security posture: RESOLVED_FOR_DEPLOYMENT required.
- Issue #80 hardened broker Edge: PASS required on exact head `4cee1cf38e923c0919633ab2b7d6ead854dfd4cc`.

PENDING, silence, approval on another SHA, a generic PR mergeability signal, or a platform advisory without a reviewed disposition is not PASS.

## Preflight before any runtime write
1. Re-read exact dependency heads and review dispositions.
2. Re-read current World 8 actor/work/workspace schema and canonical writer signatures.
3. Confirm no existing conflicting `service-karest-advisory-broker-001` Actor, Work, or Workspace.
4. Confirm Groq route remains ACTIVE + LIVE_READY with credential binding and transport VERIFIED, using opaque credential reference only; never read/export raw provider secret.
5. Confirm broker policy remains advisory-only, provider-tools=false, consequential-effects=false, paid-fallback=false.
6. Re-read broker-critical table grants/RLS posture. The current observed subset has RLS disabled but only `service_role` grants observed; no `anon`/`authenticated` grants were observed. This is not sufficient by itself because the Edge candidate uses service_role and must not become a confused deputy.
7. Confirm hardened Edge exact head remains the reviewed candidate and still enforces bounded body, exact envelope keys, exact operation shape, public Ed25519 verification key only, and explicit `raw_secret_returned=false` readiness.
8. Confirm KAREST signer public-key enrollment design separately; do not generate or move a real private key in this plan.
9. Produce a pre-write evidence receipt containing exact heads, schema/writer fingerprints, RLS/grant snapshot, readiness result, and zero/conflict counts.

## Runtime installation order
No step may be skipped.

### A. Install canonical Actor registrar
- Apply only the reviewed registrar definition from PR #71 through the governed World 8 DDL/migration mechanism selected by World 8 governance.
- Do not run `reference.sql` ad hoc from an application connection.
- Verify function definition hash after installation.

### B. Register/replay SERVICE Actor
- Invoke only the canonical registrar.
- Expected result: RECORDED if absent, REPLAY if exact existing identity.
- Any conflict or non-ACTIVE state = STOP.
- Verify authority_ref NULL and no-authority metadata.

### C. Create Work through canonical development-control path
- Satisfy the normal search receipt, Mason preflight and admission dependencies required by `world8_dev_create_work_claim_v3`.
- Work purpose is KAREST advisory broker execution attribution only.
- No code-write/economic/effect/provider-secret authority.

### D. Register Workspace through canonical writer
- Use `world8_dev_register_workspace_v2` only.
- repo_ref = `saeedfaai/Company-runtime`
- branch_ref = `karest/auth-account-session-shell-v0-1`
- access_mode = `READ_ONLY`
- isolation_mode = `REMOTE_WORKSPACE`
- canonical mutation = false.

### E. Install hardened broker Edge candidate
- Only after Actor + Work + Workspace postchecks pass and Issues #77/#80 have deployment-safe dispositions.
- Deploy only the reviewed hardened candidate descended from PR #78 exact head.
- Exact broker flow remains signature/time/hash/policy admission -> readiness_v2 -> enqueue_v2 -> replay/race suppression -> dispatch_via_worker_v1 -> canonical status/output reads.
- Request bodies remain bounded and exact-schema; unknown fields fail closed.
- Verification material is public Ed25519 only; private `d` is rejected.
- No direct generic-worker/provider endpoint.
- Service-role credentials remain internal and must never be returned.

### F. Signer/public-key boundary
- World 8 stores public verification material only.
- KAREST private signing material stays KAREST server-side and must be provisioned through a secret manager, never GitHub/Drive/chat/source.
- Real key provisioning is a separate controlled step and is NOT executed by this plan.

### G. First live proof ceiling
The first permitted live proof, after all prior gates, is one bounded advisory request with:
- no tools;
- no consequential effect;
- no paid fallback;
- no provider secret exposure;
- exact signed envelope;
- evidence of request_id, canonical enqueue, worker challenge/claim, output and receipt.

A successful provider response is not FULL_RELEASE_PASS.

## Stop conditions
Immediately stop on: review mismatch, dependency SHA drift, unresolved Issue #77, actor identity conflict, inactive actor, schema/writer drift, route not LIVE_READY/VERIFIED, missing canonical Work/Workspace dependency, unexpected anon/authenticated grants, service-role confused-deputy path, signature/policy widening, unknown envelope acceptance, oversized-body acceptance, replay redispatch, secret exposure, provider-tool request, consequential-effect request, or paid fallback.

## Rollback / containment
- Before live traffic, broker Edge can remain undeployed or disabled.
- Workspace release must use `world8_dev_release_workspace_v1`.
- Actor identity is persistent: do not DELETE it as rollback. Lifecycle suspension/revocation requires a separately governed lifecycle writer; registrar must never reactivate it.
- Do not delete canonical evidence/receipts.
- Any installed registrar function rollback must use the same governed DDL mechanism that installed it and must not remove Actor evidence/state.
- RLS/grant changes, if later approved, require their own tested rollback/compatibility plan; this plan does not apply them.

## Explicit non-actions in this plan
No World 8 runtime DDL, RLS/grant mutation, Actor/Work/Workspace write, Edge deploy, KAREST Production change, migration 046, signing-key generation, secret movement, provider call, merge, or FULL RELEASE PASS claim is performed by this file.
