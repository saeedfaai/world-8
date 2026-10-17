# World 8 Provider Failover Mesh v0.1

Status: IMPLEMENTED / RUNTIME-VALIDATED / GROQ_SCALE_5_SUCCEEDED / GROQ_SCALE_20_FAILED_RATE_LIMIT / CONCURRENCY_GOVERNOR_ENFORCED / SCALE_100_BLOCKED

## Purpose

Remove any single AI provider as a bottleneck for the N-Mason execution fabric while preserving World 8 identity, authority, evidence, Crash-Safe behavior, and provider-capacity boundaries learned from runtime evidence.

## Identity boundary

Actor identity never contains provider or model identity. Provider/model remain properties of `world8_actor_executions` and Provider Execution Requests. The Failover Mesh and capacity governor do not create new identity semantics and do not grant Authority.

## Canonical sources reused

- `world8_provider_execution_adapters`
- `world8_provider_credential_bindings`
- `world8_provider_worker_transports`
- Provider Execution Request / Receipt / Output stores
- `world8_provider_health_receipts`
- `world8_provider_capacity_receipts`
- Actor Executions
- Guardian / Diagnostic Memory
- DCP Work / Workspace / Admission / Lease / Scribe

No parallel execution truth store is introduced.

## Frozen failover policy

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

The five alternate transports were challenge-attested and are VERIFIED. Groq is credential-verified and live-ready. Other alternate credential bindings remain UNVERIFIED until their runtime secret is provisioned and a provider probe passes.

## Provider health / circuit breaker

`world8_provider_health_receipts` is append-only evidence. Health states are `HEALTHY`, `DEGRADED`, `ADMIN_BLOCKED`, `DISABLED`, and `UNKNOWN`.

`ADMIN_BLOCKED` and `DISABLED` are hard blocks for failover selection. The first OpenAI real-provider canary returned HTTP 429 with `insufficient_quota`, so OpenAI remains:

`ADMIN_BLOCKED / INSUFFICIENT_QUOTA / retryable=false`

Groq is not hard-blocked. After the scale-20 burst, Groq was conservatively projected to:

`DEGRADED / RATE_LIMIT_AT_CONCURRENCY_20 / retryable=true`

Health receipt: `provider-health-61f12a2228eb8540ee8b7d8b0ea8`.

This keeps normal governed Groq use available while preventing the system from treating the failed 20-concurrent burst as proven capacity.

## Generic worker

`world8-provider-worker-generic-v01` resolves only safe route context from DCP:

- provider;
- adapter config/base URL;
- model id;
- opaque `envref:*` credential reference;
- verified transport/binding state.

The worker resolves the named environment secret locally. Raw credentials never enter DCP, Git, chat, receipts, or outputs.

The worker supports transport challenge attestation, credential provider probe, governed Chat-Completions execution for OpenAI-compatible providers, final-output-only recording, append-only execution evidence, and sanitized provider errors. It does not persist provider error response bodies or private reasoning.

## Groq credential verification — 2026-08-27

The original binding used `envref:GROQ_API_KEY`, but the runtime secret is named `GROQ_API_KEY4`. The corrected opaque binding is:

- adapter: `adapter-groq-external-v01` — ACTIVE;
- binding: `binding-groq-envref-key4-v01` — VERIFIED;
- credential ref: `envref:GROQ_API_KEY4`;
- transport: `transport-supabase-groq-generic-v01` — ACTIVE / VERIFIED.

Credential probe challenge `credential-challenge-a191726e8838c4f5d334fc35be65` returned provider HTTP `200`, result `PASS`, and receipt `credential-receipt-f8363334b524b980756a4fd3d70b`.

No raw Groq key was read, copied, logged, committed, or returned.

## First governed Groq REAL_EXTERNAL canary — SUCCESS

A fresh Mason lane executed one real Groq request using `openai/gpt-oss-20b` and requested exactly `GROQ_CANARY_OK`.

Observed evidence:

- request: `provider-request-d6010202d2af415a0f4be7fb49df`;
- state: `SUCCEEDED`;
- provider HTTP status: `200`;
- `live_provider_invoked=true`;
- output: `GROQ_CANARY_OK`;
- output id: `provider-output-cb4e439cc2511f6603a11dc523fb`;
- final receipt: `provider-receipt-798cd073473c509b31bb07a00013`;
- `test_only=false`;
- raw secret stored: false;
- private reasoning stored: false.

The workspace and assignment were released after success.

## Scale stage 1→5 — SUCCESS

The five-request real-provider stage ran through five independent Mason Work/Assignment/Workspace lanes after canonical-head synchronization.

All lanes used:

- adapter `adapter-groq-external-v01`;
- binding `binding-groq-envref-key4-v01`;
- transport `transport-supabase-groq-generic-v01`;
- model `openai/gpt-oss-20b`;
- `automatic_retry=false`;
- `scale_out=false`;
- `test_only=false`.

Observed evidence:

- 5/5 requests `SUCCEEDED`;
- 5/5 provider HTTP statuses `200`;
- 5/5 deterministic outputs matched exactly;
- 5/5 receipts recorded `live_provider_invoked=true`;
- 5/5 recorded `raw_secret_present=false` and `private_reasoning_present=false`;
- execution duration: min `0.520 s`, mean `0.678 s`, max `0.908 s`.

All five workspaces and assignments were released. This stage established an evidence-backed successful concurrency point of five.

## Scale stage 5→20 — FAILED AT PROVIDER CAPACITY

The 20-request stage was started only after GitHub `main` and DCP both reported canonical head `ff741168011ceb62581964c1b70eda8202482165`, the Mason pool reported 100 active members and zero busy members, and Groq was `HEALTHY / LIVE_READY`.

Twenty independent Mason lanes were reserved, given independent Work and Git-branch workspaces, passed Mason Preflight with no blockers, and each received exactly one explicit provider request. No automatic retry was enabled.

Observed result:

- **10 successful live completions** with provider HTTP `200` and exact deterministic output;
- **9 provider HTTP 429** rate-limit rejections;
- **1 pre-provider dispatch/claim rejection**: Edge dispatch returned HTTP `409` with `CLAIM_REJECTED` and upstream status `401` before a provider call;
- no retry was performed for the 429 responses;
- the queued dispatch-rejected request was terminalized administratively without provider re-dispatch;
- all 20 workspaces and assignments were released after evidence collection.

The 10 successful live-completion lanes were 2, 3, 8, 9, 10, 12, 13, 15, 17, and 20. The 429 lanes were 1, 4, 5, 6, 7, 11, 14, 16, and 18. Lane 19 was the pre-provider dispatch/claim rejection.

This is **not** evidence of 20 successful live provider invocations. It is evidence that an ungoverned 20-concurrent burst exceeds the currently proven Groq capacity for this credential/model/runtime path.

Diagnostic evidence:

- capacity incident: `incident-d38d10e0bb8bc278762788f27349d831`;
- dispatch incident: `incident-415aa7f1028b6d499fd684adbb26052a`;
- health receipt: `provider-health-61f12a2228eb8540ee8b7d8b0ea8`.

## Provider Concurrency Governor v0.1 — ENFORCED

The runtime response to scale-20 is not a hidden retry or a claim of success. A claim-time capacity governor was added.

Canonical runtime objects:

- append-only `world8_provider_capacity_receipts`;
- `world8_provider_capacity_record_v1`;
- `world8_provider_capacity_snapshot_v1`;
- `world8_provider_capacity_claim_gate_v1`;
- capacity enforcement inside `world8_provider_execution_worker_claim_v1` and `world8_provider_execution_claim_v2`.

Current Groq policy:

- policy state: `ENFORCED`;
- `max_concurrent=5`;
- stale RUNNING window: `900` seconds;
- reason: `SCALE20_RATE_LIMIT_EVIDENCE`;
- capacity receipt: `provider-capacity-4f70a248bed2a873841e93c31d26`;
- automatic retry remains false;
- `SCALE_100_BLOCKED` remains true.

The gate uses a provider-specific PostgreSQL advisory transaction lock before counting recent RUNNING requests. At the ceiling it returns `DEFER / PROVIDER_CONCURRENCY_CEILING_REACHED` and the claim path stops before starting a provider invocation.

### Claim-only governor canary — SUCCESS

A six-lane claim-only canary validated enforcement without contacting Groq:

1. claims 1 through 5 passed with observed running counts `0,1,2,3,4`;
2. all five recorded `live_provider_invoked=false`;
3. with five RUNNING requests, `world8_provider_capacity_claim_gate_v1` returned `DEFER`, `running_count=5`, `max_concurrent=5`, and `provider_invoked=false`;
4. the sixth worker claim raised `PROVIDER_CONCURRENCY_CEILING_REACHED` before provider invocation;
5. after the first five claim-only requests were terminalized, the sixth claim passed and was also terminalized without provider invocation;
6. all six canary workspaces and assignments were released.

Canary diagnostic record: `incident-f10b1dbf5bd2348f789ff407709f64c6`.

The v0.1 generic Edge worker surfaces a full-capacity claim as its existing `CLAIM_REJECTED` HTTP 409 response. A first-class `CAPACITY_DEFERRED` Edge response is a v0.2 candidate; safety enforcement does not depend on that UI improvement.

## Engineering experience accumulated

Reusable diagnostics are retained rather than discarded. Relevant lessons include:

- `world8_mason_pool_reserve_v1.p_required_qualifications` is `jsonb`;
- Search and Mason Preflight expose `search_receipt_id` and `preflight_receipt_id`;
- Diagnostic v2 tags must be registered taxonomy values;
- canonical Git state must be re-observed before reservation because DCP projection can drift after merges;
- setup CTE side effects must be materially consumed or executed sequentially;
- `net._http_response` uses column `created`, not `created_at`;
- provider capacity must be enforced in the worker claim path, not inferred from Mason-pool capacity;
- successful N-Mason orchestration capacity is not equivalent to live provider concurrency capacity.

## Scale rule

`GROQ_SCALE_5_SUCCEEDED` remains valid evidence. `GROQ_SCALE_20_FAILED_RATE_LIMIT` is the observed higher-concurrency result. `CONCURRENCY_GOVERNOR_ENFORCED` is now the runtime protection derived from those observations.

The system must **not** advance to 100 concurrent live Groq executions. `SCALE_100_BLOCKED` remains in force until a new governed experiment demonstrates a higher safe concurrency ceiling or a capacity-aware throughput strategy is validated.

A future throughput retest may process 20 total tasks in governed waves constrained by `max_concurrent=5`; that would test throughput and queuing behavior, not claim that 20 concurrent provider calls are safe.

Existing Guardian/N-Mason orchestration has separately been load-tested at 100 concurrent engineering sessions. That remains distinct from provider-call evidence.

## Security and v0.2 candidates

- strengthen public Edge dispatch authentication beyond unpredictable request/capability identifiers;
- surface `CAPACITY_DEFERRED` explicitly instead of generic claim rejection;
- add governed queue wake/re-dispatch after capacity release without violating `automatic_retry=false` semantics;
- provider-specific rate, token, and cost budgets in addition to concurrency ceilings;
- health expiry and automatic observation while keeping health-state promotion governed;
- audited manual capacity override only with explicit governance evidence.
