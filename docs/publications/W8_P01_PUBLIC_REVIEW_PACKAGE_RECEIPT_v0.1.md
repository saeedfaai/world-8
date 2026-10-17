# W8-P01 — Public Reviewer Package Receipt v0.1

Date: 2026-08-27
Status: **FROZEN PUBLIC REPRODUCTION / PASS / NO LIVE EFFECTS**

## Purpose

Provide JAAMAS reviewers with a public, narrow, reproducible code/evidence surface for the principal W8-P01 experiments without requiring access to the private World 8 engineering repository.

## Frozen private evidence base

Canonical private evidence commit:
`34ed68b6e04c548e7ee14aa16e0e3eecdb1b31f0`

Private evidence freeze ref:
`freeze/w8-p01-evidence-v0.1`

## Frozen public reviewer package

Repository:
`saeedfaai/World-v6-public`

Reviewer freeze ref:
`freeze/w8-p01-review-package-v0.1`

Reviewer freeze commit:
`07b37691076652f8373f8b6020a198fa70fc285a`

Public executable source commit tested by CI:
`a0b2cf32915c9d63cca0ddd7c3eeb497ae8ce6d0`

Manifest:
`world8/w8-p01-review-package-v0.1/MANIFEST.json`

README:
`world8/w8-p01-review-package-v0.1/README.md`

## Unified public reproduction

Run:
https://github.com/saeedfaai/World-v6-public/actions/runs/33113474577

Conclusion: **SUCCESS**

Artifact:
`w8-p01-public-review-package-v0.1`

Artifact id:
`9663511297`

Artifact digest:
`sha256:46e15a72c59c5e6035e0732590941f20d1ed7c44b7870b8d54002c790efe166c`

Artifact size:
`7,942 bytes`

## Evidence reproduced in one public gate

### E1
- 98,000 deterministic reference trials.
- exact frozen valid-path check/evidence counts asserted.
- hardened baseline revoke/CAS/idempotency behavior asserted.
- frozen actor-theft, no-fence, tamper and runtime-identity-continuity differentiators asserted.

### E2
- Company: 1,000 trials.
- Trading: 1,000 trials.
- same eight-invariant suite and same governed kernel.
- all frozen rates = 1.0.
- market performance evaluated = false.
- live effects = false.

### E4
- mutation gate 5/5 killed; score=1.0.
- three compound cases × 1,000 trials.
- valid-path false-deny rate=0.0.
- production/runtime database not destructively mutated.

### E5
Pinned external runtime:
`autogen-core==0.7.5`

The unified gate materializes the exact previously public fixture from commit:
`ba9fe95cc41b02bd04962d6e38b1b6afdeefe26a`

Fixture path:
`benchmarks/w8_p01_autogen/baseline.py`

- 100 trials × 10 scenarios × 2 variants = 2,000 runtime cases.
- real AutoGen Core runtime primitives.
- no LLM/API key.
- no external effect.
- bounded frozen outcome assertions PASS.

## Public-package security boundary

The package intentionally excludes credentials, tokens, private Supabase identifiers/data, customer/supplier/business state, credential-broker internals, live trading, external business effects and private operational control-plane state not required for reproduction.

## Claim ceiling

This public reproduction supports the manuscript's bounded falsification/conformance/composability claims only. It is not evidence of production readiness, profitability, universal security, universal domain generality, general superiority over AutoGen or standalone novelty of the primitive mechanisms.

## Archival status

The Git freeze ref/commit is currently the stable reviewer reference. A DOI/archive snapshot is still an optional pre-submission enhancement and MUST NOT be represented as completed until a real archive receipt exists.
