# World 8 Objective Contract — Contract Freeze Candidate v0.1

Status: **CANDIDATE / NOT FROZEN / NOT CANONICAL / PRE-SCHEMA**

World 8 base: `8022a60d06d914d25cc969f6850ed44440534c01`
World 9 basis: R0.1 Governed Principal Architecture, Objective / ObjectiveBinding requirements
Trigger evidence: World 9 PR #84 independent review found the active `world8_dev_objectives` surface to be Development control only; canonical ObjectiveBinding remains blocked.

## 1. Purpose and boundary

This artifact is the required **Contract Freeze Candidate before schema**. It defines the logical contract that a later implementation may realize. It does **not** create a database table, migration, RPC, writer, runtime activation path, authority grant, or production state.

World 8 already separates canonical architecture/code truth, Development coordination, runtime state and human-readable recovery/reporting. This candidate preserves that boundary. `world8_dev_objectives` remains a Development/Mason coordination object and MUST NOT be reinterpreted as canonical Objective truth.

The architecture definition of this contract is governed in Git. Runtime Objective Contract instances/versions, once an implementation is independently reviewed and promoted, belong to the World 8 **Canonical Spine**, not the Development Control Plane.

## 2. Object ownership

The canonical logical object is `ObjectiveContractVersion`.

Ownership rules:

- An `ObjectiveContractVersion` belongs to one World 8 `Entity` through `entity_id`.
- The version is an immutable canonical governance object once admitted to the Canonical Spine.
- A Principal may reference a version through a separate canonical `ObjectiveBinding`; the Principal does not own or mutate the version.
- Development proposals, Mason work items, evaluator notes and semantic assessments are not canonical Objective Contract versions.
- No provider/model/session/worker identity may become the owner merely by proposing or evaluating a version.

## 3. Logical contract contents

Every canonical `ObjectiveContractVersion` MUST carry, at minimum:

- `objective_id`
- `objective_version`
- `entity_id`
- `parent_objective_version_ref` (nullable only for root/constitutional genesis)
- `objective_text_or_spec_ref`
- `hard_constraints`
- `authority_ceiling_ref`
- `risk_policy_ref`
- `observation_policy_ref`
- `promotion_policy_ref`
- `protected_metric_contract_refs`
- `valid_time`
- `jurisdiction_or_applicability_refs` when applicable
- `evidence_pack_ref`
- `content_digest`
- `created_by_governance_actor_ref`
- `promotion_decision_ref`
- `created_at`

`content_digest` MUST cover the complete immutable semantic payload, including all policy and protected-metric references. A canonical version MUST NOT be admitted if any required reference is unresolved or ambiguous.

## 4. Authoritative writer

The sole logical authoritative writer is `CanonicalSpineObjectiveContractWriter` acting under an accepted Promotion Authority decision.

Rules:

- Mason/Development may propose only.
- Evaluator may judge only.
- Promotion Authority may authorize admission/supersession only.
- The Canonical Spine writer records the admitted version and canonical lineage/binding event.
- The effect executor, provider worker, Principal, Objective refiner, evaluator and proposer MUST NOT self-authorize the canonical write.
- The exact implementation identity (RPC/service role/function) is intentionally **UNBOUND** in this candidate and MUST be bound by a later implementation-specific freeze amendment before schema is promoted.

This candidate therefore names the authority role and separation of duties while refusing to invent an implementation writer that does not exist yet.

## 5. State machine

Canonical version content is immutable. Lifecycle changes are represented by canonical lineage/status events, not in-place mutation of the version payload.

Logical states for a version reference:

`ADMITTED -> ACTIVE -> SUPERSEDED`

Exceptional terminal states:

`ADMITTED|ACTIVE -> REVOKED`

A proposal before admission exists only in Development/Evidence and is **not** a state of the canonical object.

`ACTIVE` means eligible to be referenced by a canonical `ObjectiveBinding`, subject to all other governance and authority checks. It does not itself activate a Principal.

## 6. Forbidden transitions and invariants

The following MUST fail closed:

- Development `ACTIVE` -> canonical `ACTIVE` without independent evaluation + Promotion Authority.
- mutation of an admitted version's semantic payload or `content_digest`.
- binding to a missing, Development-only, ambiguous, revoked or non-canonical version.
- `SUPERSEDED -> ACTIVE` resurrection without creation/admission of a new version.
- `REVOKED -> ACTIVE` resurrection.
- semantic/LLM assessment -> canonical admission or binding activation by itself.
- structural refinement FAIL -> canonical child Objective activation.
- stale CAS/fencing token -> canonical write.
- self-evaluation/self-promotion when independence is required.
- deletion of canonical history needed to reconstruct active or historical bindings.
- changing hard constraints, authority ceiling, risk policy, observation policy, promotion policy or protected metrics without a new immutable version.

## 7. ObjectiveBinding

`ObjectiveBinding` is a separate canonical relation between a World 8 Entity/World 9 Principal and one exact immutable Objective Contract version.

A binding MUST contain at least:

- `binding_id`
- `entity_id`
- `principal_id` when World 9 applies
- `objective_id`
- `objective_version`
- `objective_content_digest`
- `effective_interval`
- `binding_status`
- `governance_decision_ref`
- `evidence_pack_ref`
- `canonical_commit_ref`

Binding activation/change is canonical. A Development objective row, WorkOrder, Task, semantic assessment or structural checker result cannot directly create or activate a binding.

## 8. Refinement admission

For a child Objective derived from a parent:

- `SAFE_REFINEMENT` requires deterministic structural PASS and still requires governance.
- `CONDITIONAL_REFINEMENT` requires structural PASS plus independent semantic/evidence evaluation and protected Metric Contracts.
- `UNKNOWN_REFINEMENT` is forbidden from activation.
- semantic assessment MUST NOT override structural FAIL or mint authority.
- admitted child content MUST point to the exact parent version and the structural checker artifact/version/evidence used.

Protected metrics used for optimization or guardrails MUST be immutable-by-contract reference and definition, including unit, population/scope, aggregation window, data sources, freshness, missing-data semantics, methodology, threshold/degradation rule, evaluation horizon and termination condition as applicable.

## 9. Evidence requirement

A canonical admission/binding decision requires an immutable evidence bundle containing at minimum:

- proposal/candidate digest;
- exact parent version/digest when applicable;
- deterministic structural proof and checker identity for refinements;
- Metric Contract refs/digests for protected metrics;
- evaluator `GovernanceActorBinding` and independent evaluation receipt when required;
- Promotion Authority decision actor/ref;
- policy versions used;
- expected canonical head / CAS-fencing basis;
- source refs sufficient for audit and replay;
- explicit evidence ceiling.

High-risk decisions MUST NOT rely solely on the requester/proposer as evidence producer.

## 10. Recovery and replay

Recovery MUST reconstruct Objective truth without consulting Development status as authority.

A compliant implementation MUST be able to reconstruct:

1. every admitted immutable Objective Contract version;
2. lineage (`parent`, `supersedes`, `revokes`) and canonical status events;
3. the active `ObjectiveBinding` for each Principal/Entity at a requested canonical point;
4. the evidence and governance decision that admitted/changed each version or binding;
5. protected Metric Contract refs and policy refs used by that version.

Replay MUST verify digests and canonical ordering. Missing/corrupt evidence, broken lineage, digest mismatch, stale fencing or ambiguous head MUST fail closed and block activation/change.

## 11. World 8 plane mapping

- **Canonical Spine:** admitted immutable Objective Contract versions, lineage/status events, canonical ObjectiveBinding changes.
- **Operational:** WorkOrders/execution coordination that consume an already-authorized binding; never authoritative Objective truth.
- **Observation:** protected-metric measurements, drift/degradation/breach signals; cannot mutate Objective truth directly.
- **Development / Mason:** proposals, work items, candidate refinements, implementation code; proposal-only.
- **Evidence / Governance:** evaluator receipts, EvidencePacks, Promotion Authority decisions, GovernanceActorBindings.

No sixth plane is introduced.

## 12. Enforcement points

A later implementation MUST name and test exact enforcement hooks for:

1. **Canonical version admission:** validates complete contract, digest, evidence, writer authority, expected head/CAS/fencing and immutable lineage.
2. **ObjectiveBinding create/change:** verifies target version is canonical/eligible and governance decision is valid/current.
3. **Principal activation:** refuses missing/non-canonical/Development-only ObjectiveBinding.
4. **Refinement promotion:** structural FAIL/UNKNOWN cannot reach admission; CONDITIONAL requires independent evidence and protected metrics.
5. **Effect/commit path:** effective ObjectiveBinding is read/verified together with Authority/WorkOrder/policy; Objective never creates authority.
6. **Recovery/replay:** digest/lineage/fencing verification before restoring active binding state.
7. **Observation/governance feedback:** degradation can trigger governance/remediation but cannot directly rewrite the Objective.

Exact commit-time and effect-time function names remain implementation-binding work after this candidate is independently reviewed/frozen.

## 13. Concurrency / consistency contract

Canonical writes MUST use compare-and-swap/fencing semantics against an expected canonical head/version. Concurrent admissions or binding changes for the same aggregate MUST serialize or one must fail stale. Idempotent replay with the same semantic payload/digest may return the prior receipt; same idempotency key with different payload MUST fail.

## 14. Relationship to current `world8_dev_objectives`

The current Development surface may be used to coordinate proposal work only. It lacks the canonical immutable version/digest and policy/evidence semantics required here. Its `ACTIVE` development state MUST NOT be mapped to canonical `ACTIVE` or to an active World 9 ObjectiveBinding.

## 15. Freeze exit criteria

This candidate may become a frozen architecture contract only after an independent reviewer verifies:

- all eight pre-schema requirements are explicit: ownership, authoritative writer, state machine, forbidden transitions, evidence, recovery, plane mapping, enforcement point;
- immutable/versioned semantics are internally consistent;
- Development and Canonical truth are not conflated;
- refinement/Metric Contract requirements match World 9 R0.1;
- concurrency/CAS/fencing and recovery obligations are testable;
- no schema or writer implementation is smuggled into the freeze step.

Only after freeze may a separate Development/Mason slice propose concrete schema/RPC/writer implementation and tests.

## 16. Explicit non-claims

This candidate does not claim:

- a canonical Objective Contract table exists;
- a canonical writer exists;
- ObjectiveBinding can be activated now;
- migration/DDL approval;
- E2/E3 runtime evidence;
- GitHub Actions PASS;
- production readiness.
