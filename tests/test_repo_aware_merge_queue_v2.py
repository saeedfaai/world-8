from pathlib import Path

SQL = Path('supabase/drafts/20260829_world8_repo_aware_merge_queue_v2.sql').read_text()


def test_v2_does_not_hardcode_world8_canonical_resource():
    v2 = SQL.split('create or replace function public.world8_merge_enqueue_v2', 1)[1]
    assert "resource-github-world8-canonical" not in v2


def test_enqueue_resolves_resource_from_workspace_git_binding():
    assert 'world8_dev_workspace_git_bindings' in SQL
    assert 'v_bind.canonical_resource_id' in SQL
    assert 'world8_dev_canonical_git_resource_current_v1(v_bind.canonical_resource_id)' in SQL


def test_resource_scoped_serialization_and_completion():
    assert "hashtext('world8:canonical-merge:'||p_canonical_resource_id)" in SQL
    assert "hashtext('world8:canonical-merge:'||v_q.canonical_resource_id)" in SQL
    assert 'where resource_id=v_q.canonical_resource_id' in SQL


def test_external_validation_is_bound_to_exact_repo_and_head():
    assert "v_check.status<>'PASS'" in SQL
    assert "VALIDATION_HEAD_MISMATCH" in SQL
    assert "VALIDATION_REPO_MISMATCH" in SQL
    assert "validation_source','WORLD8_EXTERNAL_VALIDATION'" in SQL


def test_v1_is_preserved():
    assert 'drop function public.world8_merge_enqueue_v1' not in SQL.lower()
    assert 'drop function public.world8_merge_claim_next_v1' not in SQL.lower()
    assert 'drop function public.world8_merge_complete_v1' not in SQL.lower()
