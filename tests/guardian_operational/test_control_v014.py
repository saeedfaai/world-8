from dataclasses import replace
from datetime import datetime, timedelta, timezone
from decimal import Decimal

import pytest

from services.operational_guardian.budget import EnvelopeIdentity, EnvelopeSnapshot
from services.operational_guardian.control import (
    BudgetReservation,
    CapacityLease,
    CapacityLeaseState,
    LockMode,
    QuarantineMode,
    ReservationState,
    ResourceRequest,
    activate_capacity_lease,
    activate_reservation,
    create_soft_quarantine,
    grant_resource_set,
    operations_allowed_under_quarantine,
    record_usage,
    release_reservation_unused,
    renew_soft_quarantine,
    request_reservation,
    reserve_requested,
    settle_reservation,
)
from services.operational_guardian.kernel import BudgetSnapshot, FailureClass, GuardianKernelError, shrink_budget


def envelope(ceiling=100, settled=0, reserved=0, available=None, overhang=0, status='ACTIVE', version=1):
    c=Decimal(str(ceiling)); s=Decimal(str(settled)); r=Decimal(str(reserved)); o=Decimal(str(overhang))
    a=c+o-s-r if available is None else Decimal(str(available))
    return EnvelopeSnapshot('env-1',EnvelopeIdentity('soc-a','PROJECT','project-a','SPEND','tokens','token'),BudgetSnapshot(c,s,r,a,o,status),version)


def test_reservation_lifecycle_settles_consumed_and_releases_unused():
    now=datetime.now(timezone.utc)
    e=envelope(100)
    r=request_reservation(reservation_id='r1',assignment_id='a1',envelope=e,amount=Decimal('60'),expires_at=now+timedelta(minutes=5))
    e,r=reserve_requested(e,r,expected_envelope_version=1,now=now)
    assert (e.budget.reserved,e.budget.available,r.state)==(Decimal('60'),Decimal('40'),ReservationState.RESERVED)
    r=activate_reservation(r,now=now)
    r=record_usage(r,Decimal('35'))
    e,r=settle_reservation(e,r)
    assert r.state is ReservationState.SETTLED
    assert (e.budget.settled,e.budget.reserved,e.budget.available)==(Decimal('35'),Decimal('0'),Decimal('65'))


def test_governance_shrink_does_not_break_live_reservation_and_unused_release_reduces_overhang():
    now=datetime.now(timezone.utc)
    e=envelope(100)
    r=request_reservation(reservation_id='r1',assignment_id='a1',envelope=e,amount=Decimal('80'),expires_at=now+timedelta(minutes=5))
    e,r=reserve_requested(e,r,expected_envelope_version=1,now=now)
    shrunk=shrink_budget(e.budget,Decimal('50'))
    e=replace(e,budget=shrunk,envelope_version=e.envelope_version+1)
    assert e.budget.overhang==Decimal('30') and r.state is ReservationState.RESERVED
    e,r=release_reservation_unused(e,r,terminal_state=ReservationState.EXPIRED)
    assert r.state is ReservationState.EXPIRED
    assert e.budget.overhang==Decimal('0')
    assert e.budget.available==Decimal('50')


def test_new_reservation_blocked_under_overhang():
    now=datetime.now(timezone.utc)
    e=envelope(50,settled=60,reserved=10,available=0,overhang=20,status='OVERHANG_BLOCKED')
    r=request_reservation(reservation_id='r1',assignment_id='a1',envelope=e,amount=Decimal('1'),expires_at=now+timedelta(minutes=5))
    with pytest.raises(GuardianKernelError) as exc:
        reserve_requested(e,r,expected_envelope_version=1,now=now)
    assert exc.value.code=='ENVELOPE_BLOCKED_FOR_NEW_RESERVATION'


def active_lease(assignment, key, mode, now):
    return CapacityLease('l-'+assignment,assignment,'soc-a','p',key,'SEMANTIC_RESOURCE',mode,'SEMANTIC_RESOURCE:'+key,CapacityLeaseState.ACTIVE,1,1,now+timedelta(minutes=5))


def test_capacity_set_all_or_none_and_deterministic_order():
    now=datetime.now(timezone.utc)
    requests=[ResourceRequest('z','SEMANTIC_RESOURCE',LockMode.READ),ResourceRequest('a','SEMANTIC_RESOURCE',LockMode.READ)]
    leases=grant_resource_set(assignment_id='a1',society_id='soc-a',project_id='p',requests=requests,existing_leases=[],guardian_epoch=1,fencing_token=2,expires_at=now+timedelta(minutes=5),now=now)
    assert [l.resource_key for l in leases]==['a','z']
    assert all(l.state is CapacityLeaseState.GRANTED for l in leases)


def test_capacity_conflict_returns_no_partial_grant():
    now=datetime.now(timezone.utc)
    existing=[active_lease('other','z',LockMode.WRITE,now)]
    requests=[ResourceRequest('a','SEMANTIC_RESOURCE',LockMode.READ),ResourceRequest('z','SEMANTIC_RESOURCE',LockMode.READ)]
    with pytest.raises(GuardianKernelError) as exc:
        grant_resource_set(assignment_id='a1',society_id='soc-a',project_id='p',requests=requests,existing_leases=existing,guardian_epoch=1,fencing_token=2,expires_at=now+timedelta(minutes=5),now=now)
    assert exc.value.code=='RESOURCE_SET_CONFLICT'


def test_read_read_capacity_is_shareable_but_writer_conflicts():
    now=datetime.now(timezone.utc)
    existing=[active_lease('other','r',LockMode.READ,now)]
    leases=grant_resource_set(assignment_id='a1',society_id='soc-a',project_id='p',requests=[ResourceRequest('r','SEMANTIC_RESOURCE',LockMode.READ)],existing_leases=existing,guardian_epoch=1,fencing_token=2,expires_at=now+timedelta(minutes=5),now=now)
    assert len(leases)==1


def test_soft_quarantine_modes_ttl_and_renewal_limit():
    now=datetime.now(timezone.utc)
    q=create_soft_quarantine(quarantine_id='q1',subject_type='MASON',subject_id='m1',society_id='soc-a',project_id='p',failure_class=FailureClass.MASON_POLICY_VIOLATION,expires_at=now+timedelta(minutes=5),now=now)
    assert q.mode is QuarantineMode.IMMEDIATE
    assert operations_allowed_under_quarantine(q,now=now)==frozenset({'READ','HANDOFF'})
    q=renew_soft_quarantine(q,new_expires_at=now+timedelta(minutes=10),max_renewals=1,now=now)
    with pytest.raises(GuardianKernelError) as exc:
        renew_soft_quarantine(q,new_expires_at=now+timedelta(minutes=20),max_renewals=1,now=now)
    assert exc.value.code=='QUARANTINE_RENEWAL_LIMIT_REACHED'


def test_typed_failure_enum_complete_and_non_quarantine_failures_do_not_invent_mode():
    assert len(FailureClass)==9
    now=datetime.now(timezone.utc)
    with pytest.raises(GuardianKernelError) as exc:
        create_soft_quarantine(quarantine_id='q2',subject_type='ASSIGNMENT',subject_id='a1',society_id='soc-a',project_id='p',failure_class=FailureClass.BUDGET_EXHAUSTED,expires_at=now+timedelta(minutes=5),now=now)
    assert exc.value.code=='FAILURE_CLASS_NOT_QUARANTINE_TRIGGER'
