# W8-P01 — E3 Runtime Behavioral Probe Receipt

Date: 2026-08-27
Status: **PASS / NON-PERSISTENT PROBES**
Target runtime: World 8 Supabase project
Safety mode: read-only where possible; otherwise explicit transaction + rollback or failure-before-write. No external provider effect was executed.

## Probe set

### P1 — Authorization default-deny

Function: `public.world8_authorize_v1`

Method:
- active Actor: `chatgpt`
- synthetic action/resource with no matching authority rule
- function called inside a transaction
- expected decision: `DENY`
- expected reason: `NO_MATCHING_AUTHORITY_RULE`
- transaction rolled back

Result: **PASS**
Persistent changes: **false**

### P2 — Explicit DENY precedence over ALLOW

Function: `public.world8_authorize_v1`

Method:
- two synthetic append-only rules were inserted inside one transaction for the same synthetic action/resource: one `ALLOW`, one `DENY`
- verifier called before rollback
- expected decision: `DENY`
- expected reason: `EXPLICIT_DENY_OR_REVOKE`
- transaction rolled back

Result: **PASS**
Persistent changes: **false**

### P3 — Stale fencing-token rejection

Function: `public.world8_maintain_sequencer_lease`

Observed before probe:
- world: `world-001`
- runtime session user: `postgres`
- session is a member of `world8_sequencer_executor`
- current fencing token: `30`
- supplied stale expected token: `29`

Method:
- call wrapped in a transaction / exception assertion
- expected SQLSTATE: `40001`
- function rejects before lease update
- transaction rolled back

Result: **PASS**
Persistent changes: **false**

### P4 — External-effect receipt immutability

Guard: `public.world8_prevent_effect_receipt_mutation`
Table: `public.effect_receipts`

Method:
- an existing receipt row was selected
- an UPDATE that would preserve the same metadata was attempted inside a transaction
- expected error text: `effect_receipts are immutable`
- transaction rolled back

Result: **PASS**
Persistent changes: **false**

Interpretation: even a no-op UPDATE is rejected; the evidence table is not merely conventionally immutable.

### P5 — Development journal append-only enforcement

Guard: `public.world8_prevent_dev_continuity_mutation_v1`
Table: `public.world8_dev_session_journal`

Method:
- an existing journal row was selected
- a no-op UPDATE to `summary=summary` was attempted inside a transaction
- expected error text: `WORLD8_DEV_CONTINUITY_EVIDENCE_APPEND_ONLY`
- transaction rolled back

Result: **PASS**
Persistent changes: **false**

### P6 — Work / Actor binding rejection

Function: `public.world8_dev_register_workspace_v1`

Method:
- existing Work: `work-46bae063e66f91bb494ff4386aa4`
- actual Work Actor: `mason-worker-7dedb0-0005`
- supplied mismatched active Actor: `chatgpt`
- expected error: `WORK_ACTOR_MISMATCH`
- rejection occurs before workspace insertion

Result: **PASS**
Persistent changes: **false**

### P7 — Resume capsule is runtime-derived and read-only

Function: `public.world8_dev_resume_capsule_v2`
Work: `work-46bae063e66f91bb494ff4386aa4`

Assertions:
- schema = `WORLD8_DEV_RESUME_CAPSULE/2.1`
- returned work id matches input
- `next_safe_action` is non-empty

Observed state:
- `resume_state = CLOSED_BLOCKED`
- `next_action_source = WORK_GOAL`
- `active_session_count = 0`

Result: **PASS**
Persistent changes: **false**

Important: the probe did **not** require or force a clean state. The runtime correctly reported a blocked closed Work rather than manufacturing a PASS state.

## Recovered-source integrity gate

Historical migration statements were recovered from `supabase_migrations.schema_migrations.statements` and restored on the W8-P01 work branch.

Recovered authoritative statement hashes:
- `20260824130305_w0_0015_sequencer_lease_maintenance.sql`
  - `13b418f2f475bf423592224d44a45739cacc664cd4981263ffe40495f309b99d`
- `20260824133158_w2_0006_external_effect_governance.sql`
  - `bb3a9e65f06d374625ef7378e771ec284993f31278615d519095d5602508d92b`
- `20260824133326_w2_supabase_external_effect_hosted_overlay.sql`
  - `1f0a0789be184d5043d43e34f31a68c4d6042a0152e8e80ff59803994700e81b`

GitHub Actions integrity run:
- https://github.com/saeedfaai/world-8/actions/runs/33106395521
- conclusion: `success`

The integrity workflow verifies the Git files byte-for-byte against the SHA256 values calculated from the authoritative historical migration statements.

## Evidence interpretation

These probes upgrade selected W8-P01 mechanisms from source/schema inspection to **runtime behavioral evidence**:
- default-deny authorization semantics;
- deny precedence;
- stale fencing rejection;
- Work/Actor binding rejection;
- append-only/tamper-blocking evidence ledgers;
- runtime-derived resume state.

They do not establish:
- production security completeness;
- distributed-system linearizability under arbitrary failure;
- external-provider exactly-once effects;
- superiority to other agent frameworks;
- live trading correctness.

## Next gate

Before E3 is declared complete:
1. run canonical architecture/identity/crash-safe/N-Mason validators on the reconciled branch;
2. open a PR to move the recovered historical source into canonical `main`;
3. after canonical merge, repeat source-presence/integrity checks;
4. then begin E4 mutation/compound-fault work.
