# W8-P01 — Evidence Ladder

Date: 2026-08-27
Paper: W8-P01
Status: ACTIVE / E3 CANONICALIZED / E4 STRONG REFERENCE PASS / MANUSCRIPT STILL BLOCKED BY E5

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

Status: **PASS / CANONICALIZED IN MAIN / BOUNDED RUNTIME BEHAVIOR**

Canonical merge:
- PR #32: https://github.com/saeedfaai/world-8/pull/32
- merge commit: `4aecb1fd1c64f43f7c4e08e528821a9acd0dfd0f`

Post-merge canonical gates:
- E3 Validation Gate: https://github.com/saeedfaai/world-8/actions/runs/33108124477 — PASS
- Authoritative Source Integrity: https://github.com/saeedfaai/world-8/actions/runs/33108124506 — PASS
- release-gate: https://github.com/saeedfaai/world-8/actions/runs/33108124500 — PASS
- validate-architecture: https://github.com/saeedfaai/world-8/actions/runs/33108124549 — PASS

Binding receipt:
`experiments/flagship_governance_v0_1/E3_CANONICAL_RUNTIME_BINDING.md`

Runtime behavioral receipt:
`experiments/flagship_governance_v0_1/E3_RUNTIME_BEHAVIORAL_RECEIPT.md`

### Canonicalized source lineage
Authoritative historical migrations were recovered from `supabase_migrations.schema_migrations.statements`, byte-for-byte, and are now present on canonical `main`:
- DCP/Lease v1 foundation — SHA256 `634d057945e8d7de6b1bdf6712f18b11109d2682760bbdd30fcda117ba93c52d`
- Sequencer lease maintenance — SHA256 `13b418f2f475bf423592224d44a45739cacc664cd4981263ffe40495f309b99d`
- W2 external-effect governance — SHA256 `bb3a9e65f06d374625ef7378e771ec284993f31278615d519095d5602508d92b`
- W2 hosted overlay — SHA256 `1f0a0789be184d5043d43e34f31a68c4d6042a0152e8e80ff59803994700e81b`

### Runtime behavioral probes — PASS / NON-PERSISTENT
- default DENY with no matching authority rule;
- explicit DENY precedence over ALLOW;
- stale fencing token rejected (`30` current vs `29` supplied, SQLSTATE `40001`);
- effect receipt UPDATE rejected by immutability guard;
- development journal UPDATE rejected by append-only guard;
- Work↔Actor mismatch rejected; probe receipt count unchanged after rollback;
- read-only resume-capsule reconstruction returned governed state and next-action evidence.

No external provider effect or live trade was executed.

### Limitation retained
`world8_mason_pool_bind_execution_v1` is source/runtime bound, but no ACTIVE execution existed at probe time, so assignment→execution mismatch remains schema-backed rather than behaviorally exercised.

### Failure discovered during E3
A nonexistent workspace request caused `world8_dev_admission_check_v2` to assemble a BLOCKED result and then fail at `world8_dev_admission_receipts_workspace_id_fkey` instead of returning a structured BLOCKED receipt.

This did not bypass authorization and left no persistent probe data, but it violates the intended structured fail-closed contract.

Fix work:
- branch `fix/w8-admission-missing-workspace-v0.2.1`
- migration `20260827193000_world8_admission_missing_workspace_receipt_fix_v021.sql`
- regression workflow `W8 Admission Missing Workspace Regression`

Do not mark this defect resolved until canonical merge, runtime migration application, and post-apply regression probe all pass.

## E4 — Mutation / compound failure / recovery

Status: **STRONG REFERENCE-MODEL PASS / RUNTIME-BOUNDED NEGATIVE CONTROLS PASS / PRODUCTION SECURITY NOT CLAIMED**

### Mutation gate
Run:
- https://github.com/saeedfaai/world-8/actions/runs/33107646035
- artifact digest: `sha256:69205d5139920271ad5d20a624855f54345b257d23bf8f6f520f4605901de8ee`
- `mutation_gate_v1.json` SHA256: `f107c531c58f3e99fe74b7f5f168e7870d8def7f88cf65845e3c4601c7bdf2ac`
- 5 mutations × 500 trials
- 5/5 killed
- mutation score = `1.0`
- full-system paired target-failure rate = `0.0`
- runtime DB mutated = false

Killed mutations:
- remove Actor binding;
- remove CAS;
- remove fencing;
- remove durable idempotency;
- remove hash-chain verification.

### Compound-fault gate
Run:
- https://github.com/saeedfaai/world-8/actions/runs/33108000278
- artifact id: `9661272442`
- artifact ZIP SHA256: `94817f523a294192b0805b90a456c55af6903ed76d01f101c49bf13f284bb161`
- result SHA256: `79341467909930b09460082f34402686e2fb7f0de6df46ed4bf30fb816d94e1d`
- 1,000 trials per compound case

Results:
- stolen authorization after identity swap: World 8 safe `1.0`; hardened session baseline failure exposed `1.0`;
- stale fence after restart/rotation: World 8 safe `1.0`; no-fence baseline failure exposed `1.0`;
- restart then receipt tamper: World 8 safe `1.0`; mutable-audit baseline failure exposed `1.0`;
- valid-path success: normal `1.0`, session swap `1.0`, restart/reconstruct `1.0`;
- false-deny rate on all three valid paths = `0.0`.

Evidence level remains `REFERENCE_MODEL_COMPOUND_FAULT`; these results are not a proof of production security or distributed linearizability.

### Runtime-bounded negative controls already exercised
- default-deny authorization;
- explicit DENY precedence;
- stale fencing token rejection;
- effect-receipt mutation rejection;
- journal mutation rejection;
- actor/work mismatch;
- resume-capsule derivation.

## E5 — External framework comparison + manuscript

Status: **NEXT**

Required:
- fair externally recognizable orchestration baseline;
- compare only scoped capabilities actually supported by both systems;
- related work verified from primary/official sources;
- W8-P01 vs W8-P02 overlap audit PASS;
- exact evidence freeze;
- claim audit;
- journal formatting and cover letter;
- author approval.

Candidate first comparison target: LangGraph durable execution/checkpointing, because it provides a recognizable durable agent orchestration baseline. Any comparison must distinguish built-in guarantees from application-defined policy and must not equate absent features with failure.

## Publication rule

**Do not write Results first and search for evidence later.**

The W8-P01 full manuscript becomes eligible only after E5 establishes a fair external comparison and the discovered admission failure is resolved or explicitly retained as an open limitation. No claim may outrun this ladder.
