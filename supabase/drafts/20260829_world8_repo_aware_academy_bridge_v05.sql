-- World 8 repo-aware Academy / Git bridge v0.5
-- PROPOSAL ONLY / NOT APPLIED / NOT DEPLOYED.
-- Additive: existing World8-only Workspace v1, Academy Entry v1 and Admission v2/v3 remain unchanged.
-- This migration enrolls no repository. Canonical repository membership must pre-exist as governed evidence.

create table if not exists public.world8_dev_workspace_git_bindings(
  workspace_id text primary key references public.world8_dev_workspaces(workspace_id) on delete restrict,
  canonical_resource_id text not null references public.world8_dev_external_resources(resource_id) on delete restrict,
  resource_provider_ref text not null,
  repo_ref text not null,
  canonical_head text not null check(canonical_head ~ '^[0-9a-f]{40}$'),
  default_branch text not null,
  semantic_hash text not null check(semantic_hash ~ '^[0-9a-f]{64}$'),
  content_hash text not null check(content_hash ~ '^[0-9a-f]{64}$'),
  created_at timestamptz not null default clock_timestamp()
);

create table if not exists public.world8_academy_entry_git_bindings(
  entry_receipt_id text primary key references public.world8_academy_coding_entry_receipts(entry_receipt_id) on delete restrict,
  workspace_id text not null references public.world8_dev_workspaces(workspace_id) on delete restrict,
  canonical_resource_id text not null references public.world8_dev_external_resources(resource_id) on delete restrict,
  canonical_head text not null check(canonical_head ~ '^[0-9a-f]{40}$'),
  semantic_hash text not null check(semantic_hash ~ '^[0-9a-f]{64}$'),
  content_hash text not null check(content_hash ~ '^[0-9a-f]{64}$'),
  created_at timestamptz not null default clock_timestamp()
);

drop trigger if exists world8_workspace_git_binding_append_only_trg on public.world8_dev_workspace_git_bindings;
create trigger world8_workspace_git_binding_append_only_trg
before update or delete on public.world8_dev_workspace_git_bindings
for each row execute function public.world8_academy_evidence_append_only_v1();

drop trigger if exists world8_entry_git_binding_append_only_trg on public.world8_academy_entry_git_bindings;
create trigger world8_entry_git_binding_append_only_trg
before update or delete on public.world8_academy_entry_git_bindings
for each row execute function public.world8_academy_evidence_append_only_v1();

create or replace function public.world8_dev_canonical_git_resource_current_v1(p_resource_id text)
returns jsonb
language plpgsql stable security definer
set search_path to 'pg_catalog','public'
as $$
declare
  r public.world8_dev_external_resources%rowtype;
  repo text;
  head text;
  defbranch text;
begin
  if coalesce(btrim(p_resource_id),'')='' then
    raise exception 'CANONICAL_GIT_RESOURCE_ID_REQUIRED' using errcode='22023';
  end if;
  select * into r
  from public.world8_dev_external_resources
  where resource_id=p_resource_id and status='ACTIVE';
  if not found
     or r.resource_type<>'GITHUB'
     or coalesce((r.metadata->>'canonical')::boolean,false) is distinct from true
     or coalesce(r.metadata->>'role','')<>'canonical_architecture_and_code_source'
     or coalesce(r.provider_ref,'') !~ '^github:[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$' then
    raise exception 'CANONICAL_GIT_RESOURCE_REQUIRED' using errcode='55000';
  end if;
  repo:=substring(r.provider_ref from 8);
  head:=lower(coalesce(r.metadata->>'canonical_head_commit',''));
  defbranch:=coalesce(r.metadata->>'default_branch','');
  if head !~ '^[0-9a-f]{40}$' or coalesce(btrim(defbranch),'')='' then
    raise exception 'CANONICAL_GIT_RESOURCE_STATE_INVALID' using errcode='55000';
  end if;
  return jsonb_build_object(
    'resource_id',r.resource_id,
    'resource_type',r.resource_type,
    'provider_ref',r.provider_ref,
    'repo_ref',repo,
    'canonical_head',head,
    'default_branch',defbranch,
    'owner_scope',r.owner_scope,
    'canonical',true
  );
end$$;

revoke all on function public.world8_dev_canonical_git_resource_current_v1(text)
from public,anon,authenticated,service_role;

create or replace function public.world8_dev_register_workspace_v2(
  p_work_id text,
  p_actor_id text,
  p_execution_id text,
  p_canonical_resource_id text,
  p_repo_ref text,
  p_branch_ref text,
  p_base_commit text,
  p_access_mode text,
  p_isolation_mode text,
  p_evidence_refs jsonb default '[]'::jsonb,
  p_metadata jsonb default '{}'::jsonb
) returns jsonb
language plpgsql security definer
set search_path to 'pg_catalog','public','extensions'
as $$
declare
  w public.world8_dev_work_items%rowtype;
  a public.world8_actor_registry%rowtype;
  c jsonb;
  existing public.world8_dev_workspace_git_bindings%rowtype;
  nowv timestamptz:=clock_timestamp();
  wid text;
  sem jsonb;
  semh text;
  contenth text;
begin
  if jsonb_typeof(coalesce(p_evidence_refs,'[]'::jsonb))<>'array'
     or jsonb_typeof(coalesce(p_metadata,'{}'::jsonb))<>'object' then
    raise exception 'WORKSPACE_V2_JSON_CONTRACT_INVALID' using errcode='22023';
  end if;
  select * into w from public.world8_dev_work_items where work_id=p_work_id;
  if not found then raise exception 'WORK_NOT_FOUND'; end if;
  select * into a from public.world8_actor_registry where actor_id=p_actor_id and status='ACTIVE';
  if not found then raise exception 'ACTIVE_ACTOR_REQUIRED'; end if;
  if w.actor_ref<>p_actor_id then raise exception 'WORK_ACTOR_MISMATCH'; end if;
  if p_execution_id is not null and not exists(
    select 1 from public.world8_actor_executions e
    where e.execution_id=p_execution_id and e.actor_id=p_actor_id and e.state='ACTIVE'
  ) then raise exception 'ACTIVE_EXECUTION_MISMATCH'; end if;

  c:=public.world8_dev_canonical_git_resource_current_v1(p_canonical_resource_id);
  if lower(trim(p_repo_ref))<>lower(c->>'repo_ref') then
    raise exception 'NON_CANONICAL_REPO_FOR_RESOURCE';
  end if;
  if lower(coalesce(p_base_commit,''))<>c->>'canonical_head' then
    raise exception 'STALE_CANONICAL_RESOURCE_BASE';
  end if;
  if p_access_mode not in('READ_ONLY','WRITE') then raise exception 'INVALID_WORKSPACE_ACCESS_MODE'; end if;
  if p_isolation_mode not in('GIT_BRANCH','GIT_WORKTREE','CONTAINER','REMOTE_WORKSPACE') then raise exception 'INVALID_ISOLATION_MODE'; end if;
  if coalesce(btrim(p_branch_ref),'')='' then raise exception 'BRANCH_REQUIRED'; end if;
  if p_access_mode='WRITE' and lower(trim(p_branch_ref)) in ('main','master',lower(c->>'default_branch')) then
    raise exception 'CANONICAL_BRANCH_WRITE_FORBIDDEN';
  end if;

  sem:=jsonb_build_object(
    'schema','WORLD8_DEV_WORKSPACE_GIT_BINDING/0.5',
    'work_id',p_work_id,'actor_id',p_actor_id,'execution_id',p_execution_id,
    'canonical_resource_id',p_canonical_resource_id,
    'provider_ref',c->>'provider_ref','repo_ref',c->>'repo_ref',
    'branch_ref',p_branch_ref,'canonical_head',c->>'canonical_head',
    'default_branch',c->>'default_branch','access_mode',p_access_mode,
    'isolation_mode',p_isolation_mode
  );
  semh:=encode(extensions.digest(convert_to(sem::text,'UTF8'),'sha256'),'hex');
  wid:='workspace-'||substr(encode(extensions.digest(convert_to(
    p_work_id||'|'||p_actor_id||'|'||p_canonical_resource_id||'|'||p_repo_ref||'|'||p_branch_ref||'|'||p_base_commit,'UTF8'
  ),'sha256'),'hex'),1,32);

  insert into public.world8_dev_workspaces(
    workspace_id,world_id,work_id,actor_id,execution_id,workspace_provider,repo_ref,branch_ref,
    base_commit,access_mode,isolation_mode,state,evidence_refs,metadata,created_at,updated_at
  ) values(
    wid,'world-001',p_work_id,p_actor_id,p_execution_id,'GITHUB',c->>'repo_ref',p_branch_ref,
    c->>'canonical_head',p_access_mode,p_isolation_mode,'ACTIVE',coalesce(p_evidence_refs,'[]'::jsonb),
    coalesce(p_metadata,'{}'::jsonb)||jsonb_build_object('canonical_resource_id',p_canonical_resource_id,'workspace_contract_version','2.0'),nowv,nowv
  ) on conflict(workspace_id) do update set
    execution_id=excluded.execution_id,state='ACTIVE',evidence_refs=excluded.evidence_refs,
    metadata=excluded.metadata,updated_at=nowv;

  contenth:=encode(extensions.digest(convert_to((sem||jsonb_build_object('workspace_id',wid,'created_at',nowv))::text,'UTF8'),'sha256'),'hex');
  insert into public.world8_dev_workspace_git_bindings(
    workspace_id,canonical_resource_id,resource_provider_ref,repo_ref,canonical_head,default_branch,semantic_hash,content_hash,created_at
  ) values(
    wid,p_canonical_resource_id,c->>'provider_ref',c->>'repo_ref',c->>'canonical_head',c->>'default_branch',semh,contenth,nowv
  ) on conflict(workspace_id) do nothing;

  select * into existing from public.world8_dev_workspace_git_bindings where workspace_id=wid;
  if not found
     or existing.canonical_resource_id<>p_canonical_resource_id
     or lower(existing.repo_ref)<>lower(c->>'repo_ref')
     or existing.canonical_head<>c->>'canonical_head'
     or existing.semantic_hash<>semh then
    raise exception 'WORKSPACE_GIT_BINDING_IDEMPOTENCY_COLLISION' using errcode='23505';
  end if;

  return jsonb_build_object(
    'schema','WORLD8_DEV_WORKSPACE/2.0','workspace_id',wid,'state','ACTIVE',
    'canonical_resource_id',p_canonical_resource_id,'provider_ref',c->>'provider_ref',
    'repo_ref',c->>'repo_ref','branch_ref',p_branch_ref,'base_commit',c->>'canonical_head',
    'access_mode',p_access_mode,'isolation_mode',p_isolation_mode,'binding_hash',contenth
  );
end$$;

revoke all on function public.world8_dev_register_workspace_v2(text,text,text,text,text,text,text,text,text,jsonb,jsonb)
from public,anon,authenticated;
grant execute on function public.world8_dev_register_workspace_v2(text,text,text,text,text,text,text,text,text,jsonb,jsonb)
to service_role;

create or replace function public.world8_academy_coding_entry_issue_v2(
  p_actor_id text,
  p_execution_id text,
  p_work_id text,
  p_workspace_id text,
  p_dev_session_id text,
  p_preflight_receipt_id text,
  p_qualification_id text,
  p_canonical_resource_id text,
  p_mission_accepted boolean,
  p_valid_minutes integer default 15,
  p_evidence_refs jsonb default '[]'::jsonb
) returns jsonb
language plpgsql security definer
set search_path to 'pg_catalog','public','extensions'
as $$
declare
  nowv timestamptz:=clock_timestamp();
  e public.world8_actor_executions%rowtype;
  w public.world8_dev_work_items%rowtype;
  ws public.world8_dev_workspaces%rowtype;
  wb public.world8_dev_workspace_git_bindings%rowtype;
  s public.world8_dev_session_liveness%rowtype;
  pf public.world8_mason_preflight_receipts%rowtype;
  q public.world8_actor_qualifications%rowtype;
  g public.world8_guardian_companion_sessions%rowtype;
  sh public.world8_code_shadow_manifests%rowtype;
  cp public.world8_dev_session_checkpoints%rowtype;
  old public.world8_academy_coding_entry_receipts%rowtype;
  eb public.world8_academy_entry_git_bindings%rowtype;
  c jsonb;
  contextv jsonb;
  sem jsonb;
  semh text;
  contenth text;
  eid text;
begin
  if p_valid_minutes<5 or p_valid_minutes>60 then raise exception 'ACADEMY_ENTRY_VALIDITY_OUT_OF_RANGE'; end if;
  if p_mission_accepted is distinct from true then raise exception 'ACADEMY_MISSION_ACCEPTANCE_REQUIRED'; end if;
  if jsonb_typeof(coalesce(p_evidence_refs,'[]'::jsonb))<>'array' then raise exception 'ACADEMY_ENTRY_EVIDENCE_MUST_BE_ARRAY'; end if;
  c:=public.world8_dev_canonical_git_resource_current_v1(p_canonical_resource_id);

  select * into e from public.world8_actor_executions
  where execution_id=p_execution_id and actor_id=p_actor_id and state='ACTIVE';
  if not found then raise exception 'ACADEMY_ENTRY_ACTIVE_EXECUTION_REQUIRED'; end if;
  select * into w from public.world8_dev_work_items where work_id=p_work_id and actor_ref=p_actor_id;
  if not found or coalesce(w.goal,'')='' then raise exception 'ACADEMY_ENTRY_WORK_REQUIRED'; end if;
  select * into ws from public.world8_dev_workspaces
  where workspace_id=p_workspace_id and actor_id=p_actor_id and work_id=p_work_id and state='ACTIVE' and access_mode='WRITE';
  if not found then raise exception 'ACADEMY_ENTRY_ACTIVE_WRITE_WORKSPACE_REQUIRED'; end if;
  select * into wb from public.world8_dev_workspace_git_bindings where workspace_id=ws.workspace_id;
  if not found
     or wb.canonical_resource_id<>p_canonical_resource_id
     or lower(wb.repo_ref)<>lower(c->>'repo_ref')
     or wb.canonical_head<>c->>'canonical_head'
     or lower(ws.repo_ref)<>lower(c->>'repo_ref')
     or ws.base_commit<>c->>'canonical_head' then
    raise exception 'ACADEMY_ENTRY_CANONICAL_RESOURCE_BINDING_REQUIRED';
  end if;
  if lower(ws.branch_ref) in('main','master',lower(c->>'default_branch')) then
    raise exception 'ACADEMY_ENTRY_ACTIVE_WRITE_WORKSPACE_REQUIRED';
  end if;

  select * into s from public.world8_dev_session_liveness
  where session_id=p_dev_session_id and actor_id=p_actor_id and execution_id=p_execution_id
    and work_id=p_work_id and workspace_id=p_workspace_id and status='ACTIVE';
  if not found then raise exception 'ACADEMY_ENTRY_SESSION_BINDING_MISMATCH'; end if;
  select * into pf from public.world8_mason_preflight_receipts
  where preflight_receipt_id=p_preflight_receipt_id and actor_ref=p_actor_id and gate_state='PASS' and expires_at>nowv;
  if not found
     or jsonb_typeof(pf.now_snapshot)<>'object'
     or jsonb_typeof(pf.inbox_snapshot)<>'array'
     or jsonb_typeof(pf.attention_snapshot)<>'array'
     or jsonb_typeof(pf.access_snapshot)<>'object'
     or jsonb_typeof(pf.continuity_sync_snapshot)<>'object'
     or jsonb_typeof(pf.diagnostic_search_snapshot)<>'object' then
    raise exception 'ACADEMY_ENTRY_CONTEXT_SNAPSHOT_INCOMPLETE';
  end if;
  select * into q from public.world8_actor_qualifications
  where qualification_id=p_qualification_id and actor_id=p_actor_id
    and qualification_ref='MASON_CORE' and qualification_version='1.4.1'
    and status='ACTIVE' and valid_from<=nowv and expires_at>nowv;
  if not found then raise exception 'ACADEMY_ENTRY_CURRENT_MASON_CORE_QUALIFICATION_REQUIRED'; end if;
  select * into sh from public.world8_code_shadow_manifests
  where artifact_id='artifact-world8-academy-v1' and status='ACTIVE' and completeness_state='COMPLETE'
  order by shadow_revision desc limit 1;
  if not found then raise exception 'ACADEMY_ENTRY_CURRENT_ACADEMY_SHADOW_REQUIRED'; end if;
  select * into g from public.world8_guardian_companion_sessions
  where dev_session_id=p_dev_session_id and actor_id=p_actor_id and execution_id=p_execution_id
    and workspace_id=p_workspace_id and guardian_service_id='service-world8-engineering-guardian' and status='ACTIVE'
  order by updated_at desc limit 1;
  if not found or g.authority_mode<>'ADVISORY_ONLY' then raise exception 'ACADEMY_ENTRY_GUARDIAN_REQUIRED'; end if;
  select * into cp from public.world8_dev_session_checkpoints
  where session_id=p_dev_session_id and actor_id=p_actor_id and work_id=p_work_id and workspace_id=p_workspace_id
  order by created_at desc limit 1;
  if not found or coalesce(cp.next_safe_action,'')='' then raise exception 'ACADEMY_ENTRY_CHECKPOINT_REQUIRED'; end if;

  contextv:=jsonb_build_object(
    'architecture_ref',pf.architecture_ref,'inbox_snapshot',pf.inbox_snapshot,
    'attention_snapshot',pf.attention_snapshot,'access_snapshot',pf.access_snapshot,
    'continuity_sync_snapshot',pf.continuity_sync_snapshot,
    'diagnostic_search_snapshot',pf.diagnostic_search_snapshot,'role_ref',s.metadata->>'role',
    'canonical_resource_id',p_canonical_resource_id,'provider_ref',c->>'provider_ref',
    'repo_ref',c->>'repo_ref','canonical_head',c->>'canonical_head'
  );
  sem:=jsonb_build_object(
    'schema','WORLD8_ACADEMY_CODING_ENTRY/0.5','actor_id',p_actor_id,'execution_id',p_execution_id,
    'work_id',p_work_id,'workspace_id',p_workspace_id,'dev_session_id',p_dev_session_id,
    'preflight_receipt_id',p_preflight_receipt_id,'qualification_id',p_qualification_id,
    'canonical_resource_id',p_canonical_resource_id,'canonical_head',c->>'canonical_head',
    'academy_shadow_id',sh.shadow_id,'guardian_companion_id',g.companion_id,
    'checkpoint_id',cp.checkpoint_id,'context_binding',contextv,'authority_effect','NONE'
  );
  semh:=encode(extensions.digest(convert_to(sem::text,'UTF8'),'sha256'),'hex');

  select * into old from public.world8_academy_coding_entry_receipts
  where execution_id=p_execution_id and work_id=p_work_id and workspace_id=p_workspace_id;
  if found then
    select * into eb from public.world8_academy_entry_git_bindings where entry_receipt_id=old.entry_receipt_id;
    if old.semantic_hash=semh and old.expires_at>nowv and found
       and eb.canonical_resource_id=p_canonical_resource_id and eb.canonical_head=c->>'canonical_head' then
      return jsonb_build_object(
        'schema','WORLD8_ACADEMY_CODING_ENTRY/0.5','entry_receipt_id',old.entry_receipt_id,
        'canonical_resource_id',p_canonical_resource_id,'authority_effect','NONE',
        'idempotent_replay',true,'expires_at',old.expires_at
      );
    end if;
    raise exception 'ACADEMY_ENTRY_IDEMPOTENCY_COLLISION';
  end if;

  eid:='academy-entry-'||substr(semh,1,32);
  contenth:=encode(extensions.digest(convert_to((sem||jsonb_build_object(
    'issued_at',nowv,'expires_at',nowv+make_interval(mins=>p_valid_minutes)
  ))::text,'UTF8'),'sha256'),'hex');
  insert into public.world8_academy_coding_entry_receipts(
    entry_receipt_id,actor_id,execution_id,work_id,workspace_id,dev_session_id,preflight_receipt_id,
    qualification_id,canonical_head,academy_shadow_id,guardian_companion_id,checkpoint_id,context_binding,
    gate_state,authority_effect,semantic_hash,content_hash,issued_at,expires_at
  ) values(
    eid,p_actor_id,p_execution_id,p_work_id,p_workspace_id,p_dev_session_id,p_preflight_receipt_id,
    p_qualification_id,c->>'canonical_head',sh.shadow_id,g.companion_id,cp.checkpoint_id,contextv,
    'PASS','NONE',semh,contenth,nowv,nowv+make_interval(mins=>p_valid_minutes)
  );
  insert into public.world8_academy_entry_git_bindings(
    entry_receipt_id,workspace_id,canonical_resource_id,canonical_head,semantic_hash,content_hash,created_at
  ) values(eid,p_workspace_id,p_canonical_resource_id,c->>'canonical_head',semh,contenth,nowv);

  return jsonb_build_object(
    'schema','WORLD8_ACADEMY_CODING_ENTRY/0.5','entry_receipt_id',eid,
    'canonical_resource_id',p_canonical_resource_id,'canonical_head',c->>'canonical_head',
    'authority_effect','NONE','idempotent_replay',false,'expires_at',nowv+make_interval(mins=>p_valid_minutes)
  );
end$$;

revoke all on function public.world8_academy_coding_entry_issue_v2(text,text,text,text,text,text,text,text,boolean,integer,jsonb)
from public,anon,authenticated;
grant execute on function public.world8_academy_coding_entry_issue_v2(text,text,text,text,text,text,text,text,boolean,integer,jsonb)
to service_role;

create or replace function public.world8_dev_admission_check_v4(
  p_actor_id text,
  p_execution_id text,
  p_work_id text,
  p_workspace_id text,
  p_entry_receipt_id text,
  p_required_qualifications jsonb default '[]'::jsonb,
  p_authorization_requirement jsonb default '{}'::jsonb,
  p_valid_minutes integer default 60
) returns jsonb
language plpgsql security definer
set search_path to 'pg_catalog','public','extensions'
as $$
declare
  nowv timestamptz:=clock_timestamp();
  er public.world8_academy_coding_entry_receipts%rowtype;
  eb public.world8_academy_entry_git_bindings%rowtype;
  ws public.world8_dev_workspaces%rowtype;
  wb public.world8_dev_workspace_git_bindings%rowtype;
  actorv public.world8_actor_registry%rowtype;
  workv public.world8_dev_work_items%rowtype;
  c jsonb;
  qual jsonb:='{}'::jsonb;
  auth jsonb:='{}'::jsonb;
  authz jsonb:='{}'::jsonb;
  authscope jsonb:='{}'::jsonb;
  workspace_result jsonb:='{}'::jsonb;
  blockers jsonb:='[]'::jsonb;
  gate text:='PASS';
  auth_required boolean:=false;
  payload jsonb;
  hashv text;
  aid text;
  bindhash text;
begin
  if p_valid_minutes<5 or p_valid_minutes>240 then raise exception 'ADMISSION_VALIDITY_OUT_OF_RANGE'; end if;
  if jsonb_typeof(coalesce(p_required_qualifications,'[]'::jsonb))<>'array' then raise exception 'QUALIFICATIONS_MUST_BE_ARRAY'; end if;
  if jsonb_typeof(coalesce(p_authorization_requirement,'{}'::jsonb))<>'object' then raise exception 'AUTHORIZATION_REQUIREMENT_MUST_BE_OBJECT'; end if;

  select * into er from public.world8_academy_coding_entry_receipts
  where entry_receipt_id=p_entry_receipt_id and gate_state='PASS' and expires_at>nowv;
  if not found then raise exception 'CURRENT_ACADEMY_ENTRY_REQUIRED'; end if;
  if er.actor_id<>p_actor_id or er.execution_id<>p_execution_id or er.work_id<>p_work_id or er.workspace_id<>p_workspace_id then
    raise exception 'ACADEMY_ENTRY_BINDING_MISMATCH';
  end if;
  if er.authority_effect<>'NONE' then raise exception 'ACADEMY_ENTRY_AUTHORITY_EFFECT_FORBIDDEN'; end if;
  select * into eb from public.world8_academy_entry_git_bindings where entry_receipt_id=er.entry_receipt_id;
  if not found then raise exception 'ACADEMY_ENTRY_GIT_BINDING_REQUIRED'; end if;
  select * into ws from public.world8_dev_workspaces where workspace_id=p_workspace_id and state='ACTIVE';
  if not found then raise exception 'ACTIVE_WORKSPACE_REQUIRED'; end if;
  select * into wb from public.world8_dev_workspace_git_bindings where workspace_id=ws.workspace_id;
  if not found then raise exception 'WORKSPACE_GIT_BINDING_REQUIRED'; end if;
  if eb.workspace_id<>ws.workspace_id or eb.canonical_resource_id<>wb.canonical_resource_id or eb.canonical_head<>wb.canonical_head then
    raise exception 'ENTRY_WORKSPACE_GIT_BINDING_MISMATCH';
  end if;
  c:=public.world8_dev_canonical_git_resource_current_v1(wb.canonical_resource_id);
  if wb.canonical_head<>c->>'canonical_head' or ws.base_commit<>c->>'canonical_head'
     or er.canonical_head<>c->>'canonical_head' or lower(ws.repo_ref)<>lower(c->>'repo_ref') then
    raise exception 'STALE_CANONICAL_RESOURCE_BINDING';
  end if;
  if ws.actor_id<>p_actor_id or ws.work_id<>p_work_id then raise exception 'WORKSPACE_BINDING_MISMATCH'; end if;
  if ws.access_mode='WRITE' and lower(ws.branch_ref) in('main','master',lower(c->>'default_branch')) then
    raise exception 'CANONICAL_BRANCH_WRITE_FORBIDDEN';
  end if;

  select * into actorv from public.world8_actor_registry where actor_id=p_actor_id and status='ACTIVE';
  if not found then blockers:=blockers||jsonb_build_array(jsonb_build_object('code','ACTIVE_ACTOR_REQUIRED')); end if;
  select * into workv from public.world8_dev_work_items where work_id=p_work_id;
  if not found then raise exception 'WORK_NOT_FOUND'; end if;
  if workv.actor_ref<>p_actor_id then blockers:=blockers||jsonb_build_array(jsonb_build_object('code','WORK_ACTOR_MISMATCH')); end if;
  if not exists(select 1 from public.world8_actor_executions e where e.execution_id=p_execution_id and e.actor_id=p_actor_id and e.state='ACTIVE') then
    blockers:=blockers||jsonb_build_array(jsonb_build_object('code','ACTIVE_EXECUTION_REQUIRED'));
  end if;

  qual:=public.world8_dev_assignment_check_v1(p_actor_id,p_work_id,coalesce(p_required_qualifications,'[]'::jsonb));
  if coalesce(qual->>'gate_state','BLOCKED')<>'PASS' then
    blockers:=blockers||jsonb_build_array(jsonb_build_object('code','QUALIFICATION_REQUIRED','details',qual));
  end if;
  workspace_result:=jsonb_build_object(
    'gate_state','PASS','workspace_id',ws.workspace_id,'canonical_resource_id',wb.canonical_resource_id,
    'provider_ref',c->>'provider_ref','repo_ref',ws.repo_ref,'branch_ref',ws.branch_ref,
    'base_commit',ws.base_commit,'access_mode',ws.access_mode,'isolation_mode',ws.isolation_mode
  );

  auth_required:=coalesce((p_authorization_requirement->>'required')::boolean,false);
  if not auth_required then
    auth:=jsonb_build_object('gate_state','PASS','authorization_checked',false,'state','NOT_REQUIRED',
      'note','Qualification is not authorization. No authority was requested for this admission receipt.');
  else
    if coalesce(p_authorization_requirement->>'action','')=''
       or coalesce(p_authorization_requirement->>'resource_kind','')=''
       or coalesce(p_authorization_requirement->>'resource_ref','')='' then
      blockers:=blockers||jsonb_build_array(jsonb_build_object('code','AUTHORIZATION_CONTRACT_INVALID'));
      auth:=jsonb_build_object('gate_state','BLOCKED','authorization_checked',true,'state','INVALID_REQUIREMENT');
    else
      authscope:=coalesce(p_authorization_requirement->'scope','{}'::jsonb)||jsonb_build_object(
        'work_id',p_work_id,'workspace_id',p_workspace_id,'execution_id',p_execution_id,
        'canonical_resource_id',wb.canonical_resource_id,'repo_ref',ws.repo_ref,
        'branch_ref',ws.branch_ref,'canonical_head',ws.base_commit
      );
      authz:=public.world8_authorize_v1(
        p_actor_id,p_authorization_requirement->>'action',p_authorization_requirement->>'resource_kind',
        p_authorization_requirement->>'resource_ref',authscope,
        coalesce(p_authorization_requirement->'conditions','{}'::jsonb),
        coalesce((p_authorization_requirement->>'require_access_identity')::boolean,false),
        nullif(p_authorization_requirement->>'required_assurance',''),
        least(900,greatest(30,p_valid_minutes*60))
      );
      auth:=authz||jsonb_build_object('state',case when authz->>'decision'='ALLOW' then 'AUTHORIZED' else 'DENIED' end,'authorization_checked',true);
      if coalesce(authz->>'decision','DENY')<>'ALLOW' then
        blockers:=blockers||jsonb_build_array(jsonb_build_object('code','AUTHORIZATION_DENIED','details',authz));
      end if;
    end if;
  end if;

  if jsonb_array_length(blockers)>0 then gate:='BLOCKED'; end if;
  payload:=jsonb_build_object(
    'schema','WORLD8_DEV_ADMISSION/0.4','actor_id',p_actor_id,'execution_id',p_execution_id,
    'work_id',p_work_id,'workspace_id',p_workspace_id,'resolved_workspace_id',p_workspace_id,
    'canonical_resource_id',wb.canonical_resource_id,'canonical_head',ws.base_commit,
    'qualification_requirements',coalesce(p_required_qualifications,'[]'::jsonb),'qualification_result',qual,
    'authorization_requirement',coalesce(p_authorization_requirement,'{}'::jsonb),'authorization_result',auth,
    'workspace_result',workspace_result,'academy_entry_receipt_id',er.entry_receipt_id,
    'academy_entry_authority_effect','NONE','blockers',blockers,'gate_state',gate,
    'issued_at',nowv,'expires_at',nowv+make_interval(mins=>p_valid_minutes)
  );
  hashv:=encode(extensions.digest(convert_to(payload::text,'UTF8'),'sha256'),'hex');
  aid:='admission-'||substr(hashv,1,32);
  insert into public.world8_dev_admission_receipts(
    admission_id,world_id,actor_id,execution_id,work_id,workspace_id,
    qualification_requirements,qualification_result,authorization_requirement,
    authorization_result,workspace_result,blockers,gate_state,evidence_refs,issued_at,expires_at,content_hash
  ) values(
    aid,'world-001',p_actor_id,p_execution_id,p_work_id,p_workspace_id,
    coalesce(p_required_qualifications,'[]'::jsonb),qual,coalesce(p_authorization_requirement,'{}'::jsonb),
    auth,workspace_result,blockers,gate,
    jsonb_build_array('work:'||p_work_id,'workspace:'||p_workspace_id,'entry:'||er.entry_receipt_id,
      'canonical-resource:'||wb.canonical_resource_id,'authz:'||coalesce(auth->>'authorization_receipt_id','none')),
    nowv,nowv+make_interval(mins=>p_valid_minutes),hashv
  );
  if gate='PASS' then
    bindhash:=encode(extensions.digest(convert_to(aid||'|'||er.entry_receipt_id,'UTF8'),'sha256'),'hex');
    insert into public.world8_dev_admission_entry_bindings(admission_id,entry_receipt_id,content_hash)
    values(aid,er.entry_receipt_id,bindhash) on conflict(admission_id) do nothing;
  end if;
  return payload||jsonb_build_object('admission_id',aid,'content_hash',hashv);
end$$;

revoke all on function public.world8_dev_admission_check_v4(text,text,text,text,text,jsonb,jsonb,integer)
from public,anon,authenticated;
grant execute on function public.world8_dev_admission_check_v4(text,text,text,text,text,jsonb,jsonb,integer)
to service_role;

-- Lease v5 remains the shared write lease. It consumes Admission/Entry/Recovery evidence
-- and is repository-neutral. Persistent resource enrollment is a separate governed action.

select jsonb_build_object(
  'result','WORLD8_REPO_AWARE_ACADEMY_BRIDGE_V05_MIGRATION_LOADED',
  'resource_enrollment_performed',false,
  'legacy_world8_path_replaced',false
) as bridge_v05_marker;
