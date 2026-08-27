-- World 8 Identity & Authority Verifier v0.1.1
-- Security repair after runtime tests of v0.1.
-- Fixes: rule conditions ignored; ROUTE_USE skipped later conditions; request_hash incomplete.

create or replace function public.world8_authorize_v1(
  p_subject_ref text,p_action text,p_resource_kind text,p_resource_ref text,
  p_scope jsonb default '{}'::jsonb,p_conditions jsonb default '{}'::jsonb,
  p_require_access_identity boolean default false,p_required_assurance text default null,p_valid_seconds integer default 300
) returns jsonb
language plpgsql security definer set search_path='public','extensions' as $$
declare
  v_now timestamptz:=clock_timestamp();
  v_actor public.world8_actor_registry%rowtype;
  v_binding public.world8_access_identity_bindings%rowtype;
  v_identity_refs jsonb:='[]'::jsonb; v_specialized_refs jsonb:='[]'::jsonb; v_rules jsonb:='[]'::jsonb;
  v_has_deny boolean:=false; v_has_allow boolean:=false; v_decision text:='DENY'; v_reason text:=null;
  v_route_allow boolean:=false;
  v_payload jsonb; v_request_hash text; v_content_hash text; v_receipt_id text;
  v_work_id text:=nullif(coalesce(p_scope->>'work_id',''),'');
  v_workspace_id text:=nullif(coalesce(p_scope->>'workspace_id',''),'');
  v_required_rank integer; v_actual_rank integer; v_latest_decision text;
  v_w2 public.w2_external_effect_authorizations%rowtype; v_gov record;
  v_stepup_scope text:=nullif(coalesce(p_conditions->>'owner_step_up_scope',''),'');
begin
  if coalesce(btrim(p_subject_ref),'')='' or coalesce(btrim(p_action),'')='' or coalesce(btrim(p_resource_kind),'')='' or coalesce(btrim(p_resource_ref),'')='' then raise exception 'AUTHORIZATION_REQUEST_FIELDS_REQUIRED'; end if;
  if jsonb_typeof(coalesce(p_scope,'{}'::jsonb))<>'object' or jsonb_typeof(coalesce(p_conditions,'{}'::jsonb))<>'object' then raise exception 'AUTHORIZATION_SCOPE_CONDITIONS_MUST_BE_OBJECTS'; end if;
  if p_valid_seconds<30 or p_valid_seconds>900 then raise exception 'AUTHORIZATION_RECEIPT_VALIDITY_OUT_OF_RANGE'; end if;
  if p_required_assurance is not null and p_required_assurance not in ('UNVERIFIED','LOW','MEDIUM','HIGH','ROOT') then raise exception 'INVALID_REQUIRED_ASSURANCE'; end if;

  select * into v_actor from public.world8_actor_registry where actor_id=p_subject_ref and status='ACTIVE';
  if not found then v_reason:='ACTIVE_ACTOR_REQUIRED'; else v_identity_refs:=v_identity_refs||jsonb_build_array('actor:'||v_actor.actor_id); end if;

  if v_reason is null and p_require_access_identity then
    select * into v_binding from public.world8_access_identity_bindings b
    where b.actor_ref=p_subject_ref and b.status='ACTIVE' and (b.expires_at is null or b.expires_at>v_now)
    order by b.verified_at desc nulls last,b.updated_at desc limit 1;
    if not found then v_reason:='ACCESS_IDENTITY_BINDING_REQUIRED';
    else
      v_identity_refs:=v_identity_refs||jsonb_build_array('access-binding:'||v_binding.binding_id);
      if p_required_assurance is not null then
        v_required_rank:=case p_required_assurance when 'UNVERIFIED' then 1 when 'LOW' then 2 when 'MEDIUM' then 3 when 'HIGH' then 4 when 'ROOT' then 5 end;
        v_actual_rank:=case v_binding.assurance_class when 'UNVERIFIED' then 1 when 'LOW' then 2 when 'MEDIUM' then 3 when 'HIGH' then 4 when 'ROOT' then 5 else 0 end;
        if v_actual_rank<v_required_rank then v_reason:='ACCESS_ASSURANCE_INSUFFICIENT'; end if;
      end if;
    end if;
  end if;

  if v_reason is null and v_work_id is not null and not exists(select 1 from public.world8_dev_work_items w where w.work_id=v_work_id and w.actor_ref=p_subject_ref) then v_reason:='WORK_SCOPE_ACTOR_MISMATCH'; end if;
  if v_reason is null and v_workspace_id is not null and not exists(select 1 from public.world8_dev_workspaces ws where ws.workspace_id=v_workspace_id and ws.actor_id=p_subject_ref and ws.state='ACTIVE' and (v_work_id is null or ws.work_id=v_work_id)) then v_reason:='ACTIVE_WORKSPACE_SCOPE_REQUIRED'; end if;

  if v_reason is null and p_action='ROUTE_USE' then
    if coalesce(p_scope->>'endpoint_id','')='' or coalesce(p_scope->>'principal_fingerprint','')='' or coalesce(p_scope->>'society_id','')='' or coalesce(p_scope->>'role_id','')='' then v_reason:='ROUTE_SCOPE_FIELDS_REQUIRED';
    else
      select g.decision into v_latest_decision from public.principal_route_grants g
      where g.endpoint_id=p_scope->>'endpoint_id' and g.principal_fingerprint=p_scope->>'principal_fingerprint' and g.society_id=p_scope->>'society_id' and g.role_id=p_scope->>'role_id' and g.principal_ref=p_subject_ref order by g.grant_seq desc limit 1;
      if coalesce(v_latest_decision,'REVOKE')='GRANT' then
        v_route_allow:=true;
        select jsonb_build_array('route-grant:'||g.grant_id) into v_specialized_refs from public.principal_route_grants g
        where g.endpoint_id=p_scope->>'endpoint_id' and g.principal_fingerprint=p_scope->>'principal_fingerprint' and g.society_id=p_scope->>'society_id' and g.role_id=p_scope->>'role_id' and g.principal_ref=p_subject_ref order by g.grant_seq desc limit 1;
      else v_reason:='ROUTE_GRANT_MISSING_OR_REVOKED'; end if;
    end if;
  end if;

  if v_reason is null and coalesce((p_conditions->>'require_world_boot_approved')::boolean,false) then
    select a.decision into v_latest_decision from public.w0_boot_authorizations a where a.world_id='world-001' order by a.authorization_seq desc limit 1;
    if coalesce(v_latest_decision,'REVOKE')<>'APPROVE' then v_reason:='WORLD_BOOT_NOT_APPROVED'; else v_specialized_refs:=v_specialized_refs||jsonb_build_array('w0:latest-approved'); end if;
  end if;
  if v_reason is null and coalesce((p_conditions->>'require_world_running_approved')::boolean,false) then
    select a.decision into v_latest_decision from public.w1_running_authorizations a where a.world_id='world-001' order by a.authorization_seq desc limit 1;
    if coalesce(v_latest_decision,'REVOKE')<>'APPROVE' then v_reason:='WORLD_RUNNING_NOT_APPROVED'; else v_specialized_refs:=v_specialized_refs||jsonb_build_array('w1:latest-approved'); end if;
  end if;
  if v_reason is null and coalesce(p_conditions->>'w2_authorization_id','')<>'' then
    select * into v_w2 from public.w2_external_effect_authorizations where authorization_id=p_conditions->>'w2_authorization_id';
    if not found or v_w2.decision<>'APPROVE' then v_reason:='W2_EXTERNAL_EFFECT_APPROVAL_REQUIRED';
    elsif p_resource_kind='TASK' and v_w2.task_id<>p_resource_ref then v_reason:='W2_TASK_RESOURCE_MISMATCH';
    else v_specialized_refs:=v_specialized_refs||jsonb_build_array('w2:'||v_w2.authorization_id); end if;
  end if;
  if v_reason is null and coalesce(p_conditions->>'governance_approval_id','')<>'' then
    select a.approval_id,a.action,c.scope_id,c.status into v_gov from public.governance_approvals a join public.governance_challenges c on c.challenge_id=a.challenge_id where a.approval_id=p_conditions->>'governance_approval_id';
    if not found or v_gov.action<>p_action or v_gov.scope_id<>p_resource_ref or v_gov.status not in ('APPROVED','CONSUMED') then v_reason:='GOVERNANCE_APPROVAL_REQUIRED_OR_MISMATCH';
    else v_specialized_refs:=v_specialized_refs||jsonb_build_array('governance-approval:'||v_gov.approval_id); end if;
  end if;
  if v_reason is null and v_stepup_scope is not null then
    if not exists(select 1 from public.world8_owner_step_up_grants g where g.principal_ref=p_subject_ref and g.scope=v_stepup_scope and g.expires_at>v_now) then v_reason:='OWNER_STEP_UP_REQUIRED';
    else select v_specialized_refs||jsonb_build_array('owner-step-up:'||g.grant_id) into v_specialized_refs from public.world8_owner_step_up_grants g where g.principal_ref=p_subject_ref and g.scope=v_stepup_scope and g.expires_at>v_now order by g.expires_at desc limit 1; end if;
  end if;

  if v_reason is null and p_action<>'ROUTE_USE' then
    with latest as (
      select distinct on (r.rule_key) r.rule_id,r.rule_key,r.rule_version,r.subject_kind,r.decision,r.expires_at
      from public.world8_authority_rules r
      where r.world_id='world-001'
        and ((r.subject_kind='ACTOR' and r.subject_ref=p_subject_ref)
          or (r.subject_kind='PRINCIPAL' and r.subject_ref=p_subject_ref)
          or (r.subject_kind='SERVICE' and v_actor.actor_kind='SERVICE' and r.subject_ref=p_subject_ref))
        and r.action=p_action and r.resource_kind=p_resource_kind and r.resource_ref=p_resource_ref
        and coalesce(p_scope,'{}'::jsonb) @> r.scope
        and coalesce(p_conditions,'{}'::jsonb) @> r.conditions
        and r.valid_from<=v_now
      order by r.rule_key,r.rule_version desc,r.created_at desc
    ), effective as (select * from latest where expires_at is null or expires_at>v_now)
    select coalesce(jsonb_agg(jsonb_build_object('rule_id',rule_id,'rule_key',rule_key,'version',rule_version,'subject_kind',subject_kind,'decision',decision)),'[]'::jsonb),coalesce(bool_or(decision in ('DENY','REVOKE')),false),coalesce(bool_or(decision='ALLOW'),false)
    into v_rules,v_has_deny,v_has_allow from effective;
    if v_has_deny then v_decision:='DENY'; v_reason:='EXPLICIT_DENY_OR_REVOKE'; elsif v_has_allow then v_decision:='ALLOW'; v_reason:='GENERAL_RULE_ALLOW'; else v_decision:='DENY'; v_reason:='NO_MATCHING_AUTHORITY_RULE'; end if;
  elsif v_reason is null and p_action='ROUTE_USE' and v_route_allow then
    v_decision:='ALLOW'; v_reason:='ROUTE_GRANT_ALLOW';
  end if;

  if v_decision<>'ALLOW' then v_decision:='DENY'; end if;
  v_payload:=jsonb_build_object('schema','WORLD8_AUTHORIZATION_RECEIPT/1.1','subject_ref',p_subject_ref,'action',p_action,'resource_kind',p_resource_kind,'resource_ref',p_resource_ref,'scope',coalesce(p_scope,'{}'::jsonb),'conditions',coalesce(p_conditions,'{}'::jsonb),'require_access_identity',p_require_access_identity,'required_assurance',p_required_assurance,'decision',v_decision,'reason_code',v_reason,'matched_rules',v_rules,'identity_evidence_refs',v_identity_refs,'specialized_evidence_refs',v_specialized_refs,'evaluated_at',v_now,'expires_at',v_now+make_interval(secs=>p_valid_seconds));
  v_request_hash:=encode(extensions.digest(convert_to(jsonb_build_object('subject_ref',p_subject_ref,'action',p_action,'resource_kind',p_resource_kind,'resource_ref',p_resource_ref,'scope',coalesce(p_scope,'{}'::jsonb),'conditions',coalesce(p_conditions,'{}'::jsonb),'require_access_identity',p_require_access_identity,'required_assurance',p_required_assurance,'valid_seconds',p_valid_seconds)::text,'UTF8'),'sha256'),'hex');
  v_content_hash:=encode(extensions.digest(convert_to(v_payload::text,'UTF8'),'sha256'),'hex');
  v_receipt_id:='authz-'||substr(v_content_hash,1,32);
  insert into public.world8_authorization_receipts(authorization_receipt_id,world_id,subject_ref,action,resource_kind,resource_ref,request_scope,request_conditions,decision,reason_code,matched_rule_refs,identity_evidence_refs,specialized_evidence_refs,evaluated_at,expires_at,request_hash,content_hash)
  values(v_receipt_id,'world-001',p_subject_ref,p_action,p_resource_kind,p_resource_ref,coalesce(p_scope,'{}'::jsonb),coalesce(p_conditions,'{}'::jsonb),v_decision,v_reason,v_rules,v_identity_refs,v_specialized_refs,v_now,v_now+make_interval(secs=>p_valid_seconds),v_request_hash,v_content_hash);
  return v_payload||jsonb_build_object('authorization_receipt_id',v_receipt_id,'authorization_checked',true,'gate_state',case when v_decision='ALLOW' then 'PASS' else 'BLOCKED' end,'request_hash',v_request_hash,'content_hash',v_content_hash);
end $$;
