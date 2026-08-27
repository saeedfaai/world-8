# W8-P01 E5 — LangGraph External Baseline Scope Freeze

Date: 2026-08-27
Status: FROZEN-CANDIDATE / EXTERNAL BASELINE
Purpose: compare durable orchestration capabilities without constructing a strawman or treating undocumented capabilities as failures.

## Version freeze

- `langgraph==1.2.11`
  - PyPI release date: 2026-08-11
  - package page: https://pypi.org/project/langgraph/1.2.11/
- `langgraph-checkpoint-sqlite==3.1.1`
  - PyPI release date: 2026-07-30
  - package page: https://pypi.org/project/langgraph-checkpoint-sqlite/3.1.1/

SQLite is used only as a deterministic local durable checkpointer for the benchmark. LangGraph's official persistence documentation describes SQLite as suitable for local workflows/testing and Postgres as the production-oriented checkpointer.

## Primary official documentation sources

- Persistence: https://docs.langchain.com/oss/python/langgraph/persistence
- Interrupts: https://docs.langchain.com/oss/python/langgraph/interrupts
- Fault tolerance: https://docs.langchain.com/oss/python/langgraph/fault-tolerance
- Functional API / durable tasks: https://docs.langchain.com/oss/python/langgraph/functional-api
- Human-in-the-loop middleware: https://docs.langchain.com/oss/python/langchain/human-in-the-loop

## What LangGraph is credited with in this comparison

Based on the official documentation reviewed on 2026-08-27, LangGraph is treated as a **strong durable orchestration baseline**, not a weak session-only baseline.

Built-in/documented capabilities credited to LangGraph:
- checkpointed persistent graph state;
- conversation/workflow thread cursor through `thread_id`;
- pause/resume through interrupts;
- human approval/reject/edit patterns;
- restart from the last successful checkpoint after failures;
- pending writes for successful nodes in a failed superstep;
- time-travel / replay / fork of checkpointed graph state;
- durable task patterns intended to avoid repeating non-deterministic work on resume.

The official interrupt documentation also warns that node execution restarts from the beginning around an interrupt and that side effects before interrupts must be idempotent. The functional API documents wrapping side effects/non-deterministic operations in tasks so persisted task results can be reused on resume.

## What is NOT scored as a LangGraph failure

The following World 8 concepts are outside the common-denominator executable benchmark unless official LangGraph documentation provides an equivalent built-in guarantee:
- persistent Actor identity distinct from thread/session/provider identity;
- actor-bound authorization ledger/receipts;
- fencing tokens / lease authority;
- append-only cryptographic hash-chain evidence;
- canonical external-effect commit protocol.

For these rows the comparison uses `APPLICATION_DEFINED / NOT A NATIVE GUARANTEE IN REVIEWED DOCS`, **not FAIL**.

A user can implement policy, identity, authorization, idempotency, cryptographic logging, or fencing around LangGraph. W8-P01 must not claim those extensions are impossible.

## Executable common-denominator benchmark

The benchmark uses no LLM and no network model calls. It tests orchestration semantics only:

1. proposal enters a graph;
2. graph pauses at an approval interrupt;
3. SQLite checkpointer is closed to simulate process boundary;
4. a new graph/checkpointer instance opens the same database;
5. approval resumes the same `thread_id` and commits one synthetic effect;
6. a separate rejected run resumes after process boundary and commits zero effects;
7. checkpoint history is inspected to confirm durable persisted state exists.

Metrics:
- `approved_restart_resume_rate`
- `approved_effect_exact_count_rate` for this bounded workflow
- `rejected_restart_resume_rate`
- `rejected_zero_effect_rate`
- `checkpoint_history_present_rate`

Important ceiling:
`approved_effect_exact_count_rate=1.0` in this benchmark does **not** prove exactly-once external side effects under arbitrary crash timing. LangGraph documentation itself requires side-effect-aware durable task/idempotency design.

## Comparison rule

The external comparison must be reported as:
- **common capability** where both systems provide and exercise a comparable mechanism;
- **different abstraction / application-defined** where the frameworks solve different layers;
- **measured difference** only where an executable test with equivalent semantics exists.

No aggregate “framework score” is permitted.
