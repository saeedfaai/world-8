# World 8 — Product Hunt Media Brief v0.1

Date: 2026-08-27
Status: READY FOR ASSET PRODUCTION

## Provider specifications

Current Product Hunt guidance:
- thumbnail: square, recommended `240 × 240`, under 3 MB;
- gallery: recommended `1270 × 760`;
- gallery needs at least `2` images to be viewable;
- optional YouTube or supported interactive-demo link may be added.

Source:
https://www.producthunt.com/launch/preparing-for-launch

## Visual system

Carry the current World 8 evidence-demo visual language:
- near-black / deep navy background;
- cyan / teal evidence accents;
- restrained white typography;
- amber only for evidence-boundary warnings;
- no fake trading screens;
- no profit arrows, money imagery, or exaggerated performance visuals;
- diagrams should communicate object separation, provenance, and auditability.

## Asset A — Thumbnail

Target: `240 × 240`

Concept:
- large `W8` glyph;
- three small connected nodes underneath or around it representing `Forecast`, `Decision`, `Order`;
- minimal or no small text;
- high contrast at tiny Product Hunt feed size.

Do not put numeric performance claims in the thumbnail.

## Asset B — Gallery 1: Core invariant

Target: `1270 × 760`

Headline:
**Forecast ≠ Decision ≠ Order**

Subhead:
`Keep prediction measurable when policy and execution change.`

Composition:
- three distinct cards/nodes;
- arrows Forecast → Decision → Order;
- beneath Forecast show tiny evidence labels: `data cutoff`, `probability`, `strategy version`, `hash`, `lifecycle`;
- Decision card: `costs`, `risk`, `portfolio`, `policy`;
- Order card: `execution artifact`;
- small footer: `Historical replay · no live trading`.

## Asset C — Gallery 2: Strongest measured result

Target: `1270 × 760`

Headline:
**Frozen replay. Measured uncertainty.**

Three side-by-side pairs of horizontal bars:

BTC:
- Equal-weight raw Brier `0.265259`
- Calibrated `0.248866`
- Delta `−0.016393`
- 95% CI `[-0.021891, -0.011495]`

ETH:
- Raw `0.264132`
- Calibrated `0.250563`
- Delta `−0.013569`
- CI `[-0.020824, -0.005867]`

SOL:
- Raw `0.262727`
- Calibrated `0.250645`
- Delta `−0.012082`
- CI `[-0.016465, -0.007784]`

Footnote:
`Lower Brier is better. Frozen 2025H2 out-of-sample replay.`

Claim boundary:
`This is forecast-evaluation evidence, not a profitability claim.`

## Asset D — Gallery 3: Evidence chain

Target: `1270 × 760`

Headline:
**Every result has a receipt.**

Pipeline graphic:
`Release v0.1.0 → Zenodo DOI → Frozen data → Forecast Contracts → Evaluator → Results`

Evidence callouts:
- DOI `10.5281/zenodo.22127650`
- evidence commit `917dd82...`
- evidence archive SHA256 `100484ff...`
- `52,920 RESOLVED`
- `0 integrity failures`

Footer:
`GitHub is the living canonical source. Zenodo is the immutable snapshot.`

## Asset E — Gallery 4: Negative results retained

Target: `1270 × 760`

Headline:
**Failed ideas stay visible.**

Simple result matrix:
- Correlation penalty — `No useful general gain`
- Disagreement shrink — `Small supported gain only for SOL`
- Regime weighting — `ETH + / BTC − / SOL inconclusive`
- Shadow cold-start — `Neutral`
- Volatility risk veto — `No Decision/UOP benefit`

Subhead:
`World 8 treats disagreement and failure as evidence—not something to edit out after the fact.`

## Asset F — Optional gallery: replication

Headline:
**Direction replicated. Certainty did not.**

SPY / QQQ / GLD point-estimate deltas shown as negative Brier deltas, each with a CI line visibly crossing zero.

Caption:
`Independent daily replication points in the same direction, but all 95% intervals cross zero. Cross-market superiority is not established.`

## Copy rules

- Never write “beats the market.”
- Never write “profitable.”
- Never write “production ready.”
- Never visually imply returns from Brier-score improvements.
- Always distinguish forecast-quality metrics from Decision/UOP outcomes.
- Preserve uncertainty/negative findings in at least one gallery image.

## Asset QA gate

For each asset record:
- dimensions;
- file format;
- file size;
- SHA256;
- visual QA status;
- exact text contained in image;
- source evidence for every number shown.

No asset may be uploaded to Product Hunt until its numeric values match `docs/ssrn/SSRN_CLAIM_AUDIT_v0.1.md`.
