from __future__ import annotations

from collections.abc import Iterable

from .model import normalize_tag
from .routing import Priority, RoutingEvent


def _tags(values: Iterable[str]) -> tuple[str, ...]:
    return tuple(sorted({normalize_tag(value) for value in values}))


def diagnostic_event(
    *,
    incident_id: str,
    tags: Iterable[str],
    affected_entity_ids: Iterable[str] = (),
    severity: str = "HIGH",
    event_kind: str = "ERROR",
) -> RoutingEvent:
    return RoutingEvent(
        source_kind="DIAGNOSTIC_INCIDENT",
        source_ref=incident_id,
        event_kind=event_kind,
        priority=Priority(severity.upper()),
        affected_entity_ids=tuple(affected_entity_ids),
        affected_tags=_tags(tags),
    )


def github_change_event(
    *,
    commit_sha: str,
    affected_entity_ids: Iterable[str],
    tags: Iterable[str] = ("RUNTIME:GITHUB", "EVENT:CHANGE"),
    priority: str = "NORMAL",
) -> RoutingEvent:
    return RoutingEvent(
        source_kind="GITHUB_COMMIT",
        source_ref=commit_sha,
        event_kind="CHANGE",
        priority=Priority(priority.upper()),
        affected_entity_ids=tuple(affected_entity_ids),
        affected_tags=_tags(tags),
    )


def provider_quota_event(
    *,
    receipt_ref: str,
    provider: str,
    affected_entity_ids: Iterable[str] = (),
    exhausted: bool = True,
) -> RoutingEvent:
    provider_tag = normalize_tag(f"PROVIDER:{provider}")
    priority = Priority.CRITICAL if exhausted else Priority.HIGH
    tags = (provider_tag, "RISK:QUOTA", "EVENT:QUOTA")
    return RoutingEvent(
        source_kind="PROVIDER_CAPACITY_RECEIPT",
        source_ref=receipt_ref,
        event_kind="QUOTA",
        priority=priority,
        affected_entity_ids=tuple(affected_entity_ids),
        affected_tags=_tags(tags),
        metadata={"exhausted": exhausted, "provider": provider.upper()},
    )


def database_change_event(
    *,
    change_ref: str,
    affected_entity_ids: Iterable[str],
    database_tag: str = "RUNTIME:POSTGRES",
    schema_change: bool = True,
    priority: str = "HIGH",
) -> RoutingEvent:
    tags = [database_tag, "EVENT:CHANGE"]
    if schema_change:
        tags.extend(["RISK:SCHEMA", "LANGUAGE:SQL"])
    return RoutingEvent(
        source_kind="DATABASE_CHANGE",
        source_ref=change_ref,
        event_kind="CHANGE",
        priority=Priority(priority.upper()),
        affected_entity_ids=tuple(affected_entity_ids),
        affected_tags=_tags(tags),
        metadata={"schema_change": schema_change},
    )
