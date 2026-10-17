# W8-P01 — Claim Ledger v0.2

Date: 2026-08-27  
Status: **ACTIVE / BOUND TO EVIDENCE FREEZE v0.1 / NOVELTY-HARDENED**  
Evidence base: `34ed68b6e04c548e7ee14aa16e0e3eecdb1b31f0`  
Freeze ref: `freeze/w8-p01-evidence-v0.1`  
Supersedes for manuscript wording: `W8_P01_CLAIM_LEDGER_v0.1.md`

Binding novelty addendum:
`docs/publications/W8_P01_NOVELTY_HARDENING_ADDENDUM_v0.1.md`

A manuscript sentence that materially strengthens one of these claims requires a new evidence receipt and, where numerical evidence changes, a freeze revision.

## C1 — World 8 evaluates Actor continuity across provider/session/runtime replacement

**Allowed**

World 8 models a logical domain Actor independently from transient provider/session/runtime identity, and the frozen E1–E5 program exercises that separation under the tested replacement and binding cases.

**Evidence**
- E1 actor-binding fault/ablation families.
- E2 provider/session replacement invariant in Company and Trading adapters.
- E3 canonical actor/authority bindings and runtime checks.
- E5 AutoGen runtime-swap comparison.

**Novelty ceiling after close prior-art review**
Provider/topology-independent agent identity is **not** claimed as novel by itself. The 2026 `agent://` identity preprint explicitly studies topology-independent stable agent identity, and current identity/delegation work such as AIP combines identity, authorization and provenance.

**Do not say**
- World 8 invented persistent agent identity;
- World 8 is the first provider-independent agent-identity scheme;
- stable identity across provider/topology changes is unique to World 8;
- the frozen evidence proves identity security against all impersonation or credential attacks.

## C2 — The evaluated path binds explicit authority to the governed effect boundary

**Allowed**

The evaluated World 8 path separates proposal/prediction from approval/decision and from effect/execution and checks explicit Actor/action/resource authority before the governed effect in the tested path.

**Evidence**
- E2 Company: `QUOTE_PROPOSAL != PURCHASE_APPROVAL != SUPPLIER_ORDER_EFFECT`.
- E2 Trading: `FORECAST != TRADE_DECISION != SYNTHETIC_ORDER`.
- E3 default-DENY / explicit-DENY runtime probes.
- E5 stolen-approval fault family.

**Novelty ceiling**
Normative governance, permissions, prohibitions, obligations, run-time norm enforcement, RBAC/ABAC, delegated authorization, and agent capabilities are established or contemporaneous prior art. The claim is about the **tested composition and exact effect boundary**, not the invention of authorization or agent governance.

**Do not say**
- World 8 introduced governance or norms to MAS;
- permissions/obligations/prohibitions are novel;
- delegated agent authorization is novel;
- every World 8 action is formally verified;
- authorization alone guarantees safe autonomous behavior.

## C3 — Fencing/lease boundaries reject the tested stale-executor cases

**Allowed**

The frozen reference and runtime evidence shows fencing-token enforcement rejects the tested stale-executor/fencing cases.

**Evidence**
- E1/E4 directed and compound fault families.
- E3 runtime stale-token rejection.
- canonical sequencer lease source recovery and integrity check.
- E5 stale-fence external-runtime case.

**Do not say**
- leases or fencing tokens are novel;
- the implementation eliminates all concurrency races;
- the evidence proves whole-system consensus or linearizability.

## C4 — Tamper-evident evidence detects/blocks the tested mutation cases

**Allowed**

The frozen evidence supports detection/blocking of the tested evidence-tamper cases through append-only/chained evidence and immutable effect-receipt guards.

**Evidence**
- E1 tamper-evidence mechanism and ablation.
- E3 effect-receipt mutation block and append-only journal probe.
- E4 mutation/compound tests.
- E5 audit-tamper external-runtime case.

**Do not say**
- hash chains or provenance records are novel;
- the evidence store is cryptographically unbreakable;
- local tamper evidence replaces external notarization or trusted timestamping.

## C5 — Recovery is a tested precondition before resumed effect capability

**Allowed**

The tested recovery path reconstructs governed state/evidence before resumed effect capability, and the frozen suite includes effect-before-recovery as an explicit failure family.

**Evidence**
- E2 restart/reconstruct invariant.
- E3 `resume_capsule_v2` reconstruction probe.
- E4 restart/reconstruct valid path and compound faults.
- E5 effect-before-recovery case using actual AutoGen runtime recreation.

**Do not say**
- checkpoints/recovery are novel;
- all crash states are recoverable;
- recovery is formally complete under arbitrary storage corruption;
- no data can ever be lost.

## C6 — One shared governed kernel passed the same frozen conformance suite across two Society adapters

**Allowed**

The same executable governed kernel passed the same eight-invariant conformance suite across Company and Trading Society adapters, with 1,000 trials per Society and identical all-pass vectors.

**Evidence**
- E2 run `33103973441`.
- result SHA256 `ac3b90efabd1e83c36e388c0bda61dfff5ba325c568a50ad579f74dd1f8f9704`.

**Do not say**
- two adapters prove universal domain generality;
- the experiment validates all possible Societies;
- Trading performance was evaluated in W8-P01;
- open multi-agent coordination itself is novel.

## C7 — Hardened generic controls erase several apparent advantages

**Allowed**

After the baseline was strengthened with revoke checks, CAS/stale-write protection, durable idempotency, approval scope and durable audit, it matched World 8 on those generic mechanisms in the frozen reference experiment.

**Evidence**
- E1 run `33103617400`.

**Interpretation**
This negative result is part of the contribution because it removes ordinary engineering hardening from the differentiated claim.

## C8 — The tested World 8 governance controls are composable over AutoGen Core 0.7.5

**Allowed**

In the frozen external baseline, a transparent World-8-style governance wrapper over real AutoGen Core 0.7.5 closed the four frozen governance fault families while retaining zero false denial on the frozen valid paths.

**Evidence**
- public run `33109497608`.
- 2,000 runtime cases.
- summary SHA256 `7a2a84bdc385caf708b0e5e87e6c41a8761163900b0266c825ccc016eb2d15e7`.

**Do not say**
- World 8 beats AutoGen;
- AutoGen is insecure;
- AutoGen cannot implement equivalent controls;
- the wrapper generally improves AutoGen performance;
- the result applies to untested AutoGen versions/configurations.

## C9 — Valid-path governance cost is non-zero and only structurally measured

**Allowed**

The reference model measured approximately 7 policy checks / 9 evidence records for World 8 versus 6 / 8 for the hardened baseline on the frozen valid path.

**Do not convert this into**
- latency;
- throughput;
- storage-cost;
- production operating-cost claims.

## C10 — Novelty framing: composition + contract boundary + evidence program

**Allowed framing**

W8-P01 evaluates a particular **effect-governance composition** in which:
1. a logical Actor is explicitly bound across transient execution contexts;
2. exact Actor/action/resource authority is checked at the governed effect boundary;
3. proposal/prediction is separate from approval/decision and effect/execution;
4. stale effectors are fenced;
5. governance evidence is tamper-evident;
6. effect capability is withheld until the tested recovery boundary passes;
7. the same frozen contract is exercised across distinct Society adapters; and
8. the controls are composed over an independent AutoGen Core runtime.

The empirical contribution is the **falsification-oriented evaluation of this composition**, including hardened negative controls that erase weaker apparent advantages.

**Prior-art exclusions — binding**
Do not claim individual novelty for:
- agents / MAS / open MAS;
- agent-oriented programming;
- multi-agent governance or normative systems;
- permissions, prohibitions, obligations, norms or enforcement;
- distributed norm management;
- persistent/stable/provider-independent/topology-independent agent identity in general;
- capability-bound identity or delegated agent authorization in general;
- RBAC/ABAC/access-control policy;
- leases/fencing/distributed locks;
- CAS/version checks;
- idempotency;
- checkpoints/snapshots/generic recovery;
- event sourcing / append-only logs / hash chains / provenance;
- actor runtimes and runtime agent identifiers;
- session memory / tracing / guardrails;
- multi-agent messaging/orchestration/coordination.

See:
- `docs/publications/W8_P01_RELATED_WORK_REGISTRY.md`
- `docs/publications/W8_P01_NOVELTY_HARDENING_ADDENDUM_v0.1.md`

# Prohibited global transformations

The manuscript must never transform the frozen evidence into:
1. “World 8 is production ready.”
2. “World 8 is profitable” or “beats markets.”
3. “World 8 is generally more secure/better than AutoGen, LangGraph, or OpenAI Agents SDK.”
4. “World 8 proves universal multi-agent governance.”
5. “World 8 guarantees no unauthorized effects.”
6. “World 8 invented persistent/provider-independent agent identity.”
7. “World 8 invented multi-agent governance/norm enforcement.”
8. “World 8 mechanisms are all novel.”
9. “The architecture proves AGI, consciousness, personhood, or autonomous economic agency.”
10. “The market paper W8-P02 proves the architecture paper W8-P01.”
11. “Two Society adapters establish domain-general intelligence.”
12. Any causal/superiority claim not tied to a frozen comparator and metric.

# Paper-to-paper ownership

W8-P01 owns architecture/governance evidence.  
W8-P02 / SSRN `7359740` owns market forecasting/performance evidence.

Before final submission, a text-level overlap audit against the frozen W8-P02 manuscript is mandatory. Reusing unavoidable definitions is acceptable with appropriate attribution; reusing Results narrative, tables, figures, or conclusions as if new is prohibited.
