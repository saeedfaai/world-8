-- World 8 Operational Guardian v0.1 — SCHEMA CANDIDATE ONLY
-- STATUS: DRAFT / NOT APPLIED / NOT EVIDENCED / NOT DEPLOYED
-- DO NOT place this file in supabase/migrations or apply it until governed Work/Workspace/Admission/Lease is resolved.
-- Contract: architecture/contracts/guardian-operational-v0.1.yaml
-- State machines: architecture/contracts/operational-guardian-state-machines-v0.1.yaml
--
-- Reuse rules:
--   * no second Actor registry
--   * no second provider Execution registry
--   * no second Dev Work/Workspace/Authority/Admission/Lease truth
--   * existing world8_mason_assignments remains pool/capacity assignment truth
--   * Operational Guardian WorkAssignment is dispatch/control state and may reference existing pool assignment
--
-- IMPORTANT OPEN INTEGRATION:
-- No implemented GapSignal / ObservationContract table was found in the current repository scan.
-- Therefore gap_id is intentionally a typed text evidence reference with NO invented FK in this draft.

BEGIN;

-- ---------------------------------------------------------------------------
-- 1. Guardian leader lease / epoch
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.world8_guardian_leader_leases (
  world_id text NOT NULL DEFAULT 'world-001',
  society_id text NOT NULL,
  holder_instance_id text NOT NULL,
  guardian_epoch bigint NOT NULL CHECK (guardian_epoch > 0),
  fencing_token bigint NOT NULL CHECK (fencing_token > 0),
  lease_expires_at timestamptz NOT NULL,
  policy_version text NOT NULL,
  updated_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  PRIMARY KEY (world_id, society_id)
);

-- ---------------------------------------------------------------------------
-- 2. Partitioned Operational Control Ledger
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.world8_guardian_control_events (
  event_id text PRIMARY KEY,
  world_id text NOT NULL DEFAULT 'world-001',
  society_id text NOT NULL,
  project_id text NULL,
  aggregate_type text NOT NULL CHECK (aggregate_type IN (
    'WORK_ASSIGNMENT',
    'BUDGET_ENVELOPE',
    'BUDGET_RESERVATION',
    'RESOURCE_LEASE',
    'SOFT_QUARANTINE',
    'DECOMPOSITION_PLAN'
  )),
  aggregate_id text NOT NULL,
  aggregate_version bigint NOT NULL CHECK (aggregate_version > 0),
  event_type text NOT NULL,
  guardian_epoch bigint NOT NULL CHECK (guardian_epoch > 0),
  control_fencing_token bigint NOT NULL CHECK (control_fencing_token > 0),
  policy_version text NOT NULL,
  correlation_id text NULL,
  causation_event_ref text NULL REFERENCES public.world8_guardian_control_events(event_id),
  idempotency_key text NOT NULL,
  event_payload jsonb NOT NULL DEFAULT '{}'::jsonb CHECK (jsonb_typeof(event_payload) = 'object'),
  canonical_bytes_hash text NOT NULL CHECK (canonical_bytes_hash ~ '^[0-9a-f]{64}$'),
  issued_at timestamptz NOT NULL,
  recorded_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  UNIQUE (aggregate_type, aggregate_id, aggregate_version),
  UNIQUE (aggregate_type, aggregate_id, idempotency_key)
);

CREATE INDEX IF NOT EXISTS world8_guardian_control_events_scope_idx
  ON public.world8_guardian_control_events(society_id, project_id, recorded_at DESC);
CREATE INDEX IF NOT EXISTS world8_guardian_control_events_aggregate_idx
  ON public.world8_guardian_control_events(aggregate_type, aggregate_id, aggregate_version DESC);
CREATE INDEX IF NOT EXISTS world8_guardian_control_events_correlation_idx
  ON public.world8_guardian_control_events(correlation_id)
  WHERE correlation_id IS NOT NULL;

CREATE TABLE IF NOT EXISTS public.world8_guardian_control_aggregates (
  aggregate_type text NOT NULL,
  aggregate_id text NOT NULL,
  world_id text NOT NULL DEFAULT 'world-001',
  society_id text NOT NULL,
  project_id text NULL,
  current_version bigint NOT NULL CHECK (current_version >= 0),
  current_state text NOT NULL,
  state_payload jsonb NOT NULL DEFAULT '{}'::jsonb CHECK (jsonb_typeof(state_payload) = 'object'),
  last_event_id text NULL REFERENCES public.world8_guardian_control_events(event_id),
  updated_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  PRIMARY KEY (aggregate_type, aggregate_id)
);

-- Append-only event guard. Projection is mutable derived state; event history is not.
CREATE OR REPLACE FUNCTION public.world8_guardian_prevent_control_event_mutation_v01()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RAISE EXCEPTION 'WORLD8_GUARDIAN_CONTROL_EVENTS_APPEND_ONLY';
END;
$$;

DROP TRIGGER IF EXISTS world8_guardian_control_events_append_only_trg
  ON public.world8_guardian_control_events;
CREATE TRIGGER world8_guardian_control_events_append_only_trg
BEFORE UPDATE OR DELETE ON public.world8_guardian_control_events
FOR EACH ROW EXECUTE FUNCTION public.world8_guardian_prevent_control_event_mutation_v01();

-- ---------------------------------------------------------------------------
-- 3. Operational WorkAssignment projection
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.world8_guardian_work_assignments (
  assignment_id text PRIMARY KEY,
  world_id text NOT NULL DEFAULT 'world-001',
  society_id text NOT NULL,
  project_id text NULL,
  gap_id text NOT NULL,
  parent_assignment_id text NULL REFERENCES public.world8_guardian_work_assignments(assignment_id),
  dispatch_mode text NOT NULL CHECK (dispatch_mode IN ('SINGLE','REDUNDANT_N','SHARDED')),
  assignment_kind text NOT NULL,
  attempt_no integer NOT NULL CHECK (attempt_no >= 1),
  pool_assignment_id text NULL REFERENCES public.world8_mason_assignments(assignment_id),
  work_id text NULL REFERENCES public.world8_dev_work_items(work_id),
  actor_id text NULL REFERENCES public.world8_actor_registry(actor_id),
  execution_id text NULL REFERENCES public.world8_actor_executions(execution_id),
  workspace_id text NULL REFERENCES public.world8_dev_workspaces(workspace_id),
  state text NOT NULL CHECK (state IN ('PLANNED','ASSIGNED','ACTIVE','COMPLETED','FAILED','CANCELLED','EXPIRED','QUARANTINED')),
  policy_version text NOT NULL,
  guardian_epoch bigint NOT NULL CHECK (guardian_epoch > 0),
  control_fencing_token bigint NOT NULL CHECK (control_fencing_token > 0),
  repair_retry_budget integer NOT NULL DEFAULT 0 CHECK (repair_retry_budget >= 0),
  provider_switch_budget integer NOT NULL DEFAULT 0 CHECK (provider_switch_budget >= 0),
  timeout_budget_seconds integer NOT NULL CHECK (timeout_budget_seconds > 0),
  deadline_at timestamptz NOT NULL,
  resource_declarations jsonb NOT NULL DEFAULT '[]'::jsonb CHECK (jsonb_typeof(resource_declarations) = 'array'),
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb CHECK (jsonb_typeof(metadata) = 'object'),
  current_version bigint NOT NULL CHECK (current_version >= 1),
  created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  updated_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  UNIQUE (gap_id, policy_version, assignment_kind, attempt_no),
  CHECK (NOT (dispatch_mode = 'SHARDED' AND metadata->>'redundancy_n' IS NOT NULL))
);

CREATE INDEX IF NOT EXISTS world8_guardian_work_assignments_scope_state_idx
  ON public.world8_guardian_work_assignments(society_id, project_id, state, deadline_at);
CREATE INDEX IF NOT EXISTS world8_guardian_work_assignments_gap_idx
  ON public.world8_guardian_work_assignments(gap_id, state);

-- ---------------------------------------------------------------------------
-- 4. Hierarchical child envelopes / dimension accounting
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.world8_guardian_budget_envelopes (
  envelope_id text PRIMARY KEY,
  world_id text NOT NULL DEFAULT 'world-001',
  society_id text NOT NULL,
  project_id text NULL,
  parent_envelope_id text NULL REFERENCES public.world8_guardian_budget_envelopes(envelope_id),
  scope_kind text NOT NULL CHECK (scope_kind IN ('WORLD','SOCIETY','PROJECT','POOL')),
  scope_ref text NOT NULL,
  status text NOT NULL CHECK (status IN ('ACTIVE','OVERHANG_BLOCKED','SUSPENDED','RETIRED')),
  envelope_version bigint NOT NULL CHECK (envelope_version >= 1),
  policy_version text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  updated_at timestamptz NOT NULL DEFAULT clock_timestamp()
);

CREATE TABLE IF NOT EXISTS public.world8_guardian_budget_envelope_dimensions (
  envelope_id text NOT NULL REFERENCES public.world8_guardian_budget_envelopes(envelope_id),
  budget_class text NOT NULL CHECK (budget_class IN ('SPEND','CAPACITY','DEADLINE')),
  budget_field text NOT NULL,
  unit text NOT NULL,
  ceiling numeric NOT NULL CHECK (ceiling >= 0),
  settled numeric NOT NULL DEFAULT 0 CHECK (settled >= 0),
  reserved numeric NOT NULL DEFAULT 0 CHECK (reserved >= 0),
  available numeric NOT NULL DEFAULT 0 CHECK (available >= 0),
  overhang numeric NOT NULL DEFAULT 0 CHECK (overhang >= 0),
  dimension_version bigint NOT NULL CHECK (dimension_version >= 1),
  updated_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  PRIMARY KEY (envelope_id, budget_class, budget_field),
  CHECK (settled + reserved + available = ceiling + overhang)
);

CREATE TABLE IF NOT EXISTS public.world8_guardian_budget_reservations (
  reservation_id text PRIMARY KEY,
  assignment_id text NOT NULL REFERENCES public.world8_guardian_work_assignments(assignment_id),
  envelope_id text NOT NULL REFERENCES public.world8_guardian_budget_envelopes(envelope_id),
  envelope_version bigint NOT NULL CHECK (envelope_version >= 1),
  state text NOT NULL CHECK (state IN ('REQUESTED','RESERVED','ACTIVE','SETTLED','RELEASED','EXPIRED')),
  guardian_epoch bigint NOT NULL CHECK (guardian_epoch > 0),
  fencing_token bigint NOT NULL CHECK (fencing_token > 0),
  expires_at timestamptz NOT NULL,
  current_version bigint NOT NULL CHECK (current_version >= 1),
  created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  updated_at timestamptz NOT NULL DEFAULT clock_timestamp()
);

CREATE TABLE IF NOT EXISTS public.world8_guardian_budget_reservation_dimensions (
  reservation_id text NOT NULL REFERENCES public.world8_guardian_budget_reservations(reservation_id),
  budget_class text NOT NULL CHECK (budget_class IN ('SPEND','CAPACITY','DEADLINE')),
  budget_field text NOT NULL,
  unit text NOT NULL,
  reserved_amount numeric NOT NULL CHECK (reserved_amount >= 0),
  settled_amount numeric NOT NULL DEFAULT 0 CHECK (settled_amount >= 0),
  released_amount numeric NOT NULL DEFAULT 0 CHECK (released_amount >= 0),
  PRIMARY KEY (reservation_id, budget_class, budget_field),
  CHECK (settled_amount + released_amount <= reserved_amount)
);

-- ---------------------------------------------------------------------------
-- 5. Resource leases
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.world8_guardian_resource_leases (
  resource_lease_id text PRIMARY KEY,
  assignment_id text NOT NULL REFERENCES public.world8_guardian_work_assignments(assignment_id),
  society_id text NOT NULL,
  resource_key text NOT NULL,
  resource_kind text NOT NULL,
  lock_mode text NOT NULL CHECK (lock_mode IN ('READ','WRITE','EXCLUSIVE')),
  state text NOT NULL CHECK (state IN ('REQUESTED','GRANTED','ACTIVE','RELEASED','EXPIRED','FENCED','FAILED')),
  guardian_epoch bigint NOT NULL CHECK (guardian_epoch > 0),
  fencing_token bigint NOT NULL CHECK (fencing_token > 0),
  expires_at timestamptz NOT NULL,
  current_version bigint NOT NULL CHECK (current_version >= 1),
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb CHECK (jsonb_typeof(metadata) = 'object'),
  created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  updated_at timestamptz NOT NULL DEFAULT clock_timestamp()
);

CREATE INDEX IF NOT EXISTS world8_guardian_resource_leases_resource_idx
  ON public.world8_guardian_resource_leases(society_id, resource_key, state, expires_at);

-- ---------------------------------------------------------------------------
-- 6. Soft quarantine projection
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.world8_guardian_soft_quarantines (
  quarantine_id text PRIMARY KEY,
  world_id text NOT NULL DEFAULT 'world-001',
  society_id text NOT NULL,
  subject_type text NOT NULL CHECK (subject_type IN ('MASON','PROVIDER','POOL','ASSIGNMENT')),
  subject_id text NOT NULL,
  failure_class text NOT NULL,
  mode text NOT NULL CHECK (mode IN ('IMMEDIATE','DRAIN')),
  policy_version text NOT NULL,
  guardian_epoch bigint NOT NULL CHECK (guardian_epoch > 0),
  scope_snapshot_hash text NOT NULL CHECK (scope_snapshot_hash ~ '^[0-9a-f]{64}$'),
  computed_assignment_ids jsonb NOT NULL DEFAULT '[]'::jsonb CHECK (jsonb_typeof(computed_assignment_ids) = 'array'),
  computed_reservation_ids jsonb NOT NULL DEFAULT '[]'::jsonb CHECK (jsonb_typeof(computed_reservation_ids) = 'array'),
  evidence_refs jsonb NOT NULL DEFAULT '[]'::jsonb CHECK (jsonb_typeof(evidence_refs) = 'array'),
  status text NOT NULL CHECK (status IN ('ACTIVE','LIFTED','EXPIRED')),
  renew_count integer NOT NULL DEFAULT 0 CHECK (renew_count >= 0),
  review_due_at timestamptz NOT NULL,
  expires_at timestamptz NOT NULL,
  current_version bigint NOT NULL CHECK (current_version >= 1),
  created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  updated_at timestamptz NOT NULL DEFAULT clock_timestamp()
);

-- ---------------------------------------------------------------------------
-- 7. Advisory receipts — append-only, non-authoritative
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.world8_guardian_advisory_receipts (
  advisory_id text PRIMARY KEY,
  world_id text NOT NULL DEFAULT 'world-001',
  society_id text NOT NULL,
  project_id text NULL,
  assignment_id text NULL REFERENCES public.world8_guardian_work_assignments(assignment_id),
  advisor_provider text NOT NULL,
  advisor_model text NOT NULL,
  advisor_build text NULL,
  prompt_contract_version text NOT NULL,
  input_hash text NOT NULL CHECK (input_hash ~ '^[0-9a-f]{64}$'),
  allowed_field text NOT NULL,
  bounded_value jsonb NOT NULL,
  recommendation_summary text NOT NULL,
  confidence numeric NULL CHECK (confidence IS NULL OR (confidence >= 0 AND confidence <= 1)),
  expires_at timestamptz NULL,
  created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  CHECK (allowed_field NOT IN ('hard_budget_ceiling','authority','hard_revoke','promotion','effect_authorization','gap_resolution','policy_mutation'))
);

CREATE OR REPLACE FUNCTION public.world8_guardian_prevent_advisory_mutation_v01()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RAISE EXCEPTION 'WORLD8_GUARDIAN_ADVISORY_APPEND_ONLY';
END;
$$;

DROP TRIGGER IF EXISTS world8_guardian_advisory_append_only_trg
  ON public.world8_guardian_advisory_receipts;
CREATE TRIGGER world8_guardian_advisory_append_only_trg
BEFORE UPDATE OR DELETE ON public.world8_guardian_advisory_receipts
FOR EACH ROW EXECUTE FUNCTION public.world8_guardian_prevent_advisory_mutation_v01();

-- ---------------------------------------------------------------------------
-- 8. Decomposition plan projection (proposal-only)
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.world8_guardian_decomposition_plans (
  plan_id text PRIMARY KEY,
  world_id text NOT NULL DEFAULT 'world-001',
  society_id text NOT NULL,
  project_id text NULL,
  gap_id text NOT NULL,
  proposed_by_kind text NOT NULL CHECK (proposed_by_kind IN ('MASON_PLANNER','DETERMINISTIC_PLANNER')),
  proposed_by_ref text NOT NULL,
  policy_version text NOT NULL,
  dispatch_mode text NOT NULL CHECK (dispatch_mode = 'SHARDED'),
  dependency_dag jsonb NOT NULL CHECK (jsonb_typeof(dependency_dag) = 'object'),
  work_orders jsonb NOT NULL CHECK (jsonb_typeof(work_orders) = 'array'),
  completion_contract jsonb NOT NULL CHECK (jsonb_typeof(completion_contract) = 'object'),
  policy_check_state text NOT NULL CHECK (policy_check_state IN ('PENDING','PASS','FAIL')),
  policy_violations jsonb NOT NULL DEFAULT '[]'::jsonb CHECK (jsonb_typeof(policy_violations) = 'array'),
  current_version bigint NOT NULL CHECK (current_version >= 1),
  created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  updated_at timestamptz NOT NULL DEFAULT clock_timestamp()
);

-- ---------------------------------------------------------------------------
-- 9. Draft-only constraints intentionally NOT yet encoded
-- ---------------------------------------------------------------------------
-- These require reviewed transactional RPCs / triggers, not ad-hoc table writes:
--   * guardian_epoch checked against live leader lease on every control append
--   * per-aggregate expected-version CAS and event+projection atomic append
--   * valid WorkAssignment state-transition matrix
--   * all-or-none resource acquisition with deterministic resource sort key
--   * Society scope enforcement at every write function
--   * envelope shrink/release/settle overhang transaction semantics
--   * circuit breaker admission checks
--   * IMMEDIATE/DRAIN quarantine enforcement against existing leases
--   * SelectionDecision remains OUTSIDE this Guardian schema
--   * HARD_REVOKE remains OUTSIDE this Guardian schema
--   * external-effect authorization remains OUTSIDE this Guardian schema
--   * GapLifecycleEvent remains OUTSIDE this Guardian schema
--
-- Privileges/RLS are also intentionally omitted from this candidate until the governed
-- Operational Guardian service principal/DB role is resolved. Do not grant PUBLIC/anon/authenticated.

ROLLBACK;
-- Deliberate ROLLBACK: this is a reviewable schema candidate, not an executable migration.
