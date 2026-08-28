# Operational Guardian v0.1.2 — Negative Test Delta

Status: TEST SPECIFICATION ONLY / NO RUNTIME PASS CLAIM
Base matrix: `NEGATIVE_TEST_MATRIX_v0.1.md`
Prior delta: `NEGATIVE_TEST_DELTA_v0.1.1.md`
DCR: `architecture/proposals/DCR-0002-operational-guardian-budget-scope-identity.md`

| ID | Scenario | Expected result |
|---|---|---|
| OG-N64 | Create two Society-level envelopes for same Society/dimension using NULL project/pool routing refs | REJECT duplicate logical envelope identity |
| OG-N65 | Create two Project-level envelopes for same Society/project/dimension while pool ref is NULL | REJECT duplicate logical envelope identity |
| OG-N66 | Same `scope_ref` and dimension exist in two different Societies | Allowed; Society remains part of identity |
| OG-N67 | Envelope has empty/blank `scope_ref` | REJECT |
| OG-N68 | Mutation attempts to change `scope_kind` or `scope_ref` after envelope creation | REJECT immutable identity field |
| OG-N69 | Parent envelope Society A allocates child envelope in Society B through ordinary Guardian path | REJECT cross-Society hierarchy |
| OG-N70 | Assignment in Society A reserves from envelope in Society B | REJECT before accounting mutation |
| OG-N71 | Change `project_id`/`pool_id` routing metadata to mint a second envelope with same canonical scope identity | REJECT duplicate logical identity |
| OG-N72 | Two concurrent creates race for same `(society_id, scope_kind, scope_ref, dimension_class, dimension_key)` | At most one succeeds; no duplicate truth |
| OG-N73 | Envelope ceiling/accounting update attempts to rewrite scope identity instead of advancing version | REJECT history/identity rewrite |

## Required mutation additions

Critical mutants that must be killed when executable tests exist:

1. restore nullable `(society_id, project_id, pool_id, dimension_class, dimension_key)` as the only UNIQUE identity;
2. remove Society from envelope natural identity;
3. permit empty `scope_ref`;
4. allow scope identity mutation after creation;
5. skip parent/child same-Society validation;
6. skip assignment/envelope Society match during reservation;
7. use routing metadata changes to bypass canonical envelope uniqueness.

## Evidence rule

Static checks prove only artifact consistency. Runtime evidence requires these cases to execute against the actual envelope/reservation mutation RPCs with concurrency tests and the listed critical bypass mutants killed.
