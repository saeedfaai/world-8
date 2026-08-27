# W8-P01 Governance Experiment — Sanity Result v0.1

Status: SANITY PASS / NOT YET PAPER EVIDENCE
Run: https://github.com/saeedfaai/world-8/actions/runs/33103234548
Artifact: `w8-p01-governance-evidence-v0.1`
Artifact digest: `sha256:30ba3b7870c4e634626d88c8fdf9f533d717eaf9b9fdc0c0721e3fbc61a42d01`
Seed: `20260827`
Trials: 22,000 total = 11 fault families x 1,000 schedules x 2 systems

Evidence file hashes:
- `summary.json`: `d3c080ec5bb53750388696df585ae27b5a21b0874bef1dc03cfa5ec95d3d7d6c`
- `trials.csv`: `7e0d8aa573217f41ee88e3e6f0ca347eb7a771384154c2c85e8a64ddadfc5b2e`
- `trials.jsonl`: `fb25c8a4601b9b59a1aca0b2610746bac75f775aa1fdcb43358f0dc2b6cee525`

## Observed mechanism-level sanity results

The World 8 governed reference path preserved valid-effect success with zero false denial in the tested valid-primary families F0/F1/F5/F8/F9/F10.

It blocked the explicitly invalid attempts in:
- F2 actor/session impersonation;
- F3 revoked authorization;
- F4 stale expected version;
- F5 duplicate effect after session replacement;
- F6 missing authorization evidence;
- F7 invalid fencing token;
- F8 second concurrent writer under single-winner semantics.

It also:
- retained actor attribution through session replacement (F1);
- detected tampered receipt attribution (F9);
- reconstructed durable evidence after runtime restart (F10).

The minimal session-scoped baseline did successfully enforce one important safeguard: current role revocation in F3. This negative/non-difference is retained.

The minimal baseline failed or lacked the compared mechanism under several other directed faults, including stale-write rejection, cross-session idempotency, durable actor attribution, tamper-evident audit, and restart reconstruction.

## Why this result is NOT sufficient for W8-P01 claims

The current comparison baseline is intentionally narrow. It includes role permissions and session-local duplicate memory, but it does not include CAS/fencing, durable idempotency, persistent actor identity, or tamper-evident receipts. Therefore a reviewer could reasonably argue that several observed differences follow directly from mechanism presence/absence rather than a strong comparison against a hardened conventional design.

Also, the first 1,000 trials per fault primarily vary identifiers/order under directed single-fault schedules. They are useful as property stress but are not yet a rich stochastic/compound-fault workload.

## Required strengthening before paper evidence

- [ ] add Hardened Baseline with CAS + durable idempotency + revoke checks;
- [ ] retain session-scoped identity and mutable/non-proof audit in Hardened Baseline;
- [ ] add World 8 component ablations: actor binding, CAS, fence, idempotency, hash chain;
- [ ] add compound-fault schedules;
- [ ] measure per-mechanism protection and valid-path cost;
- [ ] compare against at least one externally recognizable orchestration pattern/framework where feasible;
- [ ] freeze final protocol only after baseline/ablation design review.

## Claim ceiling

This sanity run may be used to validate the experiment implementation and demonstrate expected mechanism semantics. It MUST NOT be used by itself to claim that World 8 is generally superior to existing multi-agent frameworks or production systems.
