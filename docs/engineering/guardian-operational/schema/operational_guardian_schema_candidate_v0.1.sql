-- World 8 Operational Guardian v0.1 — SCHEMA CANDIDATE ONLY
-- Status: NOT A MIGRATION / NOT APPLIED / NOT EVIDENCED
-- Contract: architecture/contracts/guardian-operational-v0.1.yaml
-- IMPORTANT:
--   1) world8_mason_assignments remains the assignment truth registry.
--   2) world8_dev_leases remains the governed developer write-authority lease system.
--   3) tables below extend orchestration/control; they do not create a second Actor/Work/Workspace/Authority truth store.
--   4) do not move this file into supabase/migrations until forbidden-transition tests and reuse review pass.

-- ============================================================
-- 1. Guardian leader / epoch projection
-- ============================================================

create table if not exists public.world8_operational_guardian_leader (
  guardian_key text primary key check (guardian_key = 'operational-guardian'),
  current_epoch bigint not null check (current_epoch >= 0),
  lease_holder text null,
  lease_expires_at timestamptz null,
  fencing_token bigint not null check (fencing_token >= 0),
  policy_version text not null,
  updated_at timestamptz not null default clock_timestamp()
);

-- ============================================================
-- 2. Partitioned append-only Operational Control Ledger
-- ============================================================

create table if not exists public.world8_guardian_control_events (
  event_id text primary key,
  world_id text not null default 'world-001',
  society_id text not null,
  project_id text null,
  aggregate_type text not null check (aggregate_type in (
    'WORK_CONTROL','BUDGET_ENVELOPE','BUDGET_RESERVATION','CAPACITY_LEASE',
    'QUARANTINE','DECOMPOSITION_PLAN','ADVISORY','GUARDIAN_LEADER'
  )),
  aggregate_id text not null,
  aggregate_version bigint not null check (aggregate_version > 0),
  event_type text not null,
  policy_version text not null,
  guardian_epoch bigint not null check (guardian_epoch >= 0),
  fencing_token bigint not null check (fencing_token >= 0),
  correlation_id text not null,
  causation_event_ref text null references public.world8_guardian_control_events(event_id),
  originating_gap_id text null,
  payload jsonb not null default '{}'::jsonb check (jsonb_typeof(payload)='object'),
  canonical_bytes_hash text not null,
  previous_event_hash text null,
  idempotency_key text not null,
  issued_at timestamptz not null,
  recorded_at timestamptz not null default clock_timestamp(),
  unique (aggregate_type, aggregate_id, aggregate_version),
  unique (aggregate_type, aggregate_id, idempotency_key)
);

create index if not exists world8_guardian_control_events_aggregate_idx
  on public.world8_guardian_control_events(aggregate_type,aggregate_id,aggregate_version);
create index if not exists world8_guardian_control_events_society_idx
  on public.world8_guardian_control_events(society_id,recorded_at desc);
create index if not exists world8_guardian_control_events_gap_idx
  on public.world8_guardian_control_events(originating_gap_id,recorded_at desc)
  where originating_gap_id is not null;
create index if not exists world8_guardian_control_events_causation_idx
  on public.world8_guardian_control_events(causation_event_ref)
  where causation_event_ref is not null;

create or replace function public.world8_guardian_control_events_append_only_v01()
returns trigger language plpgsql security definer set search_path=public as $$
begin
  raise exception 'WORLD8_OPERATIONAL_GUARDIAN_CONTROL_EVENTS_APPEND_ONLY';
end $$;

drop trigger if exists world8_guardian_control_events_append_only_trg on public.world8_guardian_control_events;
create trigger world8_guardian_control_events_append_only_trg
before update or delete on public.world8_guardian_control_events
for each row execute function public.world8_guardian_control_events_append_only_v01();

-- Projection/head per independent aggregate. Event stream remains source of truth.
create table if not exists public.world8_guardian_control_heads (
  aggregate_type text not null,
  aggregate_id text not null,
  society_id text not null,
  project_id text null,
  current_version bigint not null check (current_version >= 0),
  current_event_id text null references public.world8_guardian_control_events(event_id),
  current_event_hash text null,
  current_state jsonb not null default '{}'::jsonb check (jsonb_typeof(current_state)='object'),
  guardian_epoch bigint not null check (guardian_epoch >= 0),
  policy_version text not null,
  updated_at timestamptz not null default clock_timestamp(),
  primary key (aggregate_type,aggregate_id)
);

-- ============================================================
-- 3. Existing Mason Assignment extension; NOT a second assignment registry
-- ============================================================

create table if not exists public.world8_guardian_work_controls (
  assignment_id text primary key references public.world8_mason_assignments(assignment_id) on delete restrict,
  gap_id text not null,
  society_id text not null,
  project_id text not null,
  dispatch_mode text not null check (dispatch_mode in ('SINGLE','REDUNDANT_N','SHARDED')),
  assignment_kind text not null,
  attempt_no integer not null check (attempt_no > 0),
  state text not null check (state in (
    'PLANNED','ASSIGNED','ACTIVE','COMPLETED','FAILED','CANCELLED','EXPIRED','QUARANTINED'
  )),
  parent_assignment_id text null references public.world8_guardian_work_controls(assignment_id),
  decomposition_plan_id text null,
  policy_version text not null,
  guardian_epoch bigint not null check (guardian_epoch >= 0),
  fencing_token bigint not null check (fencing_token >= 0),
  repair_retry_budget integer not null default 0 check (repair_retry_budget >= 0),
  provider_switch_budget integer not null default 0 check (provider_switch_budget >= 0),
  timeout_budget_seconds bigint not null check (timeout_budget_seconds > 0),
  deadline_at timestamptz not null,
  created_at timestamptz not null default clock_timestamp(),
  updated_at timestamptz not null default clock_timestamp(),
  unique(gap_id,policy_version,assignment_kind,attempt_no),
  check (dispatch_mode <> 'SHARDED' or parent_assignment_id is not null or assignment_kind='SHARDED_PARENT')
);

create index if not exists world8_guardian_work_controls_gap_idx
  on public.world8_guardian_work_controls(gap_id,state);
create index if not exists world8_guardian_work_controls_scope_idx
  on public.world8_guardian_work_controls(society_id,project_id,state);

-- ============================================================
-- 4. Gap decomposition plan projection (Gap itself remains external/immutable)
-- ============================================================

create table if not exists public.world8_guardian_decomposition_plans (
  plan_id text primary key,
  parent_gap_id text not null,
  society_id text not null,
  project_id text not null,
  proposed_by text not null,
  proposer_kind text not null check (proposer_kind in ('MASON_PLANNER','DETERMINISTIC_PLANNER')),
  policy_version text not null,
  completion_contract text not null check (completion_contract in ('ALL','QUORUM_N','INDEPENDENT')),
  quorum_n integer null check (quorum_n is null or quorum_n > 0),
  dependency_dag jsonb not null check (jsonb_typeof(dependency_dag)='object'),
  work_orders jsonb not null check (jsonb_typeof(work_orders)='array'),
  resource_declarations jsonb not null default '[]'::jsonb check (jsonb_typeof(resource_declarations)='array'),
  policy_check_state text not null check (policy_check_state in ('PENDING','PASS','FAIL')),
  policy_violations jsonb not null default '[]'::jsonb check (jsonb_typeof(policy_violations)='array'),
  content_hash text not null,
  created_at timestamptz not null default clock_timestamp(),
  check ((completion_contract='QUORUM_N' and quorum_n is not null) or completion_contract<>'QUORUM_N')
);

-- ============================================================
-- 5. Pre-funded hierarchical Budget Envelopes, normalized per dimension
-- ============================================================

create table if not exists public.world8_guardian_budget_envelopes (
  envelope_id text primary key,
  parent_envelope_id text null references public.world8_guardian_budget_envelopes(envelope_id) on delete restrict,
  world_id text not null default 'world-001',
  society_id text not null,
  project_id text null,
  pool_id text null references public.world8_mason_pools(pool_id),
  dimension_class text not null check (dimension_class in ('SPEND','CAPACITY','DEADLINE')),
  dimension_key text not null,
  unit text not null,
  ceiling numeric(30,6) not null check (ceiling >= 0),
  settled numeric(30,6) not null default 0 check (settled >= 0),
  reserved numeric(30,6) not null default 0 check (reserved >= 0),
  available numeric(30,6) not null default 0 check (available >= 0),
  overhang numeric(30,6) not null default 0 check (overhang >= 0),
  envelope_version bigint not null default 1 check (envelope_version > 0),
  status text not null default 'ACTIVE' check (status in ('ACTIVE','OVERHANG_BLOCKED','SUSPENDED','RETIRED')),
  policy_version text not null,
  created_at timestamptz not null default clock_timestamp(),
  updated_at timestamptz not null default clock_timestamp(),
  unique(society_id,project_id,pool_id,dimension_class,dimension_key),
  check (settled + reserved + available = ceiling + overhang)
);

create index if not exists world8_guardian_budget_envelopes_scope_idx
  on public.world8_guardian_budget_envelopes(society_id,project_id,status);

-- ============================================================
-- 6. Budget Reservation projection
-- ============================================================

create table if not exists public.world8_guardian_budget_reservations (
  reservation_id text primary key,
  assignment_id text not null references public.world8_mason_assignments(assignment_id) on delete restrict,
  envelope_id text not null references public.world8_guardian_budget_envelopes(envelope_id) on delete restrict,
  dimension_class text not null check (dimension_class in ('SPEND','CAPACITY','DEADLINE')),
  dimension_key text not null,
  requested_amount numeric(30,6) not null check (requested_amount > 0),
  reserved_amount numeric(30,6) not null check (reserved_amount >= 0),
  consumed_amount numeric(30,6) not null default 0 check (consumed_amount >= 0),
  state text not null check (state in ('REQUESTED','RESERVED','ACTIVE','SETTLED','RELEASED','FAILED','CANCELLED','EXPIRED')),
  envelope_version_at_reserve bigint not null check (envelope_version_at_reserve > 0),
  guardian_epoch bigint not null check (guardian_epoch >= 0),
  fencing_token bigint not null check (fencing_token >= 0),
  extension_count integer not null default 0 check (extension_count >= 0),
  expires_at timestamptz not null,
  created_at timestamptz not null default clock_timestamp(),
  updated_at timestamptz not null default clock_timestamp(),
  check (consumed_amount <= reserved_amount)
);

create index if not exists world8_guardian_budget_reservation_assignment_idx
  on public.world8_guardian_budget_reservations(assignment_id,state);
create index if not exists world8_guardian_budget_reservation_envelope_idx
  on public.world8_guardian_budget_reservations(envelope_id,state,expires_at);

-- ============================================================
-- 7. Guardian capacity/semantic leases only; does NOT grant developer write authority
-- ============================================================

create table if not exists public.world8_guardian_capacity_leases (
  capacity_lease_id text primary key,
  assignment_id text not null references public.world8_mason_assignments(assignment_id) on delete restrict,
  society_id text not null,
  project_id text not null,
  resource_key text not null,
  resource_kind text not null check (resource_kind in (
    'MASON_SLOT','EVALUATOR_SLOT','INTEGRATOR_SLOT','PROVIDER_SLOT','SEMANTIC_RESOURCE','OTHER_CAPACITY'
  )),
  lock_mode text not null check (lock_mode in ('READ','WRITE','EXCLUSIVE')),
  global_order_key text not null,
  state text not null check (state in ('REQUESTED','GRANTED','ACTIVE','RELEASED','EXPIRED','FENCED','FAILED')),
  guardian_epoch bigint not null check (guardian_epoch >= 0),
  fencing_token bigint not null check (fencing_token >= 0),
  expires_at timestamptz not null,
  created_at timestamptz not null default clock_timestamp(),
  updated_at timestamptz not null default clock_timestamp()
);

create index if not exists world8_guardian_capacity_resource_idx
  on public.world8_guardian_capacity_leases(society_id,resource_key,state,expires_at);

-- Explicit semantic boundary: these rows MUST NOT be treated as public.world8_dev_leases.
comment on table public.world8_guardian_capacity_leases is
  'Operational capacity/semantic leases only. Never grants developer/canonical write authority; world8_dev_leases remains authoritative for governed developer writes.';

-- ============================================================
-- 8. Append-only Advisory receipts (optional / non-authoritative)
-- ============================================================

create table if not exists public.world8_guardian_advisory_receipts (
  advisory_id text primary key,
  society_id text not null,
  project_id text null,
  assignment_id text null references public.world8_mason_assignments(assignment_id) on delete restrict,
  advisor_provider text not null,
  advisor_model text not null,
  advisor_build text null,
  prompt_contract_version text not null,
  input_hash text not null,
  recommendation jsonb not null check (jsonb_typeof(recommendation)='object'),
  allowed_field text not null,
  bounded_value jsonb not null,
  policy_version text not null,
  content_hash text not null,
  created_at timestamptz not null default clock_timestamp()
);

create or replace function public.world8_guardian_advisory_append_only_v01()
returns trigger language plpgsql security definer set search_path=public as $$
begin raise exception 'WORLD8_OPERATIONAL_GUARDIAN_ADVISORY_APPEND_ONLY'; end $$;

drop trigger if exists world8_guardian_advisory_append_only_trg on public.world8_guardian_advisory_receipts;
create trigger world8_guardian_advisory_append_only_trg
before update or delete on public.world8_guardian_advisory_receipts
for each row execute function public.world8_guardian_advisory_append_only_v01();

-- ============================================================
-- 9. Soft quarantine decision projection
-- ============================================================

create table if not exists public.world8_guardian_quarantine_decisions (
  quarantine_id text primary key,
  subject_type text not null check (subject_type in ('MASON','PROVIDER','POOL','ASSIGNMENT')),
  subject_id text not null,
  society_id text not null,
  project_id text null,
  failure_class text not null,
  policy_version text not null,
  mode text not null check (mode in ('IMMEDIATE','DRAIN')),
  scope_selector text not null,
  computed_assignment_ids jsonb not null default '[]'::jsonb check (jsonb_typeof(computed_assignment_ids)='array'),
  computed_reservation_ids jsonb not null default '[]'::jsonb check (jsonb_typeof(computed_reservation_ids)='array'),
  evidence_refs jsonb not null default '[]'::jsonb check (jsonb_typeof(evidence_refs)='array'),
  guardian_epoch bigint not null check (guardian_epoch >= 0),
  state text not null check (state in ('ACTIVE','LIFTED','EXPIRED')),
  renewal_count integer not null default 0 check (renewal_count >= 0),
  expires_at timestamptz not null,
  created_at timestamptz not null default clock_timestamp(),
  updated_at timestamptz not null default clock_timestamp()
);

create index if not exists world8_guardian_quarantine_scope_idx
  on public.world8_guardian_quarantine_decisions(society_id,subject_type,subject_id,state,expires_at);

-- ============================================================
-- 10. Contract-level RLS/privilege stance (candidate; exact service roles TBD after live role inventory)
-- ============================================================

-- DO NOT grant INSERT/UPDATE/DELETE to anon/authenticated directly.
-- Exact GRANTs are intentionally deferred until the live role inventory is read through the governed runtime path.
-- Security-definer mutation RPCs must enforce:
--   - current guardian_epoch + fencing
--   - society scope
--   - policy_version
--   - per-aggregate CAS
--   - idempotency
--   - forbidden transitions
--   - authority separation

-- ============================================================
-- 11. Objects intentionally NOT created by this candidate
-- ============================================================

-- NO new Actor registry.
-- NO new Work registry.
-- NO new Workspace registry.
-- NO new Developer write Lease registry.
-- NO mutable GapSignal table/status.
-- NO SelectionDecision table in Operational store.
-- NO external-effect authorization table.
-- NO canonical Spine event table.
-- NO LLM-required Guardian decision table.

-- Next step before executable migration:
--   SQL negative-test specification + existing-role inventory + exact writer matrix.
