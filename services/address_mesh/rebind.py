from __future__ import annotations

from dataclasses import dataclass
from typing import Iterable

from .indexer import SymbolDescriptor, descriptor_to_card
from .model import AddressCard, AddressMeshError


@dataclass(frozen=True)
class AddressAlias:
    alias_address: str
    entity_id: str
    alias_kind: str
    source_ref: str

    def __post_init__(self) -> None:
        if not self.alias_address.startswith("w8://"):
            raise AddressMeshError("INVALID_ALIAS_ADDRESS")
        if self.alias_kind not in {"PREVIOUS_ADDRESS", "HUMAN_ALIAS", "IMPORT_ALIAS"}:
            raise AddressMeshError("INVALID_ALIAS_KIND")
        if not self.source_ref.strip():
            raise AddressMeshError("ALIAS_SOURCE_REF_REQUIRED")


@dataclass(frozen=True)
class RebindDecision:
    entity_id: str
    previous_address: str
    new_card: AddressCard
    alias: AddressAlias
    evidence_refs: tuple[str, ...]


def explicit_rebind(
    *,
    previous_card: AddressCard,
    new_descriptor: SymbolDescriptor,
    world_id: str,
    society_id: str,
    project_id: str,
    artifact_id: str,
    module_name: str,
    source_ref: str,
    evidence_refs: Iterable[str],
    allow_cross_artifact: bool = False,
) -> RebindDecision:
    """Explicitly preserve identity across a rename/move.

    No fuzzy matching, signature similarity, path proximity, or LLM guess may call this
    automatically. A caller must cite an explicit source_ref and at least one evidence ref.
    """
    if not source_ref.strip():
        raise AddressMeshError("REBIND_SOURCE_REF_REQUIRED")
    evidence = tuple(sorted({ref.strip() for ref in evidence_refs if ref.strip()}))
    if not evidence:
        raise AddressMeshError("REBIND_EVIDENCE_REQUIRED")
    if previous_card.entity_kind != new_descriptor.entity_kind:
        raise AddressMeshError(
            "REBIND_KIND_CHANGE_FORBIDDEN",
            previous_kind=previous_card.entity_kind.value,
            new_kind=new_descriptor.entity_kind.value,
        )
    if previous_card.artifact_id and previous_card.artifact_id != artifact_id and not allow_cross_artifact:
        raise AddressMeshError("CROSS_ARTIFACT_REBIND_REQUIRES_EXPLICIT_GOVERNED_OVERRIDE")

    candidate = descriptor_to_card(
        new_descriptor,
        world_id=world_id,
        society_id=society_id,
        project_id=project_id,
        artifact_id=artifact_id,
        module_name=module_name,
    )
    if candidate.canonical_address == previous_card.canonical_address:
        raise AddressMeshError("REBIND_ADDRESS_UNCHANGED")

    new_card = AddressCard(
        entity_id=previous_card.entity_id,
        entity_kind=previous_card.entity_kind,
        canonical_address=candidate.canonical_address,
        world_id=world_id,
        society_id=society_id,
        project_id=project_id,
        artifact_id=artifact_id,
        authoritative_ref_kind=candidate.authoritative_ref_kind,
        authoritative_ref=candidate.authoritative_ref,
        owner_ref=previous_card.owner_ref,
        role_refs=previous_card.role_refs,
        tags=candidate.tags,
        revision=previous_card.revision + 1,
    )
    alias = AddressAlias(
        alias_address=previous_card.canonical_address,
        entity_id=previous_card.entity_id,
        alias_kind="PREVIOUS_ADDRESS",
        source_ref=source_ref,
    )
    return RebindDecision(
        entity_id=previous_card.entity_id,
        previous_address=previous_card.canonical_address,
        new_card=new_card,
        alias=alias,
        evidence_refs=evidence,
    )


def reject_implicit_rebind(*, reason: str = "") -> None:
    """Marker used by index/reconciliation callers when identity continuity is ambiguous."""
    raise AddressMeshError("IMPLICIT_SYMBOL_REBIND_FORBIDDEN", reason=reason)
