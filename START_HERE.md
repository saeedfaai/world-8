# START HERE — World 8 Developer Re-entry

1. Read `architecture/WORLD8_ARCHITECTURE.yaml` and current ADRs.
2. Query current World 8 DCP/NOW state; runtime evidence outranks stale prose.
3. Resolve your persistent Actor identity and execution identity.
4. Read Inbox/Attention, target Code Shadows, active leases, Diagnostic Memory, relevant Experience Packs, and the relevant Work Capsule.
5. Run Mason Preflight before governed work.
6. For code writes, register an isolated workspace against the canonical World 8 Git repository. Never write directly to `main` during normal work.
7. Evaluate required qualifications separately from authorization. Qualification never implies permission.
8. During the v0.1 staged rollout, Developer Admission receipts are evidence; code-write authorization remains fail-closed until the unified Identity & Authority verifier is implemented.
9. Do not write governed artifacts without the applicable Work Claim + Lease/Fencing/CAS controls.
10. Work on a feature branch, then use PR/CI/conformance checks before canonical merge.
11. Update tests, Change Packet, Code Shadow, diagnostics, realization status, Handoff and Postflight.
12. Breaking changes must be impact-analyzed and propagated before clean Postflight.
13. Record reusable engineering lessons in the Engineering Development Experience Pack; material errors must enter Diagnostic Memory.

Developer Admission documentation: `docs/engineering/DEVELOPER_ADMISSION.md`.

Resume key currently used by the live handoff layer: `W8R-20260827-R1`.

Do not place secrets, raw credentials, or private chain-of-thought in this repository.
