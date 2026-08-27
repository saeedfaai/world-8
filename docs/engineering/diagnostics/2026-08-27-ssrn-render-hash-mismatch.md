# Diagnostic Memory — SSRN Render Hash Mismatch

Date: 2026-08-27
Status: RESOLVED / EXPERIENCE_CAPTURED
Scope: SSRN final manuscript packaging

## Symptom
A pre-submission integrity check found that the local PDF/DOCX bytes did not match the rendered-file SHA256 values recorded in the GitHub manuscript receipt and SSRN metadata.

Old recorded hashes:
- PDF: `acee536968f1fb9e527469d2125600b03587ce2e5a211ffdfadb6fe85f24ba7a`
- DOCX: `8de4a3bc137882181add32cb3884dc355e4fe77ca5d680bb60ae20fb1aa57a18`

The canonical Markdown SHA256 still matched GitHub:
- Markdown: `7a1f11cd3ee75d2f974f41bac5341367408fede2f75e3bbf16642902393a6c19`

## Root cause
The rendered PDF/DOCX generation and later lifecycle-v3 evidence synchronization were not atomically bound to one final receipt update. A stale render hash pair remained in publication metadata after the manuscript source/evidence binding advanced.

## Safety behavior
The mismatch was discovered before SSRN provider submission. No SSRN paper had been submitted and no provider identifier existed. The stale files/hashes were therefore prevented from becoming an external publication reference.

## Correction
1. The manuscript was re-rendered from the canonical Markdown source bound to empirical evidence commit `917dd82ed87a3470acfdb9175905ec7c8727c096`.
2. Forecast Contract v3 lifecycle evidence remained explicitly embedded.
3. All 9 PDF pages were visually re-inspected.
4. Drive PDF/DOCX bytes were replaced in place, preserving stable file IDs.
5. GitHub manuscript receipt, readiness gate, submission metadata, provider packet, and Issue #10 were updated.
6. Repository search confirmed the stale PDF/DOCX hashes no longer appear in current indexed source.

## Canonical final render
- PDF SHA256: `53b3a4c688b620cb3f611ae525484cfba0d186fb85393e7011312999ecf2efed`
- PDF bytes: `210232`
- DOCX SHA256: `345164e825abc887ae0e26de745c6705a512193e42ca25985871f46d94c69386`
- DOCX bytes: `22730`
- Markdown SHA256: `7a1f11cd3ee75d2f974f41bac5341367408fede2f75e3bbf16642902393a6c19`
- pages: 9
- visual QA: PASS

Drive:
- PDF: https://drive.google.com/file/d/15b2XrL8mqix6gBEnWXm6VTxtoCCgCi59/view
- DOCX: https://drive.google.com/file/d/1tNIMdqCBJ6a8dRDR60TkccWCoF-8G4MM/view

## Engineering rules derived
1. A publication receipt MUST bind source hash, rendered-file hashes, evidence commit, and evidence-package hash in one final pre-submission transaction.
2. Provider upload MUST verify the exact local/provider file hash against the current canonical receipt immediately before submission.
3. Re-rendering after evidence/source changes invalidates every prior rendered-file hash, even when filenames and Drive IDs are unchanged.
4. Stable Drive IDs are identifiers, not content identity; byte hash remains authoritative.
5. External publication actions MUST fail closed when source/render/evidence hashes disagree.
