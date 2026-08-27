# World 8 Architecture Baseline

## Frozen semantics
- Entity ≠ Skill; Brain ≠ Skill; Society ≠ Skill.
- Skill is independent, stateless, versioned capability in one global Skill Library.
- Entity/Role/Society consumes Skill through versioned Binding.
- Knowledge, Experience and Overlay are versioned objects outside Skill.
- Resolver pins exact versions into a Resolved Context Manifest.
- Brain is an executor; raw brain output begins as Observation.
- Composition is a versioned typed DAG.
- External effects follow: Gate → Effect Intent → Outbox → Hub → Adapter → Receipt.
- Canonical Spine stores governance/commitments/decisions/effects and hashed refs, not bulky raw data.
- Shared capability is written once; society-specific usage belongs in Binding/Policy/Composition.

## Engineering truth separation
- TRUTH: architecture + frozen contracts + ADRs.
- STATE: actual implementation/runtime realization.
- WORK: active objectives/work/claims/leases/changes.
- MEMORY: Code Shadow + Diagnostic Memory + ADRs + Dispatch + Handoffs + actor history.
