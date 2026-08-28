from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
foundation = (ROOT / 'supabase/migrations/20260827140600_world8_engineering_guardian_foundation_v01.sql').read_text()
policy = (ROOT / 'supabase/migrations/20260827143630_world8_engineering_guardian_policy_v011.sql').read_text()
privacy_repair = (ROOT / 'supabase/migrations/20260827152400_world8_guardian_privacy_false_positive_repair_v011.sql').read_text()
diagnostic_context_repair = (ROOT / 'supabase/migrations/20260828102300_world8_guardian_diagnostic_environment_tag_propagation_v012.sql').read_text()
direct_edge_repair = (ROOT / 'supabase/migrations/20260828102400_world8_guardian_direct_edge_render_tag_fix_v0121.sql').read_text()
diag_regression = (ROOT / 'tests/guardian_operational/diagnostic_environment_tag_regression.sql').read_text()
guardian_migrations = foundation + '\n' + policy + '\n' + privacy_repair + '\n' + diagnostic_context_repair + '\n' + direct_edge_repair
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
    'privacy helper present': 'world8_guardian_payload_has_private_reasoning_v1' in privacy_repair,
    'error identifiers are not scanned as free text': "v_norm_key in ('chainofthought','reasoningtrace','privatereasoning')" in privacy_repair,
    'natural language private reasoning still rejected': 'chain[ -]+of[ -]+thought' in privacy_repair and 'private[ -]+reasoning' in privacy_repair,
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

    # Diagnostic Memory -> environment -> Mason/Guardian repair.
    'environment tag helper': 'world8_guardian_environment_tags_v1' in diagnostic_context_repair,
    'explicit context tags consumed': "p_environment_ref->'context_tags'" in diagnostic_context_repair,
    'explicit diagnostic tags consumed': "p_environment_ref->'diagnostic_tags'" in diagnostic_context_repair,
    'environment ref participates in preflight classification': "coalesce(p_environment_ref::text,'')" in diagnostic_context_repair,
    'per-tag union retrieval avoids TOKEN_ALL false negative': 'TOKEN_ANY_PER_TAG_UNION' in diagnostic_context_repair and 'world8_diag_context_search_v1' in diagnostic_context_repair,
    'pre-action diagnostic lookup': "v_diag:=public.world8_diag_context_search_v1" in diagnostic_context_repair,
    'pre-action recurrence advisory persisted': 'Known Diagnostic Memory recurrence risk surfaced before action' in diagnostic_context_repair,
    'direct edge URL classified as render risk': "supabase\\.co/functions" in direct_edge_repair and "'RENDER'" in direct_edge_repair,
    'regression requires Supabase tag': 'TEST_FAIL_SUPABASE_TAG_NOT_PROPAGATED' in diag_regression,
    'regression requires Access Mesh tag': 'TEST_FAIL_ACCESS_MESH_TAG_NOT_PROPAGATED' in diag_regression,
    'regression requires Render tag': 'TEST_FAIL_DIRECT_EDGE_RENDER_TAG_NOT_PROPAGATED' in diag_regression,
    'regression proves incident surfaced': 'TEST_FAIL_ENVIRONMENT_TAG_INCIDENT_NOT_SURFACED' in diag_regression,
    'regression rolls back fixture': 'rollback;' in diag_regression.lower(),
}

failed = [name for name, ok in checks.items() if not ok]
if failed:
    raise SystemExit('Engineering Guardian validation failed: ' + ', '.join(failed))
print('Engineering Guardian validation PASS:', len(checks), 'checks')
