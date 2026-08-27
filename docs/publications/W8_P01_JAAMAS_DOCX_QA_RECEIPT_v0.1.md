# W8-P01 JAAMAS DOCX / Visual-QA Receipt v0.1

Status: **PASS / AUTHOR CONFIRMATIONS OPEN / NOT SUBMITTED**

## Canonical sources

- Manuscript: `docs/publications/manuscript/W8_P01_MANUSCRIPT_JAAMAS_v0.4.md`
  - Git blob SHA: `7daa5ad166e32837f394a6221d085d130bae7d67`
- JAAMAS Information Sheet: `docs/publications/W8_P01_JAAMAS_INFORMATION_SHEET_v0.3.md`
  - Git blob SHA after final reference-status synchronization: `9df7d4859a9586047c61b39b208d811b38337a69`
- Cover Letter: `docs/publications/W8_P01_JAAMAS_COVER_LETTER_v0.1.md`
  - Git blob SHA: `c48cd8865d3aa3d60fdf042877193977dcef86c4`

The local source bytes used to build the deliverables were verified against these Git blob SHAs before document generation.

## Frozen figures

- Public frozen ref: `saeedfaai/World-v6-public@freeze/w8-p01-figures-v0.1`
- Figure workflow run: `33114847279` — PASS
- Figure artifact digest: `sha256:d8b73fe170b8d5d654ead7a1d815c4bbf0e11089d418d5484e7ab249378a16e2`
- Manuscript contains exactly 3 inline figures and 2 rebuilt journal tables.

## Final DOCX hashes

| Deliverable | SHA256 | Bytes | Rendered pages | Visual QA |
|---|---|---:|---:|---|
| `W8_P01_JAAMAS_Manuscript_v0.4.docx` | `3da78d6e13575780c208c95b3158f47a2b91ffd0355addb423671ac791fe010f` | 344,841 | 12 | PASS 12/12 |
| `W8_P01_JAAMAS_Information_Sheet_v0.3.docx` | `f2708c3580c227a36872e7be1204198ae36ea7a5ffe2c68ae96db0050dff5075` | 28,820 | 3 | PASS 3/3 |
| `W8_P01_JAAMAS_Cover_Letter_v0.1.docx` | `b114d891f4032d856dfa67e7dff68e81e0f0ea27b94374591bc464cdb85a394c` | 25,554 | 2 | PASS 2/2 |

Visual QA was performed after the final layout-sensitive edits using the canonical DOCX renderer. All final pages were inspected. No clipping, overlap, broken tables, missing glyphs, or misplaced headers/footers were observed.

## Accessibility audit

- Manuscript: high=0 / medium=0 / low=0
- Information Sheet: high=0 / medium=0 / low=1
  - Low-only note: the public GitHub workflow is displayed as a raw URL.
- Cover Letter: high=0 / medium=0 / low=0

The low Information-Sheet finding is presentational only and does not affect document readability, provenance, or submission content.

## Formatting normalization

- Times New Roman journal-style document body and neutral black headings.
- A4 page layout with page numbers.
- Both manuscript result tables were rebuilt as native Word tables after Pandoc table rendering was found unreliable in LibreOffice.
- Figure alt text is present.
- Cover-letter author-confirmation placeholders are preserved and displayed as explicit bullets; no confirmation was inferred.
- Information Sheet final paragraph was synchronized with manuscript v0.4 so it no longer describes already-completed reference corrections as pending.

## Runner incident and fallback

Private GitHub DOCX workflow run `33126385254` and its explicit rerun failed before step allocation (`steps=null`). This is recorded as a provider-runner incident, not a document-build failure.

Fallback used: private canonical Markdown was retrieved through the authorized GitHub connector, source bytes were matched against canonical Git blob SHAs, documents were built in the document-rendering environment, and all pages were rendered and inspected there.

## Public reviewer evidence relation

- Frozen reviewer ref: `freeze/w8-p01-review-package-v0.1`
- Frozen reviewer commit: `07b37691076652f8373f8b6020a198fa70fc285a`
- Unified reproduction run: `33113474577` — PASS
- Reproduction artifact SHA256: `46e15a72c59c5e6035e0732590941f20d1ed7c44b7870b8d54002c790efe166c`

## Remaining submission gates

These remain intentionally open because only the author can confirm them:

- Competing Interests statement;
- Funding statement;
- confirmation that the manuscript is not simultaneously under consideration by another journal;
- final author approval.

After those confirmations, the remaining external step is provider-side JAAMAS submission and publisher similarity screening.

Claim boundary remains: **research manuscript / not submitted / no live trading / no external business effects / no production-readiness or general-framework-superiority claim**.
