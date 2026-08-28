-- World 8 Operational Guardian v0.1.3 — EFFECTIVE CORRECTIVE SCHEMA OVERLAY
-- Status: DESIGN_FROZEN / NOT A MIGRATION / NOT APPLIED / NOT EVIDENCED
-- DCR: architecture/proposals/DCR-0003-operational-guardian-leader-scope.md
-- Effective revision: architecture/contracts/guardian-operational-v0.1.3.yaml

-- ===========================================================================
-- EFFECTIVE REQUIREMENT 1 — no single World-global Guardian leader row
-- ===========================================================================
-- Forbidden future physical identity:
--
--   guardian_key text primary key check (guardian_key='operational-guardian')
--
-- as the only leader/fencing row for all Societies.

-- Future executable leader projection MUST use identity equivalent to:
--
--   world_id text not null,
--   society_id text not null,
--   guardian_shard_key text not null default 'primary',
--   current_epoch bigint not null,
--   lease_holder text null,
--   lease_expires_at timestamptz null,
--   fencing_token bigint not null,
--   policy_version text not null,
--   primary key (world_id, society_id, guardian_shard_key)
--
-- v0.1.x permits guardian_shard_key='primary' only unless another DCR is accepted.

-- ===========================================================================
-- EFFECTIVE REQUIREMENT 2 — same-Society leader validation on every control write
-- ===========================================================================
-- Transactional mutation RPC MUST:
--   1. determine target aggregate society_id;
--   2. determine guardian_shard_key (v0.1.x: primary);
--   3. lock/read the exact matching leader row;
--   4. verify lease holder/current epoch/fencing token/not-expired;
--   5. reject if event/control society differs from leader society;
--   6. perform aggregate CAS + event/projection transaction.

-- ===========================================================================
-- EFFECTIVE REQUIREMENT 3 — epoch values are scoped, not World-global clocks
-- ===========================================================================
-- Epoch 7 in Society A and epoch 7 in Society B are valid independent values.
-- Code MUST NOT compare epochs across distinct leader identities to infer causal order.

-- ===========================================================================
-- EFFECTIVE REQUIREMENT 4 — failover audit blast radius
-- ===========================================================================
-- Takeover/audit queries MUST include exact society_id + guardian_shard_key scope.
-- Failover in Society A MUST NOT fence/expire/inherit/rewrite Society B operational state.

-- ===========================================================================
-- EFFECTIVE REQUIREMENT 5 — future within-Society sharding is not implicit
-- ===========================================================================
-- Any additional guardian_shard_key requires a later DCR plus deterministic
-- aggregate-to-shard routing. No aggregate may be writable under multiple leader rows.

-- Required delta tests:
--   tests/guardian_operational/NEGATIVE_TEST_DELTA_v0.1.3.md
--
-- Evidence ceiling: DESIGN/SCHEMA SPECIFICATION ONLY. No runtime PASS claim.
