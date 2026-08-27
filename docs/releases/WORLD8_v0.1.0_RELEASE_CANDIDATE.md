# World 8 v0.1.0 — Foundation & DCP Baseline

Status: RELEASE CANDIDATE / NOT YET PUBLISHED AS GITHUB RELEASE
Prepared: 2026-08-27
Canonical repository: https://github.com/saeedfaai/world-8

## Release intent

This is the first formal release candidate in the new canonical `world-8` repository. It establishes the engineering foundation, architecture contracts, developer-admission model, identity/authority controls, validation tooling, and continuity/publication registry needed for developer-independent parallel development.

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

## Proposed Git tag

`v0.1.0`

## Evidence boundary

This release is an engineering foundation / governed-development baseline. Runtime truth remains the deployed runtime; DCP is the governed development projection. Claims must stay within tested and documented evidence.

## Publication chain after GitHub Release

1. Publish GitHub Release from the exact approved commit/tag.
2. Archive the exact snapshot on Zenodo as a new World 8 v0.1.0 record/version DOI.
3. Append the new record/DOI to `EXTERNAL_LINKS.md`; do not overwrite Z0-A or prior World 7/v6.2 records.
4. Mirror the release into the World 8 Hugging Face organization and Demo Space when created.
5. Use the exact tag/DOI in SSRN, Devpost, Product Hunt, Medium, LinkedIn, Reddit, Hacker News and OSF registration references.

## Gate checklist

- [ ] Exact release commit frozen
- [ ] CI / validators green on exact commit
- [ ] secrets/privacy scan passed
- [ ] release notes match shipped contents
- [ ] evidence boundary reviewed
- [ ] Git tag `v0.1.0` created
- [ ] GitHub Release published
- [ ] Zenodo snapshot + DOI created
- [ ] external registries synchronized

## Current publication status

The repository currently has no GitHub Release object. This file is the release package; publication remains pending until a GitHub Release write path is available and the exact commit passes the gate above.
