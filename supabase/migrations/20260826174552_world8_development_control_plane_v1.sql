-- World 8 Development Control Plane v1.0
-- Classification: WORLD-LEVEL DEVELOPMENT CONTROL SYSTEM (not a sixth canonical plane)

create table if not exists public.world8_dev_artifacts (
  artifact_id text primary key,
  world_id text not null default 'world-001',
  artifact_type text not null,
  owner_scope text not null check (owner_scope in ('WORLD','SHARED_CORE','COMPANY','TRADING','INFRASTRUCTURE')),
  owner_ref text,
  name text not null,
  description text,
  source_mode text not null check (source_mode in ('MANUAL_ARCHITECTURE','GENERATED_FROM_GIT','GENERATED_FROM_DB','GENERATED_FROM_RUNTIME','EXTERNAL_REFERENCE')),
  development_state text not null default 'IMPLEMENTED' check (development_state in ('PROPOSED','CLAIMED','IMPLEMENTING','IMPLEMENTED','BLOCKED','DEPRECATED','RETIRED','INVALIDATED')),
  validation_state text not null default 'UNTESTED' check (validation_state in ('UNTESTED','TESTING','VALIDATED','REJECTED')),
  promotion_state text not null default 'NOT_PROMOTED' check (promotion_state in ('NOT_PROMOTED','PROMOTION_PENDING','PROMOTED')),
  deployment_state text not null default 'NOT_DEPLOYED' check (deployment_state in ('NOT_DEPLOYED','DEPLOYING','ACTIVE','DEGRADED','RETIRED')),
  architecture_state text check (architecture_state is null or architecture_state in ('OPEN','REVIEW','FROZEN','SUPERSEDED')),
  artifact_revision bigint not null default 1 check (artifact_revision > 0),
  semantic_version text,
  repo_ref text,
  path_ref text,
  runtime_ref text,
  external_uri text,
  content_hash text,
  contract_refs jsonb not null default '[]'::jsonb,
  evidence_refs jsonb not null default '[]'::jsonb,
  tags jsonb not null default '[]'::jsonb,
  metadata jsonb not null default '{}'::jsonb,
  created_by text not null default 'human-root',
  last_changed_by text not null default 'human-root',
  last_change_id text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists world8_dev_artifacts_type_idx on public.world8_dev_artifacts(artifact_type);
create index if not exists world8_dev_artifacts_owner_idx on public.world8_dev_artifacts(owner_scope);
create index if not exists world8_dev_artifacts_name_idx on public.world8_dev_artifacts using gin (to_tsvector('simple', coalesce(name,'') || ' ' || coalesce(description,'')));

create table if not exists public.world8_dev_artifact_dependencies (
  artifact_id text not null references public.world8_dev_artifacts(artifact_id) on delete cascade,
  dependency_artifact_id text not null references public.world8_dev_artifacts(artifact_id) on delete cascade,
  dependency_kind text not null default 'DEPENDS_ON' check (dependency_kind in ('DEPENDS_ON','USES','IMPLEMENTS','RESOLVES_THROUGH','READS_FROM','WRITES_THROUGH','GOVERNED_BY','EVIDENCED_BY')),
  required boolean not null default true,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  primary key (artifact_id, dependency_artifact_id, dependency_kind),
  check (artifact_id <> dependency_artifact_id)
);

create table if not exists public.world8_dev_search_receipts (
  search_receipt_id text primary key,
  world_id text not null default 'world-001',
  actor_ref text not null,
  source_room text not null,
  query_text text not null,
  artifact_types_checked jsonb not null default '[]'::jsonb,
  matches jsonb not null default '[]'::jsonb,
  reuse_decision text not null check (reuse_decision in ('REUSE','EXTEND','NEW','NO_ACTION')),
  rationale text,
  deterministic_lookup_done boolean not null default true,
  semantic_search_used boolean not null default false,
  created_at timestamptz not null default now()
);

create table if not exists public.world8_dev_work_items (
  work_id text primary key,
  world_id text not null default 'world-001',
  source_room text not null,
  owner_scope text not null check (owner_scope in ('WORLD','SHARED_CORE','COMPANY','TRADING','INFRASTRUCTURE')),
  actor_ref text not null,
  goal text not null,
  development_state text not null default 'PROPOSED' check (development_state in ('PROPOSED','CLAIMED','IMPLEMENTING','IMPLEMENTED','BLOCKED','DEPRECATED','RETIRED','INVALIDATED')),
  validation_state text not null default 'UNTESTED' check (validation_state in ('UNTESTED','TESTING','VALIDATED','REJECTED')),
  promotion_state text not null default 'NOT_PROMOTED' check (promotion_state in ('NOT_PROMOTED','PROMOTION_PENDING','PROMOTED')),
  deployment_state text not null default 'NOT_DEPLOYED' check (deployment_state in ('NOT_DEPLOYED','DEPLOYING','ACTIVE','DEGRADED','RETIRED')),
  search_receipt_id text references public.world8_dev_search_receipts(search_receipt_id),
  architecture_ref text,
  base_revision jsonb not null default '{}'::jsonb,
  touches jsonb not null default '[]'::jsonb,
  will_create jsonb not null default '[]'::jsonb,
  will_not_create jsonb not null default '[]'::jsonb,
  blockers jsonb not null default '[]'::jsonb,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.world8_dev_leases (
  lease_id text primary key,
  world_id text not null default 'world-001',
  work_id text not null references public.world8_dev_work_items(work_id),
  artifact_id text not null references public.world8_dev_artifacts(artifact_id),
  holder_ref text not null,
  source_room text not null,
  mode text not null check (mode in ('READ','SHARED_WRITE','EXCLUSIVE_WRITE')),
  base_artifact_revision bigint not null,
  fencing_token bigint not null,
  issued_at timestamptz not null default now(),
  expires_at timestamptz not null,
  last_heartbeat_at timestamptz not null default now(),
  status text not null default 'ACTIVE' check (status in ('ACTIVE','RELEASED','EXPIRED','FORCE_RELEASED','SUPERSEDED')),
  release_reason text,
  metadata jsonb not null default '{}'::jsonb
);

create unique index if not exists world8_dev_one_active_exclusive_per_artifact
on public.world8_dev_leases(artifact_id)
where status='ACTIVE' and mode='EXCLUSIVE_WRITE';

create table if not exists public.world8_dev_handoffs (
  handoff_id text primary key,
  world_id text not null default 'world-001',
  work_id text not null references public.world8_dev_work_items(work_id),
  architecture_ref text,
  claim_ref text,
  lease_id text references public.world8_dev_leases(lease_id),
  base_revision jsonb not null default '{}'::jsonb,
  working_revision jsonb not null default '{}'::jsonb,
  completed jsonb not null default '[]'::jsonb,
  remaining jsonb not null default '[]'::jsonb,
  artifacts_touched jsonb not null default '[]'::jsonb,
  files_changed jsonb not null default '[]'::jsonb,
  db_objects_touched jsonb not null default '[]'::jsonb,
  migrations_applied jsonb not null default '[]'::jsonb,
  tests_passed jsonb not null default '[]'::jsonb,
  tests_failed jsonb not null default '[]'::jsonb,
  evidence_refs jsonb not null default '[]'::jsonb,
  decisions jsonb not null default '[]'::jsonb,
  adr_refs jsonb not null default '[]'::jsonb,
  known_issues jsonb not null default '[]'::jsonb,
  open_conflicts jsonb not null default '[]'::jsonb,
  external_effects_attempted jsonb not null default '[]'::jsonb,
  ambiguous_effects jsonb not null default '[]'::jsonb,
  required_capabilities jsonb not null default '[]'::jsonb,
  next_safe_action text,
  do_not_do jsonb not null default '[]'::jsonb,
  environment_ref jsonb not null default '{}'::jsonb,
  created_by text not null,
  created_at timestamptz not null default now(),
  superseded_by text
);

create table if not exists public.world8_dev_change_packets (
  change_id text primary key,
  world_id text not null default 'world-001',
  source_room text not null,
  source_actor text not null,
  owner_scope text not null check (owner_scope in ('WORLD','SHARED_CORE','COMPANY','TRADING','INFRASTRUCTURE')),
  change_type text not null,
  summary text not null,
  created_components jsonb not null default '[]'::jsonb,
  modified_components jsonb not null default '[]'::jsonb,
  deprecated_components jsonb not null default '[]'::jsonb,
  contracts_affected jsonb not null default '[]'::jsonb,
  dependencies jsonb not null default '[]'::jsonb,
  used_by jsonb not null default '[]'::jsonb,
  breaking boolean not null default false,
  base_revision jsonb not null default '{}'::jsonb,
  result_revision jsonb not null default '{}'::jsonb,
  evidence_refs jsonb not null default '[]'::jsonb,
  deployment_state text not null default 'NOT_DEPLOYED',
  unresolved jsonb not null default '[]'::jsonb,
  next_action text,
  requires_sync_from jsonb not null default '[]'::jsonb,
  packet_hash text not null,
  created_at timestamptz not null default now()
);

create table if not exists public.world8_dev_sync_receipts (
  sync_receipt_id text primary key,
  change_id text not null references public.world8_dev_change_packets(change_id),
  receiver_room text not null,
  status text not null check (status in ('ACCEPTED','CONFLICT','ACTION_REQUIRED','NOT_APPLICABLE','SUPERSEDED')),
  conflict_details jsonb not null default '[]'::jsonb,
  local_action jsonb not null default '[]'::jsonb,
  architecture_state text,
  received_by text not null,
  receipt_hash text not null,
  created_at timestamptz not null default now(),
  unique(change_id, receiver_room)
);

create table if not exists public.world8_dev_external_resources (
  resource_id text primary key,
  world_id text not null default 'world-001',
  resource_type text not null check (resource_type in ('GITHUB','GOOGLE_DRIVE','ZENODO','WEBSITE','SUPABASE','DOCUMENT','OTHER')),
  title text not null,
  uri text,
  provider_ref text,
  owner_scope text not null default 'WORLD',
  status text not null default 'ACTIVE',
  content_hash text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.world8_dev_runtime_snapshots (
  snapshot_id text primary key,
  world_id text not null default 'world-001',
  snapshot_kind text not null,
  generated_at timestamptz not null default now(),
  scanner_version text not null,
  source_ref text not null,
  item_count integer not null default 0,
  snapshot_hash text not null,
  payload jsonb not null,
  metadata jsonb not null default '{}'::jsonb
);

-- Deterministic artifact search. Semantic search is deliberately not authoritative here.
create or replace function public.world8_dev_search_v1(
  p_query text,
  p_types text[] default null,
  p_owner_scope text default null,
  p_include_inactive boolean default true
) returns jsonb
language sql stable security definer set search_path=public as $$
  with hits as (
    select a.artifact_id,a.artifact_type,a.owner_scope,a.name,a.description,a.source_mode,
           a.development_state,a.validation_state,a.promotion_state,a.deployment_state,
           a.artifact_revision,a.semantic_version,a.repo_ref,a.path_ref,a.runtime_ref,a.external_uri,
           a.contract_refs,a.tags,
           case
             when lower(a.artifact_id)=lower(p_query) then 100
             when lower(a.name)=lower(p_query) then 95
             when a.artifact_id ilike '%'||p_query||'%' then 80
             when a.name ilike '%'||p_query||'%' then 75
             when coalesce(a.description,'') ilike '%'||p_query||'%' then 60
             when a.tags::text ilike '%'||p_query||'%' then 50
             else 0 end as score
    from public.world8_dev_artifacts a
    where (p_types is null or a.artifact_type=any(p_types))
      and (p_owner_scope is null or a.owner_scope=p_owner_scope)
      and (p_include_inactive or a.deployment_state='ACTIVE')
      and (a.artifact_id ilike '%'||p_query||'%' or a.name ilike '%'||p_query||'%' or coalesce(a.description,'') ilike '%'||p_query||'%' or a.tags::text ilike '%'||p_query||'%')
    order by score desc,a.artifact_id
    limit 50
  )
  select jsonb_build_object('schema','w8.dev-search/1.0','query',p_query,'authoritative_layer','ARTIFACT_CATALOG','results',coalesce(jsonb_agg(to_jsonb(hits)),'[]'::jsonb)) from hits;
$$;

-- Lease acquisition with TTL + fencing. Shared-write conflicts with active exclusive; exclusive conflicts with any active write.
create or replace function public.world8_dev_acquire_lease_v1(
  p_work_id text,
  p_artifact_id text,
  p_holder_ref text,
  p_source_room text,
  p_mode text,
  p_ttl_seconds integer default 1800
) returns jsonb
language plpgsql security definer set search_path=public as $$
declare
  v_rev bigint; v_token bigint; v_lease_id text; v_now timestamptz:=clock_timestamp();
begin
  if p_ttl_seconds < 60 or p_ttl_seconds > 14400 then raise exception 'LEASE_TTL_OUT_OF_RANGE'; end if;
  update world8_dev_leases set status='EXPIRED',release_reason='TTL_EXPIRED' where status='ACTIVE' and expires_at<=v_now;
  select artifact_revision into v_rev from world8_dev_artifacts where artifact_id=p_artifact_id for update;
  if v_rev is null then raise exception 'ARTIFACT_NOT_FOUND'; end if;
  if p_mode='EXCLUSIVE_WRITE' and exists(select 1 from world8_dev_leases where artifact_id=p_artifact_id and status='ACTIVE' and mode in ('EXCLUSIVE_WRITE','SHARED_WRITE')) then raise exception 'WRITE_LEASE_CONFLICT'; end if;
  if p_mode='SHARED_WRITE' and exists(select 1 from world8_dev_leases where artifact_id=p_artifact_id and status='ACTIVE' and mode='EXCLUSIVE_WRITE') then raise exception 'WRITE_LEASE_CONFLICT'; end if;
  select coalesce(max(fencing_token),0)+1 into v_token from world8_dev_leases where artifact_id=p_artifact_id;
  v_lease_id := 'devlease-'||substr(encode(digest(p_work_id||'|'||p_artifact_id||'|'||p_holder_ref||'|'||v_token||'|'||v_now::text,'sha256'),'hex'),1,32);
  insert into world8_dev_leases(lease_id,work_id,artifact_id,holder_ref,source_room,mode,base_artifact_revision,fencing_token,issued_at,expires_at,last_heartbeat_at,status)
  values(v_lease_id,p_work_id,p_artifact_id,p_holder_ref,p_source_room,p_mode,v_rev,v_token,v_now,v_now+make_interval(secs=>p_ttl_seconds),v_now,'ACTIVE');
  update world8_dev_work_items set development_state=case when development_state='PROPOSED' then 'CLAIMED' else development_state end,updated_at=v_now where work_id=p_work_id;
  return jsonb_build_object('lease_id',v_lease_id,'artifact_id',p_artifact_id,'base_artifact_revision',v_rev,'fencing_token',v_token,'expires_at',v_now+make_interval(secs=>p_ttl_seconds));
end $$;

create or replace function public.world8_dev_heartbeat_lease_v1(p_lease_id text,p_holder_ref text,p_ttl_seconds integer default 1800)
returns jsonb language plpgsql security definer set search_path=public as $$
declare v_now timestamptz:=clock_timestamp(); v_row world8_dev_leases%rowtype;
begin
  if p_ttl_seconds < 60 or p_ttl_seconds > 14400 then raise exception 'LEASE_TTL_OUT_OF_RANGE'; end if;
  select * into v_row from world8_dev_leases where lease_id=p_lease_id for update;
  if not found or v_row.status<>'ACTIVE' then raise exception 'LEASE_NOT_ACTIVE'; end if;
  if v_row.holder_ref<>p_holder_ref then raise exception 'LEASE_HOLDER_MISMATCH'; end if;
  if v_row.expires_at<=v_now then update world8_dev_leases set status='EXPIRED',release_reason='TTL_EXPIRED' where lease_id=p_lease_id; raise exception 'LEASE_EXPIRED'; end if;
  update world8_dev_leases set last_heartbeat_at=v_now,expires_at=v_now+make_interval(secs=>p_ttl_seconds) where lease_id=p_lease_id;
  return jsonb_build_object('lease_id',p_lease_id,'status','ACTIVE','expires_at',v_now+make_interval(secs=>p_ttl_seconds),'fencing_token',v_row.fencing_token);
end $$;

create or replace function public.world8_dev_release_lease_v1(p_lease_id text,p_holder_ref text,p_reason text default 'COMPLETED')
returns jsonb language plpgsql security definer set search_path=public as $$
declare v_row world8_dev_leases%rowtype;
begin
  select * into v_row from world8_dev_leases where lease_id=p_lease_id for update;
  if not found then raise exception 'LEASE_NOT_FOUND'; end if;
  if v_row.holder_ref<>p_holder_ref then raise exception 'LEASE_HOLDER_MISMATCH'; end if;
  if v_row.status<>'ACTIVE' then return jsonb_build_object('lease_id',p_lease_id,'status',v_row.status); end if;
  update world8_dev_leases set status='RELEASED',release_reason=p_reason where lease_id=p_lease_id;
  return jsonb_build_object('lease_id',p_lease_id,'status','RELEASED','fencing_token',v_row.fencing_token);
end $$;

-- CAS update: requires the newest active fencing token for the artifact and expected revision.
create or replace function public.world8_dev_cas_update_artifact_v1(
  p_artifact_id text,
  p_expected_revision bigint,
  p_lease_id text,
  p_fencing_token bigint,
  p_actor_ref text,
  p_change_id text,
  p_patch jsonb
) returns jsonb
language plpgsql security definer set search_path=public as $$
declare v_art world8_dev_artifacts%rowtype; v_lease world8_dev_leases%rowtype; v_max_token bigint; v_newrev bigint;
begin
  select * into v_art from world8_dev_artifacts where artifact_id=p_artifact_id for update;
  if not found then raise exception 'ARTIFACT_NOT_FOUND'; end if;
  if v_art.artifact_revision<>p_expected_revision then raise exception 'STALE_WRITE_REJECTED'; end if;
  select * into v_lease from world8_dev_leases where lease_id=p_lease_id and artifact_id=p_artifact_id;
  if not found or v_lease.status<>'ACTIVE' or v_lease.mode not in ('SHARED_WRITE','EXCLUSIVE_WRITE') then raise exception 'VALID_WRITE_LEASE_REQUIRED'; end if;
  if v_lease.expires_at<=clock_timestamp() then raise exception 'LEASE_EXPIRED'; end if;
  if v_lease.fencing_token<>p_fencing_token then raise exception 'FENCING_TOKEN_MISMATCH'; end if;
  select max(fencing_token) into v_max_token from world8_dev_leases where artifact_id=p_artifact_id;
  if p_fencing_token<>v_max_token then raise exception 'STALE_FENCING_TOKEN'; end if;
  v_newrev:=v_art.artifact_revision+1;
  update world8_dev_artifacts set
    name=coalesce(p_patch->>'name',name),
    description=coalesce(p_patch->>'description',description),
    development_state=coalesce(p_patch->>'development_state',development_state),
    validation_state=coalesce(p_patch->>'validation_state',validation_state),
    promotion_state=coalesce(p_patch->>'promotion_state',promotion_state),
    deployment_state=coalesce(p_patch->>'deployment_state',deployment_state),
    semantic_version=coalesce(p_patch->>'semantic_version',semantic_version),
    repo_ref=coalesce(p_patch->>'repo_ref',repo_ref),
    path_ref=coalesce(p_patch->>'path_ref',path_ref),
    runtime_ref=coalesce(p_patch->>'runtime_ref',runtime_ref),
    external_uri=coalesce(p_patch->>'external_uri',external_uri),
    content_hash=coalesce(p_patch->>'content_hash',content_hash),
    metadata=case when p_patch ? 'metadata' then p_patch->'metadata' else metadata end,
    artifact_revision=v_newrev,last_changed_by=p_actor_ref,last_change_id=p_change_id,updated_at=clock_timestamp()
  where artifact_id=p_artifact_id;
  return jsonb_build_object('artifact_id',p_artifact_id,'previous_revision',p_expected_revision,'result_revision',v_newrev,'change_id',p_change_id);
end $$;

-- One-call bootstrap: pointers/state, not duplicated content.
create or replace function public.world8_dev_bootstrap_v1(p_room text default null)
returns jsonb language sql stable security definer set search_path=public as $$
with active_leases as (
  select jsonb_agg(jsonb_build_object('lease_id',lease_id,'work_id',work_id,'artifact_id',artifact_id,'holder_ref',holder_ref,'source_room',source_room,'mode',mode,'fencing_token',fencing_token,'expires_at',expires_at) order by expires_at) j
  from world8_dev_leases where status='ACTIVE' and expires_at>clock_timestamp()
), active_work as (
  select jsonb_agg(jsonb_build_object('work_id',work_id,'source_room',source_room,'owner_scope',owner_scope,'goal',goal,'development_state',development_state,'validation_state',validation_state,'promotion_state',promotion_state,'deployment_state',deployment_state,'blockers',blockers) order by updated_at desc) j
  from world8_dev_work_items where development_state in ('PROPOSED','CLAIMED','IMPLEMENTING','BLOCKED') and (p_room is null or source_room=p_room or owner_scope in ('WORLD','SHARED_CORE'))
), recent_changes as (
  select jsonb_agg(x) j from (select jsonb_build_object('change_id',change_id,'source_room',source_room,'owner_scope',owner_scope,'change_type',change_type,'summary',summary,'breaking',breaking,'deployment_state',deployment_state,'unresolved',unresolved,'created_at',created_at) x from world8_dev_change_packets order by created_at desc limit 20) q
), resources as (
  select jsonb_agg(jsonb_build_object('resource_id',resource_id,'resource_type',resource_type,'title',title,'uri',uri,'provider_ref',provider_ref,'status',status)) j from world8_dev_external_resources where status='ACTIVE'
), core_artifacts as (
  select jsonb_agg(jsonb_build_object('artifact_id',artifact_id,'artifact_type',artifact_type,'owner_scope',owner_scope,'name',name,'development_state',development_state,'validation_state',validation_state,'promotion_state',promotion_state,'deployment_state',deployment_state,'artifact_revision',artifact_revision,'semantic_version',semantic_version,'runtime_ref',runtime_ref,'contract_refs',contract_refs)) j
  from world8_dev_artifacts where owner_scope in ('WORLD','SHARED_CORE') or (p_room='W8-COMPANY' and owner_scope='COMPANY') or (p_room='W8-TRADING' and owner_scope='TRADING')
)
select jsonb_build_object(
 'schema','WORLD8_DEV_BOOTSTRAP/1.0',
 'classification','WORLD_LEVEL_DEVELOPMENT_CONTROL_SYSTEM_NOT_NEW_CANONICAL_PLANE',
 'thesis','World 8 separates project continuity from developer continuity, the same way it separates entity identity from brain continuity.',
 'principles',jsonb_build_array('NO_CONVERSATION_OWNED_PROJECT_STATE','NO_DUPLICATE_SHARED_INFRASTRUCTURE','SEARCH_BEFORE_BUILD','CLAIM_BEFORE_BUILD','LEASE_BEFORE_WRITE','LEASE_DOES_NOT_REPLACE_CAS','RUNTIME_REALITY_MUST_BE_GENERATED'),
 'room',p_room,
 'architecture_contract_ref','development-control-plane-contract-v1',
 'canonical_skill_registry','world8_skill_library',
 'canonical_binding_registry','world8_binding_artifacts',
 'canonical_resolver','world8_resolve_capability_v1',
 'active_work',coalesce((select j from active_work),'[]'::jsonb),
 'active_leases',coalesce((select j from active_leases),'[]'::jsonb),
 'recent_change_packets',coalesce((select j from recent_changes),'[]'::jsonb),
 'external_resources',coalesce((select j from resources),'[]'::jsonb),
 'artifact_surface',coalesce((select j from core_artifacts),'[]'::jsonb),
 'safe_start_order',jsonb_build_array('BOOTSTRAP','ARCHITECTURE_BASELINE','OWNERSHIP','ARTIFACT_SEARCH','ACTIVE_WORK_AND_LEASES','RELEVANT_HANDOFF','CONFORMANCE','RUNTIME_SNAPSHOT','ACQUIRE_SEARCH_RECEIPT','CREATE_WORK_CLAIM','ACQUIRE_LEASE')
);
$$;

-- Runtime reality snapshot: generated directly from DB metadata, never hand-authored.
create or replace function public.world8_dev_generate_db_runtime_snapshot_v1()
returns jsonb language plpgsql security definer set search_path=public as $$
declare v_payload jsonb; v_hash text; v_id text; v_count int;
begin
  select jsonb_build_object(
    'tables',(select coalesce(jsonb_agg(jsonb_build_object('name',table_name) order by table_name),'[]'::jsonb) from information_schema.tables where table_schema='public'),
    'routines',(select coalesce(jsonb_agg(jsonb_build_object('name',routine_name,'type',routine_type) order by routine_name),'[]'::jsonb) from information_schema.routines where routine_schema='public')
  ) into v_payload;
  select count(*) into v_count from information_schema.tables where table_schema='public';
  v_count:=v_count+(select count(*) from information_schema.routines where routine_schema='public');
  v_hash:=encode(digest(v_payload::text,'sha256'),'hex');
  v_id:='runtime-db-'||substr(v_hash,1,24);
  insert into world8_dev_runtime_snapshots(snapshot_id,snapshot_kind,scanner_version,source_ref,item_count,snapshot_hash,payload)
  values(v_id,'DATABASE_RUNTIME','w8-db-scanner/1.0','supabase:ogiqujrubsvzohqremuv',v_count,v_hash,v_payload)
  on conflict (snapshot_id) do nothing;
  return jsonb_build_object('snapshot_id',v_id,'item_count',v_count,'snapshot_hash',v_hash);
end $$;

-- DCP Cold Developer Bootstrap acceptance test.
create or replace function public.world8_dev_conformance_g1_v1()
returns jsonb language sql stable security definer set search_path=public as $$
select jsonb_build_object(
 'test_id','DCP-G1-COLD-DEVELOPER-BOOTSTRAP',
 'ok',
   exists(select 1 from world8_architecture_contracts where contract_id='development-control-plane-contract-v1' and status='FROZEN')
   and exists(select 1 from world8_dev_artifacts where artifact_id='artifact-world8-skill-library')
   and exists(select 1 from world8_dev_artifacts where artifact_id='artifact-world8-resolver-v1')
   and exists(select 1 from world8_dev_external_resources where resource_id='resource-supabase-world8')
   and to_regprocedure('public.world8_dev_bootstrap_v1(text)') is not null
   and to_regprocedure('public.world8_dev_search_v1(text,text[],text,boolean)') is not null
   and to_regprocedure('public.world8_dev_acquire_lease_v1(text,text,text,text,text,integer)') is not null
   and to_regprocedure('public.world8_dev_cas_update_artifact_v1(text,bigint,text,bigint,text,text,jsonb)') is not null,
 'checks',jsonb_build_object(
   'frozen_contract',exists(select 1 from world8_architecture_contracts where contract_id='development-control-plane-contract-v1' and status='FROZEN'),
   'shared_skill_registry_indexed',exists(select 1 from world8_dev_artifacts where artifact_id='artifact-world8-skill-library'),
   'resolver_indexed',exists(select 1 from world8_dev_artifacts where artifact_id='artifact-world8-resolver-v1'),
   'world_runtime_resource_indexed',exists(select 1 from world8_dev_external_resources where resource_id='resource-supabase-world8'),
   'bootstrap_rpc',to_regprocedure('public.world8_dev_bootstrap_v1(text)') is not null,
   'search_rpc',to_regprocedure('public.world8_dev_search_v1(text,text[],text,boolean)') is not null,
   'lease_rpc',to_regprocedure('public.world8_dev_acquire_lease_v1(text,text,text,text,text,integer)') is not null,
   'cas_rpc',to_regprocedure('public.world8_dev_cas_update_artifact_v1(text,bigint,text,bigint,text,text,jsonb)') is not null
  )
);
$$;

-- RLS: DCP is administrative infrastructure; no anonymous/authenticated direct table access.
alter table public.world8_dev_artifacts enable row level security;
alter table public.world8_dev_artifact_dependencies enable row level security;
alter table public.world8_dev_search_receipts enable row level security;
alter table public.world8_dev_work_items enable row level security;
alter table public.world8_dev_leases enable row level security;
alter table public.world8_dev_handoffs enable row level security;
alter table public.world8_dev_change_packets enable row level security;
alter table public.world8_dev_sync_receipts enable row level security;
alter table public.world8_dev_external_resources enable row level security;
alter table public.world8_dev_runtime_snapshots enable row level security;
revoke all on public.world8_dev_artifacts,public.world8_dev_artifact_dependencies,public.world8_dev_search_receipts,public.world8_dev_work_items,public.world8_dev_leases,public.world8_dev_handoffs,public.world8_dev_change_packets,public.world8_dev_sync_receipts,public.world8_dev_external_resources,public.world8_dev_runtime_snapshots from anon,authenticated;
revoke all on function public.world8_dev_acquire_lease_v1(text,text,text,text,text,integer) from public,anon,authenticated;
revoke all on function public.world8_dev_heartbeat_lease_v1(text,text,integer) from public,anon,authenticated;
revoke all on function public.world8_dev_release_lease_v1(text,text,text) from public,anon,authenticated;
revoke all on function public.world8_dev_cas_update_artifact_v1(text,bigint,text,bigint,text,text,jsonb) from public,anon,authenticated;