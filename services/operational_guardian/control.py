from __future__ import annotations

from dataclasses import dataclass, replace
from datetime import datetime
from decimal import Decimal
from enum import Enum
from typing import Iterable

from .budget import EnvelopeSnapshot
from .kernel import (
    BudgetSnapshot,
    FailureClass,
    GuardianKernelError,
    QuarantineMode,
    quarantine_mode,
    validate_budget_snapshot,
)


class ReservationState(str, Enum):
    REQUESTED = "REQUESTED"
    RESERVED = "RESERVED"
    ACTIVE = "ACTIVE"
    SETTLED = "SETTLED"
    RELEASED = "RELEASED"
    FAILED = "FAILED"
    CANCELLED = "CANCELLED"
    EXPIRED = "EXPIRED"


@dataclass(frozen=True)
class BudgetReservation:
    reservation_id: str
    assignment_id: str
    envelope_id: str
    dimension_class: str
    dimension_key: str
    requested_amount: Decimal
    reserved_amount: Decimal
    consumed_amount: Decimal
    state: ReservationState
    envelope_version_at_reserve: int | None
    expires_at: datetime


def request_reservation(
    *,
    reservation_id: str,
    assignment_id: str,
    envelope: EnvelopeSnapshot,
    amount: Decimal,
    expires_at: datetime,
) -> BudgetReservation:
    if amount <= 0:
        raise GuardianKernelError("RESERVATION_AMOUNT_MUST_BE_POSITIVE")
    return BudgetReservation(
        reservation_id=reservation_id,
        assignment_id=assignment_id,
        envelope_id=envelope.envelope_id,
        dimension_class=envelope.identity.dimension_class,
        dimension_key=envelope.identity.dimension_key,
        requested_amount=amount,
        reserved_amount=Decimal("0"),
        consumed_amount=Decimal("0"),
        state=ReservationState.REQUESTED,
        envelope_version_at_reserve=None,
        expires_at=expires_at,
    )


def reserve_requested(
    envelope: EnvelopeSnapshot,
    reservation: BudgetReservation,
    *,
    expected_envelope_version: int,
    now: datetime,
) -> tuple[EnvelopeSnapshot, BudgetReservation]:
    validate_budget_snapshot(envelope.budget)
    if reservation.state is not ReservationState.REQUESTED:
        raise GuardianKernelError("REQUESTED_RESERVATION_REQUIRED")
    if reservation.envelope_id != envelope.envelope_id:
        raise GuardianKernelError("RESERVATION_ENVELOPE_MISMATCH")
    if (reservation.dimension_class, reservation.dimension_key) != (
        envelope.identity.dimension_class,
        envelope.identity.dimension_key,
    ):
        raise GuardianKernelError("RESERVATION_DIMENSION_MISMATCH")
    if envelope.envelope_version != expected_envelope_version:
        raise GuardianKernelError("ENVELOPE_CAS_CONFLICT")
    if now >= reservation.expires_at:
        raise GuardianKernelError("RESERVATION_TTL_EXPIRED")
    if envelope.budget.status != "ACTIVE" or envelope.budget.overhang > 0:
        raise GuardianKernelError("ENVELOPE_BLOCKED_FOR_NEW_RESERVATION")
    if reservation.requested_amount > envelope.budget.available:
        raise GuardianKernelError("RESERVATION_EXCEEDS_AVAILABLE")

    b = envelope.budget
    envelope_after = replace(
        envelope,
        budget=BudgetSnapshot(
            ceiling=b.ceiling,
            settled=b.settled,
            reserved=b.reserved + reservation.requested_amount,
            available=b.available - reservation.requested_amount,
            overhang=b.overhang,
            status=b.status,
        ),
        envelope_version=envelope.envelope_version + 1,
    )
    reservation_after = replace(
        reservation,
        reserved_amount=reservation.requested_amount,
        state=ReservationState.RESERVED,
        envelope_version_at_reserve=envelope.envelope_version,
    )
    validate_budget_snapshot(envelope_after.budget)
    return envelope_after, reservation_after


def activate_reservation(reservation: BudgetReservation, *, now: datetime) -> BudgetReservation:
    if reservation.state is not ReservationState.RESERVED:
        raise GuardianKernelError("RESERVED_RESERVATION_REQUIRED")
    if now >= reservation.expires_at:
        raise GuardianKernelError("RESERVATION_TTL_EXPIRED")
    return replace(reservation, state=ReservationState.ACTIVE)


def record_usage(reservation: BudgetReservation, amount: Decimal) -> BudgetReservation:
    if reservation.state is not ReservationState.ACTIVE:
        raise GuardianKernelError("ACTIVE_RESERVATION_REQUIRED")
    if amount <= 0:
        raise GuardianKernelError("USAGE_AMOUNT_MUST_BE_POSITIVE")
    consumed = reservation.consumed_amount + amount
    if consumed > reservation.reserved_amount:
        raise GuardianKernelError("RESERVATION_CONSUMPTION_EXCEEDS_RESERVED")
    return replace(reservation, consumed_amount=consumed)


def _release_unused_under_overhang(b: BudgetSnapshot, amount: Decimal) -> tuple[Decimal, Decimal, Decimal]:
    reduction = min(amount, b.overhang)
    return b.overhang - reduction, b.available + (amount - reduction), reduction


def settle_reservation(
    envelope: EnvelopeSnapshot,
    reservation: BudgetReservation,
) -> tuple[EnvelopeSnapshot, BudgetReservation]:
    validate_budget_snapshot(envelope.budget)
    if reservation.state is not ReservationState.ACTIVE:
        raise GuardianKernelError("ACTIVE_RESERVATION_REQUIRED")
    if reservation.envelope_id != envelope.envelope_id:
        raise GuardianKernelError("RESERVATION_ENVELOPE_MISMATCH")
    if reservation.reserved_amount > envelope.budget.reserved:
        raise GuardianKernelError("ENVELOPE_RESERVED_UNDERFLOW")
    unused = reservation.reserved_amount - reservation.consumed_amount
    overhang, available, _ = _release_unused_under_overhang(envelope.budget, unused)
    b = envelope.budget
    envelope_after = replace(
        envelope,
        budget=BudgetSnapshot(
            ceiling=b.ceiling,
            settled=b.settled + reservation.consumed_amount,
            reserved=b.reserved - reservation.reserved_amount,
            available=available,
            overhang=overhang,
            status="OVERHANG_BLOCKED" if overhang > 0 else "ACTIVE",
        ),
        envelope_version=envelope.envelope_version + 1,
    )
    reservation_after = replace(reservation, state=ReservationState.SETTLED)
    validate_budget_snapshot(envelope_after.budget)
    return envelope_after, reservation_after


def release_reservation_unused(
    envelope: EnvelopeSnapshot,
    reservation: BudgetReservation,
    *,
    terminal_state: ReservationState = ReservationState.RELEASED,
) -> tuple[EnvelopeSnapshot, BudgetReservation]:
    validate_budget_snapshot(envelope.budget)
    if reservation.state not in (ReservationState.RESERVED, ReservationState.ACTIVE):
        raise GuardianKernelError("LIVE_RESERVATION_REQUIRED")
    if reservation.consumed_amount != 0:
        raise GuardianKernelError("RESERVATION_HAS_UNSETTLED_CONSUMPTION")
    if terminal_state not in (
        ReservationState.RELEASED,
        ReservationState.CANCELLED,
        ReservationState.EXPIRED,
        ReservationState.FAILED,
    ):
        raise GuardianKernelError("INVALID_RESERVATION_TERMINAL_STATE")
    if reservation.reserved_amount > envelope.budget.reserved:
        raise GuardianKernelError("ENVELOPE_RESERVED_UNDERFLOW")
    overhang, available, _ = _release_unused_under_overhang(envelope.budget, reservation.reserved_amount)
    b = envelope.budget
    envelope_after = replace(
        envelope,
        budget=BudgetSnapshot(
            ceiling=b.ceiling,
            settled=b.settled,
            reserved=b.reserved - reservation.reserved_amount,
            available=available,
            overhang=overhang,
            status="OVERHANG_BLOCKED" if overhang > 0 else "ACTIVE",
        ),
        envelope_version=envelope.envelope_version + 1,
    )
    validate_budget_snapshot(envelope_after.budget)
    return envelope_after, replace(reservation, state=terminal_state)


class LockMode(str, Enum):
    READ = "READ"
    WRITE = "WRITE"
    EXCLUSIVE = "EXCLUSIVE"


class CapacityLeaseState(str, Enum):
    REQUESTED = "REQUESTED"
    GRANTED = "GRANTED"
    ACTIVE = "ACTIVE"
    RELEASED = "RELEASED"
    EXPIRED = "EXPIRED"
    FENCED = "FENCED"
    FAILED = "FAILED"


@dataclass(frozen=True)
class ResourceRequest:
    resource_key: str
    resource_kind: str
    lock_mode: LockMode

    @property
    def global_order_key(self) -> str:
        return f"{self.resource_kind}:{self.resource_key}"


@dataclass(frozen=True)
class CapacityLease:
    capacity_lease_id: str
    assignment_id: str
    society_id: str
    project_id: str
    resource_key: str
    resource_kind: str
    lock_mode: LockMode
    global_order_key: str
    state: CapacityLeaseState
    guardian_epoch: int
    fencing_token: int
    expires_at: datetime


def _conflicts(request: ResourceRequest, existing: CapacityLease, assignment_id: str, now: datetime) -> bool:
    if existing.assignment_id == assignment_id:
        return False
    if existing.state not in (CapacityLeaseState.GRANTED, CapacityLeaseState.ACTIVE):
        return False
    if now >= existing.expires_at:
        return False
    if existing.resource_key != request.resource_key or existing.resource_kind != request.resource_kind:
        return False
    # Conservative v0.1 matrix: only READ/READ is shared. Any writer conflicts.
    return not (existing.lock_mode is LockMode.READ and request.lock_mode is LockMode.READ)


def grant_resource_set(
    *,
    assignment_id: str,
    society_id: str,
    project_id: str,
    requests: Iterable[ResourceRequest],
    existing_leases: Iterable[CapacityLease],
    guardian_epoch: int,
    fencing_token: int,
    expires_at: datetime,
    now: datetime,
) -> tuple[CapacityLease, ...]:
    reqs = sorted(tuple(requests), key=lambda r: r.global_order_key)
    if not reqs:
        raise GuardianKernelError("RESOURCE_SET_REQUIRED")
    if len({r.global_order_key for r in reqs}) != len(reqs):
        raise GuardianKernelError("DUPLICATE_RESOURCE_REQUEST")
    existing = tuple(existing_leases)
    for req in reqs:
        if any(_conflicts(req, lease, assignment_id, now) for lease in existing):
            raise GuardianKernelError("RESOURCE_SET_CONFLICT", resource=req.global_order_key)
    # Function is pure: no partial lease list is returned on any conflict.
    return tuple(
        CapacityLease(
            capacity_lease_id=f"cap:{assignment_id}:{i+1}:{req.global_order_key}",
            assignment_id=assignment_id,
            society_id=society_id,
            project_id=project_id,
            resource_key=req.resource_key,
            resource_kind=req.resource_kind,
            lock_mode=req.lock_mode,
            global_order_key=req.global_order_key,
            state=CapacityLeaseState.GRANTED,
            guardian_epoch=guardian_epoch,
            fencing_token=fencing_token,
            expires_at=expires_at,
        )
        for i, req in enumerate(reqs)
    )


def activate_capacity_lease(lease: CapacityLease, *, now: datetime) -> CapacityLease:
    if lease.state is not CapacityLeaseState.GRANTED:
        raise GuardianKernelError("GRANTED_CAPACITY_LEASE_REQUIRED")
    if now >= lease.expires_at:
        raise GuardianKernelError("CAPACITY_LEASE_EXPIRED")
    return replace(lease, state=CapacityLeaseState.ACTIVE)


class QuarantineState(str, Enum):
    ACTIVE = "ACTIVE"
    LIFTED = "LIFTED"
    EXPIRED = "EXPIRED"


@dataclass(frozen=True)
class SoftQuarantine:
    quarantine_id: str
    subject_type: str
    subject_id: str
    society_id: str
    project_id: str | None
    failure_class: FailureClass
    mode: QuarantineMode
    state: QuarantineState
    renewal_count: int
    expires_at: datetime


def create_soft_quarantine(
    *,
    quarantine_id: str,
    subject_type: str,
    subject_id: str,
    society_id: str,
    project_id: str | None,
    failure_class: FailureClass | str,
    expires_at: datetime,
    now: datetime,
) -> SoftQuarantine:
    if now >= expires_at:
        raise GuardianKernelError("QUARANTINE_TTL_REQUIRED")
    failure = FailureClass(failure_class)
    return SoftQuarantine(
        quarantine_id=quarantine_id,
        subject_type=subject_type,
        subject_id=subject_id,
        society_id=society_id,
        project_id=project_id,
        failure_class=failure,
        mode=quarantine_mode(failure),
        state=QuarantineState.ACTIVE,
        renewal_count=0,
        expires_at=expires_at,
    )


def renew_soft_quarantine(
    quarantine: SoftQuarantine,
    *,
    new_expires_at: datetime,
    max_renewals: int,
    now: datetime,
) -> SoftQuarantine:
    if quarantine.state is not QuarantineState.ACTIVE:
        raise GuardianKernelError("ACTIVE_QUARANTINE_REQUIRED")
    if quarantine.renewal_count >= max_renewals:
        raise GuardianKernelError("QUARANTINE_RENEWAL_LIMIT_REACHED")
    if new_expires_at <= now:
        raise GuardianKernelError("QUARANTINE_TTL_REQUIRED")
    return replace(
        quarantine,
        renewal_count=quarantine.renewal_count + 1,
        expires_at=new_expires_at,
    )


def operations_allowed_under_quarantine(quarantine: SoftQuarantine, *, now: datetime) -> frozenset[str]:
    if quarantine.state is not QuarantineState.ACTIVE or now >= quarantine.expires_at:
        return frozenset({"READ", "WRITE_CURRENT_SCOPE", "NEW_DISPATCH", "RESOURCE_ACQUIRE"})
    if quarantine.mode is QuarantineMode.IMMEDIATE:
        return frozenset({"READ", "HANDOFF"})
    return frozenset({"READ", "WRITE_CURRENT_SCOPE", "HANDOFF"})
