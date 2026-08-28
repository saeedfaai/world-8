-- Operational Guardian v0.1.3 DB kernel regression
-- PRECONDITION: supabase/drafts/20260828_world8_operational_guardian_kernel_v013.sql
-- has been applied ONLY to an authorized disposable/dev database.
-- This test rolls back all fixture data.

begin;

insert into public.world8_operational_guardian_leaders(
  world_id,society_id,guardian_shard_key,current_epoch,lease_holder,lease_expires_at,fencing_token,policy_version
) values
  ('world-001','society-test-a','primary',7,'guardian-test-a',clock_timestamp()+interval '10 minutes',44,'guardian-policy-v0.1.3'),
  ('world-001','society-test-b','primary',3,'guardian-test-b',clock_timestamp()+interval '10 minutes',11,'guardian-policy-v0.1.3');

-- DB-K1: valid fenced append creates v1.
do $$
declare r jsonb;
begin
  r:=public.world8_operational_guardian_append_event_v1(
    'world-001','society-test-a','project-test','primary','guardian-test-a',7,44,'guardian-policy-v0.1.3',
    'WORK_CONTROL','assignment-test-1',0,'WORK_PLANNED','corr-1',null,'gap-test-1',
    jsonb_build_object('state','PLANNED'),'idem-1',clock_timestamp()
  );
  if r->>'status'<>'COMMITTED' or (r->>'aggregate_version')::bigint<>1 then
    raise exception 'DB_K1_VALID_APPEND_FAILED';
  end if;
end $$;

-- DB-K2: exact replay is idempotent and does not create v2.
do $$
declare r jsonb; c bigint;
begin
  r:=public.world8_operational_guardian_append_event_v1(
    'world-001','society-test-a','project-test','primary','guardian-test-a',7,44,'guardian-policy-v0.1.3',
    'WORK_CONTROL','assignment-test-1',0,'WORK_PLANNED','corr-1',null,'gap-test-1',
    jsonb_build_object('state','PLANNED'),'idem-1',clock_timestamp()
  );
  if r->>'status'<>'IDEMPOTENT_REPLAY' then raise exception 'DB_K2_REPLAY_NOT_IDEMPOTENT'; end if;
  select count(*) into c from public.world8_guardian_control_events
  where aggregate_type='WORK_CONTROL' and aggregate_id='assignment-test-1';
  if c<>1 then raise exception 'DB_K2_REPLAY_CREATED_DUPLICATE'; end if;
end $$;

-- DB-K3: same idempotency key with different payload must fail.
do $$
begin
  begin
    perform public.world8_operational_guardian_append_event_v1(
      'world-001','society-test-a','project-test','primary','guardian-test-a',7,44,'guardian-policy-v0.1.3',
      'WORK_CONTROL','assignment-test-1',1,'WORK_PLANNED','corr-1',null,'gap-test-1',
      jsonb_build_object('state','ACTIVE'),'idem-1',clock_timestamp()
    );
    raise exception 'DB_K3_EXPECTED_COLLISION_NOT_RAISED';
  exception when others then
    if sqlerrm not like '%CONTROL_EVENT_IDEMPOTENCY_COLLISION%' then raise; end if;
  end;
end $$;

-- DB-K4: stale epoch fails closed.
do $$
begin
  begin
    perform public.world8_operational_guardian_append_event_v1(
      'world-001','society-test-a','project-test','primary','guardian-test-a',6,44,'guardian-policy-v0.1.3',
      'WORK_CONTROL','assignment-test-2',0,'WORK_PLANNED','corr-2',null,'gap-test-2',
      jsonb_build_object('state','PLANNED'),'idem-2',clock_timestamp()
    );
    raise exception 'DB_K4_EXPECTED_STALE_EPOCH_NOT_RAISED';
  exception when others then
    if sqlerrm not like '%STALE_GUARDIAN_EPOCH%' then raise; end if;
  end;
end $$;

-- DB-K5: Society A leader cannot write Society B aggregate.
do $$
begin
  begin
    perform public.world8_operational_guardian_append_event_v1(
      'world-001','society-test-b','project-test','primary','guardian-test-a',7,44,'guardian-policy-v0.1.3',
      'WORK_CONTROL','assignment-test-3',0,'WORK_PLANNED','corr-3',null,'gap-test-3',
      jsonb_build_object('state','PLANNED'),'idem-3',clock_timestamp()
    );
    raise exception 'DB_K5_EXPECTED_SCOPE_REJECTION_NOT_RAISED';
  exception when others then
    if sqlerrm not like '%GUARDIAN_LEASE_HOLDER_MISMATCH%' and sqlerrm not like '%STALE_GUARDIAN_EPOCH%' then raise; end if;
  end;
end $$;

-- DB-K6: aggregate CAS conflict must fail.
do $$
begin
  begin
    perform public.world8_operational_guardian_append_event_v1(
      'world-001','society-test-a','project-test','primary','guardian-test-a',7,44,'guardian-policy-v0.1.3',
      'WORK_CONTROL','assignment-test-1',0,'WORK_ASSIGNED','corr-4',null,'gap-test-1',
      jsonb_build_object('state','ASSIGNED'),'idem-4',clock_timestamp()
    );
    raise exception 'DB_K6_EXPECTED_CAS_CONFLICT_NOT_RAISED';
  exception when others then
    if sqlerrm not like '%AGGREGATE_CAS_CONFLICT%' then raise; end if;
  end;
end $$;

-- DB-K7: append-only event mutation must fail.
do $$
begin
  begin
    update public.world8_guardian_control_events
    set event_type='TAMPERED'
    where aggregate_type='WORK_CONTROL' and aggregate_id='assignment-test-1';
    raise exception 'DB_K7_EXPECTED_APPEND_ONLY_REJECTION_NOT_RAISED';
  exception when others then
    if sqlerrm not like '%WORLD8_OPERATIONAL_GUARDIAN_APPEND_ONLY%' then raise; end if;
  end;
end $$;

-- DB-K8: two Societies may legitimately have the same epoch value; no global comparison.
update public.world8_operational_guardian_leaders
set current_epoch=7
where society_id='society-test-b';

if exists (
  select 1 from public.world8_operational_guardian_leaders
  where society_id in ('society-test-a','society-test-b')
  group by current_epoch having count(*)=2
) then
  -- expected: duplicate epoch values across distinct Society leader identities are valid.
  null;
end if;

rollback;
