from __future__ import annotations

import argparse
import csv
import json
from pathlib import Path
import random
from dataclasses import replace
from typing import Dict, Iterable, List, Tuple

from model import Receipt, TrialObservation, World8GovernedSystem, SessionScopedBaseline

FAULTS = [f"F{i}" for i in range(11)]


def _ids(seed: int) -> dict:
    return {
        "requester_actor": f"actor-requester-{seed}",
        "reviewer_actor": f"actor-reviewer-{seed}",
        "executor_actor": f"actor-executor-{seed}",
        "auditor_actor": f"actor-auditor-{seed}",
        "requester_session": f"session-requester-{seed}-a",
        "reviewer_session": f"session-reviewer-{seed}-a",
        "executor_session": f"session-executor-{seed}-a",
        "executor_session_b": f"session-executor-{seed}-b",
        "auditor_session": f"session-auditor-{seed}-a",
        "attacker_actor": f"actor-attacker-{seed}",
        "attacker_session": f"session-attacker-{seed}",
        "auth_id": f"auth-{seed}",
        "key1": f"effect-{seed}-1",
        "key2": f"effect-{seed}-2",
    }


def _world8_trial(fault: str, seed: int) -> TrialObservation:
    rng = random.Random(seed)
    i = _ids(seed)
    s = World8GovernedSystem(object_id=f"object-{seed}")
    s.bind_actor(i["requester_actor"], "requester", i["requester_session"])
    s.bind_actor(i["reviewer_actor"], "reviewer", i["reviewer_session"])
    s.bind_actor(i["executor_actor"], "executor", i["executor_session"])
    s.bind_actor(i["auditor_actor"], "auditor", i["auditor_session"])
    s.request(i["requester_actor"], i["requester_session"])
    s.approve(i["reviewer_actor"], i["reviewer_session"], i["executor_actor"], i["auth_id"])
    fence = s.issue_fence(i["executor_actor"], i["executor_session"])

    exec_actor = i["executor_actor"]
    exec_session = i["executor_session"]
    auth_id = i["auth_id"]
    use_fence = fence
    expected_version = s.version
    invalid_attempt_present = fault in {"F2", "F3", "F4", "F5", "F6", "F7", "F8"}
    valid_primary_expected = fault in {"F0", "F1", "F5", "F8", "F9", "F10"}
    primary_committed = False
    invalid_attempt_blocked = not invalid_attempt_present
    failure_class = "NONE"

    if fault == "F1":
        s.replace_session(exec_actor, i["executor_session_b"])
        exec_session = i["executor_session_b"]
    elif fault == "F2":
        s.bind_actor(i["attacker_actor"], "executor", i["attacker_session"])
        exec_actor = i["attacker_actor"]
        exec_session = i["attacker_session"]
    elif fault == "F3":
        s.revoke(auth_id, i["reviewer_actor"], i["reviewer_session"])
    elif fault == "F4":
        expected_version = s.version - 1
    elif fault == "F6":
        auth_id = None
    elif fault == "F7":
        use_fence = fence + 100

    if fault == "F5":
        ok1, c1 = s.execute(exec_actor, exec_session, auth_id, use_fence, expected_version, i["key1"])
        primary_committed = ok1
        s.replace_session(exec_actor, i["executor_session_b"])
        ok2, c2 = s.execute(exec_actor, i["executor_session_b"], auth_id, use_fence, s.version, i["key1"])
        invalid_attempt_blocked = not ok2
        failure_class = c2 if not ok2 else "DUPLICATE_ACCEPTED"
    elif fault == "F8":
        # Same expected version and fence for two competing executors. Order changes by seed.
        attempts = [(i["key1"], "a"), (i["key2"], "b")]
        rng.shuffle(attempts)
        outcomes: List[Tuple[bool, str]] = []
        for key, _ in attempts:
            outcomes.append(s.execute(exec_actor, exec_session, auth_id, use_fence, expected_version, key))
        primary_committed = any(ok for ok, _ in outcomes)
        invalid_attempt_blocked = sum(1 for ok, _ in outcomes if ok) == 1
        failure_class = "+".join(code for ok, code in outcomes if not ok) or "RACE_BOTH_ACCEPTED"
    else:
        ok, code = s.execute(exec_actor, exec_session, auth_id, use_fence, expected_version, i["key1"])
        primary_committed = ok
        if invalid_attempt_present:
            invalid_attempt_blocked = not ok
        failure_class = code if not ok else "NONE"

    # F10 explicitly tests persistence across orchestrator restart before audit.
    if fault == "F10":
        s = s.restart_runtime()

    tampered = False
    audit_receipts = list(s.receipts)
    if fault == "F9" and audit_receipts:
        tampered = True
        candidates = [idx for idx, r in enumerate(audit_receipts) if r.kind == "EXECUTE" and r.outcome == "COMMIT"]
        idx = rng.choice(candidates)
        original = audit_receipts[idx]
        # Modify actor attribution without recomputing the hash. Integrity verification must reject it.
        audit_receipts[idx] = replace(original, actor_id=i["attacker_actor"])

    audit_ok, reconstructed_effects, reconstructed_actors = s.reconstruct(audit_receipts)
    if fault == "F9":
        reconstruction_correct = tampered and not audit_ok
        audit_outcome = "TAMPER_DETECTED" if reconstruction_correct else "TAMPER_MISSED"
    else:
        reconstruction_correct = audit_ok and reconstructed_effects == len(s.effects)
        audit_outcome = "RECONSTRUCTED" if reconstruction_correct else "RECONSTRUCTION_FAILED"

    # Append audit receipt only to the untampered durable chain; it is evidence that the audit action occurred.
    s._append("AUDIT", i["auditor_actor"], i["auditor_session"], audit_outcome, fault)

    required_kinds = {"REQUEST", "REVIEW", "EXECUTE", "AUDIT"}
    present_kinds = {r.kind for r in s.receipts}
    evidence_complete = required_kinds.issubset(present_kinds) and World8GovernedSystem.verify_receipts(s.receipts)

    session_changed = fault in {"F1", "F5", "F10"}
    if session_changed:
        # World 8 continuity is actor-based, not session-based.
        actor_continuity = i["executor_actor"] in s.actors and any(
            r.kind == "EXECUTE" and r.actor_id == i["executor_actor"] for r in s.receipts
        )
    else:
        actor_continuity = True

    unauthorized = fault in {"F2", "F3", "F6", "F7"} and len(s.effects) > 0
    stale_accepted = fault == "F4" and len(s.effects) > 0
    duplicate_effect = fault == "F5" and len(s.effects) > 1
    if fault == "F8" and len(s.effects) > 1:
        duplicate_effect = True  # extra concurrent effect beyond single-winner semantics

    return TrialObservation(
        system="world8_governed",
        fault=fault,
        valid_primary_effect_expected=valid_primary_expected,
        effect_count=len(s.effects),
        unauthorized_effect=unauthorized,
        stale_write_accepted=stale_accepted,
        duplicate_effect=duplicate_effect,
        reconstruction_success=reconstruction_correct,
        actor_attribution_continuity=actor_continuity,
        evidence_complete=evidence_complete,
        invalid_attempt_present=invalid_attempt_present,
        invalid_attempt_blocked=invalid_attempt_blocked,
        valid_primary_effect_succeeded=primary_committed,
        failure_classification=failure_class,
    )


def _baseline_trial(fault: str, seed: int) -> TrialObservation:
    rng = random.Random(seed)
    i = _ids(seed)
    s = SessionScopedBaseline(object_id=f"object-{seed}")
    s.bind_session(i["requester_session"], "requester")
    s.bind_session(i["reviewer_session"], "reviewer")
    s.bind_session(i["executor_session"], "executor")
    s.bind_session(i["auditor_session"], "auditor")
    s.request(i["requester_session"])
    s.approve(i["reviewer_session"])

    exec_session = i["executor_session"]
    invalid_attempt_present = fault in {"F2", "F3", "F4", "F5", "F6", "F7", "F8"}
    valid_primary_expected = fault in {"F0", "F1", "F5", "F8", "F9", "F10"}
    primary_committed = False
    invalid_attempt_blocked = not invalid_attempt_present
    failure_class = "NONE"

    if fault == "F1":
        s.replace_session(exec_session, i["executor_session_b"])
        exec_session = i["executor_session_b"]
    elif fault == "F2":
        # Session-scoped baseline recognizes role labels, not an external persistent actor binding.
        s.bind_session(i["attacker_session"], "executor")
        exec_session = i["attacker_session"]
    elif fault == "F3":
        s.revoke_executor()
    # F4, F6 and F7 have no corresponding baseline mechanism: execution proceeds by role.

    if fault == "F5":
        ok1, c1 = s.execute(exec_session, i["key1"])
        primary_committed = ok1
        s.replace_session(exec_session, i["executor_session_b"])
        ok2, c2 = s.execute(i["executor_session_b"], i["key1"])
        invalid_attempt_blocked = not ok2
        failure_class = c2 if not ok2 else "DUPLICATE_ACCEPTED"
    elif fault == "F8":
        attempts = [i["key1"], i["key2"]]
        rng.shuffle(attempts)
        outcomes = [s.execute(exec_session, key) for key in attempts]
        primary_committed = any(ok for ok, _ in outcomes)
        invalid_attempt_blocked = sum(1 for ok, _ in outcomes if ok) == 1
        failure_class = "+".join(code for ok, code in outcomes if not ok) or "RACE_BOTH_ACCEPTED"
    else:
        ok, code = s.execute(exec_session, i["key1"])
        primary_committed = ok
        if invalid_attempt_present:
            invalid_attempt_blocked = not ok
        failure_class = code if not ok else "NONE"

    if fault == "F10":
        s = s.restart_runtime()

    if fault == "F9" and s.mutable_log:
        commits = [idx for idx, r in enumerate(s.mutable_log) if r.get("kind") == "EXECUTE" and r.get("outcome") == "COMMIT"]
        idx = rng.choice(commits)
        # Mutable log tampering changes attribution while preserving commit count.
        s.mutable_log[idx]["session"] = i["attacker_session"]

    audit_ok, reconstructed_effects, reconstructed_sessions = s.reconstruct()
    if fault == "F9":
        # Baseline has no integrity proof; returning an apparently valid reconstruction is a missed tamper.
        reconstruction_correct = False if audit_ok else True
        audit_outcome = "TAMPER_MISSED" if audit_ok else "TAMPER_DETECTED_BY_ACCIDENT"
    else:
        reconstruction_correct = audit_ok and reconstructed_effects == len(s.effects)
        audit_outcome = "RECONSTRUCTED" if reconstruction_correct else "RECONSTRUCTION_FAILED"
    s.mutable_log.append({"kind": "AUDIT", "session": i["auditor_session"], "outcome": audit_outcome})

    required_kinds = {"REQUEST", "REVIEW", "EXECUTE", "AUDIT"}
    present_kinds = {r.get("kind") for r in s.mutable_log}
    evidence_complete = required_kinds.issubset(present_kinds)

    session_changed = fault in {"F1", "F5", "F10"}
    actor_continuity = not session_changed  # no persistent actor identity exists to prove continuity

    unauthorized = fault in {"F2", "F3", "F6", "F7"} and len(s.effects) > 0
    stale_accepted = fault == "F4" and len(s.effects) > 0
    duplicate_effect = fault == "F5" and len(s.effects) > 1
    if fault == "F8" and len(s.effects) > 1:
        duplicate_effect = True

    return TrialObservation(
        system="session_scoped_baseline",
        fault=fault,
        valid_primary_effect_expected=valid_primary_expected,
        effect_count=len(s.effects),
        unauthorized_effect=unauthorized,
        stale_write_accepted=stale_accepted,
        duplicate_effect=duplicate_effect,
        reconstruction_success=reconstruction_correct,
        actor_attribution_continuity=actor_continuity,
        evidence_complete=evidence_complete,
        invalid_attempt_present=invalid_attempt_present,
        invalid_attempt_blocked=invalid_attempt_blocked,
        valid_primary_effect_succeeded=primary_committed,
        failure_classification=failure_class,
    )


def run_trials(trials_per_fault: int, seed: int) -> List[TrialObservation]:
    out: List[TrialObservation] = []
    for fault_idx, fault in enumerate(FAULTS):
        for n in range(trials_per_fault):
            trial_seed = seed + fault_idx * 1_000_000 + n
            out.append(_world8_trial(fault, trial_seed))
            out.append(_baseline_trial(fault, trial_seed))
    return out


def _rate(rows: List[TrialObservation], field: str, denom_filter=None) -> float:
    selected = [r for r in rows if denom_filter is None or denom_filter(r)]
    if not selected:
        return 0.0
    return sum(1 for r in selected if bool(getattr(r, field))) / len(selected)


def summarize(rows: List[TrialObservation]) -> dict:
    systems = sorted({r.system for r in rows})
    result = {"systems": {}, "faults": FAULTS}
    for system in systems:
        sys_rows = [r for r in rows if r.system == system]
        by_fault = {}
        for fault in FAULTS:
            fr = [r for r in sys_rows if r.fault == fault]
            by_fault[fault] = {
                "trials": len(fr),
                "unauthorized_effect_rate": _rate(fr, "unauthorized_effect"),
                "stale_write_accept_rate": _rate(fr, "stale_write_accepted"),
                "duplicate_effect_rate": _rate(fr, "duplicate_effect"),
                "reconstruction_success_rate": _rate(fr, "reconstruction_success"),
                "actor_attribution_continuity_rate": _rate(fr, "actor_attribution_continuity"),
                "evidence_completeness_rate": _rate(fr, "evidence_complete"),
                "fail_closed_rate_on_invalid_attempts": _rate(fr, "invalid_attempt_blocked", lambda r: r.invalid_attempt_present),
                "false_deny_rate_on_valid_attempts": _rate(fr, "valid_primary_effect_succeeded", lambda r: r.valid_primary_effect_expected),
                "valid_effect_success_rate": _rate(fr, "valid_primary_effect_succeeded", lambda r: r.valid_primary_effect_expected),
                "mean_effect_count": sum(r.effect_count for r in fr) / len(fr),
            }
            # false_deny is complement of valid success on valid-primary trials
            if any(r.valid_primary_effect_expected for r in fr):
                by_fault[fault]["false_deny_rate_on_valid_attempts"] = 1.0 - by_fault[fault]["valid_effect_success_rate"]
            else:
                by_fault[fault]["false_deny_rate_on_valid_attempts"] = 0.0
        result["systems"][system] = {"by_fault": by_fault}
    return result


def write_outputs(rows: List[TrialObservation], output_dir: Path, seed: int, trials_per_fault: int) -> None:
    output_dir.mkdir(parents=True, exist_ok=True)
    raw_path = output_dir / "trials.jsonl"
    with raw_path.open("w", encoding="utf-8") as f:
        for row in rows:
            f.write(json.dumps(row.to_dict(), sort_keys=True) + "\n")

    fields = list(rows[0].to_dict().keys())
    with (output_dir / "trials.csv").open("w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=fields)
        w.writeheader()
        for row in rows:
            w.writerow(row.to_dict())

    summary = summarize(rows)
    summary["seed"] = seed
    summary["trials_per_fault_per_system"] = trials_per_fault
    summary["total_trials"] = len(rows)
    (output_dir / "summary.json").write_text(json.dumps(summary, indent=2, sort_keys=True), encoding="utf-8")


def main() -> None:
    p = argparse.ArgumentParser()
    p.add_argument("--trials", type=int, default=1000)
    p.add_argument("--seed", type=int, default=20260827)
    p.add_argument("--output", type=Path, default=Path("experiments/flagship_governance_v0_1/results"))
    args = p.parse_args()
    rows = run_trials(args.trials, args.seed)
    write_outputs(rows, args.output, args.seed, args.trials)
    print(json.dumps(summarize(rows), indent=2, sort_keys=True))


if __name__ == "__main__":
    main()
