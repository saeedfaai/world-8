# Cover Letter — W8-P01 / JAAMAS v0.1

**To:** Editors, *Autonomous Agents and Multi-Agent Systems*  
**Article type:** Regular Paper / Original Research  
**Manuscript:** *A Governed Shared-Kernel Architecture for Persistent, Auditable Multi-Agent Societies Beyond the LLM Session*  
**Author:** Saeed Farokhi, Mechanical Engineering, University of Tehran, Tehran, Iran  
**Corresponding email:** Saeed.farokhi@ut.ac.ir

Dear Editors,

Please consider the manuscript **“A Governed Shared-Kernel Architecture for Persistent, Auditable Multi-Agent Societies Beyond the LLM Session”** for publication as a Regular Paper in *Autonomous Agents and Multi-Agent Systems*.

The paper studies a bounded engineering question for persistent multi-agent systems: whether a shared governance kernel can preserve logical-Actor attribution and authority, effect-boundary controls, evidence integrity, stale-effector exclusion, and recovery invariants across transient runtime/session replacement and materially different Society adapters.

The work is deliberately framed as an **evaluation of a composed governance contract**, not as a claim that its primitive mechanisms are individually new. The manuscript explicitly concedes prior art in intelligent-agent architectures, normative/governed MAS, access control, leases and lock services, tamper-evident histories, checkpoint/recovery, and modern agent runtimes. A close pre-submission prior-art review also includes contemporary work on topology-independent agent identity and verifiable delegation. Accordingly, no “first,” “unique,” universal-security, or general-framework-superiority claim is made.

The empirical program is falsification-oriented. A hardened baseline removes apparent advantages attributable to generic revocation, CAS/stale-write protection, durable idempotency, approval scope, and audit. The remaining frozen evaluation includes: 98,000 reference-model trials; a two-Society conformance test using the same eight-invariant kernel across Company and Trading adapters; canonical/runtime behavioral governance probes; a 5/5 controlled mutation gate and compound-fault tests; and 2,000 cases on real `autogen-core==0.7.5`. The AutoGen experiment is interpreted as composability of the tested governance controls over an independent runtime, not as a claim that AutoGen is insecure or generally inferior.

For reviewer reproducibility, the manuscript evidence is frozen at a fixed canonical commit. A sanitized public reviewer package independently reproduces the principal E1/E2/E4/E5 results without access to the private engineering repository:

- Public repository: `https://github.com/saeedfaai/World-v6-public`
- Frozen reviewer ref: `freeze/w8-p01-review-package-v0.1`
- Frozen reviewer commit: `07b37691076652f8373f8b6020a198fa70fc285a`
- Unified reproduction run: `https://github.com/saeedfaai/World-v6-public/actions/runs/33113474577`
- Reproduction artifact SHA256: `46e15a72c59c5e6035e0732590941f20d1ed7c44b7870b8d54002c790efe166c`

The package contains no credentials, private operational database data, customer/supplier data, live trading, or external business effects.

A separate working paper by the author, W8-P02 (SSRN Abstract ID `7359740`), evaluates a **different question**: historical market forecasting/calibration behavior under a Forecast/Decision/Order separation. W8-P02 owns the market replay, Brier/calibration, market-ablation, and related market-performance evidence. The present W8-P01 manuscript does not reuse those Results, tables, confidence intervals, or market conclusions as its primary contribution. W8-P01 instead uses independently generated governance/failure/conformance/runtime evidence; Trading appears only as a governance/conformance adapter with `market_performance_evaluated=false` and `live_effects=false`. A post-draft overlap review is retained in the submission record.

AI-assisted tools were used for structured drafting, language editing, software/documentation support, literature discovery, experiment-orchestration support, and consistency checking. The author reviewed the resulting material and remains responsible for the research design, claims, code, interpretation, citations, and final manuscript. No AI system is listed as an author.

The manuscript is accompanied by the JAAMAS Information Sheet requested for submission, describing the main claim, evidence, closest prior work, and relationship to the author's other work.

**Author confirmations required before this letter is used for submission:**
- `[CONFIRM: this manuscript is not simultaneously under consideration by another journal]`
- `[CONFIRM: Competing Interests statement]`
- `[CONFIRM: Funding statement]`

Thank you for considering the manuscript. I believe its combination of bounded architectural claims, explicit negative results, cross-Society conformance testing, runtime-backed checks, and an independent external-runtime comparison is directly relevant to the engineering and evaluation of autonomous agents and multi-agent systems.

Sincerely,

**Saeed Farokhi**  
Mechanical Engineering, University of Tehran  
Tehran, Iran  
Saeed.farokhi@ut.ac.ir
