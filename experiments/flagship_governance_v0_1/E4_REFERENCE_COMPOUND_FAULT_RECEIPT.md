# W8-P01 — E4 Directed Reference Compound-Fault Receipt

Date: 2026-08-27
Status: **PARTIAL PASS / DIRECTED REFERENCE-MODEL COMPOUND FAULTS**

## Run

- GitHub Actions: https://github.com/saeedfaai/world-8/actions/runs/33108000278
- artifact: `w8-p01-compound-fault-gate-v1`
- artifact digest: `sha256:94817f523a294192b0805b90a456c55af6903ed76d01f101c49bf13f284bb161`
- `compound_fault_gate_v1.json` SHA256: `79341467909930b09460082f34402686e2fb7f0de6df46ed4bf30fb816d94e1d`
- seed: `20260827`
- trials per case: `1000`
- evidence level: `REFERENCE_MODEL_COMPOUND_FAULT`
- runtime DB mutated: `false`
- gate state: `PASS`

## Directed compound cases

### CF1 — Stolen authorization after identity swap

Combination:
- a valid authorization exists for the persistent executor Actor;
- an attacker receives an executor-like session/role;
- the attacker attempts to reuse the authorization.

Observed:
- World 8 safe rate: `1.0`
- hardened session-scoped baseline failure exposed: `1.0`

Interpretation:
The reference World 8 model binds authorization to persistent Actor identity rather than only to session role.

### CF2 — Stale fence after restart and lease/fence rotation

Combination:
- first valid effect commits;
- runtime restarts;
- executor session is replaced;
- a new fence is issued;
- the old fencing token is reused for a second effect.

Observed:
- World 8 safe rate: `1.0`
- hardened baseline without fencing accepts the second effect: `1.0`

Interpretation:
The reference model rejects a stale writer after restart/rotation. This is targeted mechanism evidence, not a proof of distributed linearizability.

### CF3 — Restart followed by evidence tampering

Combination:
- a valid effect commits;
- runtime restarts;
- a committed receipt/log attribution is tampered after restart;
- reconstruction/audit is attempted.

Observed:
- World 8 tamper detection/safe rate: `1.0`
- hardened mutable-audit baseline misses the tamper: `1.0`

Interpretation:
The reference model preserves verification across restart and detects the altered receipt chain.

## Valid paths / false denies

All valid reference paths passed at rate `1.0`:
- normal governed effect;
- provider/session replacement with persistent Actor unchanged;
- restart → reconstruct → obtain new fence → second valid effect.

Reported reference false-deny rates:
- normal: `0.0`
- session swap: `0.0`
- restart/reconstruct: `0.0`

## Methodological limitation

This gate is **directed and deterministic**, not a randomized or exhaustive compound-fault campaign. The 1,000 trials vary seeds/identifiers but execute the same three fault structures. Therefore the trial count must not be presented as 3,000 independent fault topologies or as coverage of arbitrary combinations.

The hardened baseline is intentionally missing the specific differentiated mechanism in each case (persistent Actor-bound authorization, fencing, or tamper-evident receipts). Therefore the baseline-failure rate demonstrates mechanism necessity in these scenarios; it does not establish general superiority over production orchestration frameworks.

## Claim ceiling

Supported:
- the three directed compound scenarios are caught by the complete reference model;
- valid reference paths in the same gate did not produce false denies;
- the corresponding deliberately mechanism-deficient reference baseline exposes the expected failure.

Not supported:
- deployed runtime compound-fault resilience;
- random/adversarial schedule coverage;
- distributed linearizability;
- exactly-once provider effects;
- superiority over external agent frameworks.

## E4 remaining work

- [ ] runtime-bound negative controls for authorization predicates;
- [ ] runtime-bound stale-fence / lease-rotation negative controls in an isolated or rollback-safe environment;
- [ ] full hash-chain verification negative control beyond row-update immutability;
- [ ] clean crash/restart/restore before new write capability;
- [ ] randomized or enumerated compound-fault schedules over runtime-bound mechanisms;
- [ ] quantitative false-deny and valid-path overhead at runtime;
- [ ] preserve surviving faults as failures instead of redefining the claim.

E4 remains **PARTIAL**, not COMPLETE.
