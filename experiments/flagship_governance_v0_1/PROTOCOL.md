# W8-P01 Flagship Experiment Protocol v0.1

Status: FROZEN-CANDIDATE / NON-MARKET / NO LIVE EFFECTS
Paper: W8-P01
Issue: https://github.com/saeedfaai/world-8/issues/27
Branch: `work/w8-p01-governance-experiment-v0.1`

## Research question

Can a governed multi-agent architecture preserve persistent actor identity, scoped authority, effect idempotency, stale-writer rejection, and reconstructable evidence across provider/session changes and injected faults better than a conventional session-scoped orchestration baseline?

## Scope

This experiment is architecture/governance evaluation only.
It does not evaluate market prediction, trading profitability, AGI, consciousness, or autonomous economic agency.
It is intentionally independent from W8-P02 / SSRN 7359740.

## Scenario

A deterministic four-role work process:

1. `requester` submits a governed change request.
2. `reviewer` approves or denies the request.
3. `executor` attempts the effect under an authorization decision and lease/fencing context.
4. `auditor` reconstructs the outcome from evidence receipts.

Persistent actor identity is independent from provider/model/session. Provider/session may change between steps without changing actor identity.

## Systems under comparison

### A. World 8 governed reference path

Required mechanisms:
- persistent `actor_id` independent of provider/session;
- explicit capability/authorization decision;
- deny/revoke precedence;
- authorization bound to exact actor + action + object;
- lease/fencing token for write/effect attempts;
- compare-and-set expected version check;
- idempotency key for externally visible effects;
- append-only evidence receipts;
- deterministic reconstruction/audit;
- fail-closed behavior when required evidence is absent/invalid.

### B. Session-scoped orchestration baseline

A deliberately minimal conventional orchestration pattern:
- role labels attached to current runtime session;
- in-memory role/permission map;
- mutable shared object state;
- no persistent actor identity across session replacement;
- no fencing token;
- no append-only evidence chain;
- duplicate suppression only when the current session remembers the prior command.

This baseline is not claimed to represent every agent framework. It represents a common minimal orchestration pattern and will be described narrowly to avoid straw-man claims.

## Fault families

F0 — no fault / valid operation
F1 — provider/session replacement between review and execution
F2 — actor/session impersonation attempt
F3 — authorization revoked after approval but before execution
F4 — stale writer uses an old expected version
F5 — duplicate command / repeated idempotency key
F6 — missing authorization evidence
F7 — expired/incorrect fencing token
F8 — concurrent executor race
F9 — tampered audit/evidence receipt
F10 — restart before audit/reconstruction

## Primary outcome metrics

For each system and fault family:

1. `unauthorized_effect_rate`
2. `stale_write_accept_rate`
3. `duplicate_effect_rate`
4. `reconstruction_success_rate`
5. `actor_attribution_continuity_rate`
6. `evidence_completeness_rate`
7. `fail_closed_rate_on_invalid_attempts`
8. `false_deny_rate_on_valid_attempts`
9. `valid_effect_success_rate`

Secondary:
- deterministic replay equality;
- number of receipts/events required for reconstruction;
- failure classification counts.

## Experimental design

- deterministic seeded simulation;
- at least 1,000 trials per fault family per system for the frozen result run;
- identical scenario seeds and fault schedules across systems;
- results written as machine-readable JSON/CSV;
- all result tables generated from receipts, never hand-entered;
- tests must verify metric calculations;
- negative/mixed findings retained.

## Success criteria for the paper evidence gate

The experiment is eligible to support W8-P01 only if:

- [ ] protocol is frozen before the final result run;
- [ ] both systems execute under identical seeded schedules;
- [ ] no market code or W8-P02 result is reused as the main evidence;
- [ ] all fault families have explicit expected semantics;
- [ ] valid no-fault operations are measured to expose false-deny cost;
- [ ] raw trial receipts are retained or reproducibly regenerable;
- [ ] final result package has an exact commit + SHA256;
- [ ] overlap audit against W8-P02 passes;
- [ ] claims are limited to measured mechanisms.

## Non-claims

This protocol does not establish that World 8 is production ready, universally superior to agent frameworks, secure against all adversaries, fault tolerant under arbitrary distributed failures, or economically beneficial.
