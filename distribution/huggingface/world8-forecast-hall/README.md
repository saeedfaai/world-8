# World 8 Forecast Hall

**Status:** Architecture / development pre-release / non-production

World 8 separates **Forecast**, **Decision**, and **Order** as distinct governed objects. Forecast Hall is the analytical layer for producing, evaluating, calibrating, and combining forecasts without directly owning trading execution.

## Current architecture principles
- Forecast != Decision != Order
- Strategy = versioned Skill
- Analyst = Role / Entity
- Brain = replaceable provider/model
- no simple majority-vote authority
- weighted ensemble with calibration and correlation control
- disagreement is a signal
- independent regime detection
- cold-start analysts begin in Shadow mode with weight 0
- Risk / Portfolio policy remains outside Forecast Hall and can veto execution

## Canonical source
https://github.com/saeedfaai/world-8

Current development pre-release:
https://github.com/saeedfaai/world-8/releases/tag/V0.1.0

## Evidence boundary
This surface documents and demonstrates architecture. It does not claim a production trading system, guaranteed returns, or completed market execution infrastructure.
