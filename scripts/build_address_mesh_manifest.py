#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
from pathlib import Path
import sys
from typing import Iterable

REPO_ROOT = Path(__file__).resolve().parents[1]
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))

from services.address_mesh.indexer import descriptor_to_card, index_source
from services.address_mesh.model import AddressCard, EntityKind, semantic_address, stable_entity_id

_SUPPORTED = {".py": "python", ".sql": "sql"}
_SKIP_DIRS = {".git", ".venv", "venv", "node_modules", "dist", "build", "__pycache__"}


def _load_map(path: Path) -> dict:
    data = json.loads(path.read_text(encoding="utf-8"))
    if data.get("schema") != "WORLD8_ADDRESS_INDEX_MAP/1.0":
        raise SystemExit("ADDRESS_INDEX_MAP_SCHEMA_UNSUPPORTED")
    return data


def _rule_for(path_ref: str, mapping: dict) -> dict:
    default = dict(mapping["default"])
    matches = [rule for rule in mapping.get("rules", []) if path_ref.startswith(rule["path_prefix"])]
    if matches:
        best = max(matches, key=lambda item: len(item["path_prefix"]))
        default.update({k: v for k, v in best.items() if k != "path_prefix"})
        default["tags"] = sorted(set(mapping["default"].get("tags", [])) | set(best.get("tags", [])))
    return default


def _walk(root: Path) -> Iterable[Path]:
    for path in root.rglob("*"):
        if not path.is_file():
            continue
        if any(part in _SKIP_DIRS for part in path.parts):
            continue
        yield path


def _file_card(*, path_ref: str, rule: dict, world_id: str) -> AddressCard:
    artifact_id = rule["artifact_id"]
    society_id = rule["society_id"]
    project_id = rule["project_id"]
    entity_id = stable_entity_id(EntityKind.FILE, f"git|{artifact_id}|{path_ref}")
    tags = set(rule.get("tags", []))
    suffix = Path(path_ref).suffix.lower()
    if suffix == ".py":
        tags.add("LANGUAGE:PYTHON")
    elif suffix == ".sql":
        tags.update({"LANGUAGE:SQL", "RUNTIME:POSTGRES"})
    return AddressCard(
        entity_id=entity_id,
        entity_kind=EntityKind.FILE,
        canonical_address=semantic_address(
            ("society", society_id),
            ("project", project_id),
            ("artifact", artifact_id),
            ("file", path_ref),
        ),
        world_id=world_id,
        society_id=society_id,
        project_id=project_id,
        artifact_id=artifact_id,
        authoritative_ref_kind="GIT_PATH",
        authoritative_ref=path_ref,
        tags=tuple(sorted(tags)),
    )


def build_manifest(root: Path, mapping: dict) -> list[dict]:
    world_id = mapping.get("world_id", "world-001")
    rows: list[dict] = []
    for path in sorted(_walk(root)):
        path_ref = path.relative_to(root).as_posix()
        rule = _rule_for(path_ref, mapping)
        file_card = _file_card(path_ref=path_ref, rule=rule, world_id=world_id)
        rows.append({"record_type": "ENTITY", **file_card.__dict__, "entity_kind": file_card.entity_kind.value})

        language = _SUPPORTED.get(path.suffix.lower())
        if not language:
            continue
        source = path.read_text(encoding="utf-8", errors="replace")
        descriptors = index_source(
            source,
            language=language,
            path_ref=path_ref,
            society_id=rule["society_id"],
            project_id=rule["project_id"],
            artifact_id=rule["artifact_id"],
        )
        for descriptor in descriptors:
            card = descriptor_to_card(
                descriptor,
                world_id=world_id,
                society_id=rule["society_id"],
                project_id=rule["project_id"],
                artifact_id=rule["artifact_id"],
                module_name=Path(path_ref).with_suffix("").as_posix().replace("/", "."),
            )
            combined_tags = tuple(sorted(set(card.tags) | set(rule.get("tags", []))))
            row = {**card.__dict__, "entity_kind": card.entity_kind.value, "tags": combined_tags}
            rows.append({"record_type": "ENTITY", **row})
            rows.append({
                "record_type": "RELATION",
                "source_entity_id": file_card.entity_id,
                "relation_type": "CONTAINS",
                "target_entity_id": card.entity_id,
                "source_ref": f"git:{path_ref}",
            })
    return rows


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", default=".")
    parser.add_argument("--map", default="architecture/contracts/world8-address-index-map-v0.1.json")
    parser.add_argument("--output", default="artifacts/address-mesh/world8-address-manifest-v0.1.jsonl")
    args = parser.parse_args()

    root = Path(args.root).resolve()
    mapping_path = Path(args.map)
    if not mapping_path.is_absolute():
        mapping_path = REPO_ROOT / mapping_path
    mapping = _load_map(mapping_path)
    rows = build_manifest(root, mapping)
    output = Path(args.output)
    output.parent.mkdir(parents=True, exist_ok=True)
    with output.open("w", encoding="utf-8") as handle:
        for row in rows:
            handle.write(json.dumps(row, ensure_ascii=False, sort_keys=True, default=list) + "\n")
    entities = sum(1 for row in rows if row["record_type"] == "ENTITY")
    relations = sum(1 for row in rows if row["record_type"] == "RELATION")
    print(json.dumps({"schema": "WORLD8_ADDRESS_MANIFEST_BUILD/1.0", "entities": entities, "relations": relations, "output": output.as_posix()}))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
