from __future__ import annotations

from fnmatch import fnmatchcase
from typing import Any

from .model import AddressCard, AddressMeshError, EntityKind, normalize_tag


_ALLOWED_KEYS = {
    "entity_id",
    "entity_kind",
    "address_exact",
    "address_prefix",
    "address_glob",
    "tags_all",
    "tags_any",
    "tags_none",
    "world_id",
    "society_id",
    "project_id",
    "artifact_id",
    "owner_ref",
    "role_ref",
    "all",
    "any",
    "not",
}


def validate_selector(selector: dict[str, Any], *, depth: int = 0) -> None:
    if depth > 12:
        raise AddressMeshError("SELECTOR_MAX_DEPTH_EXCEEDED")
    if not isinstance(selector, dict) or not selector:
        raise AddressMeshError("SELECTOR_OBJECT_REQUIRED")
    unknown = set(selector) - _ALLOWED_KEYS
    if unknown:
        raise AddressMeshError("UNKNOWN_SELECTOR_KEY", keys=sorted(unknown))

    for key in ("all", "any"):
        if key in selector:
            value = selector[key]
            if not isinstance(value, list) or not value:
                raise AddressMeshError("SELECTOR_BOOLEAN_LIST_REQUIRED", key=key)
            for child in value:
                validate_selector(child, depth=depth + 1)
    if "not" in selector:
        validate_selector(selector["not"], depth=depth + 1)

    for key in ("tags_all", "tags_any", "tags_none"):
        if key in selector:
            value = selector[key]
            if not isinstance(value, list) or not value:
                raise AddressMeshError("SELECTOR_TAG_LIST_REQUIRED", key=key)
            for tag in value:
                normalize_tag(str(tag))

    if "entity_kind" in selector:
        EntityKind(selector["entity_kind"])


def _scalar_match(actual: str | None, expected: object) -> bool:
    return actual == str(expected)


def matches(card: AddressCard, selector: dict[str, Any]) -> bool:
    validate_selector(selector)

    results: list[bool] = []

    if "entity_id" in selector:
        results.append(card.entity_id == selector["entity_id"])
    if "entity_kind" in selector:
        results.append(card.entity_kind is EntityKind(selector["entity_kind"]))
    if "address_exact" in selector:
        results.append(card.canonical_address == selector["address_exact"])
    if "address_prefix" in selector:
        prefix = str(selector["address_prefix"])
        results.append(card.canonical_address.startswith(prefix))
    if "address_glob" in selector:
        results.append(fnmatchcase(card.canonical_address, str(selector["address_glob"])))
    if "world_id" in selector:
        results.append(_scalar_match(card.world_id, selector["world_id"]))
    if "society_id" in selector:
        results.append(_scalar_match(card.society_id, selector["society_id"]))
    if "project_id" in selector:
        results.append(_scalar_match(card.project_id, selector["project_id"]))
    if "artifact_id" in selector:
        results.append(_scalar_match(card.artifact_id, selector["artifact_id"]))
    if "owner_ref" in selector:
        results.append(_scalar_match(card.owner_ref, selector["owner_ref"]))
    if "role_ref" in selector:
        results.append(str(selector["role_ref"]) in card.role_refs)

    card_tags = set(card.tags)
    if "tags_all" in selector:
        results.append({normalize_tag(str(t)) for t in selector["tags_all"]}.issubset(card_tags))
    if "tags_any" in selector:
        results.append(bool({normalize_tag(str(t)) for t in selector["tags_any"]} & card_tags))
    if "tags_none" in selector:
        results.append(not ({normalize_tag(str(t)) for t in selector["tags_none"]} & card_tags))

    if "all" in selector:
        results.append(all(matches(card, child) for child in selector["all"]))
    if "any" in selector:
        results.append(any(matches(card, child) for child in selector["any"]))
    if "not" in selector:
        results.append(not matches(card, selector["not"]))

    return all(results)


def resolve(cards: list[AddressCard], selector: dict[str, Any]) -> list[AddressCard]:
    validate_selector(selector)
    return sorted((card for card in cards if matches(card, selector)), key=lambda c: c.entity_id)
