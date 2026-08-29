from pathlib import Path

SQL = Path('supabase/drafts/20260829_world8_governance_protection_private_repos_v1.sql').read_text()


def test_fallback_is_fail_closed():
    for token in [
        'branch_protection_limitation_acknowledged',
        'no_world9_git_write',
        'GOVERNANCE_PROTECTION_EXACT_HEAD_VALIDATION_REQUIRED',
        'GOVERNANCE_PROTECTION_VALIDATION_MISMATCH',
        'EXTERNAL_VALIDATION_SUBSTITUTION_NOT_ELIGIBLE',
    ]:
        assert token in SQL


def test_external_substitution_only_for_pre_step_infrastructure_failure():
    for token in ['INFRASTRUCTURE_PRE_STEP','github_actions_runner_assigned','head_commit','repo_ref']:
        assert token in SQL


def test_native_protection_remains_preferred():
    for token in ['GITHUB_NATIVE','ENFORCED','RULESET_ENFORCED','PROTECTED']:
        assert token in SQL


def test_gate_is_single_purpose():
    assert 'create or replace function public.world8_merge_protection_gate_v1' in SQL
    assert 'create or replace function public.world8_merge_claim_next_v2' not in SQL
    assert 'create or replace function public.world8_merge_complete_v2' not in SQL
