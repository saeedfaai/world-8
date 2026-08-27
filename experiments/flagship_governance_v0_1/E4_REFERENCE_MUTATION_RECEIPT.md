# W8-P01 — E4 Reference-Model Mutation Gate Receipt

Date: 2026-08-27
Status: **PARTIAL PASS / REFERENCE-MODEL ONLY**

## Run

- GitHub Actions: https://github.com/saeedfaai/world-8/actions/runs/33107646035
- artifact: `w8-p01-mutation-gate-v1`
- artifact digest: `sha256:69205d5139920271ad5d20a624855f54345b257d23bf8f6f520f4605901de8ee`
- `mutation_gate_v1.json` SHA256: `f107c531c58f3e99fe74b7f5f168e7870d8def7f88cf65845e3c4601c7bdf2ac`
- seed: `20260827`
- trials per mutation: `500`
- mutations: `5`
- killed: `5`
- mutation score: `1.0`
- runtime DB mutated: `false`

## Mutations

| Mutation | Target scenario | Expected exposed failure | Mutant failure rate | Full-system failure rate | Killed |
|---|---|---|---:|---:|---|
| M1 remove Actor binding | F2 | unauthorized effect | 1.0 | 0.0 | yes |
| M2 remove CAS | F4 | stale write accepted | 1.0 | 0.0 | yes |
| M3 remove fence | F7 | unauthorized effect | 1.0 | 0.0 | yes |
| M4 remove idempotency | F5 | duplicate/extra effect | 1.0 | 0.0 | yes |
| M5 remove hash-chain verification | F9 | audit incorrect | 1.0 | 0.0 | yes |

## Interpretation

This is useful falsification evidence for the **reference model**: each explicitly removed control causes the corresponding directed fault family to fail while the full reference model does not fail on that metric.

It does **not** establish that equivalent mutations have been killed in the deployed PostgreSQL/Supabase implementation. It also does not establish framework superiority or distributed-systems correctness under arbitrary faults.

## E4 remaining work

- [ ] isolated/runtime-bound mutation or equivalent negative-control tests for authorization predicates;
- [ ] isolated/runtime-bound negative control for fencing enforcement;
- [ ] hash-chain verification mutation/tamper test beyond table mutation blocking;
- [ ] clean crash/restart/restore before new write capability;
- [ ] compound runtime-bound fault schedules;
- [ ] false-deny / valid-path cost quantification;
- [ ] preserve any surviving mutation as a failure requiring repair rather than changing the claim after the fact.

E4 remains **PARTIAL**, not COMPLETE.
