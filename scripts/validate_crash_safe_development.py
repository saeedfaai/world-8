from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
core = ROOT / "supabase" / "migrations" / "20260827121700_world8_dev_continuity_core_v01.sql"
resume = ROOT / "supabase" / "migrations" / "20260827122000_world8_dev_continuity_resume_scribe_v01.sql"
enforce = ROOT / "supabase" / "migrations" / "20260827125200_world8_crash_safe_enforcement_v011.sql"
harden = ROOT / "supabase" / "migrations" / "20260827125400_world8_crash_safe_mark_ready_actor_binding_v0111.sql"
closure_resume = ROOT / "supabase" / "migrations" / "20260827132600_world8_crash_safe_resume_closure_v012.sql"
doc = ROOT / "docs" / "engineering" / "CRASH_SAFE_DEVELOPMENT.md"
start = ROOT / "START_HERE.md"

for path in (core, resume, enforce, harden, closure_resume, doc, start):
    if not path.exists():
        raise SystemExit(f"Missing Crash-Safe Development file: {path.relative_to(ROOT)}")

sql = "\n".join(p.read_text(encoding="utf-8") for p in (core, resume, enforce, harden, closure_resume))
text = doc.read_text(encoding="utf-8")
start_text = start.read_text(encoding="utf-8")

required_sql = [
    "world8_dev_session_liveness",
    "world8_dev_session_journal",
    "world8_dev_session_checkpoints",
    "WORLD8_DEV_CONTINUITY_EVIDENCE_APPEND_ONLY",
    "world8_dev_journal_append_v1",
    "world8_dev_checkpoint_v1",
    "world8_dev_session_start_v1",
    "world8_dev_session_heartbeat_v1",
    "world8_dev_scribe_guard_v1",
    "UNCHECKPOINTED_PROGRESS",
    "NEXT_SAFE_ACTION_REQUIRED",
    "CHECKPOINT_INTERVAL_EXCEEDED",
    "world8_dev_resume_capsule_v2",
    "WORLD8_DEV_RESUME_CAPSULE/2.1",
    "resume_state",
    "ACTIVE_CLEAN",
    "ACTIVE_BLOCKED",
    "CLOSED_CLEAN",
    "CLOSED_AWAITING_POSTFLIGHT",
    "CLOSED_BLOCKED",
    "FINAL_HANDOFF",
    "LATEST_CHECKPOINT",
    "NOT_APPLICABLE",
    "NO_ACTIVE_SESSION",
    "active_scribe_guard",
    "closure_guard",
    "latest_postflight",
    "world8_dev_resume_board_v1",
    "world8_dev_session_close_v1",
    "world8_dev_scribe_closure_guard_v1",
    "ACTIVE_DEV_SESSION_MUST_CLOSE",
    "BEFORE_HANDOFF_CHECKPOINT_REQUIRED",
    "SCRIBE_CLOSURE_REQUIRED",
    "HANDOFF_REQUIRED_AFTER_SCRIBE_CLOSURE",
    "world8_dev_work_crash_safe_default_trg",
    "crash_safe_required",
    "crash_safe_policy_version",
    "world8_mason_pool_mark_ready_v1",
    "SCRIBE_REVIEW_CHECKPOINT_REQUIRED",
    "ASSIGNMENT_WORK_ACTOR_MISMATCH",
    "ASSIGNMENT_WORKSPACE_BINDING_MISMATCH",
    "handoff_required",
    "postflight_required",
    "previous_event_hash",
    "checkpoint_interval_seconds integer not null default 300",
    "crash_after_seconds integer not null default 600",
]
missing = [m for m in required_sql if m not in sql]
if missing:
    raise SystemExit(f"Crash-Safe Development migration set missing required markers: {missing}")

required_doc = [
    "Write progress while progress happens",
    "Do not reconstruct missing progress from memory after a crash",
    "operational engineering facts",
    "Never store private chain-of-thought",
    "Closure-aware Resume Capsule",
    "resume_state=CLOSED_CLEAN",
    "next_action_source=FINAL_HANDOFF",
    "NO_ACTIVE_SESSION",
    "Scribe Guard",
    "Resume Capsule",
    "Resume Board",
    "CHECKPOINT_INTERVAL_EXCEEDED",
    "READY_FOR_REVIEW",
    "BEFORE_HANDOFF",
    "handoff_required=true",
    "postflight_required=true",
    "crash_safe_required=true",
]
missing_doc = [m for m in required_doc if m not in text]
if missing_doc:
    raise SystemExit(f"Crash-Safe Development doc missing required invariant: {missing_doc}")

for forbidden in (
    "password_value", "secret_value", "api_key_value", "access_token_value",
    "credential_value", "chain_of_thought_text", "reasoning_trace"
):
    if re.search(rf"\b{re.escape(forbidden)}\b", sql, re.IGNORECASE):
        raise SystemExit(f"Forbidden storage marker found: {forbidden}")

if "world8_dev_checkpoint_v1(v_id" not in sql or "'SESSION_START'" not in sql:
    raise SystemExit("Session start must atomically create SESSION_START checkpoint")

cp = sql[sql.find("create or replace function public.world8_dev_checkpoint_v1"):]
if cp.find("world8_dev_journal_append_v1") > cp.find("v_now:=clock_timestamp()") and "v_now timestamptz;" in cp:
    raise SystemExit("Checkpoint timestamp must be captured after journal append")

mark = harden.read_text(encoding="utf-8")
for marker in (
    "world8_dev_scribe_guard_v1",
    "c.created_at>=v_a.updated_at",
    "c.checkpoint_kind in ('MILESTONE','COMMIT','TEST','MANUAL')",
    "ASSIGNMENT_WORK_ACTOR_MISMATCH",
):
    if marker not in mark:
        raise SystemExit(f"READY_FOR_REVIEW Scribe enforcement missing: {marker}")

closure_sql = closure_resume.read_text(encoding="utf-8")
for marker in (
    "v_active_count>0",
    "v_next:=coalesce(v_handoff_next,v_checkpoint_next,v_w.goal)",
    "v_next_source:=case when v_handoff_next is not null then 'FINAL_HANDOFF'",
    "coalesce(v_closure_guard->>'gate_state','BLOCKED')='PASS' and coalesce(v_postflight_gate,'')='PASS' then 'CLOSED_CLEAN'",
    "'gate_state','NOT_APPLICABLE'",
    "'reason','NO_ACTIVE_SESSION'",
    "'active_scribe_guard',v_active_scribe,'closure_guard',v_closure_guard",
    "'latest_postflight',v_postflight",
):
    if marker not in closure_sql:
        raise SystemExit(f"Closure-aware Resume Capsule invariant missing: {marker}")

for marker in ("Resume Board", "Resume Capsule", "Session Start", "Journal", "Checkpoint"):
    if marker not in start_text:
        raise SystemExit(f"START_HERE missing crash-safe re-entry marker: {marker}")

print("World 8 Crash-Safe Development v0.1.2 static validation PASS")
