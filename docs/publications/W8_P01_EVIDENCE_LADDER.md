# W8-P01 — Evidence Ladder

Date: 2026-08-27
Paper: W8-P01
Status: ACTIVE / MANUSCRIPT BLOCKED UNTIL E3 CANONICAL MERGE + E4

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

Status: **PASS ON EVIDENCE BRANCH / CANONICAL MERGE PENDING**

Binding receipt:
`experiments/flagship_governance_v0_1/E3_CANONICAL_RUNTIME_BINDING.md`

Runtime behavioral receipt:
`experiments/flagship_governance_v0_1/E3_RUNTIME_BEHAVIORAL_PROBES.md`

### Bound in current source + deployed runtime
- actor/authority verifier;
- actor/execution/workspace binding;
- stale canonical workspace-base protection;
- append-only chained development journal/checkpoints;
- crash-safe Scribe closure/resume;
- Lease v2/v3 wrappers and fail-closed admission/authorization dependency.

### Historical dependency/source lineage recovered on W8-P01 branch
Recovered from `supabase_migrations.schema_migrations.statements`, byte-for-byte:
- DCP/Lease v1 foundation — SHA256 `634d057945e8d7de6b1bdf6712f18b11109d2682760bbdd30fcda117ba93c52d`
- Sequencer lease maintenance — SHA256 `13b418f2f475bf423592224d44a45739cacc664cd4981263ffe40495f309b99d`
- W2 external-effect governance — SHA256 `bb3a9e65f06d374625ef7378e771ec284993f31278615d519095d5602508d92b`
- W2 hosted overlay — SHA256 `1f0a0789be184d5043d43e34f31a68c4d6042a0152e8e80ff59803994700e81b`

Integrity run after guarded EOF repair:
- https://github.com/saeedfaai/world-8/actions/runs/33107476738
- all four authoritative `sha256sum -c` checks PASS.

### Runtime behavioral probes — PASS / NON-PERSISTENT
- default DENY with no matching authority rule;
- explicit DENY precedence over ALLOW;
- stale fencing token rejected (`30` current vs `29` supplied, SQLSTATE `40001`);
- effect receipt no-op UPDATE rejected;
- development journal no-op UPDATE rejected;
- Work↔Actor mismatch rejected before workspace write;
- read-only `world8_dev_resume_capsule_v2` returned real blocked state rather than fabricated readiness.

No external provider effect or live trade was executed. Transactional probes were rolled back.

### E3 remaining gate
- [ ] final validator suite green on reconciled branch
- [ ] governed PR merges recovered source into canonical `main`
- [ ] post-merge canonical source/integrity verification

Until then, the correct wording is **runtime-backed and source-reconciled on the evidence branch**, not yet **fully canonicalized in main**.

## E4 — Mutation / compound failure / recovery

Status: OPEN

Required:
- mutation gate for actor binding, authorization, fencing, evidence verification;
- clean crash/restart before new write capability;
- compound-fault schedules on runtime-bound mechanisms;
- false-deny / valid-path cost reporting;
- preserve negative/neutral results rather than optimizing claims after the fact.

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

The W8-P01 manuscript becomes eligible for full drafting only after E3 is canonicalized and E4 passes mutation/recovery gates. Introduction/related-work notes may be collected earlier, but no claim should outrun this ladder.
