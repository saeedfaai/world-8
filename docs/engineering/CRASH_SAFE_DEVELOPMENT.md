# World 8 Crash-Safe Development Continuity v0.1.2

Status: IMPLEMENTED IN RUNTIME / ENFORCED / TESTING FOR MERGE / NOT YET PROMOTED

## Purpose

A Room or Mason must never depend on the chat window, provider memory, or a later reconstruction pass to explain what happened. **Write progress while progress happens. Do not reconstruct missing progress from memory after a crash.**

This extends the existing World 8 Development/Continuity fabric. It does not create a second DCP, Actor registry, authority system, Work registry, Workspace registry, Resume registry, Handoff system, or Postflight system.

The journal stores operational engineering facts: decisions, evidence references, changed files/DB objects, tests, completed/remaining work, known constraints, and the next safe action. It must never store private chain-of-thought, raw credentials, or secrets.

## Re-entry is Resume-first

On reconnect, after a crash, or on the next day:

1. Call `world8_dev_resume_board_v1` to see Work streams across Rooms.
2. Select the Work and call `world8_dev_resume_capsule_v2(work_id)`.
3. Read `resume_state` before treating Scribe state as an error.
4. Read in this order:
   - `START_HERE.md`
   - this document
   - `resume_state`
   - latest checkpoint
   - journal tail
   - latest Handoff / latest Postflight
   - Diagnostic Memory
   - Work Capsule / Code Shadow
5. Execute the persisted `next_safe_action` only after canonical-head/workspace freshness is verified.

If persisted evidence has a gap, record the gap as an incident/recovery condition. Do not fill it from chat memory.

## Closure-aware Resume Capsule v2.1

`world8_dev_resume_capsule_v2` keeps its existing RPC name for compatibility but returns schema `WORLD8_DEV_RESUME_CAPSULE/2.1`.

For Work with an ACTIVE development Session:

- `resume_state` is `ACTIVE_CLEAN` or `ACTIVE_BLOCKED`,
- `next_safe_action` comes from the latest checkpoint when available,
- `next_action_source=LATEST_CHECKPOINT`,
- `active_scribe_guard` is the live checkpoint/cadence gate,
- `closure_guard` is expected to remain blocked until the Session is cleanly closed.

For Work with no ACTIVE development Session:

- the active-session Scribe is `NOT_APPLICABLE` with reason `NO_ACTIVE_SESSION`; absence of a live Session is not itself a closure failure,
- `closure_guard` reports closure evidence independently,
- latest Postflight evidence is returned separately,
- a clean closed Work with Closure Guard PASS and Postflight PASS reports `resume_state=CLOSED_CLEAN`,
- `next_safe_action` prefers the final Handoff over the immutable closure checkpoint,
- `next_action_source=FINAL_HANDOFF` when a final Handoff exists.

This prevents a completed Work from presenting its pre-Handoff checkpoint instruction as the current next action after Handoff/Postflight have already completed.

Runtime regression evidence for v0.1.2:

- the completed Crash-Safe v0.1.1 Work returns `CLOSED_CLEAN`, `FINAL_HANDOFF`, active Scribe `NOT_APPLICABLE`, Closure Guard `PASS`, and Postflight `PASS`,
- the active v0.1.2 repair Work returns `ACTIVE_CLEAN`, `LATEST_CHECKPOINT`, live Scribe `PASS`, and Closure Guard `BLOCKED` while its Session is still open.

## Session baseline

Every governed coding Room starts `world8_dev_session_start_v1` after its isolated Workspace exists. Session start atomically creates:

1. an ACTIVE liveness Session,
2. a START journal event,
3. an immutable `SESSION_START` checkpoint.

This closes the gap between beginning work and remembering to write a note.

Default cadence:

- checkpoint interval: 300 seconds (5 minutes),
- crash suspicion timeout: 600 seconds (10 minutes).

A heartbeat does not replace a checkpoint.

## Append-only Journal

`world8_dev_session_journal` is append-only and hash chained per Work through `previous_event_hash`.

Material events use `requires_checkpoint=true`. Examples:

- migration applied,
- commit or material code milestone,
- test state changed,
- architectural decision,
- error diagnosed/repaired,
- canonical refresh/rebase,
- next safe action changed materially.

Use `world8_dev_checkpoint_v1` for such milestones. It writes the journal event and immutable checkpoint in one transaction.

Every checkpoint requires a non-empty `next_safe_action` and records Work/Session/Room/Workspace, canonical head, branch/commit when known, completed/remaining work, known issues, do-not-do constraints, and evidence refs.

## Scribe Guard — live work

`world8_dev_scribe_guard_v1` is the machine-enforced Scribe/Secretary gate for ACTIVE Sessions.

For an ACTIVE Session it blocks on:

- `CHECKPOINT_REQUIRED`
- `UNCHECKPOINTED_PROGRESS`
- `CHECKPOINT_INTERVAL_EXCEEDED`
- `NEXT_SAFE_ACTION_REQUIRED`

So the five-minute cadence is no longer merely advisory. A runtime negative test forced an overdue checkpoint and received `CHECKPOINT_INTERVAL_EXCEEDED`.

The Resume Capsule does not reinterpret `ACTIVE_DEV_SESSION_REQUIRED` as a closure failure. Once there is no ACTIVE Session it exposes the live Scribe as `NOT_APPLICABLE` and uses the separate Closure Guard for closure truth.

## N-Mason READY_FOR_REVIEW

`world8_mason_pool_mark_ready_v1` re-verifies Assignment -> Work -> Workspace actor binding.

For Work where `crash_safe_required=true`, READY_FOR_REVIEW additionally requires:

- an ACTIVE Scribe Session for the Work/Actor/Room,
- live Scribe Guard PASS,
- a `MILESTONE`, `COMMIT`, `TEST`, or `MANUAL` checkpoint created after the assignment entered CODING.

A baseline SESSION_START or a provider routing hint is not sufficient evidence of completed coding.

## Closure Scribe

`world8_dev_scribe_closure_guard_v1` is separate from the live guard. A crash-safe Work cannot cleanly close while any relevant Session is ACTIVE or STALE. Every CLOSED Session must end with an immutable `BEFORE_HANDOFF` checkpoint and have no dirty checkpoint-required events.

`world8_dev_session_close_v1` creates that `BEFORE_HANDOFF` checkpoint, appends CLOSURE evidence, and then marks the Session CLOSED. It returns:

- `handoff_required=true`
- `postflight_required=true`

`world8_dev_record_handoff_v1` calls the closure guard for crash-safe Work. A runtime negative test attempted Handoff with an ACTIVE Session and received `SCRIBE_CLOSURE_REQUIRED`.

`world8_mason_postflight_v1` also checks closure evidence and requires a real Handoff for crash-safe Work. Scribe evidence is included in its checklist.

## All new developer Work is crash-safe

The `world8_dev_work_crash_safe_default_trg` trigger injects:

- `crash_safe_required=true`
- `crash_safe_policy_version=0.1.1`

for newly inserted `world8_dev_work_items`.

Existing legacy Work is not silently rewritten. A legacy Work becomes enforced only when explicitly migrated/flagged. This avoids retroactively invalidating historical Handoff/Postflight receipts.

## Full lifecycle

`Resume Board -> Resume Capsule -> Preflight -> Search -> Work Claim -> isolated Workspace -> Session Start -> Qualification -> Authorization -> Admission -> Lease/Fencing/CAS -> Journal+Checkpoint during work -> PR/CI -> serialized Merge -> Change/Code Shadow -> Session Close -> Handoff -> Postflight`

Parallel coding is allowed across independent Workspaces. Canonical truth is serialized. Provider/model/session are Execution metadata, not persistent Actor identity.

## Diagnostic Memory vs Journal

The Journal answers: **what happened in this Work and what is the next safe action?**

Diagnostic Memory answers: **has this error happened before, how was it repaired, and what should another Mason reuse?**

Material failures must enter Diagnostic Memory rather than disappearing after repair.

Repaired incidents discovered while building Crash-Safe include:

- `SCRIBE_GUARD_MISSING_END_IF`
- `CHECKPOINT_EVENT_TIMESTAMP_ORDERING_RISK`
- `INVALID_CHECKPOINT_KIND_MERGE`
- `DIAG_TAG_UNKNOWN_CONTRACT`
- `LEASE_WORKSPACE_ID_COLUMN_ASSUMED`
- `AUTHORITY_RULE_STATUS_COLUMN_ASSUMED`
- `DIAG_RUN_ID_FK_ASSUMED`
- `HANDOFF_ARGUMENT_ARITY_MISMATCH`
- `INVALID_REUSE_DECISION`

## Security

- Journal/checkpoint evidence is append-only.
- Tables/functions are service-role controlled; public/anon/authenticated access is revoked where applicable.
- No raw secrets or credentials are stored.
- Never store private chain-of-thought.
- Store concise operational summaries, decisions, tests, references, and next actions only.
