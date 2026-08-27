# W8-P01 — JAAMAS Submission Preflight v0.1

Date: 2026-08-27
Status: **TARGET CONFIRMED / MANUSCRIPT ADAPTATION ACTIVE**
Target: **Autonomous Agents and Multi-Agent Systems (JAAMAS), Springer Nature**
Article type: **Regular Paper / Original Research**

## Scope fit

Official JAAMAS scope explicitly includes:
- agent decision-making architectures and their evaluation;
- organizational structuring/design for multi-agent systems;
- agent communication/protocols;
- conventions, commitments, norms, obligations, trust and reputation;
- environments/testbeds for experimentation and analysis of agent systems;
- agents as a software-engineering paradigm, including specification, verification, methodologies, analysis/design, evaluation of development approaches, and significant practical experiences.

Conclusion: **STRONG SCOPE FIT** for W8-P01 when framed as a governed multi-agent architecture/evaluation paper rather than as a trading paper or distributed-locking paper.

Official journal pages checked 2026-08-27:
- https://link.springer.com/journal/10458/aims-and-scope
- https://link.springer.com/journal/10458/submission-guidelines

## Mandatory JAAMAS Information Sheet

JAAMAS requires every submission to include a **1–2 page information sheet**. For a regular paper it must answer:
1. What is the main claim and why does it matter to autonomous-agents/MAS literature?
2. What precise evidence supports it?
3. What papers by other authors are most closely related, and how does the submission differ?
4. Has any part been published before, and what significant added value does the submission provide?

Incomplete/uninformative information sheets may be returned without review.

Status: **DRAFTED** at `docs/publications/W8_P01_JAAMAS_INFORMATION_SHEET_v0.1.md`.

## Originality / paper-portfolio gate

JAAMAS explicitly warns against:
- simultaneous consideration by multiple journals;
- text recycling/self-plagiarism without transparency;
- splitting one study into multiple papers merely to increase publication count (“salami slicing”).

W8-P01 mitigation already in place:
- publication portfolio capped;
- W8-P01/W8-P02 research questions are distinct;
- primary evidence is separate;
- pre-manuscript overlap/ownership audit PASS;
- mandatory post-draft text-level overlap audit remains required.

Relevant internal receipt:
`docs/publications/W8_P01_P02_OVERLAP_AUDIT.md`

## Manuscript format requirements and current status

### Title page
JAAMAS requires:
- concise informative title;
- author name(s);
- affiliation including institution, department if applicable, city and country;
- corresponding-author email;
- ORCID if available.

Current manuscript:
- [x] concise technical title candidate
- [x] author name
- [x] University of Tehran affiliation
- [ ] normalize affiliation to include Tehran, Iran
- [x] email
- [ ] ORCID: add only if author supplies/validates one

### Abstract
Required: **150–250 words**.

Current v0.1 abstract is longer than the target range.
Action: **BLOCKER — compress to 150–250 words in JAAMAS manuscript v0.2.**

### Keywords
Required: **4–6 keywords**.

Current v0.1 has more than 6.
Action: reduce to 6:
- multi-agent systems
- agent identity
- authorization
- governance
- fault recovery
- agent runtime

### Headings
No more than three displayed heading levels.
Current structure: compatible in principle; verify during final Word conversion.

### Editable source
JAAMAS requires editable source files at submission/revision; Word `.docx` or LaTeX accepted. Their instructions specifically state manuscripts should be submitted in Word and also permit LaTeX for mathematical content.

Plan:
- canonical authoring source: Markdown under Git for auditability;
- provider submission artifact: `.docx` generated from the frozen manuscript;
- PDF only as author/preflight artifact, not a replacement for editable source.

## AI-use disclosure

Springer/JAAMAS policy states LLMs cannot be authors and use of an LLM beyond copy editing should be properly documented in the **Methods section (or a suitable alternative if no Methods section exists)**. Human authors retain accountability.

W8-P01 used AI-assisted tools for structured drafting, language editing, software/documentation support, literature discovery, experiment-orchestration support, and consistency checking. The author remains responsible for research design, claims, code, data choices, interpretation, citations, and manuscript.

Action:
- [ ] move/add the disclosure into the Evaluation Method/Methods section, not only at the end.
- [x] do not list an AI system as author.
- [x] no generative-AI scientific figures are planned.

## Statements and Declarations

JAAMAS requires relevant declarations and may return incomplete submissions.

Needed before submission:
- [ ] Competing Interests statement
- [ ] Funding statement
- [ ] Author Contributions statement
- [ ] Data Availability statement
- [ ] Code Availability statement
- [ ] AI-use disclosure in Methods

Draft default statements, subject to author confirmation:

**Competing Interests** — The author declares no competing interests directly related to this work.

**Funding** — No external funding was specifically received for this study. `[AUTHOR CONFIRMATION REQUIRED]`

**Author Contributions** — Saeed Farokhi conceived the architecture and research question, defined the evaluation program, reviewed the software and evidence, interpreted the results, and takes responsibility for the manuscript. AI-assisted tools supported drafting, software/documentation work, literature discovery, experiment orchestration, and consistency checking under author review.

**Data/Code Availability** — The paper is software/evidence oriented and uses synthetic governance scenarios. Frozen code/evidence references are identified by exact Git commit/run/hash receipts. Public release/repository accessibility for the final review package must be confirmed before submission.

## References

JAAMAS uses numbered citations in square brackets and asks authors to include DOI links when available. Current draft already uses numeric references but DOI formatting should be normalized to full `https://doi.org/...` links.

Action:
- [ ] verify every reference against primary/publisher metadata;
- [ ] expand AutoGen bibliographic author/title details;
- [ ] cite official documentation only for current framework capabilities that are not adequately represented by archival papers;
- [ ] ensure journal references are used where possible, per the mandatory information-sheet guidance.

## Figures/Tables

Current draft is primarily text/tables.
Planned figures should be generated from verifiable architecture/evidence data, not generative artwork.

Recommended final figures:
1. Shared governed kernel and Society-adapter boundary.
2. Evidence ladder E1→E5.
3. Fault-family comparison: hardened baseline vs governance-wrapped external runtime.

All figures must remain legible in grayscale and meet Springer artwork guidance.

## Evidence freeze

Frozen evidence base:
`34ed68b6e04c548e7ee14aa16e0e3eecdb1b31f0`

Freeze ref:
`freeze/w8-p01-evidence-v0.1`

Manifest:
`docs/publications/W8_P01_EVIDENCE_FREEZE_v0.1.yaml`

No future project change may silently replace a frozen Result in this manuscript.

## Remaining submission gates

- [x] evidence E1–E5 sufficiently bounded for manuscript drafting
- [x] external executable baseline
- [x] prior-art registry
- [x] pre-manuscript W8-P01/W8-P02 overlap audit
- [x] evidence freeze
- [x] claim ledger
- [x] manuscript v0.1
- [ ] JAAMAS-adapted manuscript v0.2 (abstract/keywords/title-page/declarations)
- [ ] post-draft text-level overlap audit vs W8-P02
- [ ] independent claim/novelty review
- [ ] reference verification pass
- [ ] figures/tables finalization
- [ ] Word `.docx` render + visual QA
- [ ] mandatory JAAMAS 1–2 page information sheet final
- [ ] cover letter
- [ ] author final approval
- [ ] provider submission

Current overall gate: **MANUSCRIPT PREPARATION — GO**
