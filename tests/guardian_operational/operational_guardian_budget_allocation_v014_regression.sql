-- Operational Guardian v0.1.4 hierarchical envelope allocation regression
-- PRECONDITION: kernel v0.1.3 + budget allocation v0.1.4 drafts applied to disposable/dev DB only.
-- All fixtures are rolled back.

begin;

insert into public.world8_operational_guardian_leaders(
  world_id,society_id,guardian_shard_key,current_epoch,lease_holder,lease_expires_at,fencing_token,policy_version
) values ('world-001','society-budget-test','primary',5,'guardian-budget-test',clock_timestamp()+interval '10 minutes',21,'guardian-policy-v0.1.4');

insert into public.world8_guardian_budget_envelopes(
  envelope_id,parent_envelope_id,world_id,society_id,scope_kind,scope_ref,dimension_class,dimension_key,unit,
  ceiling,settled,reserved,available,overhang,envelope_version,status,policy_version
) values
  ('env-parent',null,'world-001','society-budget-test','SOCIETY','society-budget-test','SPEND','tokens','token',1000,0,0,1000,0,1,'ACTIVE','guardian-policy-v0.1.4'),
  ('env-child','env-parent','world-001','society-budget-test','PROJECT','project-budget-test','SPEND','tokens','token',0,0,0,0,0,1,'ACTIVE','guardian-policy-v0.1.4');

-- BA-K1 allocate 300: parent A->R, child C/A grows.
do $$
declare r jsonb;
begin
  r:=public.world8_operational_guardian_budget_allocate_child_v1(
    'alloc-1','env-parent','env-child',300,1,1,'guardian-budget-test',5,21,'guardian-policy-v0.1.4','alloc-idem-1','corr-ba-1',clock_timestamp()
  );
  if r->>'status'<>'ALLOCATED' then raise exception 'BA_K1_ALLOCATION_FAILED'; end if;
  if not exists(select 1 from public.world8_guardian_budget_envelopes where envelope_id='env-parent' and reserved=300 and available=700 and envelope_version=2) then raise exception 'BA_K1_PARENT_ACCOUNTING_FAILED'; end if;
  if not exists(select 1 from public.world8_guardian_budget_envelopes where envelope_id='env-child' and ceiling=300 and available=300 and envelope_version=2) then raise exception 'BA_K1_CHILD_ACCOUNTING_FAILED'; end if;
end $$;

-- BA-K2 exact replay must not double encumber.
do $$
declare r jsonb;
begin
  r:=public.world8_operational_guardian_budget_allocate_child_v1(
    'alloc-1','env-parent','env-child',300,1,1,'guardian-budget-test',5,21,'guardian-policy-v0.1.4','alloc-idem-1','corr-ba-1',clock_timestamp()
  );
  if r->>'status'<>'IDEMPOTENT_REPLAY' then raise exception 'BA_K2_NOT_IDEMPOTENT'; end if;
  if not exists(select 1 from public.world8_guardian_budget_envelopes where envelope_id='env-parent' and reserved=300 and available=700) then raise exception 'BA_K2_DOUBLE_ENCUMBRANCE'; end if;
end $$;

-- Child-local settlement is allowed without ancestor mutation. Simulate 100 spent locally.
update public.world8_guardian_budget_envelopes
set settled=100, available=200, envelope_version=3
where envelope_id='env-child';

-- BA-K3 explicit finalization propagates child spend parent R->S only at reconciliation.
do $$
declare r jsonb;
begin
  r:=public.world8_operational_guardian_budget_reconcile_allocation_v1(
    'alloc-1',1,2,3,0,100,'guardian-budget-test',5,21,'guardian-policy-v0.1.4','reconcile-idem-1','corr-ba-2',clock_timestamp()
  );
  if r->>'status'<>'RECONCILED' then raise exception 'BA_K3_RECONCILE_FAILED'; end if;
  if not exists(select 1 from public.world8_guardian_budget_envelopes where envelope_id='env-parent' and settled=100 and reserved=200 and available=700 and envelope_version=3) then raise exception 'BA_K3_PARENT_R_TO_S_FAILED'; end if;
end $$;

-- BA-K4 reclaim remaining 200 unused and close allocation.
do $$
declare r jsonb;
begin
  r:=public.world8_operational_guardian_budget_reconcile_allocation_v1(
    'alloc-1',2,3,4,200,0,'guardian-budget-test',5,21,'guardian-policy-v0.1.4','reconcile-idem-2','corr-ba-3',clock_timestamp()
  );
  if not exists(select 1 from public.world8_guardian_envelope_allocations where allocation_id='alloc-1' and state='CLOSED' and reclaimed_amount=200 and finalized_spend_amount=100 and remaining_encumbered=0) then raise exception 'BA_K4_ALLOCATION_NOT_CLOSED'; end if;
  if not exists(select 1 from public.world8_guardian_budget_envelopes where envelope_id='env-parent' and settled=100 and reserved=0 and available=900 and envelope_version=4) then raise exception 'BA_K4_PARENT_RECLAIM_FAILED'; end if;
  if not exists(select 1 from public.world8_guardian_budget_envelopes where envelope_id='env-child' and ceiling=100 and settled=100 and available=0 and envelope_version=5) then raise exception 'BA_K4_CHILD_RECLAIM_FAILED'; end if;
end $$;

-- BA-K5 stale parent/child versions fail CAS on new allocation.
insert into public.world8_guardian_budget_envelopes(
  envelope_id,parent_envelope_id,world_id,society_id,scope_kind,scope_ref,dimension_class,dimension_key,unit,
  ceiling,settled,reserved,available,overhang,envelope_version,status,policy_version
) values ('env-child-2','env-parent','world-001','society-budget-test','PROJECT','project-budget-test-2','SPEND','tokens','token',0,0,0,0,0,1,'ACTIVE','guardian-policy-v0.1.4');

do $$
begin
  begin
    perform public.world8_operational_guardian_budget_allocate_child_v1(
      'alloc-2','env-parent','env-child-2',10,1,1,'guardian-budget-test',5,21,'guardian-policy-v0.1.4','alloc-idem-2','corr-ba-4',clock_timestamp()
    );
    raise exception 'BA_K5_EXPECTED_CAS_CONFLICT_NOT_RAISED';
  exception when others then
    if sqlerrm not like '%ENVELOPE_CAS_CONFLICT%' then raise; end if;
  end;
end $$;

-- BA-K6 cross-Society child allocation rejected.
insert into public.world8_guardian_budget_envelopes(
  envelope_id,parent_envelope_id,world_id,society_id,scope_kind,scope_ref,dimension_class,dimension_key,unit,
  ceiling,settled,reserved,available,overhang,envelope_version,status,policy_version
) values ('env-child-cross','env-parent','world-001','society-other','PROJECT','project-other','SPEND','tokens','token',0,0,0,0,0,1,'ACTIVE','guardian-policy-v0.1.4');

do $$
begin
  begin
    perform public.world8_operational_guardian_budget_allocate_child_v1(
      'alloc-cross','env-parent','env-child-cross',10,4,1,'guardian-budget-test',5,21,'guardian-policy-v0.1.4','alloc-idem-cross','corr-ba-5',clock_timestamp()
    );
    raise exception 'BA_K6_EXPECTED_CROSS_SOCIETY_REJECTION_NOT_RAISED';
  exception when others then
    if sqlerrm not like '%CROSS_SOCIETY_ENVELOPE_ALLOCATION_FORBIDDEN%' then raise; end if;
  end;
end $$;

rollback;
