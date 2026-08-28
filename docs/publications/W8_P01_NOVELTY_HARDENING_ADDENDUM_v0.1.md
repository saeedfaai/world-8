# W8-P01 — Novelty Hardening Addendum v0.1

Date: 2026-08-27  
Status: **BINDING / POST-DRAFT PRIOR-ART HARDENING**  
Applies to: W8-P01 manuscript line after JAAMAS v0.2  
Evidence freeze unchanged: `34ed68b6e04c548e7ee14aa16e0e3eecdb1b31f0`

## Purpose

A second, closer prior-art pass was performed after manuscript v0.2. It found work materially closer to two parts of the provisional novelty framing: **normative governance in multi-agent systems** and **agent identity that is stable across topology/provider changes**.

The result is a stricter novelty boundary. No experimental result changes. Only the interpretation/novelty ceiling is narrowed.

---

## A. Normative governance in multi-agent systems is established prior art

### A1. Governing multi-agent systems

**da Silva, V. T.; Duran, F.; Guedes, J.; Lucena, C. J. P. (2007). _Governing multi-agent systems_. Journal of the Brazilian Computer Society 13:19–34.**  
DOI: `10.1007/BF03192407`  
Verified publisher source: https://link.springer.com/article/10.1007/BF03192407

The paper explicitly treats governance mechanisms for open multi-agent systems and norms specifying actions agents are prohibited, permitted, or obligated to perform, including enforcement beyond dialogical actions.

**Prior art / not ours:**
- governance mechanisms for open MAS;
- norms regulating agent behavior;
- prohibition / permission / obligation as governance categories;
- enforcement of governed agent actions as a research problem.

**Implication for W8-P01:**
World 8 MUST NOT claim to introduce governance, norms, obligations, permissions, prohibitions, or enforcement to MAS. Its narrower object is the tested **effect-boundary composition** linking logical Actor identity, effect-time authority, fencing, tamper-evident evidence, and recovery gating.

### A2. Distributed norm management

**Vasconcelos, W. W.; García-Camino, A.; Gaertner, D.; Rodríguez-Aguilar, J. A.; Noriega, P. (2012). _Distributed norm management for multi-agent systems_. Expert Systems with Applications 39(5):5990–5999.**  
DOI: `10.1016/j.eswa.2011.11.108`  
Verified sources:
- https://www.sciencedirect.com/science/article/abs/pii/S095741741101654X
- https://abdn.elsevierpure.com/en/publications/distributed-norm-management-for-multi-agent-systems/

This work explicitly models norms as prohibitions, permissions, and obligations and motivates distributed norm management by fault-tolerance and scalability concerns.

**Prior art / not ours:**
- distributed management of normative constraints;
- run-time norm conflict handling;
- fault-tolerance/scalability as motivations for distributed governance.

**Implication for W8-P01:**
The manuscript must not imply that distributing governance or managing normative rules at run time is itself new.

---

## B. Provider/topology-independent agent identity is not safe as a standalone novelty claim

### B1. Agent Identity URI Scheme — contemporaneous preprint

**Rodriguez, R. R. Jr. (2026). _Agent Identity URI Scheme: Topology-Independent Naming and Capability-Based Discovery for Multi-Agent Systems_. arXiv:2601.14567.**  
Verified source: https://arxiv.org/abs/2601.14567

The preprint directly proposes decoupling agent identity from network topology/provider location, with stable references across provider migration/federation and cryptographic capability attestation.

**Status:** contemporaneous preprint; not treated as peer-reviewed archival evidence.

**Prior/contemporaneous capability / not ours as a standalone claim:**
- stable agent identity independent of topology/provider location;
- identity continuity under migration;
- capability claims bound to agent identity.

**Implication for W8-P01:**
The paper MUST NOT present “provider-independent persistent agent identity” by itself as the novelty. C1 remains an evaluated World 8 property, but novelty moves to the broader tested governance composition and effect boundary.

### B2. AIP — verifiable agent identity/delegation — contemporaneous preprint

**Prakash, S. (2026). _AIP: Agent Identity Protocol for Verifiable Delegation Across MCP and A2A_. arXiv:2603.24775.**  
Verified source: https://arxiv.org/abs/2603.24775

AIP combines agent identity, verifiable delegation/attenuated authorization, policy, transport bindings, and provenance-oriented completion records.

**Status:** contemporaneous preprint; not treated as peer-reviewed archival evidence.

**Prior/contemporaneous capability / not ours as a standalone claim:**
- cryptographically verifiable agent identity;
- delegated/attenuated authorization;
- provenance-bound agent operations;
- chained policy for multi-hop delegation.

**Implication for W8-P01:**
Actor-bound authority and provenance must be discussed against current identity/delegation work. W8-P01's empirical distinction is not “identity + authorization exist,” but the particular tested combination with **effect-time resource/action binding, stale-effector fencing, tamper-evident governance evidence, recovery-before-effect, cross-Society conformance, and external-runtime composability**.

---

## C. Recent JAAMAS open-system coordination context

**Rother, D.; Pajarinen, J.; Peters, J.; Weisswange, T. H. (2025). _Open-ended coordination for multi-agent systems using modular open policies_. Autonomous Agents and Multi-Agent Systems 39:40.**  
DOI: `10.1007/s10458-025-09723-7`  
Verified publisher source: https://link.springer.com/article/10.1007/s10458-025-09723-7

This paper addresses adaptation/coordination in open multi-agent environments using modular policies and changing partners/tasks.

**Relation rather than direct overlap:**
- it is primarily a learning/coordination contribution, not an identity/authority/fencing/evidence architecture;
- it demonstrates that open-ended, changing-agent settings are active JAAMAS concerns and reinforces the need to frame W8-P01 as governance/effect-boundary architecture rather than generic “open MAS” novelty.

---

# Revised novelty ceiling — binding

After this second prior-art pass, W8-P01 MUST NOT claim standalone novelty for:

- multi-agent governance;
- normative rules, permissions, prohibitions, or obligations;
- enforcement of norms in open MAS;
- distributed norm management;
- persistent/stable agent identity in general;
- topology/provider-independent identity in general;
- capability-bound identity in general;
- delegated agent authorization in general;
- provenance records in general;
- any primitive already excluded by the core registry (RBAC/ABAC, leases/fencing, locks, CAS, idempotency, checkpoints/recovery, hash chains, tracing, orchestration).

## Candidate contribution after hardening

The strongest defensible framing is now:

> **W8-P01 evaluates a particular effect-governance composition in which a logical Actor is bound to exact effect-time authority; stale effectors are excluded by fencing; governance evidence is tamper-evident; effect capability is withheld until recovery passes; the same contract is tested across distinct Society adapters; and the controls are shown to compose over an independent AutoGen Core runtime.**

The novelty claim is therefore **composition + contract boundary + falsification evidence**, not invention of identity, governance, norms, authorization, fencing, evidence, recovery, or agent runtime primitives.

## Manuscript wording rule

Prefer:
- “we evaluate a governed composition…”
- “the tested contract combines…”
- “the empirical contribution is…”
- “the frozen evidence supports…”

Avoid:
- “we introduce persistent agent identity…”
- “the first provider-independent agent identity…”
- “a novel governance mechanism” without a sharply qualified compositional meaning;
- “unique” or “first” unless a later systematic prior-art review supports it.

## Status

Novelty gate after close prior-art search: **PASS WITH NARROWED CLAIM**.

This addendum is binding on Claim Ledger v0.2, JAAMAS manuscript v0.3+, Information Sheet v0.2+, cover letter, abstract, and submission metadata.
