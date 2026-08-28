# World 8 Engineering Coding Entry Gateway v0.4

Status: **DESIGN FROZEN / LOCAL NON-CANONICAL CANDIDATE / NOT DEPLOYED**

This extends the existing World 8 Academy v0.3. It does not create a second Academy, session truth, authority system, development plane, or Git repository.

## Core lifecycle

`Execution/Login -> Dev Session -> Guardian -> Academy Coding Entry -> Qualification -> Authorization -> Admission v3 -> Pre-write Recovery -> Lease v5 -> Code -> Independent Conformance`

The existing `world8_actor_executions` row is the fresh login identity. A new Academy Coding Entry Receipt is short-lived and bound to the exact Actor + Execution + Work + Workspace + Dev Session + Preflight + Qualification + canonical head + current context evidence.

**Academy Entry never grants Authority.** It confirms that the current execution has loaded and accepted current governed development context. Persistent Qualification remains separate.

## Required context

Entry must be backed by existing evidence for current architecture, Inbox/Messages, Attention, access state, continuity/Resume/Checkpoint, Diagnostic Memory, current Academy Code Shadow, Guardian attachment, mission/Work, Workspace and canonical head. References are bound; these truths are not copied into a parallel store.

## Recovery before write

Before a write Lease can be issued, the exact Entry must be paired with a Pre-write Recovery Receipt.

- `CODE_ONLY`: immutable Git/canonical baseline + crash-safe checkpoint.
- `DB_TOUCHING`: the above plus current DB runtime snapshot and an explicit restore/compensation strategy reference.

A DB runtime inventory is evidence, not by itself a promise that arbitrary data mutation is reversible.

## Correctness boundary

Entry PASS means the execution may attempt governed work after separate Authorization/Admission/Lease gates. It does not certify the resulting code. Post-work correctness remains the responsibility of independent tests, conformance review, PR/CI, Handoff and Postflight.

## Idempotency

Entry semantic identity excludes volatile timestamps. Exact retry returns the existing PASS receipt. A changed semantic context for the same Execution causes `ACADEMY_ENTRY_IDEMPOTENCY_COLLISION`; the coder must refresh/re-enter rather than silently overwrite its entry evidence.
