# Diagnostic Memory — Zenodo v0.1.0 Publication Bridge

Date: 2026-08-27
Status: RESOLVED / EXPERIENCE_CAPTURED
Scope: World 8 v0.1.0 publication pipeline

## Incident A — publication credential discovery searched in the wrong repository

### Symptom
A first sanitized probe in `saeedfaai/world-v6` reported all tested Zenodo secret names missing and led to the temporary conclusion that a new Zenodo token was required.

### Root cause
Historical publication automation and the real `ZENODO_TOKEN` were stored in `saeedfaai/World-v6-public`, not `saeedfaai/world-v6`.

### Recovery evidence
Historical Git commits recovered the deleted workflows:
- `8accab3c66ed9812901ac12bc63b90c419e0db63` — safe Zenodo token diagnostic
- `c979da96653645c8b0835420dac2f68fccbf0a10` — guarded Zenodo G7 publish
- `0392c529eea2eb55325766682bd6b000e9785f35` — guarded World 8 Z0-A Zenodo draft preparation

A new sanitized probe in `saeedfaai/World-v6-public` returned:
- legacy depositions API: HTTP 200
- modern user records API: HTTP 200
- status: VALID

### Lesson
Credential/service recovery must search historical repository commits and deleted workflows across all known publication bridges before concluding that a secret or integration is absent.

## Incident B — checksum manifest path mismatch

### Failed run
https://github.com/saeedfaai/World-v6-public/actions/runs/33072744946

### Symptom
The outer staging ZIP checksum passed, but the internal `SHA256SUMS.txt` verification failed because the manifest contained paths beginning with `zenodo-package/` while the GitHub Actions artifact ZIP extracted its contents directly at the artifact root.

### Safety behavior
The workflow stopped before any Zenodo draft creation or publication mutation. No DOI was created by the failed run.

### Root cause
The package producer and the package verifier disagreed about archive-relative path roots.

### Fix
The verifier explicitly root-mapped the stored `zenodo-package/` prefix to the extracted artifact directory before passing entries to `sha256sum -c`.

Fix commit on publication bridge:
`d73e78908f898574e2b663b3694fe2486246dd52`

### Successful rerun
https://github.com/saeedfaai/World-v6-public/actions/runs/33072844971

Result:
- status: PUBLISHED
- record: https://zenodo.org/records/22127650
- DOI: https://doi.org/10.5281/zenodo.22127650
- exact release commit: `b14f2feea0fa233851a774d6ebd295b63cde75c0`

## Incident C — Hugging Face DOI sync workflow YAML parse failure

### Failed run
https://github.com/saeedfaai/world-v6/actions/runs/33073330003

### Symptom
GitHub created a failed workflow run with no jobs. The workflow path appeared as its display name, indicating the workflow file itself could not be parsed.

### Root cause
A Python multiline string embedded in a YAML `run: |` block introduced physical lines that were not indented as YAML block-scalar content.

### Safety behavior
No GitHub job started, `HF_API_KEY` was not consumed by a job, and no Hugging Face repository or Space was modified.

### Fix
The multiline Markdown payload was changed to a Python `"\n".join([...])` construction so every physical source line remains correctly indented inside the YAML block.

Fix commit on private Hugging Face bridge:
`22f0aa2d6e2d3131c582ec22a4d5ac1e24ba7b61`

### Successful rerun
https://github.com/saeedfaai/world-v6/actions/runs/33073402200

Sanitized result:
- `Saeedfa/world8-core` README — UPDATED / OK
- `Saeedfa/world8-forecast-hall` README — UPDATED / OK
- `Saeedfa/world8-market-data` README — UPDATED / OK
- `Saeedfa/world8-demo` README — UPDATED / OK
- `Saeedfa/world8-demo` `index.html` — UPDATED / OK
- DOI synchronized: `10.5281/zenodo.22127650`

## Engineering rules derived
1. Artifact checksum manifests SHOULD use archive-relative paths independent of producer workspace layout.
2. If a manifest embeds a producer prefix, the verifier MUST explicitly map that prefix before verification.
3. External publication workflows MUST stop before provider mutation when any package, checksum, metadata, identity, or parser gate fails.
4. Publication bridges MUST be idempotent and check for an existing matching published record/draft before creating a new record.
5. Secret values MUST never appear in logs, issues, Drive documents, receipts, or repository files; only secret names and validated status may be recorded.
6. Generated GitHub Actions workflows MUST avoid unindented physical lines inside YAML block scalars; construct multiline runtime payloads in a YAML-safe form.
7. Temporary workflows that consume publication/provider secrets SHOULD be retired from the branch after completion; Git history and sanitized receipts preserve reproducibility/evidence.

## Cleanup receipt
After successful publication/synchronization, temporary Zenodo and Hugging Face secret-consuming workflows were removed from repository heads. The non-secret exact-release package builder remains available for reproducibility.

## Canonical receipts
- GitHub release: https://github.com/saeedfaai/world-8/releases/tag/V0.1.0
- Zenodo gate: https://github.com/saeedfaai/world-8/issues/9
- Zenodo receipt: https://github.com/saeedfaai/World-v6-public/blob/main/ops/zenodo/world8-v0.1.0-publication.json
- Hugging Face sync receipt: https://github.com/saeedfaai/world-v6/blob/main/ops/hf-world8-doi-sync-result.json
- Drive package backup: https://drive.google.com/file/d/1t2145gm9QGHEcCzKLnqvuDJ5CvO4a10N/view
