# ADR-0003 — Operational Guardian Boundary

Status: ACCEPTED FOR DESIGN FREEZE / NOT IMPLEMENTED / NOT EVIDENCED

## Context

World 8 already contains an **Engineering Guardian v0.1** companion service (`service-world8-engineering-guardian`) that is advisory/audit-only and has `authority_effect=NONE`. It also already contains an N-Mason Pool for concurrent engineering workers.

The new Guardian discussed in the World 8 architecture is a different concern: deterministic orchestration and resource governance between immutable Observation `GapSignal` objects and proposal-only Mason execution.

Conflating these two Guardians would create an ambiguous trust boundary. The existing Engineering Guardian must remain a context/evidence companion. The Operational Guardian must not silently inherit authority from it.

## Decision

World 8 defines a distinct **Operational Guardian Kernel** with the following boundary:

- Observer: **What happened?**
- Operational Guardian: **What may run?**
- Mason / Integrator Mason: **How can it be built or fixed?**
- Evaluator: **Is the candidate acceptable?**
- Promotion Authority: **May it become accepted?**
- Canonical Spine: **What was accepted?**

The Operational Guardian is **not a sixth plane**. It operates within the existing Operational / Evidence-Governance separation and may only enforce versioned deterministic policy.

## Hard prohibitions

Operational Guardian MUST NOT:

1. create, rewrite, claim or resolve a `GapSignal`;
2. evaluate candidate quality;
3. promote a candidate;
4. hard-revoke RoleBinding, credentials or authority ceilings;
5. authorize external business effects;
6. suppress Observer telemetry, detectors or Gap production;
7. hot-patch its own policy;
8. require an LLM Advisor for system liveness;
9. claim cross-ledger atomicity or linearizability between Operational Control and the Canonical Spine.

## Operational truth

Operational control decisions use a **partitioned append-only Operational Control Ledger** with CAS per aggregate. There is no global operational head.

High-frequency telemetry, heartbeats and raw Mason logs remain outside this ledger.

Where event and current-state projection share one PostgreSQL transaction, they MUST update atomically. Where projection is external, Outbox + idempotent projection is required. Uncoordinated dual-write is forbidden.

## Cross-ledger relation

Spine and Operational ledgers are linked by **hash citation and happens-before**, not distributed transactions.

A Spine decision that depends on Operational state cites exact Operational event IDs, aggregate versions and hashes. The cited bytes must remain available in the evidence bundle even after Operational cold archival.

## Budget boundary

Guardian distributes only budget already delegated into a pre-funded child envelope.

- Within-envelope WorkAssignment extension: deterministic Guardian policy may approve.
- Child/Project/Society hard-ceiling increase: Governance/Human Root only.
- External-effect allowance is capacity/budget, never effect authorization.

Budget accounting preserves:

`S + R + A = C + O`

where `C=ceiling`, `S=settled`, `R=reserved`, `A=available`, `O=overhang`.

A ceiling shrink never rewrites settled history and never breaks a still-valid reservation. Overhang blocks new dispatch until governed correction or natural release/settlement reduces the condition.

## Quarantine boundary

Operational Guardian may apply only versioned `SOFT_QUARANTINE_IMMEDIATE` or `SOFT_QUARANTINE_DRAIN` policies derived deterministically from a closed typed failure class and scope policy.

Permanent authority change remains `HARD_REVOKE` and is exclusively governed/canonical.

## Relationship to existing Engineering Guardian

The existing Engineering Guardian remains:

- session companion;
- context/evidence surfacing service;
- no independent authority;
- no auto-fix in its current revision.

The Operational Guardian may consume grounded facts from existing systems but MUST NOT treat Engineering Guardian advisory output as policy authority.

## Consequences

Positive:

- preserves Z0-A separation of duties;
- scales beyond a single global operational serialization point;
- keeps recovery/audit replayable;
- prevents LLM advice from becoming hidden policy;
- avoids turning resource orchestration into canonical authority.

Costs:

- requires explicit Operational Ledger objects and state machines;
- requires fencing/epoch semantics for Guardian HA;
- requires causal citation across ledgers;
- requires separate capacity accounting for Mason, Evaluator and Integrator pools.

## Change rule

Any future change to writer authority, ledger consistency, cross-ledger semantics, quarantine authority, budget accounting invariants or Gap mutation rules requires a versioned Design Change Request and a new contract revision. Silent mutation is forbidden.
