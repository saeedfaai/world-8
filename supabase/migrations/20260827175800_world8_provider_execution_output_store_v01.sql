create table if not exists public.world8_provider_execution_outputs (
  output_id text primary key,
  world_id text not null default 'world-001',
  request_id text not null references public.world8_provider_execution_requests(request_id),
  execution_id text not null,
  provider text not null,
  model_id text,
  content_kind text not null check (content_kind in ('CODE_TEXT','UNIFIED_DIFF','JSON')),
  content_text text not null,
  content_sha256 text not null,
  byte_length integer not null check (byte_length >= 1 and byte_length <= 65536),
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default clock_timestamp()
);

create or replace function public.world8_provider_execution_outputs_append_only_v1()
returns trigger language plpgsql as $$
begin
  raise exception 'PROVIDER_EXECUTION_OUTPUTS_APPEND_ONLY';
end $$;

drop trigger if exists world8_provider_execution_outputs_append_only_trg on public.world8_provider_execution_outputs;
create trigger world8_provider_execution_outputs_append_only_trg
before update or delete on public.world8_provider_execution_outputs
for each row execute function public.world8_provider_execution_outputs_append_only_v1();

alter table public.world8_provider_execution_outputs enable row level security;
revoke all on public.world8_provider_execution_outputs from public, anon, authenticated;
grant select, insert on public.world8_provider_execution_outputs to service_role;

create or replace function public.world8_provider_execution_output_record_v1(
  p_request_id text,
  p_claim_token text,
  p_content_kind text,
  p_content_text text,
  p_metadata jsonb default '{}'::jsonb
) returns jsonb
language plpgsql
security definer
set search_path to 'public','extensions'
as $$
declare
  q public.world8_provider_execution_requests%rowtype;
  a public.world8_provider_execution_adapters%rowtype;
  v_now timestamptz := clock_timestamp();
  v_bytes integer;
  v_sha text;
  v_id text;
begin
  if p_content_kind not in ('CODE_TEXT','UNIFIED_DIFF','JSON') then raise exception 'INVALID_PROVIDER_OUTPUT_KIND'; end if;
  if coalesce(p_content_text,'')='' then raise exception 'PROVIDER_OUTPUT_CONTENT_REQUIRED'; end if;
  v_bytes := octet_length(p_content_text);
  if v_bytes < 1 or v_bytes > 65536 then raise exception 'PROVIDER_OUTPUT_SIZE_OUT_OF_RANGE'; end if;
  if not public.world8_provider_execution_text_safe_v1(p_content_text) or not public.world8_provider_execution_json_safe_v1(coalesce(p_metadata,'{}'::jsonb)) then
    raise exception 'PROVIDER_OUTPUT_SECRET_OR_PRIVATE_REASONING_REJECTED';
  end if;
  select * into q from public.world8_provider_execution_requests where request_id=p_request_id;
  if not found or q.state<>'RUNNING' then raise exception 'RUNNING_EXECUTION_REQUEST_REQUIRED'; end if;
  if q.claim_token is distinct from p_claim_token then raise exception 'EXECUTION_CLAIM_TOKEN_MISMATCH'; end if;
  select * into a from public.world8_provider_execution_adapters where adapter_id=q.adapter_id;
  v_sha := encode(extensions.digest(p_content_text,'sha256'),'hex');
  v_id := 'provider-output-' || substr(encode(extensions.digest(p_request_id||'|'||q.execution_id||'|'||v_sha,'sha256'),'hex'),1,28);
  insert into public.world8_provider_execution_outputs(output_id,request_id,execution_id,provider,model_id,content_kind,content_text,content_sha256,byte_length,metadata,created_at)
  values(v_id,p_request_id,q.execution_id,a.provider,q.requested_model_id,p_content_kind,p_content_text,v_sha,v_bytes,coalesce(p_metadata,'{}'::jsonb)||jsonb_build_object('raw_secret_present',false,'private_reasoning_present',false),v_now)
  on conflict(output_id) do nothing;
  return jsonb_build_object('schema','WORLD8_PROVIDER_EXECUTION_OUTPUT/1.0','output_id',v_id,'output_ref','provider-output:'||v_id,'request_id',p_request_id,'execution_id',q.execution_id,'content_kind',p_content_kind,'content_sha256',v_sha,'byte_length',v_bytes,'raw_secret_returned',false);
end $$;

revoke all on function public.world8_provider_execution_output_record_v1(text,text,text,text,jsonb) from public, anon, authenticated;
grant execute on function public.world8_provider_execution_output_record_v1(text,text,text,text,jsonb) to service_role;
