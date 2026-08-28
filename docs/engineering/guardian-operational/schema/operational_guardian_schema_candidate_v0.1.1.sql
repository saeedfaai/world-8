-- World 8 Operational Guardian v0.1.1 — CORRECTIVE SCHEMA OVERLAY
-- Status: DESIGN_FROZEN / NOT A MIGRATION / NOT APPLIED / NOT EVIDENCED
-- Base candidate: operational_guardian_schema_candidate_v0.1.sql
-- Effective contract: architecture/contracts/guardian-operational-v0.1.1.yaml
-- DCR: architecture/proposals/DCR-0001-operational-guardian-dispatch-idempotency.md
--
-- This file is NOT intended to be executed after the v0.1 candidate. Neither candidate
-- has been applied. It records the exact physical-model corrections that MUST be folded
-- into any future executable migration candidate generated from the v0.1 design family.

-- ===========================================================================
-- REPAIR 1 — WorkControl lifecycle excludes QUARANTINED
-- ===========================================================================
-- Soft quarantine is a separate world8_guardian_quarantine_decisions aggregate/overlay.
-- The future executable CREATE TABLE for world8_guardian_work_controls MUST use:

-- state text not null check (state in (
--   'PLANNED','ASSIGNED','ACTIVE','COMPLETED','FAILED','CANCELLED','EXPIRED'
-- )),

-- Forbidden future physical model:
--   state IN (..., 'QUARANTINED')
-- because that creates a second quarantine truth in WorkControl.

-- ===========================================================================
-- REPAIR 2 — immutable dispatch_slot_key
-- ===========================================================================
-- The future executable world8_guardian_work_controls table MUST add:

-- dispatch_slot_key text not null,

-- The old uniqueness:
--   unique(gap_id, policy_version, assignment_kind, attempt_no)
-- MUST be replaced by:

-- unique(gap_id, policy_version, dispatch_slot_key, attempt_no)

-- assignment_kind remains descriptive metadata only.

-- ===========================================================================
-- REPAIR 3 — mode/slot structural checks
-- ===========================================================================
-- Future executable schema/RPC validation MUST enforce the equivalent of:

-- check (
--   (dispatch_mode = 'SINGLE'      and dispatch_slot_key = 'single')
--   or
--   (dispatch_mode = 'REDUNDANT_N' and dispatch_slot_key ~ '^redundant:[1-9][0-9]*$')
--   or
--   (dispatch_mode = 'SHARDED'     and dispatch_slot_key ~ '^shard:.+$')
-- )

-- Regex shape alone is not authorization:
-- REDUNDANT_N ordinal must also be <= policy-approved N and the Gap circuit breaker.
-- SHARDED work_order_id must also exist in the validated decomposition plan.
-- Those checks belong in the fenced transactional mutation RPC, not only a table CHECK.

-- ===========================================================================
-- REPAIR 4 — dispatch_slot_key immutability
-- ===========================================================================
-- Once WorkControl is created, the mutation RPC MUST reject any change to:
--   gap_id
--   society_id
--   policy_version (for that immutable assignment lineage)
--   dispatch_mode
--   dispatch_slot_key
--   attempt_no
--
-- Retry creates a new permitted attempt lineage; it does not rewrite these identity fields.

-- ===========================================================================
-- EFFECTIVE EXAMPLES
-- ===========================================================================
-- SINGLE:
--   gap=G17 policy=p1 slot=single attempt=1
--
-- REDUNDANT_N with N=3:
--   gap=G17 policy=p1 slot=redundant:1 attempt=1
--   gap=G17 policy=p1 slot=redundant:2 attempt=1
--   gap=G17 policy=p1 slot=redundant:3 attempt=1
--
-- SHARDED:
--   gap=G17 policy=p1 slot=shard:work-schema attempt=1
--   gap=G17 policy=p1 slot=shard:work-tests attempt=1
--
-- A replay of the exact same tuple is idempotent/duplicate-safe.
-- A distinct valid slot is parallel work, not a duplicate.

-- ===========================================================================
-- UNCHANGED REUSE / AUTHORITY BOUNDARIES
-- ===========================================================================
-- * world8_mason_assignments remains assignment identity/binding truth.
-- * world8_guardian_work_controls remains a 1:1 orchestration extension keyed by assignment_id.
-- * world8_dev_leases remains authority-bearing developer write lease truth.
-- * world8_guardian_capacity_leases grants capacity/semantic coordination only.
-- * GapSignal remains Observation-owned and immutable; no invented FK/table is added here.
-- * SelectionDecision, HARD_REVOKE, external-effect authorization and Spine writes remain
--   outside Operational Guardian authority.

-- ===========================================================================
-- PROMOTION GATE
-- ===========================================================================
-- A future executable migration candidate MUST NOT be promoted from v0.1 text by copy/paste.
-- It must be generated/reviewed against v0.1.1 and prove these corrections via negative tests.
-- Required negative tests are specified in:
--   tests/guardian_operational/NEGATIVE_TEST_DELTA_v0.1.1.md

-- Evidence ceiling: DESIGN/SCHEMA SPECIFICATION ONLY. No runtime PASS claim.
