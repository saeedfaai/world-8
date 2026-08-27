-- World 8 Provider Health Circuit v0.1
-- Health can hard-block a provider, but selection remains advisory and no automatic retry is enabled.

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

create or replace function public.world8_provider_health_receipts_append_only_v1()
returns trigger language plpgsql security definer set search_path=public as $$
begin raise exception 'PROVIDER_HEALTH_RECEIPTS_APPEND_ONLY'; end $$;

drop trigger if exists world8_provider_health_receipts_append_only_trg on public.world8_provider_health_receipts;
create trigger world8_provider_health_receipts_append_only_trg
before update or delete on public.world8_provider_health_receipts
for each row execute function public.world8_provider_health_receipts_append_only_v1();

create or replace function public.world8_provider_health_record_v1(
  p_adapter_id text,
  p_health_state text,
  p_reason_code text,
  p_retryable boolean,
  p_evidence_refs jsonb default '[]'::jsonb,
  p_metadata jsonb default '{}'::jsonb,
  p_created_by text default 'guardian-health-projection'
) returns jsonb
language plpgsql security definer set search_path=public,extensions as $$
declare v_now timestamptz:=clock_timestamp(); v_hash text; v_receipt text;
begin
  if p_health_state not in ('HEALTHY','DEGRADED','ADMIN_BLOCKED','DISABLED','UNKNOWN') then raise exception 'INVALID_PROVIDER_HEALTH_STATE'; end if;
  if coalesce(btrim(p_reason_code),'')='' then raise exception 'PROVIDER_HEALTH_REASON_REQUIRED'; end if;
  if not exists(select 1 from public.world8_provider_execution_adapters where adapter_id=p_adapter_id and status='ACTIVE') then raise exception 'ACTIVE_PROVIDER_ADAPTER_REQUIRED'; end if;
  if jsonb_typeof(coalesce(p_evidence_refs,'[]'::jsonb))<>'array' or not public.world8_provider_execution_json_safe_v1(coalesce(p_evidence_refs,'[]'::jsonb)) or not public.world8_provider_execution_json_safe_v1(coalesce(p_metadata,'{}'::jsonb)) then raise exception 'PROVIDER_HEALTH_SECRET_OR_PRIVATE_REASONING_REJECTED'; end if;
  v_hash:=encode(extensions.digest(p_adapter_id||'|'||p_health_state||'|'||p_reason_code||'|'||p_retryable::text||'|'||coalesce(p_evidence_refs,'[]'::jsonb)::text||'|'||coalesce(p_metadata,'{}'::jsonb)::text||'|'||v_now::text,'sha256'),'hex');
  v_receipt:='provider-health-'||substr(v_hash,1,28);
  insert into public.world8_provider_health_receipts(receipt_id,adapter_id,health_state,reason_code,retryable,evidence_refs,metadata,created_by,created_at,content_hash)
  values(v_receipt,p_adapter_id,p_health_state,p_reason_code,p_retryable,coalesce(p_evidence_refs,'[]'::jsonb),coalesce(p_metadata,'{}'::jsonb),p_created_by,v_now,v_hash);
  insert into public.world8_provider_health_state(adapter_id,health_state,reason_code,retryable,latest_receipt_id,observed_at,updated_at)
  values(p_adapter_id,p_health_state,p_reason_code,p_retryable,v_receipt,v_now,v_now)
  on conflict(adapter_id) do update set health_state=excluded.health_state,reason_code=excluded.reason_code,retryable=excluded.retryable,latest_receipt_id=excluded.latest_receipt_id,observed_at=excluded.observed_at,updated_at=excluded.updated_at;
  return jsonb_build_object('schema','WORLD8_PROVIDER_HEALTH_RECEIPT/1.0','receipt_id',v_receipt,'adapter_id',p_adapter_id,'health_state',p_health_state,'reason_code',p_reason_code,'retryable',p_retryable,'observed_at',v_now);
end $$;

create or replace function public.world8_provider_health_snapshot_v1(p_adapter_id text)
returns jsonb
language plpgsql security definer set search_path=public as $$
declare s public.world8_provider_health_state%rowtype;
begin
  select * into s from public.world8_provider_health_state where adapter_id=p_adapter_id;
  if not found then
    return jsonb_build_object('schema','WORLD8_PROVIDER_HEALTH/1.0','adapter_id',p_adapter_id,'health_state','UNKNOWN','reason_code','NO_HEALTH_RECEIPT','retryable',false,'hard_blocked',false,'latest_receipt_id',null);
  end if;
  return jsonb_build_object('schema','WORLD8_PROVIDER_HEALTH/1.0','adapter_id',s.adapter_id,'health_state',s.health_state,'reason_code',s.reason_code,'retryable',s.retryable,'hard_blocked',s.health_state in ('ADMIN_BLOCKED','DISABLED'),'latest_receipt_id',s.latest_receipt_id,'observed_at',s.observed_at);
end $$;

create or replace function public.world8_provider_failover_snapshot_v1(p_policy_key text)
returns jsonb
language plpgsql security definer set search_path=public as $$
declare
  p public.world8_provider_failover_policies%rowtype;
  v_adapter text;
  t public.world8_provider_worker_transports%rowtype;
  r jsonb;
  h jsonb;
  arr jsonb:='[]'::jsonb;
  selected jsonb:=null;
  v_pos int:=0;
  v_ready boolean;
  v_hard boolean;
begin
  select * into p from public.world8_provider_failover_policies where policy_key=p_policy_key and status='FROZEN' order by policy_version desc limit 1;
  if not found then raise exception 'FROZEN_FAILOVER_POLICY_REQUIRED'; end if;
  for v_adapter in select jsonb_array_elements_text(p.ordered_adapter_ids) loop
    v_pos:=v_pos+1;
    select * into t from public.world8_provider_worker_transports where adapter_id=v_adapter and status='ACTIVE' order by (verification_state='VERIFIED') desc,created_at desc limit 1;
    h:=public.world8_provider_health_snapshot_v1(v_adapter);
    v_hard:=coalesce((h->>'hard_blocked')::boolean,false);
    if t.transport_id is null then
      r:=jsonb_build_object('adapter_id',v_adapter,'priority',v_pos,'gate_state','BLOCKED','live_ready',false,'blockers',jsonb_build_array('WORKER_TRANSPORT_NOT_FOUND'),'provider_health',h);
    else
      r:=public.world8_provider_execution_readiness_v2(v_adapter,t.transport_id) || jsonb_build_object('priority',v_pos,'provider_health',h);
      v_ready:=coalesce((r->>'live_ready')::boolean,false);
      if v_hard then
        r:=r||jsonb_build_object('gate_state','BLOCKED','live_ready',false,'blockers',coalesce(r->'blockers','[]'::jsonb)||jsonb_build_array('PROVIDER_HEALTH_HARD_BLOCKED'));
      end if;
    end if;
    arr:=arr||jsonb_build_array(r);
    if selected is null and coalesce((r->>'live_ready')::boolean,false) then selected:=r; end if;
  end loop;
  return jsonb_build_object('schema','WORLD8_PROVIDER_FAILOVER_SNAPSHOT/1.1','policy_id',p.policy_id,'policy_key',p.policy_key,'policy_version',p.policy_version,'capability',p.capability,'selection_mode',p.selection_mode,'automatic_retry',p.automatic_retry,'max_attempts',p.max_attempts,'candidates',arr,'selected',selected,'gate_state',case when selected is null then 'BLOCKED' else 'PASS' end,'selection_is_advisory_only',true,'provider_invoked',false);
end $$;

alter table public.world8_provider_health_receipts enable row level security;
alter table public.world8_provider_health_state enable row level security;
revoke all on public.world8_provider_health_receipts,public.world8_provider_health_state from public,anon,authenticated;
grant all on public.world8_provider_health_receipts,public.world8_provider_health_state to service_role;
revoke all on function public.world8_provider_health_record_v1(text,text,text,boolean,jsonb,jsonb,text),public.world8_provider_health_snapshot_v1(text),public.world8_provider_failover_snapshot_v1(text) from public,anon,authenticated;
grant execute on function public.world8_provider_health_record_v1(text,text,text,boolean,jsonb,jsonb,text),public.world8_provider_health_snapshot_v1(text),public.world8_provider_failover_snapshot_v1(text) to service_role;