# START HERE — World 8 Developer Re-entry

1. Read `architecture/WORLD8_ARCHITECTURE.yaml` and current ADRs.
2. Query current World 8 DCP/NOW state; runtime evidence outranks stale prose.
3. Resolve your persistent Actor identity and execution identity.
4. Read Inbox/Attention, target Code Shadows, active leases, Diagnostic Memory, relevant Experience Packs, and the relevant Work Capsule.
5. Run Mason Preflight before governed work.
6. Create/claim the governed Work Item. A Work Claim reserves/identifies work; it does not grant code-write authority.
7. For code writes, register an isolated workspace against the canonical World 8 Git repository and bind it to that Work Item. Never write directly to `main` during normal work.
8. Evaluate required qualifications separately from authorization. Qualification never implies permission.
9. Obtain a Developer Admission receipt bound to the Actor + Work + Workspace. During the v0.1 staged rollout, requested code-write authorization remains fail-closed until the unified Identity & Authority verifier is implemented.
10. Only after Admission may a write Lease be issued. The staged `world8_dev_acquire_lease_v2` binds lease evidence to the Admission receipt; authorization enforcement becomes mandatory when the unified verifier is active.
11. Use Lease/Fencing/CAS for governed writes.
12. Work on a feature branch, then use PR/CI/conformance checks before canonical merge.
13. Update tests, Change Packet, Code Shadow, diagnostics, realization status, Handoff and Postflight.
14. Breaking changes must be impact-analyzed and propagated before clean Postflight.
15. Record reusable engineering lessons in the Engineering Development Experience Pack; material errors must enter Diagnostic Memory.

Developer Admission documentation: `docs/engineering/DEVELOPER_ADMISSION.md`.

Known ordering incident repaired in v0.1.1: `incident-64fe289e33fad6cb6ed5e964b3a2f9aa`.

Resume key currently used by the live handoff layer: `W8R-20260827-R1`.

Do not place secrets, raw credentials, or private chain-of-thought in this repository.
