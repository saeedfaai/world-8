# World 8 Engineering Guardian v0.1

## Purpose

Engineering Guardian is the always-attached engineering companion for governed Mason sessions. It welcomes the Mason automatically, keeps a live view of Work/Workspace/Lease/Admission/Resume state, classifies the current engineering context, surfaces relevant Diagnostic Memory and Code Shadow evidence, mirrors existing hard gates, and prepares grounded dialogue context.

Guardian is **not an Actor**. It is a **SYSTEM SERVICE** with fixed attribution identity:

`service-world8-engineering-guardian`

Guardian has **no independent authority**. It cannot grant Authorization, Admission, Lease, merge permission, Promotion, or canonical mutation rights. Guardian events are advisory/audit receipts only and carry `authority_effect=NONE`.

## Runtime foundation

- `world8_guardian_companion_sessions`: one lightweight companion window per governed dev session. Companion state is reconstructable and must not become a second source of truth.
- `world8_guardian_context_events`: append-only Guardian event receipts.
- `world8_guardian_policy_revisions`: append-only policy revisions.
- `world8_guardian_attach_v1`: attach/create companion.
- `world8_guardian_welcome_v1`: Welcome Bundle.
- `world8_guardian_context_classify_v1`: deterministic context tags.
- `world8_guardian_awareness_snapshot_v1`: Work/Session/Workspace/Lease/Admission/canonical awareness.
- `world8_guardian_diagnostic_advisory_v1`: canonical Diagnostic Memory + Code Shadow + compatibility retrieval.
- `world8_guardian_context_bundle_v1`: grounded bundle for the current engineering context.
- `world8_guardian_context_observe_v1`: record context-aware observations/advisories.
- `world8_guardian_ask_v1`: dialogue context; no Brain is embedded in the DB service.
- `world8_guardian_policy_v1`: frozen policy manifest.

Guardian reuses canonical Actor, Work, Workspace, Authority, Admission, Lease, Resume/Scribe, Diagnostic Memory, Code Shadow and Dispatch truth. It must not create parallel registries for those domains.

## Welcome-first lifecycle

After `world8_dev_session_start_v1` creates the baseline `SESSION_START` checkpoint, the Guardian auto-attach trigger creates the companion and Welcome snapshot. A Mason should not need to discover where diagnostics, current Work, active conflicts or next-safe-action live.

Welcome should surface at minimum:

- Actor identity and current Work
- Workspace/branch/canonical head
- Qualification/Admission state when available
- Active leases/conflicts
- Resume/next-safe-action and checkpoint state
- context-scoped recent Diagnostic evidence
- applicable Code Shadow evidence
- current Guardian service identity and frozen policy revision

The Welcome snapshot is a point-in-time receipt. Safety decisions must use the **live** Scribe/Awareness result, not assume the Welcome snapshot stays current.

## Frozen policy revision

Current revision: `guardian-policy-v0.1`.

The policy is append-only and changes only through:

`Proposal -> Review -> ADR -> Approval -> Frozen Policy Revision -> Runtime Projection`

No hot-patch may silently change Guardian policy.

### v0.1 decisions

- Guardian kind: `SYSTEM_SERVICE`
- Guardian authority: `NONE`
- Companions: stateless/reconstructable windows over central canonical state
- Auto-fix: **disabled in v0.1**
- New Guardian-specific blocking policy: **disabled in v0.1**; Guardian may only mirror already-existing hard gates
- Message classes: `FACT`, `WARNING`, `SUGGESTION`, `POLICY`
- Warning/Policy claims require evidence refs
- No raw secrets and no private reasoning/chain-of-thought may be persisted

### Context precedence

1. Active Work
2. Artifact / DB Object / Public Contract
3. Code Shadow
4. File
5. Tool / Command
6. Error Signature
7. Tags
8. Git / Environment

### Preload

Safety-critical, scope-bound context is preloaded: Actor, Work, Workspace, Qualification, active leases/conflicts, latest checkpoint and recent relevant incidents. Full dependency graphs, long history, full ADR/playbook content and unrelated Code Shadows stay on-demand.

### Sync vs async observation

Synchronous checks are reserved for sensitive operations already governed by existing gates: canonical writes, schema/contract changes, authority actions, lease/lock acquisition, merge, deploy and release. Read/search/local isolated work may proceed without turning Guardian into a central execution bottleneck.

### Failure mode

If Guardian is unavailable, underlying canonical gates remain authoritative. Authority/schema/contract/lease/lock/merge/deploy/release/write-outside-workspace must remain fail-closed through their own systems. Read/search/local isolated workspace work may fail-open with explicit degraded-mode logging. A later version should add retroactive re-evaluation of actions performed during Guardian outage.

### Advice freshness

Guardian advice must become version/evidence aware. The v0.1 policy requires evidence reference, architecture version, schema version and expiry for durable advice. A version change makes prior advice `NEEDS_REVALIDATION`, not silently valid or silently deleted. Historical Diagnostic Memory remains immutable; Guardian freshness is a projection over it.

### Semantic overlap v0.1

Conflict awareness may use Artifact dependency, Work graph, DB object overlap, public-contract overlap and semantic-domain tags. Semantic embeddings may be added later but are not required for v0.1.

## Dialogue contract

`world8_guardian_ask_v1` returns grounded context for the attached Brain/assistant. User-visible answers should distinguish:

- `[FACT]` — directly read system state
- `[WARNING]` — grounded risk
- `[SUGGESTION]` — optional recommendation
- `[POLICY]` — frozen/existing policy

Guardian advice never implies Authorization.

## Deferred to later revisions

- audited overridable-block policy
- any form of auto-fix
- advanced semantic/embedding conflict detection
- Guardian outage retroactive reconciliation automation
- acknowledgment timeout/escalation policy
- large-scale sharding beyond current 100+ Mason target

## Core invariant

**Welcome first. Stay attached. Surface relevant evidence at the right moment. Never become Authority.**
