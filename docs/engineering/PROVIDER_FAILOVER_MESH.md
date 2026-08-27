# World 8 Provider Failover Mesh v0.1

Status: IMPLEMENTED / RUNTIME-VALIDATED / GROQ_CANARY_SUCCEEDED / SCALE_5_ELIGIBLE_NOT_STARTED

## Purpose

Remove any single AI provider as a bottleneck for the N-Mason execution fabric while preserving World 8 identity, authority, evidence, and Crash-Safe invariants.

## Identity boundary

Actor identity never contains provider or model identity. Provider/model remain properties of `world8_actor_executions` and Provider Execution Requests. The Failover Mesh does not create new Actors and does not grant Authority.

## Canonical sources reused

- `world8_provider_execution_adapters`
- `world8_provider_credential_bindings`
- `world8_provider_worker_transports`
- Provider Execution Request / Receipt / Output stores
- Actor Executions
- Guardian / Diagnostic Memory
- DCP Work / Workspace / Admission / Lease / Scribe

No parallel execution truth store is introduced.

## Frozen policy

`provider-failover-code-assist-v01` / `CODE_ASSIST_PRIMARY` is append-only and FROZEN.

Selection order:
1. Groq
2. DeepSeek
3. OpenRouter
4. Cerebras
5. Mistral
6. OpenAI

The policy is advisory only. `automatic_retry=false` and `max_attempts=1`. A provider invocation still requires an explicit governed Provider Execution Request. v0.1 cannot silently retry another provider.

## Provider readiness

A candidate is selectable only when:

1. adapter is ACTIVE;
2. worker transport is VERIFIED by challenge attestation;
3. credential binding is VERIFIED by provider probe;
4. provider health is not hard-blocked.

The five alternate transports were challenge-attested in runtime and are VERIFIED. Groq is now independently credential-verified and live-ready. Other alternate credential bindings remain UNVERIFIED until their runtime secret is provisioned and a provider probe passes.

## Provider health / circuit breaker

`world8_provider_health_receipts` is append-only evidence. `world8_provider_health_state` is the current projection.

Health states: `HEALTHY`, `DEGRADED`, `ADMIN_BLOCKED`, `DISABLED`, `UNKNOWN`.

`ADMIN_BLOCKED` and `DISABLED` are hard blocks for failover selection. The first OpenAI real-provider canary returned HTTP 429 with `insufficient_quota`, so OpenAI is projected as:

`ADMIN_BLOCKED / INSUFFICIENT_QUOTA / retryable=false`

This prevents a technically VERIFIED credential/transport from being selected while provider capacity is administratively unavailable. Recovery requires explicit health revalidation evidence; no automatic retry is performed.

## Generic worker

`world8-provider-worker-generic-v01` resolves only safe route context from DCP:

- provider
- adapter config/base URL
- model id
- opaque `envref:*` credential reference
- verified transport/binding state

The worker resolves the named environment secret locally. Raw credentials never enter DCP, Git, chat, receipts, or outputs.

The worker supports:

- transport challenge attestation;
- credential provider probe;
- governed Chat-Completions execution for OpenAI-compatible providers;
- final-output-only recording;
- append-only execution evidence;
- sanitized provider error type/code.

It does not persist provider error response bodies or private reasoning.

## Groq credential verification — 2026-08-27

The original binding used `envref:GROQ_API_KEY`, but the runtime secret is named `GROQ_API_KEY4`. The corrected opaque binding is:

- adapter: `adapter-groq-external-v01` — ACTIVE;
- binding: `binding-groq-envref-key4-v01`;
- credential ref: `envref:GROQ_API_KEY4`;
- transport: `transport-supabase-groq-generic-v01` — ACTIVE / VERIFIED.

Credential probe challenge `credential-challenge-a191726e8838c4f5d334fc35be65` returned:

- `credential_present=true`;
- `provider_invoked=true`;
- provider HTTP status `200`;
- verification result `PASS`;
- binding verification state `VERIFIED`;
- receipt `credential-receipt-f8363334b524b980756a4fd3d70b`.

No raw Groq key was read, copied, logged, committed, or returned.

After this verification, `world8_provider_failover_snapshot_v1('CODE_ASSIST_PRIMARY')` selected Groq at priority 1 with:

- `gate_state=PASS`;
- `readiness_state=LIVE_READY`;
- `live_ready=true`;
- credential verification `VERIFIED`;
- transport verification `VERIFIED`.

OpenAI remains hard-blocked by `INSUFFICIENT_QUOTA`.

## First governed Groq REAL_EXTERNAL canary — SUCCESS

A fresh Mason lane was created; no failed OpenAI Work was reused.

- Actor: `mason-worker-7dedb0-0002`
- Assignment: `assignment-6597d5db4cc42b9f365263ffb11b5a82`
- Work: `work-24d8390984561324398227ce4f3c`
- Workspace: `workspace-1dbb9c0453ec0674ee92320ba378d411`
- Branch: `work/groq-live-provider-canary-mason-0002`
- Provider request: `provider-request-d6010202d2af415a0f4be7fb49df`
- Actor Execution: `execution-3bb7144880031f2f798f3f9037da96c0`
- Provider: Groq
- Model: `openai/gpt-oss-20b`

The task requested exactly one line: `GROQ_CANARY_OK`.

Observed result:

- request state: `SUCCEEDED`;
- provider HTTP status: `200`;
- `live_provider_invoked=true`;
- final output: `GROQ_CANARY_OK`;
- output id: `provider-output-cb4e439cc2511f6603a11dc523fb`;
- output SHA-256: `c8f6499670681f37f348a655b6f0807e3a1460ab7fba28f358ff704100d763ff`;
- provider request evidence: `provider:Groq:request-id:req_01m1299hcgerf9naavp9qc8c45`;
- final success receipt: `provider-receipt-798cd073473c509b31bb07a00013`;
- `test_only=false`;
- raw secret stored: false;
- private reasoning stored: false.

The temporary workspace and Mason assignment were released after success. No canonical repository mutation was required for the canary itself.

## Scale rule

The required single REAL_EXTERNAL canary has now succeeded. The next scale stage, up to 5 governed real provider executions, is eligible but **has not been started automatically**. Any 5→20→100 progression must still preserve readiness checks, explicit Work/Assignment/Workspace binding, execution receipts, cost/rate awareness, cleanup, and failure containment.

Existing Guardian/N-Mason orchestration has already been load-tested separately at 100 concurrent engineering sessions; that is not evidence of 100 live provider invocations.

## Security limitations / v0.2 candidates

- strengthen public Edge dispatch authentication beyond unpredictable capability/request IDs;
- provider-specific rate/capacity budgets and concurrency allocation;
- health expiry and automatic observation, while keeping health-state promotion governed;
- audited manual override policy if approved by governance.
