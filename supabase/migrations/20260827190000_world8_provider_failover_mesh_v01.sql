-- World 8 Provider Failover Mesh v0.1
-- Replays the final failover contract on top of Provider Execution Adapter + Credential Broker.

create table if not exists public.world8_provider_failover_policies (
  policy_id text primary key,
  world_id text not null default 'world-001',
  policy_key text not null,
  policy_version integer not null check (policy_version >= 1),
  capability text not null,
  ordered_adapter_ids jsonb not null check (jsonb_typeof(ordered_adapter_ids)='array' and jsonb_array_length(ordered_adapter_ids)>=1),
  selection_mode text not null default 'FIRST_LIVE_READY' check (selection_mode in ('FIRST_LIVE_READY')),
  automatic_retry boolean not null default false,
  max_attempts integer not null default 1 check (max_attempts between 1 and 10),
  status text not null default 'FROZEN' check (status in ('FROZEN','RETIRED')),
  metadata jsonb not null default '{}'::jsonb,
  created_by text not null,
  created_at timestamptz not null default clock_timestamp(),
  content_hash text not null,
  unique(policy_key,policy_version)
);

create table if not exists public.world8_provider_health_receipts (
  receipt_id text primary key,
  world_id text not null default 'world-001',
  adapter_id text not null references public.world8_provider_execution_adapters(adapter_id),
  health_state text not null check (health_state in ('HEALTHY','DEGRADED','ADMIN_BLOCKED','DISABLED','UNKNOWN')),
  reason_code text not null,
  retryable boolean not null default false,
  evidence_refs jsonb not null default '[]'::jsonb check (jsonb_typeof(evidence_refs)='array'),
  metadata jsonb not null default '{}'::jsonb,
  created_by text not null,
  created_at timestamptz not null default clock_timestamp(),
  content_hash text not null
);

create table if not exists public.world8_provider_health_state (
  adapter_id text primary key references public.world8_provider_execution_adapters(adapter_id),
  health_state text not null check (health_state in ('HEALTHY','DEGRADED','ADMIN_BLOCKED','DISABLED','UNKNOWN')),
  reason_code text not null,
  retryable boolean not null default false,
  latest_receipt_id text not null references public.world8_provider_health_receipts(receipt_id),
  observed_at timestamptz not null,
  updated_at timestamptz not null default clock_timestamp()
);

alter table public.world8_provider_failover_policies enable row level security;
alter table public.world8_provider_health_receipts enable row level security;
alter table public.world8_provider_health_state enable row level security;
revoke all on table public.world8_provider_failover_policies from public,anon,authenticated;
revoke all on table public.world8_provider_health_receipts from public,anon,authenticated;
revoke all on table public.world8_provider_health_state from public,anon,authenticated;
grant select,insert on table public.world8_provider_failover_policies to service_role;
grant select,insert on table public.world8_provider_health_receipts to service_role;
grant select,insert,update on table public.world8_provider_health_state to service_role;

create or replace function public.world8_provider_failover_append_only_v1()
returns trigger language plpgsql security definer set search_path=public as $$
begin raise exception 'PROVIDER_FAILOVER_POLICY_APPEND_ONLY'; end $$;
drop trigger if exists world8_provider_failover_append_only_trg on public.world8_provider_failover_policies;
create trigger world8_provider_failover_append_only_trg before update or delete on public.world8_provider_failover_policies for each row execute function public.world8_provider_failover_append_only_v1();

create or replace function public.world8_provider_health_receipts_append_only_v1()
returns trigger language plpgsql security definer set search_path=public as $$
begin raise exception 'PROVIDER_HEALTH_RECEIPTS_APPEND_ONLY'; end $$;
drop trigger if exists world8_provider_health_receipts_append_only_trg on public.world8_provider_health_receipts;
create trigger world8_provider_health_receipts_append_only_trg before update or delete on public.world8_provider_health_receipts for each row execute function public.world8_provider_health_receipts_append_only_v1();

create or replace function public.world8_provider_failover_policy_register_v1(
  p_policy_id text,p_policy_key text,p_policy_version integer,p_capability text,p_ordered_adapter_ids jsonb,
  p_max_attempts integer default 1,p_automatic_retry boolean default false,p_metadata jsonb default '{}'::jsonb,p_created_by text default 'human-root'
) returns jsonb language plpgsql security definer set search_path=public,extensions as $$
declare v_now timestamptz:=clock_timestamp(); v_hash text; v_id text; v_total int; v_distinct int;
begin
  if coalesce(btrim(p_policy_id),'')='' or coalesce(btrim(p_policy_key),'')='' or coalesce(btrim(p_capability),'')='' then raise exception 'FAILOVER_POLICY_ID_KEY_CAPABILITY_REQUIRED'; end if;
  if p_policy_version<1 or p_max_attempts<1 or p_max_attempts>10 then raise exception 'INVALID_FAILOVER_POLICY_VERSION_OR_ATTEMPTS'; end if;
  if p_automatic_retry then raise exception 'FAILOVER_AUTOMATIC_RETRY_DISABLED_V01'; end if;
  if jsonb_typeof(coalesce(p_ordered_adapter_ids,'null'::jsonb))<>'array' or jsonb_array_length(p_ordered_adapter_ids)=0 then raise exception 'FAILOVER_ADAPTER_ORDER_REQUIRED'; end if;
  if not public.world8_provider_execution_json_safe_v1(coalesce(p_ordered_adapter_ids,'[]'::jsonb)) or not public.world8_provider_execution_json_safe_v1(coalesce(p_metadata,'{}'::jsonb)) then raise exception 'FAILOVER_POLICY_SECRET_OR_PRIVATE_REASONING_REJECTED'; end if;
  select count(*),count(distinct x) into v_total,v_distinct from jsonb_array_elements_text(p_ordered_adapter_ids) q(x);
  if v_total<>v_distinct then raise exception 'FAILOVER_ADAPTER_ORDER_DUPLICATE'; end if;
  for v_id in select jsonb_array_elements_text(p_ordered_adapter_ids) loop
    if not exists(select 1 from public.world8_provider_execution_adapters where adapter_id=v_id and status='ACTIVE') then raise exception 'ACTIVE_PROVIDER_ADAPTER_REQUIRED:%',v_id; end if;
  end loop;
  v_hash:=encode(extensions.digest(p_policy_id||'|'||p_policy_key||'|'||p_policy_version::text||'|'||p_capability||'|'||p_ordered_adapter_ids::text||'|'||p_max_attempts::text||'|'||p_automatic_retry::text||'|'||coalesce(p_metadata,'{}'::jsonb)::text,'sha256'),'hex');
  insert into public.world8_provider_failover_policies(policy_id,world_id,policy_key,policy_version,capability,ordered_adapter_ids,selection_mode,automatic_retry,max_attempts,status,metadata,created_by,created_at,content_hash)
  values(p_policy_id,'world-001',p_policy_key,p_policy_version,p_capability,p_ordered_adapter_ids,'FIRST_LIVE_READY',false,p_max_attempts,'FROZEN',coalesce(p_metadata,'{}'::jsonb),p_created_by,v_now,v_hash)
  on conflict(policy_id) do nothing;
  return jsonb_build_object('schema','WORLD8_PROVIDER_FAILOVER_POLICY/1.0','policy_id',p_policy_id,'policy_key',p_policy_key,'policy_version',p_policy_version,'status',(select status from public.world8_provider_failover_policies where policy_id=p_policy_id),'automatic_retry',false,'content_hash',(select content_hash from public.world8_provider_failover_policies where policy_id=p_policy_id));
end $$;

create or replace function public.world8_provider_worker_route_context_v1(p_transport_id text)
returns jsonb language plpgsql security definer set search_path=public as $$
declare t public.world8_provider_worker_transports%rowtype; a public.world8_provider_execution_adapters%rowtype; b public.world8_provider_credential_bindings%rowtype;
begin
  select * into t from public.world8_provider_worker_transports where transport_id=p_transport_id and status='ACTIVE'; if not found then raise exception 'ACTIVE_WORKER_TRANSPORT_REQUIRED'; end if;
  select * into a from public.world8_provider_execution_adapters where adapter_id=t.adapter_id and status='ACTIVE'; if not found then raise exception 'ACTIVE_PROVIDER_ADAPTER_REQUIRED'; end if;
  select * into b from public.world8_provider_credential_bindings where adapter_id=a.adapter_id and status='ACTIVE' order by (verification_state='VERIFIED') desc,created_at desc limit 1;
  return jsonb_build_object('schema','WORLD8_PROVIDER_WORKER_ROUTE_CONTEXT/1.0','transport_id',t.transport_id,'adapter_id',a.adapter_id,'provider',a.provider,'config',a.config,'supported_models',a.supported_models,'binding_id',b.binding_id,'credential_ref',b.credential_ref,'credential_verification_state',b.verification_state,'transport_verification_state',t.verification_state,'raw_secret_returned',false);
end $$;

create or replace function public.world8_provider_credential_probe_context_v1(p_challenge_id text)
returns jsonb language plpgsql security definer set search_path=public as $$
declare c public.world8_provider_credential_probe_challenges%rowtype; r jsonb;
begin
  select * into c from public.world8_provider_credential_probe_challenges where challenge_id=p_challenge_id; if not found then raise exception 'CREDENTIAL_PROBE_CHALLENGE_REQUIRED'; end if;
  r:=public.world8_provider_worker_route_context_v1(c.transport_id);
  if r->>'binding_id' is distinct from c.binding_id then raise exception 'CREDENTIAL_PROBE_BINDING_CONTEXT_MISMATCH'; end if;
  return r||jsonb_build_object('challenge_id',c.challenge_id,'challenge_state',c.state,'binding_id',c.binding_id,'transport_id',c.transport_id);
end $$;

create or replace function public.world8_provider_health_record_v1(
  p_adapter_id text,p_health_state text,p_reason_code text,p_retryable boolean,p_evidence_refs jsonb default '[]'::jsonb,p_metadata jsonb default '{}'::jsonb,p_created_by text default 'guardian-health-projection'
) returns jsonb language plpgsql security definer set search_path=public,extensions as $$
declare v_now timestamptz:=clock_timestamp(); v_hash text; v_receipt text;
begin
  if p_health_state not in ('HEALTHY','DEGRADED','ADMIN_BLOCKED','DISABLED','UNKNOWN') then raise exception 'INVALID_PROVIDER_HEALTH_STATE'; end if;
  if coalesce(btrim(p_reason_code),'')='' then raise exception 'PROVIDER_HEALTH_REASON_REQUIRED'; end if;
  if not exists(select 1 from public.world8_provider_execution_adapters where adapter_id=p_adapter_id and status='ACTIVE') then raise exception 'ACTIVE_PROVIDER_ADAPTER_REQUIRED'; end if;
  if jsonb_typeof(coalesce(p_evidence_refs,'[]'::jsonb))<>'array' or not public.world8_provider_execution_json_safe_v1(coalesce(p_evidence_refs,'[]'::jsonb)) or not public.world8_provider_execution_json_safe_v1(coalesce(p_metadata,'{}'::jsonb)) then raise exception 'PROVIDER_HEALTH_SECRET_OR_PRIVATE_REASONING_REJECTED'; end if;
  v_hash:=encode(extensions.digest(p_adapter_id||'|'||p_health_state||'|'||p_reason_code||'|'||p_retryable::text||'|'||coalesce(p_evidence_refs,'[]'::jsonb)::text||'|'||coalesce(p_metadata,'{}'::jsonb)::text||'|'||v_now::text,'sha256'),'hex'); v_receipt:='provider-health-'||substr(v_hash,1,28);
  insert into public.world8_provider_health_receipts(receipt_id,adapter_id,health_state,reason_code,retryable,evidence_refs,metadata,created_by,created_at,content_hash)
  values(v_receipt,p_adapter_id,p_health_state,p_reason_code,p_retryable,coalesce(p_evidence_refs,'[]'::jsonb),coalesce(p_metadata,'{}'::jsonb),p_created_by,v_now,v_hash);
  insert into public.world8_provider_health_state(adapter_id,health_state,reason_code,retryable,latest_receipt_id,observed_at,updated_at)
  values(p_adapter_id,p_health_state,p_reason_code,p_retryable,v_receipt,v_now,v_now)
  on conflict(adapter_id) do update set health_state=excluded.health_state,reason_code=excluded.reason_code,retryable=excluded.retryable,latest_receipt_id=excluded.latest_receipt_id,observed_at=excluded.observed_at,updated_at=excluded.updated_at;
  return jsonb_build_object('schema','WORLD8_PROVIDER_HEALTH_RECEIPT/1.0','receipt_id',v_receipt,'adapter_id',p_adapter_id,'health_state',p_health_state,'reason_code',p_reason_code,'retryable',p_retryable,'observed_at',v_now);
end $$;

create or replace function public.world8_provider_health_snapshot_v1(p_adapter_id text)
returns jsonb language plpgsql security definer set search_path=public as $$
declare s public.world8_provider_health_state%rowtype;
begin
  select * into s from public.world8_provider_health_state where adapter_id=p_adapter_id;
  if not found then return jsonb_build_object('schema','WORLD8_PROVIDER_HEALTH/1.0','adapter_id',p_adapter_id,'health_state','UNKNOWN','reason_code','NO_HEALTH_RECEIPT','retryable',false,'hard_blocked',false,'latest_receipt_id',null); end if;
  return jsonb_build_object('schema','WORLD8_PROVIDER_HEALTH/1.0','adapter_id',s.adapter_id,'health_state',s.health_state,'reason_code',s.reason_code,'retryable',s.retryable,'hard_blocked',s.health_state in ('ADMIN_BLOCKED','DISABLED'),'latest_receipt_id',s.latest_receipt_id,'observed_at',s.observed_at);
end $$;

create or replace function public.world8_provider_failover_snapshot_v1(p_policy_key text)
returns jsonb language plpgsql security definer set search_path=public as $$
declare p public.world8_provider_failover_policies%rowtype; v_adapter text; t public.world8_provider_worker_transports%rowtype; r jsonb; h jsonb; arr jsonb:='[]'::jsonb; selected jsonb:=null; v_pos int:=0; v_hard boolean;
begin
  select * into p from public.world8_provider_failover_policies where policy_key=p_policy_key and status='FROZEN' order by policy_version desc limit 1; if not found then raise exception 'FROZEN_FAILOVER_POLICY_REQUIRED'; end if;
  for v_adapter in select jsonb_array_elements_text(p.ordered_adapter_ids) loop
    v_pos:=v_pos+1;
    select * into t from public.world8_provider_worker_transports where adapter_id=v_adapter and status='ACTIVE' order by (verification_state='VERIFIED') desc,created_at desc limit 1;
    h:=public.world8_provider_health_snapshot_v1(v_adapter); v_hard:=coalesce((h->>'hard_blocked')::boolean,false);
    if t.transport_id is null then r:=jsonb_build_object('adapter_id',v_adapter,'priority',v_pos,'gate_state','BLOCKED','live_ready',false,'blockers',jsonb_build_array('WORKER_TRANSPORT_NOT_FOUND'),'provider_health',h);
    else
      r:=public.world8_provider_execution_readiness_v2(v_adapter,t.transport_id)||jsonb_build_object('priority',v_pos,'provider_health',h);
      if v_hard then r:=r||jsonb_build_object('gate_state','BLOCKED','live_ready',false,'blockers',coalesce(r->'blockers','[]'::jsonb)||jsonb_build_array('PROVIDER_HEALTH_HARD_BLOCKED')); end if;
    end if;
    arr:=arr||jsonb_build_array(r);
    if selected is null and coalesce((r->>'live_ready')::boolean,false) then selected:=r; end if;
  end loop;
  return jsonb_build_object('schema','WORLD8_PROVIDER_FAILOVER_SNAPSHOT/1.1','policy_id',p.policy_id,'policy_key',p.policy_key,'policy_version',p.policy_version,'capability',p.capability,'selection_mode',p.selection_mode,'automatic_retry',p.automatic_retry,'max_attempts',p.max_attempts,'candidates',arr,'selected',selected,'gate_state',case when selected is null then 'BLOCKED' else 'PASS' end,'selection_is_advisory_only',true,'provider_invoked',false);
end $$;

revoke all on function public.world8_provider_failover_policy_register_v1(text,text,integer,text,jsonb,integer,boolean,jsonb,text) from public,anon,authenticated;
revoke all on function public.world8_provider_worker_route_context_v1(text) from public,anon,authenticated;
revoke all on function public.world8_provider_credential_probe_context_v1(text) from public,anon,authenticated;
revoke all on function public.world8_provider_health_record_v1(text,text,text,boolean,jsonb,jsonb,text) from public,anon,authenticated;
revoke all on function public.world8_provider_health_snapshot_v1(text) from public,anon,authenticated;
revoke all on function public.world8_provider_failover_snapshot_v1(text) from public,anon,authenticated;
grant execute on function public.world8_provider_failover_policy_register_v1(text,text,integer,text,jsonb,integer,boolean,jsonb,text) to service_role;
grant execute on function public.world8_provider_worker_route_context_v1(text) to service_role;
grant execute on function public.world8_provider_credential_probe_context_v1(text) to service_role;
grant execute on function public.world8_provider_health_record_v1(text,text,text,boolean,jsonb,jsonb,text) to service_role;
grant execute on function public.world8_provider_health_snapshot_v1(text) to service_role;
grant execute on function public.world8_provider_failover_snapshot_v1(text) to service_role;

-- Provider-neutral profiles and opaque credential bindings.
select public.world8_provider_execution_adapter_register_v1('adapter-groq-external-v01','Groq','REAL_EXTERNAL','envref:GROQ_API_KEY',jsonb_build_array('openai/gpt-oss-20b','openai/gpt-oss-120b'),jsonb_build_array('CODE_ASSIST','OPENAI_COMPATIBLE_CHAT'),jsonb_build_object('base_url','https://api.groq.com/openai/v1','chat_path','/chat/completions','models_path','/models','default_model','openai/gpt-oss-20b','preferred_code_model','openai/gpt-oss-120b','credential_env','GROQ_API_KEY'),jsonb_build_object('failover_candidate',true,'priority',1),'world8-bootstrap');
select public.world8_provider_execution_adapter_register_v1('adapter-deepseek-external-v01','DeepSeek','REAL_EXTERNAL','envref:DEEPSEEK_API_KEY',jsonb_build_array('deepseek-v4-flash'),jsonb_build_array('CODE_ASSIST','OPENAI_COMPATIBLE_CHAT'),jsonb_build_object('base_url','https://api.deepseek.com','chat_path','/chat/completions','models_path','/models','default_model','deepseek-v4-flash','credential_env','DEEPSEEK_API_KEY'),jsonb_build_object('failover_candidate',true,'priority',2),'world8-bootstrap');
select public.world8_provider_execution_adapter_register_v1('adapter-openrouter-external-v01','OpenRouter','REAL_EXTERNAL','envref:OPENROUTER_API_KEY',jsonb_build_array('openrouter/free'),jsonb_build_array('CODE_ASSIST','OPENAI_COMPATIBLE_CHAT','FREE_ROUTER'),jsonb_build_object('base_url','https://openrouter.ai/api/v1','chat_path','/chat/completions','models_path','/models','default_model','openrouter/free','credential_env','OPENROUTER_API_KEY','default_headers',jsonb_build_object('HTTP-Referer','https://github.com/saeedfaai/world-8','X-OpenRouter-Title','World 8')),jsonb_build_object('failover_candidate',true,'priority',3),'world8-bootstrap');
select public.world8_provider_execution_adapter_register_v1('adapter-cerebras-external-v01','Cerebras','REAL_EXTERNAL','envref:CEREBRAS_API_KEY',jsonb_build_array('gpt-oss-120b'),jsonb_build_array('CODE_ASSIST','OPENAI_COMPATIBLE_CHAT'),jsonb_build_object('base_url','https://api.cerebras.ai/v1','chat_path','/chat/completions','models_path','/models','default_model','gpt-oss-120b','credential_env','CEREBRAS_API_KEY'),jsonb_build_object('failover_candidate',true,'priority',4),'world8-bootstrap');
select public.world8_provider_execution_adapter_register_v1('adapter-mistral-external-v01','Mistral','REAL_EXTERNAL','envref:MISTRAL_API_KEY',jsonb_build_array('mistral-small-latest','mistral-large-latest'),jsonb_build_array('CODE_ASSIST','OPENAI_COMPATIBLE_CHAT'),jsonb_build_object('base_url','https://api.mistral.ai/v1','chat_path','/chat/completions','models_path','/models','default_model','mistral-small-latest','preferred_code_model','mistral-large-latest','credential_env','MISTRAL_API_KEY'),jsonb_build_object('failover_candidate',true,'priority',5),'world8-bootstrap');

select public.world8_provider_credential_binding_register_v1('binding-groq-envref-v01','adapter-groq-external-v01','envref:GROQ_API_KEY',jsonb_build_object('purpose','PROVIDER_FAILOVER_MESH_V01'),'world8-bootstrap');
select public.world8_provider_credential_binding_register_v1('binding-deepseek-envref-v01','adapter-deepseek-external-v01','envref:DEEPSEEK_API_KEY',jsonb_build_object('purpose','PROVIDER_FAILOVER_MESH_V01'),'world8-bootstrap');
select public.world8_provider_credential_binding_register_v1('binding-openrouter-envref-v01','adapter-openrouter-external-v01','envref:OPENROUTER_API_KEY',jsonb_build_object('purpose','PROVIDER_FAILOVER_MESH_V01'),'world8-bootstrap');
select public.world8_provider_credential_binding_register_v1('binding-cerebras-envref-v01','adapter-cerebras-external-v01','envref:CEREBRAS_API_KEY',jsonb_build_object('purpose','PROVIDER_FAILOVER_MESH_V01'),'world8-bootstrap');
select public.world8_provider_credential_binding_register_v1('binding-mistral-envref-v01','adapter-mistral-external-v01','envref:MISTRAL_API_KEY',jsonb_build_object('purpose','PROVIDER_FAILOVER_MESH_V01'),'world8-bootstrap');

-- Transports point to the generic World 8 provider worker. Transport verification is runtime evidence, not seeded.
select public.world8_provider_worker_transport_register_v1('transport-supabase-groq-generic-v01','adapter-groq-external-v01','EXTERNAL_HTTP','https://ogiqujrubsvzohqremuv.supabase.co/functions/v1/world8-provider-worker-generic-v01',jsonb_build_array('CHALLENGE_ATTESTATION','CREDENTIAL_PROBE','GOVERNED_EXECUTION'),100,jsonb_build_object('worker_id','world8-provider-worker-generic-v01'),jsonb_build_object('purpose','PROVIDER_FAILOVER_MESH_V01'),'world8-bootstrap');
select public.world8_provider_worker_transport_register_v1('transport-supabase-deepseek-generic-v01','adapter-deepseek-external-v01','EXTERNAL_HTTP','https://ogiqujrubsvzohqremuv.supabase.co/functions/v1/world8-provider-worker-generic-v01',jsonb_build_array('CHALLENGE_ATTESTATION','CREDENTIAL_PROBE','GOVERNED_EXECUTION'),100,jsonb_build_object('worker_id','world8-provider-worker-generic-v01'),jsonb_build_object('purpose','PROVIDER_FAILOVER_MESH_V01'),'world8-bootstrap');
select public.world8_provider_worker_transport_register_v1('transport-supabase-openrouter-generic-v01','adapter-openrouter-external-v01','EXTERNAL_HTTP','https://ogiqujrubsvzohqremuv.supabase.co/functions/v1/world8-provider-worker-generic-v01',jsonb_build_array('CHALLENGE_ATTESTATION','CREDENTIAL_PROBE','GOVERNED_EXECUTION'),100,jsonb_build_object('worker_id','world8-provider-worker-generic-v01'),jsonb_build_object('purpose','PROVIDER_FAILOVER_MESH_V01'),'world8-bootstrap');
select public.world8_provider_worker_transport_register_v1('transport-supabase-cerebras-generic-v01','adapter-cerebras-external-v01','EXTERNAL_HTTP','https://ogiqujrubsvzohqremuv.supabase.co/functions/v1/world8-provider-worker-generic-v01',jsonb_build_array('CHALLENGE_ATTESTATION','CREDENTIAL_PROBE','GOVERNED_EXECUTION'),100,jsonb_build_object('worker_id','world8-provider-worker-generic-v01'),jsonb_build_object('purpose','PROVIDER_FAILOVER_MESH_V01'),'world8-bootstrap');
select public.world8_provider_worker_transport_register_v1('transport-supabase-mistral-generic-v01','adapter-mistral-external-v01','EXTERNAL_HTTP','https://ogiqujrubsvzohqremuv.supabase.co/functions/v1/world8-provider-worker-generic-v01',jsonb_build_array('CHALLENGE_ATTESTATION','CREDENTIAL_PROBE','GOVERNED_EXECUTION'),100,jsonb_build_object('worker_id','world8-provider-worker-generic-v01'),jsonb_build_object('purpose','PROVIDER_FAILOVER_MESH_V01'),'world8-bootstrap');

select public.world8_provider_failover_policy_register_v1('provider-failover-code-assist-v01','CODE_ASSIST_PRIMARY',1,'CODE_ASSIST',jsonb_build_array('adapter-groq-external-v01','adapter-deepseek-external-v01','adapter-openrouter-external-v01','adapter-cerebras-external-v01','adapter-mistral-external-v01','adapter-openai-external-v01'),1,false,jsonb_build_object('governance','HUMAN_OR_EXPLICIT_WORK_DISPATCH_ONLY','scale_out_requires_successful_canary',true),'world8-bootstrap');
