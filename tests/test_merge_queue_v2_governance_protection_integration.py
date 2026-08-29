from pathlib import Path

SQL = Path('supabase/drafts/20260829_world8_merge_queue_v2_governance_protection_integration.sql').read_text()


def test_claim_rechecks_protection_before_merging():
    assert "world8_merge_protection_gate_v1" in SQL
    assert "validation_check_id" in SQL
    assert "state='MERGING'" in SQL
    assert SQL.index("world8_merge_protection_gate_v1") < SQL.index("state='MERGING'")


def test_complete_rechecks_protection():
    assert "MERGE_PROTECTION_GATE_BLOCKED" in SQL
    assert "completion_protection_gate" in SQL


def test_resource_scoping_is_preserved():
    assert "canonical_resource_id=p_canonical_resource_id" in SQL
    assert "canonical_resource_id=v_q.canonical_resource_id" in SQL
    assert "world8:canonical-merge:" in SQL


def test_receipt_carries_protection_evidence():
    assert "WORLD8_MERGE_RECEIPT/2.1" in SQL
    assert "'protection',v_protection" in SQL
