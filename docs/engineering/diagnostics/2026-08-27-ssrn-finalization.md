# Diagnostic Memory — SSRN Market Replay / Finalization

Date: 2026-08-27
Status: RESOLVED / EXPERIENCE_CAPTURED
Scope: `work/ssrn-market-replay-v0.1`

## Incident A — Stooq non-crypto source blocked CI automation

### Failed probe
- run: `33077352335`
- provider: Stooq public daily download endpoint
- requested symbols: SPY, QQQ, GLD

### Symptom
HTTP 200 was returned, but `Content-Type` was `text/html` rather than CSV. The response was a JavaScript browser-verification page. An earlier probe failed with `KeyError: Date` because it assumed CSV before validating the response schema.

### Safety behavior
No Stooq dataset was frozen, no invalid response was treated as market data, and the replication gate remained open.

### Fix
The probe was made schema/content-type aware and failed closed. The no-key replication source was switched to Yahoo Finance chart API, which returned JSON in GitHub CI and passed schema checks. The independent SPY/QQQ/GLD replication then completed on run `33077676106`.

### Lesson
A provider returning HTTP 200 is not sufficient evidence of a valid data response. Market-data ingestion gates MUST validate content type, schema, row count, date range, and source hashes before freezing data.

## Incident B — Forecast Contract v2 lacked explicit lifecycle state

### Discovery
During final SSRN readiness review, `forecast_contracts_test_v2.jsonl.gz` was found to contain 52,920 immutable forecasts with resolved targets and hash/version evidence, but no explicit lifecycle/status field.

### Impact
Forecast probabilities, targets, metrics, and empirical findings were unaffected. However, the `lifecycle integrity counts` gate could not honestly be marked complete.

### Diagnostic issue
https://github.com/saeedfaai/world-8/issues/15

### Fix
A deterministic v3 lifecycle projection was added. It changes no probability or resolved target and assigns the terminal `RESOLVED` state after the declared horizon.

Successful validation run:
https://github.com/saeedfaai/world-8/actions/runs/33079452232

Receipt:
`experiments/ssrn_market_replay_v0_1/results/lifecycle_integrity.json`

Result:
- 52,920 RESOLVED
- invalidated: 0
- expired: 0
- withdrawn: 0
- superseded: 0
- integrity failures: 0
- forecast values changed: false
- v2 input SHA256: `be5517cbdde2c16362e9567a6fb311f6a597b1a3bfa1a667e553ead16484f833`
- v3 output SHA256: `14ca2a77446aee4c91b0068f2272631db6982b7527a1ab49e7b828849a970c43`

### Lesson
Semantic lifecycle fields are evidence obligations, not documentation decoration. A record that is logically resolved is not lifecycle-verifiable until the terminal state and temporal transition are machine-readable and validated.

## Incident C — Final manuscript sync workflow YAML parse failure

### Failed run
https://github.com/saeedfaai/world-8/actions/runs/33079908931

### Symptom
GitHub recorded a failed workflow with no jobs. The first version embedded an unescaped physical multiline receipt string inside a Python heredoc within a YAML block scalar.

### Safety behavior
No job started. No manuscript source, Drive file, release, DOI, or external service was modified by the failed run.

### Fix
The receipt was constructed from a Python list joined with `\n`, keeping every physical workflow-source line YAML-safe.

Successful run:
https://github.com/saeedfaai/world-8/actions/runs/33079976146

### Lesson
Generated GitHub Actions workflows MUST avoid source-level multiline string bodies whose indentation can escape the YAML block scalar. Runtime multiline payloads should be built from YAML-safe physical lines.

## Final evidence freeze

Lifecycle-complete evidence was refrozen after Incident B:
- evidence commit: `917dd82ed87a3470acfdb9175905ec7c8727c096`
- evidence package SHA256: `100484ffba683111622377703e836728817fd6cbb45f53d62e45a5a3766ece70`
- freeze run: https://github.com/saeedfaai/world-8/actions/runs/33079638287
- classification: RESEARCH EVIDENCE / HISTORICAL REPLAY / NO LIVE TRADING

## Final manuscript candidate

- PDF SHA256: `acee536968f1fb9e527469d2125600b03587ce2e5a211ffdfadb6fe85f24ba7a`
- DOCX SHA256: `8de4a3bc137882181add32cb3884dc355e4fe77ca5d680bb60ae20fb1aa57a18`
- PDF pages: 9
- visual QA: PASS
- author claim review gate: https://github.com/saeedfaai/world-8/issues/16

## Derived engineering rules

1. Validate provider payload semantics, not just HTTP status.
2. Fail closed before data freeze or publication mutation.
3. Preserve negative empirical findings and failed-source probes as evidence.
4. Treat lifecycle state as a machine-verifiable contract obligation.
5. Re-freeze evidence whenever an evidence obligation is materially completed, even if forecast values did not change.
6. Bind human publication approval to an exact rendered-file hash.
7. Any material manuscript edit after approval invalidates that approval and requires a new hash/review.
8. One-shot workflows should be removed from the active branch after successful completion; Git history and sanitized receipts retain auditability.
