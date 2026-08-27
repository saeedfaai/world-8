# Diagnostic Memory — Admission Missing Workspace FK Failure

Date: 2026-08-27
Status: FIX CANDIDATE / RUNTIME NOT YET PATCHED
Scope: `world8_dev_admission_check_v2`

## Discovery

During W8-P01 rollback-safe runtime behavioral probing, a deliberately nonexistent workspace ID was supplied to `world8_dev_admission_check_v2`.

The function correctly detected the unresolved workspace and assembled the blocker:
`ACTIVE_WORKSPACE_REQUIRED`

However, the function then attempted to insert the blocked admission receipt with the same nonexistent `workspace_id` in the nullable FK column `world8_dev_admission_receipts.workspace_id`.

Observed failure:
- SQLSTATE family: `23503 foreign_key_violation`
- constraint: `world8_dev_admission_receipts_workspace_id_fkey`

## Safety impact

- authorization was not bypassed;
- no lease or write capability was granted;
- the probe left no persistent data;
- however, a caller received an exception instead of a structured `BLOCKED` admission receipt.

This is therefore a **fail-closed but structurally incorrect failure mode**.

## Root cause

The receipt schema already permits `workspace_id IS NULL`, but the function used `p_workspace_id` directly in the FK slot even when the ACTIVE workspace lookup failed.

The requested workspace identity and the resolved persistent workspace reference were conflated.

## Fix design

Migration candidate:
`supabase/migrations/20260827193000_world8_admission_missing_workspace_receipt_fix_v021.sql`

Rules:
1. preserve the caller-requested workspace ID in the JSON payload/evidence;
2. store the FK only when an ACTIVE workspace was actually resolved;
3. otherwise persist `workspace_id=NULL` and return a structured BLOCKED receipt;
4. do not weaken Work↔Actor, Workspace↔Actor, stale-base, authorization, or qualification checks.

## Regression gate

Workflow:
`W8 Admission Missing Workspace Regression`

Initial branch run:
https://github.com/saeedfaai/world-8/actions/runs/33108416048

Result:
- migration regression validator PASS
- existing Developer Admission validator PASS
- existing Identity & Authority validator PASS

## Required closure

- [ ] merge through governed PR
- [ ] apply canonical migration to Supabase using migration tooling
- [ ] repeat original nonexistent-workspace probe
- [ ] verify returned `gate_state=BLOCKED`
- [ ] verify `ACTIVE_WORKSPACE_REQUIRED` blocker present
- [ ] verify persisted receipt FK is NULL while requested workspace remains in payload/evidence
- [ ] verify no lease/write capability can be acquired from the blocked receipt
- [ ] record runtime receipt and close this diagnostic
