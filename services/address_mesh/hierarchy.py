from __future__ import annotations

from dataclasses import dataclass, field
from enum import Enum
import hashlib
from typing import Iterable, Mapping


class RoleHierarchyError(ValueError):
    def __init__(self, code: str, **details: object) -> None:
        super().__init__(code)
        self.code = code
        self.details = details


class RoleKind(str, Enum):
    TOP_GUARDIAN = "TOP_GUARDIAN"
    GUARDIAN = "GUARDIAN"
    MASTER_MASON = "MASTER_MASON"
    MASON = "MASON"


_ROLE_RANK = {
    RoleKind.TOP_GUARDIAN: 40,
    RoleKind.GUARDIAN: 30,
    RoleKind.MASTER_MASON: 20,
    RoleKind.MASON: 10,
}

_NEXT_DOWN = {
    RoleKind.TOP_GUARDIAN: RoleKind.GUARDIAN,
    RoleKind.GUARDIAN: RoleKind.MASTER_MASON,
    RoleKind.MASTER_MASON: RoleKind.MASON,
}

_ALLOWED_BY_ACTOR_KIND = {
    "AI_ARCHITECT": frozenset(RoleKind),
    "AI_MASON": frozenset({RoleKind.MASTER_MASON, RoleKind.MASON}),
}


@dataclass(frozen=True)
class RoleBinding:
    binding_id: str
    actor_id: str
    actor_kind: str
    role_kind: RoleKind | str
    scope_ref: str
    parent_binding_id: str | None = None
    status: str = "ACTIVE"
    authority_effect: str = "NONE"
    metadata: dict = field(default_factory=dict)

    def __post_init__(self) -> None:
        role = RoleKind(self.role_kind)
        object.__setattr__(self, "role_kind", role)
        actor_kind = self.actor_kind.strip().upper()
        object.__setattr__(self, "actor_kind", actor_kind)
        status = self.status.strip().upper()
        object.__setattr__(self, "status", status)
        if not self.binding_id.strip() or not self.actor_id.strip() or not self.scope_ref.strip():
            raise RoleHierarchyError("ROLE_BINDING_IDENTITY_REQUIRED")
        if status not in {"ACTIVE", "SUSPENDED", "RETIRED"}:
            raise RoleHierarchyError("INVALID_ROLE_BINDING_STATUS")
        if self.authority_effect != "NONE":
            raise RoleHierarchyError("ROLE_BINDING_AUTHORITY_EFFECT_FORBIDDEN")
        allowed = _ALLOWED_BY_ACTOR_KIND.get(actor_kind, frozenset())
        if role not in allowed:
            raise RoleHierarchyError(
                "ACTOR_KIND_ROLE_NOT_ELIGIBLE", actor_kind=actor_kind, role_kind=role.value
            )
        if role is RoleKind.TOP_GUARDIAN and self.scope_ref != "WORLD":
            raise RoleHierarchyError("TOP_GUARDIAN_SCOPE_MUST_BE_WORLD")
        if role is RoleKind.TOP_GUARDIAN and self.parent_binding_id is not None:
            raise RoleHierarchyError("TOP_GUARDIAN_MUST_NOT_HAVE_PARENT")
        if role is not RoleKind.TOP_GUARDIAN and not self.parent_binding_id:
            raise RoleHierarchyError("NON_TOP_ROLE_REQUIRES_PARENT")


def validate_binding_graph(bindings: Iterable[RoleBinding]) -> None:
    by_id = {b.binding_id: b for b in bindings}
    if len(by_id) != len(tuple(bindings)):
        # bindings may be an iterator; callers should normally pass a list/tuple.
        raise RoleHierarchyError("DUPLICATE_ROLE_BINDING_ID")
    active_top = [b for b in by_id.values() if b.status == "ACTIVE" and b.role_kind is RoleKind.TOP_GUARDIAN]
    if len(active_top) > 1:
        raise RoleHierarchyError("MULTIPLE_ACTIVE_TOP_GUARDIANS_FOR_WORLD")

    expected_parent = {
        RoleKind.GUARDIAN: RoleKind.TOP_GUARDIAN,
        RoleKind.MASTER_MASON: RoleKind.GUARDIAN,
        RoleKind.MASON: RoleKind.MASTER_MASON,
    }
    for binding in by_id.values():
        if binding.role_kind is RoleKind.TOP_GUARDIAN:
            continue
        parent = by_id.get(binding.parent_binding_id or "")
        if parent is None:
            raise RoleHierarchyError("ROLE_PARENT_NOT_FOUND", binding_id=binding.binding_id)
        if parent.status != "ACTIVE" or binding.status != "ACTIVE":
            continue
        if parent.role_kind is not expected_parent[binding.role_kind]:
            raise RoleHierarchyError(
                "ROLE_PARENT_LEVEL_INVALID",
                child=binding.role_kind.value,
                parent=parent.role_kind.value,
            )
        if binding.role_kind in {RoleKind.MASTER_MASON, RoleKind.MASON}:
            if parent.scope_ref not in {"WORLD", binding.scope_ref}:
                raise RoleHierarchyError("ROLE_PARENT_SCOPE_MISMATCH")

    # explicit cycle check
    for binding in by_id.values():
        seen: set[str] = set()
        current = binding
        while current.parent_binding_id:
            if current.binding_id in seen:
                raise RoleHierarchyError("ROLE_BINDING_CYCLE")
            seen.add(current.binding_id)
            parent = by_id.get(current.parent_binding_id)
            if parent is None:
                break
            current = parent


def immediate_supervisor(binding: RoleBinding, bindings: Mapping[str, RoleBinding]) -> RoleBinding | None:
    if binding.role_kind is RoleKind.TOP_GUARDIAN:
        return None
    return bindings.get(binding.parent_binding_id or "")


def direct_reports(binding: RoleBinding, bindings: Iterable[RoleBinding]) -> tuple[RoleBinding, ...]:
    return tuple(sorted(
        (b for b in bindings if b.status == "ACTIVE" and b.parent_binding_id == binding.binding_id),
        key=lambda b: b.binding_id,
    ))


def subtree(binding_id: str, bindings: Iterable[RoleBinding]) -> tuple[str, ...]:
    rows = tuple(bindings)
    children: dict[str, list[str]] = {}
    for b in rows:
        if b.parent_binding_id:
            children.setdefault(b.parent_binding_id, []).append(b.binding_id)
    out: list[str] = []
    queue = [binding_id]
    seen: set[str] = set()
    while queue:
        current = queue.pop(0)
        if current in seen:
            raise RoleHierarchyError("ROLE_BINDING_CYCLE")
        seen.add(current)
        out.append(current)
        queue.extend(sorted(children.get(current, [])))
    return tuple(out)


@dataclass(frozen=True)
class RoleSession:
    session_id: str
    actor_id: str
    binding_id: str
    current_role: RoleKind | str
    scope_ref: str
    descent_seq: int = 0
    inherited_privileges: tuple[str, ...] = ()

    def __post_init__(self) -> None:
        object.__setattr__(self, "current_role", RoleKind(self.current_role))
        if self.inherited_privileges:
            raise RoleHierarchyError("PRIVILEGE_INHERITANCE_FORBIDDEN")
        if self.descent_seq < 0:
            raise RoleHierarchyError("INVALID_DESCENT_SEQUENCE")

    @property
    def effective_role(self) -> RoleKind:
        return self.current_role


def descend_role(session: RoleSession, target_role: RoleKind | str, *, target_binding_id: str, target_scope_ref: str) -> RoleSession:
    target = RoleKind(target_role)
    expected = _NEXT_DOWN.get(session.current_role)
    if expected is None or target is not expected:
        raise RoleHierarchyError(
            "ROLE_DESCENT_MUST_BE_ONE_LEVEL_DOWN",
            current=session.current_role.value,
            target=target.value,
        )
    return RoleSession(
        session_id=session.session_id,
        actor_id=session.actor_id,
        binding_id=target_binding_id,
        current_role=target,
        scope_ref=target_scope_ref,
        descent_seq=session.descent_seq + 1,
        inherited_privileges=(),
    )


class MessageDirection(str, Enum):
    DOWNWARD = "DOWNWARD_DIRECTIVE"
    UPWARD = "UPWARD_REPORT"
    LATERAL = "LATERAL_DISCUSSION"


def message_direction(sender: RoleBinding, recipient: RoleBinding) -> MessageDirection:
    sr = _ROLE_RANK[sender.role_kind]
    rr = _ROLE_RANK[recipient.role_kind]
    if sr > rr:
        return MessageDirection.DOWNWARD
    if sr < rr:
        return MessageDirection.UPWARD
    return MessageDirection.LATERAL


@dataclass(frozen=True)
class HierarchyMessageEnvelope:
    message_id: str
    sender_binding_id: str
    recipient_binding_id: str
    direction: MessageDirection | str
    linked_refs: tuple[str, ...] = ()
    authority_effect: str = "NONE"

    def __post_init__(self) -> None:
        object.__setattr__(self, "direction", MessageDirection(self.direction))
        if self.authority_effect != "NONE":
            raise RoleHierarchyError("MESSAGE_AUTHORITY_EFFECT_FORBIDDEN")


@dataclass(frozen=True)
class ReportEnvelope:
    report_id: str
    reporter_binding_id: str
    supervisor_binding_id: str
    source_refs: tuple[str, ...]
    summary_hash: str
    authority_effect: str = "NONE"

    @classmethod
    def build(cls, *, reporter: RoleBinding, supervisor: RoleBinding, source_refs: Iterable[str], summary: str) -> "ReportEnvelope":
        if reporter.parent_binding_id != supervisor.binding_id:
            raise RoleHierarchyError("REPORT_MUST_TARGET_IMMEDIATE_SUPERVISOR")
        refs = tuple(sorted({r.strip() for r in source_refs if r.strip()}))
        if not refs:
            raise RoleHierarchyError("REPORT_SOURCE_REFS_REQUIRED")
        digest = hashlib.sha256(summary.encode()).hexdigest()
        rid = "report-" + hashlib.sha256(
            (reporter.binding_id + "|" + supervisor.binding_id + "|" + "|".join(refs) + "|" + digest).encode()
        ).hexdigest()[:32]
        return cls(rid, reporter.binding_id, supervisor.binding_id, refs, digest)
