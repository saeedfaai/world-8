# DCR-0003 — Operational Guardian leader/epoch scope

Status: ACCEPTED FOR v0.1 FAMILY ARTIFACT RECONCILIATION
Date: 2026-08-28
Affects: Guardian leader lease, epoch/fencing identity, failover blast radius
Trust/authority boundary change: NO
Fencing/HA schema semantics change: YES

## Discovery

The base schema candidate models one row:

`guardian_key = 'operational-guardian'`

for the entire World.

That creates a world-global leadership/failover domain even though the frozen contract requires:

- Society-isolated operational scope by default;
- no global Operational ledger head;
- parallel operational work with serialized truth only where required;
- cross-Society budget/quarantine access forbidden for ordinary Guardian scope.

A global leader epoch would make an ordinary Society failover capable of becoming a World-wide fencing event and would create an unnecessary global availability boundary.

## Decision

Operational Guardian leadership is scoped by Society in the v0.1 family.

Default leader identity:

`(world_id, society_id, guardian_shard_key)`

where v0.1.x uses:

`guardian_shard_key = 'primary'`

for one deterministic control leader per Society.

Future within-Society sharding MAY introduce additional stable shard keys, but that requires an explicit later DCR because assignment/resource routing and epoch provenance must remain deterministic.

## Epoch and fencing semantics

1. `guardian_epoch` is monotonic within one exact `(world_id, society_id, guardian_shard_key)` domain.
2. Epoch numbers from different Societies/shards are not globally comparable.
3. Every control write MUST resolve and validate the leader/fencing row for the same Society/shard as the target aggregate.
4. A stale leader in Society A cannot write to Society A after takeover, and cannot use its epoch/fence as evidence for Society B.
5. Failover in Society A MUST NOT fence, pause, inherit, or rewrite valid Society B assignments/reservations/quarantines.
6. Takeover audit is scoped to the leader domain being acquired.
7. Human Root / World Governance may observe multiple leader domains, but ordinary Guardian mutation remains Society-scoped.

## Non-changes

This DCR does NOT:

- create a sixth Plane;
- change Canonical Spine authority;
- permit cross-Society ordinary Guardian mutation;
- change Candidate evaluation/promotion ownership;
- change hard-ceiling or HARD_REVOKE ownership;
- change BudgetEnvelope accounting;
- create a global Operational head.

## Evidence status

Design/HA correction only. No runtime migration, failover PASS, scale PASS, or deployment evidence is implied.
