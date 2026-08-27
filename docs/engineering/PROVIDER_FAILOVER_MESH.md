# World 8 Provider Failover Mesh v0.1

Status: IMPLEMENTED / RUNTIME-VALIDATED / GROQ_SCALE_5_SUCCEEDED / SCALE_20_ELIGIBLE_NOT_STARTED

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

## Scale stage 1→5 — SUCCESS

The five-request real-provider stage was executed on 2026-08-27 using five independent Mason lanes. Before execution, preflight detected a canonical-head drift: GitHub `main` had advanced from `f4930195eef61fefe78f9edc0c386a1f58151ed2` to `a46bab811965434ff4f491f30953292de8d7e41b`, while the DCP canonical resource still advertised the older head. The stale reservations were released, `resource-github-world8-canonical` was synchronized, and all five fresh assignments were then reserved against `a46bab811965434ff4f491f30953292de8d7e41b`.

All lanes used:

- adapter: `adapter-groq-external-v01`;
- binding: `binding-groq-envref-key4-v01`;
- transport: `transport-supabase-groq-generic-v01`;
- model: `openai/gpt-oss-20b`;
- `automatic_retry=false`;
- `scale_out=false`;
- `test_only=false`.

| Lane | Actor | Assignment | Work | Workspace | Provider Request | Output | Success Receipt |
|---|---|---|---|---|---|---|---|
| 1 | `mason-worker-7dedb0-0006` | `assignment-a639a42efa55f326195fdd51965e9acc` | `work-3b339552e2a82a426771bbd9b56c` | `workspace-282bef562d1d71fadfd8084e4e85dec3` | `provider-request-7455b55a4f3c6e07177a6aa5188b` | `provider-output-cbc0fad535cb643725dae7855d35` | `provider-receipt-9c8f604bf03da483a27a5fb725e4` |
| 2 | `mason-worker-7dedb0-0007` | `assignment-d30d0945be06400978cbf379362f8c04` | `work-336b6d17a8147434b135b03d34fb` | `workspace-199c35a1fbdfa59330f3a73c6f0537de` | `provider-request-80535b58ded24ade021d9ddd936e` | `provider-output-48be77fabe5629c076e2e7e98329` | `provider-receipt-2ddbda4587fba6669189b5b011f9` |
| 3 | `mason-worker-7dedb0-0008` | `assignment-1ee7465b2d4950aff1bee40a1556e78a` | `work-be1f501b1792f520b3c613c44196` | `workspace-8215b6ec3b395942a06686acdbbbd67d` | `provider-request-aae6976863c0a678cfdd5fd86174` | `provider-output-5b945e6ea9568c4af8256d97c7c4` | `provider-receipt-4c009c3f196c2656d96224acdd70` |
| 4 | `mason-worker-7dedb0-0009` | `assignment-b783fba79e3f9eb3dfa8a033c6b12910` | `work-7483072a6fbdb782b7eeabb1c8fe` | `workspace-984f7aa328bafce0cfd204e5a9437914` | `provider-request-6f300425c44d18347eafb88cd16b` | `provider-output-c62897c060ea0e5d95e9109f8c0b` | `provider-receipt-11afd79c68594be950ae53adc881` |
| 5 | `mason-worker-7dedb0-0010` | `assignment-f217cf62978cf591db9173b19920a99b` | `work-cfa16032d0c0216cc78705a409e2` | `workspace-84993161831013a081537b08c9a2110b` | `provider-request-d41954dd79c80296ede5e8ca25a2` | `provider-output-b2298112ccb09753dc36f671a59a` | `provider-receipt-a5997b4f1f9ac715a5d1c1183512` |

Each task requested one deterministic line, `GROQ_SCALE5_LANE_N_OK`. Observed evidence:

- 5/5 requests reached `SUCCEEDED`;
- 5/5 provider HTTP statuses were `200`;
- 5/5 outputs exactly matched their requested deterministic line;
- 5/5 receipts recorded `live_provider_invoked=true`;
- 5/5 receipts recorded `test_only=false`;
- 5/5 receipts recorded `raw_secret_present=false`;
- 5/5 receipts recorded `private_reasoning_present=false`;
- observed provider execution duration: min `0.520 s`, mean `0.678 s`, max `0.908 s`.

All five Workspaces and Mason Assignments were released after verification. The canary lanes made no code mutation and did not alter canonical `main`.

### Engineering experience accumulated during scale-5

The stage also produced reusable diagnostic evidence rather than discarding orchestration mistakes:

- `world8_mason_pool_reserve_v1` requires `p_required_qualifications` as `jsonb`, not `text[]`;
- Search and Mason Preflight results expose `search_receipt_id` and `preflight_receipt_id`, not a generic `receipt_id`;
- Diagnostic v2 tags must exist in the registered diagnostic taxonomy; arbitrary tags are rejected;
- `world8_dev_workspaces` uses `state` and `updated_at`; there is no `released_at` column;
- canonical Git state must be re-observed before reservation because DCP resource metadata can drift after a merge;
- setup CTEs that perform side-effecting function calls must be materially consumed or executed sequentially; the scale-5 evidence Work therefore uses ordered PL/pgSQL calls for binding.

## Scale rule

The single-canary stage and the five-request real-provider stage have both succeeded. The next scale stage, up to 20 governed real provider executions, is now eligible but **has not been started automatically**.

Any 5→20→100 progression must preserve readiness checks, explicit Work/Assignment/Workspace binding, execution receipts, cost/rate awareness, cleanup, canonical-head synchronization, and failure containment. A failure or exhausted provider execution is not retried inside the same Work; a fresh governed Work/Assignment/Workspace is required.

Existing Guardian/N-Mason orchestration has already been load-tested separately at 100 concurrent engineering sessions; that remains distinct from evidence of 100 live provider invocations.

## Security limitations / v0.2 candidates

- strengthen public Edge dispatch authentication beyond unpredictable capability/request IDs;
- provider-specific rate/capacity budgets and concurrency allocation;
- health expiry and automatic observation, while keeping health-state promotion governed;
- audited manual override policy if approved by governance.
