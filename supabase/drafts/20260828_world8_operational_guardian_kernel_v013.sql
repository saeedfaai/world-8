-- World 8 Operational Guardian Kernel v0.1.3 — EXECUTABLE DRAFT, NOT MIGRATION
-- Status: CODE_DRAFTED / NOT_APPLIED / NOT_EVIDENCED / NOT_DEPLOYED
-- Effective contract: architecture/contracts/guardian-operational-v0.1.3.yaml
--
-- This file deliberately lives under supabase/drafts.
-- It MUST NOT be applied to Production before governed CODE_WRITE Admission + Lease,
-- executable SQL negative tests, concurrency tests, and mutation evidence.

-- ---------------------------------------------------------------------------
-- 0. Dedicated DB principal. Broad service_role capability is NOT app authority.
-- ---------------------------------------------------------------------------
do $$
begin
  if not exists (select 1 from pg_roles where rolname='world8_operational_guardian_svc') then
    create role world8_operational_guardian_svc nologin noinherit nobypassrls;
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- 1. Society-scoped leader / epoch / fencing projection.
-- ---------------------------------------------------------------------------
create table if not exists public.world8_operational_guardian_leaders (
  world_id text not null default 'world-001',
  society_id text not null,
  guardian_shard_key text not null default 'primary',
  current_epoch bigint not null check (current_epoch > 0),
  lease_holder text not null,
  lease_expires_at timestamptz not null,
  fencing_token bigint not null check (fencing_token > 0),
  policy_version text not null,
  updated_at timestamptz not null default clock_timestamp(),
  primary key(world_id,society_id,guardian_shard_key),
  check (guardian_shard_key='primary')
);

-- ---------------------------------------------------------------------------
-- 2. Partitioned append-only Operational Control Ledger + per-aggregate head.
-- ---------------------------------------------------------------------------
create table if not exists public.world8_guardian_control_events (
  event_id text primary key,
  world_id text not null default 'world-001',
  society_id text not null,
  project_id text null,
  aggregate_type text not null,
  aggregate_id text not null,
  aggregate_version bigint not null check (aggregate_version > 0),
  event_type text not null,
  policy_version text not null,
  guardian_shard_key text not null default 'primary',
  guardian_epoch bigint not null check (guardian_epoch > 0),
  fencing_token bigint not null check (fencing_token > 0),
  correlation_id text not null,
  causation_event_ref text null references public.world8_guardian_control_events(event_id),
  originating_gap_id text null,
  payload jsonb not null default '{}'::jsonb check (jsonb_typeof(payload)='object'),
  payload_hash text not null,
  previous_event_hash text null,
  event_hash text not null,
  idempotency_key text not null,
  issued_at timestamptz not null,
  recorded_at timestamptz not null default clock_timestamp(),
  unique(aggregate_type,aggregate_id,aggregate_version),
  unique(aggregate_type,aggregate_id,idempotency_key),
  check (guardian_shard_key='primary')
);
create index if not exists world8_guardian_control_events_scope_idx
  on public.world8_guardian_control_events(world_id,society_id,recorded_at desc);
create index if not exists world8_guardian_control_events_causation_idx
  on public.world8_guardian_control_events(causation_event_ref)
  where causation_event_ref is not null;

create table if not exists public.world8_guardian_control_heads (
  aggregate_type text not null,
  aggregate_id text not null,
  world_id text not null default 'world-001',
  society_id text not null,
  project_id text null,
  guardian_shard_key text not null default 'primary',
  current_version bigint not null check (current_version >= 0),
  current_event_id text null references public.world8_guardian_control_events(event_id),
  current_event_hash text null,
  current_state jsonb not null default '{}'::jsonb check (jsonb_typeof(current_state)='object'),
  guardian_epoch bigint not null check (guardian_epoch > 0),
  fencing_token bigint not null check (fencing_token > 0),
  policy_version text not null,
  updated_at timestamptz not null default clock_timestamp(),
  primary key(aggregate_type,aggregate_id),
  check (guardian_shard_key='primary')
);

create or replace function public.world8_operational_guardian_append_only_v1()
returns trigger language plpgsql security definer set search_path=public as $$
begin
  raise exception 'WORLD8_OPERATIONAL_GUARDIAN_APPEND_ONLY';
end $$;

drop trigger if exists world8_guardian_control_events_append_only_trg on public.world8_guardian_control_events;
create trigger world8_guardian_control_events_append_only_trg
before update or delete on public.world8_guardian_control_events
for each row execute function public.world8_operational_guardian_append_only_v1();

-- ---------------------------------------------------------------------------
-- 3. Existing assignment truth extension. Never mints a second Mason assignment.
-- ---------------------------------------------------------------------------
create table if not exists public.world8_guardian_work_controls (
  assignment_id text primary key references public.world8_mason_assignments(assignment_id) on delete restrict,
  gap_id text not null,
  world_id text not null default 'world-001',
  society_id text not null,
  project_id text not null,
  dispatch_mode text not null check (dispatch_mode in ('SINGLE','REDUNDANT_N','SHARDED')),
  dispatch_slot_key text not null,
  assignment_kind text not null,
  attempt_no integer not null check (attempt_no > 0),
  state text not null check (state in ('PLANNED','ASSIGNED','ACTIVE','COMPLETED','FAILED','CANCELLED','EXPIRED')),
  parent_assignment_id text null references public.world8_guardian_work_controls(assignment_id),
  decomposition_plan_id text null,
  policy_version text not null,
  guardian_shard_key text not null default 'primary',
  guardian_epoch bigint not null check (guardian_epoch > 0),
  fencing_token bigint not null check (fencing_token > 0),
  repair_retry_budget integer not null default 0 check (repair_retry_budget >= 0),
  provider_switch_budget integer not null default 0 check (provider_switch_budget >= 0),
  timeout_budget_seconds bigint not null check (timeout_budget_seconds > 0),
  deadline_at timestamptz not null,
  created_at timestamptz not null default clock_timestamp(),
  updated_at timestamptz not null default clock_timestamp(),
  unique(gap_id,policy_version,dispatch_slot_key,attempt_no),
  check (guardian_shard_key='primary'),
  check (
    (dispatch_mode='SINGLE' and dispatch_slot_key='single') or
    (dispatch_mode='REDUNDANT_N' and dispatch_slot_key ~ '^redundant:[1-9][0-9]*$') or
    (dispatch_mode='SHARDED' and dispatch_slot_key ~ '^shard:.+$')
  )
);

-- ---------------------------------------------------------------------------
-- 4. Exact leader guard. Every operational mutation must call this in-transaction.
-- ---------------------------------------------------------------------------
create or replace function public.world8_operational_guardian_require_leader_v1(
  p_world_id text,
  p_society_id text,
  p_guardian_shard_key text,
  p_holder_ref text,
  p_guardian_epoch bigint,
  p_fencing_token bigint,
  p_policy_version text
) returns void
language plpgsql security definer set search_path=public as $$
declare
  v_l public.world8_operational_guardian_leaders%rowtype;
begin
  select * into v_l
  from public.world8_operational_guardian_leaders
  where world_id=p_world_id
    and society_id=p_society_id
    and guardian_shard_key=p_guardian_shard_key
  for update;

  if not found then raise exception 'GUARDIAN_LEADER_REQUIRED'; end if;
  if v_l.lease_holder<>p_holder_ref then raise exception 'GUARDIAN_LEASE_HOLDER_MISMATCH'; end if;
  if v_l.current_epoch<>p_guardian_epoch then raise exception 'STALE_GUARDIAN_EPOCH'; end if;
  if v_l.fencing_token<>p_fencing_token then raise exception 'STALE_GUARDIAN_FENCING_TOKEN'; end if;
  if v_l.policy_version<>p_policy_version then raise exception 'GUARDIAN_POLICY_VERSION_MISMATCH'; end if;
  if clock_timestamp()>=v_l.lease_expires_at then raise exception 'GUARDIAN_LEADER_LEASE_EXPIRED'; end if;
end $$;

-- ---------------------------------------------------------------------------
-- 5. Generic fenced per-aggregate CAS append.
-- Idempotent replay returns the existing event; payload collision is rejected.
-- ---------------------------------------------------------------------------
create or replace function public.world8_operational_guardian_append_event_v1(
  p_world_id text,
  p_society_id text,
  p_project_id text,
  p_guardian_shard_key text,
  p_holder_ref text,
  p_guardian_epoch bigint,
  p_fencing_token bigint,
  p_policy_version text,
  p_aggregate_type text,
  p_aggregate_id text,
  p_expected_version bigint,
  p_event_type text,
  p_correlation_id text,
  p_causation_event_ref text,
  p_originating_gap_id text,
  p_payload jsonb,
  p_idempotency_key text,
  p_issued_at timestamptz
) returns jsonb
language plpgsql security definer set search_path='public','extensions' as $$
declare
  v_head public.world8_guardian_control_heads%rowtype;
  v_existing public.world8_guardian_control_events%rowtype;
  v_next bigint;
  v_payload_hash text;
  v_event_hash text;
  v_event_id text;
  v_previous_hash text;
begin
  if coalesce(trim(p_aggregate_type),'')='' or coalesce(trim(p_aggregate_id),'')='' then raise exception 'AGGREGATE_IDENTITY_REQUIRED'; end if;
  if coalesce(trim(p_event_type),'')='' or coalesce(trim(p_idempotency_key),'')='' then raise exception 'EVENT_TYPE_IDEMPOTENCY_REQUIRED'; end if;
  if p_expected_version<0 then raise exception 'EXPECTED_VERSION_OUT_OF_RANGE'; end if;
  if jsonb_typeof(coalesce(p_payload,'{}'::jsonb))<>'object' then raise exception 'CONTROL_EVENT_PAYLOAD_OBJECT_REQUIRED'; end if;

  perform public.world8_operational_guardian_require_leader_v1(
    p_world_id,p_society_id,p_guardian_shard_key,p_holder_ref,p_guardian_epoch,p_fencing_token,p_policy_version
  );

  v_payload_hash:=encode(extensions.digest(coalesce(p_payload,'{}'::jsonb)::text,'sha256'),'hex');

  select * into v_existing
  from public.world8_guardian_control_events
  where aggregate_type=p_aggregate_type and aggregate_id=p_aggregate_id and idempotency_key=p_idempotency_key;
  if found then
    if v_existing.payload_hash<>v_payload_hash or v_existing.event_type<>p_event_type then
      raise exception 'CONTROL_EVENT_IDEMPOTENCY_COLLISION';
    end if;
    return jsonb_build_object('status','IDEMPOTENT_REPLAY','event_id',v_existing.event_id,'aggregate_version',v_existing.aggregate_version,'event_hash',v_existing.event_hash);
  end if;

  select * into v_head from public.world8_guardian_control_heads
  where aggregate_type=p_aggregate_type and aggregate_id=p_aggregate_id
  for update;

  if not found then
    if p_expected_version<>0 then raise exception 'AGGREGATE_CAS_CONFLICT'; end if;
    v_next:=1; v_previous_hash:=null;
  else
    if v_head.world_id<>p_world_id or v_head.society_id<>p_society_id then raise exception 'AGGREGATE_SOCIETY_IMMUTABLE'; end if;
    if v_head.guardian_shard_key<>p_guardian_shard_key then raise exception 'AGGREGATE_GUARDIAN_SHARD_IMMUTABLE'; end if;
    if v_head.current_version<>p_expected_version then raise exception 'AGGREGATE_CAS_CONFLICT'; end if;
    v_next:=v_head.current_version+1; v_previous_hash:=v_head.current_event_hash;
  end if;

  v_event_id:='gctl-'||substr(encode(extensions.digest(p_aggregate_type||'|'||p_aggregate_id||'|'||v_next::text||'|'||p_idempotency_key,'sha256'),'hex'),1,40);
  v_event_hash:=encode(extensions.digest(
    concat_ws('|',p_world_id,p_society_id,coalesce(p_project_id,''),p_aggregate_type,p_aggregate_id,v_next::text,p_event_type,p_policy_version,p_guardian_epoch::text,p_fencing_token::text,coalesce(v_previous_hash,''),v_payload_hash,p_idempotency_key,p_issued_at::text),
    'sha256'
  ),'hex');

  insert into public.world8_guardian_control_events(
    event_id,world_id,society_id,project_id,aggregate_type,aggregate_id,aggregate_version,event_type,policy_version,
    guardian_shard_key,guardian_epoch,fencing_token,correlation_id,causation_event_ref,originating_gap_id,payload,payload_hash,
    previous_event_hash,event_hash,idempotency_key,issued_at
  ) values(
    v_event_id,p_world_id,p_society_id,p_project_id,p_aggregate_type,p_aggregate_id,v_next,p_event_type,p_policy_version,
    p_guardian_shard_key,p_guardian_epoch,p_fencing_token,p_correlation_id,p_causation_event_ref,p_originating_gap_id,
    coalesce(p_payload,'{}'::jsonb),v_payload_hash,v_previous_hash,v_event_hash,p_idempotency_key,p_issued_at
  );

  insert into public.world8_guardian_control_heads(
    aggregate_type,aggregate_id,world_id,society_id,project_id,guardian_shard_key,current_version,current_event_id,current_event_hash,
    current_state,guardian_epoch,fencing_token,policy_version
  ) values(
    p_aggregate_type,p_aggregate_id,p_world_id,p_society_id,p_project_id,p_guardian_shard_key,v_next,v_event_id,v_event_hash,
    coalesce(p_payload,'{}'::jsonb),p_guardian_epoch,p_fencing_token,p_policy_version
  ) on conflict(aggregate_type,aggregate_id) do update set
    project_id=excluded.project_id,
    current_version=excluded.current_version,
    current_event_id=excluded.current_event_id,
    current_event_hash=excluded.current_event_hash,
    current_state=excluded.current_state,
    guardian_epoch=excluded.guardian_epoch,
    fencing_token=excluded.fencing_token,
    policy_version=excluded.policy_version,
    updated_at=clock_timestamp();

  return jsonb_build_object('status','COMMITTED','event_id',v_event_id,'aggregate_version',v_next,'event_hash',v_event_hash);
end $$;

-- ---------------------------------------------------------------------------
-- 6. WorkControl transition guard. Quarantine is intentionally not a state here.
-- ---------------------------------------------------------------------------
create or replace function public.world8_operational_guardian_work_transition_v1(
  p_assignment_id text,
  p_world_id text,
  p_society_id text,
  p_project_id text,
  p_guardian_shard_key text,
  p_holder_ref text,
  p_guardian_epoch bigint,
  p_fencing_token bigint,
  p_policy_version text,
  p_expected_aggregate_version bigint,
  p_target_state text,
  p_gap_id text,
  p_dispatch_mode text,
  p_dispatch_slot_key text,
  p_assignment_kind text,
  p_attempt_no integer,
  p_deadline_at timestamptz,
  p_timeout_budget_seconds bigint,
  p_repair_retry_budget integer,
  p_provider_switch_budget integer,
  p_idempotency_key text,
  p_correlation_id text,
  p_issued_at timestamptz
) returns jsonb
language plpgsql security definer set search_path=public as $$
declare
  v_wc public.world8_guardian_work_controls%rowtype;
  v_current text;
  v_event jsonb;
begin
  if not exists(select 1 from public.world8_mason_assignments a where a.assignment_id=p_assignment_id) then
    raise exception 'EXISTING_MASON_ASSIGNMENT_REQUIRED';
  end if;
  if p_target_state not in ('PLANNED','ASSIGNED','ACTIVE','COMPLETED','FAILED','CANCELLED','EXPIRED') then raise exception 'INVALID_WORKCONTROL_STATE'; end if;
  if p_dispatch_mode='SINGLE' and p_dispatch_slot_key<>'single' then raise exception 'DISPATCH_SLOT_MODE_MISMATCH'; end if;
  if p_dispatch_mode='REDUNDANT_N' and p_dispatch_slot_key !~ '^redundant:[1-9][0-9]*$' then raise exception 'DISPATCH_SLOT_MODE_MISMATCH'; end if;
  if p_dispatch_mode='SHARDED' and p_dispatch_slot_key !~ '^shard:.+$' then raise exception 'DISPATCH_SLOT_MODE_MISMATCH'; end if;

  perform public.world8_operational_guardian_require_leader_v1(
    p_world_id,p_society_id,p_guardian_shard_key,p_holder_ref,p_guardian_epoch,p_fencing_token,p_policy_version
  );

  select * into v_wc from public.world8_guardian_work_controls where assignment_id=p_assignment_id for update;
  if not found then
    if p_target_state<>'PLANNED' then raise exception 'WORKCONTROL_MUST_START_PLANNED'; end if;
    insert into public.world8_guardian_work_controls(
      assignment_id,gap_id,world_id,society_id,project_id,dispatch_mode,dispatch_slot_key,assignment_kind,attempt_no,state,
      policy_version,guardian_shard_key,guardian_epoch,fencing_token,repair_retry_budget,provider_switch_budget,timeout_budget_seconds,deadline_at
    ) values(
      p_assignment_id,p_gap_id,p_world_id,p_society_id,p_project_id,p_dispatch_mode,p_dispatch_slot_key,p_assignment_kind,p_attempt_no,p_target_state,
      p_policy_version,p_guardian_shard_key,p_guardian_epoch,p_fencing_token,p_repair_retry_budget,p_provider_switch_budget,p_timeout_budget_seconds,p_deadline_at
    );
  else
    if v_wc.gap_id<>p_gap_id or v_wc.society_id<>p_society_id or v_wc.policy_version<>p_policy_version
       or v_wc.dispatch_mode<>p_dispatch_mode or v_wc.dispatch_slot_key<>p_dispatch_slot_key or v_wc.attempt_no<>p_attempt_no then
      raise exception 'WORKCONTROL_IDENTITY_IMMUTABLE';
    end if;
    v_current:=v_wc.state;
    if not (
      (v_current='PLANNED' and p_target_state in ('ASSIGNED','CANCELLED','EXPIRED')) or
      (v_current='ASSIGNED' and p_target_state in ('ACTIVE','FAILED','CANCELLED','EXPIRED')) or
      (v_current='ACTIVE' and p_target_state in ('COMPLETED','FAILED','CANCELLED','EXPIRED'))
    ) then raise exception 'FORBIDDEN_WORK_TRANSITION'; end if;
    update public.world8_guardian_work_controls set
      state=p_target_state,guardian_epoch=p_guardian_epoch,fencing_token=p_fencing_token,updated_at=clock_timestamp()
    where assignment_id=p_assignment_id;
  end if;

  v_event:=public.world8_operational_guardian_append_event_v1(
    p_world_id,p_society_id,p_project_id,p_guardian_shard_key,p_holder_ref,p_guardian_epoch,p_fencing_token,p_policy_version,
    'WORK_CONTROL',p_assignment_id,p_expected_aggregate_version,'WORK_'||p_target_state,p_correlation_id,null,p_gap_id,
    jsonb_build_object('assignment_id',p_assignment_id,'gap_id',p_gap_id,'state',p_target_state,'dispatch_mode',p_dispatch_mode,'dispatch_slot_key',p_dispatch_slot_key,'attempt_no',p_attempt_no,'deadline_at',p_deadline_at),
    p_idempotency_key,p_issued_at
  );
  return jsonb_build_object('work_control',p_assignment_id,'state',p_target_state,'ledger',v_event);
end $$;

-- ---------------------------------------------------------------------------
-- 7. Privilege boundary. No anon/authenticated/direct Mason DML.
-- ---------------------------------------------------------------------------
revoke all on public.world8_operational_guardian_leaders from anon, authenticated;
revoke all on public.world8_guardian_control_events from anon, authenticated;
revoke all on public.world8_guardian_control_heads from anon, authenticated;
revoke all on public.world8_guardian_work_controls from anon, authenticated;
revoke all on function public.world8_operational_guardian_require_leader_v1(text,text,text,text,bigint,bigint,text) from public, anon, authenticated;
revoke all on function public.world8_operational_guardian_append_event_v1(text,text,text,text,text,bigint,bigint,text,text,text,bigint,text,text,text,text,jsonb,text,timestamptz) from public, anon, authenticated;
revoke all on function public.world8_operational_guardian_work_transition_v1(text,text,text,text,text,text,bigint,bigint,text,bigint,text,text,text,text,text,integer,timestamptz,bigint,integer,integer,text,text,timestamptz) from public, anon, authenticated;

grant select on public.world8_operational_guardian_leaders, public.world8_guardian_control_events, public.world8_guardian_control_heads, public.world8_guardian_work_controls to world8_operational_guardian_svc;
grant execute on function public.world8_operational_guardian_require_leader_v1(text,text,text,text,bigint,bigint,text) to world8_operational_guardian_svc;
grant execute on function public.world8_operational_guardian_append_event_v1(text,text,text,text,text,bigint,bigint,text,text,text,bigint,text,text,text,text,jsonb,text,timestamptz) to world8_operational_guardian_svc;
grant execute on function public.world8_operational_guardian_work_transition_v1(text,text,text,text,text,text,bigint,bigint,text,bigint,text,text,text,text,text,integer,timestamptz,bigint,integer,integer,text,text,timestamptz) to world8_operational_guardian_svc;

comment on role world8_operational_guardian_svc is
  'World 8 Operational Guardian deterministic service role. NOLOGIN/NOINHERIT/NOBYPASSRLS. Must not be treated as canonical authority.';
