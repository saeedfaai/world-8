-- World 8 artifact-bound Lease + Cockpit Receipt v0.1
-- Cockpit is projection/receipt only; it does not create authority, qualification or access truth.

create table if not exists public.world8_dev_cockpit_receipts (
  cockpit_receipt_id text primary key,
  world_id text not null default 'world-001',
  actor_id text not null,
  work_id text not null,
  workspace_id text not null,
  target_artifact_id text not null,
  gate_state text not null check (gate_state in ('PASS','BLOCKED')),
  blockers jsonb not null default '[]'::jsonb check (jsonb_typeof(blockers)='array'),
  snapshot jsonb not null check (jsonb_typeof(snapshot)='object'),
  content_hash text not null,
  created_at timestamptz not null default clock_timestamp()
);

create or replace function public.world8_dev_cockpit_receipt_append_only_v1()
returns trigger language plpgsql security definer set search_path=public as $$
begin raise exception 'WORLD8_COCKPIT_RECEIPT_APPEND_ONLY'; end $$;

drop trigger if exists world8_dev_cockpit_receipt_append_only_trg on public.world8_dev_cockpit_receipts;
create trigger world8_dev_cockpit_receipt_append_only_trg before update or delete on public.world8_dev_cockpit_receipts
for each row execute function public.world8_dev_cockpit_receipt_append_only_v1();

create or replace function public.world8_dev_acquire_lease_v4(
  p_work_id text,p_artifact_id text,p_holder_ref text,p_source_room text,p_mode text,p_ttl_seconds integer,p_admission_id text
) returns jsonb language plpgsql security definer set search_path=public as $$
declare a public.world8_dev_admission_receipts%rowtype; r jsonb;
begin
  select * into a from public.world8_dev_admission_receipts where admission_id=p_admission_id;
  if not found then raise exception 'DEVELOPER_ADMISSION_REQUIRED'; end if;
  if a.actor_id<>p_holder_ref then raise exception 'ADMISSION_ACTOR_MISMATCH'; end if;
  if a.work_id<>p_work_id then raise exception 'ADMISSION_WORK_MISMATCH'; end if;
  if a.gate_state<>'PASS' then raise exception 'DEVELOPER_ADMISSION_BLOCKED'; end if;
  if a.expires_at<=clock_timestamp() then raise exception 'DEVELOPER_ADMISSION_EXPIRED'; end if;
  if coalesce(a.authorization_result->>'gate_state','BLOCKED')<>'PASS'
     or not coalesce((a.authorization_result->>'authorization_checked')::boolean,false)
  then raise exception 'WRITE_AUTHORIZATION_EVIDENCE_REQUIRED'; end if;
  if coalesce(a.authorization_result->>'resource_kind','')<>'ARTIFACT'
     or coalesce(a.authorization_result->>'resource_ref','')<>p_artifact_id
  then raise exception 'AUTHORIZATION_ARTIFACT_MISMATCH'; end if;
  if p_mode in ('SHARED_WRITE','EXCLUSIVE_WRITE') and coalesce(a.authorization_result->>'action','')<>'CODE_WRITE'
  then raise exception 'CODE_WRITE_AUTHORIZATION_REQUIRED'; end if;
  r:=public.world8_dev_acquire_lease_v2(p_work_id,p_artifact_id,p_holder_ref,p_source_room,p_mode,p_ttl_seconds,p_admission_id,true);
  update public.world8_dev_leases set metadata=coalesce(metadata,'{}'::jsonb)||jsonb_build_object(
    'authorization_resource_bound',true,'authorization_resource_kind','ARTIFACT','authorization_resource_ref',p_artifact_id,'lease_contract_version','4.0')
  where lease_id=r->>'lease_id';
  return r||jsonb_build_object('schema','WORLD8_DEV_LEASE/4.0','authorization_resource_bound',true,'authorization_resource_ref',p_artifact_id);
end $$;

revoke all on function public.world8_dev_acquire_lease_v4(text,text,text,text,text,integer,text) from public;
grant execute on function public.world8_dev_acquire_lease_v4(text,text,text,text,text,integer,text) to service_role;

create or replace function public.world8_dev_cockpit_receipt_v1(
  p_actor_id text,p_work_id text,p_workspace_id text,p_target_artifact_id text,
  p_required_qualifications jsonb default '[{"qualification_ref":"MASON_CORE","version":"1.4.1"}]'::jsonb
) returns jsonb language plpgsql security definer set search_path=public,extensions as $$
declare
  ar public.world8_actor_registry%rowtype; wi public.world8_dev_work_items%rowtype; w public.world8_dev_workspaces%rowtype;
  a public.world8_dev_admission_receipts%rowtype; g public.world8_dev_access_grant_receipts%rowtype; l public.world8_dev_leases%rowtype;
  v_q jsonb; v_scribe jsonb; v_guardian jsonb; v_resume jsonb; v_now jsonb; v_canonical_head text;
  v_blockers jsonb:='[]'::jsonb; v_snapshot jsonb; v_gate text:='PASS'; v_hash text; v_id text; v_time timestamptz:=clock_timestamp();
begin
  select * into ar from public.world8_actor_registry where actor_id=p_actor_id and status='ACTIVE';
  if not found then v_blockers:=v_blockers||jsonb_build_array(jsonb_build_object('code','ACTIVE_ACTOR_REQUIRED')); end if;
  select * into wi from public.world8_dev_work_items where work_id=p_work_id; if not found then raise exception 'WORK_NOT_FOUND'; end if;
  select * into w from public.world8_dev_workspaces where workspace_id=p_workspace_id;
  if not found or w.state<>'ACTIVE' or w.actor_id<>p_actor_id or w.work_id<>p_work_id then
    v_blockers:=v_blockers||jsonb_build_array(jsonb_build_object('code','ACTIVE_BOUND_WORKSPACE_REQUIRED'));
  end if;
  select metadata->>'canonical_head_commit' into v_canonical_head from public.world8_dev_external_resources where resource_id='resource-github-world8-canonical';
  if v_canonical_head is null or w.base_commit is distinct from v_canonical_head then
    v_blockers:=v_blockers||jsonb_build_array(jsonb_build_object('code','STALE_CANONICAL_BASE','workspace_base',w.base_commit,'canonical_head',v_canonical_head));
  end if;
  v_q:=public.world8_dev_assignment_check_v1(p_actor_id,p_work_id,coalesce(p_required_qualifications,'[]'::jsonb));
  if coalesce(v_q->>'gate_state','BLOCKED')<>'PASS' then v_blockers:=v_blockers||jsonb_build_array(jsonb_build_object('code','QUALIFICATION_REQUIRED','details',v_q)); end if;
  select * into a from public.world8_dev_admission_receipts where actor_id=p_actor_id and work_id=p_work_id and workspace_id=p_workspace_id
    and gate_state='PASS' and expires_at>v_time and authorization_result->>'resource_kind'='ARTIFACT'
    and authorization_result->>'resource_ref'=p_target_artifact_id and authorization_result->>'action'='CODE_WRITE'
    order by issued_at desc limit 1;
  if not found then v_blockers:=v_blockers||jsonb_build_array(jsonb_build_object('code','ARTIFACT_BOUND_AUTHORIZATION_REQUIRED')); end if;
  select * into g from public.world8_dev_access_grant_receipts where actor_id=p_actor_id and work_id=p_work_id and workspace_id=p_workspace_id
    and resource_kind='GITHUB_BRANCH' and resource_ref=('github:saeedfaai/world-8:branch:'||w.branch_ref) order by created_at desc limit 1;
  if not found or g.receipt_kind<>'GRANT' or g.expires_at<=v_time then v_blockers:=v_blockers||jsonb_build_array(jsonb_build_object('code','ACTIVE_BRANCH_ACCESS_GRANT_REQUIRED')); end if;
  select * into l from public.world8_dev_leases where work_id=p_work_id and artifact_id=p_target_artifact_id and holder_ref=p_actor_id
    and status='ACTIVE' and expires_at>v_time and coalesce((metadata->>'authorization_resource_bound')::boolean,false)=true
    and metadata->>'authorization_resource_ref'=p_target_artifact_id order by issued_at desc limit 1;
  if not found then v_blockers:=v_blockers||jsonb_build_array(jsonb_build_object('code','ARTIFACT_BOUND_LEASE_REQUIRED')); end if;
  v_scribe:=public.world8_dev_scribe_guard_v1(p_work_id,p_actor_id,wi.source_room);
  if coalesce(v_scribe->>'gate_state','BLOCKED')<>'PASS' then v_blockers:=v_blockers||jsonb_build_array(jsonb_build_object('code','SCRIBE_GUARD_BLOCKED','details',v_scribe)); end if;
  v_guardian:=public.world8_guardian_awareness_snapshot_v1(p_work_id,p_actor_id);
  v_resume:=public.world8_dev_resume_capsule_v2(p_work_id);
  v_now:=public.world8_now_snapshot_v2(p_actor_id);
  if jsonb_array_length(v_blockers)>0 then v_gate:='BLOCKED'; end if;
  v_snapshot:=jsonb_build_object(
    'projection_only',true,
    'actor',jsonb_build_object('actor_id',p_actor_id,'status',ar.status,'kind',ar.actor_kind),
    'qualification',v_q,
    'authorization',case when a.admission_id is null then '{}'::jsonb else jsonb_build_object('admission_id',a.admission_id,'authorization_receipt_id',a.authorization_result->>'authorization_receipt_id','resource_ref',a.authorization_result->>'resource_ref','gate_state',a.authorization_result->>'gate_state') end,
    'access',case when g.access_receipt_id is null then '{}'::jsonb else jsonb_build_object('access_receipt_id',g.access_receipt_id,'resource_ref',g.resource_ref,'mode',g.access_mode,'expires_at',g.expires_at,'raw_secret_returned',false) end,
    'workspace',jsonb_build_object('workspace_id',p_workspace_id,'branch_ref',w.branch_ref,'base_commit',w.base_commit,'canonical_head',v_canonical_head,'fresh',w.base_commit=v_canonical_head),
    'lease',case when l.lease_id is null then '{}'::jsonb else jsonb_build_object('lease_id',l.lease_id,'artifact_id',l.artifact_id,'fencing_token',l.fencing_token,'expires_at',l.expires_at,'authorization_resource_bound',true) end,
    'scribe',v_scribe,'guardian',v_guardian,
    'resume',jsonb_build_object('resume_state',v_resume->'resume_state','next_safe_action',v_resume->'next_safe_action','latest_checkpoint',v_resume->'latest_checkpoint'),
    'now',v_now,
    'principles',jsonb_build_array('TRAINING != QUALIFICATION','QUALIFICATION != AUTHORITY','ACCESS != AUTHORITY','PARALLELIZE WORK; SERIALIZE TRUTH')
  );
  v_hash:=encode(extensions.digest(p_actor_id||'|'||p_work_id||'|'||p_workspace_id||'|'||p_target_artifact_id||'|'||v_gate||'|'||v_blockers::text||'|'||v_snapshot::text||'|'||v_time::text,'sha256'),'hex');
  v_id:='cockpit-'||substr(v_hash,1,32);
  insert into public.world8_dev_cockpit_receipts(cockpit_receipt_id,actor_id,work_id,workspace_id,target_artifact_id,gate_state,blockers,snapshot,content_hash,created_at)
  values(v_id,p_actor_id,p_work_id,p_workspace_id,p_target_artifact_id,v_gate,v_blockers,v_snapshot,v_hash,v_time);
  return jsonb_build_object('schema','WORLD8_DEV_COCKPIT_RECEIPT/1.0','cockpit_receipt_id',v_id,'gate_state',v_gate,'blockers',v_blockers,'snapshot',v_snapshot,'content_hash',v_hash,'projection_only',true);
end $$;

revoke all on function public.world8_dev_cockpit_receipt_v1(text,text,text,text,jsonb) from public;
grant execute on function public.world8_dev_cockpit_receipt_v1(text,text,text,text,jsonb) to service_role;
