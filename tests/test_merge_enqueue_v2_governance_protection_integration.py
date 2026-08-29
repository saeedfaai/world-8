from pathlib import Path

SQL = Path('supabase/drafts/20260829_world8_merge_enqueue_v2_governance_protection_integration.sql').read_text()


def test_enqueue_uses_central_protection_gate():
    assert 'world8_merge_protection_gate_v1(' in SQL
    assert 'protection_gate_at_enqueue' in SQL
    assert "v_state:='WAITING_CI'" in SQL
    assert "v_state:='QUEUED'" in SQL


def test_enqueue_never_queues_stale_or_protection_blocked_work():
    stale = SQL.index("v_state:='STALE_REBASE_REQUIRED'")
    blocked = SQL.index("v_state:='WAITING_CI'")
    queued = SQL.index("v_state:='QUEUED'")
    assert stale < queued
    assert blocked < queued
    assert 'STALE_CANONICAL_BASE' in SQL
    assert 'PROTECTION_BLOCKED' in SQL


def test_exact_head_and_repo_validation_precede_queue_insert():
    assert 'VALIDATION_HEAD_MISMATCH' in SQL
    assert 'VALIDATION_REPO_MISMATCH' in SQL
    assert SQL.index('VALIDATION_HEAD_MISMATCH') < SQL.index('insert into public.world8_merge_queue')
    assert SQL.index('VALIDATION_REPO_MISMATCH') < SQL.index('insert into public.world8_merge_queue')
