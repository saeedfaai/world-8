from __future__ import annotations

import argparse
from dataclasses import dataclass, asdict, replace
import csv
import json
from pathlib import Path
import random
from typing import Dict, List, Optional, Tuple

from model_v2 import GovernedFeatures, GovernedVariantSystem, HardenedSessionBaseline

DIRECTED = [f"F{i}" for i in range(11)]
COMPOUND = ["C1_REVOKE_RACE", "C2_SESSION_SWAP_STALE_RETRY", "C3_RESTART_TAMPER"]
SCENARIOS = DIRECTED + COMPOUND

VARIANTS: Dict[str, GovernedFeatures] = {
    "world8_full": GovernedFeatures(),
    "w8_ablate_actor_binding": GovernedFeatures(actor_binding=False),
    "w8_ablate_cas": GovernedFeatures(cas=False),
    "w8_ablate_fence": GovernedFeatures(fence=False),
    "w8_ablate_idempotency": GovernedFeatures(idempotency=False),
    "w8_ablate_hash_chain": GovernedFeatures(tamper_evident_receipts=False),
}


@dataclass
class ObservationV2:
    system: str
    scenario: str
    effect_count: int
    valid_primary_expected: bool
    valid_primary_succeeded: bool
    invalid_attempt_present: bool
    invalid_attempt_blocked: bool
    unauthorized_effect: bool
    stale_write_accepted: bool
    duplicate_or_extra_effect: bool
    audit_correct: bool
    actor_continuity: bool
    evidence_complete: bool
    policy_checks: int
    evidence_records: int
    terminal_code: str

    def to_dict(self) -> dict:
        return asdict(self)


def ids(seed: int) -> dict:
    return {
        "requester_actor": f"actor-requester-{seed}",
        "reviewer_actor": f"actor-reviewer-{seed}",
        "executor_actor": f"actor-executor-{seed}",
        "auditor_actor": f"actor-auditor-{seed}",
        "attacker_actor": f"actor-attacker-{seed}",
        "requester_session": f"session-requester-{seed}-a",
        "reviewer_session": f"session-reviewer-{seed}-a",
        "executor_session": f"session-executor-{seed}-a",
        "executor_session_b": f"session-executor-{seed}-b",
        "auditor_session": f"session-auditor-{seed}-a",
        "attacker_session": f"session-attacker-{seed}",
        "auth": f"approval-{seed}",
        "k1": f"effect-{seed}-1",
        "k2": f"effect-{seed}-2",
        "k3": f"effect-{seed}-3",
    }


def _governed(system_name: str, features: GovernedFeatures, scenario: str, seed: int) -> ObservationV2:
    rng = random.Random(seed)
    i = ids(seed)
    s = GovernedVariantSystem(f"obj-{seed}", features)
    s.bind_actor(i["requester_actor"], "requester", i["requester_session"])
    s.bind_actor(i["reviewer_actor"], "reviewer", i["reviewer_session"])
    s.bind_actor(i["executor_actor"], "executor", i["executor_session"])
    s.bind_actor(i["auditor_actor"], "auditor", i["auditor_session"])
    s.request(i["requester_actor"], i["requester_session"])
    s.approve(i["reviewer_actor"], i["reviewer_session"], i["executor_actor"], i["auth"])
    fence = s.issue_fence(i["executor_actor"], i["executor_session"])

    exec_actor = i["executor_actor"]
    exec_session = i["executor_session"]
    auth: Optional[str] = i["auth"]
    use_fence: Optional[int] = fence
    expected_version = s.version
    valid_primary_expected = scenario in {"F0", "F1", "F5", "F8", "F9", "F10", "C2_SESSION_SWAP_STALE_RETRY", "C3_RESTART_TAMPER"}
    invalid_attempt_present = scenario in {"F2", "F3", "F4", "F5", "F6", "F7", "F8", "C1_REVOKE_RACE", "C2_SESSION_SWAP_STALE_RETRY"}
    primary_ok = False
    blocked = not invalid_attempt_present
    terminal = "NONE"

    if scenario == "F1":
        s.replace_session(exec_actor, i["executor_session_b"])
        exec_session = i["executor_session_b"]
    elif scenario == "F2":
        s.bind_actor(i["attacker_actor"], "executor", i["attacker_session"])
        exec_actor = i["attacker_actor"]
        exec_session = i["attacker_session"]
    elif scenario == "F3":
        s.revoke(i["auth"], i["reviewer_actor"], i["reviewer_session"])
    elif scenario == "F4":
        expected_version = s.version - 1
    elif scenario == "F6":
        auth = None
    elif scenario == "F7":
        use_fence = fence + 100

    if scenario == "F5":
        ok1, _, _ = s.execute(exec_actor, exec_session, auth, use_fence, expected_version, i["k1"])
        primary_ok = ok1
        s.replace_session(exec_actor, i["executor_session_b"])
        ok2, code2, _ = s.execute(exec_actor, i["executor_session_b"], auth, use_fence, s.version, i["k1"])
        blocked = not ok2
        terminal = code2
    elif scenario == "F8":
        attempts = [i["k1"], i["k2"]]
        rng.shuffle(attempts)
        outcomes = [s.execute(exec_actor, exec_session, auth, use_fence, expected_version, key) for key in attempts]
        primary_ok = any(o[0] for o in outcomes)
        blocked = sum(1 for o in outcomes if o[0]) == 1
        terminal = "+".join(o[1] for o in outcomes if not o[0]) or "RACE_BOTH_ACCEPTED"
    elif scenario == "C1_REVOKE_RACE":
        s.revoke(i["auth"], i["reviewer_actor"], i["reviewer_session"])
        outcomes = [s.execute(exec_actor, exec_session, auth, use_fence, expected_version, key) for key in (i["k1"], i["k2"])]
        primary_ok = False
        blocked = all(not o[0] for o in outcomes)
        terminal = "+".join(o[1] for o in outcomes)
    elif scenario == "C2_SESSION_SWAP_STALE_RETRY":
        ok1, _, _ = s.execute(exec_actor, exec_session, auth, use_fence, expected_version, i["k1"])
        primary_ok = ok1
        stale_version = expected_version
        s.replace_session(exec_actor, i["executor_session_b"])
        ok2, code2, _ = s.execute(exec_actor, i["executor_session_b"], auth, use_fence, stale_version, i["k2"])
        blocked = not ok2
        terminal = code2
    else:
        ok, code, _ = s.execute(exec_actor, exec_session, auth, use_fence, expected_version, i["k1"])
        primary_ok = ok
        if invalid_attempt_present:
            blocked = not ok
        terminal = code

    if scenario == "F10":
        s = s.restart_runtime()

    audit_receipts = list(s.receipts)
    tamper_expected = scenario in {"F9", "C3_RESTART_TAMPER"}
    if scenario == "C3_RESTART_TAMPER":
        if not primary_ok:
            # C3 starts from a valid committed effect.
            ok, _, _ = s.execute(exec_actor, exec_session, auth, use_fence, s.version, i["k1"])
            primary_ok = ok
        s = s.restart_runtime()
        audit_receipts = list(s.receipts)

    if tamper_expected:
        commits = [idx for idx, r in enumerate(audit_receipts) if r.kind == "EXECUTE" and r.outcome == "COMMIT"]
        idx = rng.choice(commits)
        audit_receipts[idx] = replace(audit_receipts[idx], actor_id=i["attacker_actor"])

    audit_ok, n_effects, _ = s.reconstruct(audit_receipts)
    if tamper_expected:
        audit_correct = not audit_ok
        audit_outcome = "TAMPER_DETECTED" if audit_correct else "TAMPER_MISSED"
    else:
        audit_correct = audit_ok and n_effects == len(s.effects)
        audit_outcome = "RECONSTRUCTED" if audit_correct else "RECONSTRUCTION_FAILED"

    s._append("AUDIT", i["auditor_actor"], i["auditor_session"], audit_outcome, scenario)
    kinds = {r.kind for r in s.receipts}
    evidence_complete = {"REQUEST", "REVIEW", "EXECUTE", "AUDIT"}.issubset(kinds) and s.verify_receipts(s.receipts)

    session_challenge = scenario in {"F1", "F5", "F10", "C2_SESSION_SWAP_STALE_RETRY", "C3_RESTART_TAMPER"}
    actor_continuity = True
    if session_challenge:
        actor_continuity = any(r.kind == "EXECUTE" and r.actor_id == i["executor_actor"] for r in s.receipts)

    unauthorized = scenario in {"F2", "F3", "F6", "F7", "C1_REVOKE_RACE"} and len(s.effects) > 0
    stale = scenario in {"F4", "C2_SESSION_SWAP_STALE_RETRY"} and ((scenario == "F4" and len(s.effects) > 0) or (scenario.startswith("C2") and len(s.effects) > 1))
    extra = (scenario == "F5" and len(s.effects) > 1) or (scenario == "F8" and len(s.effects) > 1)

    return ObservationV2(
        system=system_name,
        scenario=scenario,
        effect_count=len(s.effects),
        valid_primary_expected=valid_primary_expected,
        valid_primary_succeeded=primary_ok,
        invalid_attempt_present=invalid_attempt_present,
        invalid_attempt_blocked=blocked,
        unauthorized_effect=unauthorized,
        stale_write_accepted=stale,
        duplicate_or_extra_effect=extra,
        audit_correct=audit_correct,
        actor_continuity=actor_continuity,
        evidence_complete=evidence_complete,
        policy_checks=s.policy_checks,
        evidence_records=len(s.receipts),
        terminal_code=terminal,
    )


def _hardened(scenario: str, seed: int) -> ObservationV2:
    rng = random.Random(seed)
    i = ids(seed)
    s = HardenedSessionBaseline(f"obj-{seed}")
    s.bind_session(i["requester_session"], "requester")
    s.bind_session(i["reviewer_session"], "reviewer")
    s.bind_session(i["executor_session"], "executor")
    s.bind_session(i["auditor_session"], "auditor")
    s.request(i["requester_session"])
    s.approve(i["reviewer_session"], i["auth"])

    exec_session = i["executor_session"]
    approval: Optional[str] = i["auth"]
    expected_version = s.version
    valid_primary_expected = scenario in {"F0", "F1", "F5", "F8", "F9", "F10", "C2_SESSION_SWAP_STALE_RETRY", "C3_RESTART_TAMPER"}
    invalid_attempt_present = scenario in {"F2", "F3", "F4", "F5", "F6", "F7", "F8", "C1_REVOKE_RACE", "C2_SESSION_SWAP_STALE_RETRY"}
    primary_ok = False
    blocked = not invalid_attempt_present
    terminal = "NONE"

    if scenario == "F1":
        s.replace_session(exec_session, i["executor_session_b"])
        exec_session = i["executor_session_b"]
    elif scenario == "F2":
        s.bind_session(i["attacker_session"], "executor")
        exec_session = i["attacker_session"]
    elif scenario == "F3":
        s.revoke(i["auth"])
    elif scenario == "F4":
        expected_version = s.version - 1
    elif scenario == "F6":
        approval = None
    # F7 intentionally has no fencing concept in the hardened baseline.

    if scenario == "F5":
        ok1, _, _ = s.execute(exec_session, approval, expected_version, i["k1"])
        primary_ok = ok1
        s.replace_session(exec_session, i["executor_session_b"])
        ok2, code2, _ = s.execute(i["executor_session_b"], approval, s.version, i["k1"])
        blocked = not ok2
        terminal = code2
    elif scenario == "F8":
        attempts = [i["k1"], i["k2"]]
        rng.shuffle(attempts)
        outcomes = [s.execute(exec_session, approval, expected_version, key) for key in attempts]
        primary_ok = any(o[0] for o in outcomes)
        blocked = sum(1 for o in outcomes if o[0]) == 1
        terminal = "+".join(o[1] for o in outcomes if not o[0]) or "RACE_BOTH_ACCEPTED"
    elif scenario == "C1_REVOKE_RACE":
        s.revoke(i["auth"])
        outcomes = [s.execute(exec_session, approval, expected_version, key) for key in (i["k1"], i["k2"])]
        blocked = all(not o[0] for o in outcomes)
        terminal = "+".join(o[1] for o in outcomes)
    elif scenario == "C2_SESSION_SWAP_STALE_RETRY":
        ok1, _, _ = s.execute(exec_session, approval, expected_version, i["k1"])
        primary_ok = ok1
        stale_version = expected_version
        s.replace_session(exec_session, i["executor_session_b"])
        ok2, code2, _ = s.execute(i["executor_session_b"], approval, stale_version, i["k2"])
        blocked = not ok2
        terminal = code2
    else:
        ok, code, _ = s.execute(exec_session, approval, expected_version, i["k1"])
        primary_ok = ok
        if invalid_attempt_present:
            blocked = not ok
        terminal = code

    if scenario == "F10":
        s = s.restart_runtime()

    tamper_expected = scenario in {"F9", "C3_RESTART_TAMPER"}
    if scenario == "C3_RESTART_TAMPER":
        if not primary_ok:
            ok, _, _ = s.execute(exec_session, approval, s.version, i["k1"])
            primary_ok = ok
        s = s.restart_runtime()

    if tamper_expected:
        commits = [idx for idx, r in enumerate(s.mutable_log) if r.get("kind") == "EXECUTE" and r.get("outcome") == "COMMIT"]
        idx = rng.choice(commits)
        s.mutable_log[idx]["session"] = i["attacker_session"]

    audit_ok, n_effects, _ = s.reconstruct()
    if tamper_expected:
        audit_correct = not audit_ok
        audit_outcome = "TAMPER_DETECTED" if audit_correct else "TAMPER_MISSED"
    else:
        audit_correct = audit_ok and n_effects == len(s.effects)
        audit_outcome = "RECONSTRUCTED" if audit_correct else "RECONSTRUCTION_FAILED"
    s.mutable_log.append({"kind": "AUDIT", "session": i["auditor_session"], "outcome": audit_outcome})

    kinds = {r.get("kind") for r in s.mutable_log}
    evidence_complete = {"REQUEST", "REVIEW", "EXECUTE", "AUDIT"}.issubset(kinds)
    session_challenge = scenario in {"F1", "F5", "F10", "C2_SESSION_SWAP_STALE_RETRY", "C3_RESTART_TAMPER"}
    actor_continuity = not session_challenge

    unauthorized = scenario in {"F2", "F3", "F6", "F7", "C1_REVOKE_RACE"} and len(s.effects) > 0
    stale = scenario in {"F4", "C2_SESSION_SWAP_STALE_RETRY"} and ((scenario == "F4" and len(s.effects) > 0) or (scenario.startswith("C2") and len(s.effects) > 1))
    extra = (scenario == "F5" and len(s.effects) > 1) or (scenario == "F8" and len(s.effects) > 1)

    return ObservationV2(
        system="hardened_session_baseline",
        scenario=scenario,
        effect_count=len(s.effects),
        valid_primary_expected=valid_primary_expected,
        valid_primary_succeeded=primary_ok,
        invalid_attempt_present=invalid_attempt_present,
        invalid_attempt_blocked=blocked,
        unauthorized_effect=unauthorized,
        stale_write_accepted=stale,
        duplicate_or_extra_effect=extra,
        audit_correct=audit_correct,
        actor_continuity=actor_continuity,
        evidence_complete=evidence_complete,
        policy_checks=s.policy_checks,
        evidence_records=len(s.mutable_log),
        terminal_code=terminal,
    )


def run(trials: int, seed: int) -> List[ObservationV2]:
    rows: List[ObservationV2] = []
    for scenario_idx, scenario in enumerate(SCENARIOS):
        for n in range(trials):
            trial_seed = seed + scenario_idx * 1_000_000 + n
            rows.append(_hardened(scenario, trial_seed))
            for name, features in VARIANTS.items():
                rows.append(_governed(name, features, scenario, trial_seed))
    return rows


def rate(rows: List[ObservationV2], field: str, pred=None) -> Optional[float]:
    selected = [r for r in rows if pred is None or pred(r)]
    if not selected:
        return None
    return sum(1 for r in selected if bool(getattr(r, field))) / len(selected)


def summarize(rows: List[ObservationV2]) -> dict:
    systems = sorted({r.system for r in rows})
    summary = {"scenarios": SCENARIOS, "systems": {}}
    for system in systems:
        sr = [r for r in rows if r.system == system]
        per = {}
        for scenario in SCENARIOS:
            rr = [r for r in sr if r.scenario == scenario]
            valid_success = rate(rr, "valid_primary_succeeded", lambda r: r.valid_primary_expected)
            per[scenario] = {
                "trials": len(rr),
                "valid_effect_success_rate": valid_success,
                "false_deny_rate_on_valid_attempts": None if valid_success is None else 1.0 - valid_success,
                "fail_closed_rate_on_invalid_attempts": rate(rr, "invalid_attempt_blocked", lambda r: r.invalid_attempt_present),
                "unauthorized_effect_rate": rate(rr, "unauthorized_effect"),
                "stale_write_accept_rate": rate(rr, "stale_write_accepted"),
                "duplicate_or_extra_effect_rate": rate(rr, "duplicate_or_extra_effect"),
                "audit_correct_rate": rate(rr, "audit_correct"),
                "actor_continuity_rate": rate(rr, "actor_continuity"),
                "evidence_completeness_rate": rate(rr, "evidence_complete"),
                "mean_policy_checks": sum(r.policy_checks for r in rr) / len(rr),
                "mean_evidence_records": sum(r.evidence_records for r in rr) / len(rr),
                "mean_effect_count": sum(r.effect_count for r in rr) / len(rr),
            }
        summary["systems"][system] = {"by_scenario": per}
    return summary


def write(rows: List[ObservationV2], out: Path, seed: int, trials: int) -> None:
    out.mkdir(parents=True, exist_ok=True)
    with (out / "trials_v2.jsonl").open("w", encoding="utf-8") as f:
        for r in rows:
            f.write(json.dumps(r.to_dict(), sort_keys=True) + "\n")
    fields = list(rows[0].to_dict())
    with (out / "trials_v2.csv").open("w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=fields)
        w.writeheader()
        for r in rows:
            w.writerow(r.to_dict())
    s = summarize(rows)
    s["seed"] = seed
    s["trials_per_scenario_per_system"] = trials
    s["total_trials"] = len(rows)
    (out / "summary_v2.json").write_text(json.dumps(s, indent=2, sort_keys=True), encoding="utf-8")


def main() -> None:
    p = argparse.ArgumentParser()
    p.add_argument("--trials", type=int, default=1000)
    p.add_argument("--seed", type=int, default=20260827)
    p.add_argument("--output", type=Path, default=Path("experiments/flagship_governance_v0_1/results_v2"))
    a = p.parse_args()
    rows = run(a.trials, a.seed)
    write(rows, a.output, a.seed, a.trials)
    print(json.dumps(summarize(rows), indent=2, sort_keys=True))


if __name__ == "__main__":
    main()
