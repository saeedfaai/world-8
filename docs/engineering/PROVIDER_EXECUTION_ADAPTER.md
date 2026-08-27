# World 8 Provider Execution Adapter v0.1

Status: FOUNDATION IMPLEMENTED IN RUNTIME / VALIDATED LOCALLY / LIVE EXTERNAL PROVIDER NOT READY

## Purpose

The Provider Execution Adapter is the bridge between a governed N-Mason assignment and an actual model-provider execution lifecycle. It does not create a second Actor identity system and it does not make provider/model part of Actor identity.

**Actor identity persists; provider/model belongs only to Execution.**

The adapter reuses:
- `world8_actor_executions`
- `world8_mason_assignments`
- Work / Workspace / Admission / Lease
- Guardian context
- Diagnostic Memory

## Credential boundary

Credential mode is **OPAQUE_REF_ONLY**.

Allowed references are opaque identifiers such as `envref:...`, `vault:...`, `secretref:...`, or `connector:...`.

**No raw provider secrets** may be stored in execution requests, receipts, metadata, task text, or context refs. Private reasoning / chain-of-thought fields are rejected by the same boundary.

A real external adapter remains fail-closed while the credential broker is absent. Current readiness reason is:

`CREDENTIAL_BROKER_NOT_IMPLEMENTED`

## Lifecycle

`Assignment/Work/Workspace -> enqueue -> claim -> world8_actor_executions -> heartbeat -> result/failure receipt`

The execution request is idempotent. Claiming creates the provider/model-specific Execution and, when an N-Mason assignment is present, binds that execution back to the assignment. Result receipts are append-only.

## v0.1 safety state

- Mock internal adapter: lifecycle testing only.
- Real external adapter: registered but not live-ready until credential verification and an external network worker exist.
- No provider network call is performed by this DCP foundation.
- No claim of live provider invocation is allowed from mock lifecycle evidence.
- No autonomous canonical promotion or merge is introduced.
- Guardian authority remains NONE.

## Scale evidence

World 8 has already passed a **100 concurrent Mason** orchestration/Guardian scale run: 100 Work lanes, 100 active Sessions, 100 active Guardian Companions, zero degraded attaches, overlap awareness and existing-governance pre-action gates functioning under load. That proves the control plane can host the concurrency; it does not by itself prove 100 external LLM workers.

The remaining path to 100 genuinely independent coding brains is:

1. verified opaque credential broker;
2. external provider worker transport;
3. real request claim and model invocation;
4. result receipt / patch evidence;
5. progressive live scale 1 -> 5 -> 20 -> 100 executions.

## Non-claims

Until verified external workers exist and corresponding `world8_actor_executions` are actually ACTIVE, do not state that 100 external LLM coders are running.
