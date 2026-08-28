from __future__ import annotations
from dataclasses import dataclass, field
from enum import Enum
import hashlib
from typing import Iterable, Mapping

from .hierarchy import RoleBinding, RoleKind, RoleHierarchyError, subtree, immediate_supervisor


class LabelMessageError(ValueError):
    def __init__(self, code: str, **details: object) -> None:
        super().__init__(code); self.code=code; self.details=details


class LabelEventKind(str, Enum):
    ATTACH='ATTACH'; DETACH='DETACH'


@dataclass(frozen=True)
class LabelEvent:
    event_id: str
    entity_id: str
    label_key: str
    event_kind: LabelEventKind | str
    actor_binding_id: str
    source_ref: str
    sequence: int
    authority_effect: str='NONE'
    def __post_init__(self):
        object.__setattr__(self,'event_kind',LabelEventKind(self.event_kind))
        label=self.label_key.strip().upper().replace(' ','_')
        if not label: raise LabelMessageError('LABEL_REQUIRED')
        object.__setattr__(self,'label_key',label)
        if self.sequence < 1: raise LabelMessageError('LABEL_EVENT_SEQUENCE_INVALID')
        if self.authority_effect!='NONE': raise LabelMessageError('LABEL_AUTHORITY_EFFECT_FORBIDDEN')
        if not self.entity_id.strip() or not self.actor_binding_id.strip() or not self.source_ref.strip():
            raise LabelMessageError('LABEL_EVENT_IDENTITY_REQUIRED')


def project_labels(events: Iterable[LabelEvent]) -> tuple[str,...]:
    rows=sorted(events,key=lambda e:(e.sequence,e.event_id))
    seen_seq=set(); active=set()
    for e in rows:
        if e.sequence in seen_seq: raise LabelMessageError('DUPLICATE_LABEL_EVENT_SEQUENCE')
        seen_seq.add(e.sequence)
        if e.event_kind is LabelEventKind.ATTACH: active.add(e.label_key)
        else: active.discard(e.label_key)
    return tuple(sorted(active))


class RoleTargetType(str, Enum):
    ACTOR='ACTOR'
    ROLE_BINDING='ROLE_BINDING'
    ROLE_KIND='ROLE_KIND'
    SUBTREE='SUBTREE'
    SUPERVISOR='SUPERVISOR'


@dataclass(frozen=True)
class RoleMessageTarget:
    target_type: RoleTargetType | str
    target_ref: str
    scope_ref: str|None=None
    def __post_init__(self):
        object.__setattr__(self,'target_type',RoleTargetType(self.target_type))
        if not self.target_ref.strip(): raise LabelMessageError('ROLE_MESSAGE_TARGET_REF_REQUIRED')


@dataclass(frozen=True)
class AddressMessageTarget:
    target_type: str
    target_ref: str
    def __post_init__(self):
        t=self.target_type.strip().upper()
        if t not in {'ENTITY_ID','ADDRESS','TAG','ARTIFACT_TREE','SELECTOR'}:
            raise LabelMessageError('INVALID_ADDRESS_MESSAGE_TARGET')
        object.__setattr__(self,'target_type',t)
        if not self.target_ref.strip(): raise LabelMessageError('ADDRESS_MESSAGE_TARGET_REF_REQUIRED')


@dataclass(frozen=True)
class MessageEnvelope:
    message_id: str
    sender_actor_ref: str
    sender_binding_id: str|None
    message_class: str
    role_targets: tuple[RoleMessageTarget,...]=field(default_factory=tuple)
    address_targets: tuple[AddressMessageTarget,...]=field(default_factory=tuple)
    linked_work_refs: tuple[str,...]=field(default_factory=tuple)
    authority_effect: str='NONE'
    def __post_init__(self):
        if not self.message_id.strip() or not self.sender_actor_ref.strip():
            raise LabelMessageError('MESSAGE_IDENTITY_REQUIRED')
        if not self.role_targets and not self.address_targets:
            raise LabelMessageError('MESSAGE_TARGET_REQUIRED')
        if self.authority_effect!='NONE': raise LabelMessageError('MESSAGE_AUTHORITY_EFFECT_FORBIDDEN')


def resolve_role_target(
    target: RoleMessageTarget,
    *,
    sender_binding: RoleBinding|None,
    bindings: Mapping[str,RoleBinding],
) -> tuple[str,...]:
    active={k:v for k,v in bindings.items() if v.status=='ACTIVE'}
    if target.target_type is RoleTargetType.ACTOR:
        return (target.target_ref,)
    if target.target_type is RoleTargetType.ROLE_BINDING:
        b=active.get(target.target_ref)
        return () if b is None else (b.actor_id,)
    if target.target_type is RoleTargetType.ROLE_KIND:
        kind=RoleKind(target.target_ref)
        return tuple(sorted({b.actor_id for b in active.values() if b.role_kind is kind and (target.scope_ref is None or b.scope_ref==target.scope_ref)}))
    if target.target_type is RoleTargetType.SUBTREE:
        if target.target_ref not in active: return ()
        ids=subtree(target.target_ref,active.values())
        return tuple(sorted({active[i].actor_id for i in ids if i in active}))
    if target.target_type is RoleTargetType.SUPERVISOR:
        if sender_binding is None: return ()
        sup=immediate_supervisor(sender_binding,active)
        return () if sup is None else (sup.actor_id,)
    return ()


def resolve_role_recipients(message: MessageEnvelope, bindings: Iterable[RoleBinding]) -> tuple[str,...]:
    by={b.binding_id:b for b in bindings}
    sender=by.get(message.sender_binding_id or '')
    out=set()
    for target in message.role_targets:
        out.update(resolve_role_target(target,sender_binding=sender,bindings=by))
    return tuple(sorted(out))


def deterministic_message_id(sender_ref: str, idempotency_key: str, body_hash: str) -> str:
    material='|'.join([sender_ref.strip(),idempotency_key.strip(),body_hash.strip()])
    return 'msg-'+hashlib.sha256(material.encode()).hexdigest()[:32]
