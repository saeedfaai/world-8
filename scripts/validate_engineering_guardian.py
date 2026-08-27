from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
foundation = (ROOT / 'supabase/migrations/20260827140600_world8_engineering_guardian_foundation_v01.sql').read_text()
policy = (ROOT / 'supabase/migrations/20260827143630_world8_engineering_guardian_policy_v011.sql').read_text()
guardian_migrations = foundation + '\n' + policy
doc = (ROOT / 'docs/engineering/ENGINEERING_GUARDIAN.md').read_text()
start = (ROOT / 'START_HERE.md').read_text()
workflow = (ROOT / '.github/workflows/validate-architecture.yml').read_text()

checks = {
    'companion sessions': 'world8_guardian_companion_sessions' in foundation,
    'append-only context events': 'WORLD8_GUARDIAN_EVENTS_APPEND_ONLY' in foundation,
    'automatic attach trigger': 'world8_guardian_session_checkpoint_attach_trg' in foundation and "checkpoint_kind='SESSION_START'" in foundation,
    'welcome function': 'world8_guardian_welcome_v1' in guardian_migrations,
    'context router': 'world8_guardian_context_classify_v1' in foundation,
    'awareness': 'world8_guardian_awareness_snapshot_v1' in foundation,
    'diagnostic canonical reuse': 'world8_diag_search_v2' in foundation and 'world8_code_shadow_lookup_v1' in foundation,
    'dialogue context': 'world8_guardian_ask_v1' in foundation,
    'advisory only': 'ADVISORY_ONLY' in guardian_migrations,
    'no raw secrets': 'GUARDIAN_RAW_SECRET_REJECTED' in guardian_migrations,
    'no private reasoning persistence': 'GUARDIAN_PRIVATE_REASONING_REJECTED' in guardian_migrations,
    'system service policy': "service_kind='SYSTEM_SERVICE'" in policy,
    'zero authority policy': "authority_mode='NONE'" in policy and "authority_effect='NONE'" in policy,
    'fixed service identity': 'service-world8-engineering-guardian' in policy,
    'append-only policy': 'WORLD8_GUARDIAN_POLICY_APPEND_ONLY' in policy,
    'frozen policy revision': "'guardian-policy-v0.1'" in policy and "'FROZEN'" in policy,
    'auto-fix disabled v0.1': "'auto_fix','DISABLED_V0_1'" in policy,
    'existing-gates-only block mode': 'MIRROR_EXISTING_HARD_GATES_ONLY' in policy,
    'policy change path': 'PROPOSAL_REVIEW_ADR_APPROVAL_FROZEN_REVISION' in policy,
    'stateless companion docs': 'stateless' in doc.lower(),
    'guardian not actor docs': 'not an Actor' in doc,
    'guardian never authority docs': 'Never become Authority' in doc,
    'message classes': all(x in doc for x in ('FACT', 'WARNING', 'SUGGESTION', 'POLICY')),
    'welcome first': 'Welcome first' in doc,
    'start here guardian': 'Engineering Guardian' in start,
    'workflow guardian validator': 'validate_engineering_guardian.py' in workflow,
}

failed = [name for name, ok in checks.items() if not ok]
if failed:
    raise SystemExit('Engineering Guardian validation failed: ' + ', '.join(failed))
print('Engineering Guardian validation PASS:', len(checks), 'checks')
