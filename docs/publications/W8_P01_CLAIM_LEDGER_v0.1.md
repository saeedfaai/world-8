# W8-P01 — Claim Ledger v0.1

Date: 2026-08-27  
Status: **ACTIVE / BOUND TO EVIDENCE FREEZE v0.1**  
Evidence base: `34ed68b6e04c548e7ee14aa16e0e3eecdb1b31f0`  
Freeze ref: `freeze/w8-p01-evidence-v0.1`

This ledger defines what the manuscript may and may not say. A sentence in the paper that materially strengthens one of these claims requires a new evidence receipt and a freeze revision.

## C1 — Persistent Actor is distinct from provider/session identity

**Allowed**

World 8 models domain Actor identity independently from transient provider/session/runtime identity, and the frozen conformance/reference/runtime evidence exercises this separation.

**Evidence**
- E1 actor-binding ablation/fault families.
- E2 provider/session replacement invariant across Company and Trading adapters.
- E3 canonical `world8_authorize_v1` and actor/execution/workspace binding source+runtime verification.
- E5 AutoGen runtime-swap comparison.

**Do not say**
- persistent identity is a novel computer-science concept;
- World 8 uniquely solves identity;
- the frozen evidence proves identity security against all impersonation attacks.

## C2 — Authorization is evaluated at the governed effect boundary

**Allowed**

The evaluated World 8 path separates proposal/prediction from approval/decision and from effect/order, and uses explicit authorization checks before governed effects.

**Evidence**
- E2 Company: `QUOTE_PROPOSAL != PURCHASE_APPROVAL != SUPPLIER_ORDER_EFFECT`.
- E2 Trading: `FORECAST != TRADE_DECISION != SYNTHETIC_ORDER`.
- E3 default-DENY / explicit-DENY runtime probes.
- E5 stolen-approval fault family.

**Do not say**
- RBAC/ABAC/access control are novel;
- every World 8 action is formally verified;
- authorization alone guarantees safe autonomous behavior.

## C3 — Fencing/lease boundaries reject the tested stale executor cases

**Allowed**

The frozen reference and runtime evidence shows fencing-token enforcement rejects the tested stale-executor/fencing cases.

**Evidence**
- E1/E4 directed and compound fault families.
- E3 runtime stale-token rejection.
- canonical sequencer lease source recovered and source-integrity checked.
- E5 stale-fence external-runtime case.

**Do not say**
- fencing tokens are novel;
- the implementation eliminates all concurrency races;
- the evidence proves distributed consensus or linearizability of the whole system.

## C4 — Tamper-evident evidence detects the tested mutation/tamper cases

**Allowed**

The frozen evidence supports detection/blocking of the tested evidence tamper cases through append-only/chained evidence and immutable effect-receipt guards.

**Evidence**
- E1 tamper-evidence mechanism and ablation.
- E3 effect-receipt mutation block and append-only journal probe.
- E4 mutation/compound tests.
- E5 audit-tamper external-runtime case.

**Do not say**
- hash chains are novel;
- the evidence store is cryptographically unbreakable;
- the current design replaces external notarization or trusted timestamping.

## C5 — Recovery is a governed precondition before resumed effect capability in tested paths

**Allowed**

The tested recovery path reconstructs governed state/evidence before resumed effect capability, and the frozen fault suite includes effect-before-recovery as an explicit failure family.

**Evidence**
- E2 restart/reconstruct invariant.
- E3 `resume_capsule_v2` runtime reconstruction probe.
- E4 restart/reconstruct valid path and compound faults.
- E5 effect-before-recovery case using actual AutoGen runtime recreation.

**Do not say**
- all crash states are recoverable;
- recovery is formally complete under arbitrary storage corruption;
- no data can ever be lost.

## C6 — One shared governed kernel passed the same conformance suite across two materially different Society adapters

**Allowed**

The same executable governed kernel passed the same eight-invariant conformance suite across Company and Trading Society adapters, with 1,000 trials per Society and identical all-pass conformance vectors in the frozen E2 experiment.

**Evidence**
- E2 run `33103973441`.
- result SHA256 `ac3b90efabd1e83c36e388c0bda61dfff5ba325c568a50ad579f74dd1f8f9704`.

**Do not say**
- two adapters prove universal domain generality;
- the experiment validates all proposed World 8 Societies;
- Trading performance was evaluated in W8-P01.

## C7 — Hardened generic controls erase several apparent advantages

**Allowed**

After the baseline was strengthened with revoke checks, CAS/stale-write protection, durable idempotency, approval scope and durable audit, it matched World 8 on those generic mechanisms in the frozen reference experiment. The paper therefore does not claim those mechanisms individually as World 8 advantages.

**Evidence**
- E1 run `33103617400`.

**Importance**
This negative result is part of the contribution: it narrows the claim to the mechanisms that remained differentiated under the frozen protocol.

## C8 — Tested World 8 governance controls are composable over AutoGen Core 0.7.5

**Allowed**

In the frozen executable external baseline, a transparent World-8-style governance wrapper over real AutoGen Core 0.7.5 closed the four frozen governance fault families while retaining a zero false-deny rate on the frozen valid paths.

**Evidence**
- public run `33109497608`.
- 2,000 runtime cases.
- summary SHA256 `7a2a84bdc385caf708b0e5e87e6c41a8761163900b0266c825ccc016eb2d15e7`.

**Do not say**
- World 8 beats AutoGen;
- AutoGen is insecure;
- the wrapper improves AutoGen performance generally;
- the result applies to versions other than the pinned/tested configuration without further evidence.

## C9 — Valid-path cost is non-zero and must be reported

**Allowed**

The reference model measured a small additional governance-path cost: approximately 7 policy checks / 9 evidence records for World 8 versus 6 / 8 for the hardened baseline on the frozen valid path.

**Do not convert this into**
- a latency claim;
- a throughput claim;
- a production cost estimate.

No wall-clock or production-scale benchmark supports those claims yet.

## C10 — Novelty is in the bounded composition/contract, not the primitive mechanisms

**Allowed framing**

The paper studies a particular composition of provider-independent Actor identity, effect-time authority, fencing, tamper-evident evidence, recovery gating, and domain adapters under one shared governed kernel, together with a falsification-oriented evidence program.

**Prior-art exclusions**
The manuscript must explicitly acknowledge that the following are established prior art and are not individually claimed as novel:
- leases and fencing tokens;
- optimistic concurrency/CAS;
- idempotency;
- RBAC/ABAC/access-control policy;
- checkpoints and recovery;
- event sourcing / append-only logs / hash chains;
- actor runtimes and agent identifiers;
- tracing/observability;
- multi-agent messaging/orchestration.

See `docs/publications/W8_P01_RELATED_WORK_REGISTRY.md`.

# Prohibited global transformations

The manuscript must never transform the frozen evidence into any of the following:

1. “World 8 is production ready.”
2. “World 8 is profitable” or “beats markets.”
3. “World 8 is generally more secure than AutoGen/LangGraph/OpenAI Agents SDK.”
4. “World 8 proves universal multi-agent governance.”
5. “World 8 guarantees no unauthorized effects.”
6. “World 8 mechanisms are all novel.”
7. “The architecture proves AGI, consciousness, personhood, or autonomous economic agency.”
8. “The market paper W8-P02 proves the architecture paper W8-P01.”
9. “Two Society adapters establish domain-general intelligence.”
10. Any causal or superiority claim not tied to a frozen comparator and metric.

# Paper-to-paper ownership

W8-P01 owns architecture/governance evidence.  
W8-P02 / SSRN `7359740` owns market forecasting/performance evidence.

Before final submission, run a text-level overlap audit against the frozen W8-P02 manuscript. Reusing unavoidable definitions is acceptable with appropriate self-citation/attribution; reusing Results narrative, tables, figures, or conclusions as if new is prohibited.
