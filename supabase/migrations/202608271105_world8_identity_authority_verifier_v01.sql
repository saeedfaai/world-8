-- World 8 Identity & Authority Verifier v0.1
-- Work: work-d47f0925ba693b1c8def85d5add0
-- Principle: reuse specialized authority evidence; serialize truth; DENY by default.
-- This migration does NOT create a second identity registry, route-grant system,
-- governance approval system, W2 effect authorization system, or credential store.

create table if not exists public.world8_authority_rules (
  rule_id text primary key,
  world_id text not null default 'world-001',
  rule_key text not null,
  rule_version integer not null check (rule_version > 0),
  subject_kind text not null check (subject_kind in ('ACTOR','PRINCIPAL','ROLE','SERVICE')),
  subject_ref text not null,
  action text not null check (length(btrim(action)) > 0),
  resource_kind text not null check (length(btrim(resource_kind)) > 0),
  resource_ref text not null check (length(btrim(resource_ref)) > 0),
  scope jsonb not null default '{}'::jsonb check (jsonb_typeof(scope)='object'),
  decision text not null check (decision in ('ALLOW','DENY','REVOKE')),
  conditions jsonb not null default '{}'::jsonb check (jsonb_typeof(conditions)='object'),
  valid_from timestamptz not null default clock_timestamp(),
  expires_at timestamptz null,
  evidence_refs jsonb not null default '[]'::jsonb check (jsonb_typeof(evidence_refs)='array'),
  provenance jsonb not null default '{}'::jsonb check (jsonb_typeof(provenance)='object'),
  created_by text not null,
  created_at timestamptz not null default clock_timestamp(),
  content_hash text not null,
  unique(rule_key,rule_version),
  check (expires_at is null or expires_at > valid_from)
);

create index if not exists world8_authority_rules_lookup_idx
  on public.world8_authority_rules(world_id,subject_kind,subject_ref,action,resource_kind,resource_ref,rule_key,rule_version desc);
create index if not exists world8_authority_rules_expiry_idx
  on public.world8_authority_rules(expires_at) where expires_at is not null;

create table if not exists public.world8_authorization_receipts (
  authorization_receipt_id text primary key,
  world_id text not null default 'world-001',
  subject_ref text not null,
  action text not null,
  resource_kind text not null,
  resource_ref text not null,
  request_scope jsonb not null default '{}'::jsonb check (jsonb_typeof(request_scope)='object'),
  request_conditions jsonb not null default '{}'::jsonb check (jsonb_typeof(request_conditions)='object'),
  decision text not null check (decision in ('ALLOW','DENY')),
  reason_code text not null,
  matched_rule_refs jsonb not null default '[]'::jsonb check (jsonb_typeof(matched_rule_refs)='array'),
  identity_evidence_refs jsonb not null default '[]'::jsonb check (jsonb_typeof(identity_evidence_refs)='array'),
  specialized_evidence_refs jsonb not null default '[]'::jsonb check (jsonb_typeof(specialized_evidence_refs)='array'),
  evaluated_at timestamptz not null,
  expires_at timestamptz not null,
  request_hash text not null,
  content_hash text not null,
  check (expires_at > evaluated_at)
);

create index if not exists world8_authorization_receipts_subject_idx
  on public.world8_authorization_receipts(subject_ref,evaluated_at desc);
create index if not exists world8_authorization_receipts_request_idx
  on public.world8_authorization_receipts(request_hash,evaluated_at desc);

create or replace function public.world8_authority_rule_hash_v1()
returns trigger
language plpgsql
security definer
set search_path='public','extensions'
as $$
declare v_payload jsonb;
begin
  v_payload:=jsonb_build_object(
    'schema','WORLD8_AUTHORITY_RULE/1.0',
    'world_id',new.world_id,
    'rule_key',new.rule_key,
    'rule_version',new.rule_version,
    'subject_kind',new.subject_kind,
    'subject_ref',new.subject_ref,
    'action',new.action,
    'resource_kind',new.resource_kind,
    'resource_ref',new.resource_ref,
    'scope',new.scope,
    'decision',new.decision,
    'conditions',new.conditions,
    'valid_from',new.valid_from,
    'expires_at',new.expires_at,
    'evidence_refs',new.evidence_refs,
    'provenance',new.provenance,
    'created_by',new.created_by
  );
  new.content_hash:=encode(extensions.digest(convert_to(v_payload::text,'UTF8'),'sha256'),'hex');
  return new;
end $$;

drop trigger if exists world8_authority_rules_hash_trg on public.world8_authority_rules;
create trigger world8_authority_rules_hash_trg
before insert on public.world8_authority_rules
for each row execute function public.world8_authority_rule_hash_v1();

create or replace function public.world8_prevent_authority_ledger_mutation_v1()
returns trigger
language plpgsql
security definer
set search_path='public'
as $$
begin
  raise exception 'WORLD8_AUTHORITY_LEDGER_APPEND_ONLY';
end $$;

drop trigger if exists world8_authority_rules_append_only_trg on public.world8_authority_rules;
create trigger world8_authority_rules_append_only_trg
before update or delete on public.world8_authority_rules
for each row execute function public.world8_prevent_authority_ledger_mutation_v1();

drop trigger if exists world8_authorization_receipts_append_only_trg on public.world8_authorization_receipts;
create trigger world8_authorization_receipts_append_only_trg
before update or delete on public.world8_authorization_receipts
for each row execute function public.world8_prevent_authority_ledger_mutation_v1();

create or replace function public.world8_authorize_v1(
  p_subject_ref text,
  p_action text,
  p_resource_kind text,
  p_resource_ref text,
  p_scope jsonb default '{}'::jsonb,
  p_conditions jsonb default '{}'::jsonb,
  p_require_access_identity boolean default false,
  p_required_assurance text default null,
  p_valid_seconds integer default 300
) returns jsonb
language plpgsql
security definer
set search_path='public','extensions'
as $$
declare
  v_now timestamptz:=clock_timestamp();
  v_actor public.world8_actor_registry%rowtype;
  v_binding public.world8_access_identity_bindings%rowtype;
  v_identity_refs jsonb:='[]'::jsonb;
  v_specialized_refs jsonb:='[]'::jsonb;
  v_rules jsonb:='[]'::jsonb;
  v_has_deny boolean:=false;
  v_has_allow boolean:=false;
  v_decision text:='DENY';
  v_reason text:=null;
  v_payload jsonb;
  v_request_hash text;
  v_content_hash text;
  v_receipt_id text;
  v_work_id text:=nullif(coalesce(p_scope->>'work_id',''),'');
  v_workspace_id text:=nullif(coalesce(p_scope->>'workspace_id',''),'');
  v_required_rank integer;
  v_actual_rank integer;
  v_latest_decision text;
  v_w2 public.w2_external_effect_authorizations%rowtype;
  v_gov record;
  v_stepup_scope text:=nullif(coalesce(p_conditions->>'owner_step_up_scope',''),'');
begin
  if coalesce(btrim(p_subject_ref),'')='' or coalesce(btrim(p_action),'')='' or
     coalesce(btrim(p_resource_kind),'')='' or coalesce(btrim(p_resource_ref),'')='' then
    raise exception 'AUTHORIZATION_REQUEST_FIELDS_REQUIRED';
  end if;
  if jsonb_typeof(coalesce(p_scope,'{}'::jsonb))<>'object' or jsonb_typeof(coalesce(p_conditions,'{}'::jsonb))<>'object' then
    raise exception 'AUTHORIZATION_SCOPE_CONDITIONS_MUST_BE_OBJECTS';
  end if;
  if p_valid_seconds<30 or p_valid_seconds>900 then raise exception 'AUTHORIZATION_RECEIPT_VALIDITY_OUT_OF_RANGE'; end if;
  if p_required_assurance is not null and p_required_assurance not in ('UNVERIFIED','LOW','MEDIUM','HIGH','ROOT') then
    raise exception 'INVALID_REQUIRED_ASSURANCE';
  end if;

  select * into v_actor from public.world8_actor_registry
  where actor_id=p_subject_ref and status='ACTIVE';
  if not found then
    v_reason:='ACTIVE_ACTOR_REQUIRED';
  else
    v_identity_refs:=v_identity_refs||jsonb_build_array('actor:'||v_actor.actor_id);
  end if;

  if v_reason is null and p_require_access_identity then
    select * into v_binding
    from public.world8_access_identity_bindings b
    where b.actor_ref=p_subject_ref and b.status='ACTIVE'
      and (b.expires_at is null or b.expires_at>v_now)
    order by b.verified_at desc nulls last,b.updated_at desc
    limit 1;
    if not found then
      v_reason:='ACCESS_IDENTITY_BINDING_REQUIRED';
    else
      v_identity_refs:=v_identity_refs||jsonb_build_array('access-binding:'||v_binding.binding_id);
      if p_required_assurance is not null then
        v_required_rank:=case p_required_assurance when 'UNVERIFIED' then 1 when 'LOW' then 2 when 'MEDIUM' then 3 when 'HIGH' then 4 when 'ROOT' then 5 end;
        v_actual_rank:=case v_binding.assurance_class when 'UNVERIFIED' then 1 when 'LOW' then 2 when 'MEDIUM' then 3 when 'HIGH' then 4 when 'ROOT' then 5 else 0 end;
        if v_actual_rank<v_required_rank then v_reason:='ACCESS_ASSURANCE_INSUFFICIENT'; end if;
      end if;
    end if;
  end if;

  if v_reason is null and v_work_id is not null then
    if not exists(select 1 from public.world8_dev_work_items w where w.work_id=v_work_id and w.actor_ref=p_subject_ref) then
      v_reason:='WORK_SCOPE_ACTOR_MISMATCH';
    end if;
  end if;

  if v_reason is null and v_workspace_id is not null then
    if not exists(
      select 1 from public.world8_dev_workspaces ws
      where ws.workspace_id=v_workspace_id and ws.actor_id=p_subject_ref and ws.state='ACTIVE'
        and (v_work_id is null or ws.work_id=v_work_id)
    ) then
      v_reason:='ACTIVE_WORKSPACE_SCOPE_REQUIRED';
    end if;
  end if;

  -- Existing route-grant truth remains authoritative for route use.
  if v_reason is null and p_action='ROUTE_USE' then
    if coalesce(p_scope->>'endpoint_id','')='' or coalesce(p_scope->>'principal_fingerprint','')='' or
       coalesce(p_scope->>'society_id','')='' or coalesce(p_scope->>'role_id','')='' then
      v_reason:='ROUTE_SCOPE_FIELDS_REQUIRED';
    else
      select g.decision into v_latest_decision
      from public.principal_route_grants g
      where g.endpoint_id=p_scope->>'endpoint_id'
        and g.principal_fingerprint=p_scope->>'principal_fingerprint'
        and g.society_id=p_scope->>'society_id'
        and g.role_id=p_scope->>'role_id'
        and g.principal_ref=p_subject_ref
      order by g.grant_seq desc limit 1;
      if coalesce(v_latest_decision,'REVOKE')='GRANT' then
        v_decision:='ALLOW'; v_reason:='ROUTE_GRANT_ALLOW';
        select jsonb_build_array('route-grant:'||g.grant_id) into v_specialized_refs
        from public.principal_route_grants g
        where g.endpoint_id=p_scope->>'endpoint_id'
          and g.principal_fingerprint=p_scope->>'principal_fingerprint'
          and g.society_id=p_scope->>'society_id'
          and g.role_id=p_scope->>'role_id'
          and g.principal_ref=p_subject_ref
        order by g.grant_seq desc limit 1;
      else
        v_reason:='ROUTE_GRANT_MISSING_OR_REVOKED';
      end if;
    end if;
  end if;

  -- Specialized evidence may constrain a general rule; it never silently grants by itself.
  if v_reason is null and coalesce((p_conditions->>'require_world_boot_approved')::boolean,false) then
    select a.decision into v_latest_decision from public.w0_boot_authorizations a
    where a.world_id='world-001' order by a.authorization_seq desc limit 1;
    if coalesce(v_latest_decision,'REVOKE')<>'APPROVE' then v_reason:='WORLD_BOOT_NOT_APPROVED';
    else v_specialized_refs:=v_specialized_refs||jsonb_build_array('w0:latest-approved'); end if;
  end if;

  if v_reason is null and coalesce((p_conditions->>'require_world_running_approved')::boolean,false) then
    select a.decision into v_latest_decision from public.w1_running_authorizations a
    where a.world_id='world-001' order by a.authorization_seq desc limit 1;
    if coalesce(v_latest_decision,'REVOKE')<>'APPROVE' then v_reason:='WORLD_RUNNING_NOT_APPROVED';
    else v_specialized_refs:=v_specialized_refs||jsonb_build_array('w1:latest-approved'); end if;
  end if;

  if v_reason is null and coalesce(p_conditions->>'w2_authorization_id','')<>'' then
    select * into v_w2 from public.w2_external_effect_authorizations where authorization_id=p_conditions->>'w2_authorization_id';
    if not found or v_w2.decision<>'APPROVE' then
      v_reason:='W2_EXTERNAL_EFFECT_APPROVAL_REQUIRED';
    elsif p_resource_kind='TASK' and v_w2.task_id<>p_resource_ref then
      v_reason:='W2_TASK_RESOURCE_MISMATCH';
    else
      v_specialized_refs:=v_specialized_refs||jsonb_build_array('w2:'||v_w2.authorization_id);
    end if;
  end if;

  if v_reason is null and coalesce(p_conditions->>'governance_approval_id','')<>'' then
    select a.approval_id,a.action,c.scope_id,c.status into v_gov
    from public.governance_approvals a join public.governance_challenges c on c.challenge_id=a.challenge_id
    where a.approval_id=p_conditions->>'governance_approval_id';
    if not found or v_gov.action<>p_action or v_gov.scope_id<>p_resource_ref or v_gov.status not in ('APPROVED','CONSUMED') then
      v_reason:='GOVERNANCE_APPROVAL_REQUIRED_OR_MISMATCH';
    else
      v_specialized_refs:=v_specialized_refs||jsonb_build_array('governance-approval:'||v_gov.approval_id);
    end if;
  end if;

  if v_reason is null and v_stepup_scope is not null then
    if not exists(select 1 from public.world8_owner_step_up_grants g where g.principal_ref=p_subject_ref and g.scope=v_stepup_scope and g.expires_at>v_now) then
      v_reason:='OWNER_STEP_UP_REQUIRED';
    else
      select v_specialized_refs||jsonb_build_array('owner-step-up:'||g.grant_id) into v_specialized_refs
      from public.world8_owner_step_up_grants g
      where g.principal_ref=p_subject_ref and g.scope=v_stepup_scope and g.expires_at>v_now
      order by g.expires_at desc limit 1;
    end if;
  end if;

  -- For non-route operations, evaluate the append-only general authority ledger.
  if v_reason is null and p_action<>'ROUTE_USE' then
    with latest as (
      select distinct on (r.rule_key)
        r.rule_id,r.rule_key,r.rule_version,r.decision,r.expires_at
      from public.world8_authority_rules r
      where r.world_id='world-001'
        and r.subject_kind='ACTOR'
        and r.subject_ref=p_subject_ref
        and r.action=p_action
        and r.resource_kind=p_resource_kind
        and r.resource_ref=p_resource_ref
        and coalesce(p_scope,'{}'::jsonb) @> r.scope
        and r.valid_from<=v_now
      order by r.rule_key,r.rule_version desc,r.created_at desc
    ), effective as (
      select * from latest where expires_at is null or expires_at>v_now
    )
    select
      coalesce(jsonb_agg(jsonb_build_object('rule_id',rule_id,'rule_key',rule_key,'version',rule_version,'decision',decision)),'[]'::jsonb),
      coalesce(bool_or(decision in ('DENY','REVOKE')),false),
      coalesce(bool_or(decision='ALLOW'),false)
    into v_rules,v_has_deny,v_has_allow
    from effective;

    if v_has_deny then v_decision:='DENY'; v_reason:='EXPLICIT_DENY_OR_REVOKE';
    elsif v_has_allow then v_decision:='ALLOW'; v_reason:='GENERAL_RULE_ALLOW';
    else v_decision:='DENY'; v_reason:='NO_MATCHING_AUTHORITY_RULE';
    end if;
  end if;

  if v_reason is not null and v_decision<>'ALLOW' then v_decision:='DENY'; end if;

  v_payload:=jsonb_build_object(
    'schema','WORLD8_AUTHORIZATION_RECEIPT/1.0',
    'subject_ref',p_subject_ref,
    'action',p_action,
    'resource_kind',p_resource_kind,
    'resource_ref',p_resource_ref,
    'scope',coalesce(p_scope,'{}'::jsonb),
    'conditions',coalesce(p_conditions,'{}'::jsonb),
    'decision',v_decision,
    'reason_code',v_reason,
    'matched_rules',v_rules,
    'identity_evidence_refs',v_identity_refs,
    'specialized_evidence_refs',v_specialized_refs,
    'evaluated_at',v_now,
    'expires_at',v_now+make_interval(secs=>p_valid_seconds)
  );
  v_request_hash:=encode(extensions.digest(convert_to(jsonb_build_object('subject_ref',p_subject_ref,'action',p_action,'resource_kind',p_resource_kind,'resource_ref',p_resource_ref,'scope',coalesce(p_scope,'{}'::jsonb),'conditions',coalesce(p_conditions,'{}'::jsonb))::text,'UTF8'),'sha256'),'hex');
  v_content_hash:=encode(extensions.digest(convert_to(v_payload::text,'UTF8'),'sha256'),'hex');
  v_receipt_id:='authz-'||substr(v_content_hash,1,32);

  insert into public.world8_authorization_receipts(
    authorization_receipt_id,world_id,subject_ref,action,resource_kind,resource_ref,
    request_scope,request_conditions,decision,reason_code,matched_rule_refs,
    identity_evidence_refs,specialized_evidence_refs,evaluated_at,expires_at,
    request_hash,content_hash
  ) values (
    v_receipt_id,'world-001',p_subject_ref,p_action,p_resource_kind,p_resource_ref,
    coalesce(p_scope,'{}'::jsonb),coalesce(p_conditions,'{}'::jsonb),v_decision,v_reason,v_rules,
    v_identity_refs,v_specialized_refs,v_now,v_now+make_interval(secs=>p_valid_seconds),
    v_request_hash,v_content_hash
  );

  return v_payload||jsonb_build_object(
    'authorization_receipt_id',v_receipt_id,
    'authorization_checked',true,
    'gate_state',case when v_decision='ALLOW' then 'PASS' else 'BLOCKED' end,
    'request_hash',v_request_hash,
    'content_hash',v_content_hash
  );
end $$;

create or replace function public.world8_dev_admission_check_v2(
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
 v_authz jsonb:='{}'::jsonb;
 v_auth_scope jsonb:='{}'::jsonb;
 v_workspace jsonb:='{}'::jsonb;
 v_blockers jsonb:='[]'::jsonb;
 v_gate text:='PASS';
 v_auth_required boolean:=false;
 v_payload jsonb;
 v_hash text;
 v_id text;
begin
 if p_valid_minutes<5 or p_valid_minutes>240 then raise exception 'ADMISSION_VALIDITY_OUT_OF_RANGE'; end if;
 if jsonb_typeof(coalesce(p_required_qualifications,'[]'::jsonb))<>'array' then raise exception 'QUALIFICATIONS_MUST_BE_ARRAY'; end if;
 if jsonb_typeof(coalesce(p_authorization_requirement,'{}'::jsonb))<>'object' then raise exception 'AUTHORIZATION_REQUIREMENT_MUST_BE_OBJECT'; end if;

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
 if not v_auth_required then
   v_auth:=jsonb_build_object('gate_state','PASS','authorization_checked',false,'state','NOT_REQUIRED','note','Qualification is not authorization. No authority was requested for this admission receipt.');
 else
   if coalesce(p_authorization_requirement->>'action','')='' or coalesce(p_authorization_requirement->>'resource_kind','')='' or coalesce(p_authorization_requirement->>'resource_ref','')='' then
     v_blockers:=v_blockers||jsonb_build_array(jsonb_build_object('code','AUTHORIZATION_CONTRACT_INVALID'));
     v_auth:=jsonb_build_object('gate_state','BLOCKED','authorization_checked',true,'state','INVALID_REQUIREMENT');
   else
     v_auth_scope:=coalesce(p_authorization_requirement->'scope','{}'::jsonb)||jsonb_build_object('work_id',p_work_id,'workspace_id',p_workspace_id);
     v_authz:=public.world8_authorize_v1(
       p_actor_id,
       p_authorization_requirement->>'action',
       p_authorization_requirement->>'resource_kind',
       p_authorization_requirement->>'resource_ref',
       v_auth_scope,
       coalesce(p_authorization_requirement->'conditions','{}'::jsonb),
       coalesce((p_authorization_requirement->>'require_access_identity')::boolean,false),
       nullif(p_authorization_requirement->>'required_assurance',''),
       least(900,greatest(30,p_valid_minutes*60))
     );
     v_auth:=v_authz||jsonb_build_object(
       'state',case when v_authz->>'decision'='ALLOW' then 'AUTHORIZED' else 'DENIED' end,
       'authorization_checked',true
     );
     if coalesce(v_authz->>'decision','DENY')<>'ALLOW' then
       v_blockers:=v_blockers||jsonb_build_array(jsonb_build_object('code','AUTHORIZATION_DENIED','details',v_authz));
     end if;
   end if;
 end if;

 if jsonb_array_length(v_blockers)>0 then v_gate:='BLOCKED'; end if;
 v_payload:=jsonb_build_object('schema','WORLD8_DEV_ADMISSION/0.2','actor_id',p_actor_id,'execution_id',p_execution_id,'work_id',p_work_id,'workspace_id',p_workspace_id,'qualification_requirements',coalesce(p_required_qualifications,'[]'::jsonb),'qualification_result',v_qual,'authorization_requirement',coalesce(p_authorization_requirement,'{}'::jsonb),'authorization_result',v_auth,'workspace_result',v_workspace,'blockers',v_blockers,'gate_state',v_gate,'issued_at',v_now,'expires_at',v_now+make_interval(mins=>p_valid_minutes));
 v_hash:=encode(extensions.digest(v_payload::text,'sha256'),'hex');
 v_id:='admission-'||substr(v_hash,1,32);
 insert into public.world8_dev_admission_receipts(admission_id,world_id,actor_id,execution_id,work_id,workspace_id,qualification_requirements,qualification_result,authorization_requirement,authorization_result,workspace_result,blockers,gate_state,evidence_refs,issued_at,expires_at,content_hash)
 values(v_id,'world-001',p_actor_id,p_execution_id,p_work_id,p_workspace_id,coalesce(p_required_qualifications,'[]'::jsonb),v_qual,coalesce(p_authorization_requirement,'{}'::jsonb),v_auth,v_workspace,v_blockers,v_gate,jsonb_build_array('work:'||p_work_id,'workspace:'||coalesce(p_workspace_id,''),'authz:'||coalesce(v_auth->>'authorization_receipt_id','none')),v_now,v_now+make_interval(mins=>p_valid_minutes),v_hash);
 return v_payload||jsonb_build_object('admission_id',v_id,'content_hash',v_hash);
end $$;

-- Close the staged authorization bypass after verifier v0.1 is installed.
create or replace function public.world8_dev_acquire_lease_v2(
 p_work_id text,
 p_artifact_id text,
 p_holder_ref text,
 p_source_room text,
 p_mode text,
 p_ttl_seconds integer,
 p_admission_id text,
 p_require_authorization boolean default true
) returns jsonb
language plpgsql security definer set search_path='public'
as $$
declare
 v_adm public.world8_dev_admission_receipts%rowtype;
 v_ws public.world8_dev_workspaces%rowtype;
 v_lease jsonb;
 v_lease_id text;
 v_auth_checked boolean:=false;
 v_auth_gate text;
begin
 if not p_require_authorization then
   raise exception 'AUTHORIZATION_BYPASS_CLOSED_USE_ADMISSION_V2_AND_LEASE_V3';
 end if;
 select * into v_adm from public.world8_dev_admission_receipts where admission_id=p_admission_id;
 if not found then raise exception 'DEVELOPER_ADMISSION_REQUIRED'; end if;
 if v_adm.actor_id<>p_holder_ref then raise exception 'ADMISSION_ACTOR_MISMATCH'; end if;
 if v_adm.work_id<>p_work_id then raise exception 'ADMISSION_WORK_MISMATCH'; end if;
 if v_adm.gate_state<>'PASS' then raise exception 'DEVELOPER_ADMISSION_BLOCKED'; end if;
 if v_adm.expires_at<=clock_timestamp() then raise exception 'DEVELOPER_ADMISSION_EXPIRED'; end if;
 select * into v_ws from public.world8_dev_workspaces where workspace_id=v_adm.workspace_id and state='ACTIVE';
 if not found then raise exception 'ACTIVE_ADMISSION_WORKSPACE_REQUIRED'; end if;
 if v_ws.work_id<>p_work_id or v_ws.actor_id<>p_holder_ref then raise exception 'ADMISSION_WORKSPACE_MISMATCH'; end if;
 if p_mode in ('SHARED_WRITE','EXCLUSIVE_WRITE') and v_ws.access_mode<>'WRITE' then raise exception 'WRITE_WORKSPACE_REQUIRED'; end if;
 v_auth_gate:=coalesce(v_adm.authorization_result->>'gate_state','BLOCKED');
 v_auth_checked:=coalesce((v_adm.authorization_result->>'authorization_checked')::boolean,false);
 if v_auth_gate<>'PASS' or not v_auth_checked then raise exception 'WRITE_AUTHORIZATION_EVIDENCE_REQUIRED'; end if;
 v_lease:=public.world8_dev_acquire_lease_v1(p_work_id,p_artifact_id,p_holder_ref,p_source_room,p_mode,p_ttl_seconds);
 v_lease_id:=v_lease->>'lease_id';
 update public.world8_dev_leases
 set metadata=coalesce(metadata,'{}'::jsonb)||jsonb_build_object('admission_id',p_admission_id,'workspace_id',v_adm.workspace_id,'authorization_required',true,'authorization_checked',v_auth_checked,'authorization_receipt_id',v_adm.authorization_result->>'authorization_receipt_id','admission_schema','WORLD8_DEV_ADMISSION/0.2')
 where lease_id=v_lease_id;
 return v_lease||jsonb_build_object('admission_id',p_admission_id,'workspace_id',v_adm.workspace_id,'authorization_required',true,'authorization_checked',v_auth_checked,'authorization_receipt_id',v_adm.authorization_result->>'authorization_receipt_id','schema','WORLD8_DEV_LEASE/2.1');
end $$;

create or replace function public.world8_dev_acquire_lease_v3(
 p_work_id text,
 p_artifact_id text,
 p_holder_ref text,
 p_source_room text,
 p_mode text,
 p_ttl_seconds integer,
 p_admission_id text
) returns jsonb
language plpgsql security definer set search_path='public'
as $$
begin
 return public.world8_dev_acquire_lease_v2(p_work_id,p_artifact_id,p_holder_ref,p_source_room,p_mode,p_ttl_seconds,p_admission_id,true)
   ||jsonb_build_object('schema','WORLD8_DEV_LEASE/3.0');
end $$;

revoke all on table public.world8_authority_rules from public,anon,authenticated;
revoke all on table public.world8_authorization_receipts from public,anon,authenticated;
revoke all on function public.world8_authorize_v1(text,text,text,text,jsonb,jsonb,boolean,text,integer) from public,anon,authenticated;
grant execute on function public.world8_authorize_v1(text,text,text,text,jsonb,jsonb,boolean,text,integer) to service_role;
revoke all on function public.world8_dev_admission_check_v2(text,text,text,text,jsonb,jsonb,integer) from public,anon,authenticated;
grant execute on function public.world8_dev_admission_check_v2(text,text,text,text,jsonb,jsonb,integer) to service_role;
revoke all on function public.world8_dev_acquire_lease_v3(text,text,text,text,text,integer,text) from public,anon,authenticated;
grant execute on function public.world8_dev_acquire_lease_v3(text,text,text,text,text,integer,text) to service_role;

comment on table public.world8_authority_rules is 'Append-only general authority policy ledger. Specialized route/W0/W1/W2/governance stores remain authoritative in their own domains and are not copied here.';
comment on table public.world8_authorization_receipts is 'Immutable deterministic authorization decision receipts for World 8 unified verifier v0.1.';
comment on function public.world8_authorize_v1(text,text,text,text,jsonb,jsonb,boolean,text,integer) is 'Unified verifier facade: active Actor + optional access identity + Work/Workspace binding + specialized evidence predicates + append-only general rules; deny by default.';
