# World 8 Release & Versioning Policy

Status: CANONICAL POLICY
Effective: 2026-08-27

## Principle
GitHub Releases are immutable historical engineering checkpoints, not automatic claims of production readiness.

## Version classes
- `v0.1.x` — Foundation / DCP / Identity / Governance
- `v0.2.x` — Core runtime
- `v0.3.x` — Society runtime
- `v0.4.x` — Forecast Hall
- `v0.5.x` — Market Data / Evaluation / Risk integration
- `v0.6.x`–`v0.9.x` — integration, security, load, chaos, public demo and release hardening
- `v1.0.0` — production baseline only after explicit production exit criteria are passed

## Pre-release rule
All `0.x` World 8 releases are development releases and MUST be presented as pre-release/non-production unless a later ADR explicitly changes this policy.

## Evidence rule
A release title, README, Zenodo record, paper, demo, or external post MUST NOT claim capabilities beyond the evidence available on the exact tagged commit.

## Publication chain
1. Freeze exact GitHub commit.
2. Pass release gate and secret/privacy checks.
3. Create exact Git tag and GitHub Release.
4. Mark `0.x` releases as Pre-release in GitHub metadata.
5. Archive material releases on Zenodo and obtain a version DOI.
6. Append publication lineage; never overwrite prior records.
7. External mirrors/demos must point back to canonical GitHub and exact DOI/tag.

## Tag convention
Canonical tag spelling is lowercase `v`, e.g. `v0.1.0`.
Existing historical tags with different casing are preserved as historical facts and corrected only through explicit metadata migration; history must not be silently rewritten.
