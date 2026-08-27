# World 8 Provider Failover Mesh v0.1

Status: IMPLEMENTED / RUNTIME-VALIDATED / CANARY-GATED

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

The five alternate transports were challenge-attested in runtime and are VERIFIED. Their credential bindings remain UNVERIFIED until a secret is provisioned and a provider probe passes.

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

## Runtime evidence before merge

- 5/5 alternate transports VERIFIED by challenge attestation.
- 0/5 alternate credentials VERIFIED until explicitly provisioned.
- OpenAI credential + transport VERIFIED but provider health hard-blocked by insufficient quota.
- `world8_provider_failover_snapshot_v1('CODE_ASSIST_PRIMARY')` returns `selected=null` and `gate_state=BLOCKED` in this state.
- OpenAI candidate contains `PROVIDER_HEALTH_HARD_BLOCKED`.
- No provider was automatically invoked by failover selection.

## Scale rule

A successful single REAL_EXTERNAL canary is required before 1→5→20→100 real AI execution scale-out. Existing Guardian/N-Mason orchestration has already been load-tested separately at 100 concurrent engineering sessions; that is not evidence of 100 live provider invocations.

## Security limitations / v0.2 candidates

- strengthen public Edge dispatch authentication beyond unpredictable capability/request IDs;
- provider-specific rate/capacity budgets and concurrency allocation;
- health expiry and automatic observation, while keeping health-state promotion governed;
- audited manual override policy if approved by governance.
