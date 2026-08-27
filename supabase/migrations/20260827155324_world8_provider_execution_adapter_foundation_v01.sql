create table if not exists public.world8_provider_execution_adapters (
  adapter_id text primary key,
  world_id text not null default 'world-001',
  provider text not null,
  adapter_kind text not null check (adapter_kind in ('REAL_EXTERNAL','MOCK_INTERNAL')),
  status text not null default 'REGISTERED' check (status in ('REGISTERED','ACTIVE','DEGRADED','DISABLED')),
  credential_ref text,
  credential_state text not null default 'UNVERIFIED' check (credential_state in ('UNVERIFIED','NOT_REQUIRED','VERIFIED','REVOKED')),
  supported_models jsonb not null default '[]'::jsonb check (jsonb_typeof(supported_models)='array'),
  capabilities jsonb not null default '[]'::jsonb check (jsonb_typeof(capabilities)='array'),
  config jsonb not null default '{}'::jsonb check (jsonb_typeof(config)='object'),
  metadata jsonb not null default '{}'::jsonb check (jsonb_typeof(metadata)='object'),
  created_by text not null,
  created_at timestamptz not null default clock_timestamp(),
  updated_at timestamptz not null default clock_timestamp()
);

create table if not exists public.world8_provider_execution_requests (
  request_id text primary key,
  world_id text not null default 'world-001',
  assignment_id text references public.world8_mason_assignments(assignment_id),
  actor_id text not null references public.world8_actor_registry(actor_id),
  work_id text not null references public.world8_dev_work_items(work_id),
  workspace_id text not null references public.world8_dev_workspaces(workspace_id),
  adapter_id text not null references public.world8_provider_execution_adapters(adapter_id),
  requested_provider text not null,
  requested_model_id text,
  task_summary text not null check (char_length(task_summary) between 1 and 2000),
  input_refs jsonb not null default '[]'::jsonb check (jsonb_typeof(input_refs)='array'),
  context_refs jsonb not null default '[]'::jsonb check (jsonb_typeof(context_refs)='array'),
  idempotency_key text not null,
  request_hash text not null,
  state text not null default 'QUEUED' check (state in ('QUEUED','RUNNING','SUCCEEDED','FAILED','CANCELLED')),
  execution_id text references public.world8_actor_executions(execution_id),
  claim_token text,
  claimed_at timestamptz,
  last_heartbeat_at timestamptz,
  completed_at timestamptz,
  error_code text,
  metadata jsonb not null default '{}'::jsonb check (jsonb_typeof(metadata)='object'),
  created_at timestamptz not null default clock_timestamp(),
  updated_at timestamptz not null default clock_timestamp(),
  unique(world_id,idempotency_key)
);

create table if not exists public.world8_provider_execution_receipts (
  receipt_id text primary key,
  world_id text not null default 'world-001',
  request_id text not null references public.world8_provider_execution_requests(request_id),
  execution_id text references public.world8_actor_executions(execution_id),
  adapter_id text not null references public.world8_provider_execution_adapters(adapter_id),
  receipt_kind text not null check (receipt_kind in ('ENQUEUED','STARTED','SUCCEEDED','FAILED','CANCELLED')),
  provider text not null,
  model_id text,
  output_refs jsonb not null default '[]'::jsonb check (jsonb_typeof(output_refs)='array'),
  evidence_refs jsonb not null default '[]'::jsonb check (jsonb_typeof(evidence_refs)='array'),
  error_code text,
  metadata jsonb not null default '{}'::jsonb check (jsonb_typeof(metadata)='object'),
  content_hash text not null,
  created_at timestamptz not null default clock_timestamp()
);

create index if not exists world8_provider_exec_requests_state_idx on public.world8_provider_execution_requests(state,created_at);
create index if not exists world8_provider_exec_requests_assignment_idx on public.world8_provider_execution_requests(assignment_id,state);
create index if not exists world8_provider_exec_receipts_request_idx on public.world8_provider_execution_receipts(request_id,created_at);

create or replace function public.world8_provider_execution_json_safe_v1(p_value jsonb)
returns boolean
language sql immutable
set search_path=public
as $$
with recursive walk(k,v) as (
  select null::text, coalesce(p_value,'{}'::jsonb)
  union all
  select x.k,x.v
  from walk w
  cross join lateral (
    select e.key as k,e.value as v from jsonb_each(w.v) e where jsonb_typeof(w.v)='object'
    union all
    select null::text as k,a.value as v from jsonb_array_elements(w.v) a where jsonb_typeof(w.v)='array'
  ) x
)
select not exists (
  select 1 from walk
  where lower(coalesce(k,'')) in (
    'api_key','apikey','api_token','access_token','refresh_token','bearer_token','client_secret','secret_value','credential_value','password',
    'private_reasoning','reasoning_trace','chain_of_thought','chainofthought','hidden_reasoning','private_cot'
  )
);
$$;

create or replace function public.world8_provider_execution_text_safe_v1(p_text text)
returns boolean
language sql immutable
as $$
select coalesce(p_text,'') !~* '(sk-[A-Za-z0-9_-]{20,}|ghp_[A-Za-z0-9]{20,}|xox[baprs]-[A-Za-z0-9-]{20,}|Bearer[[:space:]]+[A-Za-z0-9._~+/-]{20,}|chain[ -]+of[ -]+thought|private[ -]+reasoning)';
$$;

create or replace function public.world8_provider_execution_receipts_append_only_v1()
returns trigger language plpgsql security definer set search_path=public as $$
begin raise exception 'WORLD8_PROVIDER_EXECUTION_RECEIPTS_APPEND_ONLY'; end $$;

drop trigger if exists world8_provider_exec_receipts_append_only_trg on public.world8_provider_execution_receipts;
create trigger world8_provider_exec_receipts_append_only_trg before update or delete on public.world8_provider_execution_receipts for each row execute function public.world8_provider_execution_receipts_append_only_v1();

create or replace function public.world8_provider_execution_adapter_register_v1(
  p_adapter_id text,p_provider text,p_adapter_kind text,p_credential_ref text default null,
  p_supported_models jsonb default '[]'::jsonb,p_capabilities jsonb default '[]'::jsonb,
  p_config jsonb default '{}'::jsonb,p_metadata jsonb default '{}'::jsonb,p_created_by text default 'human-root'
) returns jsonb language plpgsql security definer set search_path=public,extensions as $$
declare v_now timestamptz:=clock_timestamp(); v_state text;
begin
  if p_adapter_kind not in ('REAL_EXTERNAL','MOCK_INTERNAL') then raise exception 'INVALID_PROVIDER_ADAPTER_KIND'; end if;
  if coalesce(btrim(p_adapter_id),'')='' or coalesce(btrim(p_provider),'')='' then raise exception 'ADAPTER_ID_PROVIDER_REQUIRED'; end if;
  if jsonb_typeof(coalesce(p_supported_models,'[]'::jsonb))<>'array' or jsonb_typeof(coalesce(p_capabilities,'[]'::jsonb))<>'array' then raise exception 'ADAPTER_ARRAY_CONTRACT_REQUIRED'; end if;
  if not public.world8_provider_execution_json_safe_v1(coalesce(p_config,'{}'::jsonb)) or not public.world8_provider_execution_json_safe_v1(coalesce(p_metadata,'{}'::jsonb)) then raise exception 'PROVIDER_ADAPTER_SECRET_OR_PRIVATE_REASONING_REJECTED'; end if;
  if p_adapter_kind='REAL_EXTERNAL' and coalesce(btrim(p_credential_ref),'')='' then raise exception 'OPAQUE_CREDENTIAL_REF_REQUIRED'; end if;
  if p_credential_ref is not null and p_credential_ref !~ '^(secretref:|vault:|envref:|connector:)[A-Za-z0-9._:/-]+$' then raise exception 'INVALID_OPAQUE_CREDENTIAL_REF'; end if;
  v_state:=case when p_adapter_kind='MOCK_INTERNAL' then 'NOT_REQUIRED' else 'UNVERIFIED' end;
  insert into public.world8_provider_execution_adapters(adapter_id,provider,adapter_kind,status,credential_ref,credential_state,supported_models,capabilities,config,metadata,created_by,created_at,updated_at)
  values(p_adapter_id,p_provider,p_adapter_kind,'ACTIVE',p_credential_ref,v_state,coalesce(p_supported_models,'[]'::jsonb),coalesce(p_capabilities,'[]'::jsonb),coalesce(p_config,'{}'::jsonb),coalesce(p_metadata,'{}'::jsonb),p_created_by,v_now,v_now)
  on conflict(adapter_id) do update set provider=excluded.provider,adapter_kind=excluded.adapter_kind,status='ACTIVE',credential_ref=excluded.credential_ref,credential_state=v_state,supported_models=excluded.supported_models,capabilities=excluded.capabilities,config=excluded.config,metadata=excluded.metadata,updated_at=v_now;
  return jsonb_build_object('schema','WORLD8_PROVIDER_EXECUTION_ADAPTER/1.0','adapter_id',p_adapter_id,'provider',p_provider,'adapter_kind',p_adapter_kind,'status','ACTIVE','credential_state',v_state,'live_ready',false);
end $$;

create or replace function public.world8_provider_execution_readiness_v1(p_adapter_id text)
returns jsonb language plpgsql security definer set search_path=public as $$
declare v public.world8_provider_execution_adapters%rowtype;
begin
  select * into v from public.world8_provider_execution_adapters where adapter_id=p_adapter_id;
  if not found then return jsonb_build_object('schema','WORLD8_PROVIDER_ADAPTER_READINESS/1.0','adapter_id',p_adapter_id,'gate_state','BLOCKED','live_ready',false,'reason_code','ADAPTER_NOT_FOUND'); end if;
  if v.status<>'ACTIVE' then return jsonb_build_object('schema','WORLD8_PROVIDER_ADAPTER_READINESS/1.0','adapter_id',p_adapter_id,'gate_state','BLOCKED','live_ready',false,'reason_code','ADAPTER_NOT_ACTIVE'); end if;
  if v.adapter_kind='MOCK_INTERNAL' then return jsonb_build_object('schema','WORLD8_PROVIDER_ADAPTER_READINESS/1.0','adapter_id',p_adapter_id,'gate_state','PASS','readiness_state','TEST_ONLY','live_ready',false,'reason_code','MOCK_INTERNAL_TEST_ONLY'); end if;
  return jsonb_build_object('schema','WORLD8_PROVIDER_ADAPTER_READINESS/1.0','adapter_id',p_adapter_id,'gate_state','BLOCKED','readiness_state','NOT_READY','live_ready',false,'credential_state',v.credential_state,'reason_code','CREDENTIAL_BROKER_NOT_IMPLEMENTED');
end $$;

create or replace function public.world8_provider_execution_enqueue_v1(
  p_assignment_id text,p_actor_id text,p_work_id text,p_workspace_id text,p_adapter_id text,p_requested_model_id text,
  p_task_summary text,p_input_refs jsonb default '[]'::jsonb,p_context_refs jsonb default '[]'::jsonb,p_idempotency_key text default null,p_metadata jsonb default '{}'::jsonb
) returns jsonb language plpgsql security definer set search_path=public,extensions as $$
declare v_adapter public.world8_provider_execution_adapters%rowtype; v_ready jsonb; v_assign public.world8_mason_assignments%rowtype; v_now timestamptz:=clock_timestamp(); v_key text; v_hash text; v_id text; v_existing public.world8_provider_execution_requests%rowtype; v_receipt_hash text; v_receipt_id text;
begin
  if not exists(select 1 from public.world8_actor_registry a where a.actor_id=p_actor_id and a.status='ACTIVE') then raise exception 'ACTIVE_ACTOR_REQUIRED'; end if;
  if not exists(select 1 from public.world8_dev_work_items w where w.work_id=p_work_id and w.actor_ref=p_actor_id) then raise exception 'WORK_ACTOR_MISMATCH'; end if;
  if not exists(select 1 from public.world8_dev_workspaces ws where ws.workspace_id=p_workspace_id and ws.work_id=p_work_id and ws.actor_id=p_actor_id and ws.state='ACTIVE') then raise exception 'ACTIVE_WORKSPACE_BINDING_REQUIRED'; end if;
  if p_assignment_id is not null then
    select * into v_assign from public.world8_mason_assignments where assignment_id=p_assignment_id;
    if not found or v_assign.actor_id<>p_actor_id or v_assign.work_id<>p_work_id or v_assign.workspace_id<>p_workspace_id or v_assign.state<>'CODING' then raise exception 'ASSIGNMENT_ACTOR_WORK_WORKSPACE_BINDING_REQUIRED'; end if;
  end if;
  select * into v_adapter from public.world8_provider_execution_adapters where adapter_id=p_adapter_id;
  if not found then raise exception 'PROVIDER_ADAPTER_NOT_FOUND'; end if;
  v_ready:=public.world8_provider_execution_readiness_v1(p_adapter_id);
  if v_ready->>'gate_state'<>'PASS' then raise exception 'PROVIDER_ADAPTER_NOT_READY:%',v_ready->>'reason_code'; end if;
  if not public.world8_provider_execution_text_safe_v1(p_task_summary) then raise exception 'EXECUTION_TASK_SECRET_OR_PRIVATE_REASONING_REJECTED'; end if;
  if jsonb_typeof(coalesce(p_input_refs,'[]'::jsonb))<>'array' or jsonb_typeof(coalesce(p_context_refs,'[]'::jsonb))<>'array' then raise exception 'EXECUTION_REFS_MUST_BE_ARRAYS'; end if;
  if not public.world8_provider_execution_json_safe_v1(coalesce(p_input_refs,'[]'::jsonb)) or not public.world8_provider_execution_json_safe_v1(coalesce(p_context_refs,'[]'::jsonb)) or not public.world8_provider_execution_json_safe_v1(coalesce(p_metadata,'{}'::jsonb)) then raise exception 'EXECUTION_REQUEST_SECRET_OR_PRIVATE_REASONING_REJECTED'; end if;
  v_key:=coalesce(nullif(btrim(p_idempotency_key),''),encode(extensions.digest(p_actor_id||'|'||p_work_id||'|'||p_workspace_id||'|'||p_adapter_id||'|'||p_task_summary,'sha256'),'hex'));
  v_hash:=encode(extensions.digest(jsonb_build_object('assignment_id',p_assignment_id,'actor_id',p_actor_id,'work_id',p_work_id,'workspace_id',p_workspace_id,'adapter_id',p_adapter_id,'model_id',p_requested_model_id,'task_summary',p_task_summary,'input_refs',coalesce(p_input_refs,'[]'::jsonb),'context_refs',coalesce(p_context_refs,'[]'::jsonb))::text,'sha256'),'hex');
  select * into v_existing from public.world8_provider_execution_requests where world_id='world-001' and idempotency_key=v_key;
  if found then
    if v_existing.request_hash<>v_hash then raise exception 'EXECUTION_IDEMPOTENCY_COLLISION'; end if;
    return jsonb_build_object('schema','WORLD8_PROVIDER_EXECUTION_REQUEST/1.0','request_id',v_existing.request_id,'state',v_existing.state,'idempotent_replay',true,'live_provider_invoked',false);
  end if;
  v_id:='provider-request-'||substr(v_hash,1,28);
  insert into public.world8_provider_execution_requests(request_id,assignment_id,actor_id,work_id,workspace_id,adapter_id,requested_provider,requested_model_id,task_summary,input_refs,context_refs,idempotency_key,request_hash,state,metadata,created_at,updated_at)
  values(v_id,p_assignment_id,p_actor_id,p_work_id,p_workspace_id,p_adapter_id,v_adapter.provider,p_requested_model_id,p_task_summary,coalesce(p_input_refs,'[]'::jsonb),coalesce(p_context_refs,'[]'::jsonb),v_key,v_hash,'QUEUED',coalesce(p_metadata,'{}'::jsonb),v_now,v_now);
  v_receipt_hash:=encode(extensions.digest(v_id||'|ENQUEUED|'||v_now::text,'sha256'),'hex'); v_receipt_id:='provider-receipt-'||substr(v_receipt_hash,1,28);
  insert into public.world8_provider_execution_receipts(receipt_id,request_id,adapter_id,receipt_kind,provider,model_id,evidence_refs,metadata,content_hash,created_at)
  values(v_receipt_id,v_id,p_adapter_id,'ENQUEUED',v_adapter.provider,p_requested_model_id,jsonb_build_array('work:'||p_work_id,'workspace:'||p_workspace_id),jsonb_build_object('assignment_id',p_assignment_id,'live_provider_invoked',false),v_receipt_hash,v_now);
  return jsonb_build_object('schema','WORLD8_PROVIDER_EXECUTION_REQUEST/1.0','request_id',v_id,'state','QUEUED','adapter_id',p_adapter_id,'readiness',v_ready,'live_provider_invoked',false,'receipt_id',v_receipt_id);
end $$;

create or replace function public.world8_provider_execution_claim_v1(p_request_id text,p_adapter_id text,p_claim_ttl_seconds integer default 300)
returns jsonb language plpgsql security definer set search_path=public,extensions as $$
declare v_req public.world8_provider_execution_requests%rowtype; v_adapter public.world8_provider_execution_adapters%rowtype; v_ready jsonb; v_exec jsonb; v_now timestamptz:=clock_timestamp(); v_token text; v_hash text; v_receipt_id text;
begin
  if p_claim_ttl_seconds<30 or p_claim_ttl_seconds>900 then raise exception 'EXECUTION_CLAIM_TTL_OUT_OF_RANGE'; end if;
  select * into v_req from public.world8_provider_execution_requests where request_id=p_request_id for update;
  if not found then raise exception 'EXECUTION_REQUEST_NOT_FOUND'; end if;
  if v_req.state<>'QUEUED' then raise exception 'EXECUTION_REQUEST_NOT_QUEUED'; end if;
  if v_req.adapter_id<>p_adapter_id then raise exception 'EXECUTION_ADAPTER_MISMATCH'; end if;
  select * into v_adapter from public.world8_provider_execution_adapters where adapter_id=p_adapter_id;
  v_ready:=public.world8_provider_execution_readiness_v1(p_adapter_id);
  if v_ready->>'gate_state'<>'PASS' then raise exception 'PROVIDER_ADAPTER_NOT_READY:%',v_ready->>'reason_code'; end if;
  if v_req.assignment_id is not null and not exists(select 1 from public.world8_mason_assignments a where a.assignment_id=v_req.assignment_id and a.actor_id=v_req.actor_id and a.work_id=v_req.work_id and a.workspace_id=v_req.workspace_id and a.state='CODING') then raise exception 'ASSIGNMENT_BINDING_CHANGED_BEFORE_EXECUTION'; end if;
  v_token:=substr(encode(extensions.digest(p_request_id||'|'||p_adapter_id||'|'||v_now::text,'sha256'),'hex'),1,32);
  v_exec:=public.world8_actor_start_execution_v1(v_req.actor_id,v_adapter.provider,v_req.requested_model_id,p_request_id,'W8-PROVIDER-EXECUTION',jsonb_build_object('work_id',v_req.work_id,'workspace_id',v_req.workspace_id,'adapter_id',p_adapter_id,'adapter_kind',v_adapter.adapter_kind),jsonb_build_object('provider_execution_request_id',p_request_id,'assignment_id',v_req.assignment_id,'live_provider_invoked',false,'test_only',v_adapter.adapter_kind='MOCK_INTERNAL'));
  if v_req.assignment_id is not null then perform public.world8_mason_pool_bind_execution_v1(v_req.assignment_id,v_exec->>'execution_id'); end if;
  update public.world8_provider_execution_requests set state='RUNNING',execution_id=v_exec->>'execution_id',claim_token=v_token,claimed_at=v_now,last_heartbeat_at=v_now,updated_at=v_now where request_id=p_request_id;
  v_hash:=encode(extensions.digest(p_request_id||'|STARTED|'||(v_exec->>'execution_id')||'|'||v_now::text,'sha256'),'hex'); v_receipt_id:='provider-receipt-'||substr(v_hash,1,28);
  insert into public.world8_provider_execution_receipts(receipt_id,request_id,execution_id,adapter_id,receipt_kind,provider,model_id,evidence_refs,metadata,content_hash,created_at)
  values(v_receipt_id,p_request_id,v_exec->>'execution_id',p_adapter_id,'STARTED',v_adapter.provider,v_req.requested_model_id,jsonb_build_array('execution:'||(v_exec->>'execution_id')),jsonb_build_object('claim_token_hash',encode(extensions.digest(v_token,'sha256'),'hex'),'live_provider_invoked',false,'test_only',v_adapter.adapter_kind='MOCK_INTERNAL'),v_hash,v_now);
  return jsonb_build_object('schema','WORLD8_PROVIDER_EXECUTION_CLAIM/1.0','request_id',p_request_id,'execution_id',v_exec->>'execution_id','claim_token',v_token,'state','RUNNING','adapter_kind',v_adapter.adapter_kind,'live_provider_invoked',false,'readiness',v_ready,'receipt_id',v_receipt_id);
end $$;

create or replace function public.world8_provider_execution_heartbeat_v1(p_request_id text,p_claim_token text,p_metadata jsonb default '{}'::jsonb)
returns jsonb language plpgsql security definer set search_path=public as $$
declare v_req public.world8_provider_execution_requests%rowtype; v_now timestamptz:=clock_timestamp();
begin
  if not public.world8_provider_execution_json_safe_v1(coalesce(p_metadata,'{}'::jsonb)) then raise exception 'EXECUTION_HEARTBEAT_SECRET_OR_PRIVATE_REASONING_REJECTED'; end if;
  select * into v_req from public.world8_provider_execution_requests where request_id=p_request_id for update;
  if not found or v_req.state<>'RUNNING' then raise exception 'RUNNING_EXECUTION_REQUEST_REQUIRED'; end if;
  if v_req.claim_token is distinct from p_claim_token then raise exception 'EXECUTION_CLAIM_TOKEN_MISMATCH'; end if;
  perform public.world8_actor_execution_heartbeat_v1(v_req.execution_id,coalesce(p_metadata,'{}'::jsonb)||jsonb_build_object('provider_execution_request_id',p_request_id));
  update public.world8_provider_execution_requests set last_heartbeat_at=v_now,updated_at=v_now where request_id=p_request_id;
  return jsonb_build_object('schema','WORLD8_PROVIDER_EXECUTION_HEARTBEAT/1.0','request_id',p_request_id,'execution_id',v_req.execution_id,'state','RUNNING','heartbeat_at',v_now);
end $$;

create or replace function public.world8_provider_execution_complete_v1(p_request_id text,p_claim_token text,p_output_refs jsonb default '[]'::jsonb,p_evidence_refs jsonb default '[]'::jsonb,p_metadata jsonb default '{}'::jsonb)
returns jsonb language plpgsql security definer set search_path=public,extensions as $$
declare v_req public.world8_provider_execution_requests%rowtype; v_adapter public.world8_provider_execution_adapters%rowtype; v_now timestamptz:=clock_timestamp(); v_hash text; v_receipt_id text;
begin
  if jsonb_typeof(coalesce(p_output_refs,'[]'::jsonb))<>'array' or jsonb_typeof(coalesce(p_evidence_refs,'[]'::jsonb))<>'array' then raise exception 'EXECUTION_OUTPUT_EVIDENCE_REFS_MUST_BE_ARRAYS'; end if;
  if not public.world8_provider_execution_json_safe_v1(coalesce(p_output_refs,'[]'::jsonb)) or not public.world8_provider_execution_json_safe_v1(coalesce(p_evidence_refs,'[]'::jsonb)) or not public.world8_provider_execution_json_safe_v1(coalesce(p_metadata,'{}'::jsonb)) then raise exception 'EXECUTION_RESULT_SECRET_OR_PRIVATE_REASONING_REJECTED'; end if;
  select * into v_req from public.world8_provider_execution_requests where request_id=p_request_id for update;
  if not found or v_req.state<>'RUNNING' then raise exception 'RUNNING_EXECUTION_REQUEST_REQUIRED'; end if;
  if v_req.claim_token is distinct from p_claim_token then raise exception 'EXECUTION_CLAIM_TOKEN_MISMATCH'; end if;
  select * into v_adapter from public.world8_provider_execution_adapters where adapter_id=v_req.adapter_id;
  perform public.world8_actor_finish_execution_v1(v_req.execution_id,'COMPLETED',coalesce(p_metadata,'{}'::jsonb)||jsonb_build_object('provider_execution_request_id',p_request_id,'test_only',v_adapter.adapter_kind='MOCK_INTERNAL'));
  update public.world8_provider_execution_requests set state='SUCCEEDED',completed_at=v_now,updated_at=v_now where request_id=p_request_id;
  v_hash:=encode(extensions.digest(p_request_id||'|SUCCEEDED|'||v_req.execution_id||'|'||v_now::text,'sha256'),'hex'); v_receipt_id:='provider-receipt-'||substr(v_hash,1,28);
  insert into public.world8_provider_execution_receipts(receipt_id,request_id,execution_id,adapter_id,receipt_kind,provider,model_id,output_refs,evidence_refs,metadata,content_hash,created_at)
  values(v_receipt_id,p_request_id,v_req.execution_id,v_req.adapter_id,'SUCCEEDED',v_adapter.provider,v_req.requested_model_id,coalesce(p_output_refs,'[]'::jsonb),coalesce(p_evidence_refs,'[]'::jsonb),coalesce(p_metadata,'{}'::jsonb)||jsonb_build_object('live_provider_invoked',false,'test_only',v_adapter.adapter_kind='MOCK_INTERNAL'),v_hash,v_now);
  return jsonb_build_object('schema','WORLD8_PROVIDER_EXECUTION_RESULT/1.0','request_id',p_request_id,'execution_id',v_req.execution_id,'state','SUCCEEDED','live_provider_invoked',false,'test_only',v_adapter.adapter_kind='MOCK_INTERNAL','receipt_id',v_receipt_id);
end $$;

create or replace function public.world8_provider_execution_fail_v1(p_request_id text,p_claim_token text,p_error_code text,p_evidence_refs jsonb default '[]'::jsonb,p_metadata jsonb default '{}'::jsonb)
returns jsonb language plpgsql security definer set search_path=public,extensions as $$
declare v_req public.world8_provider_execution_requests%rowtype; v_adapter public.world8_provider_execution_adapters%rowtype; v_now timestamptz:=clock_timestamp(); v_hash text; v_receipt_id text;
begin
  if not public.world8_provider_execution_json_safe_v1(coalesce(p_evidence_refs,'[]'::jsonb)) or not public.world8_provider_execution_json_safe_v1(coalesce(p_metadata,'{}'::jsonb)) then raise exception 'EXECUTION_FAILURE_SECRET_OR_PRIVATE_REASONING_REJECTED'; end if;
  select * into v_req from public.world8_provider_execution_requests where request_id=p_request_id for update;
  if not found or v_req.state<>'RUNNING' then raise exception 'RUNNING_EXECUTION_REQUEST_REQUIRED'; end if;
  if v_req.claim_token is distinct from p_claim_token then raise exception 'EXECUTION_CLAIM_TOKEN_MISMATCH'; end if;
  select * into v_adapter from public.world8_provider_execution_adapters where adapter_id=v_req.adapter_id;
  perform public.world8_actor_finish_execution_v1(v_req.execution_id,'FAILED',coalesce(p_metadata,'{}'::jsonb)||jsonb_build_object('provider_execution_request_id',p_request_id,'error_code',p_error_code));
  update public.world8_provider_execution_requests set state='FAILED',completed_at=v_now,error_code=p_error_code,updated_at=v_now where request_id=p_request_id;
  v_hash:=encode(extensions.digest(p_request_id||'|FAILED|'||coalesce(p_error_code,'UNKNOWN')||'|'||v_now::text,'sha256'),'hex'); v_receipt_id:='provider-receipt-'||substr(v_hash,1,28);
  insert into public.world8_provider_execution_receipts(receipt_id,request_id,execution_id,adapter_id,receipt_kind,provider,model_id,evidence_refs,error_code,metadata,content_hash,created_at)
  values(v_receipt_id,p_request_id,v_req.execution_id,v_req.adapter_id,'FAILED',v_adapter.provider,v_req.requested_model_id,coalesce(p_evidence_refs,'[]'::jsonb),p_error_code,coalesce(p_metadata,'{}'::jsonb)||jsonb_build_object('live_provider_invoked',false,'test_only',v_adapter.adapter_kind='MOCK_INTERNAL'),v_hash,v_now);
  return jsonb_build_object('schema','WORLD8_PROVIDER_EXECUTION_RESULT/1.0','request_id',p_request_id,'execution_id',v_req.execution_id,'state','FAILED','live_provider_invoked',false,'receipt_id',v_receipt_id);
end $$;

create or replace function public.world8_provider_execution_snapshot_v1()
returns jsonb language sql security definer set search_path=public as $$
select jsonb_build_object(
 'schema','WORLD8_PROVIDER_EXECUTION_SNAPSHOT/1.0',
 'credential_broker','NOT_IMPLEMENTED',
 'live_external_ready',false,
 'adapters',coalesce((select jsonb_agg(jsonb_build_object('adapter_id',a.adapter_id,'provider',a.provider,'adapter_kind',a.adapter_kind,'status',a.status,'credential_state',a.credential_state,'readiness',public.world8_provider_execution_readiness_v1(a.adapter_id)) order by a.adapter_id) from public.world8_provider_execution_adapters a),'[]'::jsonb),
 'requests',jsonb_build_object('queued',(select count(*) from public.world8_provider_execution_requests where state='QUEUED'),'running',(select count(*) from public.world8_provider_execution_requests where state='RUNNING'),'succeeded',(select count(*) from public.world8_provider_execution_requests where state='SUCCEEDED'),'failed',(select count(*) from public.world8_provider_execution_requests where state='FAILED')),
 'active_actor_executions',(select count(*) from public.world8_actor_executions where state='ACTIVE'),
 'generated_at',clock_timestamp()
);
$$;

insert into public.world8_provider_execution_adapters(adapter_id,provider,adapter_kind,status,credential_ref,credential_state,supported_models,capabilities,config,metadata,created_by)
values('adapter-world8-mock-internal-v1','MOCK','MOCK_INTERNAL','ACTIVE',null,'NOT_REQUIRED',jsonb_build_array('mock-model-v1'),jsonb_build_array('LIFECYCLE_TEST'),jsonb_build_object('network_calls',false),jsonb_build_object('test_only',true,'live_ready',false,'purpose','Prove provider-neutral request/execution/receipt lifecycle without external model invocation'),'chatgpt-mason')
on conflict(adapter_id) do nothing;

revoke all on public.world8_provider_execution_adapters,public.world8_provider_execution_requests,public.world8_provider_execution_receipts from public,anon,authenticated;
grant select on public.world8_provider_execution_adapters,public.world8_provider_execution_requests,public.world8_provider_execution_receipts to service_role;
revoke all on function public.world8_provider_execution_adapter_register_v1(text,text,text,text,jsonb,jsonb,jsonb,jsonb,text), public.world8_provider_execution_readiness_v1(text), public.world8_provider_execution_enqueue_v1(text,text,text,text,text,text,text,jsonb,jsonb,text,jsonb), public.world8_provider_execution_claim_v1(text,text,integer), public.world8_provider_execution_heartbeat_v1(text,text,jsonb), public.world8_provider_execution_complete_v1(text,text,jsonb,jsonb,jsonb), public.world8_provider_execution_fail_v1(text,text,text,jsonb,jsonb), public.world8_provider_execution_snapshot_v1() from public,anon,authenticated;
grant execute on function public.world8_provider_execution_adapter_register_v1(text,text,text,text,jsonb,jsonb,jsonb,jsonb,text), public.world8_provider_execution_readiness_v1(text), public.world8_provider_execution_enqueue_v1(text,text,text,text,text,text,text,jsonb,jsonb,text,jsonb), public.world8_provider_execution_claim_v1(text,text,integer), public.world8_provider_execution_heartbeat_v1(text,text,jsonb), public.world8_provider_execution_complete_v1(text,text,jsonb,jsonb,jsonb), public.world8_provider_execution_fail_v1(text,text,text,jsonb,jsonb), public.world8_provider_execution_snapshot_v1() to service_role;
