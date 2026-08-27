-- World 8 Credential Broker + External Worker v0.1
-- Replayable Git mirror of the live broker contract. Raw credential values never enter DCP.

create table if not exists public.world8_provider_credential_bindings (
  binding_id text primary key,
  world_id text not null default 'world-001',
  adapter_id text not null references public.world8_provider_execution_adapters(adapter_id),
  provider text not null,
  credential_ref text not null,
  binding_kind text not null check (binding_kind in ('VAULT','ENVREF','SECRETREF','CONNECTOR')),
  status text not null default 'ACTIVE' check (status in ('ACTIVE','REVOKED')),
  verification_state text not null default 'UNVERIFIED' check (verification_state in ('UNVERIFIED','PRESENT','VERIFIED','REVOKED')),
  verified_by_transport_id text,
  verified_at timestamptz,
  metadata jsonb not null default '{}'::jsonb check (jsonb_typeof(metadata)='object'),
  created_by text not null,
  created_at timestamptz not null default clock_timestamp(),
  updated_at timestamptz not null default clock_timestamp(),
  unique(world_id,adapter_id,credential_ref)
);

create table if not exists public.world8_provider_credential_verification_receipts (
  receipt_id text primary key,
  world_id text not null default 'world-001',
  binding_id text not null references public.world8_provider_credential_bindings(binding_id),
  adapter_id text not null references public.world8_provider_execution_adapters(adapter_id),
  transport_id text,
  verification_kind text not null check (verification_kind in ('PRESENCE_CHECK','PROVIDER_PROBE','REVOKED')),
  result text not null check (result in ('PASS','FAIL','REVOKED')),
  evidence_refs jsonb not null default '[]'::jsonb check (jsonb_typeof(evidence_refs)='array'),
  metadata jsonb not null default '{}'::jsonb check (jsonb_typeof(metadata)='object'),
  content_hash text not null,
  created_at timestamptz not null default clock_timestamp()
);

create table if not exists public.world8_provider_worker_transports (
  transport_id text primary key,
  world_id text not null default 'world-001',
  adapter_id text not null references public.world8_provider_execution_adapters(adapter_id),
  provider text not null,
  transport_kind text not null check (transport_kind in ('MOCK_INTERNAL','NETLIFY_EDGE','EXTERNAL_HTTP','CONNECTOR')),
  endpoint_ref text,
  status text not null default 'ACTIVE' check (status in ('ACTIVE','DEGRADED','REVOKED')),
  verification_state text not null default 'UNVERIFIED' check (verification_state in ('UNVERIFIED','VERIFIED','REVOKED')),
  capabilities jsonb not null default '[]'::jsonb check (jsonb_typeof(capabilities)='array'),
  max_parallel integer not null default 1 check (max_parallel between 1 and 500),
  config jsonb not null default '{}'::jsonb check (jsonb_typeof(config)='object'),
  metadata jsonb not null default '{}'::jsonb check (jsonb_typeof(metadata)='object'),
  verified_at timestamptz,
  created_by text not null,
  created_at timestamptz not null default clock_timestamp(),
  updated_at timestamptz not null default clock_timestamp()
);

alter table public.world8_provider_credential_bindings
  drop constraint if exists world8_provider_credential_bindings_verified_transport_fk;
alter table public.world8_provider_credential_bindings
  add constraint world8_provider_credential_bindings_verified_transport_fk
  foreign key (verified_by_transport_id) references public.world8_provider_worker_transports(transport_id) on delete set null;

create table if not exists public.world8_provider_worker_verification_receipts (
  receipt_id text primary key,
  world_id text not null default 'world-001',
  transport_id text not null references public.world8_provider_worker_transports(transport_id),
  adapter_id text not null references public.world8_provider_execution_adapters(adapter_id),
  verification_kind text not null check (verification_kind in ('MOCK_TEST','CHALLENGE_ATTESTATION','REVOKED')),
  result text not null check (result in ('PASS','FAIL','REVOKED')),
  evidence_refs jsonb not null default '[]'::jsonb check (jsonb_typeof(evidence_refs)='array'),
  metadata jsonb not null default '{}'::jsonb check (jsonb_typeof(metadata)='object'),
  content_hash text not null,
  created_at timestamptz not null default clock_timestamp()
);

create table if not exists public.world8_provider_worker_challenges (
  challenge_id text primary key,
  transport_id text not null references public.world8_provider_worker_transports(transport_id),
  token_hash text not null,
  state text not null default 'ISSUED' check (state in ('ISSUED','CONSUMED','EXPIRED')),
  issued_at timestamptz not null default clock_timestamp(),
  expires_at timestamptz not null,
  consumed_at timestamptz,
  metadata jsonb not null default '{}'::jsonb check (jsonb_typeof(metadata)='object')
);

create table if not exists public.world8_provider_credential_probe_challenges (
  challenge_id text primary key,
  binding_id text not null references public.world8_provider_credential_bindings(binding_id),
  transport_id text not null references public.world8_provider_worker_transports(transport_id),
  token_hash text not null,
  state text not null default 'ISSUED' check (state in ('ISSUED','CONSUMED','EXPIRED')),
  issued_at timestamptz not null default clock_timestamp(),
  expires_at timestamptz not null,
  consumed_at timestamptz,
  metadata jsonb not null default '{}'::jsonb check (jsonb_typeof(metadata)='object')
);

alter table public.world8_provider_execution_requests
  add column if not exists credential_binding_id text references public.world8_provider_credential_bindings(binding_id),
  add column if not exists worker_transport_id text references public.world8_provider_worker_transports(transport_id);

create index if not exists world8_provider_credential_binding_adapter_idx on public.world8_provider_credential_bindings(adapter_id,status,verification_state);
create index if not exists world8_provider_worker_transport_adapter_idx on public.world8_provider_worker_transports(adapter_id,status,verification_state);
create index if not exists world8_provider_worker_challenge_idx on public.world8_provider_worker_challenges(transport_id,state,expires_at);
create index if not exists world8_provider_credential_probe_idx on public.world8_provider_credential_probe_challenges(binding_id,state,expires_at);

create or replace function public.world8_provider_broker_receipts_append_only_v1()
returns trigger language plpgsql security definer set search_path=public as $$
begin raise exception 'WORLD8_PROVIDER_BROKER_RECEIPTS_APPEND_ONLY'; end $$;

drop trigger if exists world8_provider_credential_receipts_append_only_trg on public.world8_provider_credential_verification_receipts;
create trigger world8_provider_credential_receipts_append_only_trg before update or delete on public.world8_provider_credential_verification_receipts for each row execute function public.world8_provider_broker_receipts_append_only_v1();
drop trigger if exists world8_provider_worker_receipts_append_only_trg on public.world8_provider_worker_verification_receipts;
create trigger world8_provider_worker_receipts_append_only_trg before update or delete on public.world8_provider_worker_verification_receipts for each row execute function public.world8_provider_broker_receipts_append_only_v1();

create or replace function public.world8_provider_credential_binding_register_v1(
  p_binding_id text,p_adapter_id text,p_credential_ref text,p_metadata jsonb default '{}'::jsonb,p_created_by text default 'human-root'
) returns jsonb language plpgsql security definer set search_path=public as $$
declare a public.world8_provider_execution_adapters%rowtype; k text;
begin
  if coalesce(btrim(p_binding_id),'')='' then raise exception 'CREDENTIAL_BINDING_ID_REQUIRED'; end if;
  if p_credential_ref !~ '^(vault:|envref:|secretref:|connector:)[A-Za-z0-9._:/-]+$' then raise exception 'INVALID_OPAQUE_CREDENTIAL_REF'; end if;
  if not public.world8_provider_execution_text_safe_v1(p_credential_ref) or not public.world8_provider_execution_json_safe_v1(coalesce(p_metadata,'{}'::jsonb)) then raise exception 'CREDENTIAL_BINDING_SECRET_OR_PRIVATE_REASONING_REJECTED'; end if;
  select * into a from public.world8_provider_execution_adapters where adapter_id=p_adapter_id and status='ACTIVE';
  if not found then raise exception 'ACTIVE_PROVIDER_ADAPTER_REQUIRED'; end if;
  k:=case when p_credential_ref like 'vault:%' then 'VAULT' when p_credential_ref like 'envref:%' then 'ENVREF' when p_credential_ref like 'secretref:%' then 'SECRETREF' else 'CONNECTOR' end;
  insert into public.world8_provider_credential_bindings(binding_id,adapter_id,provider,credential_ref,binding_kind,status,verification_state,metadata,created_by)
  values(p_binding_id,p_adapter_id,a.provider,p_credential_ref,k,'ACTIVE','UNVERIFIED',coalesce(p_metadata,'{}'::jsonb),p_created_by)
  on conflict(binding_id) do nothing;
  return jsonb_build_object('schema','WORLD8_PROVIDER_CREDENTIAL_BINDING/1.0','binding_id',p_binding_id,'adapter_id',p_adapter_id,'provider',a.provider,'credential_ref',p_credential_ref,'binding_kind',k,'verification_state',(select verification_state from public.world8_provider_credential_bindings where binding_id=p_binding_id),'raw_secret_stored',false);
end $$;

create or replace function public.world8_provider_credential_presence_v1(p_binding_id text)
returns jsonb language plpgsql security definer set search_path=public,vault as $$
declare b public.world8_provider_credential_bindings%rowtype; present boolean:=false; v_name text; v_now timestamptz:=clock_timestamp(); h text; rid text;
begin
  select * into b from public.world8_provider_credential_bindings where binding_id=p_binding_id for update;
  if not found or b.status<>'ACTIVE' then raise exception 'ACTIVE_CREDENTIAL_BINDING_REQUIRED'; end if;
  if b.binding_kind='VAULT' then
    v_name:=substr(b.credential_ref,7);
    select exists(select 1 from vault.secrets s where s.name=v_name or s.id::text=v_name) into present;
  else
    return jsonb_build_object('schema','WORLD8_PROVIDER_CREDENTIAL_PRESENCE/1.0','binding_id',p_binding_id,'state','EXTERNAL_RESOLUTION_REQUIRED','present',false,'verified',false,'credential_ref',b.credential_ref,'raw_secret_returned',false);
  end if;
  if present and b.verification_state='UNVERIFIED' then update public.world8_provider_credential_bindings set verification_state='PRESENT',updated_at=v_now where binding_id=p_binding_id; end if;
  h:=encode(extensions.digest(p_binding_id||'|PRESENCE_CHECK|'||present::text||'|'||v_now::text,'sha256'),'hex'); rid:='credential-receipt-'||substr(h,1,28);
  insert into public.world8_provider_credential_verification_receipts(receipt_id,binding_id,adapter_id,verification_kind,result,evidence_refs,metadata,content_hash,created_at)
  values(rid,p_binding_id,b.adapter_id,'PRESENCE_CHECK',case when present then 'PASS' else 'FAIL' end,jsonb_build_array('opaque-ref:'||b.credential_ref),jsonb_build_object('presence_only',true,'provider_verified',false,'raw_secret_returned',false),h,v_now) on conflict do nothing;
  return jsonb_build_object('schema','WORLD8_PROVIDER_CREDENTIAL_PRESENCE/1.0','binding_id',p_binding_id,'state',case when present then 'PRESENT_NOT_VERIFIED' else 'NOT_PRESENT' end,'present',present,'verified',false,'credential_ref',b.credential_ref,'raw_secret_returned',false,'receipt_id',rid);
end $$;

create or replace function public.world8_provider_worker_transport_register_v1(
 p_transport_id text,p_adapter_id text,p_transport_kind text,p_endpoint_ref text,p_capabilities jsonb default '[]'::jsonb,p_max_parallel integer default 1,p_config jsonb default '{}'::jsonb,p_metadata jsonb default '{}'::jsonb,p_created_by text default 'human-root'
) returns jsonb language plpgsql security definer set search_path=public as $$
declare a public.world8_provider_execution_adapters%rowtype; ver text:='UNVERIFIED';
begin
  if p_transport_kind not in ('MOCK_INTERNAL','NETLIFY_EDGE','EXTERNAL_HTTP','CONNECTOR') then raise exception 'INVALID_WORKER_TRANSPORT_KIND'; end if;
  if p_max_parallel<1 or p_max_parallel>500 then raise exception 'WORKER_MAX_PARALLEL_OUT_OF_RANGE'; end if;
  if p_endpoint_ref is not null and not public.world8_provider_execution_text_safe_v1(p_endpoint_ref) then raise exception 'WORKER_ENDPOINT_SECRET_OR_PRIVATE_REASONING_REJECTED'; end if;
  if not public.world8_provider_execution_json_safe_v1(coalesce(p_capabilities,'[]'::jsonb)) or not public.world8_provider_execution_json_safe_v1(coalesce(p_config,'{}'::jsonb)) or not public.world8_provider_execution_json_safe_v1(coalesce(p_metadata,'{}'::jsonb)) then raise exception 'WORKER_TRANSPORT_SECRET_OR_PRIVATE_REASONING_REJECTED'; end if;
  select * into a from public.world8_provider_execution_adapters where adapter_id=p_adapter_id and status='ACTIVE'; if not found then raise exception 'ACTIVE_PROVIDER_ADAPTER_REQUIRED'; end if;
  if p_transport_kind='MOCK_INTERNAL' and a.adapter_kind<>'MOCK_INTERNAL' then raise exception 'MOCK_TRANSPORT_REQUIRES_MOCK_ADAPTER'; end if;
  if p_transport_kind='MOCK_INTERNAL' then ver:='VERIFIED'; end if;
  insert into public.world8_provider_worker_transports(transport_id,adapter_id,provider,transport_kind,endpoint_ref,status,verification_state,capabilities,max_parallel,config,metadata,verified_at,created_by)
  values(p_transport_id,p_adapter_id,a.provider,p_transport_kind,p_endpoint_ref,'ACTIVE',ver,coalesce(p_capabilities,'[]'::jsonb),p_max_parallel,coalesce(p_config,'{}'::jsonb),coalesce(p_metadata,'{}'::jsonb),case when ver='VERIFIED' then clock_timestamp() end,p_created_by)
  on conflict(transport_id) do nothing;
  return jsonb_build_object('schema','WORLD8_PROVIDER_WORKER_TRANSPORT/1.0','transport_id',p_transport_id,'adapter_id',p_adapter_id,'provider',a.provider,'transport_kind',p_transport_kind,'verification_state',(select verification_state from public.world8_provider_worker_transports where transport_id=p_transport_id),'live_ready',false,'test_only',p_transport_kind='MOCK_INTERNAL');
end $$;

create or replace function public.world8_provider_worker_challenge_issue_v1(p_transport_id text,p_ttl_seconds integer default 300,p_metadata jsonb default '{}'::jsonb)
returns jsonb language plpgsql security definer set search_path=public,extensions as $$
declare t public.world8_provider_worker_transports%rowtype; n timestamptz:=clock_timestamp(); token text; h text; id text;
begin
  if p_ttl_seconds<30 or p_ttl_seconds>900 then raise exception 'WORKER_CHALLENGE_TTL_OUT_OF_RANGE'; end if;
  if not public.world8_provider_execution_json_safe_v1(coalesce(p_metadata,'{}'::jsonb)) then raise exception 'WORKER_CHALLENGE_SECRET_OR_PRIVATE_REASONING_REJECTED'; end if;
  select * into t from public.world8_provider_worker_transports where transport_id=p_transport_id and status='ACTIVE'; if not found then raise exception 'ACTIVE_WORKER_TRANSPORT_REQUIRED'; end if;
  if t.transport_kind='MOCK_INTERNAL' then raise exception 'MOCK_TRANSPORT_DOES_NOT_REQUIRE_LIVE_CHALLENGE'; end if;
  token:=encode(extensions.digest(gen_random_uuid()::text||'|'||p_transport_id||'|'||n::text,'sha256'),'hex'); h:=encode(extensions.digest(token,'sha256'),'hex'); id:='worker-challenge-'||substr(encode(extensions.digest(p_transport_id||'|'||n::text,'sha256'),'hex'),1,28);
  insert into public.world8_provider_worker_challenges(challenge_id,transport_id,token_hash,state,issued_at,expires_at,metadata) values(id,p_transport_id,h,'ISSUED',n,n+make_interval(secs=>p_ttl_seconds),coalesce(p_metadata,'{}'::jsonb));
  return jsonb_build_object('schema','WORLD8_PROVIDER_WORKER_CHALLENGE/1.0','challenge_id',id,'transport_id',p_transport_id,'challenge_token',token,'expires_at',n+make_interval(secs=>p_ttl_seconds),'ephemeral_token',true);
end $$;

create or replace function public.world8_provider_worker_challenge_attest_v1(p_challenge_id text,p_challenge_token text,p_evidence_refs jsonb,p_metadata jsonb default '{}'::jsonb)
returns jsonb language plpgsql security definer set search_path=public,extensions as $$
declare c public.world8_provider_worker_challenges%rowtype; t public.world8_provider_worker_transports%rowtype; n timestamptz:=clock_timestamp(); h text; rid text;
begin
  if jsonb_typeof(coalesce(p_evidence_refs,'[]'::jsonb))<>'array' or jsonb_array_length(coalesce(p_evidence_refs,'[]'::jsonb))=0 then raise exception 'WORKER_ATTESTATION_EVIDENCE_REQUIRED'; end if;
  if not public.world8_provider_execution_json_safe_v1(p_evidence_refs) or not public.world8_provider_execution_json_safe_v1(coalesce(p_metadata,'{}'::jsonb)) then raise exception 'WORKER_ATTESTATION_SECRET_OR_PRIVATE_REASONING_REJECTED'; end if;
  select * into c from public.world8_provider_worker_challenges where challenge_id=p_challenge_id for update; if not found or c.state<>'ISSUED' then raise exception 'ISSUED_WORKER_CHALLENGE_REQUIRED'; end if;
  if c.expires_at<=n then update public.world8_provider_worker_challenges set state='EXPIRED' where challenge_id=p_challenge_id; raise exception 'WORKER_CHALLENGE_EXPIRED'; end if;
  if c.token_hash<>encode(extensions.digest(p_challenge_token,'sha256'),'hex') then raise exception 'WORKER_CHALLENGE_TOKEN_MISMATCH'; end if;
  select * into t from public.world8_provider_worker_transports where transport_id=c.transport_id for update; if not found or t.status<>'ACTIVE' then raise exception 'ACTIVE_WORKER_TRANSPORT_REQUIRED'; end if;
  update public.world8_provider_worker_challenges set state='CONSUMED',consumed_at=n where challenge_id=p_challenge_id;
  update public.world8_provider_worker_transports set verification_state='VERIFIED',verified_at=n,updated_at=n where transport_id=t.transport_id;
  h:=encode(extensions.digest(t.transport_id||'|CHALLENGE_ATTESTATION|PASS|'||p_challenge_id||'|'||n::text,'sha256'),'hex'); rid:='worker-receipt-'||substr(h,1,28);
  insert into public.world8_provider_worker_verification_receipts(receipt_id,transport_id,adapter_id,verification_kind,result,evidence_refs,metadata,content_hash,created_at) values(rid,t.transport_id,t.adapter_id,'CHALLENGE_ATTESTATION','PASS',p_evidence_refs,coalesce(p_metadata,'{}'::jsonb)||jsonb_build_object('challenge_id',p_challenge_id,'raw_secret_present',false),h,n);
  return jsonb_build_object('schema','WORLD8_PROVIDER_WORKER_ATTESTATION/1.0','transport_id',t.transport_id,'verification_state','VERIFIED','receipt_id',rid,'challenge_consumed',true);
end $$;

create or replace function public.world8_provider_credential_probe_issue_v1(p_binding_id text,p_transport_id text,p_ttl_seconds integer default 300,p_metadata jsonb default '{}'::jsonb)
returns jsonb language plpgsql security definer set search_path=public,extensions as $$
declare b public.world8_provider_credential_bindings%rowtype; t public.world8_provider_worker_transports%rowtype; n timestamptz:=clock_timestamp(); token text; h text; id text;
begin
  if p_ttl_seconds<30 or p_ttl_seconds>900 then raise exception 'CREDENTIAL_PROBE_TTL_OUT_OF_RANGE'; end if;
  if not public.world8_provider_execution_json_safe_v1(coalesce(p_metadata,'{}'::jsonb)) then raise exception 'CREDENTIAL_PROBE_SECRET_OR_PRIVATE_REASONING_REJECTED'; end if;
  select * into b from public.world8_provider_credential_bindings where binding_id=p_binding_id and status='ACTIVE'; if not found then raise exception 'ACTIVE_CREDENTIAL_BINDING_REQUIRED'; end if;
  select * into t from public.world8_provider_worker_transports where transport_id=p_transport_id and status='ACTIVE' and verification_state='VERIFIED'; if not found then raise exception 'VERIFIED_WORKER_TRANSPORT_REQUIRED'; end if;
  if b.adapter_id<>t.adapter_id or b.provider<>t.provider then raise exception 'CREDENTIAL_TRANSPORT_PROVIDER_MISMATCH'; end if;
  token:=encode(extensions.digest(gen_random_uuid()::text||'|'||p_binding_id||'|'||p_transport_id||'|'||n::text,'sha256'),'hex'); h:=encode(extensions.digest(token,'sha256'),'hex'); id:='credential-challenge-'||substr(encode(extensions.digest(p_binding_id||'|'||p_transport_id||'|'||n::text,'sha256'),'hex'),1,28);
  insert into public.world8_provider_credential_probe_challenges(challenge_id,binding_id,transport_id,token_hash,state,issued_at,expires_at,metadata) values(id,p_binding_id,p_transport_id,h,'ISSUED',n,n+make_interval(secs=>p_ttl_seconds),coalesce(p_metadata,'{}'::jsonb));
  return jsonb_build_object('schema','WORLD8_PROVIDER_CREDENTIAL_PROBE_CHALLENGE/1.0','challenge_id',id,'binding_id',p_binding_id,'transport_id',p_transport_id,'probe_token',token,'credential_ref',b.credential_ref,'expires_at',n+make_interval(secs=>p_ttl_seconds),'ephemeral_token',true,'raw_secret_returned',false);
end $$;

create or replace function public.world8_provider_credential_probe_attest_v1(p_challenge_id text,p_probe_token text,p_probe_result text,p_evidence_refs jsonb,p_metadata jsonb default '{}'::jsonb)
returns jsonb language plpgsql security definer set search_path=public,extensions as $$
declare c public.world8_provider_credential_probe_challenges%rowtype; b public.world8_provider_credential_bindings%rowtype; n timestamptz:=clock_timestamp(); h text; rid text;
begin
  if p_probe_result not in ('PASS','FAIL') then raise exception 'INVALID_CREDENTIAL_PROBE_RESULT'; end if;
  if jsonb_typeof(coalesce(p_evidence_refs,'[]'::jsonb))<>'array' or jsonb_array_length(coalesce(p_evidence_refs,'[]'::jsonb))=0 then raise exception 'CREDENTIAL_PROBE_EVIDENCE_REQUIRED'; end if;
  if not public.world8_provider_execution_json_safe_v1(p_evidence_refs) or not public.world8_provider_execution_json_safe_v1(coalesce(p_metadata,'{}'::jsonb)) then raise exception 'CREDENTIAL_PROBE_ATTESTATION_SECRET_OR_PRIVATE_REASONING_REJECTED'; end if;
  select * into c from public.world8_provider_credential_probe_challenges where challenge_id=p_challenge_id for update; if not found or c.state<>'ISSUED' then raise exception 'ISSUED_CREDENTIAL_PROBE_CHALLENGE_REQUIRED'; end if;
  if c.expires_at<=n then update public.world8_provider_credential_probe_challenges set state='EXPIRED' where challenge_id=p_challenge_id; raise exception 'CREDENTIAL_PROBE_CHALLENGE_EXPIRED'; end if;
  if c.token_hash<>encode(extensions.digest(p_probe_token,'sha256'),'hex') then raise exception 'CREDENTIAL_PROBE_TOKEN_MISMATCH'; end if;
  if not exists(select 1 from public.world8_provider_worker_transports where transport_id=c.transport_id and status='ACTIVE' and verification_state='VERIFIED') then raise exception 'VERIFIED_WORKER_TRANSPORT_REQUIRED'; end if;
  select * into b from public.world8_provider_credential_bindings where binding_id=c.binding_id and status='ACTIVE' for update; if not found then raise exception 'ACTIVE_CREDENTIAL_BINDING_REQUIRED'; end if;
  update public.world8_provider_credential_probe_challenges set state='CONSUMED',consumed_at=n where challenge_id=p_challenge_id;
  if p_probe_result='PASS' then update public.world8_provider_credential_bindings set verification_state='VERIFIED',verified_by_transport_id=c.transport_id,verified_at=n,updated_at=n where binding_id=b.binding_id; end if;
  h:=encode(extensions.digest(b.binding_id||'|PROVIDER_PROBE|'||p_probe_result||'|'||p_challenge_id||'|'||n::text,'sha256'),'hex'); rid:='credential-receipt-'||substr(h,1,28);
  insert into public.world8_provider_credential_verification_receipts(receipt_id,binding_id,adapter_id,transport_id,verification_kind,result,evidence_refs,metadata,content_hash,created_at) values(rid,b.binding_id,b.adapter_id,c.transport_id,'PROVIDER_PROBE',p_probe_result,p_evidence_refs,coalesce(p_metadata,'{}'::jsonb)||jsonb_build_object('challenge_id',p_challenge_id,'raw_secret_present',false),h,n);
  return jsonb_build_object('schema','WORLD8_PROVIDER_CREDENTIAL_PROBE_RESULT/1.0','binding_id',b.binding_id,'transport_id',c.transport_id,'probe_result',p_probe_result,'verification_state',case when p_probe_result='PASS' then 'VERIFIED' else b.verification_state end,'receipt_id',rid,'raw_secret_returned',false);
end $$;

create or replace function public.world8_provider_execution_readiness_v2(p_adapter_id text,p_transport_id text default null)
returns jsonb language plpgsql security definer set search_path=public as $$
declare a public.world8_provider_execution_adapters%rowtype; b public.world8_provider_credential_bindings%rowtype; t public.world8_provider_worker_transports%rowtype; blockers jsonb:='[]'::jsonb;
begin
  select * into a from public.world8_provider_execution_adapters where adapter_id=p_adapter_id;
  if not found then return jsonb_build_object('schema','WORLD8_PROVIDER_EXECUTION_READINESS/2.0','adapter_id',p_adapter_id,'gate_state','BLOCKED','live_ready',false,'blockers',jsonb_build_array('ADAPTER_NOT_FOUND')); end if;
  if a.status<>'ACTIVE' then blockers:=blockers||jsonb_build_array('ADAPTER_NOT_ACTIVE'); end if;
  if p_transport_id is not null then select * into t from public.world8_provider_worker_transports where transport_id=p_transport_id; else select * into t from public.world8_provider_worker_transports where adapter_id=p_adapter_id and status='ACTIVE' order by (verification_state='VERIFIED') desc,created_at desc limit 1; end if;
  if a.adapter_kind='MOCK_INTERNAL' then
    if t.transport_id is null then blockers:=blockers||jsonb_build_array('WORKER_TRANSPORT_NOT_FOUND'); elsif t.adapter_id<>p_adapter_id then blockers:=blockers||jsonb_build_array('WORKER_TRANSPORT_ADAPTER_MISMATCH'); elsif t.status<>'ACTIVE' or t.verification_state<>'VERIFIED' then blockers:=blockers||jsonb_build_array('WORKER_TRANSPORT_NOT_VERIFIED'); end if;
    return jsonb_build_object('schema','WORLD8_PROVIDER_EXECUTION_READINESS/2.0','adapter_id',p_adapter_id,'transport_id',t.transport_id,'gate_state',case when jsonb_array_length(blockers)=0 then 'PASS' else 'BLOCKED' end,'readiness_state',case when jsonb_array_length(blockers)=0 then 'TEST_ONLY' else 'NOT_READY' end,'live_ready',false,'test_only',true,'blockers',blockers,'raw_secret_returned',false);
  end if;
  select * into b from public.world8_provider_credential_bindings where adapter_id=p_adapter_id and status='ACTIVE' order by (verification_state='VERIFIED') desc,created_at desc limit 1;
  if b.binding_id is null then blockers:=blockers||jsonb_build_array('CREDENTIAL_BINDING_NOT_FOUND'); elsif b.verification_state<>'VERIFIED' then blockers:=blockers||jsonb_build_array('CREDENTIAL_BINDING_NOT_VERIFIED'); end if;
  if t.transport_id is null then blockers:=blockers||jsonb_build_array('WORKER_TRANSPORT_NOT_FOUND'); elsif t.adapter_id<>p_adapter_id then blockers:=blockers||jsonb_build_array('WORKER_TRANSPORT_ADAPTER_MISMATCH'); elsif t.status<>'ACTIVE' or t.verification_state<>'VERIFIED' then blockers:=blockers||jsonb_build_array('WORKER_TRANSPORT_NOT_VERIFIED'); end if;
  return jsonb_build_object('schema','WORLD8_PROVIDER_EXECUTION_READINESS/2.0','adapter_id',p_adapter_id,'provider',a.provider,'binding_id',b.binding_id,'credential_ref',b.credential_ref,'credential_verification_state',b.verification_state,'transport_id',t.transport_id,'transport_verification_state',t.verification_state,'gate_state',case when jsonb_array_length(blockers)=0 then 'PASS' else 'BLOCKED' end,'readiness_state',case when jsonb_array_length(blockers)=0 then 'LIVE_READY' else 'NOT_READY' end,'live_ready',jsonb_array_length(blockers)=0,'test_only',false,'blockers',blockers,'raw_secret_returned',false);
end $$;

create or replace function public.world8_provider_broker_snapshot_v1()
returns jsonb language sql security definer set search_path=public as $$
select jsonb_build_object('schema','WORLD8_PROVIDER_BROKER_SNAPSHOT/1.0','credential_mode','OPAQUE_REF_ONLY','raw_secret_storage_in_dcp',false,'bindings',coalesce((select jsonb_agg(jsonb_build_object('binding_id',binding_id,'adapter_id',adapter_id,'provider',provider,'credential_ref',credential_ref,'binding_kind',binding_kind,'status',status,'verification_state',verification_state,'verified_by_transport_id',verified_by_transport_id) order by binding_id) from public.world8_provider_credential_bindings),'[]'::jsonb),'transports',coalesce((select jsonb_agg(jsonb_build_object('transport_id',transport_id,'adapter_id',adapter_id,'provider',provider,'transport_kind',transport_kind,'endpoint_ref',endpoint_ref,'status',status,'verification_state',verification_state,'max_parallel',max_parallel) order by transport_id) from public.world8_provider_worker_transports),'[]'::jsonb),'real_live_ready_count',(select count(*) from public.world8_provider_execution_adapters a where a.adapter_kind='REAL_EXTERNAL' and (public.world8_provider_execution_readiness_v2(a.adapter_id,null)->>'live_ready')::boolean),'generated_at',clock_timestamp());
$$;

insert into public.world8_provider_worker_transports(transport_id,adapter_id,provider,transport_kind,endpoint_ref,status,verification_state,capabilities,max_parallel,config,metadata,verified_at,created_by)
select 'transport-world8-mock-internal-v1','adapter-world8-mock-internal-v1','MOCK','MOCK_INTERNAL',null,'ACTIVE','VERIFIED',jsonb_build_array('LIFECYCLE_TEST'),100,jsonb_build_object('network_calls',false),jsonb_build_object('test_only',true,'live_ready',false),clock_timestamp(),'chatgpt-mason'
where exists(select 1 from public.world8_provider_execution_adapters where adapter_id='adapter-world8-mock-internal-v1') on conflict(transport_id) do nothing;

insert into public.world8_provider_credential_bindings(binding_id,adapter_id,provider,credential_ref,binding_kind,status,verification_state,metadata,created_by)
select 'binding-openai-envref-v01','adapter-openai-external-v01','OpenAI','envref:OPENAI_API_KEY','ENVREF','ACTIVE','UNVERIFIED',jsonb_build_object('source','provider-execution-adapter-v0.1','verification_required','PROVIDER_PROBE','raw_secret_stored',false),'chatgpt-mason'
where exists(select 1 from public.world8_provider_execution_adapters where adapter_id='adapter-openai-external-v01') on conflict(binding_id) do nothing;

insert into public.world8_provider_worker_transports(transport_id,adapter_id,provider,transport_kind,endpoint_ref,status,verification_state,capabilities,max_parallel,config,metadata,created_by)
select 'transport-netlify-world8-grok-proxy-v01','adapter-openai-external-v01','OpenAI','NETLIFY_EDGE','https://world8-grok-mcp-proxy.netlify.app','ACTIVE','UNVERIFIED',jsonb_build_array('CODE_ASSIST'),20,jsonb_build_object('env_required',true),jsonb_build_object('site_id','3e698349-9a2a-45e9-91e8-bc661ced51d3','network_attestation_required',true,'raw_secret_stored',false),'chatgpt-mason'
where exists(select 1 from public.world8_provider_execution_adapters where adapter_id='adapter-openai-external-v01') on conflict(transport_id) do nothing;

revoke all on public.world8_provider_credential_bindings,public.world8_provider_credential_verification_receipts,public.world8_provider_worker_transports,public.world8_provider_worker_verification_receipts,public.world8_provider_worker_challenges,public.world8_provider_credential_probe_challenges from public,anon,authenticated;
grant select on public.world8_provider_credential_bindings,public.world8_provider_credential_verification_receipts,public.world8_provider_worker_transports,public.world8_provider_worker_verification_receipts,public.world8_provider_worker_challenges,public.world8_provider_credential_probe_challenges to service_role;
revoke all on function public.world8_provider_credential_binding_register_v1(text,text,text,jsonb,text),public.world8_provider_credential_presence_v1(text),public.world8_provider_worker_transport_register_v1(text,text,text,text,jsonb,integer,jsonb,jsonb,text),public.world8_provider_worker_challenge_issue_v1(text,integer,jsonb),public.world8_provider_worker_challenge_attest_v1(text,text,jsonb,jsonb),public.world8_provider_credential_probe_issue_v1(text,text,integer,jsonb),public.world8_provider_credential_probe_attest_v1(text,text,text,jsonb,jsonb),public.world8_provider_execution_readiness_v2(text,text),public.world8_provider_broker_snapshot_v1() from public,anon,authenticated;
grant execute on function public.world8_provider_credential_binding_register_v1(text,text,text,jsonb,text),public.world8_provider_credential_presence_v1(text),public.world8_provider_worker_transport_register_v1(text,text,text,text,jsonb,integer,jsonb,jsonb,text),public.world8_provider_worker_challenge_issue_v1(text,integer,jsonb),public.world8_provider_worker_challenge_attest_v1(text,text,jsonb,jsonb),public.world8_provider_credential_probe_issue_v1(text,text,integer,jsonb),public.world8_provider_credential_probe_attest_v1(text,text,text,jsonb,jsonb),public.world8_provider_execution_readiness_v2(text,text),public.world8_provider_broker_snapshot_v1() to service_role;
