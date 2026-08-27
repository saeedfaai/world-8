-- World 8 N-Mason Pool v0.1
-- Principle: Parallelize work; serialize truth.
-- Reuses world8_actor_registry, world8_actor_executions, Work/Workspace/Admission/Lease,
-- Dispatch and unified Authority. No second identity/authority/workspace registry.

create table if not exists public.world8_mason_pools (
  pool_id text primary key,
  world_id text not null default 'world-001',
  name text not null,
  status text not null default 'ACTIVE' check (status in ('ACTIVE','DRAINING','SUSPENDED','RETIRED')),
  target_concurrency integer not null check (target_concurrency between 1 and 1000),
  max_members integer not null check (max_members between 1 and 10000),
  coding_enabled boolean not null default true,
  auto_merge_enabled boolean not null default false,
  branch_protection_required boolean not null default true,
  config jsonb not null default '{}'::jsonb check (jsonb_typeof(config)='object'),
  created_by text not null,
  created_at timestamptz not null default clock_timestamp(),
  updated_at timestamptz not null default clock_timestamp(),
  check (max_members >= target_concurrency)
);

create table if not exists public.world8_mason_pool_members (
  pool_id text not null references public.world8_mason_pools(pool_id),
  actor_id text not null references public.world8_actor_registry(actor_id),
  ordinal integer not null check (ordinal > 0),
  status text not null default 'ACTIVE' check (status in ('ACTIVE','DRAINING','SUSPENDED','RETIRED')),
  provider_hints jsonb not null default '[]'::jsonb check (jsonb_typeof(provider_hints)='array'),
  capability_hints jsonb not null default '[]'::jsonb check (jsonb_typeof(capability_hints)='array'),
  metadata jsonb not null default '{}'::jsonb check (jsonb_typeof(metadata)='object'),
  created_at timestamptz not null default clock_timestamp(),
  updated_at timestamptz not null default clock_timestamp(),
  primary key(pool_id,actor_id),
  unique(pool_id,ordinal)
);

create table if not exists public.world8_mason_assignments (
  assignment_id text primary key,
  world_id text not null default 'world-001',
  pool_id text not null references public.world8_mason_pools(pool_id),
  actor_id text not null references public.world8_actor_registry(actor_id),
  work_id text null references public.world8_dev_work_items(work_id),
  execution_id text null references public.world8_actor_executions(execution_id),
  workspace_id text null references public.world8_dev_workspaces(workspace_id),
  provider_hint text null,
  source_room text null,
  required_qualifications jsonb not null default '[]'::jsonb check (jsonb_typeof(required_qualifications)='array'),
  state text not null check (state in ('RESERVED','WORK_BOUND','EXECUTING','CODING','READY_FOR_REVIEW','RELEASED','QUARANTINED','EXPIRED')),
  reserved_by text not null,
  canonical_head_at_reservation text not null,
  expires_at timestamptz not null,
  metadata jsonb not null default '{}'::jsonb check (jsonb_typeof(metadata)='object'),
  created_at timestamptz not null default clock_timestamp(),
  updated_at timestamptz not null default clock_timestamp()
);

create unique index if not exists world8_mason_assignments_one_active_per_actor
  on public.world8_mason_assignments(actor_id)
  where state in ('RESERVED','WORK_BOUND','EXECUTING','CODING','READY_FOR_REVIEW');
create unique index if not exists world8_mason_assignments_one_active_per_work
  on public.world8_mason_assignments(work_id)
  where work_id is not null and state in ('WORK_BOUND','EXECUTING','CODING','READY_FOR_REVIEW');
create index if not exists world8_mason_assignments_pool_state_idx
  on public.world8_mason_assignments(pool_id,state,expires_at);

create or replace function public.world8_mason_pool_create_v1(
  p_pool_id text,
  p_name text,
  p_target_concurrency integer,
  p_max_members integer,
  p_created_by text,
  p_config jsonb default '{}'::jsonb
) returns jsonb
language plpgsql security definer set search_path='public','extensions' as $$
begin
  if coalesce(btrim(p_pool_id),'')='' or coalesce(btrim(p_name),'')='' then raise exception 'POOL_ID_NAME_REQUIRED'; end if;
  if p_target_concurrency<1 or p_target_concurrency>1000 then raise exception 'TARGET_CONCURRENCY_OUT_OF_RANGE'; end if;
  if p_max_members<p_target_concurrency or p_max_members>10000 then raise exception 'POOL_MAX_MEMBERS_INVALID'; end if;
  if jsonb_typeof(coalesce(p_config,'{}'::jsonb))<>'object' then raise exception 'POOL_CONFIG_MUST_BE_OBJECT'; end if;
  insert into public.world8_mason_pools(pool_id,name,status,target_concurrency,max_members,coding_enabled,auto_merge_enabled,branch_protection_required,config,created_by)
  values(p_pool_id,p_name,'ACTIVE',p_target_concurrency,p_max_members,true,false,true,coalesce(p_config,'{}'::jsonb),p_created_by)
  on conflict(pool_id) do update set
    name=excluded.name,
    target_concurrency=excluded.target_concurrency,
    max_members=excluded.max_members,
    config=public.world8_mason_pools.config||excluded.config,
    updated_at=clock_timestamp();
  return (select jsonb_build_object('schema','WORLD8_MASON_POOL/1.0','pool',to_jsonb(p)) from public.world8_mason_pools p where p.pool_id=p_pool_id);
end $$;

create or replace function public.world8_mason_pool_provision_v1(
  p_pool_id text,
  p_count integer,
  p_created_by text,
  p_home_scope text default 'SHARED_CORE'
) returns jsonb
language plpgsql security definer set search_path='public','extensions' as $$
declare
  v_pool public.world8_mason_pools%rowtype;
  v_start integer;
  v_end integer;
  v_i integer;
  v_actor_id text;
  v_prefix text;
  v_created jsonb:='[]'::jsonb;
begin
  if p_count<1 or p_count>1000 then raise exception 'PROVISION_COUNT_OUT_OF_RANGE'; end if;
  if p_home_scope not in ('WORLD','SHARED_CORE','COMPANY','TRADING','INFRASTRUCTURE') then raise exception 'INVALID_ACTOR_SCOPE'; end if;
  select * into v_pool from public.world8_mason_pools where pool_id=p_pool_id and status='ACTIVE' for update;
  if not found then raise exception 'ACTIVE_MASON_POOL_REQUIRED'; end if;
  select coalesce(max(ordinal),0)+1 into v_start from public.world8_mason_pool_members where pool_id=p_pool_id;
  v_end:=v_start+p_count-1;
  if v_end>v_pool.max_members then raise exception 'POOL_MAX_MEMBERS_EXCEEDED'; end if;
  v_prefix:=substr(md5(p_pool_id),1,6);
  for v_i in v_start..v_end loop
    v_actor_id:='mason-worker-'||v_prefix||'-'||lpad(v_i::text,4,'0');
    perform public.world8_actor_upsert_v1(
      v_actor_id,'AI_MASON','Mason Worker '||lpad(v_i::text,4,'0'),p_home_scope,null,
      jsonb_build_object('pool_member',true,'pool_id',p_pool_id,'pool_ordinal',v_i,'identity_provider_independent',true,'provisioned_by',p_created_by)
    );
    insert into public.world8_mason_pool_members(pool_id,actor_id,ordinal,status,metadata)
    values(p_pool_id,v_actor_id,v_i,'ACTIVE',jsonb_build_object('provisioned_by',p_created_by))
    on conflict(pool_id,actor_id) do nothing;
    v_created:=v_created||jsonb_build_array(jsonb_build_object('actor_id',v_actor_id,'ordinal',v_i));
  end loop;
  return jsonb_build_object('schema','WORLD8_MASON_POOL_PROVISION/1.0','pool_id',p_pool_id,'created_count',jsonb_array_length(v_created),'members',v_created);
end $$;

create or replace function public.world8_mason_pool_reserve_v1(
  p_pool_id text,
  p_requested_by text,
  p_provider_hint text default null,
  p_source_room text default null,
  p_required_qualifications jsonb default '[]'::jsonb,
  p_ttl_minutes integer default 120
) returns jsonb
language plpgsql security definer set search_path='public','extensions' as $$
declare
  v_pool public.world8_mason_pools%rowtype;
  v_member record;
  v_now timestamptz:=clock_timestamp();
  v_id text;
  v_head text;
begin
  if p_ttl_minutes<15 or p_ttl_minutes>720 then raise exception 'ASSIGNMENT_TTL_OUT_OF_RANGE'; end if;
  if jsonb_typeof(coalesce(p_required_qualifications,'[]'::jsonb))<>'array' then raise exception 'QUALIFICATIONS_MUST_BE_ARRAY'; end if;
  select * into v_pool from public.world8_mason_pools where pool_id=p_pool_id and status='ACTIVE';
  if not found or not v_pool.coding_enabled then raise exception 'MASON_POOL_CODING_DISABLED'; end if;
  update public.world8_mason_assignments
    set state='EXPIRED',updated_at=v_now
    where pool_id=p_pool_id and state in ('RESERVED','WORK_BOUND','EXECUTING','CODING','READY_FOR_REVIEW') and expires_at<=v_now;
  select m.pool_id,m.actor_id,m.ordinal into v_member
  from public.world8_mason_pool_members m
  where m.pool_id=p_pool_id and m.status='ACTIVE'
    and not exists(
      select 1 from public.world8_mason_assignments a
      where a.actor_id=m.actor_id and a.state in ('RESERVED','WORK_BOUND','EXECUTING','CODING','READY_FOR_REVIEW') and a.expires_at>v_now
    )
    and (p_provider_hint is null or jsonb_array_length(m.provider_hints)=0 or m.provider_hints ? p_provider_hint)
    and not exists(
      select 1 from jsonb_array_elements(coalesce(p_required_qualifications,'[]'::jsonb)) req
      where coalesce(req->>'qualification_ref','')='' or not exists(
        select 1 from public.world8_actor_qualifications q
        where q.actor_id=m.actor_id and q.status='ACTIVE'
          and q.qualification_ref=req->>'qualification_ref'
          and (q.expires_at is null or q.expires_at>v_now)
          and (coalesce(req->>'required_version','')='' or q.qualification_version=req->>'required_version')
      )
    )
  order by m.ordinal
  for update skip locked
  limit 1;
  if not found then raise exception 'POOL_CAPACITY_OR_QUALIFICATION_EXHAUSTED'; end if;
  select metadata->>'canonical_head_commit' into v_head from public.world8_dev_external_resources where resource_id='resource-github-world8-canonical' and status='ACTIVE';
  if coalesce(v_head,'')='' then raise exception 'CANONICAL_GIT_REQUIRED'; end if;
  v_id:='assignment-'||substr(encode(extensions.digest(p_pool_id||'|'||v_member.actor_id||'|'||p_requested_by||'|'||v_now::text,'sha256'),'hex'),1,32);
  insert into public.world8_mason_assignments(assignment_id,pool_id,actor_id,provider_hint,source_room,required_qualifications,state,reserved_by,canonical_head_at_reservation,expires_at,metadata)
  values(v_id,p_pool_id,v_member.actor_id,p_provider_hint,p_source_room,coalesce(p_required_qualifications,'[]'::jsonb),'RESERVED',p_requested_by,v_head,v_now+make_interval(mins=>p_ttl_minutes),jsonb_build_object('provider_is_hint_only',true));
  return jsonb_build_object('schema','WORLD8_MASON_ASSIGNMENT/1.0','assignment_id',v_id,'pool_id',p_pool_id,'actor_id',v_member.actor_id,'ordinal',v_member.ordinal,'state','RESERVED','provider_hint',p_provider_hint,'canonical_head',v_head,'expires_at',v_now+make_interval(mins=>p_ttl_minutes));
end $$;

create or replace function public.world8_mason_pool_bind_work_v1(p_assignment_id text,p_work_id text) returns jsonb
language plpgsql security definer set search_path='public' as $$
declare v_a public.world8_mason_assignments%rowtype; v_w public.world8_dev_work_items%rowtype;
begin
  select * into v_a from public.world8_mason_assignments where assignment_id=p_assignment_id for update;
  if not found or v_a.state not in ('RESERVED','WORK_BOUND') then raise exception 'RESERVED_ASSIGNMENT_REQUIRED'; end if;
  select * into v_w from public.world8_dev_work_items where work_id=p_work_id;
  if not found then raise exception 'WORK_NOT_FOUND'; end if;
  if v_w.actor_ref<>v_a.actor_id then raise exception 'ASSIGNMENT_WORK_ACTOR_MISMATCH'; end if;
  if v_a.source_room is not null and v_w.source_room<>v_a.source_room then raise exception 'ASSIGNMENT_WORK_ROOM_MISMATCH'; end if;
  update public.world8_mason_assignments set work_id=p_work_id,state='WORK_BOUND',updated_at=clock_timestamp() where assignment_id=p_assignment_id;
  return jsonb_build_object('assignment_id',p_assignment_id,'actor_id',v_a.actor_id,'work_id',p_work_id,'state','WORK_BOUND');
end $$;

create or replace function public.world8_mason_pool_bind_execution_v1(p_assignment_id text,p_execution_id text) returns jsonb
language plpgsql security definer set search_path='public' as $$
declare v_a public.world8_mason_assignments%rowtype; v_e public.world8_actor_executions%rowtype;
begin
  select * into v_a from public.world8_mason_assignments where assignment_id=p_assignment_id for update;
  if not found or v_a.state not in ('WORK_BOUND','EXECUTING') or v_a.work_id is null then raise exception 'WORK_BOUND_ASSIGNMENT_REQUIRED'; end if;
  select * into v_e from public.world8_actor_executions where execution_id=p_execution_id and state='ACTIVE';
  if not found then raise exception 'ACTIVE_EXECUTION_REQUIRED'; end if;
  if v_e.actor_id<>v_a.actor_id then raise exception 'ASSIGNMENT_EXECUTION_ACTOR_MISMATCH'; end if;
  update public.world8_mason_assignments set execution_id=p_execution_id,state='EXECUTING',updated_at=clock_timestamp(),metadata=metadata||jsonb_build_object('actual_provider',v_e.provider,'model_id',v_e.model_id) where assignment_id=p_assignment_id;
  return jsonb_build_object('assignment_id',p_assignment_id,'actor_id',v_a.actor_id,'execution_id',p_execution_id,'provider',v_e.provider,'state','EXECUTING');
end $$;

create or replace function public.world8_mason_pool_bind_workspace_v1(p_assignment_id text,p_workspace_id text) returns jsonb
language plpgsql security definer set search_path='public' as $$
declare v_a public.world8_mason_assignments%rowtype; v_ws public.world8_dev_workspaces%rowtype;
begin
  select * into v_a from public.world8_mason_assignments where assignment_id=p_assignment_id for update;
  if not found or v_a.state not in ('WORK_BOUND','EXECUTING','CODING') or v_a.work_id is null then raise exception 'WORK_BOUND_ASSIGNMENT_REQUIRED'; end if;
  select * into v_ws from public.world8_dev_workspaces where workspace_id=p_workspace_id and state='ACTIVE';
  if not found then raise exception 'ACTIVE_WORKSPACE_REQUIRED'; end if;
  if v_ws.actor_id<>v_a.actor_id or v_ws.work_id<>v_a.work_id then raise exception 'ASSIGNMENT_WORKSPACE_BINDING_MISMATCH'; end if;
  if lower(v_ws.branch_ref) in ('main','master') then raise exception 'CANONICAL_BRANCH_WRITE_FORBIDDEN'; end if;
  update public.world8_mason_assignments set workspace_id=p_workspace_id,state='CODING',updated_at=clock_timestamp() where assignment_id=p_assignment_id;
  return jsonb_build_object('assignment_id',p_assignment_id,'actor_id',v_a.actor_id,'work_id',v_a.work_id,'workspace_id',p_workspace_id,'branch_ref',v_ws.branch_ref,'state','CODING');
end $$;

create or replace function public.world8_mason_pool_mark_ready_v1(p_assignment_id text,p_actor_id text,p_metadata jsonb default '{}'::jsonb) returns jsonb
language plpgsql security definer set search_path='public' as $$
begin
  update public.world8_mason_assignments
  set state='READY_FOR_REVIEW',metadata=metadata||coalesce(p_metadata,'{}'::jsonb),updated_at=clock_timestamp()
  where assignment_id=p_assignment_id and actor_id=p_actor_id and state='CODING' and work_id is not null and workspace_id is not null;
  if not found then raise exception 'CODING_ASSIGNMENT_REQUIRED'; end if;
  return jsonb_build_object('assignment_id',p_assignment_id,'state','READY_FOR_REVIEW');
end $$;

create or replace function public.world8_mason_pool_release_assignment_v1(p_assignment_id text,p_actor_id text,p_reason text) returns jsonb
language plpgsql security definer set search_path='public' as $$
declare v_a public.world8_mason_assignments%rowtype;
begin
  select * into v_a from public.world8_mason_assignments where assignment_id=p_assignment_id for update;
  if not found or v_a.actor_id<>p_actor_id then raise exception 'ASSIGNMENT_ACTOR_MISMATCH'; end if;
  if v_a.work_id is not null and exists(select 1 from public.world8_dev_leases l where l.work_id=v_a.work_id and l.status='ACTIVE' and l.expires_at>clock_timestamp()) then raise exception 'ACTIVE_LEASES_MUST_RELEASE_FIRST'; end if;
  if v_a.execution_id is not null and exists(select 1 from public.world8_actor_executions e where e.execution_id=v_a.execution_id and e.state='ACTIVE') then raise exception 'ACTIVE_EXECUTION_MUST_FINISH_FIRST'; end if;
  update public.world8_mason_assignments set state='RELEASED',metadata=metadata||jsonb_build_object('release_reason',coalesce(p_reason,'RELEASED')),updated_at=clock_timestamp() where assignment_id=p_assignment_id;
  return jsonb_build_object('assignment_id',p_assignment_id,'actor_id',p_actor_id,'state','RELEASED');
end $$;

create or replace function public.world8_mason_pool_snapshot_v1(p_pool_id text) returns jsonb
language sql security definer set search_path='public' as $$
  with p as (select * from public.world8_mason_pools where pool_id=p_pool_id),
  members as (select count(*) total,count(*) filter(where status='ACTIVE') active from public.world8_mason_pool_members where pool_id=p_pool_id),
  a as (select count(*) filter(where state in ('RESERVED','WORK_BOUND','EXECUTING','CODING','READY_FOR_REVIEW') and expires_at>clock_timestamp()) busy,
               count(*) filter(where state='CODING' and expires_at>clock_timestamp()) coding,
               count(*) filter(where state='READY_FOR_REVIEW' and expires_at>clock_timestamp()) ready
        from public.world8_mason_assignments where pool_id=p_pool_id)
  select jsonb_build_object('schema','WORLD8_MASON_POOL_SNAPSHOT/1.0','pool',to_jsonb(p),'members',jsonb_build_object('total',members.total,'active',members.active,'busy',a.busy,'available',greatest(members.active-a.busy,0),'coding',a.coding,'ready_for_review',a.ready),'observed_at',clock_timestamp()) from p,members,a;
$$;

revoke all on table public.world8_mason_pools from public,anon,authenticated;
revoke all on table public.world8_mason_pool_members from public,anon,authenticated;
revoke all on table public.world8_mason_assignments from public,anon,authenticated;
revoke all on function public.world8_mason_pool_create_v1(text,text,integer,integer,text,jsonb) from public,anon,authenticated;
revoke all on function public.world8_mason_pool_provision_v1(text,integer,text,text) from public,anon,authenticated;
revoke all on function public.world8_mason_pool_reserve_v1(text,text,text,text,jsonb,integer) from public,anon,authenticated;
revoke all on function public.world8_mason_pool_bind_work_v1(text,text) from public,anon,authenticated;
revoke all on function public.world8_mason_pool_bind_execution_v1(text,text) from public,anon,authenticated;
revoke all on function public.world8_mason_pool_bind_workspace_v1(text,text) from public,anon,authenticated;
revoke all on function public.world8_mason_pool_mark_ready_v1(text,text,jsonb) from public,anon,authenticated;
revoke all on function public.world8_mason_pool_release_assignment_v1(text,text,text) from public,anon,authenticated;
revoke all on function public.world8_mason_pool_snapshot_v1(text) from public,anon,authenticated;
grant execute on function public.world8_mason_pool_create_v1(text,text,integer,integer,text,jsonb) to service_role;
grant execute on function public.world8_mason_pool_provision_v1(text,integer,text,text) to service_role;
grant execute on function public.world8_mason_pool_reserve_v1(text,text,text,text,jsonb,integer) to service_role;
grant execute on function public.world8_mason_pool_bind_work_v1(text,text) to service_role;
grant execute on function public.world8_mason_pool_bind_execution_v1(text,text) to service_role;
grant execute on function public.world8_mason_pool_bind_workspace_v1(text,text) to service_role;
grant execute on function public.world8_mason_pool_mark_ready_v1(text,text,jsonb) to service_role;
grant execute on function public.world8_mason_pool_release_assignment_v1(text,text,text) to service_role;
grant execute on function public.world8_mason_pool_snapshot_v1(text) to service_role;

comment on table public.world8_mason_pools is 'World 8 provider-independent Mason capacity pools. Not an identity registry.';
comment on table public.world8_mason_pool_members is 'References canonical Actor Registry; provider identity belongs to Execution, not Actor.';
comment on table public.world8_mason_assignments is 'Ephemeral pool reservations and bindings to existing Work/Execution/Workspace truth.';
