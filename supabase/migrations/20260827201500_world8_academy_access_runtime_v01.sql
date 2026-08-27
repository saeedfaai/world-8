-- World 8 Academy + Developer Access Runtime v0.1
-- TRAINING != QUALIFICATION != AUTHORITY.
-- Extends canonical actor qualification and Access Mesh truth; stores no raw credentials.

create table if not exists public.world8_academy_curricula (
  curriculum_id text primary key,
  world_id text not null default 'world-001',
  curriculum_ref text not null,
  curriculum_version text not null,
  qualification_kind text not null check (qualification_kind in ('ROLE','CAPABILITY','TYPE_RATING')),
  qualification_ref text not null,
  qualification_version text not null,
  rulebase_version_id text,
  min_score numeric not null default 1.0 check (min_score >= 0 and min_score <= 1),
  required_refs jsonb not null default '[]'::jsonb check (jsonb_typeof(required_refs)='array'),
  recurrent_training_triggers jsonb not null default '[]'::jsonb check (jsonb_typeof(recurrent_training_triggers)='array'),
  status text not null default 'FROZEN' check (status in ('FROZEN','RETIRED')),
  metadata jsonb not null default '{}'::jsonb check (jsonb_typeof(metadata)='object'),
  content_hash text not null,
  created_by text not null,
  created_at timestamptz not null default clock_timestamp(),
  unique(curriculum_ref,curriculum_version)
);

create table if not exists public.world8_academy_checkride_receipts (
  checkride_receipt_id text primary key,
  world_id text not null default 'world-001',
  subject_actor_id text not null references public.world8_actor_registry(actor_id),
  evaluator_actor_id text not null references public.world8_actor_registry(actor_id),
  curriculum_id text not null references public.world8_academy_curricula(curriculum_id),
  qualification_kind text not null,
  qualification_ref text not null,
  qualification_version text not null,
  result text not null check (result in ('PASS','FAIL')),
  score numeric not null check (score >= 0 and score <= 1),
  evidence_refs jsonb not null default '[]'::jsonb check (jsonb_typeof(evidence_refs)='array'),
  metadata jsonb not null default '{}'::jsonb check (jsonb_typeof(metadata)='object'),
  content_hash text not null,
  created_at timestamptz not null default clock_timestamp()
);
create index if not exists world8_academy_checkride_subject_idx on public.world8_academy_checkride_receipts(subject_actor_id,created_at desc);

create table if not exists public.world8_dev_access_grant_receipts (
  access_receipt_id text primary key,
  world_id text not null default 'world-001',
  grant_key text not null,
  receipt_kind text not null check (receipt_kind in ('GRANT','REVOKE')),
  actor_id text not null references public.world8_actor_registry(actor_id),
  work_id text not null references public.world8_dev_work_items(work_id),
  workspace_id text not null references public.world8_dev_workspaces(workspace_id),
  resource_kind text not null check (resource_kind in ('GITHUB_BRANCH','SUPABASE_PROJECT','GOOGLE_DRIVE','GITHUB_REPO_READ')),
  resource_ref text not null,
  access_mode text not null check (access_mode in ('READ','BRANCH_WRITE','GOVERNED_MIGRATION','RPC')),
  credential_ref text not null,
  scope jsonb not null default '{}'::jsonb check (jsonb_typeof(scope)='object'),
  expires_at timestamptz not null,
  evidence_refs jsonb not null default '[]'::jsonb check (jsonb_typeof(evidence_refs)='array'),
  metadata jsonb not null default '{}'::jsonb check (jsonb_typeof(metadata)='object'),
  created_by text not null,
  content_hash text not null,
  created_at timestamptz not null default clock_timestamp()
);
create index if not exists world8_dev_access_grant_key_idx on public.world8_dev_access_grant_receipts(grant_key,created_at desc);

create or replace function public.world8_academy_evidence_append_only_v1()
returns trigger language plpgsql security definer set search_path=public as $$
begin raise exception 'WORLD8_ACADEMY_EVIDENCE_APPEND_ONLY:%',TG_TABLE_NAME; end $$;

drop trigger if exists world8_academy_curricula_append_only_trg on public.world8_academy_curricula;
create trigger world8_academy_curricula_append_only_trg before update or delete on public.world8_academy_curricula for each row execute function public.world8_academy_evidence_append_only_v1();
drop trigger if exists world8_academy_checkride_append_only_trg on public.world8_academy_checkride_receipts;
create trigger world8_academy_checkride_append_only_trg before update or delete on public.world8_academy_checkride_receipts for each row execute function public.world8_academy_evidence_append_only_v1();
drop trigger if exists world8_dev_access_grant_append_only_trg on public.world8_dev_access_grant_receipts;
create trigger world8_dev_access_grant_append_only_trg before update or delete on public.world8_dev_access_grant_receipts for each row execute function public.world8_academy_evidence_append_only_v1();

insert into public.world8_academy_curricula(curriculum_id,curriculum_ref,curriculum_version,qualification_kind,qualification_ref,qualification_version,rulebase_version_id,min_score,required_refs,recurrent_training_triggers,status,metadata,content_hash,created_by)
values(
  'curriculum-world8-mason-core-v14','MASON_CORE','1.4.0','TYPE_RATING','MASON_CORE','1.4.0','mason-rulebase-v1.4',1.0,
  '["START_HERE.md","docs/engineering/DEVELOPER_ADMISSION.md","docs/engineering/N_MASON_POOL.md","docs/engineering/CRASH_SAFE_DEVELOPMENT.md","docs/engineering/ENGINEERING_GUARDIAN.md","artifact-world8-academy-v1:shadow-2264e550aa1f2a8f769cb606944d646a"]'::jsonb,
  '["RULEBASE_CHANGE","ARCHITECTURE_CHANGE","AUTHORIZATION_CONTRACT_CHANGE","ACCESS_CONTRACT_CHANGE"]'::jsonb,
  'FROZEN','{"training_not_authority":true,"qualification_not_authority":true,"bootstrap_seed":true}'::jsonb,
  encode(extensions.digest('MASON_CORE|1.4.0|mason-rulebase-v1.4|qualification-not-authority','sha256'),'hex'),'service-world8-qualification-authority'
) on conflict(curriculum_ref,curriculum_version) do nothing;

create or replace function public.world8_academy_record_checkride_v1(
  p_subject_actor_id text,p_evaluator_actor_id text,p_curriculum_id text,p_result text,p_score numeric,
  p_evidence_refs jsonb default '[]'::jsonb,p_metadata jsonb default '{}'::jsonb
) returns jsonb language plpgsql security definer set search_path=public,extensions as $$
declare c public.world8_academy_curricula%rowtype; v_now timestamptz:=clock_timestamp(); v_hash text; v_id text;
begin
  if p_subject_actor_id=p_evaluator_actor_id then raise exception 'CHECKRIDE_SELF_EVALUATION_FORBIDDEN'; end if;
  if p_result not in ('PASS','FAIL') then raise exception 'INVALID_CHECKRIDE_RESULT'; end if;
  if p_score<0 or p_score>1 then raise exception 'INVALID_CHECKRIDE_SCORE'; end if;
  if jsonb_typeof(coalesce(p_evidence_refs,'[]'::jsonb))<>'array' then raise exception 'EVIDENCE_REFS_MUST_BE_ARRAY'; end if;
  if not exists(select 1 from public.world8_actor_registry where actor_id=p_subject_actor_id and status='ACTIVE') then raise exception 'ACTIVE_SUBJECT_ACTOR_REQUIRED'; end if;
  if not exists(select 1 from public.world8_actor_registry where actor_id=p_evaluator_actor_id and status='ACTIVE') then raise exception 'ACTIVE_EVALUATOR_ACTOR_REQUIRED'; end if;
  select * into c from public.world8_academy_curricula where curriculum_id=p_curriculum_id and status='FROZEN';
  if not found then raise exception 'ACTIVE_CURRICULUM_NOT_FOUND'; end if;
  if p_result='PASS' and (p_score<c.min_score or jsonb_array_length(coalesce(p_evidence_refs,'[]'::jsonb))=0) then raise exception 'PASS_CHECKRIDE_EVIDENCE_OR_SCORE_INSUFFICIENT'; end if;
  v_hash:=encode(extensions.digest(p_subject_actor_id||'|'||p_evaluator_actor_id||'|'||p_curriculum_id||'|'||p_result||'|'||p_score::text||'|'||coalesce(p_evidence_refs,'[]'::jsonb)::text||'|'||v_now::text,'sha256'),'hex');
  v_id:='academy-checkride-'||substr(v_hash,1,28);
  insert into public.world8_academy_checkride_receipts(checkride_receipt_id,subject_actor_id,evaluator_actor_id,curriculum_id,qualification_kind,qualification_ref,qualification_version,result,score,evidence_refs,metadata,content_hash,created_at)
  values(v_id,p_subject_actor_id,p_evaluator_actor_id,p_curriculum_id,c.qualification_kind,c.qualification_ref,c.qualification_version,p_result,p_score,coalesce(p_evidence_refs,'[]'::jsonb),coalesce(p_metadata,'{}'::jsonb)||jsonb_build_object('authorization_granted',false),v_hash,v_now);
  return jsonb_build_object('schema','WORLD8_ACADEMY_CHECKRIDE/1.0','checkride_receipt_id',v_id,'subject_actor_id',p_subject_actor_id,'result',p_result,'score',p_score,'qualification_ref',c.qualification_ref,'qualification_version',c.qualification_version,'authorization_granted',false,'content_hash',v_hash);
end $$;

create or replace function public.world8_academy_issue_license_v1(
  p_checkride_receipt_id text,p_issued_by text,p_expires_at timestamptz,p_metadata jsonb default '{}'::jsonb
) returns jsonb language plpgsql security definer set search_path=public as $$
declare r public.world8_academy_checkride_receipts%rowtype; q jsonb;
begin
  select * into r from public.world8_academy_checkride_receipts where checkride_receipt_id=p_checkride_receipt_id;
  if not found then raise exception 'CHECKRIDE_RECEIPT_NOT_FOUND'; end if;
  if r.result<>'PASS' then raise exception 'PASS_CHECKRIDE_REQUIRED'; end if;
  if p_issued_by<>'service-world8-qualification-authority' then raise exception 'QUALIFICATION_AUTHORITY_REQUIRED'; end if;
  if not exists(select 1 from public.world8_actor_registry where actor_id=p_issued_by and status='ACTIVE') then raise exception 'ACTIVE_QUALIFICATION_AUTHORITY_REQUIRED'; end if;
  if p_expires_at is null or p_expires_at<=clock_timestamp() or p_expires_at>clock_timestamp()+interval '30 days' then raise exception 'QUALIFICATION_EXPIRY_OUT_OF_RANGE'; end if;
  q:=public.world8_actor_issue_qualification_v1(r.subject_actor_id,r.qualification_kind,r.qualification_ref,r.qualification_version,p_issued_by,r.evidence_refs||jsonb_build_array('checkride:'||r.checkride_receipt_id),p_expires_at,coalesce(p_metadata,'{}'::jsonb)||jsonb_build_object('checkride_receipt_id',r.checkride_receipt_id,'authorization_granted',false,'recurrent_training_required',true));
  return jsonb_build_object('schema','WORLD8_ACADEMY_LICENSE_ISSUE/1.0','checkride_receipt_id',r.checkride_receipt_id,'qualification',q,'authorization_granted',false);
end $$;

create or replace function public.world8_dev_access_grant_issue_v1(
  p_actor_id text,p_work_id text,p_workspace_id text,p_resource_kind text,p_resource_ref text,p_access_mode text,p_credential_ref text,p_expires_at timestamptz,
  p_evidence_refs jsonb default '[]'::jsonb,p_metadata jsonb default '{}'::jsonb
) returns jsonb language plpgsql security definer set search_path=public,extensions as $$
declare w public.world8_dev_workspaces%rowtype; v_now timestamptz:=clock_timestamp(); v_key text; v_hash text; v_id text;
begin
  if p_resource_kind not in ('GITHUB_BRANCH','SUPABASE_PROJECT','GOOGLE_DRIVE','GITHUB_REPO_READ') then raise exception 'INVALID_DEVELOPER_ACCESS_RESOURCE_KIND'; end if;
  if p_access_mode not in ('READ','BRANCH_WRITE','GOVERNED_MIGRATION','RPC') then raise exception 'INVALID_DEVELOPER_ACCESS_MODE'; end if;
  if p_credential_ref not in ('connector:github:world8','connector:supabase:world8','connector:google-drive:world8') then raise exception 'OPAQUE_APPROVED_CONNECTOR_REF_REQUIRED'; end if;
  if p_expires_at is null or p_expires_at<=v_now or p_expires_at>v_now+interval '4 hours' then raise exception 'DEVELOPER_ACCESS_EXPIRY_OUT_OF_RANGE'; end if;
  if not exists(select 1 from public.world8_actor_registry where actor_id=p_actor_id and status='ACTIVE') then raise exception 'ACTIVE_ACTOR_REQUIRED'; end if;
  select * into w from public.world8_dev_workspaces where workspace_id=p_workspace_id and state='ACTIVE';
  if not found or w.actor_id<>p_actor_id or w.work_id<>p_work_id then raise exception 'ACTIVE_BOUND_WORKSPACE_REQUIRED'; end if;
  if p_resource_kind='GITHUB_BRANCH' then
    if p_access_mode<>'BRANCH_WRITE' or p_credential_ref<>'connector:github:world8' then raise exception 'GITHUB_BRANCH_GRANT_CONTRACT_MISMATCH'; end if;
    if w.branch_ref in ('main','master') or p_resource_ref<>('github:saeedfaai/world-8:branch:'||w.branch_ref) then raise exception 'GITHUB_BRANCH_MUST_MATCH_ISOLATED_WORKSPACE'; end if;
  elsif p_resource_kind='SUPABASE_PROJECT' then
    if p_credential_ref<>'connector:supabase:world8' or p_resource_ref<>'supabase:ogiqujrubsvzohqremuv' or p_access_mode not in ('GOVERNED_MIGRATION','RPC') then raise exception 'SUPABASE_GRANT_CONTRACT_MISMATCH'; end if;
  end if;
  v_key:=encode(extensions.digest(p_actor_id||'|'||p_work_id||'|'||p_workspace_id||'|'||p_resource_kind||'|'||p_resource_ref||'|'||p_access_mode,'sha256'),'hex');
  v_hash:=encode(extensions.digest(v_key||'|GRANT|'||p_credential_ref||'|'||p_expires_at::text||'|'||coalesce(p_evidence_refs,'[]'::jsonb)::text||'|'||v_now::text,'sha256'),'hex');
  v_id:='access-grant-'||substr(v_hash,1,28);
  insert into public.world8_dev_access_grant_receipts(access_receipt_id,grant_key,receipt_kind,actor_id,work_id,workspace_id,resource_kind,resource_ref,access_mode,credential_ref,scope,expires_at,evidence_refs,metadata,created_by,content_hash,created_at)
  values(v_id,v_key,'GRANT',p_actor_id,p_work_id,p_workspace_id,p_resource_kind,p_resource_ref,p_access_mode,p_credential_ref,jsonb_build_object('work_id',p_work_id,'workspace_id',p_workspace_id,'branch_ref',w.branch_ref),p_expires_at,coalesce(p_evidence_refs,'[]'::jsonb),coalesce(p_metadata,'{}'::jsonb)||jsonb_build_object('raw_secret_present',false,'authority_granted',false),p_actor_id,v_hash,v_now);
  return jsonb_build_object('schema','WORLD8_DEV_ACCESS_GRANT/1.0','access_receipt_id',v_id,'grant_key',v_key,'resource_kind',p_resource_kind,'resource_ref',p_resource_ref,'access_mode',p_access_mode,'credential_ref',p_credential_ref,'expires_at',p_expires_at,'raw_secret_returned',false,'authority_granted',false);
end $$;

create or replace function public.world8_dev_access_grant_revoke_v1(p_grant_key text,p_created_by text,p_reason text)
returns jsonb language plpgsql security definer set search_path=public,extensions as $$
declare g public.world8_dev_access_grant_receipts%rowtype; v_now timestamptz:=clock_timestamp(); v_hash text; v_id text;
begin
  select * into g from public.world8_dev_access_grant_receipts where grant_key=p_grant_key order by created_at desc limit 1;
  if not found or g.receipt_kind<>'GRANT' then raise exception 'ACTIVE_GRANT_NOT_FOUND'; end if;
  v_hash:=encode(extensions.digest(p_grant_key||'|REVOKE|'||coalesce(p_reason,'')||'|'||v_now::text,'sha256'),'hex'); v_id:='access-revoke-'||substr(v_hash,1,28);
  insert into public.world8_dev_access_grant_receipts(access_receipt_id,grant_key,receipt_kind,actor_id,work_id,workspace_id,resource_kind,resource_ref,access_mode,credential_ref,scope,expires_at,evidence_refs,metadata,created_by,content_hash,created_at)
  values(v_id,g.grant_key,'REVOKE',g.actor_id,g.work_id,g.workspace_id,g.resource_kind,g.resource_ref,g.access_mode,g.credential_ref,g.scope,v_now,g.evidence_refs,jsonb_build_object('reason',p_reason,'raw_secret_present',false,'authority_granted',false),p_created_by,v_hash,v_now);
  return jsonb_build_object('schema','WORLD8_DEV_ACCESS_REVOKE/1.0','access_receipt_id',v_id,'grant_key',p_grant_key,'state','REVOKED','raw_secret_returned',false);
end $$;

create or replace function public.world8_dev_access_grants_snapshot_v1(p_actor_id text,p_work_id text,p_workspace_id text)
returns jsonb language sql security definer set search_path=public as $$
with latest as (
  select distinct on (grant_key) * from public.world8_dev_access_grant_receipts
  where actor_id=p_actor_id and work_id=p_work_id and workspace_id=p_workspace_id
  order by grant_key,created_at desc
), active as (
  select * from latest where receipt_kind='GRANT' and expires_at>clock_timestamp()
)
select jsonb_build_object('schema','WORLD8_DEV_ACCESS_GRANTS_SNAPSHOT/1.0','actor_id',p_actor_id,'work_id',p_work_id,'workspace_id',p_workspace_id,
  'grants',coalesce(jsonb_agg(jsonb_build_object('access_receipt_id',access_receipt_id,'grant_key',grant_key,'resource_kind',resource_kind,'resource_ref',resource_ref,'access_mode',access_mode,'credential_ref',credential_ref,'scope',scope,'expires_at',expires_at) order by resource_kind,resource_ref) filter (where grant_key is not null),'[]'::jsonb),
  'raw_secret_returned',false,'authority_granted',false)
from active;
$$;

revoke all on function public.world8_academy_record_checkride_v1(text,text,text,text,numeric,jsonb,jsonb) from public,anon,authenticated;
revoke all on function public.world8_academy_issue_license_v1(text,text,timestamptz,jsonb) from public,anon,authenticated;
revoke all on function public.world8_dev_access_grant_issue_v1(text,text,text,text,text,text,text,timestamptz,jsonb,jsonb) from public,anon,authenticated;
revoke all on function public.world8_dev_access_grant_revoke_v1(text,text,text) from public,anon,authenticated;
revoke all on function public.world8_dev_access_grants_snapshot_v1(text,text,text) from public,anon,authenticated;
grant execute on function public.world8_academy_record_checkride_v1(text,text,text,text,numeric,jsonb,jsonb) to service_role;
grant execute on function public.world8_academy_issue_license_v1(text,text,timestamptz,jsonb) to service_role;
grant execute on function public.world8_dev_access_grant_issue_v1(text,text,text,text,text,text,text,timestamptz,jsonb,jsonb) to service_role;
grant execute on function public.world8_dev_access_grant_revoke_v1(text,text,text) to service_role;
grant execute on function public.world8_dev_access_grants_snapshot_v1(text,text,text) to service_role;
