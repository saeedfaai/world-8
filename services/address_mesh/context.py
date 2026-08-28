from __future__ import annotations

from dataclasses import dataclass, field
from typing import Iterable

from .model import AddressCard
from .routing import Subscription, message_target_matches


@dataclass(frozen=True)
class MessageRecord:
    message_id: str
    sender_ref: str
    direct_recipient_refs: tuple[str, ...]
    state: str
    priority: str
    targets: tuple[dict, ...] = field(default_factory=tuple)
    linked_refs: tuple[object, ...] = field(default_factory=tuple)


@dataclass(frozen=True)
class DiagnosticRecord:
    diagnostic_ref: str
    tags: tuple[str, ...]
    entity_ids: tuple[str, ...] = field(default_factory=tuple)
    state: str = "OPEN"
    severity: str = "NORMAL"


@dataclass(frozen=True)
class AddressContextBundle:
    entity_id: str
    actor_ref: str
    direct_message_ids: tuple[str, ...]
    targeted_message_ids: tuple[str, ...]
    matching_subscription_ids: tuple[str, ...]
    diagnostic_refs: tuple[str, ...]
    dependency_entity_ids: tuple[str, ...]
    dependent_entity_ids: tuple[str, ...]
    required_test_refs: tuple[str, ...]
    active_work_refs: tuple[str, ...]
    owner_ref: str | None
    role_refs: tuple[str, ...]


def _diagnostic_matches(card: AddressCard, diagnostic: DiagnosticRecord) -> bool:
    if diagnostic.state not in {"OPEN", "ACTIVE", "REQUIRED"}:
        return False
    if card.entity_id in diagnostic.entity_ids:
        return True
    return bool(set(card.tags) & {tag.upper() for tag in diagnostic.tags})


def build_context_bundle(
    *,
    card: AddressCard,
    actor_ref: str,
    messages: Iterable[MessageRecord] = (),
    subscriptions: Iterable[Subscription] = (),
    diagnostics: Iterable[DiagnosticRecord] = (),
    dependency_entity_ids: Iterable[str] = (),
    dependent_entity_ids: Iterable[str] = (),
    required_test_refs: Iterable[str] = (),
    active_work_refs: Iterable[str] = (),
) -> AddressContextBundle:
    direct: set[str] = set()
    targeted: set[str] = set()

    for message in messages:
        if message.state in {"RESOLVED", "SUPERSEDED"}:
            continue
        if actor_ref in message.direct_recipient_refs:
            direct.add(message.message_id)
        if any(message_target_matches(card, target) for target in message.targets):
            targeted.add(message.message_id)

    matching_subscriptions = {
        sub.subscription_id
        for sub in subscriptions
        if sub.status == "ACTIVE" and message_target_matches(
            card,
            {"type": "SELECTOR", "selector": sub.selector},
        )
    }

    diagnostic_refs = {
        diagnostic.diagnostic_ref
        for diagnostic in diagnostics
        if _diagnostic_matches(card, diagnostic)
    }

    return AddressContextBundle(
        entity_id=card.entity_id,
        actor_ref=actor_ref,
        direct_message_ids=tuple(sorted(direct)),
        targeted_message_ids=tuple(sorted(targeted)),
        matching_subscription_ids=tuple(sorted(matching_subscriptions)),
        diagnostic_refs=tuple(sorted(diagnostic_refs)),
        dependency_entity_ids=tuple(sorted(set(dependency_entity_ids))),
        dependent_entity_ids=tuple(sorted(set(dependent_entity_ids))),
        required_test_refs=tuple(sorted(set(required_test_refs))),
        active_work_refs=tuple(sorted(set(active_work_refs))),
        owner_ref=card.owner_ref,
        role_refs=card.role_refs,
    )
