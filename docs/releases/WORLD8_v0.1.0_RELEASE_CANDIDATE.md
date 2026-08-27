# World 8 v0.1.0 — Foundation & DCP Baseline

Status: PUBLISHED DEVELOPMENT PRE-RELEASE / NON-PRODUCTION
Prepared: 2026-08-27
Published: 2026-08-27
Canonical repository: https://github.com/saeedfaai/world-8
GitHub Release: https://github.com/saeedfaai/world-8/releases/tag/V0.1.0
Frozen release branch: `release/v0.1.0`
Frozen release commit: `b14f2feea0fa233851a774d6ebd295b63cde75c0`

## Release intent

This is the first formal release in the new canonical `world-8` repository. It establishes the engineering foundation, architecture contracts, developer-admission model, identity/authority controls, validation tooling, and continuity/publication registry needed for developer-independent parallel development.

Per `docs/RELEASE_POLICY.md`, all World 8 `0.x` releases are development pre-releases and are not production claims.

## Included

- canonical World 8 architecture baseline
- architecture contracts and ADRs
- Development Control Plane onboarding / `START_HERE`
- Developer Admission workflow and validator
- Identity & Authority model and verifier
- lease / workspace / authorization evidence foundations
- Supabase migrations supporting governed development
- CI architecture validation
- external identity / publication / DOI lineage registry
- publishing architecture and next-channel roadmap

## Explicitly not claimed

This release does **not** claim:
- production-ready World 8
- complete society runtime
- complete Forecast Hall runtime
- complete Market Data service
- autonomous production trading
- production-grade distributed atomicity
- full security/load/chaos validation
- AGI, consciousness, legal personhood, or proven autonomous evolution

## Release title

**World 8 v0.1.0 — Foundation & Development Control Plane Baseline**

## Tag metadata

Published GitHub tag: `V0.1.0`.
Canonical future tag convention: lowercase `v`, e.g. `v0.1.0`.
The casing difference is preserved as historical metadata and should be corrected only by an explicit migration, not by silently rewriting history.

## Evidence boundary

This release is an engineering foundation / governed-development baseline. Runtime truth remains the deployed runtime; DCP is the governed development projection. Claims must stay within tested and documented evidence.

## Validation receipt

Release gate run: https://github.com/saeedfaai/world-8/actions/runs/33069284797

PASS on frozen release commit:
- Architecture validator
- Developer Admission validator
- Identity & Authority validator
- high-confidence secret-pattern scan

## Publication chain after GitHub Release

1. GitHub Release published from frozen release branch/commit.
2. Mark GitHub release metadata as **Pre-release** for `0.x` policy compliance.
3. Archive the exact snapshot on Zenodo as a new World 8 v0.1.0 record/version DOI.
4. Append the new record/DOI to `EXTERNAL_LINKS.md`; do not overwrite Z0-A or prior World 7/v6.2 records.
5. Mirror the release into the World 8 Hugging Face organization and Demo Space when created.
6. Use the exact tag/DOI in SSRN, Devpost, Product Hunt, Medium, LinkedIn, Reddit, Hacker News and OSF registration references.

## Gate checklist

- [x] Exact release commit frozen
- [x] CI / validators green on exact commit
- [x] secrets/privacy scan passed
- [x] release notes match shipped contents
- [x] evidence boundary reviewed
- [x] GitHub Release published
- [ ] GitHub release metadata marked Pre-release
- [ ] Canonical lowercase-tag migration decision recorded
- [ ] Zenodo snapshot + DOI created
- [ ] external registries synchronized

## Current publication status

GitHub Release object exists and is published. Its current provider metadata reports `prerelease: false`; this conflicts with the canonical `0.x` release policy and remains an explicit metadata-correction task. No production-readiness claim is authorized.
