from __future__ import annotations

from dataclasses import dataclass, field
from enum import Enum
import hashlib
import re
from typing import Iterable
from urllib.parse import quote


class AddressMeshError(ValueError):
    def __init__(self, code: str, **details: object) -> None:
        super().__init__(code)
        self.code = code
        self.details = details


class EntityKind(str, Enum):
    WORLD = "WORLD"
    SOCIETY = "SOCIETY"
    PROJECT = "PROJECT"
    ARTIFACT = "ARTIFACT"
    MODULE = "MODULE"
    FILE = "FILE"
    SYMBOL = "SYMBOL"
    FUNCTION = "FUNCTION"
    CLASS = "CLASS"
    METHOD = "METHOD"
    RPC = "RPC"
    DB_FUNCTION = "DB_FUNCTION"
    TABLE = "TABLE"
    TEST = "TEST"
    SERVICE_ENTRYPOINT = "SERVICE_ENTRYPOINT"
    ACTOR = "ACTOR"
    ROLE = "ROLE"
    WORK = "WORK"
    WORKSPACE = "WORKSPACE"
    ASSIGNMENT = "ASSIGNMENT"
    PROVIDER = "PROVIDER"
    CHANNEL = "CHANNEL"
    DIAGNOSTIC_OBJECT = "DIAGNOSTIC_OBJECT"
    POLICY = "POLICY"
    CONTRACT = "CONTRACT"


class RelationType(str, Enum):
    CONTAINS = "CONTAINS"
    DEPENDS_ON = "DEPENDS_ON"
    CALLS = "CALLS"
    READS = "READS"
    WRITES = "WRITES"
    PUBLISHES_TO = "PUBLISHES_TO"
    SUBSCRIBES_TO = "SUBSCRIBES_TO"
    IMPLEMENTS = "IMPLEMENTS"
    TESTS = "TESTS"
    OWNS = "OWNS"
    AFFECTS = "AFFECTS"


_KIND_PREFIX: dict[EntityKind, str] = {
    EntityKind.WORLD: "WRLD",
    EntityKind.SOCIETY: "SOC",
    EntityKind.PROJECT: "PRJ",
    EntityKind.ARTIFACT: "ART",
    EntityKind.MODULE: "MOD",
    EntityKind.FILE: "FILE",
    EntityKind.SYMBOL: "SYM",
    EntityKind.FUNCTION: "FN",
    EntityKind.CLASS: "CLS",
    EntityKind.METHOD: "MTH",
    EntityKind.RPC: "RPC",
    EntityKind.DB_FUNCTION: "DBF",
    EntityKind.TABLE: "TBL",
    EntityKind.TEST: "TST",
    EntityKind.SERVICE_ENTRYPOINT: "SVC",
    EntityKind.ACTOR: "ACT",
    EntityKind.ROLE: "ROL",
    EntityKind.WORK: "WRK",
    EntityKind.WORKSPACE: "WSP",
    EntityKind.ASSIGNMENT: "ASN",
    EntityKind.PROVIDER: "PRV",
    EntityKind.CHANNEL: "CHN",
    EntityKind.DIAGNOSTIC_OBJECT: "DIA",
    EntityKind.POLICY: "POL",
    EntityKind.CONTRACT: "CTR",
}

# Namespaced tags are preferred for new Address Mesh data (e.g. RUNTIME:SUPABASE),
# but legacy Diagnostic Memory uses valid flat tags (e.g. SUPABASE, RENDER).
# Both are accepted so the new mesh cannot orphan existing diagnostics.
_TAG_RE = re.compile(r"^[A-Z][A-Z0-9_]*(?::[A-Z0-9][A-Z0-9_.:/-]*)?$")
_SEGMENT_RE = re.compile(r"^[A-Za-z0-9._~-]+$")


def require_text(name: str, value: str) -> str:
    value = value.strip()
    if not value:
        raise AddressMeshError(f"{name.upper()}_REQUIRED")
    return value


def stable_entity_id(kind: EntityKind | str, stable_key: str) -> str:
    """Return an opaque stable ID. Mutable hierarchy/role is not encoded into identity."""
    kind = EntityKind(kind)
    stable_key = require_text("stable_key", stable_key)
    digest = hashlib.sha256(f"W8-UAG-v0.1|{kind.value}|{stable_key}".encode()).hexdigest()[:20].upper()
    return f"W8-{_KIND_PREFIX[kind]}-{digest}"


def normalize_tag(tag: str) -> str:
    normalized = require_text("tag", tag).strip().upper().replace(" ", "_")
    if not _TAG_RE.fullmatch(normalized):
        raise AddressMeshError("INVALID_TAG", tag=tag)
    return normalized


def normalize_tags(tags: Iterable[str]) -> tuple[str, ...]:
    return tuple(sorted({normalize_tag(tag) for tag in tags}))


def normalize_segment(segment: str) -> str:
    segment = require_text("address_segment", segment).strip()
    if _SEGMENT_RE.fullmatch(segment):
        return segment.lower()
    return quote(segment.lower(), safe="._~-")


def semantic_address(*segments: tuple[str, str]) -> str:
    """Build w8://kind/value/kind/value... address from explicit typed segments."""
    if not segments:
        raise AddressMeshError("ADDRESS_SEGMENTS_REQUIRED")
    encoded: list[str] = []
    for key, value in segments:
        encoded.append(normalize_segment(key))
        encoded.append(normalize_segment(value))
    return "w8://" + "/".join(encoded)


@dataclass(frozen=True)
class AddressCard:
    entity_id: str
    entity_kind: EntityKind
    canonical_address: str
    world_id: str = "world-001"
    society_id: str | None = None
    project_id: str | None = None
    artifact_id: str | None = None
    authoritative_ref_kind: str | None = None
    authoritative_ref: str | None = None
    owner_ref: str | None = None
    role_refs: tuple[str, ...] = field(default_factory=tuple)
    tags: tuple[str, ...] = field(default_factory=tuple)
    revision: int = 1
    content_hash: str = ""

    def __post_init__(self) -> None:
        if not self.entity_id.startswith("W8-"):
            raise AddressMeshError("INVALID_ENTITY_ID", entity_id=self.entity_id)
        if not self.canonical_address.startswith("w8://"):
            raise AddressMeshError("INVALID_CANONICAL_ADDRESS", address=self.canonical_address)
        if self.revision < 1:
            raise AddressMeshError("INVALID_ADDRESS_REVISION")
        normalized_tags = normalize_tags(self.tags)
        object.__setattr__(self, "tags", normalized_tags)
        object.__setattr__(self, "role_refs", tuple(sorted(set(self.role_refs))))
        if not self.content_hash:
            material = "|".join(
                [
                    self.entity_id,
                    self.entity_kind.value,
                    self.canonical_address,
                    self.world_id,
                    self.society_id or "",
                    self.project_id or "",
                    self.artifact_id or "",
                    self.authoritative_ref_kind or "",
                    self.authoritative_ref or "",
                    self.owner_ref or "",
                    ",".join(self.role_refs),
                    ",".join(self.tags),
                    str(self.revision),
                ]
            )
            object.__setattr__(self, "content_hash", hashlib.sha256(material.encode()).hexdigest())


@dataclass(frozen=True)
class AddressRelation:
    source_entity_id: str
    relation_type: RelationType
    target_entity_id: str
    source_ref: str
    revision: int = 1

    def __post_init__(self) -> None:
        if self.source_entity_id == self.target_entity_id and self.relation_type in {
            RelationType.CONTAINS,
            RelationType.DEPENDS_ON,
        }:
            raise AddressMeshError("SELF_RELATION_FORBIDDEN", relation_type=self.relation_type.value)
        if self.revision < 1:
            raise AddressMeshError("INVALID_RELATION_REVISION")
        require_text("source_ref", self.source_ref)
