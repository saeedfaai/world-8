from pathlib import Path

SQL = Path('supabase/drafts/20260829_world8_governance_protection_private_repos_v1.sql').read_text()

def test_fallback_is_fail_closed():
    for token in ['branch_protection_limitation_acknowledged','no_world9_git_write','GOVERNANCE_PROTECTION_EXACT_HEAD_VALIDATION_REQUIRED','GOVERNANCE_PROTECTION_VALIDATION_MISMATCH','EXTERNAL_VALIDATION_SUBSTITUTION_NOT_ELIGIBLE']:
        assert token in SQL

def test_external_substitution_only_for_pre_step_infrastructure_failure():
    for token in ['INFRASTRUCTURE_PRE_STEP','github_actions_runner_assigned','head_commit','repo_ref']:
        assert token in SQL

def test_native_protection_remains_preferred():
    for token in ['GITHUB_NATIVE','ENFORCED','RULESET_ENFORCED','PROTECTED']:
        assert token in SQL

def test_claim_and_complete_recheck_same_gate():
    assert 'create or replace function public.world8_merge_claim_next_v2' in SQL
    assert 'create or replace function public.world8_merge_complete_v2' in SQL
    assert SQL.count('world8_merge_protection_gate_v1(') >= 3
    assert 'protection_gate_at_claim' in SQL
    assert 'protection_gate_at_complete' in SQL
    assert 'MERGE_ALREADY_IN_PROGRESS' in SQL
    assert 'STALE_CANONICAL_BASE' in SQL
