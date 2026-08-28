from datetime import datetime, timedelta, timezone
from decimal import Decimal

import pytest

from services.operational_guardian.kernel import (
    BudgetSnapshot,
    FailureClass,
    GuardianKernelError,
    LeaderLease,
    dispatch_slot_key,
    idempotency_key,
    provider_switch,
    quarantine_mode,
    release_reservation,
    shrink_budget,
    validate_control_write,
    validate_work_transition,
)


def err_code(excinfo):
    return excinfo.value.code


def test_work_transition_happy_path_and_terminal_rejection():
    validate_work_transition("PLANNED", "ASSIGNED")
    validate_work_transition("ASSIGNED", "ACTIVE")
    validate_work_transition("ACTIVE", "COMPLETED")
    with pytest.raises(GuardianKernelError) as exc:
        validate_work_transition("COMPLETED", "ACTIVE")
    assert err_code(exc) == "FORBIDDEN_WORK_TRANSITION"


def test_dispatch_slot_identity_and_v01_hybrid_forbidden():
    assert dispatch_slot_key("SINGLE") == "single"
    assert dispatch_slot_key("REDUNDANT_N", redundant_ordinal=2) == "redundant:2"
    assert dispatch_slot_key("SHARDED", work_order_id="schema") == "shard:schema"
    with pytest.raises(GuardianKernelError) as exc:
        dispatch_slot_key("SHARDED", redundant_ordinal=1, work_order_id="schema")
    assert err_code(exc) == "SHARDED_REDUNDANT_COMBINATION_FORBIDDEN_V0_1"


def test_idempotency_key_stable_and_slot_sensitive():
    a = idempotency_key("gap-1", "p1", "redundant:1", 1)
    b = idempotency_key("gap-1", "p1", "redundant:1", 1)
    c = idempotency_key("gap-1", "p1", "redundant:2", 1)
    assert a == b
    assert a != c


def lease():
    now = datetime.now(timezone.utc)
    return LeaderLease(
        world_id="world-001",
        society_id="society-trading",
        guardian_shard_key="primary",
        lease_holder="guardian-a",
        current_epoch=7,
        fencing_token=44,
        policy_version="guardian-policy-v0.1.3",
        lease_expires_at=now + timedelta(minutes=5),
    ), now


def test_control_write_requires_same_society_epoch_fence_policy_and_live_lease():
    l, now = lease()
    validate_control_write(
        l,
        target_world_id="world-001",
        target_society_id="society-trading",
        guardian_shard_key="primary",
        holder_ref="guardian-a",
        guardian_epoch=7,
        fencing_token=44,
        policy_version="guardian-policy-v0.1.3",
        now=now,
    )
    for change, code in [
        ({"target_society_id": "society-company"}, "CROSS_SOCIETY_LEADER_USE_FORBIDDEN"),
        ({"guardian_epoch": 6}, "STALE_GUARDIAN_EPOCH"),
        ({"fencing_token": 43}, "STALE_GUARDIAN_FENCING_TOKEN"),
        ({"policy_version": "old"}, "GUARDIAN_POLICY_VERSION_MISMATCH"),
    ]:
        kwargs = dict(
            target_world_id="world-001",
            target_society_id="society-trading",
            guardian_shard_key="primary",
            holder_ref="guardian-a",
            guardian_epoch=7,
            fencing_token=44,
            policy_version="guardian-policy-v0.1.3",
            now=now,
        )
        kwargs.update(change)
        with pytest.raises(GuardianKernelError) as exc:
            validate_control_write(l, **kwargs)
        assert err_code(exc) == code


def test_expired_leader_fails_closed_for_new_control_write():
    l, now = lease()
    with pytest.raises(GuardianKernelError) as exc:
        validate_control_write(
            l,
            target_world_id="world-001",
            target_society_id="society-trading",
            guardian_shard_key="primary",
            holder_ref="guardian-a",
            guardian_epoch=7,
            fencing_token=44,
            policy_version="guardian-policy-v0.1.3",
            now=l.lease_expires_at,
        )
    assert err_code(exc) == "GUARDIAN_LEADER_LEASE_EXPIRED"


def test_budget_shrink_preserves_live_reservations_and_records_overhang():
    before = BudgetSnapshot(
        ceiling=Decimal("300"),
        settled=Decimal("180"),
        reserved=Decimal("80"),
        available=Decimal("40"),
        overhang=Decimal("0"),
    )
    after = shrink_budget(before, Decimal("100"))
    assert after.settled == Decimal("180")
    assert after.reserved == Decimal("80")
    assert after.available == Decimal("0")
    assert after.overhang == Decimal("160")
    assert after.status == "OVERHANG_BLOCKED"


def test_release_under_overhang_reclaims_to_parent_before_child_available():
    snapshot = BudgetSnapshot(
        ceiling=Decimal("100"),
        settled=Decimal("20"),
        reserved=Decimal("100"),
        available=Decimal("0"),
        overhang=Decimal("20"),
        status="OVERHANG_BLOCKED",
    )
    after, to_parent = release_reservation(snapshot, Decimal("10"))
    assert to_parent == Decimal("10")
    assert after.overhang == Decimal("10")
    assert after.available == Decimal("0")


def test_provider_switch_never_resets_deadline():
    deadline = datetime(2026, 8, 28, 12, 0, tzinfo=timezone.utc)
    new_deadline, remaining = provider_switch(deadline_at=deadline, provider_switch_budget=2)
    assert new_deadline == deadline
    assert remaining == 1


def test_failure_class_is_closed_and_quarantine_mode_is_deterministic():
    assert quarantine_mode(FailureClass.PROVIDER_SECURITY).value == "IMMEDIATE"
    assert quarantine_mode(FailureClass.PROVIDER_TRANSIENT).value == "DRAIN"
    with pytest.raises(GuardianKernelError) as exc:
        quarantine_mode("LLM_GUESSED_NEW_CLASS")
    assert err_code(exc) == "UNKNOWN_FAILURE_CLASS"
