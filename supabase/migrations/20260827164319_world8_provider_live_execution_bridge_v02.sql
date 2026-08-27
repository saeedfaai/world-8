-- World 8 strict REAL_EXTERNAL live execution bridge v2.
-- Provider/model remains Execution metadata; credential values remain outside DCP.

create table if not exists public.world8_provider_worker_dispatch_receipts (
  receipt_id text primary key,
  world_id text not null default 'world-001',
  request_id text not null references public.world8_provider_execution_requests(request_id),
  execution_id text references public.world8_actor_executions(execution_id),
  adapter_id text not null references public.world8_provider_execution_adapters(adapter_id),
  transport_id text not null references public.world8_provider_worker_transports(transport_id),
  credential_binding_id text references public.world8_provider_credential_bindings(binding_id),
  dispatch_state text not null check (dispatch_state in ('PREPARED','ACCEPTED','REJECTED')),
  evidence_refs jsonb not null default '[]'::jsonb check (jsonb_typeof(evidence_refs)='array'),
  metadata jsonb not null default '{}'::jsonb check (jsonb_typeof(metadata)='object'),
  content_hash text not null,
  created_at timestamptz not null default clock_timestamp()
);
create index if not exists world8_provider_worker_dispatch_request_idx on public.world8_provider_worker_dispatch_receipts(request_id,created_at);

create or replace function public.world8_provider_worker_dispatch_append_only_v1()
returns trigger language plpgsql security definer set search_path=public as $$
begin raise exception 'WORLD8_PROVIDER_WORKER_DISPATCH_RECEIPTS_APPEND_ONLY'; end $$;
drop trigger if exists world8_provider_worker_dispatch_append_only_trg on public.world8_provider_worker_dispatch_receipts;
create trigger world8_provider_worker_dispatch_append_only_trg before update or delete on public.world8_provider_worker_dispatch_receipts for each row execute function public.world8_provider_worker_dispatch_append_only_v1();

create or replace function public.world8_provider_execution_enqueue_v2(
  p_assignment_id text,p_actor_id text,p_work_id text,p_workspace_id text,p_adapter_id text,p_worker_transport_id text,p_credential_binding_id text,p_requested_model_id text,p_task_summary text,
  p_input_refs jsonb default '[]'::jsonb,p_context_refs jsonb default '[]'::jsonb,p_idempotency_key text default null,p_metadata jsonb default '{}'::jsonb
) returns jsonb language plpgsql security definer set search_path=public,extensions as $$
declare a public.world8_provider_execution_adapters%rowtype; ready jsonb; assn public.world8_mason_assignments%rowtype; b public.world8_provider_credential_bindings%rowtype; t public.world8_provider_worker_transports%rowtype; n timestamptz:=clock_timestamp(); k text; h text; id text; old public.world8_provider_execution_requests%rowtype; rh text; rid text;
begin
  if not exists(select 1 from public.world8_actor_registry x where x.actor_id=p_actor_id and x.status='ACTIVE') then raise exception 'ACTIVE_ACTOR_REQUIRED'; end if;
  if not exists(select 1 from public.world8_dev_work_items w where w.work_id=p_work_id and w.actor_ref=p_actor_id) then raise exception 'WORK_ACTOR_MISMATCH'; end if;
  if not exists(select 1 from public.world8_dev_workspaces ws where ws.workspace_id=p_workspace_id and ws.work_id=p_work_id and ws.actor_id=p_actor_id and ws.state='ACTIVE') then raise exception 'ACTIVE_WORKSPACE_BINDING_REQUIRED'; end if;
  if p_assignment_id is not null then select * into assn from public.world8_mason_assignments where assignment_id=p_assignment_id; if not found or assn.actor_id<>p_actor_id or assn.work_id<>p_work_id or assn.workspace_id<>p_workspace_id or assn.state<>'CODING' then raise exception 'ASSIGNMENT_ACTOR_WORK_WORKSPACE_BINDING_REQUIRED'; end if; end if;
  select * into a from public.world8_provider_execution_adapters where adapter_id=p_adapter_id and status='ACTIVE'; if not found then raise exception 'ACTIVE_PROVIDER_ADAPTER_REQUIRED'; end if;
  if a.adapter_kind<>'REAL_EXTERNAL' then raise exception 'REAL_EXTERNAL_ADAPTER_REQUIRED_FOR_V2'; end if;
  select * into b from public.world8_provider_credential_bindings where binding_id=p_credential_binding_id and adapter_id=p_adapter_id and status='ACTIVE'; if not found then raise exception 'ACTIVE_CREDENTIAL_BINDING_REQUIRED'; end if;
  select * into t from public.world8_provider_worker_transports where transport_id=p_worker_transport_id and adapter_id=p_adapter_id and status='ACTIVE'; if not found then raise exception 'ACTIVE_WORKER_TRANSPORT_REQUIRED'; end if;
  ready:=public.world8_provider_execution_readiness_v2(p_adapter_id,p_worker_transport_id);
  if ready->>'gate_state'<>'PASS' or coalesce((ready->>'live_ready')::boolean,false)<>true then raise exception 'PROVIDER_EXECUTION_V2_NOT_READY:%',ready->'blockers'; end if;
  if ready->>'binding_id'<>p_credential_binding_id then raise exception 'VERIFIED_CREDENTIAL_BINDING_MISMATCH'; end if;
  if not public.world8_provider_execution_text_safe_v1(p_task_summary) then raise exception 'EXECUTION_TASK_SECRET_OR_PRIVATE_REASONING_REJECTED'; end if;
  if jsonb_typeof(coalesce(p_input_refs,'[]'::jsonb))<>'array' or jsonb_typeof(coalesce(p_context_refs,'[]'::jsonb))<>'array' then raise exception 'EXECUTION_REFS_MUST_BE_ARRAYS'; end if;
  if not public.world8_provider_execution_json_safe_v1(coalesce(p_input_refs,'[]'::jsonb)) or not public.world8_provider_execution_json_safe_v1(coalesce(p_context_refs,'[]'::jsonb)) or not public.world8_provider_execution_json_safe_v1(coalesce(p_metadata,'{}'::jsonb)) then raise exception 'EXECUTION_REQUEST_SECRET_OR_PRIVATE_REASONING_REJECTED'; end if;
  k:=coalesce(nullif(btrim(p_idempotency_key),''),encode(extensions.digest(p_actor_id||'|'||p_work_id||'|'||p_workspace_id||'|'||p_adapter_id||'|'||p_worker_transport_id||'|'||p_credential_binding_id||'|'||p_task_summary,'sha256'),'hex'));
  h:=encode(extensions.digest(jsonb_build_object('assignment_id',p_assignment_id,'actor_id',p_actor_id,'work_id',p_work_id,'workspace_id',p_workspace_id,'adapter_id',p_adapter_id,'worker_transport_id',p_worker_transport_id,'credential_binding_id',p_credential_binding_id,'model_id',p_requested_model_id,'task_summary',p_task_summary,'input_refs',coalesce(p_input_refs,'[]'::jsonb),'context_refs',coalesce(p_context_refs,'[]'::jsonb))::text,'sha256'),'hex');
  select * into old from public.world8_provider_execution_requests where world_id='world-001' and idempotency_key=k;
  if found then if old.request_hash<>h then raise exception 'EXECUTION_IDEMPOTENCY_COLLISION'; end if; return jsonb_build_object('schema','WORLD8_PROVIDER_EXECUTION_REQUEST/2.0','request_id',old.request_id,'state',old.state,'idempotent_replay',true,'live_provider_invoked',false); end if;
  id:='provider-request-'||substr(h,1,28);
  insert into public.world8_provider_execution_requests(request_id,assignment_id,actor_id,work_id,workspace_id,adapter_id,requested_provider,requested_model_id,task_summary,input_refs,context_refs,idempotency_key,request_hash,state,metadata,credential_binding_id,worker_transport_id,created_at,updated_at)
  values(id,p_assignment_id,p_actor_id,p_work_id,p_workspace_id,p_adapter_id,a.provider,p_requested_model_id,p_task_summary,coalesce(p_input_refs,'[]'::jsonb),coalesce(p_context_refs,'[]'::jsonb),k,h,'QUEUED',coalesce(p_metadata,'{}'::jsonb),p_credential_binding_id,p_worker_transport_id,n,n);
  rh:=encode(extensions.digest(id||'|ENQUEUED_V2|'||n::text,'sha256'),'hex'); rid:='provider-receipt-'||substr(rh,1,28);
  insert into public.world8_provider_execution_receipts(receipt_id,request_id,adapter_id,receipt_kind,provider,model_id,evidence_refs,metadata,content_hash,created_at)
  values(rid,id,p_adapter_id,'ENQUEUED',a.provider,p_requested_model_id,jsonb_build_array('work:'||p_work_id,'workspace:'||p_workspace_id,'transport:'||p_worker_transport_id,'credential-binding:'||p_credential_binding_id),jsonb_build_object('assignment_id',p_assignment_id,'live_provider_invoked',false,'execution_contract_version','2.0'),rh,n);
  return jsonb_build_object('schema','WORLD8_PROVIDER_EXECUTION_REQUEST/2.0','request_id',id,'state','QUEUED','adapter_id',p_adapter_id,'worker_transport_id',p_worker_transport_id,'credential_binding_id',p_credential_binding_id,'readiness',ready,'live_provider_invoked',false,'receipt_id',rid);
end $$;

create or replace function public.world8_provider_execution_claim_v2(p_request_id text,p_adapter_id text,p_worker_transport_id text,p_claim_ttl_seconds integer default 300)
returns jsonb language plpgsql security definer set search_path=public,extensions as $$
declare q public.world8_provider_execution_requests%rowtype; a public.world8_provider_execution_adapters%rowtype; ready jsonb; ex jsonb; n timestamptz:=clock_timestamp(); token text; h text; rid text;
begin
  if p_claim_ttl_seconds<30 or p_claim_ttl_seconds>900 then raise exception 'EXECUTION_CLAIM_TTL_OUT_OF_RANGE'; end if;
  select * into q from public.world8_provider_execution_requests where request_id=p_request_id for update; if not found then raise exception 'EXECUTION_REQUEST_NOT_FOUND'; end if;
  if q.state<>'QUEUED' then raise exception 'EXECUTION_REQUEST_NOT_QUEUED'; end if;
  if q.adapter_id<>p_adapter_id or q.worker_transport_id<>p_worker_transport_id then raise exception 'EXECUTION_ADAPTER_OR_TRANSPORT_MISMATCH'; end if;
  select * into a from public.world8_provider_execution_adapters where adapter_id=p_adapter_id and adapter_kind='REAL_EXTERNAL'; if not found then raise exception 'REAL_EXTERNAL_ADAPTER_REQUIRED_FOR_V2'; end if;
  ready:=public.world8_provider_execution_readiness_v2(p_adapter_id,p_worker_transport_id); if ready->>'gate_state'<>'PASS' or coalesce((ready->>'live_ready')::boolean,false)<>true then raise exception 'PROVIDER_EXECUTION_V2_NOT_READY:%',ready->'blockers'; end if;
  if ready->>'binding_id'<>q.credential_binding_id then raise exception 'VERIFIED_CREDENTIAL_BINDING_CHANGED_BEFORE_EXECUTION'; end if;
  if q.assignment_id is not null and not exists(select 1 from public.world8_mason_assignments x where x.assignment_id=q.assignment_id and x.actor_id=q.actor_id and x.work_id=q.work_id and x.workspace_id=q.workspace_id and x.state='CODING') then raise exception 'ASSIGNMENT_BINDING_CHANGED_BEFORE_EXECUTION'; end if;
  token:=substr(encode(extensions.digest(p_request_id||'|'||p_adapter_id||'|'||p_worker_transport_id||'|'||n::text,'sha256'),'hex'),1,32);
  ex:=public.world8_actor_start_execution_v1(q.actor_id,a.provider,q.requested_model_id,p_request_id,'W8-PROVIDER-EXECUTION',jsonb_build_object('work_id',q.work_id,'workspace_id',q.workspace_id,'adapter_id',p_adapter_id,'adapter_kind','REAL_EXTERNAL','worker_transport_id',p_worker_transport_id,'credential_binding_id',q.credential_binding_id),jsonb_build_object('provider_execution_request_id',p_request_id,'assignment_id',q.assignment_id,'live_provider_invoked',false,'test_only',false,'execution_contract_version','2.0'));
  if q.assignment_id is not null then perform public.world8_mason_pool_bind_execution_v1(q.assignment_id,ex->>'execution_id'); end if;
  update public.world8_provider_execution_requests set state='RUNNING',execution_id=ex->>'execution_id',claim_token=token,claimed_at=n,last_heartbeat_at=n,updated_at=n where request_id=p_request_id;
  h:=encode(extensions.digest(p_request_id||'|STARTED_V2|'||(ex->>'execution_id')||'|'||n::text,'sha256'),'hex'); rid:='provider-receipt-'||substr(h,1,28);
  insert into public.world8_provider_execution_receipts(receipt_id,request_id,execution_id,adapter_id,receipt_kind,provider,model_id,evidence_refs,metadata,content_hash,created_at)
  values(rid,p_request_id,ex->>'execution_id',p_adapter_id,'STARTED',a.provider,q.requested_model_id,jsonb_build_array('execution:'||(ex->>'execution_id'),'transport:'||p_worker_transport_id,'credential-binding:'||q.credential_binding_id),jsonb_build_object('claim_token_hash',encode(extensions.digest(token,'sha256'),'hex'),'live_provider_invoked',false,'test_only',false,'execution_contract_version','2.0'),h,n);
  return jsonb_build_object('schema','WORLD8_PROVIDER_EXECUTION_CLAIM/2.0','request_id',p_request_id,'execution_id',ex->>'execution_id','claim_token',token,'state','RUNNING','adapter_kind','REAL_EXTERNAL','worker_transport_id',p_worker_transport_id,'credential_binding_id',q.credential_binding_id,'live_provider_invoked',false,'readiness',ready,'receipt_id',rid);
end $$;

create or replace function public.world8_provider_execution_dispatch_envelope_v2(p_request_id text,p_claim_token text)
returns jsonb language plpgsql security definer set search_path=public,extensions as $$
declare q public.world8_provider_execution_requests%rowtype; a public.world8_provider_execution_adapters%rowtype; b public.world8_provider_credential_bindings%rowtype; t public.world8_provider_worker_transports%rowtype; r jsonb; n timestamptz:=clock_timestamp(); h text; rid text;
begin
  select * into q from public.world8_provider_execution_requests where request_id=p_request_id; if not found or q.state<>'RUNNING' then raise exception 'RUNNING_EXECUTION_REQUEST_REQUIRED'; end if;
  if coalesce(q.claim_token,'')='' or coalesce(p_claim_token,'')='' or q.claim_token<>p_claim_token then raise exception 'EXECUTION_CLAIM_TOKEN_MISMATCH'; end if;
  select * into a from public.world8_provider_execution_adapters where adapter_id=q.adapter_id and adapter_kind='REAL_EXTERNAL'; if not found then raise exception 'REAL_EXTERNAL_ADAPTER_REQUIRED_FOR_DISPATCH'; end if;
  select * into t from public.world8_provider_worker_transports where transport_id=q.worker_transport_id and adapter_id=q.adapter_id and status='ACTIVE' and verification_state='VERIFIED'; if not found then raise exception 'VERIFIED_WORKER_TRANSPORT_REQUIRED'; end if;
  select * into b from public.world8_provider_credential_bindings where binding_id=q.credential_binding_id and adapter_id=q.adapter_id and status='ACTIVE' and verification_state='VERIFIED'; if not found then raise exception 'VERIFIED_CREDENTIAL_BINDING_REQUIRED'; end if;
  r:=public.world8_provider_execution_readiness_v2(q.adapter_id,q.worker_transport_id); if r->>'gate_state'<>'PASS' then raise exception 'PROVIDER_EXECUTION_V2_NOT_READY:%',r->'blockers'; end if;
  h:=encode(extensions.digest(q.request_id||'|DISPATCH_PREPARED|'||q.execution_id||'|'||q.worker_transport_id||'|'||n::text,'sha256'),'hex'); rid:='worker-dispatch-'||substr(h,1,28);
  insert into public.world8_provider_worker_dispatch_receipts(receipt_id,request_id,execution_id,adapter_id,transport_id,credential_binding_id,dispatch_state,evidence_refs,metadata,content_hash,created_at)
  values(rid,q.request_id,q.execution_id,q.adapter_id,q.worker_transport_id,q.credential_binding_id,'PREPARED',jsonb_build_array('request:'||q.request_id,'execution:'||q.execution_id),jsonb_build_object('credential_ref',b.credential_ref,'raw_secret_included',false,'private_reasoning_included',false,'live_provider_invoked',false),h,n);
  return jsonb_build_object('schema','WORLD8_PROVIDER_WORKER_DISPATCH/2.0','dispatch_receipt_id',rid,'request_id',q.request_id,'execution_id',q.execution_id,'assignment_id',q.assignment_id,'actor_id',q.actor_id,'work_id',q.work_id,'workspace_id',q.workspace_id,'adapter_id',q.adapter_id,'provider',q.requested_provider,'model_id',q.requested_model_id,'transport_id',q.worker_transport_id,'transport_kind',t.transport_kind,'endpoint_ref',t.endpoint_ref,'credential_binding_id',q.credential_binding_id,'credential_ref',b.credential_ref,'task_summary',q.task_summary,'input_refs',q.input_refs,'context_refs',q.context_refs,'readiness',r,'raw_secret_returned',false,'private_reasoning_returned',false,'live_provider_invoked',false);
end $$;

create or replace function public.world8_provider_execution_complete_v2(p_request_id text,p_claim_token text,p_provider_invocation_evidence_ref text,p_output_refs jsonb default '[]'::jsonb,p_evidence_refs jsonb default '[]'::jsonb,p_metadata jsonb default '{}'::jsonb)
returns jsonb language plpgsql security definer set search_path=public,extensions as $$
declare q public.world8_provider_execution_requests%rowtype; a public.world8_provider_execution_adapters%rowtype; n timestamptz:=clock_timestamp(); h text; rid text; live boolean;
begin
  if jsonb_typeof(coalesce(p_output_refs,'[]'::jsonb))<>'array' or jsonb_typeof(coalesce(p_evidence_refs,'[]'::jsonb))<>'array' then raise exception 'EXECUTION_OUTPUT_EVIDENCE_REFS_MUST_BE_ARRAYS'; end if;
  if not public.world8_provider_execution_json_safe_v1(coalesce(p_output_refs,'[]'::jsonb)) or not public.world8_provider_execution_json_safe_v1(coalesce(p_evidence_refs,'[]'::jsonb)) or not public.world8_provider_execution_json_safe_v1(coalesce(p_metadata,'{}'::jsonb)) or not public.world8_provider_execution_text_safe_v1(coalesce(p_provider_invocation_evidence_ref,'')) then raise exception 'EXECUTION_RESULT_SECRET_OR_PRIVATE_REASONING_REJECTED'; end if;
  select * into q from public.world8_provider_execution_requests where request_id=p_request_id for update; if not found or q.state<>'RUNNING' then raise exception 'RUNNING_EXECUTION_REQUEST_REQUIRED'; end if;
  if q.claim_token is distinct from p_claim_token then raise exception 'EXECUTION_CLAIM_TOKEN_MISMATCH'; end if;
  select * into a from public.world8_provider_execution_adapters where adapter_id=q.adapter_id; live:=a.adapter_kind='REAL_EXTERNAL';
  if live and coalesce(btrim(p_provider_invocation_evidence_ref),'')='' then raise exception 'REAL_PROVIDER_INVOCATION_EVIDENCE_REQUIRED'; end if;
  perform public.world8_actor_finish_execution_v1(q.execution_id,'COMPLETED',coalesce(p_metadata,'{}'::jsonb)||jsonb_build_object('provider_execution_request_id',p_request_id,'worker_transport_id',q.worker_transport_id,'live_provider_invoked',live));
  update public.world8_provider_execution_requests set state='SUCCEEDED',completed_at=n,updated_at=n where request_id=p_request_id;
  h:=encode(extensions.digest(p_request_id||'|SUCCEEDED_V2|'||q.execution_id||'|'||n::text,'sha256'),'hex'); rid:='provider-receipt-'||substr(h,1,28);
  insert into public.world8_provider_execution_receipts(receipt_id,request_id,execution_id,adapter_id,receipt_kind,provider,model_id,output_refs,evidence_refs,metadata,content_hash,created_at)
  values(rid,p_request_id,q.execution_id,q.adapter_id,'SUCCEEDED',a.provider,q.requested_model_id,coalesce(p_output_refs,'[]'::jsonb),coalesce(p_evidence_refs,'[]'::jsonb)||case when coalesce(btrim(p_provider_invocation_evidence_ref),'')<>'' then jsonb_build_array(p_provider_invocation_evidence_ref) else '[]'::jsonb end,coalesce(p_metadata,'{}'::jsonb)||jsonb_build_object('worker_transport_id',q.worker_transport_id,'credential_binding_id',q.credential_binding_id,'live_provider_invoked',live,'raw_secret_present',false,'test_only',not live),h,n);
  return jsonb_build_object('schema','WORLD8_PROVIDER_EXECUTION_RESULT/2.0','request_id',p_request_id,'execution_id',q.execution_id,'state','SUCCEEDED','live_provider_invoked',live,'test_only',not live,'receipt_id',rid);
end $$;

revoke all on public.world8_provider_worker_dispatch_receipts from public,anon,authenticated;
grant select on public.world8_provider_worker_dispatch_receipts to service_role;
revoke all on function public.world8_provider_execution_enqueue_v2(text,text,text,text,text,text,text,text,text,jsonb,jsonb,text,jsonb),public.world8_provider_execution_claim_v2(text,text,text,integer),public.world8_provider_execution_dispatch_envelope_v2(text,text),public.world8_provider_execution_complete_v2(text,text,text,jsonb,jsonb,jsonb) from public,anon,authenticated;
grant execute on function public.world8_provider_execution_enqueue_v2(text,text,text,text,text,text,text,text,text,jsonb,jsonb,text,jsonb),public.world8_provider_execution_claim_v2(text,text,text,integer),public.world8_provider_execution_dispatch_envelope_v2(text,text),public.world8_provider_execution_complete_v2(text,text,text,jsonb,jsonb,jsonb) to service_role;
