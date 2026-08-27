create extension if not exists pg_net;

create or replace function public.world8_provider_worker_challenge_dispatch_v1(
  p_transport_id text,
  p_ttl_seconds integer default 180,
  p_metadata jsonb default '{}'::jsonb
) returns jsonb
language plpgsql
security definer
set search_path=public,extensions,net
as $$
declare
  v_transport public.world8_provider_worker_transports%rowtype;
  v_challenge jsonb;
  v_request_id bigint;
begin
  select * into v_transport
  from public.world8_provider_worker_transports
  where transport_id=p_transport_id and status='ACTIVE';
  if not found then raise exception 'ACTIVE_WORKER_TRANSPORT_REQUIRED'; end if;
  if coalesce(v_transport.endpoint_ref,'')='' then raise exception 'WORKER_ENDPOINT_REQUIRED'; end if;
  if not public.world8_provider_execution_json_safe_v1(coalesce(p_metadata,'{}'::jsonb)) then
    raise exception 'WORKER_CHALLENGE_SECRET_OR_PRIVATE_REASONING_REJECTED';
  end if;

  v_challenge := public.world8_provider_worker_challenge_issue_v1(
    p_transport_id=>p_transport_id,
    p_ttl_seconds=>p_ttl_seconds,
    p_metadata=>coalesce(p_metadata,'{}'::jsonb) || jsonb_build_object('dispatch_mode','PG_NET_ASYNC')
  );

  select net.http_post(
    url:=v_transport.endpoint_ref,
    headers:=jsonb_build_object('Content-Type','application/json'),
    body:=jsonb_build_object(
      'challenge_id',v_challenge->>'challenge_id',
      'challenge_token',v_challenge->>'challenge_token'
    )
  ) into v_request_id;

  return jsonb_build_object(
    'schema','WORLD8_PROVIDER_WORKER_CHALLENGE_DISPATCH/1.0',
    'transport_id',p_transport_id,
    'challenge_id',v_challenge->>'challenge_id',
    'net_request_id',v_request_id,
    'expires_at',v_challenge->>'expires_at',
    'ephemeral_token_exposed',false,
    'provider_invoked',false
  );
end $$;

revoke all on function public.world8_provider_worker_challenge_dispatch_v1(text,integer,jsonb) from public,anon,authenticated;
grant execute on function public.world8_provider_worker_challenge_dispatch_v1(text,integer,jsonb) to service_role;
