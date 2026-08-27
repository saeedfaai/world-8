-- World 8 Academy machine-verified Mason Core Checkride v0.3
-- PASS is derived from governed runtime evidence, not from a declared score.

insert into public.world8_academy_curricula(
  curriculum_id,curriculum_ref,curriculum_version,qualification_kind,qualification_ref,qualification_version,
  rulebase_version_id,min_score,required_refs,recurrent_training_triggers,status,metadata,content_hash,created_by
) values (
  'curriculum-world8-mason-core-v141','MASON_CORE','1.4.1','TYPE_RATING','MASON_CORE','1.4.1',
  'mason-rulebase-v1.4',1.0,
  '["MACHINE:PREFLIGHT_PASS","MACHINE:RULEBASE_MATCH","MACHINE:ACADEMY_SHADOW_CURRENT","MACHINE:WORKSPACE_BASE_FRESH","MACHINE:SCRIBE_PASS","MACHINE:GUARDIAN_ATTACHED","MACHINE:DIAGNOSTIC_SEARCH_CAPTURED"]'::jsonb,
  '["RULEBASE_CHANGE","ARCHITECTURE_CHANGE","AUTHORIZATION_CONTRACT_CHANGE","ACCESS_CONTRACT_CHANGE","GUARDIAN_POLICY_CHANGE"]'::jsonb,
  'FROZEN',
  '{"training_not_authority":true,"qualification_not_authority":true,"machine_verified_required":true,"checkride_contract":"MASON_CORE/2.0"}'::jsonb,
  encode(extensions.digest('MASON_CORE|1.4.1|MASON_CORE/2.0|machine-verified|qualification-not-authority','sha256'),'hex'),
  'service-world8-qualification-authority'
) on conflict(curriculum_ref,curriculum_version) do nothing;

create or replace function public.world8_academy_mason_core_checkride_v2(
  p_subject_actor_id text,
  p_evaluator_actor_id text,
  p_preflight_receipt_id text,
  p_dev_session_id text,
  p_evidence_refs jsonb default '[]'::jsonb,
  p_metadata jsonb default '{}'::jsonb
) returns jsonb
language plpgsql
security definer
set search_path=public,extensions
as $$
declare
  c public.world8_academy_curricula%rowtype;
  pf public.world8_mason_preflight_receipts%rowtype;
  s public.world8_dev_session_liveness%rowtype;
  w public.world8_dev_workspaces%rowtype;
  canonical public.world8_dev_external_resources%rowtype;
  shadow public.world8_code_shadow_manifests%rowtype;
  v_scribe jsonb:='{}'::jsonb;
  v_blockers jsonb:='[]'::jsonb;
  v_checks jsonb:='{}'::jsonb;
  v_guardian_ok boolean:=false;
  v_shadow_ok boolean:=false;
  v_preflight_ok boolean:=false;
  v_rulebase_ok boolean:=false;
  v_workspace_ok boolean:=false;
  v_scribe_ok boolean:=false;
  v_diag_ok boolean:=false;
  v_result text;
  v_score numeric;
  v_now timestamptz:=clock_timestamp();
  v_hash text;
  v_id text;
  v_auto_evidence jsonb:='[]'::jsonb;
begin
  if p_subject_actor_id=p_evaluator_actor_id then raise exception 'CHECKRIDE_SELF_EVALUATION_FORBIDDEN'; end if;
  if p_evaluator_actor_id<>'service-world8-academy-examiner' then raise exception 'ACADEMY_EXAMINER_REQUIRED'; end if;
  if jsonb_typeof(coalesce(p_evidence_refs,'[]'::jsonb))<>'array' then raise exception 'EVIDENCE_REFS_MUST_BE_ARRAY'; end if;
  if not exists(select 1 from public.world8_actor_registry where actor_id=p_subject_actor_id and status='ACTIVE') then raise exception 'ACTIVE_SUBJECT_ACTOR_REQUIRED'; end if;
  if not exists(select 1 from public.world8_actor_registry where actor_id=p_evaluator_actor_id and status='ACTIVE') then raise exception 'ACTIVE_EVALUATOR_ACTOR_REQUIRED'; end if;

  select * into c from public.world8_academy_curricula
  where curriculum_ref='MASON_CORE' and curriculum_version='1.4.1' and status='FROZEN';
  if not found then raise exception 'MASON_CORE_MACHINE_CURRICULUM_NOT_FOUND'; end if;

  select * into pf from public.world8_mason_preflight_receipts where preflight_receipt_id=p_preflight_receipt_id;
  if found then
    v_preflight_ok := pf.actor_ref=p_subject_actor_id and pf.gate_state='PASS' and pf.expires_at>v_now
      and exists(select 1 from jsonb_array_elements_text(coalesce(pf.target_artifact_ids,'[]'::jsonb)) x where x='artifact-world8-academy-v1');
    v_rulebase_ok := pf.rulebase_version_id=c.rulebase_version_id;
    v_diag_ok := pf.diagnostic_search_snapshot is not null and jsonb_typeof(pf.diagnostic_search_snapshot)='object';
  end if;
  if not v_preflight_ok then v_blockers:=v_blockers||jsonb_build_array(jsonb_build_object('code','MACHINE_PREFLIGHT_PASS_REQUIRED')); end if;
  if not v_rulebase_ok then v_blockers:=v_blockers||jsonb_build_array(jsonb_build_object('code','MACHINE_RULEBASE_MATCH_REQUIRED')); end if;
  if not v_diag_ok then v_blockers:=v_blockers||jsonb_build_array(jsonb_build_object('code','MACHINE_DIAGNOSTIC_SEARCH_CAPTURE_REQUIRED')); end if;

  select * into shadow from public.world8_code_shadow_manifests
  where artifact_id='artifact-world8-academy-v1' and status='ACTIVE' and completeness_state='COMPLETE'
  order by shadow_revision desc limit 1;
  if found and found then
    v_shadow_ok := exists(
      select 1 from jsonb_array_elements(coalesce(pf.reviewed_shadow_ids,'[]'::jsonb)) e
      where e->>'shadow_id'=shadow.shadow_id and e->>'content_hash'=shadow.content_hash
    );
  end if;
  if not v_shadow_ok then v_blockers:=v_blockers||jsonb_build_array(jsonb_build_object('code','MACHINE_ACADEMY_SHADOW_CURRENT_REQUIRED')); end if;

  select * into s from public.world8_dev_session_liveness where session_id=p_dev_session_id;
  if not found or s.actor_id<>p_subject_actor_id or s.status<>'ACTIVE' then
    v_blockers:=v_blockers||jsonb_build_array(jsonb_build_object('code','ACTIVE_TRAINING_SESSION_REQUIRED'));
  else
    select * into w from public.world8_dev_workspaces where workspace_id=s.workspace_id and state='ACTIVE';
    select * into canonical from public.world8_dev_external_resources where resource_id='resource-github-world8-canonical' and status='ACTIVE';
    if found then
      v_workspace_ok := w.actor_id=p_subject_actor_id and w.work_id=s.work_id and w.base_commit=coalesce(canonical.metadata->>'canonical_head_commit','');
    end if;
    v_scribe:=public.world8_dev_scribe_guard_v1(s.work_id,p_subject_actor_id,s.source_room);
    v_scribe_ok:=coalesce(v_scribe->>'gate_state','BLOCKED')='PASS';
    v_guardian_ok:=exists(
      select 1 from public.world8_guardian_companion_sessions g
      where g.dev_session_id=p_dev_session_id and g.actor_id=p_subject_actor_id and g.status='ACTIVE'
        and g.guardian_service_id='service-world8-engineering-guardian'
    );
  end if;
  if not v_workspace_ok then v_blockers:=v_blockers||jsonb_build_array(jsonb_build_object('code','MACHINE_WORKSPACE_BASE_FRESH_REQUIRED')); end if;
  if not v_scribe_ok then v_blockers:=v_blockers||jsonb_build_array(jsonb_build_object('code','MACHINE_SCRIBE_PASS_REQUIRED','details',v_scribe)); end if;
  if not v_guardian_ok then v_blockers:=v_blockers||jsonb_build_array(jsonb_build_object('code','MACHINE_GUARDIAN_ATTACHED_REQUIRED')); end if;

  v_result:=case when jsonb_array_length(v_blockers)=0 then 'PASS' else 'FAIL' end;
  v_score:=case when v_result='PASS' then 1.0 else 0.0 end;
  v_checks:=jsonb_build_object(
    'preflight_pass',v_preflight_ok,
    'rulebase_match',v_rulebase_ok,
    'academy_shadow_current',v_shadow_ok,
    'workspace_base_fresh',v_workspace_ok,
    'scribe_pass',v_scribe_ok,
    'guardian_attached',v_guardian_ok,
    'diagnostic_search_captured',v_diag_ok
  );
  v_auto_evidence:=coalesce(p_evidence_refs,'[]'::jsonb)||jsonb_build_array(
    'preflight:'||p_preflight_receipt_id,
    'session:'||p_dev_session_id,
    'shadow:'||coalesce(shadow.shadow_id,'missing'),
    'workspace:'||coalesce(w.workspace_id,'missing'),
    'canonical:'||coalesce(canonical.metadata->>'canonical_head_commit','missing')
  );
  v_hash:=encode(extensions.digest(p_subject_actor_id||'|'||p_evaluator_actor_id||'|'||p_preflight_receipt_id||'|'||p_dev_session_id||'|'||v_result||'|'||v_checks::text||'|'||v_now::text,'sha256'),'hex');
  v_id:='academy-checkride-'||substr(v_hash,1,28);
  insert into public.world8_academy_checkride_receipts(
    checkride_receipt_id,subject_actor_id,evaluator_actor_id,curriculum_id,qualification_kind,qualification_ref,
    qualification_version,result,score,evidence_refs,metadata,content_hash,created_at
  ) values (
    v_id,p_subject_actor_id,p_evaluator_actor_id,c.curriculum_id,c.qualification_kind,c.qualification_ref,
    c.qualification_version,v_result,v_score,v_auto_evidence,
    coalesce(p_metadata,'{}'::jsonb)||jsonb_build_object(
      'authorization_granted',false,
      'machine_verified',true,
      'checkride_contract','MASON_CORE/2.0',
      'checks',v_checks,
      'blockers',v_blockers
    ),v_hash,v_now
  );
  return jsonb_build_object(
    'schema','WORLD8_ACADEMY_CHECKRIDE/2.0',
    'checkride_receipt_id',v_id,
    'subject_actor_id',p_subject_actor_id,
    'result',v_result,
    'score',v_score,
    'checks',v_checks,
    'blockers',v_blockers,
    'qualification_ref',c.qualification_ref,
    'qualification_version',c.qualification_version,
    'machine_verified',true,
    'authorization_granted',false,
    'content_hash',v_hash
  );
end $$;

create or replace function public.world8_academy_issue_license_v2(
  p_checkride_receipt_id text,
  p_issued_by text,
  p_expires_at timestamptz,
  p_metadata jsonb default '{}'::jsonb
) returns jsonb
language plpgsql
security definer
set search_path=public
as $$
declare
  r public.world8_academy_checkride_receipts%rowtype;
  q jsonb;
begin
  select * into r from public.world8_academy_checkride_receipts where checkride_receipt_id=p_checkride_receipt_id;
  if not found then raise exception 'CHECKRIDE_RECEIPT_NOT_FOUND'; end if;
  if r.result<>'PASS' or r.score<>1.0 then raise exception 'MACHINE_VERIFIED_PASS_CHECKRIDE_REQUIRED'; end if;
  if coalesce((r.metadata->>'machine_verified')::boolean,false) is not true or r.metadata->>'checkride_contract'<>'MASON_CORE/2.0' then
    raise exception 'MACHINE_VERIFIED_MASON_CORE_CHECKRIDE_REQUIRED';
  end if;
  if r.qualification_ref<>'MASON_CORE' or r.qualification_version<>'1.4.1' then raise exception 'MASON_CORE_141_REQUIRED'; end if;
  if p_issued_by<>'service-world8-qualification-authority' then raise exception 'QUALIFICATION_AUTHORITY_REQUIRED'; end if;
  if not exists(select 1 from public.world8_actor_registry where actor_id=p_issued_by and status='ACTIVE') then raise exception 'ACTIVE_QUALIFICATION_AUTHORITY_REQUIRED'; end if;
  if p_expires_at is null or p_expires_at<=clock_timestamp() or p_expires_at>clock_timestamp()+interval '7 days' then raise exception 'MASON_CORE_LICENSE_EXPIRY_OUT_OF_RANGE'; end if;
  q:=public.world8_actor_issue_qualification_v1(
    r.subject_actor_id,r.qualification_kind,r.qualification_ref,r.qualification_version,p_issued_by,
    r.evidence_refs||jsonb_build_array('checkride:'||r.checkride_receipt_id),p_expires_at,
    coalesce(p_metadata,'{}'::jsonb)||jsonb_build_object(
      'checkride_receipt_id',r.checkride_receipt_id,
      'checkride_contract','MASON_CORE/2.0',
      'machine_verified',true,
      'authorization_granted',false,
      'recurrent_training_required',true
    )
  );
  return jsonb_build_object(
    'schema','WORLD8_ACADEMY_LICENSE_ISSUE/2.0',
    'checkride_receipt_id',r.checkride_receipt_id,
    'qualification',q,
    'machine_verified',true,
    'authorization_granted',false
  );
end $$;

revoke all on function public.world8_academy_mason_core_checkride_v2(text,text,text,text,jsonb,jsonb) from public,anon,authenticated;
revoke all on function public.world8_academy_issue_license_v2(text,text,timestamptz,jsonb) from public,anon,authenticated;
grant execute on function public.world8_academy_mason_core_checkride_v2(text,text,text,text,jsonb,jsonb) to service_role;
grant execute on function public.world8_academy_issue_license_v2(text,text,timestamptz,jsonb) to service_role;
