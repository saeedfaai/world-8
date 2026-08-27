# W8-P01 — Evidence Ladder

Date: 2026-08-27
Paper: W8-P01
Status: ACTIVE / MANUSCRIPT BLOCKED UNTIL E3+E4

## E0 — Architectural proposition

Status: PASS AS DESIGN / NOT EVIDENCE OF SUPERIORITY

Proposition: one governed kernel can separate persistent Actor identity, authority, canonical/effect boundaries, and evidence/recovery from provider/session identity and domain-specific Society semantics.

Sources:
- `architecture/WORLD8_ARCHITECTURE.yaml`
- `architecture/adr/ADR-0002-actor-identity.md`
- `START_HERE.md`

## E1 — Mechanism falsification / hardened baseline / ablation

Status: **PASS / REFERENCE-MODEL EVIDENCE**

Strong run:
- https://github.com/saeedfaai/world-8/actions/runs/33103617400
- 98,000 trials
- 14 directed/compound scenarios
- 7 systems/variants
- evidence artifact SHA256: `03d8542ea15b9ae3296d26b5ab52ad7e5e1b4bbf5974e77f7693ffaaebad3486`

Result ceiling:
- hardened baseline matched revoke, CAS/stale-write rejection, durable idempotency, missing-approval and single-winner semantics;
- differentiated mechanisms remaining in the reference model: persistent actor/authorization binding, fencing/lease enforcement, tamper-evident evidence verification;
- ablations recovered the targeted failures;
- valid-path reference cost: ~7 checks/9 evidence records vs hardened baseline ~6/8.

This level does NOT prove general superiority to agent frameworks.

## E2 — Cross-Society shared-kernel conformance

Status: **PASS / CROSS-DOMAIN REFERENCE CONFORMANCE**

Run:
- https://github.com/saeedfaai/world-8/actions/runs/33103973441
- Company Society: 1,000 trials
- Trading Society: 1,000 trials
- same kernel + same 8-invariant suite
- both conformance vectors all `1.0`
- vectors equal = true
- artifact SHA256: `f6a0c8a6d4c39daa67326dbcf9f4c34494836ca81d63964b493a989482ac91aa`
- result SHA256: `ac3b90efabd1e83c36e388c0bda61dfff5ba325c568a50ad579f74dd1f8f9704`

Company domain boundary:
`QUOTE_PROPOSAL != PURCHASE_APPROVAL != SUPPLIER_ORDER_EFFECT`

Trading domain boundary:
`FORECAST != TRADE_DECISION != SYNTHETIC_ORDER`

No market-performance metric and no live effect is used in E2.

## E3 — Canonical/runtime binding

Status: **PARTIAL PASS / SOURCE DRIFT OPEN**

Binding receipt:
`experiments/flagship_governance_v0_1/E3_CANONICAL_RUNTIME_BINDING.md`

Canonical + runtime schema-backed now:
- actor/authority verifier;
- actor/execution/workspace binding;
- stale canonical workspace base gate;
- append-only chained development journal/checkpoints;
- crash-safe Scribe closure/resume.

Runtime-deployed but source drift open:
- Development Lease v2/v3 lineage;
- sequencer fencing lineage;
- external-effect planner / immutable effect-receipt lineage.

E3 cannot be marked COMPLETE until source drift is reconciled or those mechanisms are removed from claims, and isolated behavioral SQL tests pass.

## E4 — Mutation / compound failure / recovery

Status: OPEN

Required:
- isolated behavioral SQL tests;
- mutation gate for actor binding, authorization, fencing, evidence integrity;
- crash/restart before new write capability;
- compound-fault schedules on runtime-bound mechanisms;
- false-deny / valid-path cost reporting.

## E5 — External framework comparison + manuscript

Status: OPEN

Required:
- fair externally recognizable orchestration baseline or clearly justified absence;
- related work verified;
- W8-P01 vs W8-P02 overlap audit PASS;
- exact evidence freeze;
- claim audit;
- journal formatting and cover letter;
- author approval.

## Publication rule

**Do not write Results first and search for evidence later.**

The W8-P01 manuscript becomes eligible for full drafting only when E3 is complete enough to reproduce the measured kernel claims and E4 passes mutation/recovery gates. Introduction/related-work notes may be collected earlier, but no claim should outrun this ladder.
