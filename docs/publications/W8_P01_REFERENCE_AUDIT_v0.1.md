# W8-P01 — Reference Verification Audit v0.1

Date: 2026-08-27
Status: **PASS WITH REQUIRED MANUSCRIPT CORRECTIONS**

Purpose: verify the W8-P01 v0.3 reference list against DOI/publisher/venue/official-documentation sources before journal rendering.

## R1 — Wooldridge & Jennings (1995)

Verified:
- Michael Wooldridge; Nicholas R. Jennings
- *Intelligent agents: theory and practice*
- The Knowledge Engineering Review 10(2), 115–152 (1995)
- DOI `10.1017/S0269888900008122`

Preferred authority:
https://doi.org/10.1017/S0269888900008122

Status: **PASS**

## R2 — Shoham (1993)

Verified:
- Yoav Shoham
- *Agent-oriented programming*
- Artificial Intelligence 60(1), 51–92 (1993)
- DOI `10.1016/0004-3702(93)90034-9`

Authority:
https://www.sciencedirect.com/science/article/pii/0004370293900349

Status: **PASS**

## R3 — Sandhu et al. (1996)

Verified:
- Ravi S. Sandhu; Edward J. Coyne; Hal L. Feinstein; Charles E. Youman
- *Role-Based Access Control Models*
- Computer 29(2), 38–47 (1996)
- DOI `10.1109/2.485845`

Authority:
https://doi.org/10.1109/2.485845

Status: **PASS**

## R4 — Gray & Cheriton (1989)

Verified paper:
- Cary G. Gray; David R. Cheriton
- *Leases: An Efficient Fault-Tolerant Mechanism for Distributed File Cache Consistency*
- SOSP 1989, 202–210

Preferred paper DOI:
`10.1145/74850.74870`

DBLP resolves the paper to this DOI. Some aggregators also expose `10.1145/74851.74870`, associated with the proceedings/container lineage. W8-P01 should cite the paper DOI `10.1145/74850.74870` and should not list both as if they were two works.

Authorities:
- https://dblp.org/rec/conf/sosp/GrayC89.html
- https://doi.org/10.1145/74850.74870

Status: **PASS / DOI AMBIGUITY RESOLVED**

## R5 — Burrows (2006)

Verified:
- Mike Burrows
- *The Chubby Lock Service for Loosely-Coupled Distributed Systems*
- 7th USENIX Symposium on Operating Systems Design and Implementation (OSDI 06)
- pages 335–350
- USENIX Association, 2006

Authority:
https://www.usenix.org/conference/osdi-06/chubby-lock-service-loosely-coupled-distributed-systems

No DOI is required in the manuscript if no authoritative DOI is supplied by the venue record.

Status: **PASS / ADD PAGES + USENIX ASSOCIATION RECOMMENDED**

## R6 — Haber & Stornetta (1991)

Verified:
- Stuart Haber; W. Scott Stornetta
- *How to Time-Stamp a Digital Document*
- Advances in Cryptology — CRYPTO '90, LNCS 537, 437–455
- copyright/publication lineage 1991
- DOI `10.1007/3-540-38424-3_32`

Authority:
https://doi.org/10.1007/3-540-38424-3_32

Springer web metadata may show a later online digitization date; the bibliographic work remains the CRYPTO 1990 / LNCS 537 publication with 1991 copyright lineage.

Status: **PASS**

## R7 — Chandy & Lamport (1985)

Verified:
- K. Mani Chandy; Leslie Lamport
- *Distributed Snapshots: Determining Global States of Distributed Systems*
- ACM Transactions on Computer Systems 3(1), 63–75 (1985)
- DOI `10.1145/214451.214456`

Authority:
https://doi.org/10.1145/214451.214456

Status: **PASS**

## R8 — AutoGen / Wu et al. (COLM 2024)

Venue authority verifies accepted COLM 2024 title:
*AutoGen: Enabling Next-Gen LLM Applications via Multi-Agent Conversations*

COLM accepted-paper metadata lists 14 authors:
1. Qingyun Wu
2. Gagan Bansal
3. Jieyu Zhang
4. Yiran Wu
5. Beibin Li
6. Erkang Zhu
7. Li Jiang
8. Xiaoyun Zhang
9. Shaokun Zhang
10. Jiale Liu
11. Ahmed Hassan Awadallah
12. Ryen W White
13. Doug Burger
14. Chi Wang

Authorities:
- https://colmweb.org/2024/AcceptedPapers.html
- https://arxiv.org/abs/2308.08155
- Microsoft Research publication page is useful but currently omits Jiale Liu in its displayed author metadata; use the COLM accepted-paper list/OpenReview/arXiv lineage for the complete author list.

W8-P01 v0.3 already contains Jiale Liu and the 14-author list. Preserve that list.

Status: **PASS / VENUE-AUTHOR LIST RESOLVED**

## R9 — LangGraph Persistence documentation

Verified official documentation:
https://docs.langchain.com/oss/python/langgraph/persistence

Documented capabilities relevant to the related-work statement include checkpointed graph state, thread persistence, resume after interruption, time travel, human-in-the-loop and fault-tolerant restart from a successful step.

Final reference should include:
`LangChain. LangGraph Persistence. Official documentation. Accessed 27 August 2026.`

Status: **PASS / ADD ACCESS DATE**

## R10 — OpenAI Agents SDK documentation

Verified current official Python SDK documentation:
- Sessions: https://openai.github.io/openai-agents-python/sessions/
- Guardrails: https://openai.github.io/openai-agents-python/guardrails/
- Tracing: https://openai.github.io/openai-agents-python/tracing/
- Agents/overview: https://openai.github.io/openai-agents-python/agents/

The current docs support the manuscript's bounded prior-art statements about session memory, guardrails, agent orchestration/handoffs and tracing.

Final reference should include an access date:
`OpenAI. OpenAI Agents SDK documentation. Accessed 27 August 2026.`

Status: **PASS / ADD ACCESS DATE AND OFFICIAL URL(S)**

## R11 — da Silva et al. (2007)

Verified:
- Viviane Torres da Silva; Fernanda Duran; José Guedes; Carlos J. P. de Lucena
- *Governing multi-agent systems*
- Journal of the Brazilian Computer Society 13, 19–34 (2007)
- DOI `10.1007/BF03192407`

Authority:
https://doi.org/10.1007/BF03192407

Status: **PASS**

## R12 — Vasconcelos et al. (2012)

Verified:
- Wamberto W. Vasconcelos
- Andrés García-Camino
- Dorian Gaertner
- Juan A. Rodríguez-Aguilar
- Pablo Noriega
- *Distributed norm management for multi-agent systems*
- Expert Systems with Applications 39(5), 5990–5999 (2012)
- DOI `10.1016/j.eswa.2011.11.108`

Authority:
https://www.sciencedirect.com/science/article/pii/S095741741101654X

Status: **PASS**

## R13 — Rodriguez (2026 preprint)

Verified arXiv record:
- Roland R. Rodriguez
- *Agent Identity URI Scheme: Topology-Independent Naming and Capability-Based Discovery for Multi-Agent Systems*
- arXiv:2601.14567 (2026)

Authority:
https://arxiv.org/abs/2601.14567

**Required correction:** W8-P01 v0.3 currently renders the author as `Rodriguez, R. R. Jr.`. The verified arXiv metadata available in this audit identifies the author as `Roland R. Rodriguez`; remove the unsupported `Jr.` unless a stronger primary source explicitly establishes it.

Status: **PASS AFTER AUTHOR-NAME CORRECTION**

## R14 — Prakash (2026 preprint)

Verified:
- Sunil Prakash
- *AIP: Agent Identity Protocol for Verifiable Delegation Across MCP and A2A*
- arXiv:2603.24775 (2026)

Authority:
https://arxiv.org/abs/2603.24775

Status: **PASS**

## R15 — Rother et al. (2025)

Verified:
- David Rother; Joni Pajarinen; Jan Peters; Thomas H. Weisswange
- *Open-ended coordination for multi-agent systems using modular open policies*
- Autonomous Agents and Multi-Agent Systems 39, article 40 (2025)
- DOI `10.1007/s10458-025-09723-7`
- published 10 October 2025

Authority:
https://doi.org/10.1007/s10458-025-09723-7

Status: **PASS**

# Required manuscript edits before reference gate closes

1. R5: add OSDI pages 335–350 / USENIX Association if journal style permits.
2. R9: replace placeholder with final LangGraph official-doc citation and access date `27 August 2026`.
3. R10: replace placeholder with official OpenAI Agents SDK citation/URLs and access date `27 August 2026`.
4. R13: change `Rodriguez, R. R. Jr.` to `Rodriguez, R. R.` / Roland R. Rodriguez unless a primary source supports the suffix.
5. Preserve all 14 COLM-listed AutoGen authors including Jiale Liu.

Overall reference-verification state: **PASS WITH FOUR EDIT ACTIONS + AUTOGEN AUTHOR-LIST PRESERVATION**.
