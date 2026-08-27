from __future__ import annotations

import argparse
import json
from dataclasses import replace
from pathlib import Path
from typing import Dict

from model_v2 import GovernedFeatures, GovernedVariantSystem, HardenedSessionBaseline


def ids(seed: int) -> dict:
    return {
        "reviewer_actor": f"actor-reviewer-{seed}",
        "executor_actor": f"actor-executor-{seed}",
        "attacker_actor": f"actor-attacker-{seed}",
        "reviewer_session": f"session-reviewer-{seed}",
        "executor_session": f"session-executor-{seed}-a",
        "executor_session_b": f"session-executor-{seed}-b",
        "attacker_session": f"session-attacker-{seed}",
        "auth": f"approval-{seed}",
        "k1": f"effect-{seed}-1",
        "k2": f"effect-{seed}-2",
    }


def setup_w8(seed: int) -> tuple[GovernedVariantSystem, dict, int]:
    i = ids(seed)
    s = GovernedVariantSystem(f"obj-{seed}", GovernedFeatures())
    s.bind_actor(i["reviewer_actor"], "reviewer", i["reviewer_session"])
    s.bind_actor(i["executor_actor"], "executor", i["executor_session"])
    s.approve(i["reviewer_actor"], i["reviewer_session"], i["executor_actor"], i["auth"])
    fence = s.issue_fence(i["executor_actor"], i["executor_session"])
    return s, i, fence


def setup_baseline(seed: int) -> tuple[HardenedSessionBaseline, dict]:
    i = ids(seed)
    s = HardenedSessionBaseline(f"obj-{seed}")
    s.bind_session(i["reviewer_session"], "reviewer")
    s.bind_session(i["executor_session"], "executor")
    s.approve(i["reviewer_session"], i["auth"])
    return s, i


def cf_stolen_auth_after_identity_swap(seed: int) -> Dict[str, bool]:
    w, i, fence = setup_w8(seed)
    w.bind_actor(i["attacker_actor"], "executor", i["attacker_session"])
    w_ok, _, _ = w.execute(i["attacker_actor"], i["attacker_session"], i["auth"], fence, w.version, i["k1"])

    b, i = setup_baseline(seed)
    b.bind_session(i["attacker_session"], "executor")
    b_ok, _, _ = b.execute(i["attacker_session"], i["auth"], b.version, i["k1"])
    return {"world8_blocked": not w_ok and len(w.effects) == 0, "baseline_accepted": b_ok and len(b.effects) == 1}


def cf_stale_fence_after_restart_rotation(seed: int) -> Dict[str, bool]:
    w, i, old_fence = setup_w8(seed)
    first, _, _ = w.execute(i["executor_actor"], i["executor_session"], i["auth"], old_fence, w.version, i["k1"])
    w = w.restart_runtime()
    w.replace_session(i["executor_actor"], i["executor_session_b"])
    new_fence = w.issue_fence(i["executor_actor"], i["executor_session_b"])
    stale_ok, _, _ = w.execute(i["executor_actor"], i["executor_session_b"], i["auth"], old_fence, w.version, i["k2"])

    b, i = setup_baseline(seed)
    first_b, _, _ = b.execute(i["executor_session"], i["auth"], b.version, i["k1"])
    b = b.restart_runtime()
    b.bind_session(i["executor_session_b"], "executor")
    second_b, _, _ = b.execute(i["executor_session_b"], i["auth"], b.version, i["k2"])
    return {
        "world8_first_valid": first,
        "world8_rotated_fence": new_fence != old_fence,
        "world8_stale_fence_blocked": not stale_ok and len(w.effects) == 1,
        "baseline_first_valid": first_b,
        "baseline_no_fence_accepts_second": second_b and len(b.effects) == 2,
    }


def cf_restart_then_tamper(seed: int) -> Dict[str, bool]:
    w, i, fence = setup_w8(seed)
    ok, _, _ = w.execute(i["executor_actor"], i["executor_session"], i["auth"], fence, w.version, i["k1"])
    w = w.restart_runtime()
    receipts = list(w.receipts)
    idx = next(j for j, r in enumerate(receipts) if r.kind == "EXECUTE" and r.outcome == "COMMIT")
    receipts[idx] = replace(receipts[idx], actor_id=i["attacker_actor"])
    audit_ok, _, _ = w.reconstruct(receipts)

    b, i = setup_baseline(seed)
    ok_b, _, _ = b.execute(i["executor_session"], i["auth"], b.version, i["k1"])
    b = b.restart_runtime()
    idx_b = next(j for j, r in enumerate(b.mutable_log) if r.get("kind") == "EXECUTE" and r.get("outcome") == "COMMIT")
    b.mutable_log[idx_b]["session"] = i["attacker_session"]
    audit_b, _, _ = b.reconstruct()
    return {"world8_first_valid": ok, "world8_tamper_detected": not audit_ok, "baseline_first_valid": ok_b, "baseline_tamper_missed": audit_b}


def valid_paths(seed: int) -> Dict[str, bool]:
    # Normal path.
    w, i, fence = setup_w8(seed)
    normal, _, _ = w.execute(i["executor_actor"], i["executor_session"], i["auth"], fence, w.version, i["k1"])

    # Provider/session replacement without changing persistent Actor.
    w2, i2, fence2 = setup_w8(seed + 10_000_000)
    w2.replace_session(i2["executor_actor"], i2["executor_session_b"])
    swapped, _, _ = w2.execute(i2["executor_actor"], i2["executor_session_b"], i2["auth"], fence2, w2.version, i2["k1"])

    # Restart, reconstruct, then obtain a new fence before another write.
    w3, i3, fence3 = setup_w8(seed + 20_000_000)
    first, _, _ = w3.execute(i3["executor_actor"], i3["executor_session"], i3["auth"], fence3, w3.version, i3["k1"])
    w3 = w3.restart_runtime()
    audit_ok, n, _ = w3.reconstruct()
    w3.replace_session(i3["executor_actor"], i3["executor_session_b"])
    new_fence = w3.issue_fence(i3["executor_actor"], i3["executor_session_b"])
    second, _, _ = w3.execute(i3["executor_actor"], i3["executor_session_b"], i3["auth"], new_fence, w3.version, i3["k2"])
    return {"normal": normal, "session_swap": swapped, "restart_reconstruct": first and audit_ok and n == 1 and second}


def run_gate(trials: int, seed: int) -> dict:
    counters = {
        "CF1_STOLEN_AUTH_AFTER_IDENTITY_SWAP": {"world8_safe": 0, "baseline_failure_exposed": 0},
        "CF2_STALE_FENCE_AFTER_RESTART_ROTATION": {"world8_safe": 0, "baseline_failure_exposed": 0},
        "CF3_RESTART_THEN_TAMPER": {"world8_safe": 0, "baseline_failure_exposed": 0},
        "VALID_PATHS": {"normal": 0, "session_swap": 0, "restart_reconstruct": 0},
    }
    for n in range(trials):
        s = seed + n
        r1 = cf_stolen_auth_after_identity_swap(s)
        counters["CF1_STOLEN_AUTH_AFTER_IDENTITY_SWAP"]["world8_safe"] += int(r1["world8_blocked"])
        counters["CF1_STOLEN_AUTH_AFTER_IDENTITY_SWAP"]["baseline_failure_exposed"] += int(r1["baseline_accepted"])

        r2 = cf_stale_fence_after_restart_rotation(s + 1_000_000)
        counters["CF2_STALE_FENCE_AFTER_RESTART_ROTATION"]["world8_safe"] += int(r2["world8_first_valid"] and r2["world8_rotated_fence"] and r2["world8_stale_fence_blocked"])
        counters["CF2_STALE_FENCE_AFTER_RESTART_ROTATION"]["baseline_failure_exposed"] += int(r2["baseline_first_valid"] and r2["baseline_no_fence_accepts_second"])

        r3 = cf_restart_then_tamper(s + 2_000_000)
        counters["CF3_RESTART_THEN_TAMPER"]["world8_safe"] += int(r3["world8_first_valid"] and r3["world8_tamper_detected"])
        counters["CF3_RESTART_THEN_TAMPER"]["baseline_failure_exposed"] += int(r3["baseline_first_valid"] and r3["baseline_tamper_missed"])

        vr = valid_paths(s + 3_000_000)
        for key, ok in vr.items():
            counters["VALID_PATHS"][key] += int(ok)

    rates = {}
    for name, values in counters.items():
        rates[name] = {k: v / trials for k, v in values.items()}

    pass_state = (
        all(rates[name]["world8_safe"] == 1.0 for name in rates if name.startswith("CF"))
        and all(rates["VALID_PATHS"][k] == 1.0 for k in rates["VALID_PATHS"])
    )
    return {
        "schema": "WORLD8_W8P01_COMPOUND_FAULT_GATE/1.0",
        "seed": seed,
        "trials_per_case": trials,
        "rates": rates,
        "world8_false_deny_rate_valid_paths": {k: 1.0 - v for k, v in rates["VALID_PATHS"].items()},
        "gate_state": "PASS" if pass_state else "FAIL",
        "evidence_level": "REFERENCE_MODEL_COMPOUND_FAULT",
        "runtime_db_mutated": False,
    }


def main() -> None:
    p = argparse.ArgumentParser()
    p.add_argument("--trials", type=int, default=1000)
    p.add_argument("--seed", type=int, default=20260827)
    p.add_argument("--output", type=Path, default=Path("experiments/flagship_governance_v0_1/results_compound"))
    a = p.parse_args()
    result = run_gate(a.trials, a.seed)
    a.output.mkdir(parents=True, exist_ok=True)
    path = a.output / "compound_fault_gate_v1.json"
    path.write_text(json.dumps(result, indent=2, sort_keys=True), encoding="utf-8")
    print(json.dumps(result, indent=2, sort_keys=True))
    if result["gate_state"] != "PASS":
        raise SystemExit(1)


if __name__ == "__main__":
    main()
