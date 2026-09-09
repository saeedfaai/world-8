# World 8 Objective Contract — Implementation-Specific Binding Inventory v0.1

Status: **REVIEW EVIDENCE / PRE-SCHEMA / NON-CANONICAL / FREEZE BLOCKERS EXPLICIT**

World 8 canonical architecture base: `8022a60d06d914d25cc969f6850ed44440534c01`
World 9 basis: R0.1 requirement to inspect implementation-specific Entity, Objective, grant, effect, evidence and fencing surfaces before contract freeze.

## Purpose

This inventory records the exact currently observed World 8 implementation surfaces relevant to the Objective Contract freeze candidate. It is not a schema proposal and does not promote any Development surface into Canonical Spine truth.

The key rule is: **absence is recorded as absence**. A concept documented in architecture is not treated as a live runtime binding unless an implementation-specific surface was actually observed.

## 1. Canonical truth boundary

Observed canonical repository: `saeedfaai/world-8`, `main@8022a60d06d914d25cc969f6850ed44440534c01`.

Frozen architecture baseline states that Entity, Binding, external effects and Canonical Spine are normative concepts, while active objectives/work/claims/leases/changes are WORK/Development state. The canonical-boundary ADR states that Git is canonical for architecture/code history, DCP is Development coordination/governance projection/cache, runtime is live deployed state, and Drive is recovery/reporting only.

Disposition: **BOUND FOR ARCHITECTURE TRUTH; DOES NOT BY ITSELF CREATE RUNTIME OBJECTIVE INSTANCE TRUTH.**

## 2. Entity surface

Architecture-level Entity semantics are present in the frozen World 8 baseline (`Entity != Skill`; Entity/Role/Society consumes Skill through versioned Binding).

Live `public` runtime inspection found no table whose name represents a canonical World 8 Entity registry. The only live table containing `entity` in its name was `world8_access_identity_bindings`, whose columns bind an actor/channel/subject fingerprint and assurance evidence. That is an access/identity proof binding, not sufficient evidence of a canonical Entity object.

Disposition: **UNRESOLVED IMPLEMENTATION BINDING / FREEZE BLOCKER.**

The Objective Contract MUST NOT invent an `entity_id` foreign-key target until the canonical Entity runtime binding is identified or separately governed into existence.

## 3. Objective surface

Observed live Development surface: `public.world8_dev_objectives`.

Observed fields:

- `objective_id`, `world_id`, `title`, `goal`, `success_criteria`, `owner_scope`, `architecture_ref`, `state`, `created_by`, `metadata`, timestamps.
- state constraint permits `DRAFT`, `ACTIVE`, `BLOCKED`, `COMPLETED`, `CANCELLED`.
- owner scope constraint permits `WORLD`, `SHARED_CORE`, `COMPANY`, `TRADING`, `INFRASTRUCTURE`.

Observed functions include:

- `world8_dev_create_objective_v1`
- `world8_dev_bind_work_to_objective_v1`
- `world8_dev_objective_status_v1`

This surface does not contain immutable objective version identity, canonical content digest, hard-constraint set, authority-ceiling ref, risk/observation/promotion policy refs, protected Metric Contract refs, promotion decision ref, canonical lineage, or canonical ObjectiveBinding.

Disposition: **DEVELOPMENT/DCP ONLY — FORBIDDEN AS CANONICAL OBJECTIVE SOURCE.**

## 4. Authority / grant surfaces

Observed governed authority-rule surface: `public.world8_authority_rules`, including subject/action/resource/scope/decision/conditions, validity interval, evidence refs, provenance, creator, and content hash.

Observed authority lifecycle functions include request/challenge/approve/issue/revoke flows such as:

- `world8_authority_rule_request_v1`
- `world8_authority_rule_approve_v1`
- `world8_authority_rule_issue_v1`
- `world8_authority_rule_revoke_closed_work_v1`

Observed Development access-grant receipt surface: `public.world8_dev_access_grant_receipts`, with actor/work/workspace/resource/access-mode/scope/expiry/evidence/content-hash fields and issue/revoke functions.

Disposition: **AUTHORITY PATTERN EXISTS; OBJECTIVE AUTHORITY-CEILING BINDING NOT YET DEFINED.**

The Objective Contract may reference a future exact authority-ceiling contract/ref, but MUST NOT equate Development access grants with canonical Objective authority.

## 5. Effect surfaces

Observed external-effect authorization and execution surfaces:

- `w2_external_effect_authorizations`
- `effect_attempts`
- `effect_receipts`

Observed functions include:

- `world8_authorize_task_external_effect`
- `world8_plan_task_external_effect`
- `world8_begin_external_effect_attempt`
- `world8_finish_external_effect_attempt`
- `world8_external_effect_readiness`

`effect_attempts` carries `fencing_token` and lease expiry. `world8_plan_task_external_effect` accepts both `expected_head_hash` and `fencing_token`.

Disposition: **EFFECT-TIME FENCING PATTERN OBSERVED; OBJECTIVE-BINDING CHECK HOOK REMAINS UNBOUND.**

A later implementation must verify the effective canonical ObjectiveBinding together with authority/policy at the effect/commit boundary; no existing effect function is claimed to perform that Objective check today.

## 6. Evidence / promotion surfaces

Observed promotion/evidence surfaces are currently skill-oriented:

- `skill_promotion_evaluations`
- `skill_promotion_gate_evidence`
- `skill_promotion_requests`
- related challenge/readiness/finalization functions.

These carry evaluator identity, evidence hashes/snapshots, artifact hash, request scope head/version, authority epoch, expiry and consumed-at/request fields.

Disposition: **INDEPENDENT EVALUATION/PROMOTION PATTERN EXISTS; OBJECTIVE-SPECIFIC EVALUATOR/PROMOTION BINDING DOES NOT YET EXIST.**

The Objective Contract MUST reuse the World 8 separation-of-duties pattern but must not silently reuse a Skill-specific promotion record as an Objective admission decision.

## 7. Fencing / canonical-write patterns

Observed fencing/concurrency primitives include:

- `governance_authority_state.authority_epoch`
- promotion requests carrying `request_scope_head_hash`, `request_scope_version`, and `authority_epoch`
- effect planning with `expected_head_hash` and `fencing_token`
- effect attempts carrying `fencing_token` and lease expiry.

Disposition: **PATTERN AVAILABLE / OBJECTIVE AGGREGATE WRITER NOT IMPLEMENTED.**

A future Objective writer must define its own exact expected-head/CAS aggregate, fencing basis, idempotency key contract and stale-write behavior rather than assuming an unrelated effect or skill token is interchangeable.

## 8. Binding contract artifact

Observed frozen World 8 architecture contract `architecture/contracts/binding.yaml` identifies `binding-contract-v1` as FROZEN, but the file itself is a compact identity/version/hash declaration and does not specify the runtime shape needed for World 9 `ObjectiveBinding`.

Disposition: **NORMATIVE BINDING CONCEPT PRESENT; OBJECTIVE-SPECIFIC RUNTIME BINDING STILL REQUIRED.**

## 9. Freeze blockers from this inventory

The following are explicit blockers to `PASS_FOR_FREEZE` unless independently resolved or accepted through a governed amendment with exact bindings:

1. **ENTITY_RUNTIME_BINDING_UNRESOLVED** — no canonical live Entity registry/surface was identified in the inspected runtime.
2. **OBJECTIVE_CANONICAL_SURFACE_NOT_IMPLEMENTED** — only `world8_dev_objectives` is present and it is Development/DCP state.
3. **OBJECTIVE_PROMOTION_BINDING_UNRESOLVED** — promotion/evaluation machinery observed is Skill-specific, not Objective-specific.
4. **OBJECTIVE_EFFECT_CHECK_HOOK_UNBOUND** — effect-time fencing exists, but no current hook is claimed to verify canonical ObjectiveBinding.
5. **OBJECTIVE_WRITER_CAS_FENCING_UNBOUND** — the required Objective aggregate writer and its exact CAS/fencing/idempotency contract do not yet exist.

These blockers do **not** authorize schema work. They define what a reviewer must either resolve before freeze or return as `BLOCKED`/`FAIL`.

## 10. Safe next sequence

1. Independent reviewer validates this inventory against the exact World 8 base and live runtime observations.
2. Resolve the canonical Entity implementation binding first, because Objective ownership and ObjectiveBinding depend on it.
3. Only if the freeze contract becomes complete and receives `PASS_FOR_FREEZE`, create a separate Development/Mason schema/writer implementation candidate.
4. Do not merge a schema, migration, canonical writer or production activation through this pre-schema PR.

## Non-claims

This inventory does not claim that the live runtime implements the World 8 Objective Contract, that `world8_dev_objectives` is canonical, that a canonical Entity table exists, that Skill promotion is valid Objective promotion, or that any current effect path verifies ObjectiveBinding.