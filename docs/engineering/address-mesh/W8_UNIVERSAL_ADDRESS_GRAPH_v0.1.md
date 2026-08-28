# World 8 Universal Address Graph / Addressable Engineering Mesh v0.1

Status: DESIGN FREEZE CANDIDATE / CODE DRAFTED / UNIT+INDEX CI PASS / DB NOT APPLIED / NOT DEPLOYED

## Why

World 8 already has IDs for Actors, Artifacts, Work, Workspaces, Assignments, Messages, Attention Items, Diagnostics and Code Shadow. The missing layer is stable addressability down to code/runtime symbols plus selector-based group addressing.

The Address Mesh does **not** replace those truth stores. It gives them a common query/address plane.

## Core model

Every addressable object has two identities:

1. **Immutable entity ID** — stable across moves/renames where semantic identity remains the same.
2. **Semantic address** — hierarchical and queryable; changes are versioned and old addresses become aliases.

Example:

```text
entity_id: W8-SYM-01JX83K7
address:   w8://society/company/project/taminyaran/artifact/pricing/module/supplier/symbol/update_price
```

Do not embed mutable role, file path, current Mason or line number as the sole permanent identity.

## Query dimensions

Address path answers **where**. Tags answer **what/why/risk/channel/runtime**. Bindings answer **who currently owns/works on it**.

Examples:

```text
society: COMPANY
project: TAMINYARAN
kind: FUNCTION
tag: DOMAIN:PRICING
tag: RISK:MONEY
tag: CHANNEL:TELEGRAM
runtime: SUPABASE
owner_role: MASON
```

This allows queries such as:

```text
all Company code
all Trading functions
all SQL objects
all Telegram-related objects
all Supabase + render-risk objects
all money-impacting Company functions
all objects affected by a provider quota incident
```

## Existing truth reused

- `world8_actor_registry`
- `world8_dev_artifacts`
- `world8_code_shadow_manifests`
- `world8_diag_tags`
- `world8_diag_tag_bindings`
- `world8_internal_messages`
- `world8_attention_items`
- `world8_dev_work_items`
- `world8_dev_workspaces`
- `world8_mason_assignments`

No second Message/Actor/Artifact/Diagnostic truth is allowed.

## New objects

### Address Entity

Thin address/index row referencing the authoritative object when one already exists.

Fields include:

- entity_id
- entity_kind
- canonical_address
- authoritative_ref_kind
- authoritative_ref
- world/society/project/artifact routing refs
- tags
- revision
- content_hash

### Address Alias

Append-only prior/alternate semantic address -> entity ID mapping.

### Address Relation

Typed graph edge:

- CONTAINS
- DEPENDS_ON
- CALLS
- READS
- WRITES
- PUBLISHES_TO
- SUBSCRIBES_TO
- IMPLEMENTS
- TESTS
- OWNS
- AFFECTS

### Subscription

A subscriber registers a Selector against event kinds and priority.

Example:

```json
{
  "subscriber_ref": "mason-worker-...",
  "selector": {
    "all": [
      {"society_id": "company"},
      {"tags_any": ["CHANNEL:TELEGRAM", "RUNTIME:SUPABASE"]}
    ]
  },
  "event_kinds": ["ERROR", "CHANGE", "QUOTA", "SECURITY"],
  "delivery_mode": "ATTENTION"
}
```

### Message Target

`world8_internal_messages` remains message truth. A Message Target attaches one or more entity/address/selector targets to that existing message.

No N-way duplicate message rows are created for broadcasts.

### Delivery Receipt

Append-only proof that a specific source message/event matched a subscription/context and was surfaced to a recipient/session.

## Selector semantics

Selectors are deterministic JSON expressions supporting:

- `entity_id`
- `entity_kind`
- `address_exact`
- `address_prefix`
- `address_glob`
- `tags_all`
- `tags_any`
- `tags_none`
- `world_id`
- `society_id`
- `project_id`
- `artifact_id`
- `owner_ref`
- `role_ref`
- boolean `all`, `any`, `not`

Unknown selector keys fail closed.

## Code symbol indexing

The first adapters are:

- Python AST: functions, async functions, classes, methods
- PostgreSQL/SQL: CREATE FUNCTION/PROCEDURE/TABLE/VIEW triggers and RPC symbols
- generic FILE object for unsupported languages

The indexer produces deterministic symbol descriptors but does not silently decide that two renamed symbols are the same semantic entity. Rename/move reconciliation is explicit through alias/rebind operations.

Historical SQL migration files are definition provenance, not DB-object identity. Repeated `CREATE OR REPLACE` statements for the same runtime DB object resolve to one stable Entity and one migration-independent canonical address, while every defining file retains an explicit file-to-object relation. A repeated entity ID with conflicting identity fields fails closed.

## Context delivery

When a Mason enters a Work/Artifact/Symbol, resolve a single `ADDRESS_CONTEXT_BUNDLE` containing:

- direct messages
- selector-addressed messages
- matching subscriptions
- diagnostics / incidents / signatures / playbooks
- required tests
- dependencies and dependents
- recent changes
- active Work/Assignment
- owner/role bindings

Guardian Pre-Action must use the same resolver.

Compatibility wrappers are drafted as `world8_mason_preflight_v2` and `world8_guardian_pre_action_v2`; existing v1 behavior remains the rollback baseline and Address Mesh cannot remove an existing blocker or grant authority.

## Impact graph

When event E affects entity X:

1. cite authoritative source event/incident/change;
2. resolve X and its known relations;
3. bound graph traversal by explicit relation types/depth;
4. match subscriptions/selectors;
5. produce delivery receipts/attention items.

No semantic impact is inferred from proximity alone.

## Messaging is not authority

Messages can notify, warn, request review or create Attention Items. They cannot grant code-write authority, Promotion, HARD_REVOKE or external-effect authorization.

Role fan-out is also non-authoritative. In v0.1, `role:MASON` resolves only through active Actor Registry rows with `actor_kind=AI_MASON`; unresolved roles deliver to nobody rather than guessing from names. Every actual recipient gets a distinct deterministic delivery receipt identity.

## Desired operator experience

Examples:

```text
message all society=COMPANY AND tag=RISK:MONEY
watch tag=CHANNEL:TELEGRAM for ERROR|CHANGE|SECURITY
show everything affected by W8-SYM-...
show unread context for current symbol
show all SQL functions related to TRADING
show all code, diagnostics, PDFs/docs, GitHub changes and Work touching SUPABASE
```

The Address Mesh is therefore the common internal "GPS + query language + routing fabric" for World 8.

## Executable code/index evidence — 2026-08-28

GitHub Actions workflow `W8 Address Mesh v0.1`, run `33167001149`, job `98834689338`:

- unit tests: **30 / 30 PASS**;
- whole-repository Address Manifest build: **PASS**;
- unique address entities: **938**;
- explicit provenance/containment relations: **659**;
- duplicate-entity validation: **PASS**.

The green manifest includes the repeated-SQL-definition regression: multiple migration definitions of one DB object collapse to one Entity without deleting definition provenance. Distinct Python module symbols remain distinct.

This is code/index evidence only. SQL runtime behavior is not yet evidenced.

## Governed runtime status

Current Work: `work-f50ecf53e1dbc58d69889b601973`  
Workspace: `workspace-ecad938a154397fffbed2a54d96388bc`  
Branch: `w8-address-mesh-v0.1`

Current CODE_WRITE Admission is blocked with `NO_MATCHING_AUTHORITY_RULE`.

A narrowly scoped Human Root request exists:

`authreq-addressmesh-f50e-20260828-01`

Human Root Attention item:

`attn-7cc42f399e484e8772926e31cf8c9c`

The challenge token is intentionally not stored in documentation/messages.

Until governed approval + Developer Lease:

- Address Mesh SQL remains in `supabase/drafts`;
- no Address Mesh DDL is applied to Production;
- the 938-entity manifest is not imported into Production;
- default subscriptions are not activated;
- Mason Preflight v2 / Guardian Pre-Action v2 runtime behavior is not claimed.

## Next safe action

After Human Root CODE_WRITE approval:

1. re-run Admission v2;
2. acquire Developer Lease;
3. review/compose the SQL drafts into an executable migration;
4. execute `tests/address_mesh/address_mesh_db_regression_v01.sql` on an authorized disposable/dev database;
5. import the generated manifest into the thin Address index;
6. test selector fan-out and idempotent Attention delivery;
7. test Mason Preflight v2 and Guardian Pre-Action v2 with real Address Context;
8. only then consider Production deployment/promotion.
