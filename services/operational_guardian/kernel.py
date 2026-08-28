from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime
from decimal import Decimal
from enum import Enum
import hashlib


class GuardianKernelError(ValueError):
    def __init__(self, code: str, **details: object) -> None:
        super().__init__(code)
        self.code = code
        self.details = details


class WorkState(str, Enum):
    PLANNED = "PLANNED"
    ASSIGNED = "ASSIGNED"
    ACTIVE = "ACTIVE"
    COMPLETED = "COMPLETED"
    FAILED = "FAILED"
    CANCELLED = "CANCELLED"
    EXPIRED = "EXPIRED"


class DispatchMode(str, Enum):
    SINGLE = "SINGLE"
    REDUNDANT_N = "REDUNDANT_N"
    SHARDED = "SHARDED"


class FailureClass(str, Enum):
    PROVIDER_TRANSIENT = "PROVIDER_TRANSIENT"
    PROVIDER_SECURITY = "PROVIDER_SECURITY"
    MASON_DETERMINISTIC_FAIL = "MASON_DETERMINISTIC_FAIL"
    MASON_POLICY_VIOLATION = "MASON_POLICY_VIOLATION"
    MASON_CREDENTIAL_SUSPECT = "MASON_CREDENTIAL_SUSPECT"
    RESOURCE_LOCK_TIMEOUT = "RESOURCE_LOCK_TIMEOUT"
    DEADLOCK_DETECTED = "DEADLOCK_DETECTED"
    BUDGET_EXHAUSTED = "BUDGET_EXHAUSTED"
    DEADLINE_EXPIRED = "DEADLINE_EXPIRED"


class QuarantineMode(str, Enum):
    IMMEDIATE = "IMMEDIATE"
    DRAIN = "DRAIN"


_ALLOWED_WORK_TRANSITIONS: dict[WorkState, frozenset[WorkState]] = {
    WorkState.PLANNED: frozenset({WorkState.ASSIGNED, WorkState.CANCELLED, WorkState.EXPIRED}),
    WorkState.ASSIGNED: frozenset({WorkState.ACTIVE, WorkState.FAILED, WorkState.CANCELLED, WorkState.EXPIRED}),
    WorkState.ACTIVE: frozenset({WorkState.COMPLETED, WorkState.FAILED, WorkState.CANCELLED, WorkState.EXPIRED}),
    WorkState.COMPLETED: frozenset(),
    WorkState.FAILED: frozenset(),
    WorkState.CANCELLED: frozenset(),
    WorkState.EXPIRED: frozenset(),
}

_QUARANTINE_MODE: dict[FailureClass, QuarantineMode] = {
    FailureClass.PROVIDER_TRANSIENT: QuarantineMode.DRAIN,
    FailureClass.PROVIDER_SECURITY: QuarantineMode.IMMEDIATE,
    FailureClass.MASON_DETERMINISTIC_FAIL: QuarantineMode.DRAIN,
    FailureClass.MASON_POLICY_VIOLATION: QuarantineMode.IMMEDIATE,
    FailureClass.MASON_CREDENTIAL_SUSPECT: QuarantineMode.IMMEDIATE,
    FailureClass.RESOURCE_LOCK_TIMEOUT: QuarantineMode.DRAIN,
}


def _require_text(name: str, value: str) -> str:
    value = value.strip()
    if not value:
        raise GuardianKernelError(f"{name.upper()}_REQUIRED")
    return value


def validate_work_transition(current: WorkState | str, target: WorkState | str) -> None:
    current = WorkState(current)
    target = WorkState(target)
    if target not in _ALLOWED_WORK_TRANSITIONS[current]:
        raise GuardianKernelError(
            "FORBIDDEN_WORK_TRANSITION", current=current.value, target=target.value
        )


def dispatch_slot_key(
    mode: DispatchMode | str,
    *,
    redundant_ordinal: int | None = None,
    work_order_id: str | None = None,
) -> str:
    mode = DispatchMode(mode)
    if mode is DispatchMode.SINGLE:
        if redundant_ordinal is not None or work_order_id is not None:
            raise GuardianKernelError("SINGLE_DISPATCH_HAS_EXTRA_SLOT_SELECTOR")
        return "single"
    if mode is DispatchMode.REDUNDANT_N:
        if work_order_id is not None:
            raise GuardianKernelError("SHARDED_REDUNDANT_COMBINATION_FORBIDDEN_V0_1")
        if redundant_ordinal is None or redundant_ordinal < 1:
            raise GuardianKernelError("REDUNDANT_ORDINAL_REQUIRED")
        return f"redundant:{redundant_ordinal}"
    if redundant_ordinal is not None:
        raise GuardianKernelError("SHARDED_REDUNDANT_COMBINATION_FORBIDDEN_V0_1")
    work_order_id = _require_text("work_order_id", work_order_id or "")
    return f"shard:{work_order_id}"


def idempotency_key(
    gap_id: str,
    policy_version: str,
    dispatch_slot: str,
    attempt_no: int,
) -> str:
    if attempt_no < 1:
        raise GuardianKernelError("ATTEMPT_NO_OUT_OF_RANGE")
    material = "|".join(
        [
            _require_text("gap_id", gap_id),
            _require_text("policy_version", policy_version),
            _require_text("dispatch_slot", dispatch_slot),
            str(attempt_no),
        ]
    )
    return hashlib.sha256(material.encode("utf-8")).hexdigest()


@dataclass(frozen=True)
class LeaderLease:
    world_id: str
    society_id: str
    guardian_shard_key: str
    lease_holder: str
    current_epoch: int
    fencing_token: int
    policy_version: str
    lease_expires_at: datetime


def validate_control_write(
    lease: LeaderLease,
    *,
    target_world_id: str,
    target_society_id: str,
    guardian_shard_key: str,
    holder_ref: str,
    guardian_epoch: int,
    fencing_token: int,
    policy_version: str,
    now: datetime,
) -> None:
    if lease.world_id != target_world_id or lease.society_id != target_society_id:
        raise GuardianKernelError("CROSS_SOCIETY_LEADER_USE_FORBIDDEN")
    if lease.guardian_shard_key != guardian_shard_key:
        raise GuardianKernelError("GUARDIAN_SHARD_MISMATCH")
    if lease.lease_holder != holder_ref:
        raise GuardianKernelError("GUARDIAN_LEASE_HOLDER_MISMATCH")
    if lease.current_epoch != guardian_epoch:
        raise GuardianKernelError("STALE_GUARDIAN_EPOCH")
    if lease.fencing_token != fencing_token:
        raise GuardianKernelError("STALE_GUARDIAN_FENCING_TOKEN")
    if lease.policy_version != policy_version:
        raise GuardianKernelError("GUARDIAN_POLICY_VERSION_MISMATCH")
    if now >= lease.lease_expires_at:
        raise GuardianKernelError("GUARDIAN_LEADER_LEASE_EXPIRED")


@dataclass(frozen=True)
class BudgetSnapshot:
    ceiling: Decimal
    settled: Decimal
    reserved: Decimal
    available: Decimal
    overhang: Decimal
    status: str = "ACTIVE"


def validate_budget_snapshot(snapshot: BudgetSnapshot) -> None:
    for field in ("ceiling", "settled", "reserved", "available", "overhang"):
        if getattr(snapshot, field) < 0:
            raise GuardianKernelError("NEGATIVE_BUDGET_COMPONENT", field=field)
    if snapshot.settled + snapshot.reserved + snapshot.available != snapshot.ceiling + snapshot.overhang:
        raise GuardianKernelError("BUDGET_ACCOUNTING_INVARIANT_BROKEN")
    if snapshot.overhang > 0 and snapshot.status != "OVERHANG_BLOCKED":
        raise GuardianKernelError("OVERHANG_MUST_BLOCK_NEW_DISPATCH")


def shrink_budget(snapshot: BudgetSnapshot, new_ceiling: Decimal) -> BudgetSnapshot:
    validate_budget_snapshot(snapshot)
    if new_ceiling < 0:
        raise GuardianKernelError("NEGATIVE_BUDGET_CEILING")
    available = max(Decimal("0"), new_ceiling - snapshot.settled - snapshot.reserved)
    overhang = max(Decimal("0"), snapshot.settled + snapshot.reserved - new_ceiling)
    status = "OVERHANG_BLOCKED" if overhang > 0 else snapshot.status
    result = BudgetSnapshot(
        ceiling=new_ceiling,
        settled=snapshot.settled,
        reserved=snapshot.reserved,
        available=available,
        overhang=overhang,
        status=status,
    )
    validate_budget_snapshot(result)
    return result


def release_reservation(snapshot: BudgetSnapshot, released: Decimal) -> tuple[BudgetSnapshot, Decimal]:
    validate_budget_snapshot(snapshot)
    if released <= 0 or released > snapshot.reserved:
        raise GuardianKernelError("INVALID_RESERVATION_RELEASE_AMOUNT")
    reserved = snapshot.reserved - released
    to_parent = min(released, snapshot.overhang)
    overhang = max(Decimal("0"), snapshot.overhang - to_parent)
    if overhang > 0:
        available = Decimal("0")
        status = "OVERHANG_BLOCKED"
    else:
        available = max(Decimal("0"), snapshot.ceiling - snapshot.settled - reserved)
        status = "ACTIVE"
    result = BudgetSnapshot(
        ceiling=snapshot.ceiling,
        settled=snapshot.settled,
        reserved=reserved,
        available=available,
        overhang=overhang,
        status=status,
    )
    validate_budget_snapshot(result)
    return result, to_parent


def provider_switch(
    *,
    deadline_at: datetime,
    provider_switch_budget: int,
) -> tuple[datetime, int]:
    if provider_switch_budget <= 0:
        raise GuardianKernelError("PROVIDER_SWITCH_BUDGET_EXHAUSTED")
    # Contract invariant: provider failover never resets the assignment deadline.
    return deadline_at, provider_switch_budget - 1


def quarantine_mode(failure_class: FailureClass | str) -> QuarantineMode:
    try:
        failure = FailureClass(failure_class)
    except ValueError as exc:
        raise GuardianKernelError("UNKNOWN_FAILURE_CLASS") from exc
    mode = _QUARANTINE_MODE.get(failure)
    if mode is None:
        raise GuardianKernelError("FAILURE_CLASS_NOT_QUARANTINE_TRIGGER", failure_class=failure.value)
    return mode
