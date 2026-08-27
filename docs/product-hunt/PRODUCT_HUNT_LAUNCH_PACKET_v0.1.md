# World 8 — Product Hunt Launch Packet v0.1

Date: 2026-08-27
Status: READY FOR MEDIA / ACCOUNT VERIFICATION / NOT LAUNCHED

## Canonical launch surface

Primary product URL:
https://huggingface.co/spaces/Saeedfa/world8-demo

Canonical repository:
https://github.com/saeedfaai/world-8

Release:
https://github.com/saeedfaai/world-8/releases/tag/V0.1.0

Zenodo DOI:
https://doi.org/10.5281/zenodo.22127650

SSRN:
https://papers.ssrn.com/sol3/papers.cfm?abstract_id=7359740
Status: submitted / under SSRN staff review

## Product Hunt fields

### Product name
World 8

### Tagline
Persistent multi-agent forecasting with auditable evidence

Length target: <= 60 characters.

### Description
World 8 is an evidence-backed research demo for multi-agent forecasting architecture. It separates Forecast, Decision, and Order, preserves immutable forecast receipts, and exposes reproducible replay results, lifecycle integrity, calibrated ensemble evaluation, negative ablations, and frozen research evidence.

Keep the Product Hunt form description within the live 500-character limit.

### Pricing
Free

### Availability
Live / available now

### Candidate launch tags
Use at most three, subject to exact labels available in the live Product Hunt form:
1. Artificial Intelligence
2. Fintech
3. Developer Tools

### Maker
Saeed Farrokhi

Use a personal Product Hunt account, not a company/brand account.

## First comment draft

Hi Product Hunt — I’m Saeed, the maker of World 8.

World 8 started from a simple architectural problem: in many AI-agent systems, a forecast, a decision, and an execution action get collapsed into one opaque output. That makes it difficult to audit what actually failed, reproduce evaluations, or distinguish a bad forecast from a bad decision policy.

This public demo shows a different approach: Forecast, Decision, and Order are separate objects with explicit lifecycles and evidence boundaries. The current release includes immutable forecast receipts, deterministic historical replay, calibration-aware ensemble evaluation, lifecycle-integrity checks, and retained negative results rather than only favorable findings.

The current public release is a development/research baseline — not a production trading system and not a profitability claim. I’d especially value feedback on the architecture, evidence model, reproducibility, and how the demo can become more useful to researchers and agent builders.

Demo: https://huggingface.co/spaces/Saeedfa/world8-demo
Research snapshot: https://doi.org/10.5281/zenodo.22127650

## Claim boundary

Allowed:
- persistent/evidence-backed multi-agent forecasting architecture;
- Forecast != Decision != Order;
- deterministic historical replay and lifecycle integrity;
- calibrated ensemble improvement in the frozen crypto replay;
- retained negative/mixed ablations;
- non-production research/development baseline.

Do not claim:
- live-trading profitability;
- production readiness;
- universal cross-market superiority;
- causal architectural superiority;
- autonomous market intelligence / AGI.

## Product Hunt current provider requirements captured 2026-08-27

Source: Product Hunt Help Center / Launch Guide.

- personal account required;
- account must generally be at least one week old before posting, unless provider grants earlier access through its current onboarding/newsletter route;
- direct product URL required;
- product name only in the name field;
- tagline max 60 characters;
- description max 500 characters;
- up to 3 launch tags recommended;
- square thumbnail, recommended 240x240 and under 3 MB;
- gallery requires 2+ images and recommends 1270x760;
- YouTube video optional;
- product should be live/usable to maximize eligibility for featuring;
- do not ask people to upvote; organic sharing and discussion are allowed;
- launch can be saved as a draft or scheduled; Product Hunt daily launch period begins at 12:01 AM Pacific Time.

References:
- https://help.producthunt.com/en/articles/479557-how-to-post-a-product
- https://www.producthunt.com/launch/preparing-for-launch
- https://help.producthunt.com/en/articles/9883485-product-hunt-featuring-guidelines
- https://help.producthunt.com/en/articles/771527-personal-account-vs-company-account

## Media asset specification

### Thumbnail
- 240x240 square
- simple World 8 mark / W8 identity
- legible at small size
- no dense text
- under 3 MB

### Gallery image 1 — Architecture
- 1270x760
- headline: `Forecast ≠ Decision ≠ Order`
- show the three-stage boundary with Evidence Receipts and independent Evaluator
- footer: `World 8 v0.1.0 — Development / Research Baseline`

### Gallery image 2 — Evidence
- 1270x760
- headline: `Auditable forecasts. Frozen evidence.`
- show: BTC / ETH / SOL replay, lifecycle `52,920 RESOLVED / 0 integrity failures`, calibrated-vs-raw Brier improvements, and negative/mixed ablations retained
- include DOI `10.5281/zenodo.22127650`

### Optional gallery image 3 — Public surfaces
- 1270x760
- show Demo -> GitHub -> Zenodo DOI -> SSRN pipeline
- emphasize `Parallelize distribution; serialize truth.`

## Remaining launch gates

- [x] live public demo
- [x] Product Hunt copy packet prepared
- [x] claim boundary prepared
- [x] current provider content requirements verified
- [ ] thumbnail created
- [ ] at least two 1270x760 gallery images created
- [ ] Product Hunt personal maker account/login verified
- [ ] account posting eligibility verified
- [ ] Product Hunt draft created
- [ ] exact preview reviewed
- [ ] explicit launch-date decision
- [ ] launch

No launch should occur until the preview is reviewed against this packet and the product page points to the live Hugging Face demo.