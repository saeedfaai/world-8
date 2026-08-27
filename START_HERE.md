# START HERE — World 8 Developer Re-entry

## Reconnect / new Room / next day

1. Query the **Resume Board** with `world8_dev_resume_board_v1` before starting new work.
2. Open the relevant **Resume Capsule** with `world8_dev_resume_capsule_v2(work_id)`.
3. Read its latest Checkpoint first, then journal tail, Diagnostic Memory, Work Capsule and Code Shadow. Do not reconstruct missing progress from chat memory.
4. Verify the persisted `next_safe_action` against the current canonical Git head. If the Workspace base is stale, record a `RECONNECT` Checkpoint and refresh before writing.
5. Read `architecture/WORLD8_ARCHITECTURE.yaml`, current ADRs, `docs/engineering/CRASH_SAFE_DEVELOPMENT.md`, and `docs/engineering/ENGINEERING_GUARDIAN.md`.

## Governed coding lifecycle

6. Resolve persistent Actor identity. Actor identity is independent from provider/model/session/channel.
7. If using N-Mason, reserve a pool slot. Provider is a routing hint only until a real Actor Execution is ACTIVE and bound.
8. Read Inbox/Attention, target Code Shadows, active Leases, Diagnostic Memory and relevant Experience Packs.
9. Run Mason Preflight.
10. Search existing artifacts/contracts and create the Search Receipt before creating/extending components.
11. Create/claim the governed Work Item. New developer Work is Crash-Safe by default (`crash_safe_required=true`). A Work Claim identifies work; it does not grant code-write authority.
12. Register an isolated Workspace from the current canonical World 8 Git head. Never write directly to `main` during normal work.
13. **Session Start:** call `world8_dev_session_start_v1` for the Work/Actor/Workspace. It atomically writes START Journal evidence plus the baseline `SESSION_START` Checkpoint.
13a. **Engineering Guardian Welcome:** Guardian auto-attaches to the governed Session after the baseline checkpoint. Read/refresh `world8_guardian_welcome_v1(session_id)` and verify the live Awareness/Scribe state before sensitive work. Guardian is `service-world8-engineering-guardian`, a SYSTEM SERVICE with `authority_effect=NONE`; it never grants permission.
14. Evaluate Qualification separately from Authorization. Qualification never implies permission.
15. Obtain scoped Authorization through the unified Identity & Authority verifier. Default is DENY; explicit DENY/REVOKE wins.
16. Obtain Developer Admission v0.2 bound to exact Actor + Work + Workspace + authorization evidence.
17. **Only after Admission may a write Lease be issued.** Current governed write path is Lease v3 with checked authorization evidence; bootstrap bypass is closed.
18. Use Lease/Fencing/CAS for governed writes.

## While coding

19. **Journal while work happens.** Material code, migration, decision, test, error/repair, rebase, and next-action changes must be persisted, not reconstructed later.
20. Use atomic Checkpoint calls for material milestones. Default interval is 5 minutes; Scribe Guard treats overdue Checkpoint state as `CHECKPOINT_INTERVAL_EXCEEDED`.
21. Each Checkpoint must include a non-empty `next_safe_action` plus completed/remaining work, known issues and evidence refs.
22. Keep Guardian attached. As Work/Artifact/File/DB object/Tool/Error context changes, use Guardian context/observation/dialogue surfaces so relevant Diagnostic Memory, Code Shadow, conflicts and existing hard gates are surfaced automatically. Treat Welcome as a snapshot; live safety state wins.
23. Guardian messages distinguish `FACT / WARNING / SUGGESTION / POLICY`; WARNING/POLICY requires evidence. Guardian v0.1 has no auto-fix and no new independent block authority: it only mirrors existing hard gates.
24. N-Mason `READY_FOR_REVIEW` requires Scribe PASS and a post-CODING `MILESTONE`, `COMMIT`, `TEST`, or `MANUAL` Checkpoint. A baseline Session Start is not enough.
25. Run tests + PR/CI on the isolated feature branch.
26. Concurrent coding is allowed; canonical merge is serialized. A stale canonical base must be refreshed/rebased and re-evaluated immediately before merge.
27. N-Mason automatic merge claim remains fail-closed until GitHub branch protection/ruleset enforcement is independently verified.

## Close correctly

28. After merge, update Change Packet, Code Shadow, diagnostics and realization state.
29. Close the development Session with `world8_dev_session_close_v1`. It creates the final `BEFORE_HANDOFF` Checkpoint and CLOSURE Journal evidence. The attached Guardian companion becomes closed/reconstructable with the Session.
30. Record Handoff. Crash-Safe Handoff is blocked by `world8_dev_scribe_closure_guard_v1` until all relevant Sessions are closed/recovered and checkpoint-clean.
31. Run Postflight. Crash-Safe Postflight requires the closure guard plus a real Handoff. Breaking changes must also be impact-analyzed/propagated.
32. Record reusable lessons in the Engineering Development Experience Pack; material code/tooling/schema/governance failures must enter Diagnostic Memory.

## Core docs

- Engineering Guardian: `docs/engineering/ENGINEERING_GUARDIAN.md`
- Crash-Safe Development: `docs/engineering/CRASH_SAFE_DEVELOPMENT.md`
- Developer Admission: `docs/engineering/DEVELOPER_ADMISSION.md`
- Identity & Authority: `docs/engineering/IDENTITY_AUTHORITY.md`
- N-Mason Pool / serialized merge: `docs/engineering/N_MASON_POOL.md`

Important repaired incidents remain queryable in Diagnostic Memory; do not hide an error merely because it was repaired.

Do not place secrets, raw credentials, or private chain-of-thought in this repository.
