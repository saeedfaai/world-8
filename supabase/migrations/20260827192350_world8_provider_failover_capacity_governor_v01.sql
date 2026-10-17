-- World 8 Provider Failover Capacity Governor v0.1
-- Evidence-backed claim-time concurrency enforcement. Provider/model remain execution metadata.

create table if not exists public.world8_provider_capacity_receipts (
  receipt_id text primary key,
  world_id text not null default 'world-001',
  adapter_id text not null references public.world8_provider_execution_adapters(adapter_id),
  policy_state text not null check (policy_state in ('ENFORCED','OBSERVE_ONLY','DISABLED')),
  max_concurrent integer not null check (max_concurrent between 1 and 1000),
  stale_after_seconds integer not null default 900 check (stale_after_seconds between 30 and 3600),
  reason_code text not null,
  evidence_refs jsonb not null default '[]'::jsonb check (jsonb_typeof(evidence_refs)='array'),
  metadata jsonb not null default '{}'::jsonb check (jsonb_typeof(metadata)='object'),
  content_hash text not null,
  created_by text not null,
  created_at timestamptz not null default clock_timestamp()
);
create index if not exists world8_provider_capacity_receipts_adapter_idx
  on public.world8_provider_capacity_receipts(adapter_id,created_at desc);

create or replace function public.world8_provider_capacity_receipts_append_only_v1()
returns trigger language plpgsql security definer set search_path=public as $$
begin
  raise exception 'WORLD8_PROVIDER_CAPACITY_RECEIPTS_APPEND_ONLY';
end $$;

drop trigger if exists world8_provider_capacity_receipts_append_only_trg on public.world8_provider_capacity_receipts;
create trigger world8_provider_capacity_receipts_append_only_trg
before update or delete on public.world8_provider_capacity_receipts
for each row execute function public.world8_provider_capacity_receipts_append_only_v1();

create or replace function public.world8_provider_capacity_record_v1(
  p_adapter_id text,
  p_policy_state text,
  p_max_concurrent integer,
  p_stale_after_seconds integer,
  p_reason_code text,
  p_evidence_refs jsonb default '[]'::jsonb,
  p_metadata jsonb default '{}'::jsonb,
  p_created_by text default 'world8-system'
) returns jsonb language plpgsql security definer set search_path=public,extensions as $$
declare
  v_now timestamptz:=clock_timestamp();
  v_hash text;
  v_id text;
begin
  if not exists(select 1 from public.world8_provider_execution_adapters where adapter_id=p_adapter_id) then
    raise exception 'PROVIDER_CAPACITY_ADAPTER_NOT_FOUND';
  end if;
  if p_policy_state not in ('ENFORCED','OBSERVE_ONLY','DISABLED') then raise exception 'PROVIDER_CAPACITY_POLICY_STATE_INVALID'; end if;
  if p_max_concurrent<1 or p_max_concurrent>1000 then raise exception 'PROVIDER_CAPACITY_MAX_CONCURRENT_INVALID'; end if;
  if p_stale_after_seconds<30 or p_stale_after_seconds>3600 then raise exception 'PROVIDER_CAPACITY_STALE_WINDOW_INVALID'; end if;
  if jsonb_typeof(coalesce(p_evidence_refs,'[]'::jsonb))<>'array' or jsonb_typeof(coalesce(p_metadata,'{}'::jsonb))<>'object' then
    raise exception 'PROVIDER_CAPACITY_JSON_INVALID';
  end if;
  v_hash:=encode(extensions.digest(jsonb_build_object(
    'adapter_id',p_adapter_id,
    'policy_state',p_policy_state,
    'max_concurrent',p_max_concurrent,
    'stale_after_seconds',p_stale_after_seconds,
    'reason_code',p_reason_code,
    'evidence_refs',coalesce(p_evidence_refs,'[]'::jsonb),
    'metadata',coalesce(p_metadata,'{}'::jsonb),
    'created_by',p_created_by,
    'created_at',v_now
  )::text,'sha256'),'hex');
  v_id:='provider-capacity-'||substr(v_hash,1,28);
  insert into public.world8_provider_capacity_receipts(
    receipt_id,adapter_id,policy_state,max_concurrent,stale_after_seconds,reason_code,evidence_refs,metadata,content_hash,created_by,created_at
  ) values(
    v_id,p_adapter_id,p_policy_state,p_max_concurrent,p_stale_after_seconds,p_reason_code,coalesce(p_evidence_refs,'[]'::jsonb),coalesce(p_metadata,'{}'::jsonb),v_hash,p_created_by,v_now
  );
  return jsonb_build_object(
    'schema','WORLD8_PROVIDER_CAPACITY_RECEIPT/1.0',
    'receipt_id',v_id,
    'adapter_id',p_adapter_id,
    'policy_state',p_policy_state,
    'max_concurrent',p_max_concurrent,
    'stale_after_seconds',p_stale_after_seconds,
    'reason_code',p_reason_code,
    'created_at',v_now
  );
end $$;

create or replace function public.world8_provider_capacity_snapshot_v1(p_adapter_id text)
returns jsonb language plpgsql stable security definer set search_path=public as $$
declare c public.world8_provider_capacity_receipts%rowtype;
begin
  select * into c
  from public.world8_provider_capacity_receipts
  where adapter_id=p_adapter_id
  order by created_at desc,receipt_id desc
  limit 1;
  if not found then
    return jsonb_build_object(
      'schema','WORLD8_PROVIDER_CAPACITY/1.0',
      'adapter_id',p_adapter_id,
      'policy_state','DISABLED',
      'enforced',false,
      'max_concurrent',null,
      'stale_after_seconds',900,
      'latest_receipt_id',null
    );
  end if;
  return jsonb_build_object(
    'schema','WORLD8_PROVIDER_CAPACITY/1.0',
    'adapter_id',c.adapter_id,
    'policy_state',c.policy_state,
    'enforced',c.policy_state='ENFORCED',
    'max_concurrent',c.max_concurrent,
    'stale_after_seconds',c.stale_after_seconds,
    'reason_code',c.reason_code,
    'evidence_refs',c.evidence_refs,
    'metadata',c.metadata,
    'latest_receipt_id',c.receipt_id,
    'observed_at',c.created_at
  );
end $$;

create or replace function public.world8_provider_capacity_claim_gate_v1(p_adapter_id text)
returns jsonb language plpgsql security definer set search_path=public,extensions as $$
declare
  c jsonb;
  v_now timestamptz:=clock_timestamp();
  v_max integer;
  v_stale integer;
  v_running integer;
begin
  c:=public.world8_provider_capacity_snapshot_v1(p_adapter_id);
  if coalesce((c->>'enforced')::boolean,false)<>true then
    return jsonb_build_object(
      'schema','WORLD8_PROVIDER_CAPACITY_GATE/1.0',
      'adapter_id',p_adapter_id,
      'gate_state','PASS',
      'enforced',false,
      'running_count',null,
      'max_concurrent',c->'max_concurrent',
      'provider_invoked',false
    );
  end if;
  v_max:=(c->>'max_concurrent')::integer;
  v_stale:=coalesce((c->>'stale_after_seconds')::integer,900);
  perform pg_advisory_xact_lock(hashtextextended('world8-provider-capacity:'||p_adapter_id,0));
  select count(*)::integer into v_running
  from public.world8_provider_execution_requests r
  where r.adapter_id=p_adapter_id
    and r.state='RUNNING'
    and coalesce(r.last_heartbeat_at,r.claimed_at,r.updated_at) > v_now-make_interval(secs=>v_stale);
  if v_running>=v_max then
    return jsonb_build_object(
      'schema','WORLD8_PROVIDER_CAPACITY_GATE/1.0',
      'adapter_id',p_adapter_id,
      'gate_state','DEFER',
      'reason_code','PROVIDER_CONCURRENCY_CEILING_REACHED',
      'retryable',true,
      'running_count',v_running,
      'max_concurrent',v_max,
      'stale_after_seconds',v_stale,
      'policy_receipt_id',c->>'latest_receipt_id',
      'provider_invoked',false
    );
  end if;
  return jsonb_build_object(
    'schema','WORLD8_PROVIDER_CAPACITY_GATE/1.0',
    'adapter_id',p_adapter_id,
    'gate_state','PASS',
    'enforced',true,
    'running_count',v_running,
    'max_concurrent',v_max,
    'stale_after_seconds',v_stale,
    'policy_receipt_id',c->>'latest_receipt_id',
    'provider_invoked',false
  );
end $$;

create or replace function public.world8_provider_execution_worker_claim_v1(p_request_id text,p_transport_id text,p_claim_ttl_seconds integer default 300)
returns jsonb language plpgsql security definer set search_path=public,extensions as $$
declare q public.world8_provider_execution_requests%rowtype; a public.world8_provider_execution_adapters%rowtype; r jsonb; cap jsonb; ex jsonb; v_now timestamptz:=clock_timestamp(); v_token text; v_hash text; v_receipt_id text;
begin
  if p_claim_ttl_seconds<30 or p_claim_ttl_seconds>900 then raise exception 'EXECUTION_CLAIM_TTL_OUT_OF_RANGE'; end if;
  select * into q from public.world8_provider_execution_requests where request_id=p_request_id for update; if not found or q.state<>'QUEUED' then raise exception 'EXECUTION_REQUEST_NOT_QUEUED'; end if;
  if q.worker_transport_id is distinct from p_transport_id then raise exception 'EXECUTION_WORKER_TRANSPORT_MISMATCH'; end if;
  r:=public.world8_provider_execution_readiness_v2(q.adapter_id,p_transport_id); if r->>'gate_state'<>'PASS' then raise exception 'PROVIDER_EXECUTION_V2_NOT_READY:%',r->'blockers'; end if;
  if q.assignment_id is not null and not exists(select 1 from public.world8_mason_assignments x where x.assignment_id=q.assignment_id and x.actor_id=q.actor_id and x.work_id=q.work_id and x.workspace_id=q.workspace_id and x.state='CODING') then raise exception 'ASSIGNMENT_BINDING_CHANGED_BEFORE_EXECUTION'; end if;
  cap:=public.world8_provider_capacity_claim_gate_v1(q.adapter_id);
  if cap->>'gate_state'='DEFER' then raise exception 'PROVIDER_CONCURRENCY_CEILING_REACHED:%',cap; end if;
  select * into a from public.world8_provider_execution_adapters where adapter_id=q.adapter_id;
  v_token:=substr(encode(extensions.digest(p_request_id||'|'||p_transport_id||'|'||v_now::text,'sha256'),'hex'),1,32);
  ex:=public.world8_actor_start_execution_v1(q.actor_id,a.provider,q.requested_model_id,p_request_id,'W8-PROVIDER-WORKER',jsonb_build_object('work_id',q.work_id,'workspace_id',q.workspace_id,'adapter_id',q.adapter_id,'worker_transport_id',p_transport_id,'credential_binding_id',q.credential_binding_id),jsonb_build_object('provider_execution_request_id',p_request_id,'assignment_id',q.assignment_id,'live_provider_invoked',false,'test_only',a.adapter_kind='MOCK_INTERNAL','capacity_gate',cap));
  if q.assignment_id is not null then perform public.world8_mason_pool_bind_execution_v1(q.assignment_id,ex->>'execution_id'); end if;
  update public.world8_provider_execution_requests set state='RUNNING',execution_id=ex->>'execution_id',claim_token=v_token,claimed_at=v_now,last_heartbeat_at=v_now,updated_at=v_now where request_id=p_request_id;
  v_hash:=encode(extensions.digest(p_request_id||'|WORKER_STARTED|'||(ex->>'execution_id')||'|'||v_now::text,'sha256'),'hex'); v_receipt_id:='provider-receipt-'||substr(v_hash,1,28);
  insert into public.world8_provider_execution_receipts(receipt_id,request_id,execution_id,adapter_id,receipt_kind,provider,model_id,evidence_refs,metadata,content_hash,created_at)
  values(v_receipt_id,p_request_id,ex->>'execution_id',q.adapter_id,'STARTED',a.provider,q.requested_model_id,jsonb_build_array('execution:'||(ex->>'execution_id'),'transport:'||p_transport_id,'capacity-policy:'||coalesce(cap->>'policy_receipt_id','none')),jsonb_build_object('claim_token_hash',encode(extensions.digest(v_token,'sha256'),'hex'),'credential_binding_id',q.credential_binding_id,'worker_transport_id',p_transport_id,'live_provider_invoked',false,'raw_secret_present',false,'test_only',a.adapter_kind='MOCK_INTERNAL','capacity_gate',cap),v_hash,v_now);
  return jsonb_build_object('schema','WORLD8_PROVIDER_WORKER_CLAIM/1.1','request_id',p_request_id,'execution_id',ex->>'execution_id','claim_token',v_token,'state','RUNNING','transport_id',p_transport_id,'dispatch',jsonb_build_object('credential_binding_id',q.credential_binding_id,'credential_ref',(select credential_ref from public.world8_provider_credential_bindings where binding_id=q.credential_binding_id),'provider',q.requested_provider,'model_id',q.requested_model_id,'task_summary',q.task_summary,'input_refs',q.input_refs,'context_refs',q.context_refs,'raw_secret_returned',false),'capacity_gate',cap,'live_provider_invoked',false,'receipt_id',v_receipt_id);
end $$;

create or replace function public.world8_provider_execution_claim_v2(p_request_id text,p_adapter_id text,p_worker_transport_id text,p_claim_ttl_seconds integer default 300)
returns jsonb language plpgsql security definer set search_path=public,extensions as $$
declare q public.world8_provider_execution_requests%rowtype; a public.world8_provider_execution_adapters%rowtype; ready jsonb; cap jsonb; ex jsonb; n timestamptz:=clock_timestamp(); token text; h text; rid text;
begin
  if p_claim_ttl_seconds<30 or p_claim_ttl_seconds>900 then raise exception 'EXECUTION_CLAIM_TTL_OUT_OF_RANGE'; end if;
  select * into q from public.world8_provider_execution_requests where request_id=p_request_id for update; if not found then raise exception 'EXECUTION_REQUEST_NOT_FOUND'; end if;
  if q.state<>'QUEUED' then raise exception 'EXECUTION_REQUEST_NOT_QUEUED'; end if;
  if q.adapter_id<>p_adapter_id or q.worker_transport_id<>p_worker_transport_id then raise exception 'EXECUTION_ADAPTER_OR_TRANSPORT_MISMATCH'; end if;
  select * into a from public.world8_provider_execution_adapters where adapter_id=p_adapter_id and adapter_kind='REAL_EXTERNAL'; if not found then raise exception 'REAL_EXTERNAL_ADAPTER_REQUIRED_FOR_V2'; end if;
  ready:=public.world8_provider_execution_readiness_v2(p_adapter_id,p_worker_transport_id); if ready->>'gate_state'<>'PASS' or coalesce((ready->>'live_ready')::boolean,false)<>true then raise exception 'PROVIDER_EXECUTION_V2_NOT_READY:%',ready->'blockers'; end if;
  if ready->>'binding_id'<>q.credential_binding_id then raise exception 'VERIFIED_CREDENTIAL_BINDING_CHANGED_BEFORE_EXECUTION'; end if;
  if q.assignment_id is not null and not exists(select 1 from public.world8_mason_assignments x where x.assignment_id=q.assignment_id and x.actor_id=q.actor_id and x.work_id=q.work_id and x.workspace_id=q.workspace_id and x.state='CODING') then raise exception 'ASSIGNMENT_BINDING_CHANGED_BEFORE_EXECUTION'; end if;
  cap:=public.world8_provider_capacity_claim_gate_v1(q.adapter_id);
  if cap->>'gate_state'='DEFER' then raise exception 'PROVIDER_CONCURRENCY_CEILING_REACHED:%',cap; end if;
  token:=substr(encode(extensions.digest(p_request_id||'|'||p_adapter_id||'|'||p_worker_transport_id||'|'||n::text,'sha256'),'hex'),1,32);
  ex:=public.world8_actor_start_execution_v1(q.actor_id,a.provider,q.requested_model_id,p_request_id,'W8-PROVIDER-EXECUTION',jsonb_build_object('work_id',q.work_id,'workspace_id',q.workspace_id,'adapter_id',p_adapter_id,'adapter_kind','REAL_EXTERNAL','worker_transport_id',p_worker_transport_id,'credential_binding_id',q.credential_binding_id),jsonb_build_object('provider_execution_request_id',p_request_id,'assignment_id',q.assignment_id,'live_provider_invoked',false,'test_only',false,'execution_contract_version','2.1','capacity_gate',cap));
  if q.assignment_id is not null then perform public.world8_mason_pool_bind_execution_v1(q.assignment_id,ex->>'execution_id'); end if;
  update public.world8_provider_execution_requests set state='RUNNING',execution_id=ex->>'execution_id',claim_token=token,claimed_at=n,last_heartbeat_at=n,updated_at=n where request_id=p_request_id;
  h:=encode(extensions.digest(p_request_id||'|STARTED_V21|'||(ex->>'execution_id')||'|'||n::text,'sha256'),'hex'); rid:='provider-receipt-'||substr(h,1,28);
  insert into public.world8_provider_execution_receipts(receipt_id,request_id,execution_id,adapter_id,receipt_kind,provider,model_id,evidence_refs,metadata,content_hash,created_at)
  values(rid,p_request_id,ex->>'execution_id',p_adapter_id,'STARTED',a.provider,q.requested_model_id,jsonb_build_array('execution:'||(ex->>'execution_id'),'transport:'||p_worker_transport_id,'credential-binding:'||q.credential_binding_id,'capacity-policy:'||coalesce(cap->>'policy_receipt_id','none')),jsonb_build_object('claim_token_hash',encode(extensions.digest(token,'sha256'),'hex'),'live_provider_invoked',false,'test_only',false,'execution_contract_version','2.1','capacity_gate',cap),h,n);
  return jsonb_build_object('schema','WORLD8_PROVIDER_EXECUTION_CLAIM/2.1','request_id',p_request_id,'execution_id',ex->>'execution_id','claim_token',token,'state','RUNNING','adapter_kind','REAL_EXTERNAL','worker_transport_id',p_worker_transport_id,'credential_binding_id',q.credential_binding_id,'live_provider_invoked',false,'readiness',ready,'capacity_gate',cap,'receipt_id',rid);
end $$;

do $$
begin
  if not exists(
    select 1 from public.world8_provider_capacity_receipts
    where adapter_id='adapter-groq-external-v01'
      and policy_state='ENFORCED'
      and max_concurrent=5
      and reason_code='SCALE20_RATE_LIMIT_EVIDENCE'
  ) then
    perform public.world8_provider_capacity_record_v1(
      'adapter-groq-external-v01',
      'ENFORCED',
      5,
      900,
      'SCALE20_RATE_LIMIT_EVIDENCE',
      '["stage:GROQ_SCALE5:PASS_5_OF_5","stage:GROQ_SCALE20:RATE_LIMITED"]'::jsonb,
      jsonb_build_object(
        'evidence_basis','Scale-5 passed 5/5; scale-20 burst produced 10 successful completions, 9 HTTP 429 responses, and 1 pre-provider dispatch rejection.',
        'scale100_blocked',true,
        'automatic_retry',false,
        'conservative_ceiling',true
      ),
      'migration:world8_provider_failover_capacity_governor_v01'
    );
  end if;
end $$;
