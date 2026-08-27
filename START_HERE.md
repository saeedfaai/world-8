# START HERE — World 8 Developer Re-entry

1. Read `architecture/WORLD8_ARCHITECTURE.yaml` and current ADRs.
2. Query current World 8 DCP/NOW state; runtime evidence outranks stale prose.
3. Resolve your persistent Actor identity and execution identity.
4. Read Inbox/Attention, target Code Shadows, active leases, Diagnostic Memory, and relevant Work Capsule.
5. Run Mason Preflight before claiming governed work.
6. Do not write without valid Work Claim + Lease/Fencing/CAS where required.
7. Update tests, Change Packet, Code Shadow, diagnostics, realization status, Handoff and Postflight.
8. Breaking changes must be impact-analyzed and propagated before clean Postflight.

Resume key currently used by the live handoff layer: `W8R-20260827-R1`.

Do not place secrets, raw credentials, or private chain-of-thought in this repository.
