from decimal import Decimal

import pytest

from services.operational_guardian.budget import (
    AllocationState,
    EnvelopeIdentity,
    EnvelopeSnapshot,
    allocate_child,
    reconcile_allocation,
)
from services.operational_guardian.kernel import BudgetSnapshot, GuardianKernelError


def env(eid, society, scope_kind, scope_ref, ceiling, settled=0, reserved=0, available=None, overhang=0, status='ACTIVE'):
    ceiling=Decimal(str(ceiling)); settled=Decimal(str(settled)); reserved=Decimal(str(reserved)); overhang=Decimal(str(overhang))
    if available is None:
        available=ceiling+overhang-settled-reserved
    else:
        available=Decimal(str(available))
    return EnvelopeSnapshot(
        envelope_id=eid,
        identity=EnvelopeIdentity(society,scope_kind,scope_ref,'SPEND','tokens','token'),
        budget=BudgetSnapshot(ceiling,settled,reserved,available,overhang,status),
        envelope_version=1,
    )


def test_prefund_moves_parent_available_to_reserved_and_child_available():
    parent=env('parent','soc-a','SOCIETY','soc-a',1000)
    child=env('child','soc-a','PROJECT','project-a',0)
    p,c,a=allocate_child(parent,child,allocation_id='alloc-1',amount=Decimal('300'))
    assert (p.budget.reserved,p.budget.available)==(Decimal('300'),Decimal('700'))
    assert (c.budget.ceiling,c.budget.available)==(Decimal('300'),Decimal('300'))
    assert a.remaining_encumbered==Decimal('300')


def test_cross_society_and_dimension_mismatch_rejected():
    parent=env('parent','soc-a','SOCIETY','soc-a',1000)
    child=env('child','soc-b','PROJECT','project-b',0)
    with pytest.raises(GuardianKernelError) as exc:
        allocate_child(parent,child,allocation_id='alloc-x',amount=Decimal('1'))
    assert exc.value.code=='CROSS_SOCIETY_ENVELOPE_ALLOCATION_FORBIDDEN'


def test_parent_overhang_blocks_new_child_allocation():
    parent=env('parent','soc-a','SOCIETY','soc-a',100,settled=120,reserved=10,available=0,overhang=30,status='OVERHANG_BLOCKED')
    child=env('child','soc-a','PROJECT','project-a',0)
    with pytest.raises(GuardianKernelError) as exc:
        allocate_child(parent,child,allocation_id='alloc-x',amount=Decimal('1'))
    assert exc.value.code=='PARENT_ENVELOPE_NOT_ALLOCATABLE'


def test_reconciliation_propagates_spend_only_on_explicit_boundary_and_reclaims_unused():
    parent=env('parent','soc-a','SOCIETY','soc-a',1000)
    child=env('child','soc-a','PROJECT','project-a',0)
    p,c,a=allocate_child(parent,child,allocation_id='alloc-1',amount=Decimal('300'))

    # Simulate child-local task settlement without touching the parent.
    c=EnvelopeSnapshot(c.envelope_id,c.identity,BudgetSnapshot(Decimal('300'),Decimal('100'),Decimal('0'),Decimal('200'),Decimal('0'),'ACTIVE'),c.envelope_version+1)
    assert p.budget.reserved==Decimal('300') and p.budget.settled==Decimal('0')

    p,c,a=reconcile_allocation(p,c,a,finalize_spend=Decimal('100'))
    assert (p.budget.reserved,p.budget.settled)==(Decimal('200'),Decimal('100'))
    assert a.remaining_encumbered==Decimal('200')

    p,c,a=reconcile_allocation(p,c,a,reclaim_unused=Decimal('200'))
    assert a.state is AllocationState.CLOSED
    assert (p.budget.reserved,p.budget.available,p.budget.settled)==(Decimal('0'),Decimal('900'),Decimal('100'))
    assert (c.budget.ceiling,c.budget.settled,c.budget.available)==(Decimal('100'),Decimal('100'),Decimal('0'))


def test_reconcile_cannot_exceed_remaining_or_child_unused_available():
    parent=env('parent','soc-a','SOCIETY','soc-a',1000)
    child=env('child','soc-a','PROJECT','project-a',0)
    p,c,a=allocate_child(parent,child,allocation_id='alloc-1',amount=Decimal('100'))
    with pytest.raises(GuardianKernelError) as exc:
        reconcile_allocation(p,c,a,reclaim_unused=Decimal('101'))
    assert exc.value.code=='ALLOCATION_RECONCILIATION_EXCEEDS_REMAINING'


def test_reclaim_reduces_parent_overhang_before_available():
    # Construct a valid parent snapshot after a governance shrink while allocation is encumbered.
    parent=env('parent','soc-a','SOCIETY','soc-a',50,settled=20,reserved=60,available=0,overhang=30,status='OVERHANG_BLOCKED')
    child=env('child','soc-a','PROJECT','project-a',60)
    from services.operational_guardian.budget import EnvelopeAllocation
    a=EnvelopeAllocation('alloc-1','parent','child','soc-a','SPEND','tokens','token',Decimal('60'),Decimal('0'),Decimal('0'),Decimal('60'),AllocationState.ACTIVE,1)
    p,c,a=reconcile_allocation(parent,child,a,reclaim_unused=Decimal('20'))
    assert p.budget.overhang==Decimal('10')
    assert p.budget.available==Decimal('0')
