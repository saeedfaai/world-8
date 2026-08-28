-- World 8 Universal Address Graph / Addressable Engineering Mesh v0.1
-- STATUS: DRAFT ONLY / NOT A MIGRATION / NOT APPLIED / NOT EVIDENCED
-- Contract: architecture/contracts/world8-universal-address-graph-v0.1.yaml
--
-- Reuses existing truth:
--   world8_actor_registry
--   world8_dev_artifacts
--   world8_internal_messages
--   world8_attention_items
--   world8_diag_tags / world8_diag_tag_bindings
--   world8_dev_work_items / world8_dev_workspaces / world8_mason_assignments
--
-- This draft adds address/index/routing objects only. It MUST NOT create a second
-- message, actor, artifact, work, authority or diagnostic truth store.

create table if not exists public.world8_address_entities (
  entity_id text primary key,
  entity_kind text not null check (entity_kind in (
    'WORLD','SOCIETY','PROJECT','ARTIFACT','MODULE','FILE','SYMBOL','FUNCTION','CLASS','METHOD',
    'RPC','DB_FUNCTION','TABLE','TEST','SERVICE_ENTRYPOINT','ACTOR','ROLE','WORK','WORKSPACE',
    'ASSIGNMENT','PROVIDER','CHANNEL','DIAGNOSTIC_OBJECT','POLICY','CONTRACT'
  )),
  canonical_address text not null unique check (canonical_address like 'w8://%'),
  world_id text not null default 'world-001',
  society_id text null,
  project_id text null,
  artifact_id text null references public.world8_dev_artifacts(artifact_id) on delete restrict,
  authoritative_ref_kind text null,
  authoritative_ref text null,
  owner_ref text null,
  role_refs jsonb not null default '[]'::jsonb check (jsonb_typeof(role_refs)='array'),
  tags jsonb not null default '[]'::jsonb check (jsonb_typeof(tags)='array'),
  revision bigint not null default 1 check (revision > 0),
  status text not null default 'ACTIVE' check (status in ('ACTIVE','DEPRECATED','RETIRED')),
  content_hash text not null,
  created_at timestamptz not null default clock_timestamp(),
  updated_at timestamptz not null default clock_timestamp()
);

create index if not exists world8_address_entities_scope_idx
  on public.world8_address_entities(world_id,society_id,project_id,artifact_id,entity_kind,status);
create index if not exists world8_address_entities_address_prefix_idx
  on public.world8_address_entities(canonical_address text_pattern_ops);
create index if not exists world8_address_entities_tags_gin
  on public.world8_address_entities using gin(tags);
create index if not exists world8_address_entities_roles_gin
  on public.world8_address_entities using gin(role_refs);

-- Historical addresses are immutable aliases. Moving/renaming a semantic object creates
-- a new current canonical_address and preserves the old address here.
create table if not exists public.world8_address_aliases (
  alias_address text primary key check (alias_address like 'w8://%'),
  entity_id text not null references public.world8_address_entities(entity_id) on delete restrict,
  alias_kind text not null check (alias_kind in ('PREVIOUS_ADDRESS','HUMAN_ALIAS','IMPORT_ALIAS')),
  source_ref text not null,
  created_at timestamptz not null default clock_timestamp()
);

create table if not exists public.world8_address_relations (
  relation_id text primary key,
  source_entity_id text not null references public.world8_address_entities(entity_id) on delete restrict,
  relation_type text not null check (relation_type in (
    'CONTAINS','DEPENDS_ON','CALLS','READS','WRITES','PUBLISHES_TO','SUBSCRIBES_TO',
    'IMPLEMENTS','TESTS','OWNS','AFFECTS'
  )),
  target_entity_id text not null references public.world8_address_entities(entity_id) on delete restrict,
  source_ref text not null,
  revision bigint not null default 1 check (revision > 0),
  content_hash text not null,
  created_at timestamptz not null default clock_timestamp(),
  check (source_entity_id <> target_entity_id or relation_type not in ('CONTAINS','DEPENDS_ON')),
  unique(source_entity_id,relation_type,target_entity_id,source_ref,revision)
);

create index if not exists world8_address_relations_source_idx
  on public.world8_address_relations(source_entity_id,relation_type);
create index if not exists world8_address_relations_target_idx
  on public.world8_address_relations(target_entity_id,relation_type);

-- Subscription current projection. History is append-only in subscription_events.
create table if not exists public.world8_address_subscriptions (
  subscription_id text primary key,
  subscriber_ref text not null,
  selector jsonb not null check (jsonb_typeof(selector)='object'),
  event_kinds jsonb not null check (jsonb_typeof(event_kinds)='array'),
  minimum_priority text not null default 'NORMAL' check (minimum_priority in ('LOW','NORMAL','HIGH','CRITICAL')),
  delivery_mode text not null check (delivery_mode in ('INBOX','ATTENTION','GUARDIAN_CONTEXT','MASON_PREFLIGHT')),
  society_scope text null,
  revision bigint not null default 1 check (revision > 0),
  status text not null default 'ACTIVE' check (status in ('ACTIVE','SUSPENDED','RETIRED')),
  created_by text not null,
  created_at timestamptz not null default clock_timestamp(),
  updated_at timestamptz not null default clock_timestamp()
);

create index if not exists world8_address_subscriptions_subscriber_idx
  on public.world8_address_subscriptions(subscriber_ref,status);
create index if not exists world8_address_subscriptions_selector_gin
  on public.world8_address_subscriptions using gin(selector);

create table if not exists public.world8_address_subscription_events (
  event_id text primary key,
  subscription_id text not null references public.world8_address_subscriptions(subscription_id) on delete restrict,
  subscription_revision bigint not null check (subscription_revision > 0),
  event_type text not null check (event_type in ('CREATED','UPDATED','SUSPENDED','RETIRED')),
  selector_snapshot jsonb not null check (jsonb_typeof(selector_snapshot)='object'),
  event_kinds_snapshot jsonb not null check (jsonb_typeof(event_kinds_snapshot)='array'),
  actor_ref text not null,
  content_hash text not null,
  created_at timestamptz not null default clock_timestamp(),
  unique(subscription_id,subscription_revision,event_type)
);

-- Attach selector/entity targets to EXISTING world8_internal_messages. Message body/state
-- remains authoritative in world8_internal_messages; this table is routing metadata only.
create table if not exists public.world8_internal_message_targets (
  target_id text primary key,
  message_id text not null references public.world8_internal_messages(message_id) on delete cascade,
  target_type text not null check (target_type in ('ENTITY_ID','ADDRESS','TAG','ROLE','ARTIFACT_TREE','SELECTOR')),
  target_ref text null,
  selector jsonb null check (selector is null or jsonb_typeof(selector)='object'),
  created_by text not null,
  created_at timestamptz not null default clock_timestamp(),
  check (
    (target_type='SELECTOR' and selector is not null)
    or (target_type<>'SELECTOR' and target_ref is not null)
  )
);

create index if not exists world8_internal_message_targets_message_idx
  on public.world8_internal_message_targets(message_id,target_type);
create index if not exists world8_internal_message_targets_selector_gin
  on public.world8_internal_message_targets using gin(selector)
  where selector is not null;

-- Delivery receipts cite existing source truth. They are NOT a second event/message store.
create table if not exists public.world8_address_delivery_receipts (
  delivery_receipt_id text primary key,
  source_kind text not null,
  source_ref text not null,
  message_id text null references public.world8_internal_messages(message_id) on delete restrict,
  subscription_id text null references public.world8_address_subscriptions(subscription_id) on delete restrict,
  recipient_ref text not null,
  context_ref text null,
  delivery_mode text not null check (delivery_mode in ('INBOX','ATTENTION','GUARDIAN_CONTEXT','MASON_PREFLIGHT')),
  matched_entity_ids jsonb not null default '[]'::jsonb check (jsonb_typeof(matched_entity_ids)='array'),
  resolver_version text not null,
  selector_hash text null,
  content_hash text not null,
  created_at timestamptz not null default clock_timestamp(),
  unique(source_kind,source_ref,subscription_id,recipient_ref,context_ref,delivery_mode)
);

create index if not exists world8_address_delivery_recipient_idx
  on public.world8_address_delivery_receipts(recipient_ref,created_at desc);

-- Append-only historical/routing proof objects.
create or replace function public.world8_address_append_only_v01()
returns trigger language plpgsql security definer set search_path=public as $$
begin
  raise exception 'WORLD8_ADDRESS_HISTORY_APPEND_ONLY';
end $$;

drop trigger if exists world8_address_aliases_append_only_trg on public.world8_address_aliases;
create trigger world8_address_aliases_append_only_trg
before update or delete on public.world8_address_aliases
for each row execute function public.world8_address_append_only_v01();

drop trigger if exists world8_address_relations_append_only_trg on public.world8_address_relations;
create trigger world8_address_relations_append_only_trg
before update or delete on public.world8_address_relations
for each row execute function public.world8_address_append_only_v01();

drop trigger if exists world8_address_subscription_events_append_only_trg on public.world8_address_subscription_events;
create trigger world8_address_subscription_events_append_only_trg
before update or delete on public.world8_address_subscription_events
for each row execute function public.world8_address_append_only_v01();

drop trigger if exists world8_address_delivery_receipts_append_only_trg on public.world8_address_delivery_receipts;
create trigger world8_address_delivery_receipts_append_only_trg
before update or delete on public.world8_address_delivery_receipts
for each row execute function public.world8_address_append_only_v01();

comment on table public.world8_address_entities is
  'Thin universal address/index projection; authoritative Actor/Artifact/Work/Message/Diagnostic state remains in existing World 8 truth stores.';
comment on table public.world8_internal_message_targets is
  'Routing attachment for existing internal messages. Does not duplicate message truth or grant authority.';
comment on table public.world8_address_delivery_receipts is
  'Append-only evidence that an authoritative source message/event matched a selector/context and was surfaced.';

-- Privilege stance for future executable migration:
-- * no anon/authenticated direct INSERT/UPDATE/DELETE on address graph tables;
-- * narrow SECURITY DEFINER registration/subscription/target/delivery RPCs only;
-- * selector resolution must enforce society visibility/scope;
-- * messaging never grants CODE_WRITE, Promotion, HARD_REVOKE or external-effect authority.
