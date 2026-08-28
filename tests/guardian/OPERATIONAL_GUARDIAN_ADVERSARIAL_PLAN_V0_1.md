# Operational Guardian v0.1 — Adversarial Test Plan

Status: SPECIFIED / NOT RUN
Contract: `docs/engineering/OPERATIONAL_GUARDIAN_CONTRACT_V0_1.md`
State machines: `architecture/contracts/operational-guardian-state-machines-v0.1.yaml`

No PASS claim is made by this file. Each case is an obligation for implementation evidence.

## A. Guardian leadership / fencing

1. **STALE_EPOCH_WRITE** — leader A loses lease; leader B acquires epoch+1; A attempts control append. Expected: reject with no event/projection mutation.
2. **TAKEOVER_INHERITS_VALID_ASSIGNMENT** — B takes over while assignment lease is valid and policy current. Expected: assignment remains active; no duplicate assignment.
3. **TAKEOVER_FENCES_EXPIRED_ASSIGNMENT** — assignment lease expired before takeover. Expected: no new effect/write allowed; stale work cannot settle using old fence.
4. **REPLAY_IDEMPOTENCY** — restart/replay repeats same natural assignment key. Expected: prior semantic result returned or duplicate rejected; no second WorkAssignment.

## B. Budget / envelope

5. **CONCURRENT_RESERVATION_CAS** — two reservations race for the last spend amount. Expected: at most one succeeds; accounting invariant holds.
6. **SHRINK_WITH_LIVE_RESERVATION** — Governance shrinks ceiling below S+R. Expected: reservation remains valid to lease semantics; O>0; A=0; new dispatch blocked.
7. **STALE_ENVELOPE_VERSION_RESERVE** — reserve uses pre-shrink envelope version. Expected: CAS fail and retry against new version; no oversubscription.
8. **SETTLED_HISTORY_IMMUTABLE** — shrink below settled amount. Expected: no settled rewrite; explicit overhang/governed correction required.
9. **WITHIN_ENVELOPE_EXTENSION** — WorkAssignment requests same-dimension extension within child envelope. Expected: Guardian may approve according to policy.
10. **HARD_CEILING_EXTENSION_BY_GUARDIAN** — Guardian attempts child hard-ceiling increase. Expected: reject; Governance-only.
11. **CROSS_SOCIETY_BUDGET** — Guardian scoped to Society A attempts reserve from Society B envelope. Expected: reject.

## C. Gap / Observer boundary

12. **GUARDIAN_GAP_MUTATION** — Guardian attempts to alter GapSignal or lifecycle. Expected: reject.
13. **WORK_COMPLETED_DOES_NOT_RESOLVE_GAP** — all WorkOrders complete and Candidate passes. Expected: Gap remains unresolved until Observer re-measurement.
14. **RELAXED_CONTRACT_NO_AUTO_RESOLVE** — threshold relaxes. Expected: old Gap is not auto-resolved.
15. **BREAKING_CONTRACT_SUPERSESSION** — predicate meaning changes. Expected: lifecycle may become SUPERSEDED via allowed observation/governance succession path; original bytes unchanged.
16. **EXPIRED_ACTIONABILITY_WITH_VIOLATION** — window expires while original predicate still violated. Expected: actionability=EXPIRED while resolution remains STILL_VIOLATED/OPEN as appropriate.
17. **GUARDIAN_SUPPRESS_OBSERVER** — Guardian attempts detector/telemetry suppression. Expected: forbidden.

## D. Dispatch modes / integration

18. **SHARDED_REDUNDANT_FORBIDDEN** — dispatch plan combines SHARDED and REDUNDANT_N. Expected: policy rejection before reservation.
19. **REDUNDANT_WINNER_BY_GUARDIAN** — Guardian attempts winner selection. Expected: reject; SelectionDecision required from Evidence/Governance.
20. **INTEGRATION_BEFORE_COMPLETION_CONTRACT** — Integrator starts before required shards satisfy completion contract. Expected: reject.
21. **INTEGRATION_FAILED** — shard interfaces conflict. Expected: INTEGRATION_FAILED operational outcome; no candidate promotion implication.
22. **DERIVED_FROM_REQUIRED** — integrated candidate omits shard lineage. Expected: fail validation.

## E. Advisor / provider

23. **ADVISOR_NULL** — Advisor unavailable. Expected: deterministic Guardian still dispatches/refuses based on policy; no liveness dependency.
24. **ADVISOR_OUT_OF_BOUNDS** — advisor proposes hard budget, authority or forbidden priority override. Expected: ignore/reject advisory input; no kernel mutation.
25. **PROVIDER_SWITCH_NO_DEADLINE_RESET** — provider fails and route switches. Expected: provider-switch budget decrements; original timeout/deadline continues.
26. **PROVIDER_QUARANTINE_NOT_ACTOR_REVOKE** — provider security quarantine occurs. Expected: provider route blocked according to policy; Actor identity/authority not hard-revoked.

## F. Quarantine

27. **IMMEDIATE_SOFT_QUARANTINE** — typed policy violation triggers IMMEDIATE. Expected: new work forbidden, write/effect/resource leases fenced, bounded read/handoff only.
28. **DRAIN_SOFT_QUARANTINE** — deterministic failure class triggers DRAIN. Expected: no new work/extensions; valid safe current work may finish inside lease.
29. **SOFT_TO_HARD_AUTHORITY_BYPASS** — Guardian tries to convert repeated quarantine directly to HARD_REVOKE. Expected: reject; governed path required.
30. **QUARANTINE_TTL_REPLAY** — failover occurs while quarantine active. Expected: new leader reconstructs same still-valid quarantine; no re-judgment.
31. **QUARANTINE_SCOPE_REPLAY** — same typed failure class + policy version + ledger snapshot replayed. Expected: identical computed scope.

## G. External effects

32. **ALLOWANCE_NOT_AUTHORIZATION** — assignment has external_effect_allowance but no Effect authorization. Expected: actual external effect blocked.
33. **STALE_EFFECT_LEASE_AFTER_IMMEDIATE_QUARANTINE** — old worker tries effect after fence. Expected: reject.

## H. Control ledger / cross-ledger

34. **AGGREGATE_CAS_RACE** — two writes against same expected aggregate_version. Expected: one accepted, one conflict.
35. **CAUSAL_REF_REPLAY** — WorkAssignment activation cites reservation event. Expected: causation reference resolves to exact event/version/hash.
36. **SPINE_CITATION_HASH_TAMPER** — cited operational bytes changed/tampered. Expected: citation verification fails.
37. **NO_CROSS_LEDGER_2PC_ASSUMPTION** — Operational commit succeeds and later Spine decision fails. Expected: system remains valid with explicit incomplete governance state; no rollback fiction across ledgers.
38. **ARCHIVE_SAFE_CITATION** — terminal aggregate moved to cold archive. Expected: frozen evidence bytes still verify Spine citation.
39. **PROJECTION_LAG_EXTERNAL** — external projector lags. Expected: control decision does not rely on stale external projection where committed event truth is required.

## I. Capacity / circuit breaker

40. **EVALUATOR_BACKPRESSURE** — Mason capacity free but Evaluator slots saturated. Expected: admission/dispatch respects downstream capacity policy; Candidate backlog does not grow unbounded by design.
41. **INTEGRATOR_CAPACITY** — sharded work lacks Integrator capacity. Expected: no false completion; waits/backoffs according to policy.
42. **GAP_RETRY_STORM** — repeated failures reach max_failed_attempts/max_assignments. Expected: ESCALATE; no further automatic assignment.
43. **RESOURCE_ALL_OR_NONE** — requested resource set partially available. Expected: zero retained partial locks and WAIT/BACKOFF.
44. **DEPENDENCY_CYCLE** — unprevented dependency cycle introduced. Expected: detector yields deadlock failure/escalation; no indefinite wait.

## Mutation obligations

At minimum mutate and require kill for:
- disable guardian_epoch check
- bypass aggregate CAS
- reset deadline on provider switch
- treat allowance as effect authorization
- allow Guardian HARD_REVOKE
- allow Guardian Gap mutation
- allow SHARDED x REDUNDANT_N
- disable circuit breaker
- allow cross-Society envelope lookup
- ignore overhang in dispatch admission
- allow Advisor to change hard ceiling
- let Work completion mark Gap RESOLVED

A test family counts as evidenced only when it exercises real implementation code and the corresponding mutation is killed where applicable.
