# ADR-0001 — Canonical Truth Boundary

Status: ACCEPTED_FOR_REPO_BOOTSTRAP

## Context
World 8 separates architecture truth, live runtime state, development coordination, and human-readable documentation.

## Decision
- Git is canonical for architecture manifests and code history.
- DCP is the live development coordination/governance projection/cache.
- Runtime is the truth of what is actually deployed/running.
- Drive is a human-read/recovery/report surface, not canonical source truth.

## Consequences
DCP must be reconstructable/synchronizable from canonical Git for architecture/code metadata; runtime evidence may show implementation lag or divergence and must not be overwritten by prose.
