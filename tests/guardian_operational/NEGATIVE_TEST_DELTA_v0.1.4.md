# Operational Guardian — Negative Test Delta v0.1.4

Status: SPECIFIED / NOT EXECUTED
Contract: `architecture/contracts/guardian-operational-v0.1.4.yaml`
DCR: `architecture/proposals/DCR-0004-operational-guardian-envelope-allocation.md`

These tests are added to the existing v0.1-v0.1.3 suite.

| ID | Fault / mutation | Required result |
|---|---|---|
| OG-N86 | Create child envelope allocation without reducing parent available / increasing parent reserved | REJECT / invariant failure |
| OG-N87 | Allocate across two Societies | REJECT |
| OG-N88 | Allocate parent SPEND/tokens to child CAPACITY/concurrency | REJECT dimension mismatch |
| OG-N89 | Allocate with different units for same dimension key | REJECT |
| OG-N90 | Allocate while parent `overhang > 0` | REJECT new allocation |
| OG-N91 | Allocate above parent available | REJECT |
| OG-N92 | Replay same allocation idempotency key | IDEMPOTENT / no double encumbrance |
| OG-N93 | Reuse allocation idempotency key with different amount/child | REJECT collision |
| OG-N94 | Child task settlement mutates World/Society ancestors per task | FAIL architecture test; ancestor hot-row path forbidden |
| OG-N95 | Reclaim more than `remaining_encumbered` | REJECT |
| OG-N96 | Finalize spend more than `remaining_encumbered` | REJECT |
| OG-N97 | Reconciliation violates `allocated = reclaimed + finalized + remaining` | REJECT / transaction rollback |
| OG-N98 | Reclaim unused funds but leave parent `reserved` unchanged | REJECT accounting mismatch |
| OG-N99 | Finalize child spend but move parent encumbrance directly to available | REJECT; must move parent R -> S |
| OG-N100 | Close allocation with non-zero `remaining_encumbered` | REJECT |
| OG-N101 | Parent envelope CAS changes between read and allocation commit | REJECT stale parent version |
| OG-N102 | Guardian increases hard ceiling while creating allocation | REJECT / governance-only ceiling increase |
| OG-N103 | Allocation event written with stale Guardian epoch/fence | REJECT |
| OG-N104 | Allocation projection changes without matching Operational Control event | FAIL evidence/invariant test |
| OG-N105 | Archive/replay loses allocation lineage needed to explain parent reserved | FAIL recovery test |

## Mutation kills required

At minimum, the executable mutation gate must kill variants that:

1. skip parent available decrement;
2. skip parent reserved increment;
3. remove same-Society check;
4. remove dimension/unit check;
5. permit allocation under overhang;
6. permit reconciliation above remaining encumbrance;
7. remove parent envelope CAS;
8. perform ancestor update on every child reservation/settlement;
9. omit the allocation event while mutating projections.

No PASS claim is allowed until these are executable against an authorized disposable/dev database.
