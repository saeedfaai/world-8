# Operational Guardian v0.1 — Negative / Adversarial Test Matrix

Status: TEST SPECIFICATION ONLY / NO RUNTIME PASS CLAIM

The implementation may not claim evidence beyond design until these tests (or stricter equivalents) execute against the actual schema/RPCs.

| ID | Scenario | Expected result |
|---|---|---|
| OG-N01 | Old Guardian replica writes after newer `guardian_epoch` exists | REJECT stale epoch/fencing |
| OG-N02 | Same natural assignment key replayed after crash | idempotent prior result or duplicate rejection; never second Work |
| OG-N03 | WorkControl ACTIVE without all required budget reservations | REJECT |
| OG-N04 | WorkControl ACTIVE without required capacity/resource leases | REJECT |
| OG-N05 | Budget reserve uses stale `envelope_version` after shrink | CAS conflict / retry against new version |
| OG-N06 | New reservation while envelope has `overhang > 0` | REJECT |
| OG-N07 | Attempt to reclaim settled Spend | REJECT; settled remains immutable |
| OG-N08 | Ceiling shrinks below `S + R` | live reservations survive; A=0; O recorded; new dispatch blocked |
| OG-N09 | Released reservation while overhang exists | release repays parent/overhang first per accounting rule |
| OG-N10 | Guardian attempts hard-ceiling increase | REJECT; Governance path required |
| OG-N11 | Provider switch attempts to reset original deadline | REJECT / deadline unchanged |
| OG-N12 | Provider transient error consumes repair retry budget | REJECT incorrect accounting; must consume provider-switch budget |
| OG-N13 | Infinite provider switching within same timeout window | circuit breaker/deadline terminates |
| OG-N14 | Advisor is unavailable | deterministic Guardian still produces valid policy outcome |
| OG-N15 | Advisor suggests hard budget increase | ignored/rejected as non-authoritative |
| OG-N16 | Advisor suggests new failure class | ignored; closed enum remains authoritative |
| OG-N17 | Guardian attempts to mark Gap RESOLVED | REJECT |
| OG-N18 | Guardian attempts to mutate GapSignal status | REJECT / no such mutation surface |
| OG-N19 | Relaxed Observation Contract auto-resolves old Gap | REJECT |
| OG-N20 | Breaking Observation Contract creates successor without fresh violating measurement | REJECT |
| OG-N21 | SHARDED plan contains REDUNDANT_N shard in v0.1 | REJECT policy validation |
| OG-N22 | SHARDED dependency graph contains cycle | REJECT decomposition plan |
| OG-N23 | Integrator runs before completion contract satisfied | REJECT |
| OG-N24 | Integrated Candidate omits `derived_from_candidate_ids` | REJECT candidate gate |
| OG-N25 | Guardian chooses winning candidate in REDUNDANT_N | REJECT; SelectionDecision must be Governance/Evidence |
| OG-N26 | IMMEDIATE quarantine lets current write/effect lease continue | REJECT; fence immediately |
| OG-N27 | DRAIN quarantine receives lease extension | REJECT |
| OG-N28 | Soft quarantine renewal exceeds policy maximum | ESCALATE advisory; no indefinite operational hard revoke |
| OG-N29 | Guardian tries to HARD_REVOKE Actor/RoleBinding/credential | REJECT |
| OG-N30 | Provider quarantine revokes persistent Mason identity | REJECT; Provider != Actor |
| OG-N31 | Guardian quarantine query expands to another Society | REJECT |
| OG-N32 | Budget allocation borrows from another Society | REJECT |
| OG-N33 | Guardian suppresses Observer telemetry/detector/gap path | REJECT |
| OG-N34 | External-effect allowance is used as effect authorization | REJECT; governed effect path required |
| OG-N35 | Capacity lease is presented as developer write authority | REJECT; `world8_dev_leases` required |
| OG-N36 | Direct Mason/Brain SQL mutation of control tables | REJECT by privilege/RPC boundary |
| OG-N37 | Update/delete of committed control event | REJECT append-only |
| OG-N38 | Update/delete of AdvisoryReceipt | REJECT append-only |
| OG-N39 | Two concurrent event appends use same aggregate version | only one succeeds; other CAS conflict |
| OG-N40 | Event has correct wall clock but wrong aggregate causal version | REJECT; aggregate version is ordering truth |
| OG-N41 | Cross-ledger decision cites only timestamp/correlation ID | INVALID citation pack |
| OG-N42 | Cited Operational event archived without frozen bytes in evidence bundle | archival gate FAIL |
| OG-N43 | System claims cross-ledger linearizability/2PC | conformance FAIL |
| OG-N44 | Guardian crash/failover kills every valid assignment | conformance FAIL; valid leases inherited |
| OG-N45 | Guardian failover recreates existing assignment despite idempotency key | REJECT duplicate |
| OG-N46 | Guardian failover forgets still-valid soft quarantine | conformance FAIL |
| OG-N47 | Gap exceeds `max_failed_attempts` | ESCALATE; no new Mason dispatch |
| OG-N48 | Mason capacity available but Evaluator capacity exhausted | dispatch/admission policy must back-pressure rather than unlimited candidate buildup |
| OG-N49 | Partial resource-set acquisition succeeds for worker execution | REJECT; all-or-none required |
| OG-N50 | Ordered lock prevention fails and dependency cycle appears | detector must classify `DEADLOCK_DETECTED` and terminate/escalate within timeout policy |

## Required mutation families after base tests pass

1. remove epoch check;
2. remove envelope-version CAS;
3. allow overhang dispatch;
4. allow settled reclaim;
5. reset deadline on provider switch;
6. make Advisor required;
7. permit Guardian Gap resolution;
8. permit Guardian HARD_REVOKE;
9. permit effect allowance as authorization;
10. remove Society scope predicate;
11. allow SHARDED x REDUNDANT_N;
12. remove append-only event trigger;
13. remove assignment natural-idempotency uniqueness;
14. allow stale/fenced capacity lease use;
15. accept citation without exact event hash/version.

A future mutation gate should fail the evidence claim if any critical mutant survives.

## Evidence ceiling

This file is a test plan, not a test result. `0 PASS claims` are implied until executable results and receipts are committed.
