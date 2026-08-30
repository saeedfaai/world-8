# World 8 Entity Identity — Implementation Inventory v0.1

Status: **REVIEW EVIDENCE / PRE-SCHEMA / NON-CANONICAL**

World 8 canonical architecture base: `8022a60d06d914d25cc969f6850ed44440534c01`

World 9 dependency: R0.1 requires every Principal to be backed by a World 8 Entity and explicitly states that the implementation-specific Entity persistence surface must be resolved before Principal/Objectives schema work.

## Purpose

This inventory answers one narrow question: **what live runtime surface currently carries canonical World 8 Entity identity?**

The answer from the inspected runtime is: **none identified**. This absence is recorded rather than papered over by aliasing an Actor, authenticated user, access identity, or existing Principal row into an Entity.

No DDL or production mutation was performed while producing this inventory.

## 1. Canonical architecture truth

The canonical World 8 repository is `saeedfaai/world-8` and the inspected architecture base is `main@8022a60d06d914d25cc969f6850ed44440534c01`.

The frozen baseline separates Git architecture/code truth, Development/DCP coordination state, live runtime state, and Drive read/recovery copies. It also treats Entity identity as a stable architecture concept independent of replaceable model/provider/session state.

World 9 R0.1 further fixes the relation `Principal ⊂ World8Entity` as a semantic requirement and forbids treating provider/model/session identity as canonical Principal identity.

## 2. Live public-schema inspection

Read-only catalog inspection found no public table named or shaped as a canonical World 8 Entity registry.

Tables relevant to nearby identity concepts were inspected:

### `public.world8_actor_registry`

Columns observed:

- `actor_id`
- `world_id`
- `actor_kind`
- `display_name`
- `home_scope`
- `status`
- `identity_version`
- `authority_ref`
- `metadata`
- timestamps

Observed actor kinds at the inspection point were `AI_MASON`, `HUMAN`, and `SERVICE`.

Disposition: **governance/execution Actor identity; DO NOT ALIAS AS ENTITY.**

Reason: Actor identity is used to attribute executions/governance work. Treating every Mason/Human/Service Actor as the canonical Entity object would collapse Actor and Entity semantics and would make transient/governance execution identities capable of satisfying Principal Entity backing merely by registry presence.

### `public.world8_owner_identities`

Columns observed:

- `identity_id`
- `auth_user_id`
- `principal_ref`
- `status`
- timestamps/revocation

Disposition: **authenticated owner/principal binding; DO NOT ALIAS AS ENTITY.**

Reason: it binds an authentication identity to a principal reference. It is not a canonical Entity record with Entity genesis, lifecycle, immutable identity versioning, or canonical Entity lineage.

### `public.world8_access_identity_bindings`

Columns observed:

- `binding_id`
- `world_id`
- `actor_ref`
- `channel_id`
- `subject_fingerprint`
- `assurance_class`
- `proof_policy`
- `status`
- verification/expiry/evidence/metadata timestamps

Disposition: **channel/access proof binding; DO NOT ALIAS AS ENTITY.**

Reason: connectivity/authentication proof is not canonical Entity identity. World 8 already freezes `Connectivity != Identity != Authority` as a core principle.

## 3. Entity-named runtime objects

Read-only function catalog inspection found no World 8 Entity lifecycle/admission writer function. The only `public` functions containing `entity` in their name at the inspection point were World 9 machine-identity ceremony/request functions, which are unrelated to canonical World 8 Entity lifecycle.

Disposition: **NO ACTIVE ENTITY WRITER/LIFECYCLE SURFACE IDENTIFIED.**

## 4. Existing World 9 Principal runtime is not a substitute

The live `public.world9_principal_contract_versions` table was inspected read-only. Its columns are centered on `principal_id`, contract version/body/digests, status, authorization and genesis refs. It has no `entity_id` column.

The observed current contract-body keys included Principal policy/authority/objective fields but no `entity_id` key.

Disposition: **existing pre-R0.1 World 9 Principal contract state does not satisfy the R0.1 requirement that an ACTIVE Principal be backed by an explicit World 8 Entity identity.**

This does not invalidate the historical runtime work; it means that historical Principal rows cannot be silently reclassified as the missing canonical Entity aggregate.

## 5. Binding decision candidate

Because no active canonical Entity persistence surface was identified, the safe pre-schema decision is:

- do not alias `world8_actor_registry`, `world8_owner_identities`, `world8_access_identity_bindings`, authentication subject IDs, provider/model/session IDs, or existing Principal IDs into `entity_id`;
- define a **dedicated canonical World 8 Entity aggregate** as the implementation target;
- keep PrincipalContract as a separate governed aggregate that references an already-existing canonical Entity identity/version/digest;
- require Entity admission/lifecycle to pass the existing World 8 Development → independent evaluation → Promotion Authority → Canonical Spine path;
- preserve Actor identity separately for proposer/evaluator/writer attribution.

The logical target is named `World8EntityRecord` in the accompanying freeze candidate. This is a logical contract name only; no database table or RPC name is frozen by this inventory.

## 6. Why this is not schema authorization

The absence of an Entity runtime surface is an implementation gap. It does **not** authorize creating a table immediately.

The required sequence is:

1. freeze/review the Entity identity contract;
2. only after governed freeze, create a separate schema/writer implementation candidate;
3. independently evaluate and promote that implementation through World 8;
4. then return to Objective Contract/Principal binding with an exact deployed Entity persistence/writer reference.

Until that deployment exists, the Objective Contract blocker is more precisely described as **ENTITY_CANONICAL_RUNTIME_DEPENDENCY_NOT_IMPLEMENTED**, not as permission to invent a foreign-key target.

## 7. Negative requirements

A future implementation is invalid if any of the following succeeds:

- `actor_id` is accepted as `entity_id` merely because the Actor exists;
- an authenticated user ID becomes Entity identity without governed Entity admission;
- an existing Principal row creates its own Entity implicitly;
- provider/model/session replacement changes `entity_id`;
- two different Genesis anchors reuse one `entity_id`;
- a tombstoned Entity is resurrected by editing the record in place;
- Entity history is reconstructed only from DCP/read-model state;
- proposer/evaluator/Principal self-promotes the Entity writer or identity change.

## 8. Current disposition

**BINDING DESIGN DECIDED / RUNTIME SURFACE NOT YET IMPLEMENTED / PRE-SCHEMA / INDEPENDENT REVIEW REQUIRED.**

This artifact resolves the ambiguity about *what existing thing should be treated as Entity*: none of the observed nearby identity surfaces qualify. It does not claim the runtime dependency is already implemented.