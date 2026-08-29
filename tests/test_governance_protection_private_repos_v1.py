from pathlib import Path

SQL = Path('supabase/drafts/20260829_world8_governance_protection_private_repos_v1.sql').read_text()

def test_fallback_is_fail_closed():
    assert "branch_protection_limitation_acknowledged" in SQL
    assert "no_world9_git_write" in SQL
    assert "GOVERNANCE_PROTECTION_EXACT_HEAD_VALIDATION_REQUIRED" in SQL
    assert "GOVERNANCE_PROTECTION_VALIDATION_MISMATCH" in SQL
    assert "EXTERNAL_VALIDATION_SUBSTITUTION_NOT_ELIGIBLE" in SQL

def test_external_substitution_only_for_pre_step_infrastructure_failure():
    assert "INFRASTRUCTURE_PRE_STEP" in SQL
    assert "github_actions_runner_assigned" in SQL
    assert "head_commit" in SQL
    assert "repo_ref" in SQL

def test_native_protection_remains_preferred():
    assert "GITHUB_NATIVE" in SQL
    assert "ENFORCED" in SQL
    assert "RULESET_ENFORCED" in SQL
    assert "PROTECTED" in SQL
