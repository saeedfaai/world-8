-- World 8 Academy Engineering Entry Gateway v0.4
-- REVIEWED CODE CANDIDATE / NOT APPLIED / NOT DEPLOYED
-- TRAINING != QUALIFICATION != AUTHORITY. Academy Entry has authority_effect NONE.

create table if not exists public.world8_academy_coding_entry_receipts(
 entry_receipt_id text primary key, world_id text not null default 'world-001',
 actor_id text not null, execution_id text not null, work_id text not null,
 workspace_id text not null, dev_session_id text not null, preflight_receipt_id text not null,
 qualification_id text not null, canonical_head text not null, academy_shadow_id text not null,
 guardian_companion_id text not null, checkpoint_id text not null,
 context_binding jsonb not null check(jsonb_typeof(context_binding)='object'),
 gate_state text not null check(gate_state='PASS'), authority_effect text not null default 'NONE' check(authority_effect='NONE'),
 semantic_hash text not null, content_hash text not null, issued_at timestamptz not null,
 expires_at timestamptz not null check(expires_at>issued_at), created_at timestamptz not null default clock_timestamp()
);
create unique index if not exists world8_academy_entry_identity_uq on public.world8_academy_coding_entry_receipts(execution_id,work_id,workspace_id);

create table if not exists public.world8_dev_prewrite_recovery_receipts(
 recovery_receipt_id text primary key, world_id text not null default 'world-001', entry_receipt_id text not null,
 actor_id text not null, execution_id text not null, work_id text not null, workspace_id text not null,
 recovery_class text not null check(recovery_class in('CODE_ONLY','DB_TOUCHING')), canonical_head text not null,
 checkpoint_id text not null, runtime_snapshot_id text, restore_strategy_ref text,
 evidence_refs jsonb not null default '[]'::jsonb check(jsonb_typeof(evidence_refs)='array'),
 authority_effect text not null default 'NONE' check(authority_effect='NONE'), semantic_hash text not null unique,
 content_hash text not null, issued_at timestamptz not null, expires_at timestamptz not null check(expires_at>issued_at),
 created_at timestamptz not null default clock_timestamp(),
 check(recovery_class='CODE_ONLY' or (runtime_snapshot_id is not null and length(trim(coalesce(restore_strategy_ref,'')))>0))
);

create table if not exists public.world8_dev_admission_entry_bindings(
 admission_id text primary key, entry_receipt_id text not null, content_hash text not null,
 created_at timestamptz not null default clock_timestamp()
);

create or replace function public.world8_academy_coding_entry_issue_v1(
 p_actor_id text,p_execution_id text,p_work_id text,p_workspace_id text,p_dev_session_id text,
 p_preflight_receipt_id text,p_qualification_id text,p_mission_accepted boolean,p_valid_minutes integer default 15,
 p_evidence_refs jsonb default '[]'::jsonb
) returns jsonb language plpgsql security definer set search_path=public,extensions as $$
declare v_now timestamptz:=clock_timestamp(); e public.world8_actor_executions%rowtype; w public.world8_dev_work_items%rowtype;
 ws public.world8_dev_workspaces%rowtype; s public.world8_dev_session_liveness%rowtype; pf public.world8_mason_preflight_receipts%rowtype;
 q public.world8_actor_qualifications%rowtype; g public.world8_guardian_companion_sessions%rowtype;
 c public.world8_dev_external_resources%rowtype; sh public.world8_code_shadow_manifests%rowtype;
 cp public.world8_dev_session_checkpoints%rowtype; old public.world8_academy_coding_entry_receipts%rowtype;
 v_context jsonb; v_semantic jsonb; v_semantic_hash text; v_content_hash text; v_id text;
begin
 if p_valid_minutes<5 or p_valid_minutes>60 then raise exception 'ACADEMY_ENTRY_VALIDITY_OUT_OF_RANGE'; end if;
 if p_mission_accepted is distinct from true then raise exception 'ACADEMY_MISSION_ACCEPTANCE_REQUIRED'; end if;
 select * into e from public.world8_actor_executions where execution_id=p_execution_id and actor_id=p_actor_id and state='ACTIVE';
 if not found then raise exception 'ACADEMY_ENTRY_ACTIVE_EXECUTION_REQUIRED'; end if;
 select * into w from public.world8_dev_work_items where work_id=p_work_id and actor_ref=p_actor_id;
 if not found or coalesce(w.goal,'')='' then raise exception 'ACADEMY_ENTRY_WORK_REQUIRED'; end if;
 select * into ws from public.world8_dev_workspaces where workspace_id=p_workspace_id and actor_id=p_actor_id and work_id=p_work_id and state='ACTIVE' and access_mode='WRITE';
 if not found or lower(ws.branch_ref) in('main','master') then raise exception 'ACADEMY_ENTRY_ACTIVE_WRITE_WORKSPACE_REQUIRED'; end if;
 select * into c from public.world8_dev_external_resources where resource_id='resource-github-world8-canonical' and status='ACTIVE';
 if not found or ws.base_commit<>coalesce(c.metadata->>'canonical_head_commit','') then raise exception 'ACADEMY_ENTRY_STALE_CANONICAL_BASE'; end if;
 select * into s from public.world8_dev_session_liveness where session_id=p_dev_session_id and actor_id=p_actor_id and execution_id=p_execution_id and work_id=p_work_id and workspace_id=p_workspace_id and status='ACTIVE';
 if not found then raise exception 'ACADEMY_ENTRY_SESSION_BINDING_MISMATCH'; end if;
 select * into pf from public.world8_mason_preflight_receipts where preflight_receipt_id=p_preflight_receipt_id and actor_ref=p_actor_id and gate_state='PASS' and expires_at>v_now;
 if not found or jsonb_typeof(pf.now_snapshot)<>'object' or jsonb_typeof(pf.inbox_snapshot)<>'array' or jsonb_typeof(pf.attention_snapshot)<>'array' or jsonb_typeof(pf.access_snapshot)<>'object' or jsonb_typeof(pf.continuity_sync_snapshot)<>'object' or jsonb_typeof(pf.diagnostic_search_snapshot)<>'object' then raise exception 'ACADEMY_ENTRY_CONTEXT_SNAPSHOT_INCOMPLETE'; end if;
 select * into q from public.world8_actor_qualifications where qualification_id=p_qualification_id and actor_id=p_actor_id and qualification_ref='MASON_CORE' and qualification_version='1.4.1' and status='ACTIVE' and valid_from<=v_now and expires_at>v_now;
 if not found then raise exception 'ACADEMY_ENTRY_CURRENT_MASON_CORE_QUALIFICATION_REQUIRED'; end if;
 select * into sh from public.world8_code_shadow_manifests where artifact_id='artifact-world8-academy-v1' and status='ACTIVE' and completeness_state='COMPLETE' order by shadow_revision desc limit 1;
 if not found then raise exception 'ACADEMY_ENTRY_CURRENT_ACADEMY_SHADOW_REQUIRED'; end if;
 select * into g from public.world8_guardian_companion_sessions where dev_session_id=p_dev_session_id and actor_id=p_actor_id and execution_id=p_execution_id and workspace_id=p_workspace_id and guardian_service_id='service-world8-engineering-guardian' and status='ACTIVE' order by updated_at desc limit 1;
 if not found or g.authority_mode<>'ADVISORY_ONLY' then raise exception 'ACADEMY_ENTRY_GUARDIAN_REQUIRED'; end if;
 select * into cp from public.world8_dev_session_checkpoints where session_id=p_dev_session_id and actor_id=p_actor_id and work_id=p_work_id and workspace_id=p_workspace_id order by created_at desc limit 1;
 if not found or coalesce(cp.next_safe_action,'')='' then raise exception 'ACADEMY_ENTRY_CHECKPOINT_REQUIRED'; end if;
 v_context:=jsonb_build_object('architecture_ref',pf.architecture_ref,'inbox_snapshot',pf.inbox_snapshot,'attention_snapshot',pf.attention_snapshot,'access_snapshot',pf.access_snapshot,'continuity_sync_snapshot',pf.continuity_sync_snapshot,'diagnostic_search_snapshot',pf.diagnostic_search_snapshot,'role_ref',s.metadata->>'role');
 v_semantic:=jsonb_build_object('schema','WORLD8_ACADEMY_CODING_ENTRY/0.4','actor_id',p_actor_id,'execution_id',p_execution_id,'work_id',p_work_id,'workspace_id',p_workspace_id,'dev_session_id',p_dev_session_id,'preflight_receipt_id',p_preflight_receipt_id,'qualification_id',p_qualification_id,'canonical_head',ws.base_commit,'academy_shadow_id',sh.shadow_id,'guardian_companion_id',g.companion_id,'checkpoint_id',cp.checkpoint_id,'context_binding',v_context,'authority_effect','NONE');
 v_semantic_hash:=encode(extensions.digest(convert_to(v_semantic::text,'UTF8'),'sha256'),'hex');
 select * into old from public.world8_academy_coding_entry_receipts where execution_id=p_execution_id and work_id=p_work_id and workspace_id=p_workspace_id;
 if found then
   if old.semantic_hash=v_semantic_hash and old.expires_at>v_now then return jsonb_build_object('schema','WORLD8_ACADEMY_CODING_ENTRY/0.4','entry_receipt_id',old.entry_receipt_id,'authority_effect','NONE','idempotent_replay',true,'expires_at',old.expires_at); end if;
   raise exception 'ACADEMY_ENTRY_IDEMPOTENCY_COLLISION';
 end if;
 v_id:='academy-entry-'||substr(v_semantic_hash,1,32);
 v_content_hash:=encode(extensions.digest(convert_to((v_semantic||jsonb_build_object('issued_at',v_now,'expires_at',v_now+make_interval(mins=>p_valid_minutes)))::text,'UTF8'),'sha256'),'hex');
 insert into public.world8_academy_coding_entry_receipts(entry_receipt_id,actor_id,execution_id,work_id,workspace_id,dev_session_id,preflight_receipt_id,qualification_id,canonical_head,academy_shadow_id,guardian_companion_id,checkpoint_id,context_binding,gate_state,authority_effect,semantic_hash,content_hash,issued_at,expires_at)
 values(v_id,p_actor_id,p_execution_id,p_work_id,p_workspace_id,p_dev_session_id,p_preflight_receipt_id,p_qualification_id,ws.base_commit,sh.shadow_id,g.companion_id,cp.checkpoint_id,v_context,'PASS','NONE',v_semantic_hash,v_content_hash,v_now,v_now+make_interval(mins=>p_valid_minutes));
 return jsonb_build_object('schema','WORLD8_ACADEMY_CODING_ENTRY/0.4','entry_receipt_id',v_id,'authority_effect','NONE','idempotent_replay',false,'expires_at',v_now+make_interval(mins=>p_valid_minutes));
end $$;

create or replace function public.world8_dev_record_prewrite_recovery_v1(
 p_entry_receipt_id text,p_checkpoint_id text,p_recovery_class text,p_runtime_snapshot_id text,p_restore_strategy_ref text,
 p_evidence_refs jsonb default '[]'::jsonb,p_valid_minutes integer default 15
) returns jsonb language plpgsql security definer set search_path=public,extensions as $$
declare v_now timestamptz:=clock_timestamp(); er public.world8_academy_coding_entry_receipts%rowtype; cp public.world8_dev_session_checkpoints%rowtype; rs public.world8_dev_runtime_snapshots%rowtype; v_semantic jsonb; v_hash text; v_id text;
begin
 if p_recovery_class not in('CODE_ONLY','DB_TOUCHING') then raise exception 'RECOVERY_CLASS_INVALID'; end if;
 select * into er from public.world8_academy_coding_entry_receipts where entry_receipt_id=p_entry_receipt_id and gate_state='PASS' and expires_at>v_now;
 if not found then raise exception 'CURRENT_ACADEMY_ENTRY_REQUIRED'; end if;
 select * into cp from public.world8_dev_session_checkpoints where checkpoint_id=p_checkpoint_id and session_id=er.dev_session_id and work_id=er.work_id and actor_id=er.actor_id and workspace_id=er.workspace_id;
 if not found or cp.created_at<er.issued_at then raise exception 'RECOVERY_CHECKPOINT_BINDING_MISMATCH'; end if;
 if p_recovery_class='DB_TOUCHING' then
   if coalesce(p_runtime_snapshot_id,'')='' then raise exception 'DB_RUNTIME_SNAPSHOT_REQUIRED'; end if;
   if coalesce(trim(p_restore_strategy_ref),'')='' then raise exception 'DB_RESTORE_STRATEGY_REQUIRED'; end if;
   select * into rs from public.world8_dev_runtime_snapshots where snapshot_id=p_runtime_snapshot_id and snapshot_kind='DATABASE_RUNTIME' and generated_at>=er.issued_at;
   if not found then raise exception 'DB_RUNTIME_SNAPSHOT_REQUIRED'; end if;
 else p_runtime_snapshot_id:=null; p_restore_strategy_ref:='GIT_BASELINE_AND_CHECKPOINT'; end if;
 v_semantic:=jsonb_build_object('schema','WORLD8_PREWRITE_RECOVERY/0.4','entry_receipt_id',er.entry_receipt_id,'actor_id',er.actor_id,'execution_id',er.execution_id,'work_id',er.work_id,'workspace_id',er.workspace_id,'recovery_class',p_recovery_class,'canonical_head',er.canonical_head,'checkpoint_id',cp.checkpoint_id,'runtime_snapshot_id',p_runtime_snapshot_id,'restore_strategy_ref',p_restore_strategy_ref,'evidence_refs',coalesce(p_evidence_refs,'[]'::jsonb),'authority_effect','NONE');
 v_hash:=encode(extensions.digest(convert_to(v_semantic::text,'UTF8'),'sha256'),'hex'); v_id:='recovery-'||substr(v_hash,1,32);
 insert into public.world8_dev_prewrite_recovery_receipts(recovery_receipt_id,entry_receipt_id,actor_id,execution_id,work_id,workspace_id,recovery_class,canonical_head,checkpoint_id,runtime_snapshot_id,restore_strategy_ref,evidence_refs,authority_effect,semantic_hash,content_hash,issued_at,expires_at)
 values(v_id,er.entry_receipt_id,er.actor_id,er.execution_id,er.work_id,er.workspace_id,p_recovery_class,er.canonical_head,cp.checkpoint_id,p_runtime_snapshot_id,p_restore_strategy_ref,coalesce(p_evidence_refs,'[]'::jsonb),'NONE',v_hash,v_hash,v_now,v_now+make_interval(mins=>p_valid_minutes)) on conflict(semantic_hash) do nothing;
 return jsonb_build_object('schema','WORLD8_PREWRITE_RECOVERY/0.4','recovery_receipt_id',v_id,'recovery_class',p_recovery_class,'authority_effect','NONE');
end $$;

create or replace function public.world8_dev_admission_check_v3(
 p_actor_id text,p_execution_id text,p_work_id text,p_workspace_id text,p_entry_receipt_id text,
 p_required_qualifications jsonb default '[]'::jsonb,p_authorization_requirement jsonb default '{}'::jsonb,p_valid_minutes integer default 60
) returns jsonb language plpgsql security definer set search_path=public,extensions as $$
declare er public.world8_academy_coding_entry_receipts%rowtype; a jsonb; v_hash text;
begin
 select * into er from public.world8_academy_coding_entry_receipts where entry_receipt_id=p_entry_receipt_id and gate_state='PASS' and expires_at>clock_timestamp();
 if not found then raise exception 'CURRENT_ACADEMY_ENTRY_REQUIRED'; end if;
 if er.actor_id<>p_actor_id or er.execution_id<>p_execution_id or er.work_id<>p_work_id or er.workspace_id<>p_workspace_id then raise exception 'ACADEMY_ENTRY_BINDING_MISMATCH'; end if;
 if er.authority_effect<>'NONE' then raise exception 'ACADEMY_ENTRY_AUTHORITY_EFFECT_FORBIDDEN'; end if;
 a:=public.world8_dev_admission_check_v2(p_actor_id,p_execution_id,p_work_id,p_workspace_id,p_required_qualifications,p_authorization_requirement,p_valid_minutes);
 if coalesce(a->>'gate_state','BLOCKED')='PASS' then
   v_hash:=encode(extensions.digest(convert_to((a->>'admission_id')||'|'||er.entry_receipt_id,'UTF8'),'sha256'),'hex');
   insert into public.world8_dev_admission_entry_bindings(admission_id,entry_receipt_id,content_hash) values(a->>'admission_id',er.entry_receipt_id,v_hash) on conflict(admission_id) do nothing;
 end if;
 return a||jsonb_build_object('schema','WORLD8_DEV_ADMISSION/0.3','academy_entry_receipt_id',er.entry_receipt_id,'academy_entry_authority_effect','NONE');
end $$;

create or replace function public.world8_dev_acquire_lease_v5(
 p_work_id text,p_artifact_id text,p_holder_ref text,p_source_room text,p_mode text,p_ttl_seconds integer,
 p_admission_id text,p_recovery_receipt_id text,p_required_recovery_class text default 'CODE_ONLY'
) returns jsonb language plpgsql security definer set search_path=public as $$
declare a public.world8_dev_admission_receipts%rowtype; b public.world8_dev_admission_entry_bindings%rowtype; er public.world8_academy_coding_entry_receipts%rowtype; rr public.world8_dev_prewrite_recovery_receipts%rowtype; r jsonb;
begin
 if p_required_recovery_class not in('CODE_ONLY','DB_TOUCHING') then raise exception 'RECOVERY_CLASS_INVALID'; end if;
 select * into a from public.world8_dev_admission_receipts where admission_id=p_admission_id and gate_state='PASS' and expires_at>clock_timestamp(); if not found then raise exception 'DEVELOPER_ADMISSION_REQUIRED'; end if;
 select * into b from public.world8_dev_admission_entry_bindings where admission_id=p_admission_id; if not found then raise exception 'ACADEMY_ENTRY_BOUND_ADMISSION_REQUIRED'; end if;
 select * into er from public.world8_academy_coding_entry_receipts where entry_receipt_id=b.entry_receipt_id and gate_state='PASS' and expires_at>clock_timestamp(); if not found then raise exception 'CURRENT_ACADEMY_ENTRY_REQUIRED'; end if;
 select * into rr from public.world8_dev_prewrite_recovery_receipts where recovery_receipt_id=p_recovery_receipt_id and expires_at>clock_timestamp(); if not found then raise exception 'CURRENT_PREWRITE_RECOVERY_REQUIRED'; end if;
 if er.actor_id<>p_holder_ref or er.work_id<>p_work_id or er.workspace_id<>a.workspace_id or er.execution_id<>a.execution_id then raise exception 'ACADEMY_ENTRY_ADMISSION_BINDING_MISMATCH'; end if;
 if rr.entry_receipt_id<>er.entry_receipt_id or rr.actor_id<>p_holder_ref or rr.execution_id<>er.execution_id or rr.work_id<>p_work_id or rr.workspace_id<>er.workspace_id or rr.canonical_head<>er.canonical_head then raise exception 'RECOVERY_BINDING_MISMATCH'; end if;
 if p_required_recovery_class='DB_TOUCHING' and rr.recovery_class<>'DB_TOUCHING' then raise exception 'DB_TOUCHING_RECOVERY_REQUIRED'; end if;
 r:=public.world8_dev_acquire_lease_v4(p_work_id,p_artifact_id,p_holder_ref,p_source_room,p_mode,p_ttl_seconds,p_admission_id);
 update public.world8_dev_leases set metadata=coalesce(metadata,'{}'::jsonb)||jsonb_build_object('lease_contract_version','5.0','academy_entry_receipt_id',er.entry_receipt_id,'prewrite_recovery_receipt_id',rr.recovery_receipt_id,'recovery_class',rr.recovery_class) where lease_id=r->>'lease_id';
 return r||jsonb_build_object('schema','WORLD8_DEV_LEASE/5.0','academy_entry_receipt_id',er.entry_receipt_id,'prewrite_recovery_receipt_id',rr.recovery_receipt_id,'recovery_class',rr.recovery_class);
end $$;

revoke all on table public.world8_academy_coding_entry_receipts from public,anon,authenticated;
revoke all on table public.world8_dev_prewrite_recovery_receipts from public,anon,authenticated;
revoke all on table public.world8_dev_admission_entry_bindings from public,anon,authenticated;
revoke all on function public.world8_academy_coding_entry_issue_v1(text,text,text,text,text,text,text,boolean,integer,jsonb) from public,anon,authenticated;
revoke all on function public.world8_dev_record_prewrite_recovery_v1(text,text,text,text,text,jsonb,integer) from public,anon,authenticated;
revoke all on function public.world8_dev_admission_check_v3(text,text,text,text,text,jsonb,jsonb,integer) from public,anon,authenticated;
revoke all on function public.world8_dev_acquire_lease_v5(text,text,text,text,text,integer,text,text,text) from public,anon,authenticated;

-- Runtime cutover: service_role must not bypass Academy Entry by invoking legacy public gates directly.
-- v3/v5 remain SECURITY DEFINER and may call v2/v4 internally as implementation details.
revoke execute on function public.world8_dev_admission_check_v2(text,text,text,text,jsonb,jsonb,integer) from service_role;
revoke execute on function public.world8_dev_acquire_lease_v4(text,text,text,text,text,integer,text) from service_role;

-- Marker consumed by the static validator and review automation.
-- REVOKE_DIRECT_SERVICE_ROLE_EXECUTE_ON_ADMISSION_V2_AND_LEASE_V4

grant execute on function public.world8_academy_coding_entry_issue_v1(text,text,text,text,text,text,text,boolean,integer,jsonb) to service_role;
grant execute on function public.world8_dev_record_prewrite_recovery_v1(text,text,text,text,text,jsonb,integer) to service_role;
grant execute on function public.world8_dev_admission_check_v3(text,text,text,text,text,jsonb,jsonb,integer) to service_role;
grant execute on function public.world8_dev_acquire_lease_v5(text,text,text,text,text,integer,text,text,text) to service_role;
