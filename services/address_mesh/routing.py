from __future__ import annotations

from dataclasses import dataclass, field
from enum import Enum
import hashlib
from typing import Iterable

from .model import AddressCard, AddressMeshError
from .selector import matches, validate_selector


class DeliveryMode(str, Enum):
    INBOX = "INBOX"
    ATTENTION = "ATTENTION"
    GUARDIAN_CONTEXT = "GUARDIAN_CONTEXT"
    MASON_PREFLIGHT = "MASON_PREFLIGHT"


class Priority(str, Enum):
    LOW = "LOW"
    NORMAL = "NORMAL"
    HIGH = "HIGH"
    CRITICAL = "CRITICAL"


_PRIORITY_RANK = {
    Priority.LOW: 10,
    Priority.NORMAL: 20,
    Priority.HIGH: 30,
    Priority.CRITICAL: 40,
}


@dataclass(frozen=True)
class Subscription:
    subscription_id: str
    subscriber_ref: str
    selector: dict
    event_kinds: tuple[str, ...]
    minimum_priority: Priority = Priority.NORMAL
    delivery_mode: DeliveryMode = DeliveryMode.INBOX
    status: str = "ACTIVE"

    def __post_init__(self) -> None:
        if not self.subscription_id.strip() or not self.subscriber_ref.strip():
            raise AddressMeshError("SUBSCRIPTION_IDENTITY_REQUIRED")
        validate_selector(self.selector)
        if not self.event_kinds:
            raise AddressMeshError("SUBSCRIPTION_EVENT_KINDS_REQUIRED")
        normalized_events = tuple(sorted({event.strip().upper() for event in self.event_kinds if event.strip()}))
        if not normalized_events:
            raise AddressMeshError("SUBSCRIPTION_EVENT_KINDS_REQUIRED")
        object.__setattr__(self, "event_kinds", normalized_events)
        if self.status not in {"ACTIVE", "SUSPENDED", "RETIRED"}:
            raise AddressMeshError("INVALID_SUBSCRIPTION_STATUS")


@dataclass(frozen=True)
class RoutingEvent:
    source_kind: str
    source_ref: str
    event_kind: str
    priority: Priority
    affected_entity_ids: tuple[str, ...] = field(default_factory=tuple)
    affected_tags: tuple[str, ...] = field(default_factory=tuple)
    metadata: dict = field(default_factory=dict)

    def __post_init__(self) -> None:
        if not self.source_kind.strip() or not self.source_ref.strip() or not self.event_kind.strip():
            raise AddressMeshError("ROUTING_EVENT_SOURCE_REQUIRED")
        object.__setattr__(self, "event_kind", self.event_kind.strip().upper())
        object.__setattr__(self, "affected_entity_ids", tuple(sorted(set(self.affected_entity_ids))))
        object.__setattr__(self, "affected_tags", tuple(sorted({tag.upper() for tag in self.affected_tags})))


@dataclass(frozen=True)
class DeliveryMatch:
    delivery_receipt_id: str
    subscriber_ref: str
    subscription_id: str
    source_kind: str
    source_ref: str
    event_kind: str
    delivery_mode: DeliveryMode
    matched_entity_ids: tuple[str, ...]


def _priority_at_least(actual: Priority, minimum: Priority) -> bool:
    return _PRIORITY_RANK[actual] >= _PRIORITY_RANK[minimum]


def _receipt_id(subscription_id: str, source_kind: str, source_ref: str, matched_ids: Iterable[str]) -> str:
    material = "|".join(
        [subscription_id, source_kind, source_ref, ",".join(sorted(set(matched_ids)))]
    )
    return "delivery-" + hashlib.sha256(material.encode()).hexdigest()[:32]


def resolve_subscription(
    *,
    subscription: Subscription,
    event: RoutingEvent,
    cards: Iterable[AddressCard],
) -> DeliveryMatch | None:
    if subscription.status != "ACTIVE":
        return None
    if event.event_kind not in subscription.event_kinds and "*" not in subscription.event_kinds:
        return None
    if not _priority_at_least(event.priority, subscription.minimum_priority):
        return None

    affected_ids = set(event.affected_entity_ids)
    affected_tags = set(event.affected_tags)
    matching: list[str] = []

    for card in cards:
        directly_affected = card.entity_id in affected_ids
        tag_affected = bool(affected_tags & set(card.tags))
        if (directly_affected or tag_affected) and matches(card, subscription.selector):
            matching.append(card.entity_id)

    if not matching:
        return None

    matched_ids = tuple(sorted(set(matching)))
    return DeliveryMatch(
        delivery_receipt_id=_receipt_id(
            subscription.subscription_id,
            event.source_kind,
            event.source_ref,
            matched_ids,
        ),
        subscriber_ref=subscription.subscriber_ref,
        subscription_id=subscription.subscription_id,
        source_kind=event.source_kind,
        source_ref=event.source_ref,
        event_kind=event.event_kind,
        delivery_mode=subscription.delivery_mode,
        matched_entity_ids=matched_ids,
    )


def resolve_subscriptions(
    *,
    subscriptions: Iterable[Subscription],
    event: RoutingEvent,
    cards: Iterable[AddressCard],
) -> list[DeliveryMatch]:
    card_list = list(cards)
    matches_out = [
        match
        for subscription in subscriptions
        if (match := resolve_subscription(subscription=subscription, event=event, cards=card_list)) is not None
    ]
    return sorted(matches_out, key=lambda item: (item.subscriber_ref, item.subscription_id))


def message_target_matches(card: AddressCard, target: dict) -> bool:
    """Resolve one message routing target without creating a duplicate message truth row."""
    target_type = str(target.get("type", "")).upper()
    if target_type == "ENTITY_ID":
        return card.entity_id == target.get("entity_id")
    if target_type == "ADDRESS":
        address = target.get("address")
        return card.canonical_address == address
    if target_type == "TAG":
        return str(target.get("tag", "")).upper() in set(card.tags)
    if target_type == "ROLE":
        return str(target.get("role_ref", "")) in set(card.role_refs)
    if target_type == "ARTIFACT_TREE":
        artifact_id = str(target.get("artifact_id", ""))
        return card.artifact_id == artifact_id
    if target_type == "SELECTOR":
        selector = target.get("selector")
        if not isinstance(selector, dict):
            raise AddressMeshError("MESSAGE_SELECTOR_OBJECT_REQUIRED")
        return matches(card, selector)
    raise AddressMeshError("UNKNOWN_MESSAGE_TARGET_TYPE", target_type=target_type)
