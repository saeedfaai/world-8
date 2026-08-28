# Operational Guardian v0.1.3 — Leader / Failover State Rules

Status: DESIGN_FROZEN / NOT IMPLEMENTED / NOT EVIDENCED / NOT DEPLOYED
DCR: `architecture/proposals/DCR-0003-operational-guardian-leader-scope.md`

This file is a corrective HA/state overlay on the v0.1 family.

## 1. Leader domain

A Guardian leader lease is identified by:

`(world_id, society_id, guardian_shard_key)`

v0.1.x default:

`guardian_shard_key = primary`

One Society therefore has one active control leader in the default revision, but different Societies may have independent active leaders and independent epoch values.

## 2. Leader lease lifecycle

Logical states:

`UNCLAIMED -> ACTIVE -> EXPIRED -> ACTIVE(new epoch)`

Renewal while ACTIVE preserves the current epoch and advances fencing evidence according to the lease implementation contract.

Takeover after expiry/allowed failover advances the epoch for that exact leader domain.

Forbidden:

- two ACTIVE holders for the same exact leader domain;
- takeover without expected previous epoch/fencing CAS;
- world-global takeover that implicitly fences every Society;
- using Society A leader evidence for Society B control mutation.

## 3. Epoch semantics

`guardian_epoch` is monotonic only inside one exact leader identity.

Examples:

- Society A / primary may be epoch 7.
- Society B / primary may independently also be epoch 7.
- those two values are unrelated and MUST NOT be compared as a World-global ordering.

Every control mutation validates:

1. target aggregate Society;
2. target Guardian shard;
3. current ACTIVE leader row for that same identity;
4. epoch equality;
5. fencing evidence;
6. lease not expired;
7. policy version and aggregate CAS rules.

## 4. Failover blast radius

Failover audit is limited to the acquired leader domain.

Society A takeover may inspect/inherit/fence only Society A assignments, reservations, capacity leases and quarantine state routed to that shard.

It MUST NOT:

- expire Society B reservations;
- fence Society B workers;
- rewrite Society B quarantine decisions;
- advance Society B Guardian epoch;
- block Society B solely because Society A lost leadership.

## 5. Future sharding

Additional stable `guardian_shard_key` values inside one Society are not enabled by this revision.

Adding them requires a later DCR that freezes deterministic aggregate-to-shard routing and proves that no aggregate can be concurrently writable under two leader domains.

## Evidence rule

Static conformance proves only that artifacts agree with DCR-0003. Runtime evidence requires concurrent lease-acquisition tests, stale-epoch rejection, cross-Society isolation tests, failover blast-radius tests, and mutation kills.
