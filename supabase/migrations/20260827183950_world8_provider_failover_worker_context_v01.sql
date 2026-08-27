-- World 8 generic provider worker context v0.1
-- Provides only opaque credential refs and provider routing configuration.

create or replace function public.world8_provider_execution_adapter_profile_v1(p_adapter_id text)
returns jsonb
language plpgsql security definer set search_path=public as $$
declare
  a public.world8_provider_execution_adapters%rowtype;
  b public.world8_provider_credential_bindings%rowtype;
  t public.world8_provider_worker_transports%rowtype;
begin
  select * into a from public.world8_provider_execution_adapters where adapter_id=p_adapter_id and status='ACTIVE';
  if not found then raise exception 'ACTIVE_PROVIDER_ADAPTER_REQUIRED'; end if;
  select * into b from public.world8_provider_credential_bindings where adapter_id=p_adapter_id and status='ACTIVE' order by (verification_state='VERIFIED') desc,created_at desc limit 1;
  select * into t from public.world8_provider_worker_transports where adapter_id=p_adapter_id and status='ACTIVE' order by (verification_state='VERIFIED') desc,created_at desc limit 1;
  return jsonb_build_object(
    'schema','WORLD8_PROVIDER_ADAPTER_PROFILE/1.0',
    'adapter_id',a.adapter_id,'provider',a.provider,'adapter_kind',a.adapter_kind,'supported_models',a.supported_models,'capabilities',a.capabilities,
    'config',a.config,'binding_id',b.binding_id,'credential_ref',b.credential_ref,'credential_verification_state',b.verification_state,
    'transport_id',t.transport_id,'transport_kind',t.transport_kind,'endpoint_ref',t.endpoint_ref,'transport_verification_state',t.verification_state,
    'raw_secret_returned',false
  );
end $$;

create or replace function public.world8_provider_worker_route_context_v1(p_transport_id text)
returns jsonb
language plpgsql security definer set search_path=public as $$
declare
  t public.world8_provider_worker_transports%rowtype;
  a public.world8_provider_execution_adapters%rowtype;
  b public.world8_provider_credential_bindings%rowtype;
begin
  select * into t from public.world8_provider_worker_transports where transport_id=p_transport_id and status='ACTIVE';
  if not found then raise exception 'ACTIVE_WORKER_TRANSPORT_REQUIRED'; end if;
  select * into a from public.world8_provider_execution_adapters where adapter_id=t.adapter_id and status='ACTIVE';
  if not found then raise exception 'ACTIVE_PROVIDER_ADAPTER_REQUIRED'; end if;
  select * into b from public.world8_provider_credential_bindings where adapter_id=a.adapter_id and status='ACTIVE' order by (verification_state='VERIFIED') desc,created_at desc limit 1;
  return jsonb_build_object(
    'schema','WORLD8_PROVIDER_WORKER_ROUTE_CONTEXT/1.0',
    'transport_id',t.transport_id,'adapter_id',a.adapter_id,'provider',a.provider,'config',a.config,'supported_models',a.supported_models,
    'binding_id',b.binding_id,'credential_ref',b.credential_ref,'credential_verification_state',b.verification_state,
    'transport_verification_state',t.verification_state,'raw_secret_returned',false
  );
end $$;

create or replace function public.world8_provider_credential_probe_context_v1(p_challenge_id text)
returns jsonb
language plpgsql security definer set search_path=public as $$
declare
  c public.world8_provider_credential_probe_challenges%rowtype;
  r jsonb;
begin
  select * into c from public.world8_provider_credential_probe_challenges where challenge_id=p_challenge_id;
  if not found then raise exception 'CREDENTIAL_PROBE_CHALLENGE_REQUIRED'; end if;
  r:=public.world8_provider_worker_route_context_v1(c.transport_id);
  if r->>'binding_id' is distinct from c.binding_id then raise exception 'CREDENTIAL_PROBE_BINDING_CONTEXT_MISMATCH'; end if;
  return r||jsonb_build_object('challenge_id',c.challenge_id,'challenge_state',c.state,'binding_id',c.binding_id,'transport_id',c.transport_id);
end $$;

revoke all on function public.world8_provider_execution_adapter_profile_v1(text),public.world8_provider_worker_route_context_v1(text),public.world8_provider_credential_probe_context_v1(text) from public,anon,authenticated;
grant execute on function public.world8_provider_execution_adapter_profile_v1(text),public.world8_provider_worker_route_context_v1(text),public.world8_provider_credential_probe_context_v1(text) to service_role;