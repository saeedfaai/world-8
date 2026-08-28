from __future__ import annotations

from dataclasses import dataclass
from typing import Mapping

from .model import AddressMeshError
from .routing import DeliveryMatch, DeliveryMode, RoutingEvent


@dataclass(frozen=True)
class AttentionCommand:
    idempotency_key: str
    recipient_ref: str
    source_kind: str
    source_ref: str
    title: str
    summary: str
    priority: str
    action_kind: str
    payload_refs: tuple[object, ...]


@dataclass(frozen=True)
class ContextDeliveryCommand:
    delivery_receipt_id: str
    recipient_ref: str
    source_kind: str
    source_ref: str
    delivery_mode: DeliveryMode
    matched_entity_ids: tuple[str, ...]


def _text(metadata: Mapping[str, object], key: str, fallback: str) -> str:
    value = metadata.get(key)
    if value is None:
        return fallback
    text = str(value).strip()
    return text or fallback


def materialize_delivery(*, match: DeliveryMatch, event: RoutingEvent) -> AttentionCommand | ContextDeliveryCommand:
    if match.source_kind != event.source_kind or match.source_ref != event.source_ref:
        raise AddressMeshError("DELIVERY_SOURCE_MISMATCH")

    if match.delivery_mode is DeliveryMode.ATTENTION:
        title = _text(event.metadata, "title", f"{event.event_kind}: {event.source_ref}")
        summary = _text(event.metadata, "summary", f"Address Mesh matched {len(match.matched_entity_ids)} entity(s).")
        action_kind = _text(event.metadata, "action_kind", "ACK")
        return AttentionCommand(
            idempotency_key=match.delivery_receipt_id,
            recipient_ref=match.subscriber_ref,
            source_kind=event.source_kind,
            source_ref=event.source_ref,
            title=title,
            summary=summary,
            priority=event.priority.value,
            action_kind=action_kind,
            payload_refs=(
                {"delivery_receipt_id": match.delivery_receipt_id},
                {"subscription_id": match.subscription_id},
                {"matched_entity_ids": list(match.matched_entity_ids)},
            ),
        )

    if match.delivery_mode in {DeliveryMode.INBOX, DeliveryMode.GUARDIAN_CONTEXT, DeliveryMode.MASON_PREFLIGHT}:
        return ContextDeliveryCommand(
            delivery_receipt_id=match.delivery_receipt_id,
            recipient_ref=match.subscriber_ref,
            source_kind=event.source_kind,
            source_ref=event.source_ref,
            delivery_mode=match.delivery_mode,
            matched_entity_ids=match.matched_entity_ids,
        )

    raise AddressMeshError("UNSUPPORTED_DELIVERY_MODE", delivery_mode=match.delivery_mode.value)
