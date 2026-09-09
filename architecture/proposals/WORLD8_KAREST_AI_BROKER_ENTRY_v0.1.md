# World 8 ↔ KAREST AI Broker Entry v0.1

Status: PROPOSAL_ONLY / NOT DEPLOYED / NO AUTHORITY / NO SECRET MOVEMENT

## Purpose
Provide a narrowly scoped service-to-service admission surface so KAREST can request advisory-only AI generation while the existing Groq credential remains inside World 8 as opaque `envref:GROQ_API_KEY4`.

## Existing live route evidence
- adapter: `adapter-groq-external-v01`
- transport: `transport-supabase-groq-generic-v01`
- credential binding: `binding-groq-envref-key4-v01`
- credential ref: `envref:GROQ_API_KEY4`
- binding: ACTIVE / VERIFIED
- transport: ACTIVE / VERIFIED
- exact-binding provider probe evidence: PASS / HTTP 200 / raw_secret_present=false

This proposal does not contain or request the raw provider credential.

## Service identity
Logical service identity: `service-karest-advisory-v01`.

Preferred authentication is asymmetric. World 8 stores only an independently governed KAREST public verification key. KAREST keeps the private signing key server-side.

Signed request fields: schema, request_id, service_id, issued_at, expires_at, nonce, operation, context_ref, actor_ref_hash, prompt_sha256, prompt, policy, signature.

Admission fails closed on unknown service/key version, invalid signature, expiry, replay, clock skew, prompt hash mismatch, malformed identifiers, policy widening, unsupported operation or oversized input.

## Hard policy ceiling
Exact required policy:

```json
{
  "advisoryOnly": true,
  "providerToolsAllowed": false,
  "consequentialEffectAllowed": false,
  "paidFallbackAllowed": false
}
```

No omitted/extra/widened policy field may pass.

## Execution boundary
An accepted broker request MUST enter the existing World 8 provider-execution machinery. The broker is forbidden from calling Groq directly and forbidden from receiving the raw credential.

Required chain:

`broker admission -> governed provider request -> worker challenge/claim/dispatch -> existing generic provider worker -> opaque envref resolution -> output/evidence receipt -> bounded broker response`

Direct invocation of `world8-provider-worker-generic-v01` from KAREST is not permitted.

## Consequential-effect boundary
The broker never grants KAREST business authority. If KAREST later chooses to act on advisory output, the action remains subject to KAREST current authorization, policy and Effect Gateway.

## Promotion gates
This proposal cannot be deployed until an independent World 8 review validates the exact implementation, negative tests, service-key registration, replay protection, challenge preservation, no-side-effect canary and no-secret evidence.
