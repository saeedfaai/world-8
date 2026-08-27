# W8-P01 — E3 Canonical / Runtime Binding Matrix

Date: 2026-08-27
Status: **PASS ON EVIDENCE BRANCH / CANONICAL MERGE PENDING**
Mode: canonical-source inspection + authoritative historical migration recovery + non-persistent runtime behavioral probes.

## Purpose

E1/E2 are executable reference-model evidence. E3 asks a stricter question:

> Are the mechanisms measured by the flagship experiment represented by reproducible World 8 source lineage and deployed runtime behavior, rather than by a paper-only model?

A mechanism is classified as:

- `CANONICAL+RUNTIME+BEHAVIOR` — source is already present in the current canonical repository lineage, function is deployed, and a bounded runtime behavioral probe passed.
- `CANONICAL+RUNTIME / SCHEMA` — source and deployed object are verified; direct behavioral probe is not yet part of W8-P01 evidence.
- `RECOVERED+RUNTIME+BEHAVIOR / MERGE_PENDING` — authoritative historical migration statement was recovered byte-for-byte from Supabase migration history onto the W8-P01 branch, deployed behavior was probed, but the recovered source is not canonical-main until PR merge.
- `REFERENCE_MODEL_ONLY` — no adequate current source/runtime binding has been established.

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

| Experiment mechanism / invariant | Source evidence | Runtime evidence | Status | Claim ceiling |
|---|---|---|---|---|
| Persistent Actor / authorization binding | `20260827111400_world8_identity_authority_verifier_v011.sql`; `20260827114000_world8_n_mason_pool_v01.sql`; actor-binding repair `20260827125400...` | deployed functions; Work↔Actor mismatch probe passed | CANONICAL+RUNTIME+BEHAVIOR | May claim bounded runtime evidence for actor/work binding and source-level provider/execution separation. Not a proof against all impersonation attacks. |
| Exact subject-action-resource authorization; default DENY; DENY/REVOKE precedence | `world8_authorize_v1` in Identity & Authority v0.1/v0.1.1 | no-rule default-DENY probe PASS; synthetic ALLOW+DENY precedence probe PASS; both rollback-contained | CANONICAL+RUNTIME+BEHAVIOR | May claim fail-closed verifier behavior for tested paths. No general security-completeness claim. |
| Workspace actor/work binding + stale canonical base protection | `202608271004_world8_developer_admission_workspace_v01.sql`; N-Mason binding functions | mismatched Work/Actor rejected before workspace write | CANONICAL+RUNTIME+BEHAVIOR | Supports explicit actor/work/workspace binding. Stale-base source semantics are bound but dedicated live stale-base mutation remains outside this probe set. |
| Assignment → Execution actor continuity | `world8_mason_pool_bind_execution_v1` | deployed and definition-hashed | CANONICAL+RUNTIME / SCHEMA | Source/runtime binding established; cross-provider behavioral comparison remains an E4/E5 candidate. |
| Assignment → Workspace actor continuity | `world8_mason_pool_bind_workspace_v1`; `world8_mason_pool_mark_ready_v1` | deployed and definition-hashed; Work↔Actor rejection observed | CANONICAL+RUNTIME+BEHAVIOR | Supports exact assignment/work/workspace actor binding for tested mismatch path. |
| Append-only, chained development evidence | `20260827121700_world8_dev_continuity_core_v01.sql`: `previous_event_hash`, `content_hash`, advisory serialization, append-only triggers | no-op UPDATE of real journal row rejected by append-only guard; rollback | CANONICAL+RUNTIME+BEHAVIOR | Supports deployed mutation blocking plus source-defined hash chaining. Full chain-verification mutation gate remains E4. |
| Crash-safe closure / resume | crash-safe enforcement + resume-closure migrations | `world8_dev_resume_capsule_v2` read-only probe PASS; real Work reported `CLOSED_BLOCKED`, not fabricated PASS | CANONICAL+RUNTIME+BEHAVIOR | May claim runtime-derived resume state and fail-closed reporting. A clean crash/restart-to-write test remains E4. |
| Development Lease v1 foundation: TTL, fencing-token allocation, write-conflict checks, CAS update | authoritative historical `20260826174552_world8_development_control_plane_v1.sql`, recovered byte-for-byte on this branch | v1/heartbeat/CAS functions deployed | RECOVERED+RUNTIME / MERGE_PENDING | Reproducible on evidence branch; not canonical-main until PR merge. |
| Development Lease v2/v3 requires admission + checked authorization | `202608271105_world8_identity_authority_verifier_v01.sql` already contains effective v2/v3 source; earlier code-search absence was a false negative | `world8_dev_acquire_lease_v2/v3` deployed | CANONICAL+RUNTIME / SCHEMA | May describe fail-closed admission/authorization dependency. Dedicated lease-creation behavioral probe is deferred to isolated E4 work. |
| Sequencer fencing-token CAS / stale token rejection | authoritative historical `20260824130305_w0_0015_sequencer_lease_maintenance.sql`, recovered byte-for-byte on this branch | current token 30; supplied stale token 29 rejected with SQLSTATE `40001`; no persistent change | RECOVERED+RUNTIME+BEHAVIOR / MERGE_PENDING | Strong bounded evidence for stale-token rejection; not a proof of distributed linearizability under arbitrary failures. |
| External effect planning binds explicit approval + payload hash + expected head + fencing token | authoritative historical `20260824133158_w2_0006_external_effect_governance.sql` + hosted overlay, recovered byte-for-byte | planner deployed; no live external effect invoked in W8-P01 | RECOVERED+RUNTIME / MERGE_PENDING | Source/runtime binding only. W8-P01 must not claim live exactly-once provider effects. |
| Effect receipt mutation blocked | same recovered W2 governance source defines immutable receipt trigger | no-op UPDATE of existing `effect_receipts` row rejected with `effect_receipts are immutable`; rollback | RECOVERED+RUNTIME+BEHAVIOR / MERGE_PENDING | Supports deployed append-preservation for tested mutation path. |
| Generic CAS in E1/E2 reference model | DCP v1 contains `world8_dev_cas_update_artifact_v1`; external-effect commit also carries expected-head semantics | source/runtime mechanisms exist | PARTIAL BINDING; NOT EXCLUSIVE CONTRIBUTION | Hardened baseline already matches CAS; use only as a shared control mechanism, not novelty. |
| Durable idempotency in E1/E2 reference model | W2 effect governance contains attempt collision/replay and outbox business-effect keys | deployed path exists; no provider effect invoked | PARTIAL BINDING; NOT EXCLUSIVE CONTRIBUTION | Hardened baseline already matches durable idempotency; not a novelty claim. |

## Runtime behavioral probe receipt

See:
`experiments/flagship_governance_v0_1/E3_RUNTIME_BEHAVIORAL_PROBES.md`

PASS set, all with `persistent_changes=false`:
1. default-DENY authorization;
2. explicit DENY precedence over ALLOW;
3. stale sequencer fencing token rejection;
4. effect-receipt mutation rejection;
5. development-journal mutation rejection;
6. Work↔Actor mismatch rejection;
7. read-only resume-capsule derivation.

No external provider effect, live trade, supplier order, or durable synthetic authorization rule was left behind.

## Authoritative source recovery

Historical SQL was recovered from `supabase_migrations.schema_migrations.statements`, not reconstructed from current `pg_get_functiondef` output.

Recovered branch files and authoritative statement SHA256:

- `20260824130305_w0_0015_sequencer_lease_maintenance.sql`
  - `13b418f2f475bf423592224d44a45739cacc664cd4981263ffe40495f309b99d`
- `20260824133158_w2_0006_external_effect_governance.sql`
  - `bb3a9e65f06d374625ef7378e771ec284993f31278615d519095d5602508d92b`
- `20260824133326_w2_supabase_external_effect_hosted_overlay.sql`
  - `1f0a0789be184d5043d43e34f31a68c4d6042a0152e8e80ff59803994700e81b`
- `20260826174552_world8_development_control_plane_v1.sql`
  - `634d057945e8d7de6b1bdf6712f18b11109d2682760bbdd30fcda117ba93c52d`

Integrity run after the guarded one-byte EOF-newline repair:
- https://github.com/saeedfaai/world-8/actions/runs/33107476738
- all four `sha256sum -c` checks: PASS

The earlier DCP recovery failure is retained as diagnostic evidence: the integrity gate caught a one-byte missing final newline; segment hashing localized it to EOF; a guarded repair appended only ASCII 10 and the authoritative full-file hash then passed.

## Runtime function-definition receipts

Read-only `pg_proc` inspection returned:

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

These definition hashes establish the observed deployed function bodies at inspection time. Behavioral claims are limited to the explicit probe set above.

## E3 gate status

### PASS on the W8-P01 evidence branch
- [x] identity/authority source ↔ deployed runtime bound
- [x] actor/work/workspace source ↔ deployed runtime bound
- [x] append-only chained development evidence source ↔ deployed runtime bound
- [x] crash-safe resume source ↔ deployed runtime bound
- [x] Lease v2/v3 source confirmed in existing Git history
- [x] direct Lease v1/DCP dependency source recovered byte-for-byte
- [x] sequencer fencing source recovered byte-for-byte
- [x] external-effect governance/receipt source recovered byte-for-byte
- [x] four-file source-recovery integrity gate PASS
- [x] bounded runtime behavioral probes PASS with no persistent external effect

### OPEN before E3 COMPLETE / canonical claim
- [ ] run the final branch validator suite against reconciled source
- [ ] merge recovered historical source through a governed PR into canonical `main`
- [ ] confirm post-merge source presence/integrity on canonical `main`

## Current claim ceiling

W8-P01 now has reference-model evidence, two-Society conformance, authoritative source lineage on the evidence branch, and bounded runtime behavioral evidence for its central governance mechanisms.

Until the recovery PR is merged and post-merge integrity is verified, language must say **reconciled on the evidence branch** rather than **fully canonicalized in main**.

E4 still owns mutation testing, compound failures, clean crash/restart-to-write behavior, and quantitative false-deny / valid-path costs.
