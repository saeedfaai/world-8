# First Real Provider Canary

Status: `TRANSPORT_VERIFIED / CREDENTIAL_VERIFIED / LIVE_READY / REAL_PROVIDER_REACHED / CANARY_FAILED_OPENAI_429 / NO_SCALE_OUT`

Work: `work-bc8ebdac796d271e6bf9b0104fbf`

Canonical base: `3d2a4208e9a7336f0d050292730e73faf4bba6c6`

## Goal

Execute exactly one evidence-backed `REAL_EXTERNAL` provider canary before any scale-out. Actor identity remains provider-independent. Provider/model data belongs to Execution only.

## Verified worker transport

Worker: `world8-provider-worker-canary-v01`

Transport: `transport-supabase-world8-provider-canary-v01`

The worker is a Supabase Edge Function. Challenge tokens and credential probe tokens are transient and dispatched with `pg_net` after commit; raw tokens never enter DCP evidence or tool arguments.

Worker challenge evidence:

- challenge: `worker-challenge-83010632b77ad71df7f7ce8c756f`
- canonical challenge state: `CONSUMED`
- transport verification state: `VERIFIED`
- receipt: `worker-receipt-20581d3521386d56ed2425de23bc`
- verification kind: `CHALLENGE_ATTESTATION`
- result: `PASS`

## Credential state

Adapter: `adapter-openai-external-v01`

Binding: `binding-openai-envref-v01`

Credential ref: `envref:OPENAI_API_KEY`

Credential challenge: `credential-challenge-fdee714031fd9e3cc35033031ced`

Current credential state: `VERIFIED`.

`world8_provider_execution_readiness_v2(...)` returned:

- `gate_state=PASS`
- `readiness_state=LIVE_READY`
- `live_ready=true`
- transport verification: `VERIFIED`
- credential verification: `VERIFIED`
- blockers: `[]`

No raw provider secret is stored in DCP, Journal, Diagnostic Memory, Git, or receipts.

## First real provider execution attempt

A real Mason Actor was reserved from `pool-world8-engineering-main`:

- actor: `mason-worker-7dedb0-0001`
- assignment: `assignment-f17beeaee0bb684d92c4ded5e01a2007`
- Work: `work-30bcfef47b3536d2c5a8e9cfc304`
- Workspace: `workspace-abef7b1d80710f671848907050463ef3`
- branch: `work/live-provider-canary-mason-0001`
- model requested: `gpt-5-mini`

Provider Execution request:

- request: `provider-request-9dbced9140497522dc113561165a`
- Actor Execution: `execution-8480f615f20aceac4e420a811a091977`
- adapter: `adapter-openai-external-v01`
- transport: `transport-supabase-world8-provider-canary-v01`
- credential binding: `binding-openai-envref-v01`

The first Worker claim exposed a real contract mismatch: the N-Mason workspace binding correctly moved the Assignment to `CODING`, but `world8_mason_pool_bind_execution_v1` accepted only `WORK_BOUND|EXECUTING`. The function was repaired to accept `CODING` while still requiring the Work/Actor/Workspace binding and an ACTIVE Actor Execution.

After the repair, a transactional dry-run confirmed the Worker claim would succeed without mutating state. The real Worker execution then reached OpenAI `/v1/responses`.

Result:

- `provider_invoked=true`
- provider HTTP status: `429`
- request state: `FAILED`
- Actor Execution state: `FAILED`
- error code: `OPENAI_HTTP_429`
- output: none
- raw secret stored: false
- private chain-of-thought stored: false

Therefore World 8 has evidence that the real external transport, credential resolution, request claim, Actor Execution binding, and provider network call all work. It does **not** yet have a successful AI coding completion. Scale-out remains blocked until a fresh canary succeeds after provider quota/rate-limit capacity is available.

## Scale gate

Do not scale to 5/20/100 real provider executions until all are true:

1. provider capacity is confirmed;
2. a fresh Work/Assignment is created;
3. `readiness_v2=PASS/LIVE_READY` immediately before enqueue and claim;
4. exactly one new canary reaches `SUCCEEDED`;
5. output is stored with hash/evidence;
6. completion receipt has `live_provider_invoked=true` and `test_only=false`;
7. failed or stale Assignments/Workspaces are released cleanly.

## Non-negotiable boundaries

- No raw provider secret outside the secret store.
- No private chain-of-thought storage.
- No synthetic credential or transport verification.
- No provider-dependent Actor identity.
- No task execution before `readiness_v2=PASS`.
- No retry of a failed real request under a Work whose execution budget is exhausted.
- No scale-out before one real canary is `SUCCEEDED` with evidence.
