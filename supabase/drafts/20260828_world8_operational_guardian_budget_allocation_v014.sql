-- World 8 Operational Guardian Budget Allocation v0.1.4 — EXECUTABLE DRAFT
-- Status: CODE_DRAFTED / NOT_APPLIED / NOT_EVIDENCED / NOT_DEPLOYED
-- Requires: 20260828_world8_operational_guardian_kernel_v013.sql
-- DCR: architecture/proposals/DCR-0004-operational-guardian-envelope-allocation.md

create table if not exists public.world8_guardian_budget_envelopes (
  envelope_id text primary key,
  parent_envelope_id text null references public.world8_guardian_budget_envelopes(envelope_id) on delete restrict,
  world_id text not null default 'world-001',
  society_id text not null,
  scope_kind text not null check (scope_kind in ('SOCIETY','PROJECT','POOL')),
  scope_ref text not null check (length(trim(scope_ref))>0),
  project_id text null,
  pool_id text null references public.world8_mason_pools(pool_id),
  dimension_class text not null check (dimension_class in ('SPEND','CAPACITY','DEADLINE')),
  dimension_key text not null,
  unit text not null,
  ceiling numeric(30,6) not null check (ceiling>=0),
  settled numeric(30,6) not null default 0 check (settled>=0),
  reserved numeric(30,6) not null default 0 check (reserved>=0),
  available numeric(30,6) not null default 0 check (available>=0),
  overhang numeric(30,6) not null default 0 check (overhang>=0),
  envelope_version bigint not null default 1 check (envelope_version>0),
  status text not null default 'ACTIVE' check (status in ('ACTIVE','OVERHANG_BLOCKED','SUSPENDED','RETIRED')),
  policy_version text not null,
  created_at timestamptz not null default clock_timestamp(),
  updated_at timestamptz not null default clock_timestamp(),
  unique(society_id,scope_kind,scope_ref,dimension_class,dimension_key),
  check (settled + reserved + available = ceiling + overhang)
);
create index if not exists world8_guardian_budget_envelopes_scope_idx
  on public.world8_guardian_budget_envelopes(society_id,scope_kind,scope_ref,status);

create table if not exists public.world8_guardian_envelope_allocations (
  allocation_id text primary key,
  parent_envelope_id text not null references public.world8_guardian_budget_envelopes(envelope_id) on delete restrict,
  child_envelope_id text not null references public.world8_guardian_budget_envelopes(envelope_id) on delete restrict,
  world_id text not null default 'world-001',
  society_id text not null,
  dimension_class text not null,
  dimension_key text not null,
  unit text not null,
  allocated_amount numeric(30,6) not null check (allocated_amount>0),
  reclaimed_amount numeric(30,6) not null default 0 check (reclaimed_amount>=0),
  finalized_spend_amount numeric(30,6) not null default 0 check (finalized_spend_amount>=0),
  remaining_encumbered numeric(30,6) not null check (remaining_encumbered>=0),
  state text not null check (state in ('ACTIVE','CLOSED','CANCELLED')),
  parent_envelope_version_at_allocate bigint not null check (parent_envelope_version_at_allocate>0),
  policy_version text not null,
  guardian_shard_key text not null default 'primary' check (guardian_shard_key='primary'),
  guardian_epoch bigint not null check (guardian_epoch>0),
  fencing_token bigint not null check (fencing_token>0),
  idempotency_key text not null,
  created_at timestamptz not null default clock_timestamp(),
  updated_at timestamptz not null default clock_timestamp(),
  unique(parent_envelope_id,child_envelope_id,dimension_class,dimension_key),
  unique(parent_envelope_id,idempotency_key),
  check (allocated_amount = reclaimed_amount + finalized_spend_amount + remaining_encumbered),
  check (state<>'CLOSED' or remaining_encumbered=0)
);

create or replace function public.world8_operational_guardian_budget_allocate_child_v1(
  p_allocation_id text,
  p_parent_envelope_id text,
  p_child_envelope_id text,
  p_amount numeric,
  p_expected_parent_version bigint,
  p_expected_child_version bigint,
  p_holder_ref text,
  p_guardian_epoch bigint,
  p_fencing_token bigint,
  p_policy_version text,
  p_idempotency_key text,
  p_correlation_id text,
  p_issued_at timestamptz
) returns jsonb
language plpgsql security definer set search_path=public as $$
declare
  v_parent public.world8_guardian_budget_envelopes%rowtype;
  v_child public.world8_guardian_budget_envelopes%rowtype;
  v_existing public.world8_guardian_envelope_allocations%rowtype;
  v_event jsonb;
begin
  if p_amount<=0 then raise exception 'ALLOCATION_AMOUNT_MUST_BE_POSITIVE'; end if;
  if coalesce(trim(p_idempotency_key),'')='' then raise exception 'ALLOCATION_IDEMPOTENCY_REQUIRED'; end if;

  select * into v_existing from public.world8_guardian_envelope_allocations
  where parent_envelope_id=p_parent_envelope_id and idempotency_key=p_idempotency_key;
  if found then
    if v_existing.child_envelope_id<>p_child_envelope_id or v_existing.allocated_amount<>p_amount then
      raise exception 'ALLOCATION_IDEMPOTENCY_COLLISION';
    end if;
    return jsonb_build_object('status','IDEMPOTENT_REPLAY','allocation_id',v_existing.allocation_id,'remaining_encumbered',v_existing.remaining_encumbered);
  end if;

  -- Deterministic lock order prevents parent/child lock inversion.
  perform 1 from public.world8_guardian_budget_envelopes
  where envelope_id in (p_parent_envelope_id,p_child_envelope_id)
  order by envelope_id for update;

  select * into v_parent from public.world8_guardian_budget_envelopes where envelope_id=p_parent_envelope_id;
  select * into v_child from public.world8_guardian_budget_envelopes where envelope_id=p_child_envelope_id;
  if v_parent.envelope_id is null or v_child.envelope_id is null then raise exception 'PARENT_CHILD_ENVELOPE_REQUIRED'; end if;
  if v_child.parent_envelope_id is distinct from v_parent.envelope_id then raise exception 'CHILD_PARENT_BINDING_MISMATCH'; end if;
  if v_parent.world_id<>v_child.world_id or v_parent.society_id<>v_child.society_id then raise exception 'CROSS_SOCIETY_ENVELOPE_ALLOCATION_FORBIDDEN'; end if;
  if (v_parent.dimension_class,v_parent.dimension_key,v_parent.unit) is distinct from (v_child.dimension_class,v_child.dimension_key,v_child.unit) then raise exception 'ENVELOPE_DIMENSION_OR_UNIT_MISMATCH'; end if;
  if v_parent.policy_version<>p_policy_version or v_child.policy_version<>p_policy_version then raise exception 'GUARDIAN_POLICY_VERSION_MISMATCH'; end if;
  if v_parent.envelope_version<>p_expected_parent_version or v_child.envelope_version<>p_expected_child_version then raise exception 'ENVELOPE_CAS_CONFLICT'; end if;
  if v_parent.status<>'ACTIVE' or v_parent.overhang>0 then raise exception 'PARENT_ENVELOPE_NOT_ALLOCATABLE'; end if;
  if v_parent.available<p_amount then raise exception 'PARENT_ENVELOPE_AVAILABLE_EXCEEDED'; end if;

  perform public.world8_operational_guardian_require_leader_v1(
    v_parent.world_id,v_parent.society_id,'primary',p_holder_ref,p_guardian_epoch,p_fencing_token,p_policy_version
  );

  update public.world8_guardian_budget_envelopes set
    reserved=reserved+p_amount,
    available=available-p_amount,
    envelope_version=envelope_version+1,
    updated_at=clock_timestamp()
  where envelope_id=p_parent_envelope_id;

  update public.world8_guardian_budget_envelopes set
    ceiling=ceiling+p_amount,
    available=available+p_amount,
    envelope_version=envelope_version+1,
    updated_at=clock_timestamp()
  where envelope_id=p_child_envelope_id;

  insert into public.world8_guardian_envelope_allocations(
    allocation_id,parent_envelope_id,child_envelope_id,world_id,society_id,dimension_class,dimension_key,unit,
    allocated_amount,reclaimed_amount,finalized_spend_amount,remaining_encumbered,state,parent_envelope_version_at_allocate,
    policy_version,guardian_epoch,fencing_token,idempotency_key
  ) values(
    p_allocation_id,p_parent_envelope_id,p_child_envelope_id,v_parent.world_id,v_parent.society_id,v_parent.dimension_class,v_parent.dimension_key,v_parent.unit,
    p_amount,0,0,p_amount,'ACTIVE',v_parent.envelope_version,p_policy_version,p_guardian_epoch,p_fencing_token,p_idempotency_key
  );

  v_event:=public.world8_operational_guardian_append_event_v1(
    v_parent.world_id,v_parent.society_id,v_child.project_id,'primary',p_holder_ref,p_guardian_epoch,p_fencing_token,p_policy_version,
    'ENVELOPE_ALLOCATION',p_allocation_id,0,'ALLOCATION_CREATED',p_correlation_id,null,null,
    jsonb_build_object('allocation_id',p_allocation_id,'parent_envelope_id',p_parent_envelope_id,'child_envelope_id',p_child_envelope_id,'allocated_amount',p_amount,'remaining_encumbered',p_amount),
    p_idempotency_key,p_issued_at
  );

  return jsonb_build_object('status','ALLOCATED','allocation_id',p_allocation_id,'parent_version',p_expected_parent_version+1,'child_version',p_expected_child_version+1,'ledger',v_event);
end $$;

create or replace function public.world8_operational_guardian_budget_reconcile_allocation_v1(
  p_allocation_id text,
  p_expected_allocation_version bigint,
  p_expected_parent_version bigint,
  p_expected_child_version bigint,
  p_reclaim_unused numeric,
  p_finalize_spend numeric,
  p_holder_ref text,
  p_guardian_epoch bigint,
  p_fencing_token bigint,
  p_policy_version text,
  p_idempotency_key text,
  p_correlation_id text,
  p_issued_at timestamptz
) returns jsonb
language plpgsql security definer set search_path=public as $$
declare
  v_a public.world8_guardian_envelope_allocations%rowtype;
  v_parent public.world8_guardian_budget_envelopes%rowtype;
  v_child public.world8_guardian_budget_envelopes%rowtype;
  v_delta numeric;
  v_overhang_reduction numeric;
  v_event jsonb;
  v_new_remaining numeric;
begin
  if p_reclaim_unused<0 or p_finalize_spend<0 then raise exception 'NEGATIVE_ALLOCATION_RECONCILIATION'; end if;
  v_delta:=p_reclaim_unused+p_finalize_spend;
  if v_delta<=0 then raise exception 'ALLOCATION_RECONCILIATION_DELTA_REQUIRED'; end if;

  select * into v_a from public.world8_guardian_envelope_allocations where allocation_id=p_allocation_id for update;
  if not found or v_a.state<>'ACTIVE' then raise exception 'ACTIVE_ALLOCATION_REQUIRED'; end if;
  if v_a.policy_version<>p_policy_version then raise exception 'GUARDIAN_POLICY_VERSION_MISMATCH'; end if;
  if v_delta>v_a.remaining_encumbered then raise exception 'ALLOCATION_RECONCILIATION_EXCEEDS_REMAINING'; end if;

  perform 1 from public.world8_guardian_budget_envelopes
  where envelope_id in (v_a.parent_envelope_id,v_a.child_envelope_id)
  order by envelope_id for update;
  select * into v_parent from public.world8_guardian_budget_envelopes where envelope_id=v_a.parent_envelope_id;
  select * into v_child from public.world8_guardian_budget_envelopes where envelope_id=v_a.child_envelope_id;

  if v_parent.envelope_version<>p_expected_parent_version or v_child.envelope_version<>p_expected_child_version then raise exception 'ENVELOPE_CAS_CONFLICT'; end if;
  if p_reclaim_unused>v_child.available then raise exception 'CHILD_UNUSED_AVAILABLE_EXCEEDED'; end if;
  if v_parent.reserved<v_delta then raise exception 'PARENT_RESERVED_UNDERFLOW'; end if;

  perform public.world8_operational_guardian_require_leader_v1(
    v_a.world_id,v_a.society_id,'primary',p_holder_ref,p_guardian_epoch,p_fencing_token,p_policy_version
  );

  v_overhang_reduction:=least(p_reclaim_unused,v_parent.overhang);
  update public.world8_guardian_budget_envelopes set
    settled=settled+p_finalize_spend,
    reserved=reserved-v_delta,
    overhang=overhang-v_overhang_reduction,
    available=available+(p_reclaim_unused-v_overhang_reduction),
    status=case when overhang-v_overhang_reduction>0 then 'OVERHANG_BLOCKED' else 'ACTIVE' end,
    envelope_version=envelope_version+1,
    updated_at=clock_timestamp()
  where envelope_id=v_parent.envelope_id;

  update public.world8_guardian_budget_envelopes set
    ceiling=ceiling-p_reclaim_unused,
    available=available-p_reclaim_unused,
    envelope_version=envelope_version+1,
    updated_at=clock_timestamp()
  where envelope_id=v_child.envelope_id;

  v_new_remaining:=v_a.remaining_encumbered-v_delta;
  update public.world8_guardian_envelope_allocations set
    reclaimed_amount=reclaimed_amount+p_reclaim_unused,
    finalized_spend_amount=finalized_spend_amount+p_finalize_spend,
    remaining_encumbered=v_new_remaining,
    state=case when v_new_remaining=0 then 'CLOSED' else 'ACTIVE' end,
    guardian_epoch=p_guardian_epoch,
    fencing_token=p_fencing_token,
    updated_at=clock_timestamp()
  where allocation_id=p_allocation_id;

  v_event:=public.world8_operational_guardian_append_event_v1(
    v_a.world_id,v_a.society_id,v_child.project_id,'primary',p_holder_ref,p_guardian_epoch,p_fencing_token,p_policy_version,
    'ENVELOPE_ALLOCATION',p_allocation_id,p_expected_allocation_version,'ALLOCATION_RECONCILED',p_correlation_id,null,null,
    jsonb_build_object('allocation_id',p_allocation_id,'reclaim_unused',p_reclaim_unused,'finalize_spend',p_finalize_spend,'remaining_encumbered',v_new_remaining),
    p_idempotency_key,p_issued_at
  );

  return jsonb_build_object('status','RECONCILED','allocation_id',p_allocation_id,'remaining_encumbered',v_new_remaining,'ledger',v_event);
end $$;

revoke all on public.world8_guardian_budget_envelopes from anon, authenticated;
revoke all on public.world8_guardian_envelope_allocations from anon, authenticated;
revoke all on function public.world8_operational_guardian_budget_allocate_child_v1(text,text,text,numeric,bigint,bigint,text,bigint,bigint,text,text,text,timestamptz) from public, anon, authenticated;
revoke all on function public.world8_operational_guardian_budget_reconcile_allocation_v1(text,bigint,bigint,bigint,numeric,numeric,text,bigint,bigint,text,text,text,timestamptz) from public, anon, authenticated;
grant select on public.world8_guardian_budget_envelopes, public.world8_guardian_envelope_allocations to world8_operational_guardian_svc;
grant execute on function public.world8_operational_guardian_budget_allocate_child_v1(text,text,text,numeric,bigint,bigint,text,bigint,bigint,text,text,text,timestamptz) to world8_operational_guardian_svc;
grant execute on function public.world8_operational_guardian_budget_reconcile_allocation_v1(text,bigint,bigint,bigint,numeric,numeric,text,bigint,bigint,text,text,text,timestamptz) to world8_operational_guardian_svc;
