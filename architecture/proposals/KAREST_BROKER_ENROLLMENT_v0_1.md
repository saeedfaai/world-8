# KAREST Advisory Broker Enrollment v0.1

Status: PROPOSAL_ONLY / PRE_RUNTIME / NO DDL / NO INSERT / NO AUTHORITY CREATION

## Purpose

Define the minimum World 8 Actor / Work / Workspace enrollment required before KAREST may submit advisory-only provider execution requests through the existing World 8 provider pipeline.

Enrollment is identity/scope binding only. **Enrollment does not grant business authority, code-write authority, provider-tool authority, external-effect authority, spending authority, promotion authority, or credential access.**

## Runtime facts this proposal binds to

World 8 currently requires provider enqueue/claim to resolve:

1. ACTIVE Actor;
2. Work bound to that Actor;
3. ACTIVE Workspace bound to the same Actor + Work;
4. provider readiness;
5. canonical execution request / idempotency;
6. governed worker dispatch / challenge / claim / receipts.

Current runtime audit found no KAREST-specific Actor, Work, or Workspace. Therefore KAREST provider dispatch remains blocked until a separately governed enrollment is implemented.

## Proposed stable identities

### Actor

- `actor_id`: `service-karest-advisory-broker-001`
- `actor_kind`: `SERVICE`
- `display_name`: `KAREST Advisory Broker`
- `home_scope`: `COMPANY`
- initial `status`: `ACTIVE` only after governed enrollment approval
- `authority_ref`: `NULL`

Required Actor metadata:

```json
{
  "service_kind": "KAREST_ADVISORY_BROKER",
  "authority_effect": "NONE",
  "runtime_authority_effect": "NONE",
  "may_write_code": false,
  "may_promote": false,
  "may_purchase": false,
  "may_grant_authority": false,
  "may_execute_provider_tools": false,
  "may_create_consequential_effect": false,
  "may_access_provider_secret": false,
  "brain_provider_independent": true,
  "advisory_only": true
}
```

The Actor identifies the accountable KAREST service lane for World 8 execution provenance. It is not HumanRoot, Principal, Mason, owner, or a business operator.

## Proposed Work

- logical stable purpose: `KAREST_ADVISORY_AI_BROKER_INTEGRATION`
- `owner_scope`: `COMPANY`
- `actor_ref`: `service-karest-advisory-broker-001`
- initial `development_state`: `PROPOSED`
- `validation_state`: `UNTESTED`
- `promotion_state`: `NOT_PROMOTED`
- `deployment_state`: `NOT_DEPLOYED`

Goal:

> Permit only advisory text-generation execution requests originating from authenticated KAREST runtime, while preserving World 8 provider readiness, idempotency, capacity, challenge, worker, output, and receipt controls.

The Work must explicitly exclude:

- direct provider calls;
- direct worker calls;
- raw credential access;
- provider-tool execution;
- KAREST Effect Gateway bypass;
- payments / purchases / paid-provider fallback;
- code mutation;
- canonical World 8 mutation except execution lifecycle records created by the existing provider pipeline;
- business commitments or external messages.

## Proposed Workspace

- bound to the exact KAREST advisory Work and Actor above;
- `workspace_provider`: `GITHUB`
- `repo_ref`: `saeedfaai/Company-runtime`
- `branch_ref`: `karest/auth-account-session-shell-v0-1`
- `access_mode`: `READ_ONLY`
- `isolation_mode`: `REMOTE_WORKSPACE`
- initial `state`: `ACTIVE` only after governed enrollment approval

Required Workspace metadata:

```json
{
  "purpose": "KAREST_ADVISORY_AI_BROKER_INTEGRATION",
  "canonical_mutation": false,
  "no_code_mutation": true,
  "authority_effect": "NONE",
  "advisory_only": true,
  "provider_tools_allowed": false,
  "consequential_effect_allowed": false,
  "paid_fallback_allowed": false,
  "execution_scoped_identity": false,
  "workspace_contract_version": "2.2"
}
```

The Workspace is a scope/evidence binding required by the existing provider execution contract. `READ_ONLY` is mandatory. A later change to `WRITE` requires a separate governed proposal and must never be implied by this enrollment.

## Provider route pin

Enrollment does not select or reveal a secret. The broker implementation may only request the already-observed governed route:

- adapter: `adapter-groq-external-v01`
- transport: `transport-supabase-groq-generic-v01`
- credential binding: `binding-groq-envref-key4-v01`
- default model: `openai/gpt-oss-20b`

Provider/model remain **Execution provenance**, never Actor identity or authority.

## Allowed broker operations

Only:

- `advisory.generate.submit`
- `advisory.generate.status`

Required policy on every signed request:

```json
{
  "advisoryOnly": true,
  "providerToolsAllowed": false,
  "consequentialEffectAllowed": false,
  "paidFallbackAllowed": false
}
```

## Enrollment is not dispatch authority

Even after enrollment, a request must still pass all independent gates:

`KAREST signature/time/hash/policy fence -> exact enrollment -> World 8 provider readiness -> canonical enqueue/idempotency -> capacity -> worker challenge -> worker claim -> provider invocation -> output/evidence/receipt`

No enrollment row may bypass or replace those checks.

## Revocation / lifecycle

Any one of these must fail closed for future provider execution:

- Actor status changes from ACTIVE;
- Work is invalidated/retired or Actor binding changes;
- Workspace is RELEASED / STALE / BLOCKED;
- Workspace access_mode ceases to be READ_ONLY;
- provider route loses VERIFIED/ACTIVE readiness;
- KAREST broker verification key is unavailable/revoked;
- request policy widens beyond advisory-only.

Revocation of enrollment must not delete historical execution/evidence receipts.

## Implementation boundary

This document intentionally contains no SQL INSERT, UPDATE, DDL, Edge deployment, signing key, challenge token, service-role key, provider API key, or runtime mutation.

A later enrollment implementation candidate must be separate, reviewable, idempotent, and fail closed. It may not be applied until the KAREST broker contract review and enrollment review permit runtime implementation.

## Required negative tests before runtime enrollment

1. wrong actor kind rejected;
2. non-COMPANY home scope rejected;
3. non-null authority grant/effect rejected;
4. Work actor mismatch rejected;
5. Workspace actor/work mismatch rejected;
6. Workspace `WRITE` rejected;
7. wrong repository or branch scope rejected;
8. provider-tool / consequential-effect / paid-fallback policy widening rejected;
9. direct worker/provider route rejected;
10. inactive/released/stale enrollment rejected;
11. enrollment alone cannot mint authority;
12. provider secret cannot enter enrollment artifacts.
