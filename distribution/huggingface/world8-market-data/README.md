# World 8 Market Data

**Status:** Architecture / development pre-release / non-production

World 8 Market Data is the planned shared evidence-oriented market-data layer for normalized, cached, gap-filled, policy-gated market observations used by forecasting and evaluation components.

## Current data policy
- Spine stores Evidence Receipts rather than bulk market history
- Derived Store holds features, forecasts, evaluation outputs, and derived knowledge
- OHLCV at 1h+ can be cached with retention policy
- minute/tick history is bounded by policy
- order books are on-demand unless explicitly retained
- a shared Market Data Node owns cache, normalization, gap filling, and Policy Gate behavior

## Canonical source
https://github.com/saeedfaai/world-8

Current development pre-release:
https://github.com/saeedfaai/world-8/releases/tag/V0.1.0

## Evidence boundary
No complete production market-data service or exchange-grade feed reliability is claimed by v0.1.0.
