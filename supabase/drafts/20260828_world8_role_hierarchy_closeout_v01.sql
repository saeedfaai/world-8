-- NON-CANONICAL LOCAL DRAFT / NOT APPLIED / NOT DEPLOYED
-- World 8 closeout: TOP_GUARDIAN -> GUARDIAN -> MASTER_MASON -> MASON
-- Label != Message. Neither Label nor Message grants authority.

create table public.world8_role_bindings (
  binding_id text primary key,
  world_id text not null default 'world-001',
  actor_id text not null references public.world8_actor_registry(actor_id) on delete restrict,
  role_kind text not null check (role_kind in ('TOP_GUARDIAN','GUARDIAN','MASTER_MASON','MASON')),
  scope_ref text not null check (length(trim(scope_ref)) > 0),
  parent_binding_id text null references public.world8_role_bindings(binding_id) on delete restrict,
  status text not null default 'ACTIVE' check (status in ('ACTIVE','SUSPENDED','RETIRED')),
  revision bigint not null default 1 check (revision > 0),
  authority_effect text not null default 'NONE' check (authority_effect='NONE'),
  created_by text not null,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default clock_timestamp(),
  updated_at timestamptz not null default clock_timestamp(),
  check ((role_kind='TOP_GUARDIAN' and parent_binding_id is null and scope_ref='WORLD') or role_kind<>'TOP_GUARDIAN')
);

create unique index world8_role_one_active_top_guardian_idx
  on public.world8_role_bindings(world_id)
  where role_kind='TOP_GUARDIAN' and status='ACTIVE';
create index world8_role_bindings_parent_idx
  on public.world8_role_bindings(parent_binding_id,status);
create index world8_role_bindings_actor_idx
  on public.world8_role_bindings(actor_id,status,role_kind,scope_ref);

create table public.world8_role_binding_events (
  event_id text primary key,
  binding_id text not null references public.world8_role_bindings(binding_id) on delete restrict,
  binding_revision bigint not null check (binding_revision > 0),
  event_kind text not null check (event_kind in ('CREATED','SUSPENDED','RESUMED','RETIRED','PARENT_REBOUND')),
  actor_ref text not null,
  snapshot jsonb not null check (jsonb_typeof(snapshot)='object'),
  source_ref text not null,
  content_hash text not null,
  created_at timestamptz not null default clock_timestamp(),
  unique(binding_id,binding_revision,event_kind)
);

create table public.world8_role_sessions (
  role_session_id text primary key,
  world_id text not null default 'world-001',
  actor_id text not null references public.world8_actor_registry(actor_id) on delete restrict,
  current_binding_id text not null references public.world8_role_bindings(binding_id) on delete restrict,
  current_role_kind text not null check (current_role_kind in ('TOP_GUARDIAN','GUARDIAN','MASTER_MASON','MASON')),
  scope_ref text not null,
  descent_seq bigint not null default 0 check (descent_seq >= 0),
  state text not null default 'ACTIVE' check (state in ('ACTIVE','CLOSED','EXPIRED')),
  authority_effect text not null default 'NONE' check (authority_effect='NONE'),
  created_at timestamptz not null default clock_timestamp(),
  updated_at timestamptz not null default clock_timestamp()
);

create table public.world8_role_session_events (
  event_id text primary key,
  role_session_id text not null references public.world8_role_sessions(role_session_id) on delete restrict,
  descent_seq bigint not null check (descent_seq >= 0),
  event_kind text not null check (event_kind in ('STARTED','DESCENDED','CLOSED','EXPIRED')),
  from_binding_id text null,
  to_binding_id text not null,
  actor_ref text not null,
  source_ref text not null,
  created_at timestamptz not null default clock_timestamp(),
  unique(role_session_id,descent_seq,event_kind)
);

-- Normalized Label projection for Address Entities. The authoritative code/function identity
-- remains world8_address_entities. Label history is append-only below.
create table public.world8_address_labels (
  entity_id text not null references public.world8_address_entities(entity_id) on delete restrict,
  label_key text not null,
  status text not null default 'ACTIVE' check (status in ('ACTIVE','DETACHED')),
  revision bigint not null default 1 check (revision > 0),
  last_event_id text not null,
  updated_at timestamptz not null default clock_timestamp(),
  primary key(entity_id,label_key)
);

create index world8_address_labels_key_idx
  on public.world8_address_labels(label_key,status,entity_id);

create table public.world8_address_label_events (
  event_id text primary key,
  entity_id text not null references public.world8_address_entities(entity_id) on delete restrict,
  label_key text not null,
  event_kind text not null check (event_kind in ('ATTACH','DETACH')),
  entity_label_revision bigint not null check (entity_label_revision > 0),
  actor_binding_id text not null references public.world8_role_bindings(binding_id) on delete restrict,
  source_ref text not null,
  authority_effect text not null default 'NONE' check (authority_effect='NONE'),
  created_at timestamptz not null default clock_timestamp(),
  unique(entity_id,label_key,entity_label_revision)
);

-- One-to-one hierarchy metadata for EXISTING world8_internal_messages.
create table public.world8_internal_message_hierarchy_context (
  message_id text primary key references public.world8_internal_messages(message_id) on delete cascade,
  sender_binding_id text null references public.world8_role_bindings(binding_id) on delete restrict,
  direction_class text not null check (direction_class in ('DOWNWARD','UPWARD','LATERAL','ROOT_EXTERNAL','UNSCOPED')),
  message_class text not null check (message_class in (
    'DIRECTIVE','REPORT','ESCALATION','BLOCKER','ADVISORY','HANDOFF','REVIEW_REQUEST','STATUS','POLICY_NOTICE'
  )),
  parent_directive_message_id text null references public.world8_internal_messages(message_id) on delete restrict,
  work_ref text null,
  authority_effect text not null default 'NONE' check (authority_effect='NONE'),
  created_at timestamptz not null default clock_timestamp()
);

-- Role/Actor recipient routing metadata. Message body/state remains in world8_internal_messages.
create table public.world8_internal_message_role_targets (
  target_id text primary key,
  message_id text not null references public.world8_internal_messages(message_id) on delete cascade,
  target_type text not null check (target_type in ('ACTOR','ROLE_BINDING','ROLE_KIND','SUBTREE','SUPERVISOR')),
  target_ref text not null,
  scope_ref text null,
  created_by text not null,
  created_at timestamptz not null default clock_timestamp()
);

-- PostgreSQL does not permit expression terms directly in table UNIQUE constraints on all
-- supported versions; enforce the null-safe tuple with an index instead.
drop index if exists world8_internal_message_role_targets_natural_idx;
create unique index world8_internal_message_role_targets_natural_idx
  on public.world8_internal_message_role_targets(message_id,target_type,target_ref,coalesce(scope_ref,''));

-- Auto-report receipts do not create a second report truth. Each receipt cites the existing
-- message/journal/checkpoint refs that produced an upward report.
create table public.world8_role_report_receipts (
  report_receipt_id text primary key,
  reporter_binding_id text not null references public.world8_role_bindings(binding_id) on delete restrict,
  supervisor_binding_id text not null references public.world8_role_bindings(binding_id) on delete restrict,
  report_message_id text not null references public.world8_internal_messages(message_id) on delete restrict,
  source_refs jsonb not null check (jsonb_typeof(source_refs)='array'),
  summarizer_ref text not null,
  content_hash text not null,
  authority_effect text not null default 'NONE' check (authority_effect='NONE'),
  created_at timestamptz not null default clock_timestamp(),
  unique(reporter_binding_id,supervisor_binding_id,report_message_id)
);

create or replace function public.world8_role_history_append_only_v01()
returns trigger language plpgsql security definer set search_path=public as $$
begin
  raise exception 'WORLD8_ROLE_HISTORY_APPEND_ONLY';
end $$;

create trigger world8_role_binding_events_append_only_trg
before update or delete on public.world8_role_binding_events
for each row execute function public.world8_role_history_append_only_v01();
create trigger world8_role_session_events_append_only_trg
before update or delete on public.world8_role_session_events
for each row execute function public.world8_role_history_append_only_v01();
create trigger world8_address_label_events_append_only_trg
before update or delete on public.world8_address_label_events
for each row execute function public.world8_role_history_append_only_v01();
create trigger world8_role_report_receipts_append_only_trg
before update or delete on public.world8_role_report_receipts
for each row execute function public.world8_role_history_append_only_v01();

-- Eligibility and exact parent-level validator, called by narrow mutation RPCs.
create or replace function public.world8_role_binding_validate_v1(
  p_actor_id text,
  p_role_kind text,
  p_scope_ref text,
  p_parent_binding_id text
) returns jsonb
language plpgsql stable security definer set search_path=public as $$
declare
  v_actor_kind text;
  v_parent public.world8_role_bindings%rowtype;
begin
  select actor_kind into v_actor_kind
  from public.world8_actor_registry
  where actor_id=p_actor_id and status='ACTIVE';
  if v_actor_kind is null then raise exception 'ROLE_ACTOR_NOT_ACTIVE'; end if;

  if v_actor_kind='AI_MASON' and p_role_kind not in ('MASTER_MASON','MASON') then
    raise exception 'ACTOR_KIND_ROLE_NOT_ELIGIBLE';
  elsif v_actor_kind='AI_ARCHITECT' and p_role_kind in ('TOP_GUARDIAN','GUARDIAN','MASTER_MASON','MASON') then
    null;
  elsif v_actor_kind not in ('AI_MASON','AI_ARCHITECT') then
    raise exception 'ACTOR_KIND_ROLE_NOT_ELIGIBLE';
  end if;

  if p_role_kind='TOP_GUARDIAN' then
    if p_scope_ref<>'WORLD' or p_parent_binding_id is not null then
      raise exception 'TOP_GUARDIAN_PARENT_OR_SCOPE_INVALID';
    end if;
    return jsonb_build_object('gate_state','PASS','role_kind',p_role_kind,'authority_effect','NONE');
  end if;

  if p_parent_binding_id is null then raise exception 'NON_TOP_ROLE_REQUIRES_PARENT'; end if;
  select * into v_parent from public.world8_role_bindings
  where binding_id=p_parent_binding_id and status='ACTIVE';
  if not found then raise exception 'ROLE_PARENT_NOT_ACTIVE'; end if;

  if (p_role_kind='GUARDIAN' and v_parent.role_kind<>'TOP_GUARDIAN')
     or (p_role_kind='MASTER_MASON' and v_parent.role_kind<>'GUARDIAN')
     or (p_role_kind='MASON' and v_parent.role_kind<>'MASTER_MASON') then
    raise exception 'ROLE_PARENT_LEVEL_INVALID';
  end if;

  if p_role_kind in ('MASTER_MASON','MASON')
     and v_parent.scope_ref not in ('WORLD',p_scope_ref) then
    raise exception 'ROLE_PARENT_SCOPE_MISMATCH';
  end if;

  return jsonb_build_object('gate_state','PASS','role_kind',p_role_kind,'parent_binding_id',p_parent_binding_id,'authority_effect','NONE');
end $$;

-- Solo Role Descent: exact one-level drop only; no privilege inheritance column exists.
create or replace function public.world8_role_descend_check_v1(
  p_current_role text,
  p_target_role text
) returns boolean
language sql immutable as $$
  select (p_current_role='TOP_GUARDIAN' and p_target_role='GUARDIAN')
      or (p_current_role='GUARDIAN' and p_target_role='MASTER_MASON')
      or (p_current_role='MASTER_MASON' and p_target_role='MASON')
$$;

-- Read helper for immediate supervisor.
create or replace function public.world8_role_supervisor_v1(p_binding_id text)
returns jsonb language sql stable security definer set search_path=public as $$
  select case when child.role_kind='TOP_GUARDIAN' then
      jsonb_build_object('schema','WORLD8_ROLE_SUPERVISOR/1.0','binding_id',child.binding_id,'supervisor',null)
    else jsonb_build_object(
      'schema','WORLD8_ROLE_SUPERVISOR/1.0',
      'binding_id',child.binding_id,
      'supervisor',jsonb_build_object('binding_id',parent.binding_id,'actor_id',parent.actor_id,'role_kind',parent.role_kind,'scope_ref',parent.scope_ref)
    ) end
  from public.world8_role_bindings child
  left join public.world8_role_bindings parent on parent.binding_id=child.parent_binding_id
  where child.binding_id=p_binding_id and child.status='ACTIVE'
$$;

-- Read helper for subtree recipient resolution. This returns role bindings/actors; caller may
-- put resolved Actor IDs in existing world8_internal_messages.recipient_refs.
create or replace function public.world8_role_subtree_v1(p_root_binding_id text, p_limit integer default 1000)
returns jsonb language sql stable security definer set search_path=public as $$
  with recursive tree as (
    select binding_id,actor_id,role_kind,scope_ref,parent_binding_id,0 as depth
    from public.world8_role_bindings
    where binding_id=p_root_binding_id and status='ACTIVE'
    union all
    select c.binding_id,c.actor_id,c.role_kind,c.scope_ref,c.parent_binding_id,t.depth+1
    from public.world8_role_bindings c join tree t on c.parent_binding_id=t.binding_id
    where c.status='ACTIVE' and t.depth < 32
  )
  select jsonb_build_object(
    'schema','WORLD8_ROLE_SUBTREE/1.0',
    'root_binding_id',p_root_binding_id,
    'members',coalesce(jsonb_agg(jsonb_build_object('binding_id',binding_id,'actor_id',actor_id,'role_kind',role_kind,'scope_ref',scope_ref,'depth',depth) order by depth,binding_id),'[]'::jsonb),
    'authority_effect','NONE'
  ) from (select * from tree order by depth,binding_id limit greatest(1,least(p_limit,1000))) q
$$;

-- Future narrow write RPCs must:
-- 1) call world8_role_binding_validate_v1;
-- 2) verify DCP Admission/Lease when mutation is engineering/governed;
-- 3) append event + update projection in one transaction;
-- 4) treat Message/Label/RoleBinding as authority_effect=NONE;
-- 5) never mutate world8_actor_registry identity to express current role;
-- 6) never duplicate world8_internal_messages or world8_mason_assignments truth.
