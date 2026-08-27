# World 8 — Product Hunt Launch Packet v0.1

Date: 2026-08-27
Status: CONTENT READY / ACCOUNT UNVERIFIED / NOT SCHEDULED / NOT LAUNCHED

## Current Product Hunt requirements checked

Checked against current Product Hunt guidance on 2026-08-27:
- personal maker account required; company accounts cannot post;
- product must be live for strongest featuring eligibility;
- direct product URL should be used as primary link;
- product name should contain only the product name;
- tagline maximum: 60 characters;
- description maximum: 500 characters in the current launch guide;
- choose up to 3 launch tags/categories that strongly relate;
- thumbnail recommended: 240 × 240, under 3 MB;
- gallery: at least 2 images to be viewable, recommended 1270 × 760;
- launch may be saved as a draft or scheduled up to 30 days in advance;
- first maker comment is strongly recommended;
- do not ask people directly for upvotes.

Official references:
- https://help.producthunt.com/en/articles/479557-how-to-post-a-product
- https://www.producthunt.com/launch/preparing-for-launch
- https://help.producthunt.com/en/articles/9883485-product-hunt-featuring-guidelines
- https://help.producthunt.com/en/articles/2724119-how-to-schedule-a-post

## Product identity

**Name**

World 8

**Primary URL**

https://huggingface.co/spaces/Saeedfa/world8-demo

Reason: this is the current public, live, directly explorable product/demo surface. The canonical GitHub repository is private and therefore should not be the primary Product Hunt URL at this checkpoint.

**Pricing**

Free

**Availability**

Live public research demo / development pre-release / non-production

Do not label World 8 as production-ready.

## Recommended tagline

**Evidence-backed multi-agent forecasting architecture**

Length: 52 characters.

This stays inside the current 60-character Product Hunt limit and explains the product without hype.

### Alternate taglines

- Separate forecasts, decisions, and orders with evidence
- Auditable multi-agent forecasting with immutable receipts
- Multi-agent forecasting where prediction stays measurable

Use the recommended tagline unless a later Product Hunt preview demonstrates a material layout issue.

## Description — provider form

World 8 is a public research demo for an evidence-backed multi-agent forecasting architecture. It keeps Forecast, Decision, and Order as separate objects, preserves immutable forecast receipts, and evaluates calibrated ensembles under frozen historical replay. Explore measured results, negative ablations, lifecycle integrity, and reproducibility evidence—without live trading or profitability claims.

Provider form target: <= 500 characters.

## Recommended launch tags / categories

1. **Predictive AI**
2. **AI Agents**
3. **Fintech**

Fallback if Product Hunt's live taxonomy/form presents different available labels:
- Artificial Intelligence
- Developer Tools
- Fintech

Do not invent a category if the live form does not present it.

## Thumbnail

Required asset target:
- 240 × 240 px
- square
- static PNG preferred for v0.1
- under 3 MB
- minimal text
- strong readable `W8` / forecast-contract visual identity

Asset status: OPEN — media brief prepared separately.

## Gallery

At least two images are required for the gallery to be viewable.

Recommended v0.1 sequence:

1. **Architecture invariant** — `Forecast != Decision != Order`
2. **Frozen evidence** — BTC / ETH / SOL calibrated-vs-raw Brier result
3. **Evidence chain** — release -> Zenodo DOI -> frozen evidence -> lifecycle receipt
4. **Negative results matter** — correlation / disagreement / regime / shadow / risk-veto outcomes

Target dimensions:
`1270 × 760 px`

Asset status: OPEN — media brief prepared separately.

## Maker first comment

Hi Product Hunt — I'm Saeed, the maker of World 8.

World 8 started from a measurement problem I kept running into with multi-agent systems: prediction, decision, and execution are often collapsed into one output. When the result is wrong, it becomes hard to tell whether the forecast was wrong, the policy was wrong, risk intervened, or execution changed the outcome.

So World 8 treats **Forecast, Decision, and Order as separate objects**.

For this public demo I froze a historical replay rather than showing a polished black-box claim. The current evidence package includes:

- BTC / ETH / SOL hourly replay with provider checksums;
- calibrated-vs-raw probabilistic forecast evaluation;
- 2,000-replicate paired moving-block bootstrap intervals;
- negative and mixed ablations that are kept instead of hidden;
- an independent SPY / QQQ / GLD replication;
- 52,920 resolved Forecast Contracts with zero lifecycle-integrity failures;
- a Zenodo snapshot and reproducibility receipts.

The strongest result in this frozen study is that calibrated weighting reduced Brier loss relative to equal-weight raw aggregation for BTC, ETH, and SOL. The non-crypto replication points in the same direction, but its confidence intervals cross zero, so I'm not claiming universal cross-market superiority.

This is **not** a profitability claim and there is no live trading in this demo.

I'd especially value feedback on three questions:
1. Is separating Forecast / Decision / Order useful for how you build or evaluate agents?
2. Which evidence or failure mode would you want to see added next?
3. What would make the demo more useful as an agent-evaluation tool rather than just a research artifact?

Thanks for taking a look.

## Short maker reply / social announcement

World 8 is live as a public evidence-backed forecasting demo.

It separates Forecast, Decision, and Order, keeps immutable forecast receipts, and exposes both positive and negative replay results.

No live trading. No profitability claim. Just a measurable architecture and frozen evidence.

Demo:
https://huggingface.co/spaces/Saeedfa/world8-demo

## Product links to add after primary URL

- Zenodo snapshot: https://zenodo.org/records/22127650
- DOI: https://doi.org/10.5281/zenodo.22127650
- Hugging Face Collection: https://huggingface.co/collections/Saeedfa/world-8-6a902b1a3a05b0ab39990265

Canonical private source should not be presented as a public usage link until repository-visibility policy changes.

## Launch strategy

### Draft first

Create a Product Hunt **Draft** before scheduling. Review the real provider preview for:
- tagline wrapping;
- thumbnail readability;
- gallery ordering;
- category availability;
- link behavior;
- description truncation;
- maker attribution.

### Schedule only after

- [ ] personal Product Hunt account verified
- [ ] account has posting access
- [ ] primary Demo URL opens publicly
- [ ] thumbnail complete
- [ ] minimum two gallery images complete
- [ ] live Product Hunt preview reviewed
- [ ] maker identity correct
- [ ] final launch decision explicitly recorded

## Claim boundary

The Product Hunt launch MUST NOT claim:
- profitability;
- market-beating performance;
- production readiness;
- universal cross-market superiority;
- causal superiority of the architecture;
- general success of correlation control, regime detection, disagreement shrink, shadow cold-start, or risk veto;
- AGI, consciousness, or autonomous market intelligence.

## Current blocker

No Product Hunt account/profile could be verified through the connected Gmail or public search on 2026-08-27. No Product Hunt connector/plugin is installed. Do not invent a maker username.

Status remains `ACCOUNT_UNVERIFIED` until provider login is available.
