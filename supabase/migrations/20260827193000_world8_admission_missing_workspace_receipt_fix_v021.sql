-- World 8 Developer Admission v0.2.1
-- Fixes: unresolved/nonexistent workspace caused FK exception while writing a BLOCKED admission receipt.
-- Safety rule: preserve the requested workspace_id inside the receipt payload/evidence,
-- but persist a workspace foreign key only when an ACTIVE workspace was actually resolved.

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
 v_receipt_workspace_id text:=null;
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
   v_receipt_workspace_id:=null;
   v_blockers:=v_blockers||jsonb_build_array(jsonb_build_object('code','ACTIVE_WORKSPACE_REQUIRED','requested_workspace_id',p_workspace_id));
   v_workspace:=jsonb_build_object('gate_state','BLOCKED','requested_workspace_id',p_workspace_id,'resolved_workspace_id',null);
 else
   v_receipt_workspace_id:=v_ws.workspace_id;
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
 v_payload:=jsonb_build_object(
   'schema','WORLD8_DEV_ADMISSION/0.2.1',
   'actor_id',p_actor_id,
   'execution_id',p_execution_id,
   'work_id',p_work_id,
   'workspace_id',p_workspace_id,
   'resolved_workspace_id',v_receipt_workspace_id,
   'qualification_requirements',coalesce(p_required_qualifications,'[]'::jsonb),
   'qualification_result',v_qual,
   'authorization_requirement',coalesce(p_authorization_requirement,'{}'::jsonb),
   'authorization_result',v_auth,
   'workspace_result',v_workspace,
   'blockers',v_blockers,
   'gate_state',v_gate,
   'issued_at',v_now,
   'expires_at',v_now+make_interval(mins=>p_valid_minutes)
 );
 v_hash:=encode(extensions.digest(v_payload::text,'sha256'),'hex');
 v_id:='admission-'||substr(v_hash,1,32);
 insert into public.world8_dev_admission_receipts(
   admission_id,world_id,actor_id,execution_id,work_id,workspace_id,
   qualification_requirements,qualification_result,authorization_requirement,
   authorization_result,workspace_result,blockers,gate_state,evidence_refs,
   issued_at,expires_at,content_hash
 ) values (
   v_id,'world-001',p_actor_id,p_execution_id,p_work_id,v_receipt_workspace_id,
   coalesce(p_required_qualifications,'[]'::jsonb),v_qual,
   coalesce(p_authorization_requirement,'{}'::jsonb),v_auth,v_workspace,v_blockers,v_gate,
   jsonb_build_array('work:'||p_work_id,'workspace-request:'||coalesce(p_workspace_id,''),'workspace-resolved:'||coalesce(v_receipt_workspace_id,'none'),'authz:'||coalesce(v_auth->>'authorization_receipt_id','none')),
   v_now,v_now+make_interval(mins=>p_valid_minutes),v_hash
 );
 return v_payload||jsonb_build_object('admission_id',v_id,'content_hash',v_hash);
end $$;

comment on function public.world8_dev_admission_check_v2(text,text,text,text,jsonb,jsonb,integer)
is 'Developer Admission v0.2.1: unresolved workspace requests fail closed with a structured BLOCKED receipt while the nullable workspace FK remains NULL; requested workspace identity is preserved in payload/evidence.';
