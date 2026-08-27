# World 8 Credential Broker + External Worker v0.1

Status: RUNTIME FOUNDATION IMPLEMENTED / REAL EXTERNAL EXECUTION NOT YET VERIFIED

## Purpose

This layer closes the gap between the provider-neutral Provider Execution Adapter and a real external model worker without moving provider credentials, private reasoning, or a second Actor identity into the Development Control Plane.

**Actor identity persists; provider/model belongs only to Execution.**

## Secret boundary

Credential mode is **OPAQUE_REF_ONLY**.

DCP may store only opaque references such as `vault:...`, `envref:...`, `secretref:...`, or `connector:...`. Raw credential values must remain in the vault / worker runtime boundary and must never appear in Work, request, context, dispatch, receipt, journal, Diagnostic Memory, or Code Shadow.

Provider execution data also rejects private reasoning / chain-of-thought fields.

## Independent verification

Real readiness requires independent evidence for both sides of the bridge:

1. **Worker transport attestation** — a challenge token is issued, stored only as a hash, consumed once, and produces an append-only verification receipt.
2. **Credential provider probe** — after worker verification, a separate ephemeral challenge proves that the opaque credential reference resolves successfully at the worker/provider boundary and produces an append-only verification receipt.

Presence is not authorization and presence is not provider verification.

## Readiness

`world8_provider_execution_readiness_v2` is fail-closed. A REAL_EXTERNAL adapter is live-ready only when:

- the adapter is ACTIVE;
- an ACTIVE credential binding is VERIFIED;
- an ACTIVE worker transport for that adapter is VERIFIED.

The live lifecycle is:

`Assignment / Actor / Work / Workspace -> enqueue_v2 -> claim_v2 -> Actor Execution -> dispatch_envelope_v2 -> external provider invocation -> complete_v2 + provider invocation evidence`

The dispatch envelope contains the opaque credential reference, never the credential value. The v2 claim re-checks readiness immediately before creating the provider-specific Execution.

## Current OpenAI / Netlify state

Registered runtime objects:

- adapter: `adapter-openai-external-v01`
- credential binding: `binding-openai-envref-v01` / `envref:OPENAI_API_KEY`
- worker transport: `transport-netlify-world8-grok-proxy-v01`
- endpoint: `https://world8-grok-mcp-proxy.netlify.app`

At implementation time the credential binding and worker transport are both **UNVERIFIED**. Therefore OpenAI readiness is intentionally BLOCKED with:

- `CREDENTIAL_BINDING_NOT_VERIFIED`
- `WORKER_TRANSPORT_NOT_VERIFIED`

No live OpenAI/provider invocation is claimed from this state.

## Runtime evidence

- Provider Execution Adapter v0.1 is canonical on `main`.
- Mock provider lifecycle remains test-only.
- Broker challenge / attestation and credential probe contracts are installed.
- Strict v2 enqueue rejects an unverified OpenAI path before inserting a request; negative test left request count unchanged.
- Dispatch receipts are append-only and explicitly record `raw_secret_included=false`, `private_reasoning_included=false`, and `live_provider_invoked=false` until external invocation evidence exists.

## Scale path

The control plane and Guardian have already passed 100 concurrent governed Mason lanes. That is not a claim of 100 external LLM executions.

Live execution must progress with evidence:

`1 real canary -> 5 -> 20 -> 100`

Each stage requires verified credential + worker transport, rate/cost awareness, execution receipts, and successful cleanup before increasing concurrency.

## Non-claims

Until the worker transport challenge is attested, the credential probe passes, and a real provider invocation produces evidence, World 8 must not state that a real external model worker is active. Until 100 provider executions are actually active/succeeded with evidence, World 8 must not state that 100 external AI coders are running.
