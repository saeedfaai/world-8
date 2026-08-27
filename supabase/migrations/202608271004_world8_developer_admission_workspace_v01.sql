-- World 8 Developer Admission + Workspace Foundation v0.1
-- Applied to Supabase world-8 on 2026-08-27.
-- Qualification != Authorization. No raw credentials are stored.

create table if not exists public.world8_dev_workspaces (
  workspace_id text primary key,
  world_id text not null default 'world-001',
  work_id text not null references public.world8_dev_work_items(work_id),
  actor_id text not null references public.world8_actor_registry(actor_id),
  execution_id text null references public.world8_actor_executions(execution_id),
  workspace_provider text not null,
  repo_ref text not null,
  branch_ref text not null,
  base_commit text not null,
  access_mode text not null check (access_mode in ('READ_ONLY','WRITE')),
  isolation_mode text not null check (isolation_mode in ('GIT_BRANCH','GIT_WORKTREE','CONTAINER','REMOTE_WORKSPACE')),
  state text not null check (state in ('ACTIVE','RELEASED','STALE','BLOCKED')),
  evidence_refs jsonb not null default '[]'::jsonb,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default clock_timestamp(),
  updated_at timestamptz not null default clock_timestamp()
);

create unique index if not exists world8_dev_workspaces_active_branch_uq
  on public.world8_dev_workspaces(repo_ref,branch_ref) where state='ACTIVE';
create index if not exists world8_dev_workspaces_work_idx
  on public.world8_dev_workspaces(work_id,state);
create index if not exists world8_dev_workspaces_actor_idx
  on public.world8_dev_workspaces(actor_id,state);

create table if not exists public.world8_dev_admission_receipts (
  admission_id text primary key,
  world_id text not null default 'world-001',
  actor_id text not null references public.world8_actor_registry(actor_id),
  execution_id text null references public.world8_actor_executions(execution_id),
  work_id text not null references public.world8_dev_work_items(work_id),
  workspace_id text null references public.world8_dev_workspaces(workspace_id),
  qualification_requirements jsonb not null default '[]'::jsonb,
  qualification_result jsonb not null default '{}'::jsonb,
  authorization_requirement jsonb not null default '{}'::jsonb,
  authorization_result jsonb not null default '{}'::jsonb,
  workspace_result jsonb not null default '{}'::jsonb,
  blockers jsonb not null default '[]'::jsonb,
  gate_state text not null check (gate_state in ('PASS','BLOCKED')),
  evidence_refs jsonb not null default '[]'::jsonb,
  issued_at timestamptz not null,
  expires_at timestamptz not null,
  content_hash text not null
);

create index if not exists world8_dev_admission_work_idx
  on public.world8_dev_admission_receipts(work_id,issued_at desc);
create index if not exists world8_dev_admission_actor_idx
  on public.world8_dev_admission_receipts(actor_id,issued_at desc);

create or replace function public.world8_dev_register_workspace_v1(
 p_work_id text,
 p_actor_id text,
 p_execution_id text,
 p_repo_ref text,
 p_branch_ref text,
 p_base_commit text,
 p_access_mode text,
 p_isolation_mode text,
 p_evidence_refs jsonb default '[]'::jsonb,
 p_metadata jsonb default '{}'::jsonb
) returns jsonb
language plpgsql security definer set search_path='public','extensions'
as $$
declare
 v_work public.world8_dev_work_items%rowtype;
 v_actor public.world8_actor_registry%rowtype;
 v_canonical public.world8_dev_external_resources%rowtype;
 v_expected_repo text;
 v_expected_head text;
 v_now timestamptz:=clock_timestamp();
 v_id text;
begin
 select * into v_work from public.world8_dev_work_items where work_id=p_work_id;
 if not found then raise exception 'WORK_NOT_FOUND'; end if;
 select * into v_actor from public.world8_actor_registry where actor_id=p_actor_id and status='ACTIVE';
 if not found then raise exception 'ACTIVE_ACTOR_REQUIRED'; end if;
 if v_work.actor_ref<>p_actor_id then raise exception 'WORK_ACTOR_MISMATCH'; end if;
 if p_execution_id is not null and not exists(
   select 1 from public.world8_actor_executions e
   where e.execution_id=p_execution_id and e.actor_id=p_actor_id and e.state='ACTIVE'
 ) then raise exception 'ACTIVE_EXECUTION_MISMATCH'; end if;
 select * into v_canonical from public.world8_dev_external_resources
 where resource_id='resource-github-world8-canonical' and status='ACTIVE';
 if not found then raise exception 'CANONICAL_GIT_REQUIRED'; end if;
 v_expected_repo:=replace(coalesce(v_canonical.provider_ref,''),'github:','');
 v_expected_head:=v_canonical.metadata->>'canonical_head_commit';
 if lower(trim(p_repo_ref))<>lower(trim(v_expected_repo)) then raise exception 'NON_CANONICAL_REPO'; end if;
 if p_access_mode not in ('READ_ONLY','WRITE') then raise exception 'INVALID_WORKSPACE_ACCESS_MODE'; end if;
 if p_isolation_mode not in ('GIT_BRANCH','GIT_WORKTREE','CONTAINER','REMOTE_WORKSPACE') then raise exception 'INVALID_ISOLATION_MODE'; end if;
 if p_access_mode='WRITE' and lower(trim(p_branch_ref)) in ('main','master') then raise exception 'CANONICAL_BRANCH_WRITE_FORBIDDEN'; end if;
 if p_access_mode='WRITE' and (v_expected_head is null or p_base_commit<>v_expected_head) then raise exception 'STALE_CANONICAL_BASE'; end if;
 if p_branch_ref is null or btrim(p_branch_ref)='' then raise exception 'BRANCH_REQUIRED'; end if;
 v_id:='workspace-'||substr(encode(extensions.digest(p_work_id||'|'||p_actor_id||'|'||p_repo_ref||'|'||p_branch_ref||'|'||p_base_commit,'sha256'),'hex'),1,32);
 insert into public.world8_dev_workspaces(workspace_id,world_id,work_id,actor_id,execution_id,workspace_provider,repo_ref,branch_ref,base_commit,access_mode,isolation_mode,state,evidence_refs,metadata,created_at,updated_at)
 values(v_id,'world-001',p_work_id,p_actor_id,p_execution_id,'GITHUB',p_repo_ref,p_branch_ref,p_base_commit,p_access_mode,p_isolation_mode,'ACTIVE',coalesce(p_evidence_refs,'[]'::jsonb),coalesce(p_metadata,'{}'::jsonb),v_now,v_now)
 on conflict(workspace_id) do update set execution_id=excluded.execution_id,state='ACTIVE',evidence_refs=excluded.evidence_refs,metadata=excluded.metadata,updated_at=v_now;
 return jsonb_build_object('schema','WORLD8_DEV_WORKSPACE/1.0','workspace_id',v_id,'state','ACTIVE','repo_ref',p_repo_ref,'branch_ref',p_branch_ref,'base_commit',p_base_commit,'access_mode',p_access_mode,'isolation_mode',p_isolation_mode);
end $$;

create or replace function public.world8_dev_release_workspace_v1(p_workspace_id text,p_actor_id text,p_reason text)
returns jsonb language plpgsql security definer set search_path='public'
as $$
declare v_row public.world8_dev_workspaces%rowtype;
begin
 select * into v_row from public.world8_dev_workspaces where workspace_id=p_workspace_id for update;
 if not found then raise exception 'WORKSPACE_NOT_FOUND'; end if;
 if v_row.actor_id<>p_actor_id then raise exception 'WORKSPACE_ACTOR_MISMATCH'; end if;
 update public.world8_dev_workspaces
 set state='RELEASED',metadata=metadata||jsonb_build_object('release_reason',p_reason),updated_at=clock_timestamp()
 where workspace_id=p_workspace_id;
 return jsonb_build_object('workspace_id',p_workspace_id,'state','RELEASED');
end $$;

create or replace function public.world8_dev_admission_check_v1(
 p_actor_id text,
 p_execution_id text,
 p_work_id text,
 p_workspace_id text,
 p_required_qualifications jsonb default '[]'::jsonb,
 p_authorization_requirement jsonb default '{}'::jsonb,
 p_valid_minutes integer default 60
) returns jsonb
language plpgsql security definer set search_path='public','extensions'
as $$
declare
 v_now timestamptz:=clock_timestamp();
 v_work public.world8_dev_work_items%rowtype;
 v_actor public.world8_actor_registry%rowtype;
 v_ws public.world8_dev_workspaces%rowtype;
 v_canonical public.world8_dev_external_resources%rowtype;
 v_qual jsonb:='{}'::jsonb;
 v_auth jsonb:='{}'::jsonb;
 v_workspace jsonb:='{}'::jsonb;
 v_blockers jsonb:='[]'::jsonb;
 v_gate text:='PASS';
 v_auth_required boolean:=false;
 v_identity_required boolean:=false;
 v_payload jsonb;
 v_hash text;
 v_id text;
begin
 if p_valid_minutes<5 or p_valid_minutes>240 then raise exception 'ADMISSION_VALIDITY_OUT_OF_RANGE'; end if;
 if jsonb_typeof(coalesce(p_required_qualifications,'[]'::jsonb))<>'array' then raise exception 'QUALIFICATIONS_MUST_BE_ARRAY'; end if;
 select * into v_actor from public.world8_actor_registry where actor_id=p_actor_id and status='ACTIVE';
 if not found then v_blockers:=v_blockers||jsonb_build_array(jsonb_build_object('code','ACTIVE_ACTOR_REQUIRED')); end if;
 select * into v_work from public.world8_dev_work_items where work_id=p_work_id;
 if not found then raise exception 'WORK_NOT_FOUND'; end if;
 if v_work.actor_ref<>p_actor_id then v_blockers:=v_blockers||jsonb_build_array(jsonb_build_object('code','WORK_ACTOR_MISMATCH')); end if;
 if p_execution_id is not null and not exists(select 1 from public.world8_actor_executions e where e.execution_id=p_execution_id and e.actor_id=p_actor_id and e.state='ACTIVE') then
   v_blockers:=v_blockers||jsonb_build_array(jsonb_build_object('code','ACTIVE_EXECUTION_REQUIRED'));
 end if;
 v_qual:=public.world8_dev_assignment_check_v1(p_actor_id,p_work_id,coalesce(p_required_qualifications,'[]'::jsonb));
 if coalesce(v_qual->>'gate_state','BLOCKED')<>'PASS' then
   v_blockers:=v_blockers||jsonb_build_array(jsonb_build_object('code','QUALIFICATION_REQUIRED','details',v_qual));
 end if;
 select * into v_ws from public.world8_dev_workspaces where workspace_id=p_workspace_id and state='ACTIVE';
 if not found then
   v_blockers:=v_blockers||jsonb_build_array(jsonb_build_object('code','ACTIVE_WORKSPACE_REQUIRED'));
   v_workspace:=jsonb_build_object('gate_state','BLOCKED');
 else
   select * into v_canonical from public.world8_dev_external_resources where resource_id='resource-github-world8-canonical' and status='ACTIVE';
   if not found then v_blockers:=v_blockers||jsonb_build_array(jsonb_build_object('code','CANONICAL_GIT_REQUIRED')); end if;
   if v_ws.actor_id<>p_actor_id or v_ws.work_id<>p_work_id then v_blockers:=v_blockers||jsonb_build_array(jsonb_build_object('code','WORKSPACE_BINDING_MISMATCH')); end if;
   if v_ws.access_mode='WRITE' and lower(v_ws.branch_ref) in ('main','master') then v_blockers:=v_blockers||jsonb_build_array(jsonb_build_object('code','CANONICAL_BRANCH_WRITE_FORBIDDEN')); end if;
   if v_ws.access_mode='WRITE' and v_ws.base_commit<>coalesce(v_canonical.metadata->>'canonical_head_commit','') then
     v_blockers:=v_blockers||jsonb_build_array(jsonb_build_object('code','STALE_CANONICAL_BASE','workspace_base',v_ws.base_commit,'canonical_head',v_canonical.metadata->>'canonical_head_commit'));
   end if;
   v_workspace:=jsonb_build_object('gate_state',case when v_ws.actor_id=p_actor_id and v_ws.work_id=p_work_id and not(v_ws.access_mode='WRITE' and lower(v_ws.branch_ref) in ('main','master')) and (v_ws.access_mode<>'WRITE' or v_ws.base_commit=coalesce(v_canonical.metadata->>'canonical_head_commit','')) then 'PASS' else 'BLOCKED' end,'workspace_id',v_ws.workspace_id,'repo_ref',v_ws.repo_ref,'branch_ref',v_ws.branch_ref,'base_commit',v_ws.base_commit,'access_mode',v_ws.access_mode,'isolation_mode',v_ws.isolation_mode);
 end if;
 v_auth_required:=coalesce((p_authorization_requirement->>'required')::boolean,false);
 v_identity_required:=coalesce((p_authorization_requirement->>'require_access_identity')::boolean,false);
 if not v_auth_required then
   v_auth:=jsonb_build_object('gate_state','PASS','authorization_checked',false,'state','NOT_REQUIRED','note','Qualification is not authorization. No authority was requested for this admission receipt.');
 else
   if v_identity_required and not exists(select 1 from public.world8_access_identity_bindings b where b.actor_ref=p_actor_id and b.status='ACTIVE' and (b.expires_at is null or b.expires_at>v_now)) then
     v_blockers:=v_blockers||jsonb_build_array(jsonb_build_object('code','ACCESS_IDENTITY_BINDING_REQUIRED'));
   end if;
   if v_actor.authority_ref is null then v_blockers:=v_blockers||jsonb_build_array(jsonb_build_object('code','AUTHORITY_REF_REQUIRED')); end if;
   v_blockers:=v_blockers||jsonb_build_array(jsonb_build_object('code','AUTHORIZATION_VERIFIER_NOT_IMPLEMENTED','action',p_authorization_requirement->>'action','scope',p_authorization_requirement->'scope','resource_refs',p_authorization_requirement->'resource_refs'));
   v_auth:=jsonb_build_object('gate_state','BLOCKED','authorization_checked',false,'state','VERIFIER_NOT_IMPLEMENTED','authority_ref',v_actor.authority_ref,'require_access_identity',v_identity_required,'note','Fail-closed until unified Identity & Authority Fabric provides subject-action-resource-scope-condition authorization evidence.');
 end if;
 if jsonb_array_length(v_blockers)>0 then v_gate:='BLOCKED'; end if;
 v_payload:=jsonb_build_object('schema','WORLD8_DEV_ADMISSION/0.1','actor_id',p_actor_id,'execution_id',p_execution_id,'work_id',p_work_id,'workspace_id',p_workspace_id,'qualification_requirements',coalesce(p_required_qualifications,'[]'::jsonb),'qualification_result',v_qual,'authorization_requirement',coalesce(p_authorization_requirement,'{}'::jsonb),'authorization_result',v_auth,'workspace_result',v_workspace,'blockers',v_blockers,'gate_state',v_gate,'issued_at',v_now,'expires_at',v_now+make_interval(mins=>p_valid_minutes));
 v_hash:=encode(extensions.digest(v_payload::text,'sha256'),'hex');
 v_id:='admission-'||substr(v_hash,1,32);
 insert into public.world8_dev_admission_receipts(admission_id,world_id,actor_id,execution_id,work_id,workspace_id,qualification_requirements,qualification_result,authorization_requirement,authorization_result,workspace_result,blockers,gate_state,evidence_refs,issued_at,expires_at,content_hash)
 values(v_id,'world-001',p_actor_id,p_execution_id,p_work_id,p_workspace_id,coalesce(p_required_qualifications,'[]'::jsonb),v_qual,coalesce(p_authorization_requirement,'{}'::jsonb),v_auth,v_workspace,v_blockers,v_gate,jsonb_build_array('work:'||p_work_id,'workspace:'||coalesce(p_workspace_id,'')),v_now,v_now+make_interval(mins=>p_valid_minutes),v_hash);
 return v_payload||jsonb_build_object('admission_id',v_id,'content_hash',v_hash);
end $$;

create or replace function public.world8_dev_create_work_claim_v3(
 p_source_room text,
 p_owner_scope text,
 p_actor_ref text,
 p_goal text,
 p_search_receipt_id text,
 p_mason_preflight_receipt_id text,
 p_admission_id text,
 p_architecture_ref text,
 p_touches jsonb,
 p_will_create jsonb,
 p_will_not_create jsonb,
 p_blockers jsonb default '[]'::jsonb,
 p_metadata jsonb default '{}'::jsonb
) returns jsonb
language plpgsql security definer set search_path='public','extensions'
as $$
declare v_adm public.world8_dev_admission_receipts%rowtype;
begin
 select * into v_adm from public.world8_dev_admission_receipts where admission_id=p_admission_id;
 if not found then raise exception 'DEVELOPER_ADMISSION_REQUIRED'; end if;
 if v_adm.actor_id<>p_actor_ref then raise exception 'ADMISSION_ACTOR_MISMATCH'; end if;
 if v_adm.gate_state<>'PASS' then raise exception 'DEVELOPER_ADMISSION_BLOCKED'; end if;
 if v_adm.expires_at<=clock_timestamp() then raise exception 'DEVELOPER_ADMISSION_EXPIRED'; end if;
 return public.world8_dev_create_work_claim_v2(p_source_room,p_owner_scope,p_actor_ref,p_goal,p_search_receipt_id,p_mason_preflight_receipt_id,p_architecture_ref,p_touches,p_will_create,p_will_not_create,p_blockers,coalesce(p_metadata,'{}'::jsonb)||jsonb_build_object('admission_id',p_admission_id,'admission_schema','WORLD8_DEV_ADMISSION/0.1'));
end $$;

revoke all on function public.world8_dev_register_workspace_v1(text,text,text,text,text,text,text,text,jsonb,jsonb) from public,anon,authenticated;
grant execute on function public.world8_dev_register_workspace_v1(text,text,text,text,text,text,text,text,jsonb,jsonb) to service_role;
revoke all on function public.world8_dev_release_workspace_v1(text,text,text) from public,anon,authenticated;
grant execute on function public.world8_dev_release_workspace_v1(text,text,text) to service_role;
revoke all on function public.world8_dev_admission_check_v1(text,text,text,text,jsonb,jsonb,integer) from public,anon,authenticated;
grant execute on function public.world8_dev_admission_check_v1(text,text,text,text,jsonb,jsonb,integer) to service_role;
revoke all on function public.world8_dev_create_work_claim_v3(text,text,text,text,text,text,text,text,jsonb,jsonb,jsonb,jsonb,jsonb) from public,anon,authenticated;
grant execute on function public.world8_dev_create_work_claim_v3(text,text,text,text,text,text,text,text,jsonb,jsonb,jsonb,jsonb,jsonb) to service_role;
