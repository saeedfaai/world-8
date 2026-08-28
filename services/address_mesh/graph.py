from __future__ import annotations

from collections import defaultdict, deque
from dataclasses import dataclass
from typing import Iterable

from .model import AddressMeshError, AddressRelation, RelationType


@dataclass(frozen=True)
class ImpactNode:
    entity_id: str
    depth: int
    via_relation: str | None
    predecessor_id: str | None


def bounded_impact(
    *,
    origin_entity_id: str,
    relations: Iterable[AddressRelation],
    relation_types: Iterable[RelationType | str],
    max_depth: int = 3,
    reverse: bool = True,
) -> list[ImpactNode]:
    """Traverse only explicit known graph edges; never infer semantic impact from proximity."""
    if max_depth < 0 or max_depth > 12:
        raise AddressMeshError("IMPACT_MAX_DEPTH_OUT_OF_RANGE")
    allowed = {RelationType(value) for value in relation_types}
    if not allowed:
        raise AddressMeshError("IMPACT_RELATION_TYPES_REQUIRED")

    adjacency: dict[str, list[tuple[str, RelationType]]] = defaultdict(list)
    for relation in relations:
        if relation.relation_type not in allowed:
            continue
        if reverse:
            # Dependents/consumers affected by a changed target.
            adjacency[relation.target_entity_id].append((relation.source_entity_id, relation.relation_type))
        else:
            adjacency[relation.source_entity_id].append((relation.target_entity_id, relation.relation_type))

    queue = deque([(origin_entity_id, 0, None, None)])
    seen = {origin_entity_id}
    output: list[ImpactNode] = []

    while queue:
        current, depth, via, predecessor = queue.popleft()
        output.append(ImpactNode(current, depth, via.value if via else None, predecessor))
        if depth >= max_depth:
            continue
        for neighbor, relation_type in sorted(adjacency.get(current, []), key=lambda item: (item[0], item[1].value)):
            if neighbor in seen:
                continue
            seen.add(neighbor)
            queue.append((neighbor, depth + 1, relation_type, current))

    return output
