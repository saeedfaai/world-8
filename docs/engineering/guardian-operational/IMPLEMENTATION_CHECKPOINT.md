# Operational Guardian v0.1 — Implementation Checkpoint

Checkpoint status: DESIGN ARTIFACTS WRITTEN / IMPLEMENTATION NOT STARTED

Branch: `guardian-contract-v0.1`
Base: `main`
Repository: `saeedfaai/world-8`

## Completed

1. Read `START_HERE.md` and current architecture manifest.
2. Read existing `ENGINEERING_GUARDIAN.md` and confirmed it is a distinct advisory companion service with `authority_effect=NONE`.
3. Read current `N_MASON_POOL.md` and confirmed existing provider-independent Mason identity/execution/work/workspace/lease truth should be reused.
4. Froze new Operational Guardian design as a separate contract, not an overwrite of the existing Engineering Guardian.
5. Added machine-readable contract:
   - `architecture/contracts/guardian-operational-v0.1.yaml`
6. Added architecture decision:
   - `architecture/adr/ADR-0003-operational-guardian-boundary.md`
7. Added normative state-machine / forbidden-transition specification:
   - `docs/engineering/guardian-operational/STATE_MACHINES_v0.1.md`

## Current design status

`DESIGN_FROZEN / NOT_IMPLEMENTED / NOT_EVIDENCED / NOT_DEPLOYED`

No migration, runtime RPC, deployment or production schema claim has been made.

## Important existing-system boundary

Do not replace or silently widen the authority of `service-world8-engineering-guardian`.

The new Operational Guardian must remain distinct:

- Engineering Guardian: advisory/context/evidence companion, authority NONE.
- Operational Guardian: deterministic resource/orchestration kernel under frozen policy; still not canonical authority.

## Known tool/runtime limitation encountered

During re-entry, live Resume Board access through the available connector path was not available in this session. The runtime state was therefore NOT reconstructed or guessed from chat memory.

This limitation must not be interpreted as proof that no active Work/Session exists.

## Do not do next

- Do not deploy to Supabase production yet.
- Do not merge directly to `main`.
- Do not create a second Actor/Work/Workspace/Authority/Lease registry.
- Do not let Guardian directly write accepted Spine authority/history.
- Do not make LLM Advisor required for liveness.
- Do not implement mutable Gap status on `GapSignal`.
- Do not add distributed 2PC between Operational Ledger and Spine.

## Next safe action

Inspect existing migrations for:

1. N-Mason pool/assignment schema and lease conventions;
2. Engineering Guardian append-only event conventions;
3. authority/admission/fencing helpers;
4. existing diagnostic/error logging patterns.

Then draft a **schema-only migration candidate** for Operational Guardian objects on this branch, without applying it to the live Supabase project.

After the schema draft:

- write SQL-level forbidden-transition tests first;
- review for reuse vs duplicate truth stores;
- only then consider a governed runtime migration/admission path.

## Error / diagnostic logging rule

Every material implementation error, failed assumption, schema mismatch, migration failure, test failure, workaround and repair must be recorded while work happens. Do not erase repaired failures from history. Store concise operational facts and evidence; never store secrets or private chain-of-thought.
