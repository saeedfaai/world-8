# W8-P01 — E4 Scoped Close

Date: 2026-08-27
Status: **PASS WITH SCOPE / E5 MAY START**

E4 is closed for purposes of starting E5, with a deliberately bounded claim ceiling.

## Evidence that passed

### Reference-model mutation gate
- Run: https://github.com/saeedfaai/world-8/actions/runs/33107646035
- 5 controlled mutations
- 500 trials per mutation
- killed: 5/5
- mutation score: 1.0
- full-system target failure rate: 0.0 for each target metric
- mutant target failure rate: 1.0 for each target metric
- runtime DB mutated: false

Mutations:
1. remove Actor binding → F2 unauthorized effect exposed
2. remove CAS → F4 stale write exposed
3. remove fence → F7 invalid-fence effect exposed
4. remove idempotency → F5 duplicate effect exposed
5. remove hash-chain verification → F9 tamper detection lost

### Reference-model compound-fault gate
- Run: https://github.com/saeedfaai/world-8/actions/runs/33108000278
- 1,000 trials per compound case
- World 8 safe rate: 1.0 in all three compound cases
- hardened baseline targeted failure exposed: 1.0 in all three cases
- valid-path false-deny rate: 0.0 for normal, session-swap, and restart/reconstruct controls
- runtime DB mutated: false

### Runtime-bound negative controls / behavioral probes
Performed against deployed Supabase with read-only or rollback-safe probes; no external provider/business effect was emitted and no experimental residue was intentionally retained.

PASS:
- authorization fail-closed + DENY precedence
- stale fencing token rejection (stale 29 vs observed current 30 at probe time)
- immutable effect-receipt mutation guard
- append-only development-journal mutation guard
- actor/work binding mismatch blocking with admission row count unchanged 64 → 64
- resume capsule reconstruction: `CLOSED_CLEAN`, 20-event journal tail, next action sourced from `FINAL_HANDOFF`

## Known limitation retained

`world8_mason_pool_bind_execution_v1` is canonical-source-backed and deployed, but no suitable ACTIVE execution + compatible assignment existed for a clean live behavioral probe. This mechanism is therefore schema/runtime-backed, not directly behavior-probed in E4.

A separate runtime failure mode was also discovered and is not hidden: `world8_dev_admission_check_v2` can raise an FK exception for a nonexistent `workspace_id` instead of returning a clean BLOCKED receipt. No persistent write was observed in the probe.

## Why E4 is not called “production proof”

We did **not** mutate production PostgreSQL functions to create runtime mutants. Doing so would be an unsafe research method on a live control plane. Therefore:
- mutation score 1.0 applies to the executable reference model;
- deployed runtime evidence consists of source binding plus targeted negative-control and recovery probes;
- no claim of arbitrary fault tolerance, complete security, or production correctness is authorized.

## E5 unlock

E5 may now start because:
- mechanisms have been falsified against a hardened baseline;
- cross-Society conformance passed;
- canonical/runtime lineage is materially reconciled;
- controlled mutation and compound-fault gates passed;
- key runtime negative controls passed;
- limitations and discovered failures are explicitly retained.

E5 order:
1. W8-P01 vs W8-P02 overlap/ownership audit
2. external-framework comparison design and fair baseline selection
3. related-work verification and venue-fit update
4. exact evidence freeze from canonical `main`
5. claim ledger
6. only then full manuscript drafting
