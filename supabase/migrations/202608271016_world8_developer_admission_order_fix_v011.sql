-- World 8 Developer Admission ordering fix v0.1.1
-- Incident: incident-64fe289e33fad6cb6ed5e964b3a2f9aa
-- Correct order: Preflight -> Work Claim -> Workspace -> Admission -> Lease/Write.

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
language plpgsql security definer set search_path='public'
as $$
begin
 raise exception 'DEPRECATED_USE_WORK_CLAIM_V2_THEN_ADMISSION_THEN_LEASE_V2';
end $$;

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
 if p_require_authorization and (v_auth_gate<>'PASS' or not v_auth_checked) then
   raise exception 'WRITE_AUTHORIZATION_EVIDENCE_REQUIRED';
 end if;

 v_lease:=public.world8_dev_acquire_lease_v1(p_work_id,p_artifact_id,p_holder_ref,p_source_room,p_mode,p_ttl_seconds);
 v_lease_id:=v_lease->>'lease_id';
 update public.world8_dev_leases
 set metadata=coalesce(metadata,'{}'::jsonb)||jsonb_build_object(
   'admission_id',p_admission_id,
   'workspace_id',v_adm.workspace_id,
   'authorization_required',p_require_authorization,
   'authorization_checked',v_auth_checked,
   'admission_schema','WORLD8_DEV_ADMISSION/0.1'
 )
 where lease_id=v_lease_id;
 return v_lease||jsonb_build_object(
   'admission_id',p_admission_id,
   'workspace_id',v_adm.workspace_id,
   'authorization_required',p_require_authorization,
   'authorization_checked',v_auth_checked,
   'schema','WORLD8_DEV_LEASE/2.0'
 );
end $$;

revoke all on function public.world8_dev_create_work_claim_v3(text,text,text,text,text,text,text,text,jsonb,jsonb,jsonb,jsonb,jsonb) from public,anon,authenticated;
grant execute on function public.world8_dev_create_work_claim_v3(text,text,text,text,text,text,text,text,jsonb,jsonb,jsonb,jsonb,jsonb) to service_role;
revoke all on function public.world8_dev_acquire_lease_v2(text,text,text,text,text,integer,text,boolean) from public,anon,authenticated;
grant execute on function public.world8_dev_acquire_lease_v2(text,text,text,text,text,integer,text,boolean) to service_role;
