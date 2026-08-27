from __future__ import annotations

import argparse
import importlib.metadata
import json
from pathlib import Path
import tempfile
from typing import TypedDict

from langgraph.checkpoint.sqlite import SqliteSaver
from langgraph.graph import END, START, StateGraph
from langgraph.types import Command, interrupt


class FlowState(TypedDict, total=False):
    request_id: str
    proposed: bool
    approved: bool
    effect_committed: bool


def _effect_lines(path: Path) -> list[str]:
    if not path.exists():
        return []
    return [line for line in path.read_text(encoding="utf-8").splitlines() if line.strip()]


def build_graph(checkpointer: SqliteSaver, effect_log: Path):
    def propose(state: FlowState) -> FlowState:
        return {"proposed": True}

    def approval(state: FlowState) -> FlowState:
        decision = interrupt(
            {
                "type": "approval",
                "request_id": state["request_id"],
                "proposed": bool(state.get("proposed")),
            }
        )
        approved = decision is True or decision == "approve"
        return {"approved": approved}

    def effect(state: FlowState) -> FlowState:
        # This is a bounded synthetic effect for the common-denominator benchmark.
        # It intentionally occurs after the durable approval interrupt; the benchmark
        # does not claim arbitrary crash-time exactly-once external effects.
        with effect_log.open("a", encoding="utf-8") as fh:
            fh.write(state["request_id"] + "\n")
        return {"effect_committed": True}

    def route_after_approval(state: FlowState) -> str:
        return "effect" if state.get("approved") else "end"

    g = StateGraph(FlowState)
    g.add_node("propose", propose)
    g.add_node("approval", approval)
    g.add_node("effect", effect)
    g.add_edge(START, "propose")
    g.add_edge("propose", "approval")
    g.add_conditional_edges("approval", route_after_approval, {"effect": "effect", "end": END})
    g.add_edge("effect", END)
    return g.compile(checkpointer=checkpointer)


def run_one(root: Path, trial: int, decision: str) -> dict:
    root.mkdir(parents=True, exist_ok=True)
    db_path = root / f"trial-{trial}-{decision}.sqlite"
    effect_log = root / f"trial-{trial}-{decision}.effects"
    thread_id = f"w8-p01-langgraph-{trial}-{decision}"
    request_id = f"request-{trial}-{decision}"
    config = {"configurable": {"thread_id": thread_id}}

    # Process instance A: start and stop at the human-approval interrupt.
    with SqliteSaver.from_conn_string(str(db_path)) as saver:
        graph = build_graph(saver, effect_log)
        first = graph.invoke({"request_id": request_id, "proposed": False, "approved": False, "effect_committed": False}, config)
        history_before = list(graph.get_state_history(config))
        snapshot_before = graph.get_state(config)
        interrupted = bool(first.get("__interrupt__")) or bool(snapshot_before.next)

    # Process instance B: reopen the durable checkpointer and resume the same thread.
    with SqliteSaver.from_conn_string(str(db_path)) as saver:
        graph = build_graph(saver, effect_log)
        resumed = graph.invoke(Command(resume=decision), config)
        history_after = list(graph.get_state_history(config))
        snapshot_after = graph.get_state(config)

    effects = _effect_lines(effect_log)
    approved = decision == "approve"
    return {
        "decision": decision,
        "interrupted_before_process_boundary": interrupted,
        "history_before_count": len(history_before),
        "history_after_count": len(history_after),
        "resumed_approved_value": bool(resumed.get("approved")),
        "final_effect_committed": bool(resumed.get("effect_committed")),
        "final_next_empty": len(snapshot_after.next) == 0,
        "effect_count": len(effects),
        "effect_ids": effects,
        "expected_effect_count": 1 if approved else 0,
        "pass": (
            interrupted
            and len(history_before) > 0
            and len(history_after) >= len(history_before)
            and len(snapshot_after.next) == 0
            and bool(resumed.get("approved")) == approved
            and bool(resumed.get("effect_committed")) == approved
            and len(effects) == (1 if approved else 0)
        ),
    }


def run_benchmark(trials: int) -> dict:
    approved_pass = 0
    rejected_pass = 0
    approved_exact = 0
    rejected_zero = 0
    history_present = 0
    examples = []

    with tempfile.TemporaryDirectory(prefix="w8-p01-langgraph-") as td:
        root = Path(td)
        for trial in range(trials):
            approved = run_one(root, trial, "approve")
            rejected = run_one(root, trial, "reject")
            approved_pass += int(approved["pass"])
            rejected_pass += int(rejected["pass"])
            approved_exact += int(approved["effect_count"] == 1)
            rejected_zero += int(rejected["effect_count"] == 0)
            history_present += int(approved["history_before_count"] > 0 and rejected["history_before_count"] > 0)
            if trial < 3:
                examples.append({"approved": approved, "rejected": rejected})

    return {
        "schema": "WORLD8_W8P01_LANGGRAPH_BASELINE/1.0",
        "versions": {
            "langgraph": importlib.metadata.version("langgraph"),
            "langgraph-checkpoint-sqlite": importlib.metadata.version("langgraph-checkpoint-sqlite"),
        },
        "trials": trials,
        "metrics": {
            "approved_restart_resume_rate": approved_pass / trials,
            "approved_effect_exact_count_rate": approved_exact / trials,
            "rejected_restart_resume_rate": rejected_pass / trials,
            "rejected_zero_effect_rate": rejected_zero / trials,
            "checkpoint_history_present_rate": history_present / trials,
        },
        "examples": examples,
        "external_network_or_llm_calls": False,
        "claim_ceiling": "Durable local orchestration baseline only; not an exactly-once external-effect or security proof.",
        "gate_state": "PASS" if approved_pass == trials and rejected_pass == trials else "FAIL",
    }


def main() -> None:
    p = argparse.ArgumentParser()
    p.add_argument("--trials", type=int, default=100)
    p.add_argument("--output", type=Path, default=Path("experiments/flagship_governance_v0_1/e5_langgraph/results"))
    args = p.parse_args()
    result = run_benchmark(args.trials)
    args.output.mkdir(parents=True, exist_ok=True)
    path = args.output / "langgraph_baseline_v1.json"
    path.write_text(json.dumps(result, indent=2, sort_keys=True), encoding="utf-8")
    print(json.dumps(result, indent=2, sort_keys=True))
    if result["gate_state"] != "PASS":
        raise SystemExit(1)


if __name__ == "__main__":
    main()
