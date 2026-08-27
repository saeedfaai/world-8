from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Dict, List

from model_v2 import GovernedFeatures
from run_experiment_v2 import _governed


MUTATIONS = {
    "M1_REMOVE_ACTOR_BINDING": {
        "features": GovernedFeatures(actor_binding=False),
        "scenario": "F2",
        "failure_field": "unauthorized_effect",
        "description": "Remove persistent Actor/session and actor-bound authorization checks.",
    },
    "M2_REMOVE_CAS": {
        "features": GovernedFeatures(cas=False),
        "scenario": "F4",
        "failure_field": "stale_write_accepted",
        "description": "Remove expected-version compare-and-set check.",
    },
    "M3_REMOVE_FENCE": {
        "features": GovernedFeatures(fence=False),
        "scenario": "F7",
        "failure_field": "unauthorized_effect",
        "description": "Remove current fencing-token validation.",
    },
    "M4_REMOVE_IDEMPOTENCY": {
        "features": GovernedFeatures(idempotency=False),
        "scenario": "F5",
        "failure_field": "duplicate_or_extra_effect",
        "description": "Remove durable idempotency suppression.",
    },
    "M5_REMOVE_HASH_CHAIN": {
        "features": GovernedFeatures(tamper_evident_receipts=False),
        "scenario": "F9",
        "failure_field": "audit_correct",
        "invert": True,
        "description": "Trust receipt sequence without hash-chain verification.",
    },
}


def mutation_failure(obs, spec: dict) -> bool:
    value = bool(getattr(obs, spec["failure_field"]))
    return (not value) if spec.get("invert") else value


def run_gate(trials: int, seed: int) -> dict:
    results: Dict[str, dict] = {}
    killed = 0

    for index, (name, spec) in enumerate(MUTATIONS.items()):
        failures: List[bool] = []
        full_failures: List[bool] = []
        scenario = spec["scenario"]
        for n in range(trials):
            trial_seed = seed + index * 1_000_000 + n
            mutant = _governed(name, spec["features"], scenario, trial_seed)
            full = _governed("world8_full", GovernedFeatures(), scenario, trial_seed)
            failures.append(mutation_failure(mutant, spec))
            full_failures.append(mutation_failure(full, spec))

        mutant_failure_rate = sum(failures) / len(failures)
        full_failure_rate = sum(full_failures) / len(full_failures)
        is_killed = mutant_failure_rate == 1.0 and full_failure_rate == 0.0
        killed += int(is_killed)
        results[name] = {
            "scenario": scenario,
            "failure_field": spec["failure_field"],
            "description": spec["description"],
            "trials": trials,
            "mutant_failure_rate": mutant_failure_rate,
            "full_system_failure_rate": full_failure_rate,
            "killed": is_killed,
        }

    total = len(MUTATIONS)
    return {
        "schema": "WORLD8_W8P01_MUTATION_GATE/1.0",
        "seed": seed,
        "trials_per_mutation": trials,
        "mutations": results,
        "killed": killed,
        "total": total,
        "mutation_score": killed / total,
        "gate_state": "PASS" if killed == total else "FAIL",
        "evidence_level": "REFERENCE_MODEL_MUTATION",
        "runtime_db_mutated": False,
    }


def main() -> None:
    p = argparse.ArgumentParser()
    p.add_argument("--trials", type=int, default=500)
    p.add_argument("--seed", type=int, default=20260827)
    p.add_argument("--output", type=Path, default=Path("experiments/flagship_governance_v0_1/results_mutation"))
    a = p.parse_args()
    result = run_gate(a.trials, a.seed)
    a.output.mkdir(parents=True, exist_ok=True)
    path = a.output / "mutation_gate_v1.json"
    path.write_text(json.dumps(result, indent=2, sort_keys=True), encoding="utf-8")
    print(json.dumps(result, indent=2, sort_keys=True))
    if result["gate_state"] != "PASS":
        raise SystemExit(1)


if __name__ == "__main__":
    main()
