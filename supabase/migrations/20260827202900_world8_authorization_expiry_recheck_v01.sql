-- World 8 authorization-evidence expiry recheck v0.1
-- Admission lifetime must never extend the usable lifetime of its embedded Authorization receipt.
-- Access grants, write leases and Cockpit PASS re-check Authorization at use time.

create or replace function public.world8_dev_access_grant_issue_v2(
  p_actor_id text,p_work_id text,p_workspace_id text,p_admission_id text,p_resource_kind text,p_resource_ref text,
  p_access_mode text,p_credential_ref text,p_expires_at timestamptz,p_evidence_refs jsonb default '[]'::jsonb,p_metadata jsonb default '{}'::jsonb
) returns jsonb language plpgsql security definer set search_path=public,extensions as $$
declare
  w public.world8_dev_workspaces%rowtype; adm public.world8_dev_admission_receipts%rowtype; work_row public.world8_dev_work_items%rowtype;
  v_now timestamptz:=clock_timestamp(); v_auth_expires timestamptz; v_key text; v_hash text; v_id text; v_auth_resource text;
begin
  if p_resource_kind not in ('GITHUB_BRANCH','SUPABASE_PROJECT','GOOGLE_DRIVE','GITHUB_REPO_READ') then raise exception 'INVALID_DEVELOPER_ACCESS_RESOURCE_KIND'; end if;
  if p_access_mode not in ('READ','BRANCH_WRITE','GOVERNED_MIGRATION','RPC') then raise exception 'INVALID_DEVELOPER_ACCESS_MODE'; end if;
  if p_credential_ref not in ('connector:github:world8','connector:supabase:world8','connector:google-drive:world8') then raise exception 'OPAQUE_APPROVED_CONNECTOR_REF_REQUIRED'; end if;
  if p_expires_at is null or p_expires_at<=v_now or p_expires_at>v_now+interval '4 hours' then raise exception 'DEVELOPER_ACCESS_EXPIRY_OUT_OF_RANGE'; end if;
  if jsonb_typeof(coalesce(p_evidence_refs,'[]'::jsonb))<>'array' then raise exception 'EVIDENCE_REFS_MUST_BE_ARRAY'; end if;
  if not exists(select 1 from public.world8_actor_registry where actor_id=p_actor_id and status='ACTIVE') then raise exception 'ACTIVE_ACTOR_REQUIRED'; end if;
  if not exists(select 1 from public.world8_actor_qualifications q where q.actor_id=p_actor_id and q.status='ACTIVE'
      and q.qualification_ref='MASON_CORE' and q.qualification_version='1.4.1' and q.valid_from<=v_now
      and (q.expires_at is null or q.expires_at>v_now) and coalesce((q.metadata->>'machine_verified')::boolean,false)=true)
  then raise exception 'ACTIVE_MACHINE_VERIFIED_MASON_CORE_REQUIRED'; end if;

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
     or coalesce(adm.authorization_result->>'decision','DENY')<>'ALLOW' then raise exception 'CHECKED_AUTHORIZATION_ALLOW_REQUIRED'; end if;
  begin v_auth_expires:=(adm.authorization_result->>'expires_at')::timestamptz; exception when others then v_auth_expires:=null; end;
  if v_auth_expires is null or v_auth_expires<=v_now then raise exception 'AUTHORIZATION_EVIDENCE_EXPIRED'; end if;
  if p_expires_at>v_auth_expires then raise exception 'DEVELOPER_ACCESS_EXCEEDS_AUTHORIZATION_EXPIRY'; end if;
  v_auth_resource:=adm.authorization_result->>'resource_ref';
  if v_auth_resource is null or not exists(select 1 from jsonb_array_elements_text(coalesce(work_row.touches,'[]'::jsonb)) x where x=v_auth_resource)
  then raise exception 'AUTHORIZED_RESOURCE_MUST_BELONG_TO_WORK'; end if;

  if p_resource_kind='GITHUB_BRANCH' then
    if p_access_mode<>'BRANCH_WRITE' or p_credential_ref<>'connector:github:world8' then raise exception 'GITHUB_BRANCH_GRANT_CONTRACT_MISMATCH'; end if;
    if w.branch_ref in ('main','master') or p_resource_ref<>('github:saeedfaai/world-8:branch:'||w.branch_ref) then raise exception 'GITHUB_BRANCH_MUST_MATCH_ISOLATED_WORKSPACE'; end if;
  elsif p_resource_kind='SUPABASE_PROJECT' then
    if p_credential_ref<>'connector:supabase:world8' or p_resource_ref<>'supabase:ogiqujrubsvzohqremuv' or p_access_mode not in ('GOVERNED_MIGRATION','RPC') then raise exception 'SUPABASE_GRANT_CONTRACT_MISMATCH'; end if;
  elsif p_resource_kind='GOOGLE_DRIVE' then
    if p_access_mode<>'READ' or p_credential_ref<>'connector:google-drive:world8' then raise exception 'GOOGLE_DRIVE_GRANT_CONTRACT_MISMATCH'; end if;
  elsif p_resource_kind='GITHUB_REPO_READ' then
    if p_access_mode<>'READ' or p_credential_ref<>'connector:github:world8' then raise exception 'GITHUB_READ_GRANT_CONTRACT_MISMATCH'; end if;
  end if;

  v_key:=encode(extensions.digest(p_actor_id||'|'||p_work_id||'|'||p_workspace_id||'|'||p_resource_kind||'|'||p_resource_ref||'|'||p_access_mode,'sha256'),'hex');
  v_hash:=encode(extensions.digest(v_key||'|GRANT_V2_EXPIRY_BOUND|'||p_admission_id||'|'||p_credential_ref||'|'||p_expires_at::text||'|'||v_now::text,'sha256'),'hex');
  v_id:='access-grant-'||substr(v_hash,1,28);
  insert into public.world8_dev_access_grant_receipts(access_receipt_id,grant_key,receipt_kind,actor_id,work_id,workspace_id,resource_kind,resource_ref,access_mode,credential_ref,scope,expires_at,evidence_refs,metadata,created_by,content_hash,created_at)
  values(v_id,v_key,'GRANT',p_actor_id,p_work_id,p_workspace_id,p_resource_kind,p_resource_ref,p_access_mode,p_credential_ref,
    jsonb_build_object('work_id',p_work_id,'workspace_id',p_workspace_id,'branch_ref',w.branch_ref,'authorized_artifact_ref',v_auth_resource),
    p_expires_at,coalesce(p_evidence_refs,'[]'::jsonb)||jsonb_build_array('admission:'||p_admission_id,'authorization:'||coalesce(adm.authorization_result->>'authorization_receipt_id','missing')),
    coalesce(p_metadata,'{}'::jsonb)||jsonb_build_object('admission_id',p_admission_id,'authorization_receipt_id',adm.authorization_result->>'authorization_receipt_id','authorization_expires_at',v_auth_expires,'mason_core_version','1.4.1','machine_verified_qualification',true,'raw_secret_present',false,'authority_granted',false),
    p_actor_id,v_hash,v_now);
  return jsonb_build_object('schema','WORLD8_DEV_ACCESS_GRANT/2.1','access_receipt_id',v_id,'grant_key',v_key,'resource_kind',p_resource_kind,'resource_ref',p_resource_ref,'access_mode',p_access_mode,'credential_ref',p_credential_ref,'admission_id',p_admission_id,'authorized_artifact_ref',v_auth_resource,'authorization_expires_at',v_auth_expires,'expires_at',p_expires_at,'machine_verified_qualification',true,'raw_secret_returned',false,'authority_granted',false);
end $$;

create or replace function public.world8_dev_acquire_lease_v4(
  p_work_id text,p_artifact_id text,p_holder_ref text,p_source_room text,p_mode text,p_ttl_seconds integer,p_admission_id text
) returns jsonb language plpgsql security definer set search_path=public as $$
declare a public.world8_dev_admission_receipts%rowtype; r jsonb; v_now timestamptz:=clock_timestamp(); v_auth_expires timestamptz; v_max_ttl integer;
begin
  select * into a from public.world8_dev_admission_receipts where admission_id=p_admission_id;
  if not found then raise exception 'DEVELOPER_ADMISSION_REQUIRED'; end if;
  if a.actor_id<>p_holder_ref then raise exception 'ADMISSION_ACTOR_MISMATCH'; end if;
  if a.work_id<>p_work_id then raise exception 'ADMISSION_WORK_MISMATCH'; end if;
  if a.gate_state<>'PASS' then raise exception 'DEVELOPER_ADMISSION_BLOCKED'; end if;
  if a.expires_at<=v_now then raise exception 'DEVELOPER_ADMISSION_EXPIRED'; end if;
  if coalesce(a.authorization_result->>'gate_state','BLOCKED')<>'PASS'
     or not coalesce((a.authorization_result->>'authorization_checked')::boolean,false)
     or coalesce(a.authorization_result->>'decision','DENY')<>'ALLOW' then raise exception 'WRITE_AUTHORIZATION_EVIDENCE_REQUIRED'; end if;
  begin v_auth_expires:=(a.authorization_result->>'expires_at')::timestamptz; exception when others then v_auth_expires:=null; end;
  if v_auth_expires is null or v_auth_expires<=v_now then raise exception 'AUTHORIZATION_EVIDENCE_EXPIRED'; end if;
  if coalesce(a.authorization_result->>'resource_kind','')<>'ARTIFACT' or coalesce(a.authorization_result->>'resource_ref','')<>p_artifact_id then raise exception 'AUTHORIZATION_ARTIFACT_MISMATCH'; end if;
  if p_mode in ('SHARED_WRITE','EXCLUSIVE_WRITE') and coalesce(a.authorization_result->>'action','')<>'CODE_WRITE' then raise exception 'CODE_WRITE_AUTHORIZATION_REQUIRED'; end if;
  v_max_ttl:=greatest(1,floor(extract(epoch from (v_auth_expires-v_now)))::integer);
  if p_ttl_seconds>v_max_ttl then raise exception 'LEASE_TTL_EXCEEDS_AUTHORIZATION_EXPIRY'; end if;
  r:=public.world8_dev_acquire_lease_v2(p_work_id,p_artifact_id,p_holder_ref,p_source_room,p_mode,p_ttl_seconds,p_admission_id,true);
  update public.world8_dev_leases set metadata=coalesce(metadata,'{}'::jsonb)||jsonb_build_object('authorization_resource_bound',true,'authorization_resource_kind','ARTIFACT','authorization_resource_ref',p_artifact_id,'authorization_expires_at',v_auth_expires,'lease_contract_version','4.1') where lease_id=r->>'lease_id';
  return r||jsonb_build_object('schema','WORLD8_DEV_LEASE/4.1','authorization_resource_bound',true,'authorization_resource_ref',p_artifact_id,'authorization_expires_at',v_auth_expires);
end $$;

create or replace function public.world8_dev_cockpit_receipt_v1(
  p_actor_id text,p_work_id text,p_workspace_id text,p_target_artifact_id text,
  p_required_qualifications jsonb default '[{"qualification_ref":"MASON_CORE","version":"1.4.1"}]'::jsonb
) returns jsonb language plpgsql security definer set search_path=public,extensions as $$
declare
  ar public.world8_actor_registry%rowtype; wi public.world8_dev_work_items%rowtype; w public.world8_dev_workspaces%rowtype;
  a public.world8_dev_admission_receipts%rowtype; g public.world8_dev_access_grant_receipts%rowtype; ga public.world8_dev_admission_receipts%rowtype; l public.world8_dev_leases%rowtype;
  v_q jsonb; v_scribe jsonb; v_guardian jsonb; v_resume jsonb; v_now jsonb; v_canonical_head text; v_auth_expires timestamptz; v_grant_auth_expires timestamptz; v_lease_auth_expires timestamptz;
  v_blockers jsonb:='[]'::jsonb; v_snapshot jsonb; v_gate text:='PASS'; v_hash text; v_id text; v_time timestamptz:=clock_timestamp();
begin
  select * into ar from public.world8_actor_registry where actor_id=p_actor_id and status='ACTIVE';
  if not found then v_blockers:=v_blockers||jsonb_build_array(jsonb_build_object('code','ACTIVE_ACTOR_REQUIRED')); end if;
  select * into wi from public.world8_dev_work_items where work_id=p_work_id; if not found then raise exception 'WORK_NOT_FOUND'; end if;
  select * into w from public.world8_dev_workspaces where workspace_id=p_workspace_id;
  if not found or w.state<>'ACTIVE' or w.actor_id<>p_actor_id or w.work_id<>p_work_id then v_blockers:=v_blockers||jsonb_build_array(jsonb_build_object('code','ACTIVE_BOUND_WORKSPACE_REQUIRED')); end if;
  select metadata->>'canonical_head_commit' into v_canonical_head from public.world8_dev_external_resources where resource_id='resource-github-world8-canonical';
  if v_canonical_head is null or w.base_commit is distinct from v_canonical_head then v_blockers:=v_blockers||jsonb_build_array(jsonb_build_object('code','STALE_CANONICAL_BASE','workspace_base',w.base_commit,'canonical_head',v_canonical_head)); end if;
  v_q:=public.world8_dev_assignment_check_v1(p_actor_id,p_work_id,coalesce(p_required_qualifications,'[]'::jsonb));
  if coalesce(v_q->>'gate_state','BLOCKED')<>'PASS' then v_blockers:=v_blockers||jsonb_build_array(jsonb_build_object('code','QUALIFICATION_REQUIRED','details',v_q)); end if;

  select * into a from public.world8_dev_admission_receipts where actor_id=p_actor_id and work_id=p_work_id and workspace_id=p_workspace_id
    and gate_state='PASS' and expires_at>v_time and authorization_result->>'resource_kind'='ARTIFACT'
    and authorization_result->>'resource_ref'=p_target_artifact_id and authorization_result->>'action'='CODE_WRITE'
    and authorization_result->>'decision'='ALLOW' order by issued_at desc limit 1;
  if not found then v_blockers:=v_blockers||jsonb_build_array(jsonb_build_object('code','ARTIFACT_BOUND_AUTHORIZATION_REQUIRED'));
  else
    begin v_auth_expires:=(a.authorization_result->>'expires_at')::timestamptz; exception when others then v_auth_expires:=null; end;
    if v_auth_expires is null or v_auth_expires<=v_time then v_blockers:=v_blockers||jsonb_build_array(jsonb_build_object('code','AUTHORIZATION_EVIDENCE_EXPIRED')); end if;
  end if;

  select * into g from public.world8_dev_access_grant_receipts where actor_id=p_actor_id and work_id=p_work_id and workspace_id=p_workspace_id
    and resource_kind='GITHUB_BRANCH' and resource_ref=('github:saeedfaai/world-8:branch:'||w.branch_ref) order by created_at desc limit 1;
  if not found or g.receipt_kind<>'GRANT' or g.expires_at<=v_time or coalesce((g.metadata->>'machine_verified_qualification')::boolean,false)<>true then
    v_blockers:=v_blockers||jsonb_build_array(jsonb_build_object('code','ACTIVE_BRANCH_ACCESS_GRANT_REQUIRED'));
  else
    select * into ga from public.world8_dev_admission_receipts where admission_id=g.metadata->>'admission_id';
    begin v_grant_auth_expires:=(ga.authorization_result->>'expires_at')::timestamptz; exception when others then v_grant_auth_expires:=null; end;
    if not found or ga.gate_state<>'PASS' or ga.expires_at<=v_time or v_grant_auth_expires is null or v_grant_auth_expires<=v_time or ga.authorization_result->>'decision'<>'ALLOW' then
      v_blockers:=v_blockers||jsonb_build_array(jsonb_build_object('code','ACCESS_AUTHORIZATION_EVIDENCE_EXPIRED'));
    end if;
  end if;

  select * into l from public.world8_dev_leases where work_id=p_work_id and artifact_id=p_target_artifact_id and holder_ref=p_actor_id
    and status='ACTIVE' and expires_at>v_time and coalesce((metadata->>'authorization_resource_bound')::boolean,false)=true
    and metadata->>'authorization_resource_ref'=p_target_artifact_id order by issued_at desc limit 1;
  if not found then v_blockers:=v_blockers||jsonb_build_array(jsonb_build_object('code','ARTIFACT_BOUND_LEASE_REQUIRED'));
  else
    begin v_lease_auth_expires:=(l.metadata->>'authorization_expires_at')::timestamptz; exception when others then v_lease_auth_expires:=null; end;
    if v_lease_auth_expires is null or v_lease_auth_expires<=v_time then v_blockers:=v_blockers||jsonb_build_array(jsonb_build_object('code','LEASE_AUTHORIZATION_EVIDENCE_EXPIRED')); end if;
  end if;

  v_scribe:=public.world8_dev_scribe_guard_v1(p_work_id,p_actor_id,wi.source_room);
  if coalesce(v_scribe->>'gate_state','BLOCKED')<>'PASS' then v_blockers:=v_blockers||jsonb_build_array(jsonb_build_object('code','SCRIBE_GUARD_BLOCKED','details',v_scribe)); end if;
  v_guardian:=public.world8_guardian_awareness_snapshot_v1(p_work_id,p_actor_id);
  v_resume:=public.world8_dev_resume_capsule_v2(p_work_id);
  v_now:=public.world8_now_snapshot_v2(p_actor_id);
  if jsonb_array_length(v_blockers)>0 then v_gate:='BLOCKED'; end if;
  v_snapshot:=jsonb_build_object('projection_only',true,'actor',jsonb_build_object('actor_id',p_actor_id,'status',ar.status,'kind',ar.actor_kind),'qualification',v_q,
    'authorization',case when a.admission_id is null then '{}'::jsonb else jsonb_build_object('admission_id',a.admission_id,'authorization_receipt_id',a.authorization_result->>'authorization_receipt_id','resource_ref',a.authorization_result->>'resource_ref','gate_state',a.authorization_result->>'gate_state','expires_at',v_auth_expires) end,
    'access',case when g.access_receipt_id is null then '{}'::jsonb else jsonb_build_object('access_receipt_id',g.access_receipt_id,'resource_ref',g.resource_ref,'mode',g.access_mode,'expires_at',g.expires_at,'authorization_expires_at',v_grant_auth_expires,'raw_secret_returned',false) end,
    'workspace',jsonb_build_object('workspace_id',p_workspace_id,'branch_ref',w.branch_ref,'base_commit',w.base_commit,'canonical_head',v_canonical_head,'fresh',w.base_commit=v_canonical_head),
    'lease',case when l.lease_id is null then '{}'::jsonb else jsonb_build_object('lease_id',l.lease_id,'artifact_id',l.artifact_id,'fencing_token',l.fencing_token,'expires_at',l.expires_at,'authorization_expires_at',v_lease_auth_expires,'authorization_resource_bound',true) end,
    'scribe',v_scribe,'guardian',v_guardian,'resume',jsonb_build_object('resume_state',v_resume->'resume_state','next_safe_action',v_resume->'next_safe_action','latest_checkpoint',v_resume->'latest_checkpoint'),'now',v_now,
    'principles',jsonb_build_array('TRAINING != QUALIFICATION','QUALIFICATION != AUTHORITY','ACCESS != AUTHORITY','PARALLELIZE WORK; SERIALIZE TRUTH'));
  v_hash:=encode(extensions.digest(p_actor_id||'|'||p_work_id||'|'||p_workspace_id||'|'||p_target_artifact_id||'|'||v_gate||'|'||v_blockers::text||'|'||v_snapshot::text||'|'||v_time::text,'sha256'),'hex');
  v_id:='cockpit-'||substr(v_hash,1,32);
  insert into public.world8_dev_cockpit_receipts(cockpit_receipt_id,actor_id,work_id,workspace_id,target_artifact_id,gate_state,blockers,snapshot,content_hash,created_at)
  values(v_id,p_actor_id,p_work_id,p_workspace_id,p_target_artifact_id,v_gate,v_blockers,v_snapshot,v_hash,v_time);
  return jsonb_build_object('schema','WORLD8_DEV_COCKPIT_RECEIPT/1.1','cockpit_receipt_id',v_id,'gate_state',v_gate,'blockers',v_blockers,'snapshot',v_snapshot,'content_hash',v_hash,'projection_only',true);
end $$;
