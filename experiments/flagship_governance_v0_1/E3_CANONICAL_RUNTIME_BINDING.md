# W8-P01 — E3 Canonical / Runtime Binding Matrix

Date: 2026-08-27
Status: **PARTIAL PASS / RUNTIME SOURCE DRIFT OPEN**
Mode: Git source inspection + read-only runtime schema inspection. No live data or provider effect was mutated.

## Purpose

E1/E2 are executable reference-model evidence. E3 asks a stricter question:

> Are the mechanisms measured by the flagship experiment actually represented in the canonical World 8 source and deployed runtime, with enough source lineage to support reproducibility?

A mechanism is classified as:

- `CANONICAL+RUNTIME` — source exists in the canonical repository and the named function is deployed in runtime.
- `RUNTIME_SCHEMA_BACKED` — deployed definition was verified read-only, but behavioral execution was not invoked.
- `RUNTIME_ONLY / SOURCE_DRIFT` — deployed object exists, but the effective source definition is not present in the current canonical Git tree.
- `REFERENCE_MODEL_ONLY` — experiment mechanism has not yet been bound to a canonical/runtime object.

## E2 receipt entering E3

Two-Society conformance run:
- run: https://github.com/saeedfaai/world-8/actions/runs/33103973441
- artifact: `w8-p01-two-society-conformance-v0.1`
- artifact digest: `sha256:f6a0c8a6d4c39daa67326dbcf9f4c34494836ca81d63964b493a989482ac91aa`
- `society_conformance.json` SHA256: `ac3b90efabd1e83c36e388c0bda61dfff5ba325c568a50ad579f74dd1f8f9704`
- 1,000 trials per Society
- Company: all 8 invariants pass = 1.0
- Trading: all 8 invariants pass = 1.0
- conformance vectors equal = true
- same suite / same governed kernel = true
- market performance evaluated = false
- live effects = false

## Binding matrix

| Experiment mechanism / invariant | Canonical Git evidence | Runtime evidence | Status | Claim ceiling |
|---|---|---|---|---|
| Persistent Actor / authorization binding | `20260827111400_world8_identity_authority_verifier_v011.sql` → `world8_authorize_v1`; `20260827114000_world8_n_mason_pool_v01.sql` → assignment/execution/workspace actor checks; `20260827125400_world8_crash_safe_mark_ready_actor_binding_v0111.sql` | functions present in `public`; exact definitions hashed below | CANONICAL+RUNTIME / SCHEMA-BACKED | Can claim architecture and deployed schema bind actor/subject separately from execution/session/provider. Behavioral runtime test still pending. |
| Exact subject-action-resource authorization; DENY/REVOKE precedence | `world8_authorize_v1` in identity/authority v0.1.1; explicit `EXPLICIT_DENY_OR_REVOKE`, `NO_MATCHING_AUTHORITY_RULE`, identity/workspace scope checks and authorization receipt | deployed `world8_authorize_v1` verified | CANONICAL+RUNTIME / SCHEMA-BACKED | May describe fail-closed verifier semantics; do not claim adversarial security completeness. |
| Workspace actor/work binding + stale canonical base protection | `202608271004_world8_developer_admission_workspace_v01.sql` → `world8_dev_register_workspace_v1`, `world8_dev_admission_check_v1`; N-Mason binding functions | deployed functions verified | CANONICAL+RUNTIME / SCHEMA-BACKED | Supports actor/work/workspace binding and stale-base gate. |
| Assignment → Execution actor continuity | `world8_mason_pool_bind_execution_v1` | deployed and hash verified | CANONICAL+RUNTIME / SCHEMA-BACKED | Supports provider/execution binding to persistent Actor; actual provider swap behavior remains a runtime test target. |
| Assignment → Workspace actor continuity | `world8_mason_pool_bind_workspace_v1`; `world8_mason_pool_mark_ready_v1` defense-in-depth | deployed and hash verified | CANONICAL+RUNTIME / SCHEMA-BACKED | Supports exact assignment/work/workspace actor binding. |
| Append-only, chained development evidence | `20260827121700_world8_dev_continuity_core_v01.sql`: journal has `previous_event_hash`, `content_hash`, advisory serialization, append-only UPDATE/DELETE trigger; checkpoints contain journal hash/content hash | `world8_dev_journal_append_v1`, `world8_dev_checkpoint_v1` deployed | CANONICAL+RUNTIME / SCHEMA-BACKED | Supports tamper-evident development continuity model. Mutation/tamper execution against isolated DB pending. |
| Crash-safe closure / resume before new work | `20260827125200_world8_crash_safe_enforcement_v011.sql`; `20260827132600_world8_crash_safe_resume_closure_v012.sql` | `world8_dev_scribe_guard_v1`, `world8_dev_scribe_closure_guard_v1`, `world8_dev_resume_capsule_v2`, handoff/postflight functions deployed | CANONICAL+RUNTIME / SCHEMA-BACKED | Supports deployed recovery/closure gates; clean restore behavioral test pending. |
| Development Lease v3 requires admission + checked authorization | Current `START_HERE.md` and runtime semantics; effective lease v2/v3 source definition recovered from runtime but not found in current canonical migration tree | `world8_dev_acquire_lease_v2/v3` deployed; v2 refuses authorization bypass, verifies admission actor/work/workspace and checked auth evidence | **RUNTIME_ONLY / SOURCE_DRIFT** | Cannot call this fully reproducible/canonical until source lineage is reconciled into Git. |
| Lease heartbeat/release semantics with fencing token surfaced | effective runtime definitions recovered read-only; current canonical Git tree does not contain source | `world8_dev_heartbeat_lease_v1`, `world8_dev_release_lease_v2` deployed | **RUNTIME_ONLY / SOURCE_DRIFT** | Runtime schema evidence only. |
| Sequencer fencing-token rotation / stale expected token rejection | effective runtime definition recovered read-only; current canonical Git tree does not contain source | `world8_maintain_sequencer_lease` deployed; stale expected fencing token raises serializable conflict | **RUNTIME_ONLY / SOURCE_DRIFT** | Do not claim canonical reproducibility until source reconciled. |
| External effect plan binds approval + payload hash + expected head + fencing token | effective runtime definition recovered read-only; current canonical Git tree does not contain source | `world8_plan_task_external_effect` deployed; uses authorization, payload hash, expected head, fencing token and canonical commit | **RUNTIME_ONLY / SOURCE_DRIFT** | Do not use as paper evidence yet. |
| Effect receipt mutation blocked | effective runtime function exists; current canonical Git tree does not contain source | `world8_prevent_effect_receipt_mutation` deployed | **RUNTIME_ONLY / SOURCE_DRIFT** | Runtime schema evidence only. |
| Generic CAS used in E1/E2 reference model | stale-base and runtime commit mechanisms exist, but exact experiment CAS abstraction is broader than one canonical current function | mixed | REFERENCE→PARTIAL BINDING | Use as mechanism illustration, not as exclusive World 8 contribution. Hardened baseline already matches CAS. |
| Durable idempotency used in E1/E2 reference model | runtime effect/outbox path contains business-effect/idempotency concepts, but detailed canonical source binding is not yet complete | mixed | REFERENCE→PARTIAL BINDING | Not an exclusive contribution; hardened baseline already matches durable idempotency. |

## Runtime function-definition receipts

Read-only `pg_proc` inspection returned the following SHA256 hashes of deployed function definitions:

- `world8_authorize_v1` — `1fecca17bef4266d1a5558ffcef6a056b359602edf3c6a59a8a072ffc099fa5a`
- `world8_dev_register_workspace_v1` — `f6ff36204135f30081a1fc1604a6588202935b36f9cdac67d5a9d44ead689a0b`
- `world8_mason_pool_bind_execution_v1` — `9fb88d1efce4cd5ca3885217fcb4712037f4c48c5aea103191b54daba0d42f40`
- `world8_mason_pool_bind_workspace_v1` — `484dd363fb19dfc38453ab7e69b66152fff458cb1471ed813bc9d9c7f791b3b0`
- `world8_mason_pool_mark_ready_v1` — `3815892d0c3aa152a62318d41b8c70e57af3b431e7396fa6c9fb2b522826e9a4`
- `world8_dev_journal_append_v1` — `2a135f78650aa4c8171e8fe834484db8f47fbc53b6ce82b7a7298c5a00f5c68d`
- `world8_dev_checkpoint_v1` — `84afab7d4b77416fde39c534247f5e9fe76f028144c6470879c162f91eb8aa2d`
- `world8_dev_resume_capsule_v2` — `4971dc34cef606d0405d41f122a4d35ddfdf883ce83c3b7252968688f5c25b57`
- `world8_dev_acquire_lease_v2` — `c88a9ad12266bc5a3ae1a653704b26c1cd689518b865cde294285f969851c845`
- `world8_dev_acquire_lease_v3` — `8fb8f0401efd20a46c1b19c08f0a005f76b9387b660cb458f6dd3c45c9b5e1af`
- `world8_maintain_sequencer_lease` — `455ef983ee9461e1db38706aac779c2f7d203568fdc11fd8a9e644d2bd0b117c`
- `world8_plan_task_external_effect` — `4e73a7d389437c57db7ee53289ddcd880d21394ec2f4ccfb69890ca39448e84a`
- `world8_prevent_effect_receipt_mutation` — `bf900d7b71b2181984f973837ecd3ea115ef4d9e47eebce75cb41363126d44c2`

These hashes establish the observed deployed schema definitions at inspection time; they do not by themselves prove runtime behavior.

## Runtime migration-history consistency

Read-only migration history confirms the current Git-visible 2026-08-27 engineering migrations are deployed, including:
- Developer Admission / Workspace
- Identity & Authority v0.1 / v0.1.1
- N-Mason Pool / Merge Queue
- Development Continuity
- Crash-Safe enforcement / actor-binding repair / resume closure
- Engineering Guardian
- Provider execution / credential broker / live bridge

However, the runtime also contains older foundational World 8 functions whose source migrations are not present in the current canonical repository tree. This is a **reproducibility drift**, not evidence of a failure in the deployed function itself.

## E3 gate status

### PASS now
- [x] core identity/authority function exists in canonical Git and runtime
- [x] actor/execution/workspace binding functions exist in canonical Git and runtime
- [x] chained append-only development journal/checkpoint exists in canonical Git and runtime
- [x] crash-safe guard/resume functions exist in canonical Git and runtime
- [x] runtime inspection was read-only; no provider effect or business data mutated

### OPEN before E3 COMPLETE
- [ ] reconcile Lease v1/v2/v3 source lineage into canonical Git
- [ ] reconcile sequencer fencing source lineage into canonical Git
- [ ] reconcile external-effect commit/receipt immutability source lineage into canonical Git, or exclude those mechanisms from W8-P01 claims
- [ ] add isolated behavioral SQL tests for authorization deny/revoke, actor binding, journal tamper protection, lease/fencing, restart/resume
- [ ] rerun architecture/identity/crash-safe validators against the final reconciled source

## Current claim ceiling

W8-P01 may state that the current deployed schema and canonical source independently support persistent actor/authority binding and crash-safe tamper-evident development evidence, and that reference-model conformance passed across Company and Trading adapters.

W8-P01 MUST NOT yet claim a fully reproducible runtime implementation of fencing/effect mechanisms until the source-drift items above are closed.
