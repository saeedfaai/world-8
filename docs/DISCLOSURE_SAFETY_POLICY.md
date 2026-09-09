# World 8 Disclosure Safety Policy

Status: **POLICY CANDIDATE / NON-CANONICAL UNTIL GOVERNED MERGE**

## Purpose

World 8 is already a public engineering repository and includes executable engineering artifacts. This policy does not attempt to make already-public history secret. It adds a **prospective disclosure gate** for future artifacts whose capability or misuse potential may exceed the public release ceiling.

This is a publication/distribution governance overlay. It does not add a sixth World 8 plane and does not change existing runtime semantics by itself.

## Core rule

> **Public architecture and evidence do not imply unrestricted publication of every executable capability.**

World 8 release/distribution decisions MUST consider what an artifact materially enables, not merely whether it is source code, documentation, a schema, a prompt, a test, an adapter or a deployment recipe.

## Disclosure classes

World 8 adopts a minimal disclosure vocabulary compatible with the World 9 CDRF:

- `D0 PUBLIC` — open internet distribution.
- `D1 REGISTERED_RESEARCH` — identified/scoped research access.
- `D2 CONTROLLED_REVIEW` — pinned reviewer package or sandbox; no production secrets.
- `D3 RESTRICTED` — named internal/approved collaborators only.
- `D4 CRITICAL_HOLD` — no source distribution by default; supervised evaluation only.

World 8 does not need to adopt World 9 Principal semantics to use this publication control.

## Mandatory pre-publication checks

Before a new artifact is promoted into a public release, mirror, archive, demo, paper supplement or public repository path, the release process MUST determine:

1. whether the artifact enables real credentials or privileged access;
2. whether it enables external effects beyond a safe research sandbox;
3. whether it materially lowers the effort required to build autonomous or high-impact operation;
4. whether it exposes secrets, private infrastructure, customer/company data or operational attack surface;
5. whether reproducibility can be satisfied with a narrower reviewer package;
6. whether independent review is required before public disclosure.

Unknown or materially disputed classification MUST NOT silently default to public release.

## Public release invariants

### DS-01 — Secret exclusion

Production secrets, private keys, live tokens and production authority material are never research publication artifacts.

### DS-02 — Capability-based disclosure

Documentation and diagrams receive the same disclosure-risk scrutiny as code if they materially enable restricted capability.

### DS-03 — No silent downgrade

An artifact classified above D0 cannot be moved to public distribution without a recorded reviewed reclassification.

### DS-04 — Historical honesty

Already-public Git commits, releases, Zenodo records and mirrors remain part of public history. The system MUST NOT claim retroactive secrecy.

### DS-05 — Claim-scoped reproducibility

Journal/research reviewers SHOULD receive only the source, tests, fixtures and environment necessary to evaluate the claim, excluding unrelated production effects and secrets.

### DS-06 — Separation of duties

For materially high-risk disclosure decisions, the artifact author or requesting Mason MUST NOT be the sole evaluator and promoter of its own public release.

## World 8 plane mapping

No sixth plane is introduced:

- Observation may identify disclosure/misuse risk signals.
- Development/Mason proposes release/distribution changes.
- Evidence/Governance evaluates disclosure classification and evidence.
- Promotion Authority decides activation/release status.
- Canonical Spine records governed activation/release references where applicable.
- Operational performs only the permitted distribution/runtime actions.

## Reviewer packages

A controlled reviewer package may include:

- exact pinned source snapshot;
- claim-relevant tests and fixtures;
- proof/mutation runners;
- hashes / environment lock;
- reproduction instructions;
- safety/use notice.

It SHOULD exclude production credentials, unrelated effectors, private data, unrestricted infrastructure access and other capability not required to review the claim.

## Relationship to World 9

World 9 proposes a richer Capability & Disclosure Risk Framework because its future Principal runtime may create stronger autonomous capability. World 8 needs only this minimal overlay now so that future World 9 integration does not inherit an unconditional assumption that all engineering artifacts are public by default.

## Claim boundary

This policy manages dual-use and disclosure risk. It does not assert consciousness, sentience, AGI, rebellion, inevitable loss of control, or production readiness.
