-- World 8 Developer Access Grant v0.2
-- Access is issued only after machine-verified Mason qualification plus exact PASS Developer Admission and Authorization.
-- The grant contains only opaque connector refs; it is not Authority.

create or replace function public.world8_dev_access_grant_issue_v2(
  p_actor_id text,
  p_work_id text,
  p_workspace_id text,
  p_admission_id text,
  p_resource_kind text,
  p_resource_ref text,
  p_access_mode text,
  p_credential_ref text,
  p_expires_at timestamptz,
  p_evidence_refs jsonb default '[]'::jsonb,
  p_metadata jsonb default '{}'::jsonb
) returns jsonb
language plpgsql
security definer
set search_path=public,extensions
as $$
declare
  w public.world8_dev_workspaces%rowtype;
  adm public.world8_dev_admission_receipts%rowtype;
  work_row public.world8_dev_work_items%rowtype;
  v_now timestamptz:=clock_timestamp();
  v_key text;
  v_hash text;
  v_id text;
  v_auth_resource text;
begin
  if p_resource_kind not in ('GITHUB_BRANCH','SUPABASE_PROJECT','GOOGLE_DRIVE','GITHUB_REPO_READ') then raise exception 'INVALID_DEVELOPER_ACCESS_RESOURCE_KIND'; end if;
  if p_access_mode not in ('READ','BRANCH_WRITE','GOVERNED_MIGRATION','RPC') then raise exception 'INVALID_DEVELOPER_ACCESS_MODE'; end if;
  if p_credential_ref not in ('connector:github:world8','connector:supabase:world8','connector:google-drive:world8') then raise exception 'OPAQUE_APPROVED_CONNECTOR_REF_REQUIRED'; end if;
  if p_expires_at is null or p_expires_at<=v_now or p_expires_at>v_now+interval '4 hours' then raise exception 'DEVELOPER_ACCESS_EXPIRY_OUT_OF_RANGE'; end if;
  if jsonb_typeof(coalesce(p_evidence_refs,'[]'::jsonb))<>'array' then raise exception 'EVIDENCE_REFS_MUST_BE_ARRAY'; end if;
  if not exists(select 1 from public.world8_actor_registry where actor_id=p_actor_id and status='ACTIVE') then raise exception 'ACTIVE_ACTOR_REQUIRED'; end if;
  if not exists(
    select 1 from public.world8_actor_qualifications q
    where q.actor_id=p_actor_id and q.status='ACTIVE' and q.qualification_ref='MASON_CORE' and q.qualification_version='1.4.1'
      and q.valid_from<=v_now and (q.expires_at is null or q.expires_at>v_now)
      and coalesce((q.metadata->>'machine_verified')::boolean,false)=true
  ) then raise exception 'ACTIVE_MACHINE_VERIFIED_MASON_CORE_REQUIRED'; end if;

  select * into w from public.world8_dev_workspaces where workspace_id=p_workspace_id and state='ACTIVE';
  if not found or w.actor_id<>p_actor_id or w.work_id<>p_work_id then raise exception 'ACTIVE_BOUND_WORKSPACE_REQUIRED'; end if;
  select * into work_row from public.world8_dev_work_items where work_id=p_work_id;
  if not found or work_row.actor_ref<>p_actor_id then raise exception 'BOUND_WORK_REQUIRED'; end if;

  select * into adm from public.world8_dev_admission_receipts where admission_id=p_admission_id;
  if not found then raise exception 'PASS_DEVELOPER_ADMISSION_REQUIRED'; end if;
  if adm.actor_id<>p_actor_id or adm.work_id<>p_work_id or adm.workspace_id<>p_workspace_id then raise exception 'ADMISSION_BINDING_MISMATCH'; end if;
  if adm.gate_state<>'PASS' or adm.expires_at<=v_now then raise exception 'ACTIVE_PASS_DEVELOPER_ADMISSION_REQUIRED'; end if;
  if coalesce(adm.qualification_result->>'gate_state','BLOCKED')<>'PASS' then raise exception 'ADMISSION_QUALIFICATION_PASS_REQUIRED'; end if;
  if coalesce(adm.authorization_result->>'gate_state','BLOCKED')<>'PASS'
     or coalesce((adm.authorization_result->>'authorization_checked')::boolean,false)<>true
     or coalesce(adm.authorization_result->>'decision','DENY')<>'ALLOW' then
    raise exception 'CHECKED_AUTHORIZATION_ALLOW_REQUIRED';
  end if;
  v_auth_resource:=adm.authorization_result->>'resource_ref';
  if v_auth_resource is null or not exists(select 1 from jsonb_array_elements_text(coalesce(work_row.touches,'[]'::jsonb)) x where x=v_auth_resource) then
    raise exception 'AUTHORIZED_RESOURCE_MUST_BELONG_TO_WORK';
  end if;

  if p_resource_kind='GITHUB_BRANCH' then
    if p_access_mode<>'BRANCH_WRITE' or p_credential_ref<>'connector:github:world8' then raise exception 'GITHUB_BRANCH_GRANT_CONTRACT_MISMATCH'; end if;
    if w.branch_ref in ('main','master') or p_resource_ref<>('github:saeedfaai/world-8:branch:'||w.branch_ref) then raise exception 'GITHUB_BRANCH_MUST_MATCH_ISOLATED_WORKSPACE'; end if;
  elsif p_resource_kind='SUPABASE_PROJECT' then
    if p_credential_ref<>'connector:supabase:world8' or p_resource_ref<>'supabase:ogiqujrubsvzohqremuv' or p_access_mode not in ('GOVERNED_MIGRATION','RPC') then
      raise exception 'SUPABASE_GRANT_CONTRACT_MISMATCH';
    end if;
  elsif p_resource_kind='GOOGLE_DRIVE' then
    if p_access_mode<>'READ' or p_credential_ref<>'connector:google-drive:world8' then raise exception 'GOOGLE_DRIVE_GRANT_CONTRACT_MISMATCH'; end if;
  elsif p_resource_kind='GITHUB_REPO_READ' then
    if p_access_mode<>'READ' or p_credential_ref<>'connector:github:world8' then raise exception 'GITHUB_READ_GRANT_CONTRACT_MISMATCH'; end if;
  end if;

  v_key:=encode(extensions.digest(p_actor_id||'|'||p_work_id||'|'||p_workspace_id||'|'||p_resource_kind||'|'||p_resource_ref||'|'||p_access_mode,'sha256'),'hex');
  v_hash:=encode(extensions.digest(v_key||'|GRANT_V2|'||p_admission_id||'|'||p_credential_ref||'|'||p_expires_at::text||'|'||coalesce(p_evidence_refs,'[]'::jsonb)::text||'|'||v_now::text,'sha256'),'hex');
  v_id:='access-grant-'||substr(v_hash,1,28);
  insert into public.world8_dev_access_grant_receipts(
    access_receipt_id,grant_key,receipt_kind,actor_id,work_id,workspace_id,resource_kind,resource_ref,access_mode,
    credential_ref,scope,expires_at,evidence_refs,metadata,created_by,content_hash,created_at
  ) values (
    v_id,v_key,'GRANT',p_actor_id,p_work_id,p_workspace_id,p_resource_kind,p_resource_ref,p_access_mode,
    p_credential_ref,
    jsonb_build_object('work_id',p_work_id,'workspace_id',p_workspace_id,'branch_ref',w.branch_ref,'authorized_artifact_ref',v_auth_resource),
    p_expires_at,
    coalesce(p_evidence_refs,'[]'::jsonb)||jsonb_build_array('admission:'||p_admission_id,'authorization:'||coalesce(adm.authorization_result->>'authorization_receipt_id','missing')),
    coalesce(p_metadata,'{}'::jsonb)||jsonb_build_object(
      'admission_id',p_admission_id,
      'authorization_receipt_id',adm.authorization_result->>'authorization_receipt_id',
      'mason_core_version','1.4.1',
      'machine_verified_qualification',true,
      'raw_secret_present',false,
      'authority_granted',false
    ),
    p_actor_id,v_hash,v_now
  );
  return jsonb_build_object(
    'schema','WORLD8_DEV_ACCESS_GRANT/2.0',
    'access_receipt_id',v_id,
    'grant_key',v_key,
    'resource_kind',p_resource_kind,
    'resource_ref',p_resource_ref,
    'access_mode',p_access_mode,
    'credential_ref',p_credential_ref,
    'admission_id',p_admission_id,
    'authorized_artifact_ref',v_auth_resource,
    'expires_at',p_expires_at,
    'machine_verified_qualification',true,
    'raw_secret_returned',false,
    'authority_granted',false
  );
end $$;

revoke all on function public.world8_dev_access_grant_issue_v1(text,text,text,text,text,text,text,timestamptz,jsonb,jsonb) from service_role;
revoke all on function public.world8_dev_access_grant_issue_v2(text,text,text,text,text,text,text,text,timestamptz,jsonb,jsonb) from public,anon,authenticated;
grant execute on function public.world8_dev_access_grant_issue_v2(text,text,text,text,text,text,text,text,timestamptz,jsonb,jsonb) to service_role;
