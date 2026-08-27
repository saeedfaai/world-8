create or replace function public.world8_provider_credential_probe_dispatch_v1(
  p_binding_id text,
  p_transport_id text,
  p_ttl_seconds integer default 180,
  p_metadata jsonb default '{}'::jsonb
) returns jsonb
language plpgsql
security definer
set search_path=public,extensions,net
as $$
declare
  v_binding public.world8_provider_credential_bindings%rowtype;
  v_transport public.world8_provider_worker_transports%rowtype;
  v_probe jsonb;
  v_request_id bigint;
begin
  select * into v_binding
  from public.world8_provider_credential_bindings
  where binding_id=p_binding_id and status='ACTIVE';
  if not found then raise exception 'ACTIVE_CREDENTIAL_BINDING_REQUIRED'; end if;

  select * into v_transport
  from public.world8_provider_worker_transports
  where transport_id=p_transport_id and status='ACTIVE' and verification_state='VERIFIED';
  if not found then raise exception 'VERIFIED_WORKER_TRANSPORT_REQUIRED'; end if;

  if v_binding.adapter_id<>v_transport.adapter_id or v_binding.provider<>v_transport.provider then
    raise exception 'CREDENTIAL_TRANSPORT_PROVIDER_MISMATCH';
  end if;
  if coalesce(v_transport.endpoint_ref,'')='' then raise exception 'WORKER_ENDPOINT_REQUIRED'; end if;
  if not public.world8_provider_execution_json_safe_v1(coalesce(p_metadata,'{}'::jsonb)) then
    raise exception 'CREDENTIAL_PROBE_SECRET_OR_PRIVATE_REASONING_REJECTED';
  end if;

  v_probe := public.world8_provider_credential_probe_issue_v1(
    p_binding_id=>p_binding_id,
    p_transport_id=>p_transport_id,
    p_ttl_seconds=>p_ttl_seconds,
    p_metadata=>coalesce(p_metadata,'{}'::jsonb) || jsonb_build_object('dispatch_mode','PG_NET_ASYNC')
  );

  select net.http_post(
    url:=v_transport.endpoint_ref,
    headers:=jsonb_build_object('Content-Type','application/json'),
    body:=jsonb_build_object(
      'action','credential_probe',
      'challenge_id',v_probe->>'challenge_id',
      'probe_token',v_probe->>'probe_token',
      'credential_ref',v_probe->>'credential_ref'
    )
  ) into v_request_id;

  return jsonb_build_object(
    'schema','WORLD8_PROVIDER_CREDENTIAL_PROBE_DISPATCH/1.0',
    'binding_id',p_binding_id,
    'transport_id',p_transport_id,
    'challenge_id',v_probe->>'challenge_id',
    'net_request_id',v_request_id,
    'expires_at',v_probe->>'expires_at',
    'ephemeral_token_exposed',false,
    'raw_secret_returned',false
  );
end $$;

revoke all on function public.world8_provider_credential_probe_dispatch_v1(text,text,integer,jsonb) from public,anon,authenticated;
grant execute on function public.world8_provider_credential_probe_dispatch_v1(text,text,integer,jsonb) to service_role;
