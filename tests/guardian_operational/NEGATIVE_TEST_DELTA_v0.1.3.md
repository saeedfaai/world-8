# Operational Guardian v0.1.3 — Negative Test Delta

Status: TEST SPECIFICATION ONLY / NO RUNTIME PASS CLAIM
DCR: `architecture/proposals/DCR-0003-operational-guardian-leader-scope.md`

| ID | Scenario | Expected result |
|---|---|---|
| OG-N74 | Two contenders acquire leader lease for same `(world,society,primary)` concurrently | At most one ACTIVE holder; loser fails CAS/lease acquisition |
| OG-N75 | Stale Society A leader writes after Society A takeover advances epoch | REJECT with no event/projection mutation |
| OG-N76 | Society A leader epoch/fence is presented for Society B control write | REJECT cross-Society leader evidence |
| OG-N77 | Society A and Society B both have `guardian_epoch=7` | Allowed; epochs are independent and not globally ordered |
| OG-N78 | Society A failover occurs while Society B assignments/reservations are valid | Society B state remains unchanged |
| OG-N79 | Society A takeover audit query omits Society filter and fences Society B stale-looking work | REJECT/conformance failure; blast radius must be same leader domain only |
| OG-N80 | Executable schema uses one global `guardian_key='operational-guardian'` row as sole leader identity | REJECT/conformance failure |
| OG-N81 | Control event society differs from the leader row society while epoch numerically matches | REJECT |
| OG-N82 | Ordinary Guardian attempts to acquire/renew leadership for multiple Societies as one mutation | REJECT; ordinary leader mutation is one Society domain at a time |
| OG-N83 | New unapproved `guardian_shard_key` is used without deterministic routing DCR | REJECT |
| OG-N84 | Same aggregate is routed to two leader shard keys concurrently | REJECT; single deterministic writable leader domain required |
| OG-N85 | Failover in Society A globally increments a World-wide Guardian epoch | REJECT; no World-global operational fencing clock |

## Required mutation additions

Critical mutants that must be killed when executable tests exist:

1. replace Society-scoped leader PK with one global Guardian row;
2. skip society_id in leader validation;
3. treat guardian_epoch as globally comparable across Societies;
4. omit Society filter from takeover audit/fencing queries;
5. let Society A failover mutate Society B assignments/reservations/quarantines;
6. permit arbitrary new guardian_shard_key without deterministic routing policy;
7. allow one aggregate to be writable under two leader domains.

## Evidence rule

Runtime evidence requires actual concurrent leader acquisition, stale-write fencing, cross-Society failover isolation, and mutation kills against the implemented lease/takeover RPCs. Static text matching is not runtime HA evidence.
