# W8-P01 — E3 Runtime Behavioral Receipt

Date: 2026-08-27
Status: **PASS WITH ONE DISCOVERED FAILURE MODE**
Provider mutation policy: **NO LIVE EXTERNAL EFFECTS / NO PERSISTENT PROBE WRITES**

## Scope

These probes were executed against the deployed World 8 Supabase runtime. Read-only probes were used where possible. Write-path probes were either blocked by runtime guards or executed inside PL/pgSQL exception subtransactions so all permanent-table changes were rolled back before the probe result was recorded.

## Behavioral probes

| Probe | Result | Persistent changes | Runtime observation |
|---|---|---:|---|
| Authorization fail-closed + DENY/REVOKE precedence | PASS | false | Unified verifier blocked an ungranted/denied request under deployed rules. |
| Stale sequencer fencing token | PASS | false | Current runtime token was 30; supplied stale token 29 was rejected before any lease mutation. |
| Effect receipt tamper guard | PASS | false | `effect_receipts` UPDATE was rejected with `effect_receipts are immutable`. |
| Development journal tamper guard | PASS | false | `world8_dev_session_journal` UPDATE was rejected with `WORLD8_DEV_CONTINUITY_EVIDENCE_APPEND_ONLY`. |
| Resume capsule reconstruction | PASS | false | Work `work-a5517129d0e73ead523f5b6fa426` returned schema `WORLD8_DEV_RESUME_CAPSULE/2.1`, `resume_state=CLOSED_CLEAN`, 20 journal-tail events, zero active sessions, and `next_action_source=FINAL_HANDOFF`. |
| Actor/work binding mismatch | PASS | false | Admission probe using Actor `chatgpt` against work owned by `chatgpt-mason` detected `WORK_ACTOR_MISMATCH` plus inactive/mismatched workspace; admission receipt row count remained 64 before and after rollback. |

## Execution-binding limitation

`world8_mason_pool_bind_execution_v1` is deployed and canonical-source backed. Its deployed definition explicitly requires an ACTIVE execution and rejects `ASSIGNMENT_EXECUTION_ACTOR_MISMATCH` before updating the assignment.

At probe time there were no ACTIVE `world8_actor_executions`, so a production-runtime behavioral mismatch probe was intentionally not fabricated against completed assignments. This remains **CANONICAL+RUNTIME SCHEMA-BACKED**, not behaviorally exercised in E3.

## Discovered failure mode — admission workspace FK exception

A rollback-safe actor-binding probe initially used a deliberately nonexistent workspace ID. `world8_dev_admission_check_v2` correctly assembled blockers including `ACTIVE_WORKSPACE_REQUIRED`, but then attempted to insert the blocked admission receipt using the nonexistent `workspace_id`. The insert violated `world8_dev_admission_receipts_workspace_id_fkey` and raised an exception instead of returning a clean `BLOCKED` receipt.

Observed error family:
`23503 foreign_key_violation`

Impact:
- no persistent mutation occurred;
- authorization was not bypassed;
- however, the failure semantics are worse than the intended structured fail-closed receipt contract.

Required follow-up:
- add regression test;
- decide whether blocked admission receipts should allow `workspace_id` null when the workspace is unresolved/nonexistent, or whether the function must avoid receipt insertion until a valid workspace reference exists;
- preserve this as a negative/failure-mode result in W8-P01 engineering evidence.

## Source recovery integrity

Historical source drift was reconciled from authoritative `supabase_migrations.schema_migrations.statements` for:
- `20260824130305_w0_0015_sequencer_lease_maintenance.sql`
- `20260824133158_w2_0006_external_effect_governance.sql`
- `20260824133326_w2_supabase_external_effect_hosted_overlay.sql`

Integrity workflow:
https://github.com/saeedfaai/world-8/actions/runs/33106395521

Result: **SUCCESS**

Expected historical statement SHA256 values verified byte-for-byte:
- sequencer lease: `13b418f2f475bf423592224d44a45739cacc664cd4981263ffe40495f309b99d`
- external effect governance: `bb3a9e65f06d374625ef7378e771ec284993f31278615d519095d5602508d92b`
- hosted overlay: `1f0a0789be184d5043d43e34f31a68c4d6042a0152e8e80ff59803994700e81b`

## E3 conclusion

E3 is now **COMPLETE WITH LIMITATIONS** for the mechanisms actually claimed:
- persistent actor/work authorization binding — canonical + runtime + behavioral mismatch probe;
- fail-closed authorization — canonical + runtime + behavioral probe;
- fencing stale-token rejection — recovered canonical historical source + runtime + behavioral probe;
- tamper-evident evidence guards — canonical/recovered source + runtime + behavioral probes;
- crash-safe resume reconstruction — canonical + runtime + behavioral read-only probe.

Limitations retained:
- assignment→execution actor mismatch is schema-backed but not behaviorally exercised because no ACTIVE execution was available;
- external provider effects were not executed;
- admission nonexistent-workspace behavior has a structured-error defect and is explicitly carried into E4.
