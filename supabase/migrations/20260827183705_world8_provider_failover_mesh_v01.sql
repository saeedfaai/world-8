-- World 8 Provider Failover Mesh v0.1
-- Provider/model remains Execution metadata. Failover selection is advisory and human/work-dispatch gated.

create table if not exists public.world8_provider_failover_policies (
  policy_id text primary key,
  world_id text not null default 'world-001',
  policy_key text not null,
  policy_version integer not null check (policy_version >= 1),
  capability text not null,
  ordered_adapter_ids jsonb not null check (jsonb_typeof(ordered_adapter_ids)='array' and jsonb_array_length(ordered_adapter_ids)>=1),
  selection_mode text not null default 'FIRST_LIVE_READY' check (selection_mode='FIRST_LIVE_READY'),
  automatic_retry boolean not null default false,
  max_attempts integer not null default 1 check (max_attempts between 1 and 10),
  status text not null default 'FROZEN' check (status in ('FROZEN','RETIRED')),
  metadata jsonb not null default '{}'::jsonb,
  created_by text not null,
  created_at timestamptz not null default clock_timestamp(),
  content_hash text not null,
  unique(policy_key,policy_version)
);

create or replace function public.world8_provider_failover_append_only_v1()
returns trigger language plpgsql security definer set search_path=public as $$
begin raise exception 'PROVIDER_FAILOVER_POLICY_APPEND_ONLY'; end $$;

drop trigger if exists world8_provider_failover_append_only_trg on public.world8_provider_failover_policies;
create trigger world8_provider_failover_append_only_trg
before update or delete on public.world8_provider_failover_policies
for each row execute function public.world8_provider_failover_append_only_v1();

create or replace function public.world8_provider_failover_policy_register_v1(
  p_policy_id text,
  p_policy_key text,
  p_policy_version integer,
  p_capability text,
  p_ordered_adapter_ids jsonb,
  p_max_attempts integer default 1,
  p_automatic_retry boolean default false,
  p_metadata jsonb default '{}'::jsonb,
  p_created_by text default 'human-root'
) returns jsonb
language plpgsql security definer set search_path=public,extensions as $$
declare
  v_now timestamptz:=clock_timestamp();
  v_hash text;
  v_id text;
  v_total int;
  v_distinct int;
begin
  if coalesce(btrim(p_policy_id),'')='' or coalesce(btrim(p_policy_key),'')='' or coalesce(btrim(p_capability),'')='' then
    raise exception 'FAILOVER_POLICY_ID_KEY_CAPABILITY_REQUIRED';
  end if;
  if p_policy_version < 1 or p_max_attempts < 1 or p_max_attempts > 10 then raise exception 'INVALID_FAILOVER_POLICY_VERSION_OR_ATTEMPTS'; end if;
  if p_automatic_retry then raise exception 'FAILOVER_AUTOMATIC_RETRY_DISABLED_V01'; end if;
  if jsonb_typeof(coalesce(p_ordered_adapter_ids,'null'::jsonb)) <> 'array' or jsonb_array_length(p_ordered_adapter_ids)=0 then raise exception 'FAILOVER_ADAPTER_ORDER_REQUIRED'; end if;
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

-- Provider routes. These calls store opaque env references only; no secret values enter DCP.
select public.world8_provider_execution_adapter_register_v1(
  'adapter-groq-external-v01','Groq','REAL_EXTERNAL','envref:GROQ_API_KEY',
  '["openai/gpt-oss-20b","openai/gpt-oss-120b"]'::jsonb,
  '["CODE_ASSIST","OPENAI_COMPATIBLE_CHAT"]'::jsonb,
  '{"base_url":"https://api.groq.com/openai/v1","chat_path":"/chat/completions","models_path":"/models","default_model":"openai/gpt-oss-20b","credential_env":"GROQ_API_KEY","preferred_code_model":"openai/gpt-oss-120b"}'::jsonb,
  '{"priority":1,"failover_candidate":true}'::jsonb,'chatgpt-mason');
select public.world8_provider_execution_adapter_register_v1(
  'adapter-deepseek-external-v01','DeepSeek','REAL_EXTERNAL','envref:DEEPSEEK_API_KEY',
  '["deepseek-v4-flash"]'::jsonb,'["CODE_ASSIST","OPENAI_COMPATIBLE_CHAT"]'::jsonb,
  '{"base_url":"https://api.deepseek.com","chat_path":"/chat/completions","models_path":"/models","default_model":"deepseek-v4-flash","credential_env":"DEEPSEEK_API_KEY"}'::jsonb,
  '{"priority":2,"failover_candidate":true}'::jsonb,'chatgpt-mason');
select public.world8_provider_execution_adapter_register_v1(
  'adapter-openrouter-external-v01','OpenRouter','REAL_EXTERNAL','envref:OPENROUTER_API_KEY',
  '["openrouter/free"]'::jsonb,'["CODE_ASSIST","OPENAI_COMPATIBLE_CHAT","FREE_ROUTER"]'::jsonb,
  '{"base_url":"https://openrouter.ai/api/v1","chat_path":"/chat/completions","models_path":"/models","default_model":"openrouter/free","credential_env":"OPENROUTER_API_KEY","default_headers":{"HTTP-Referer":"https://github.com/saeedfaai/world-8","X-OpenRouter-Title":"World 8"}}'::jsonb,
  '{"priority":3,"failover_candidate":true}'::jsonb,'chatgpt-mason');
select public.world8_provider_execution_adapter_register_v1(
  'adapter-cerebras-external-v01','Cerebras','REAL_EXTERNAL','envref:CEREBRAS_API_KEY',
  '["gpt-oss-120b"]'::jsonb,'["CODE_ASSIST","OPENAI_COMPATIBLE_CHAT"]'::jsonb,
  '{"base_url":"https://api.cerebras.ai/v1","chat_path":"/chat/completions","models_path":"/models","default_model":"gpt-oss-120b","credential_env":"CEREBRAS_API_KEY"}'::jsonb,
  '{"priority":4,"failover_candidate":true}'::jsonb,'chatgpt-mason');
select public.world8_provider_execution_adapter_register_v1(
  'adapter-mistral-external-v01','Mistral','REAL_EXTERNAL','envref:MISTRAL_API_KEY',
  '["mistral-small-latest","mistral-large-latest"]'::jsonb,'["CODE_ASSIST","OPENAI_COMPATIBLE_CHAT"]'::jsonb,
  '{"base_url":"https://api.mistral.ai/v1","chat_path":"/chat/completions","models_path":"/models","default_model":"mistral-small-latest","credential_env":"MISTRAL_API_KEY","preferred_code_model":"mistral-large-latest"}'::jsonb,
  '{"priority":5,"failover_candidate":true}'::jsonb,'chatgpt-mason');

select public.world8_provider_credential_binding_register_v1('binding-groq-envref-v01','adapter-groq-external-v01','envref:GROQ_API_KEY','{"failover_candidate":true}'::jsonb,'chatgpt-mason');
select public.world8_provider_credential_binding_register_v1('binding-deepseek-envref-v01','adapter-deepseek-external-v01','envref:DEEPSEEK_API_KEY','{"failover_candidate":true}'::jsonb,'chatgpt-mason');
select public.world8_provider_credential_binding_register_v1('binding-openrouter-envref-v01','adapter-openrouter-external-v01','envref:OPENROUTER_API_KEY','{"failover_candidate":true}'::jsonb,'chatgpt-mason');
select public.world8_provider_credential_binding_register_v1('binding-cerebras-envref-v01','adapter-cerebras-external-v01','envref:CEREBRAS_API_KEY','{"failover_candidate":true}'::jsonb,'chatgpt-mason');
select public.world8_provider_credential_binding_register_v1('binding-mistral-envref-v01','adapter-mistral-external-v01','envref:MISTRAL_API_KEY','{"failover_candidate":true}'::jsonb,'chatgpt-mason');

select public.world8_provider_worker_transport_register_v1('transport-supabase-groq-generic-v01','adapter-groq-external-v01','EXTERNAL_HTTP','https://ogiqujrubsvzohqremuv.supabase.co/functions/v1/world8-provider-worker-generic-v01','["GENERIC_CHAT","CREDENTIAL_PROBE"]'::jsonb,100,'{"worker_id":"world8-provider-worker-generic-v01"}'::jsonb,'{}'::jsonb,'chatgpt-mason');
select public.world8_provider_worker_transport_register_v1('transport-supabase-deepseek-generic-v01','adapter-deepseek-external-v01','EXTERNAL_HTTP','https://ogiqujrubsvzohqremuv.supabase.co/functions/v1/world8-provider-worker-generic-v01','["GENERIC_CHAT","CREDENTIAL_PROBE"]'::jsonb,100,'{"worker_id":"world8-provider-worker-generic-v01"}'::jsonb,'{}'::jsonb,'chatgpt-mason');
select public.world8_provider_worker_transport_register_v1('transport-supabase-openrouter-generic-v01','adapter-openrouter-external-v01','EXTERNAL_HTTP','https://ogiqujrubsvzohqremuv.supabase.co/functions/v1/world8-provider-worker-generic-v01','["GENERIC_CHAT","CREDENTIAL_PROBE"]'::jsonb,100,'{"worker_id":"world8-provider-worker-generic-v01"}'::jsonb,'{}'::jsonb,'chatgpt-mason');
select public.world8_provider_worker_transport_register_v1('transport-supabase-cerebras-generic-v01','adapter-cerebras-external-v01','EXTERNAL_HTTP','https://ogiqujrubsvzohqremuv.supabase.co/functions/v1/world8-provider-worker-generic-v01','["GENERIC_CHAT","CREDENTIAL_PROBE"]'::jsonb,100,'{"worker_id":"world8-provider-worker-generic-v01"}'::jsonb,'{}'::jsonb,'chatgpt-mason');
select public.world8_provider_worker_transport_register_v1('transport-supabase-mistral-generic-v01','adapter-mistral-external-v01','EXTERNAL_HTTP','https://ogiqujrubsvzohqremuv.supabase.co/functions/v1/world8-provider-worker-generic-v01','["GENERIC_CHAT","CREDENTIAL_PROBE"]'::jsonb,100,'{"worker_id":"world8-provider-worker-generic-v01"}'::jsonb,'{}'::jsonb,'chatgpt-mason');

select public.world8_provider_failover_policy_register_v1(
  'provider-failover-code-assist-v01','CODE_ASSIST_PRIMARY',1,'CODE_ASSIST',
  '["adapter-groq-external-v01","adapter-deepseek-external-v01","adapter-openrouter-external-v01","adapter-cerebras-external-v01","adapter-mistral-external-v01","adapter-openai-external-v01"]'::jsonb,
  1,false,'{"governance":"HUMAN_OR_EXPLICIT_WORK_DISPATCH_ONLY","openai_health_gate_required":true,"scale_out_requires_successful_canary":true}'::jsonb,'chatgpt-mason');

alter table public.world8_provider_failover_policies enable row level security;
revoke all on public.world8_provider_failover_policies from public,anon,authenticated;
grant all on public.world8_provider_failover_policies to service_role;
revoke all on function public.world8_provider_failover_policy_register_v1(text,text,integer,text,jsonb,integer,boolean,jsonb,text) from public,anon,authenticated;
grant execute on function public.world8_provider_failover_policy_register_v1(text,text,integer,text,jsonb,integer,boolean,jsonb,text) to service_role;