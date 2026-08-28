from __future__ import annotations

from dataclasses import dataclass, replace
from decimal import Decimal
from enum import Enum

from .kernel import BudgetSnapshot, GuardianKernelError, validate_budget_snapshot


class AllocationState(str, Enum):
    ACTIVE = "ACTIVE"
    CLOSED = "CLOSED"
    CANCELLED = "CANCELLED"


@dataclass(frozen=True)
class EnvelopeIdentity:
    society_id: str
    scope_kind: str
    scope_ref: str
    dimension_class: str
    dimension_key: str
    unit: str


@dataclass(frozen=True)
class EnvelopeSnapshot:
    envelope_id: str
    identity: EnvelopeIdentity
    budget: BudgetSnapshot
    envelope_version: int


@dataclass(frozen=True)
class EnvelopeAllocation:
    allocation_id: str
    parent_envelope_id: str
    child_envelope_id: str
    society_id: str
    dimension_class: str
    dimension_key: str
    unit: str
    allocated_amount: Decimal
    reclaimed_amount: Decimal
    finalized_spend_amount: Decimal
    remaining_encumbered: Decimal
    state: AllocationState
    parent_envelope_version_at_allocate: int


def _positive(amount: Decimal, code: str) -> None:
    if amount <= 0:
        raise GuardianKernelError(code)


def validate_allocation(allocation: EnvelopeAllocation) -> None:
    if allocation.allocated_amount <= 0:
        raise GuardianKernelError("ALLOCATION_AMOUNT_MUST_BE_POSITIVE")
    if min(
        allocation.reclaimed_amount,
        allocation.finalized_spend_amount,
        allocation.remaining_encumbered,
    ) < 0:
        raise GuardianKernelError("NEGATIVE_ALLOCATION_COMPONENT")
    if allocation.allocated_amount != (
        allocation.reclaimed_amount
        + allocation.finalized_spend_amount
        + allocation.remaining_encumbered
    ):
        raise GuardianKernelError("ALLOCATION_ACCOUNTING_INVARIANT_BROKEN")
    if allocation.state is AllocationState.CLOSED and allocation.remaining_encumbered != 0:
        raise GuardianKernelError("CLOSED_ALLOCATION_HAS_REMAINING_ENCUMBRANCE")


def _validate_pair(parent: EnvelopeSnapshot, child: EnvelopeSnapshot) -> None:
    p = parent.identity
    c = child.identity
    if p.society_id != c.society_id:
        raise GuardianKernelError("CROSS_SOCIETY_ENVELOPE_ALLOCATION_FORBIDDEN")
    if (p.dimension_class, p.dimension_key, p.unit) != (
        c.dimension_class,
        c.dimension_key,
        c.unit,
    ):
        raise GuardianKernelError("ENVELOPE_DIMENSION_OR_UNIT_MISMATCH")


def allocate_child(
    parent: EnvelopeSnapshot,
    child: EnvelopeSnapshot,
    *,
    allocation_id: str,
    amount: Decimal,
) -> tuple[EnvelopeSnapshot, EnvelopeSnapshot, EnvelopeAllocation]:
    _positive(amount, "ALLOCATION_AMOUNT_MUST_BE_POSITIVE")
    _validate_pair(parent, child)
    validate_budget_snapshot(parent.budget)
    validate_budget_snapshot(child.budget)
    if parent.budget.status != "ACTIVE" or parent.budget.overhang > 0:
        raise GuardianKernelError("PARENT_ENVELOPE_NOT_ALLOCATABLE")
    if amount > parent.budget.available:
        raise GuardianKernelError("PARENT_ENVELOPE_AVAILABLE_EXCEEDED")

    pb = parent.budget
    cb = child.budget
    parent_after = replace(
        parent,
        budget=BudgetSnapshot(
            ceiling=pb.ceiling,
            settled=pb.settled,
            reserved=pb.reserved + amount,
            available=pb.available - amount,
            overhang=pb.overhang,
            status=pb.status,
        ),
        envelope_version=parent.envelope_version + 1,
    )
    child_after = replace(
        child,
        budget=BudgetSnapshot(
            ceiling=cb.ceiling + amount,
            settled=cb.settled,
            reserved=cb.reserved,
            available=cb.available + amount,
            overhang=cb.overhang,
            status=cb.status,
        ),
        envelope_version=child.envelope_version + 1,
    )
    allocation = EnvelopeAllocation(
        allocation_id=allocation_id,
        parent_envelope_id=parent.envelope_id,
        child_envelope_id=child.envelope_id,
        society_id=parent.identity.society_id,
        dimension_class=parent.identity.dimension_class,
        dimension_key=parent.identity.dimension_key,
        unit=parent.identity.unit,
        allocated_amount=amount,
        reclaimed_amount=Decimal("0"),
        finalized_spend_amount=Decimal("0"),
        remaining_encumbered=amount,
        state=AllocationState.ACTIVE,
        parent_envelope_version_at_allocate=parent.envelope_version,
    )
    validate_budget_snapshot(parent_after.budget)
    validate_budget_snapshot(child_after.budget)
    validate_allocation(allocation)
    return parent_after, child_after, allocation


def reconcile_allocation(
    parent: EnvelopeSnapshot,
    child: EnvelopeSnapshot,
    allocation: EnvelopeAllocation,
    *,
    reclaim_unused: Decimal = Decimal("0"),
    finalize_spend: Decimal = Decimal("0"),
) -> tuple[EnvelopeSnapshot, EnvelopeSnapshot, EnvelopeAllocation]:
    _validate_pair(parent, child)
    validate_budget_snapshot(parent.budget)
    validate_budget_snapshot(child.budget)
    validate_allocation(allocation)
    if allocation.state is not AllocationState.ACTIVE:
        raise GuardianKernelError("ACTIVE_ALLOCATION_REQUIRED")
    if reclaim_unused < 0 or finalize_spend < 0:
        raise GuardianKernelError("NEGATIVE_ALLOCATION_RECONCILIATION")
    delta = reclaim_unused + finalize_spend
    if delta <= 0:
        raise GuardianKernelError("ALLOCATION_RECONCILIATION_DELTA_REQUIRED")
    if delta > allocation.remaining_encumbered:
        raise GuardianKernelError("ALLOCATION_RECONCILIATION_EXCEEDS_REMAINING")
    if reclaim_unused > child.budget.available:
        raise GuardianKernelError("CHILD_UNUSED_AVAILABLE_EXCEEDED")
    if allocation.parent_envelope_id != parent.envelope_id or allocation.child_envelope_id != child.envelope_id:
        raise GuardianKernelError("ALLOCATION_ENVELOPE_BINDING_MISMATCH")

    pb = parent.budget
    cb = child.budget

    # Finalized child spend is propagated only at explicit reconciliation: parent R -> S.
    reserved_after_finalize = pb.reserved - finalize_spend
    settled_after = pb.settled + finalize_spend
    if reserved_after_finalize < 0:
        raise GuardianKernelError("PARENT_RESERVED_UNDERFLOW")

    # Unused reclaim releases parent encumbrance. Under overhang, it reduces O first;
    # only the remainder becomes parent available.
    reserved_after = reserved_after_finalize - reclaim_unused
    if reserved_after < 0:
        raise GuardianKernelError("PARENT_RESERVED_UNDERFLOW")
    overhang_reduction = min(reclaim_unused, pb.overhang)
    overhang_after = pb.overhang - overhang_reduction
    available_after = pb.available + (reclaim_unused - overhang_reduction)
    status_after = "OVERHANG_BLOCKED" if overhang_after > 0 else "ACTIVE"

    parent_after = replace(
        parent,
        budget=BudgetSnapshot(
            ceiling=pb.ceiling,
            settled=settled_after,
            reserved=reserved_after,
            available=available_after,
            overhang=overhang_after,
            status=status_after,
        ),
        envelope_version=parent.envelope_version + 1,
    )
    child_after = replace(
        child,
        budget=BudgetSnapshot(
            ceiling=cb.ceiling - reclaim_unused,
            settled=cb.settled,
            reserved=cb.reserved,
            available=cb.available - reclaim_unused,
            overhang=cb.overhang,
            status=cb.status,
        ),
        envelope_version=child.envelope_version + 1,
    )
    remaining = allocation.remaining_encumbered - delta
    allocation_after = replace(
        allocation,
        reclaimed_amount=allocation.reclaimed_amount + reclaim_unused,
        finalized_spend_amount=allocation.finalized_spend_amount + finalize_spend,
        remaining_encumbered=remaining,
        state=AllocationState.CLOSED if remaining == 0 else AllocationState.ACTIVE,
    )
    validate_budget_snapshot(parent_after.budget)
    validate_budget_snapshot(child_after.budget)
    validate_allocation(allocation_after)
    return parent_after, child_after, allocation_after
