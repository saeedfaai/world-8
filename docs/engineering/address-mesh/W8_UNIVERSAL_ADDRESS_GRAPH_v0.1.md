# World 8 Universal Address Graph / Addressable Engineering Mesh v0.1

Status: DESIGN FREEZE CANDIDATE / PARTIAL CODE DRAFTED / NOT DEPLOYED

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
