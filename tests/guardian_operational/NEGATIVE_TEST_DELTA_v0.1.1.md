# Operational Guardian v0.1.1 — Negative Test Delta

Status: TEST SPECIFICATION ONLY / NO RUNTIME PASS CLAIM
Base matrix: `NEGATIVE_TEST_MATRIX_v0.1.md`
DCR: `architecture/proposals/DCR-0001-operational-guardian-dispatch-idempotency.md`

These cases are mandatory additions/clarifications for the effective v0.1.1 implementation contract.

| ID | Scenario | Expected result |
|---|---|---|
| OG-N51 | Replay exact `(gap_id, policy_version, dispatch_slot_key, attempt_no)` | Return prior semantic result or reject duplicate; never create second lane |
| OG-N52 | REDUNDANT_N creates `redundant:1` and `redundant:2` for same Gap/policy/attempt with approved N>=2 | Both lanes are valid and distinct; no idempotency collision |
| OG-N53 | REDUNDANT_N creates `redundant:4` while approved N=3 | REJECT before dispatch/reservation |
| OG-N54 | REDUNDANT_N uses malformed slot key such as `single` or `redundant:0` | REJECT |
| OG-N55 | SHARDED creates `shard:<work_order_id>` that is not present in validated decomposition plan | REJECT |
| OG-N56 | SHARDED slot key uses REDUNDANT_N semantics | REJECT; SHARDED x REDUNDANT_N remains forbidden |
| OG-N57 | SINGLE uses anything except `dispatch_slot_key=single` | REJECT |
| OG-N58 | Mutation attempts to change `dispatch_slot_key` after WorkControl creation | REJECT immutable identity field |
| OG-N59 | Mutation attempts to change dispatch mode while preserving same slot identity | REJECT immutable assignment lineage |
| OG-N60 | Retry rewrites attempt=1 WorkControl instead of creating allowed attempt=2 lineage | REJECT history rewrite |
| OG-N61 | WorkControl core state is set to `QUARANTINED` | REJECT/conformance failure; quarantine is separate overlay aggregate |
| OG-N62 | Active IMMEDIATE QuarantineDecision exists while WorkControl remains ACTIVE | Allowed representation; effective operations must be fenced by quarantine overlay |
| OG-N63 | Quarantine expires/lifts and implementation rewrites historical WorkControl lifecycle to reconstruct it | REJECT; quarantine history remains in its own aggregate/events |

## Required mutation additions

Critical mutants that must be killed when executable tests exist:

1. remove `dispatch_slot_key` from natural uniqueness/idempotency semantics;
2. use `assignment_kind` as the only parallel-lane discriminator;
3. permit redundant ordinal above policy-approved N;
4. skip shard membership validation against decomposition plan;
5. allow `dispatch_slot_key` mutation after creation;
6. add `QUARANTINED` back into core WorkControl lifecycle and bypass quarantine overlay.

## Evidence rule

A textual/static check may prove only contract consistency. Runtime evidence requires these cases to execute against actual mutation RPCs/schema, with critical bypass mutants killed.
