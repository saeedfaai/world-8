# START HERE — World 8 Developer Re-entry

1. Read `architecture/WORLD8_ARCHITECTURE.yaml` and current ADRs.
2. Query current World 8 DCP/NOW state; runtime evidence outranks stale prose.
3. Resolve your persistent Actor identity. Actor identity is independent from provider/model/session/channel.
4. If you are using the N-Mason Pool, reserve a pool slot first. Provider is only a routing hint until a real Actor Execution is created and bound.
5. Read Inbox/Attention, target Code Shadows, active leases, Diagnostic Memory, relevant Experience Packs, and the relevant Work Capsule.
6. Run Mason Preflight before governed work.
7. Search existing artifacts/contracts and create the Search Receipt before creating or extending components.
8. Create/claim the governed Work Item. A Work Claim identifies work; it does not grant code-write authority.
9. For code writes, register an isolated Workspace from the current canonical World 8 Git head and bind it to the Work Item. Never write directly to `main` during normal work.
10. Evaluate required qualifications separately from authorization. Qualification never implies permission.
11. Obtain scoped authorization through the unified Identity & Authority verifier. Default is DENY; explicit DENY/REVOKE wins.
12. Obtain Developer Admission v0.2 bound to exact Actor + Work + Workspace + authorization evidence.
13. Only after Admission may a write Lease be issued. In the current path that is Lease v3, which requires checked authorization evidence; the old bootstrap bypass is closed.
14. Use Lease/Fencing/CAS for governed writes.
15. Work on the isolated feature branch and run tests + PR/CI.
16. N-Mason workers mark assignments READY_FOR_REVIEW and enqueue them; concurrent coding is allowed but canonical merge is serialized.
17. A stale canonical base must be refreshed/rebased and re-evaluated before merge.
18. N-Mason automatic merge claim is fail-closed until GitHub branch protection/ruleset enforcement is independently verified.
19. After merge, update Change Packet, Code Shadow, diagnostics, realization status, Handoff and Postflight.
20. Breaking changes must be impact-analyzed and propagated before clean Postflight.
21. Record reusable engineering lessons in the Engineering Development Experience Pack; material errors and tooling/contract failures must enter Diagnostic Memory.

Core docs:

- Developer Admission: `docs/engineering/DEVELOPER_ADMISSION.md`
- Identity & Authority: `docs/engineering/IDENTITY_AUTHORITY.md`
- N-Mason Pool / serialized merge: `docs/engineering/N_MASON_POOL.md`

Important repaired incidents include Developer Admission ordering (`incident-64fe289e33fad6cb6ed5e964b3a2f9aa`) and authorization policy regressions recorded in Diagnostic Memory.

Resume key currently used by the live handoff layer: `W8R-20260827-R1`.

Do not place secrets, raw credentials, or private chain-of-thought in this repository.
