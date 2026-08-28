from __future__ import annotations

import ast
from dataclasses import dataclass
import hashlib
import re
from pathlib import PurePosixPath
from typing import Iterable

from .model import AddressCard, EntityKind, semantic_address, stable_entity_id


@dataclass(frozen=True)
class SymbolDescriptor:
    entity_id: str
    entity_kind: EntityKind
    qualified_name: str
    path_ref: str
    line_start: int | None
    line_end: int | None
    signature_hash: str
    tags: tuple[str, ...]


def _signature_hash(material: str) -> str:
    return hashlib.sha256(material.encode("utf-8")).hexdigest()


def _path_module(path_ref: str) -> str:
    path = PurePosixPath(path_ref)
    parts = list(path.with_suffix("").parts)
    return ".".join(parts)


def index_python(
    source: str,
    *,
    path_ref: str,
    society_id: str,
    project_id: str,
    artifact_id: str,
) -> list[SymbolDescriptor]:
    tree = ast.parse(source, filename=path_ref)
    module = _path_module(path_ref)
    output: list[SymbolDescriptor] = []

    class Visitor(ast.NodeVisitor):
        def __init__(self) -> None:
            self.stack: list[str] = []

        def _add(self, node: ast.AST, name: str, kind: EntityKind, async_flag: bool = False) -> None:
            qname = ".".join([module, *self.stack, name])
            stable_key = f"python|{artifact_id}|{qname}|{kind.value}"
            entity_id = stable_entity_id(kind, stable_key)
            args = ""
            if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef)):
                args = ast.dump(node.args, include_attributes=False)
            signature = _signature_hash(f"{kind.value}|{qname}|{args}|async={async_flag}")
            tags = ["LANGUAGE:PYTHON", f"SOCIETY:{society_id.upper()}", f"PROJECT:{project_id.upper()}"]
            if kind is EntityKind.TEST or name.startswith("test_"):
                tags.append("ROLE:TEST")
            output.append(
                SymbolDescriptor(
                    entity_id=entity_id,
                    entity_kind=kind,
                    qualified_name=qname,
                    path_ref=path_ref,
                    line_start=getattr(node, "lineno", None),
                    line_end=getattr(node, "end_lineno", None),
                    signature_hash=signature,
                    tags=tuple(sorted(set(tags))),
                )
            )

        def visit_ClassDef(self, node: ast.ClassDef) -> None:
            self._add(node, node.name, EntityKind.CLASS)
            self.stack.append(node.name)
            self.generic_visit(node)
            self.stack.pop()

        def visit_FunctionDef(self, node: ast.FunctionDef) -> None:
            kind = EntityKind.METHOD if self.stack else (EntityKind.TEST if node.name.startswith("test_") else EntityKind.FUNCTION)
            self._add(node, node.name, kind)
            self.stack.append(node.name)
            self.generic_visit(node)
            self.stack.pop()

        def visit_AsyncFunctionDef(self, node: ast.AsyncFunctionDef) -> None:
            kind = EntityKind.METHOD if self.stack else (EntityKind.TEST if node.name.startswith("test_") else EntityKind.FUNCTION)
            self._add(node, node.name, kind, async_flag=True)
            self.stack.append(node.name)
            self.generic_visit(node)
            self.stack.pop()

    Visitor().visit(tree)
    return sorted(output, key=lambda item: (item.path_ref, item.line_start or 0, item.qualified_name))


_SQL_PATTERNS: tuple[tuple[EntityKind, re.Pattern[str]], ...] = (
    (EntityKind.DB_FUNCTION, re.compile(r"\bcreate\s+(?:or\s+replace\s+)?function\s+([a-zA-Z_][\w$.]*)", re.I)),
    (EntityKind.RPC, re.compile(r"\bcreate\s+(?:or\s+replace\s+)?procedure\s+([a-zA-Z_][\w$.]*)", re.I)),
    (EntityKind.TABLE, re.compile(r"\bcreate\s+table\s+(?:if\s+not\s+exists\s+)?([a-zA-Z_][\w$.]*)", re.I)),
    (EntityKind.SYMBOL, re.compile(r"\bcreate\s+(?:or\s+replace\s+)?view\s+([a-zA-Z_][\w$.]*)", re.I)),
)


def _line_number(source: str, offset: int) -> int:
    return source.count("\n", 0, offset) + 1


def index_sql(
    source: str,
    *,
    path_ref: str,
    society_id: str,
    project_id: str,
    artifact_id: str,
) -> list[SymbolDescriptor]:
    output: list[SymbolDescriptor] = []
    for kind, pattern in _SQL_PATTERNS:
        for match in pattern.finditer(source):
            raw_name = match.group(1)
            qualified_name = raw_name.lower()
            stable_key = f"sql|{artifact_id}|{qualified_name}|{kind.value}"
            entity_id = stable_entity_id(kind, stable_key)
            line = _line_number(source, match.start())
            tags = (
                "LANGUAGE:SQL",
                "RUNTIME:POSTGRES",
                f"SOCIETY:{society_id.upper()}",
                f"PROJECT:{project_id.upper()}",
            )
            output.append(
                SymbolDescriptor(
                    entity_id=entity_id,
                    entity_kind=kind,
                    qualified_name=qualified_name,
                    path_ref=path_ref,
                    line_start=line,
                    line_end=None,
                    signature_hash=_signature_hash(f"{kind.value}|{qualified_name}"),
                    tags=tuple(sorted(tags)),
                )
            )
    return sorted(output, key=lambda item: (item.line_start or 0, item.qualified_name))


def descriptor_to_card(
    descriptor: SymbolDescriptor,
    *,
    world_id: str,
    society_id: str,
    project_id: str,
    artifact_id: str,
    module_name: str,
) -> AddressCard:
    address = semantic_address(
        ("society", society_id),
        ("project", project_id),
        ("artifact", artifact_id),
        ("module", module_name),
        ("symbol", descriptor.qualified_name),
    )
    return AddressCard(
        entity_id=descriptor.entity_id,
        entity_kind=descriptor.entity_kind,
        canonical_address=address,
        world_id=world_id,
        society_id=society_id,
        project_id=project_id,
        artifact_id=artifact_id,
        authoritative_ref_kind="CODE_SYMBOL",
        authoritative_ref=f"{descriptor.path_ref}#{descriptor.qualified_name}",
        tags=descriptor.tags,
        content_hash=descriptor.signature_hash,
    )


def index_source(
    source: str,
    *,
    language: str,
    path_ref: str,
    society_id: str,
    project_id: str,
    artifact_id: str,
) -> list[SymbolDescriptor]:
    language = language.strip().lower()
    if language in {"python", "py"}:
        return index_python(
            source,
            path_ref=path_ref,
            society_id=society_id,
            project_id=project_id,
            artifact_id=artifact_id,
        )
    if language in {"sql", "postgres", "postgresql", "plpgsql"}:
        return index_sql(
            source,
            path_ref=path_ref,
            society_id=society_id,
            project_id=project_id,
            artifact_id=artifact_id,
        )
    # Unsupported languages still remain addressable at FILE/Artifact level; no fake symbol parsing.
    return []
