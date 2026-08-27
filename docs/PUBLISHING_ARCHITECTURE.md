# World 8 — Publication Architecture

Status: ACTIVE ROADMAP
Owner: Saeed Farrokhi
Last updated: 2026-08-27

## Principle

GitHub is the canonical living source. Every external publication, demo, paper, competition entry, or distribution post must point back to the canonical World 8 GitHub repository and, when applicable, to the exact Zenodo DOI for the released snapshot.

**Flow:** Demo / Distribution → GitHub canonical source → Zenodo DOI / immutable scientific snapshot.

## Priority 1 — Hugging Face

Create a World 8 organization or account and establish the AI-native public surface:
- `world8-core`
- `world8-forecast-hall`
- `world8-market-data`
- `World 8 Demo` Space

Purpose: public AI/agent/model community presence, runnable demos, lightweight artifacts, and direct links back to GitHub canonical source.

## Priority 2 — GitHub / Canonical

Repository: `https://github.com/saeedfaai/world-8`

GitHub remains authoritative for:
- source code
- architecture
- issues
- roadmap
- tests
- release gates
- release notes
- development-control evidence

External platforms must never become an independent competing source of truth.

## Priority 3 — Zenodo / DOI lineage

Each material World 8 release (`v0.1`, `v0.2`, ...) receives an immutable Zenodo snapshot and version DOI.

Rules:
- GitHub = living project.
- Zenodo = immutable citeable historical snapshot.
- DOI history is append-only; never overwrite older release records.
- Release notes must record GitHub commit/tag, Zenodo record, DOI, date, and evidence boundary.

## Priority 4 — SSRN

Prepare a technical Working Paper focused on World 8 forecasting/trading architecture:
- Forecast ≠ Decision ≠ Order
- Forecast Contract
- evaluator / UOP
- market data architecture
- risk and portfolio veto boundary
- weighted ensemble and calibration
- reproducibility and failure modes

SSRN is a publication surface, not canonical source; the paper must link to GitHub and the matching DOI.

## Priority 5 — Product Hunt

Launch only after a working public World 8 demo exists.

Candidate title: **World 8 — Persistent Multi-Agent Forecasting Architecture**

Product Hunt is a product-launch/discovery surface, not a repository or evidence store. Launch materials must point to the demo, GitHub, and DOI.

## Priority 6 — Devpost

Maintain a complete World 8 project profile and submit purpose-built variants to relevant AI / Agents / FinTech / Autonomous Systems hackathons.

Competition submissions are derivative release surfaces and must identify the exact World 8 release/tag they use.

## Priority 7 — Medium

Publish understandable narrative/technical articles, including:
- What is World 8?
- Why Forecast and Decision are different objects
- Why Majority Vote is insufficient for multi-agent intelligence
- Persistent identity outside replaceable AI brains

Every article should route readers to Demo/Hugging Face → GitHub → DOI.

## Priority 8 — LinkedIn + Reddit + Hacker News

These are distribution layers, not storage/canonical layers.

Use them to distribute release announcements, technical essays, experiments, demos, review requests, and falsification challenges. Every post should link inward to World 8 canonical surfaces.

## Priority 9 — OSF

Use only for freeze-style scientific registration / registration evidence where useful, not as the main World 8 home.

Any OSF registration must identify the exact GitHub commit/tag and Zenodo DOI it freezes.

## Release sequence

1. Freeze exact GitHub commit.
2. Pass release gate / tests / evidence-boundary review.
3. Create GitHub tag + GitHub Release.
4. Archive exact release snapshot on Zenodo and capture DOI.
5. Update `EXTERNAL_LINKS.md` append-only publication lineage.
6. Publish/update Hugging Face organization/repos/Space.
7. Publish SSRN paper when the relevant technical package is mature.
8. Launch Product Hunt only when a usable demo exists.
9. Distribute through Medium, LinkedIn, Reddit, Hacker News, Devpost.

## Security boundary

Never copy secrets, credentials, private datasets, raw DNA/genetic data, claim/recovery URLs, API keys, private keys, session cookies, or confidential operational data into public publication surfaces.

## Canonicality rule

**Parallelize distribution; serialize truth.**
