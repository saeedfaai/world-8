# World 8 Provider Failover Mesh v0.1

Status: IMPLEMENTED / RUNTIME-VALIDATED / GROQ_CANARY_SUCCEEDED / SCALE_5_SUCCEEDED / SCALE_20_ELIGIBLE_NOT_STARTED

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

The five alternate transports were challenge-attested in runtime and are VERIFIED. Groq is independently credential-verified and live-ready. Other alternate credential bindings remain UNVERIFIED until their runtime secret is provisioned and a provider probe passes.

## Provider health / circuit breaker

`world8_provider_health_receipts` is append-only evidence. `world8_provider_health_state` is the current projection.

Health states: `HEALTHY`, `DEGRADED`, `ADMIN_BLOCKED`, `DISABLED`, `UNKNOWN`.

`ADMIN_BLOCKED` and `DISABLED` are hard blocks for failover selection. The first OpenAI real-provider canary returned HTTP 429 with `insufficient_quota`, so OpenAI remains:

`ADMIN_BLOCKED / INSUFFICIENT_QUOTA / retryable=false`

Groq is currently `HEALTHY / SCALE5_SUCCEEDED`.

## Generic worker

`world8-provider-worker-generic-v01` resolves only safe route context from DCP:

- provider
- adapter config/base URL
- model id
- opaque `envref:*` credential reference
- verified transport/binding state

The worker resolves the named environment secret locally. Raw credentials never enter DCP, Git, chat, receipts, or outputs.

The worker supports transport challenge attestation, credential provider probe, governed Chat-Completions execution for OpenAI-compatible providers, final-output-only recording, append-only execution evidence, and sanitized provider errors. It does not persist provider error response bodies or private reasoning.

## Groq credential verification — 2026-08-27

The original binding used `envref:GROQ_API_KEY`, but the runtime secret is named `GROQ_API_KEY4`. The corrected opaque binding is:

- adapter: `adapter-groq-external-v01` — ACTIVE;
- binding: `binding-groq-envref-key4-v01`;
- credential ref: `envref:GROQ_API_KEY4`;
- transport: `transport-supabase-groq-generic-v01` — ACTIVE / VERIFIED.

Credential probe challenge `credential-challenge-a191726e8838c4f5d334fc35be65` returned `PASS`, provider HTTP status `200`, `credential_present=true`, `provider_invoked=true`, and receipt `credential-receipt-f8363334b524b980756a4fd3d70b`.

No raw Groq key was read, copied, logged, committed, or returned.

After verification, `world8_provider_failover_snapshot_v1('CODE_ASSIST_PRIMARY')` selected Groq at priority 1 with `PASS / LIVE_READY`.

## First governed Groq REAL_EXTERNAL canary — SUCCESS

The first governed Groq canary used a fresh Mason lane and did not reuse failed OpenAI Work. It completed with HTTP 200, `live_provider_invoked=true`, `test_only=false`, output `GROQ_CANARY_OK`, output SHA-256 `c8f6499670681f37f348a655b6f0807e3a1460ab7fba28f358ff704100d763ff`, and success receipt `provider-receipt-798cd073473c509b31bb07a00013`.

The temporary Workspace and Mason Assignment were released after success. No canonical repository mutation was required for the canary itself.

## Formal Scale-5 stage — SUCCESS

The five-execution stage was run only after Provider Failover Mesh PR #29 merged, CI passed, and the DCP canonical Git resource was synchronized to merge `a46bab811965434ff4f491f30953292de8d7e41b`.

An initial five-assignment reservation was safely released before provider execution because the DCP canonical-head projection was stale. After canonical-head synchronization, five fresh lanes were created and executed.

Final result:

- 5 fresh Mason Assignments;
- 5 fresh Work claims;
- 5 isolated Git Workspaces;
- 5 Provider Execution Requests;
- 5 Actor Executions;
- 5 `SUCCEEDED` receipts;
- 5 provider HTTP `200` responses;
- 5 exact lane outputs;
- 0 failures;
- 0 retries;
- 0 failovers to another provider;
- all Workspaces released;
- all Assignments released;
- raw secret stored: false;
- private reasoning stored: false.

Full lane-level evidence is canonicalized in `docs/engineering/GROQ_SCALE5_EVIDENCE.md`.

Groq health is now `HEALTHY / SCALE5_SUCCEEDED` with receipt `provider-health-34c974ca47a12e5822558d94e698`.

## Scale rule

Stages 1 and 5 are satisfied by real provider evidence. The next eligible stage is 20 real executions, but **SCALE_20 has not started**.

Any 20→100 progression must preserve:

- canonical-head synchronization before reservation;
- provider readiness and health checks;
- explicit fresh Work/Assignment/Workspace binding;
- rate/cost awareness;
- append-only execution/output evidence;
- clean resource release;
- failure containment;
- `automatic_retry=false` until governance explicitly changes it.

Existing Guardian/N-Mason orchestration load tests at 100 concurrent engineering sessions are not evidence of 100 live provider invocations.

## Security limitations / v0.2 candidates

- strengthen public Edge dispatch authentication beyond unpredictable capability/request IDs;
- provider-specific rate/capacity budgets and concurrency allocation;
- health expiry and automatic observation, while keeping health-state promotion governed;
- audited manual override policy if approved by governance.
