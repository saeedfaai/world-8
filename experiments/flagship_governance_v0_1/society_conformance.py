from __future__ import annotations

from dataclasses import dataclass, replace
import json
from pathlib import Path
from typing import Dict, List, Tuple

from model_v2 import GovernedFeatures, GovernedVariantSystem


@dataclass(frozen=True)
class SocietySpec:
    society: str
    proposal_label: str
    approval_label: str
    effect_label: str


COMPANY = SocietySpec(
    society="company",
    proposal_label="QUOTE_PROPOSAL",
    approval_label="PURCHASE_APPROVAL",
    effect_label="SUPPLIER_ORDER_EFFECT",
)

TRADING = SocietySpec(
    society="trading",
    proposal_label="FORECAST",
    approval_label="TRADE_DECISION",
    effect_label="SYNTHETIC_ORDER",
)


class SharedKernelSocietyAdapter:
    """A thin domain adapter over the exact same governed kernel.

    Domain objects can propose information/intention, but only the shared kernel's
    explicit authorization path can enable an effect.
    """

    def __init__(self, spec: SocietySpec, seed: int) -> None:
        self.spec = spec
        self.seed = seed
        self.object_id = f"{spec.society}:object:{seed}"
        self.kernel = GovernedVariantSystem(self.object_id, GovernedFeatures())
        self.ids = {
            "proposer_actor": f"{spec.society}:actor:proposer:{seed}",
            "approver_actor": f"{spec.society}:actor:approver:{seed}",
            "executor_actor": f"{spec.society}:actor:executor:{seed}",
            "auditor_actor": f"{spec.society}:actor:auditor:{seed}",
            "proposer_session": f"{spec.society}:session:proposer:{seed}:a",
            "approver_session": f"{spec.society}:session:approver:{seed}:a",
            "executor_session": f"{spec.society}:session:executor:{seed}:a",
            "executor_session_b": f"{spec.society}:session:executor:{seed}:b",
            "auditor_session": f"{spec.society}:session:auditor:{seed}:a",
            "auth": f"{spec.society}:auth:{seed}",
            "key": f"{spec.society}:effect:{seed}",
        }
        self._bind_roles()

    def _bind_roles(self) -> None:
        k, i = self.kernel, self.ids
        k.bind_actor(i["proposer_actor"], "proposer", i["proposer_session"])
        k.bind_actor(i["approver_actor"], "approver", i["approver_session"])
        k.bind_actor(i["executor_actor"], "executor", i["executor_session"])
        k.bind_actor(i["auditor_actor"], "auditor", i["auditor_session"])

    def propose(self) -> None:
        i = self.ids
        self.kernel._append(
            "DOMAIN_PROPOSAL",
            i["proposer_actor"],
            i["proposer_session"],
            "RECORDED",
            self.spec.proposal_label,
        )

    def approve(self) -> None:
        i = self.ids
        self.kernel.approve(
            i["approver_actor"],
            i["approver_session"],
            i["executor_actor"],
            i["auth"],
        )
        self.kernel._append(
            "DOMAIN_APPROVAL",
            i["approver_actor"],
            i["approver_session"],
            "RECORDED",
            self.spec.approval_label,
        )

    def issue_fence(self, session: str | None = None) -> int:
        i = self.ids
        return self.kernel.issue_fence(i["executor_actor"], session or i["executor_session"])

    def effect(self, *, auth: str | None, fence: int | None, expected_version: int,
               session: str | None = None, key: str | None = None) -> Tuple[bool, str, int]:
        i = self.ids
        ok, code, checks = self.kernel.execute(
            i["executor_actor"],
            session or i["executor_session"],
            auth,
            fence,
            expected_version,
            key or i["key"],
        )
        self.kernel._append(
            "DOMAIN_EFFECT",
            i["executor_actor"],
            session or i["executor_session"],
            "COMMITTED" if ok else "BLOCKED",
            f"{self.spec.effect_label}:{code}",
        )
        return ok, code, checks

    def swap_executor_session(self) -> str:
        i = self.ids
        self.kernel.replace_session(i["executor_actor"], i["executor_session_b"])
        return i["executor_session_b"]

    def audit(self, receipts=None) -> bool:
        i = self.ids
        ok, n, _ = self.kernel.reconstruct(receipts)
        self.kernel._append(
            "AUDIT",
            i["auditor_actor"],
            i["auditor_session"],
            "PASS" if ok and n == len(self.kernel.effects) else "FAIL",
            self.spec.society,
        )
        return ok and n == len(self.kernel.effects)

    def restart(self) -> None:
        self.kernel = self.kernel.restart_runtime()


INVARIANTS = [
    "proposal_not_authority",
    "valid_effect",
    "session_swap_identity",
    "stale_writer_rejected",
    "duplicate_suppressed",
    "invalid_fence_rejected",
    "tamper_detected",
    "restart_reconstructs",
]


def run_conformance(spec: SocietySpec, seed: int) -> Dict[str, bool]:
    out: Dict[str, bool] = {}

    # I1: proposal is data/intention, not effect authority.
    a = SharedKernelSocietyAdapter(spec, seed * 100 + 1)
    a.propose()
    fence = a.issue_fence()
    ok, _, _ = a.effect(auth=None, fence=fence, expected_version=a.kernel.version)
    out["proposal_not_authority"] = not ok and len(a.kernel.effects) == 0

    # I2: valid approved path succeeds.
    a = SharedKernelSocietyAdapter(spec, seed * 100 + 2)
    a.propose(); a.approve(); fence = a.issue_fence()
    ok, _, _ = a.effect(auth=a.ids["auth"], fence=fence, expected_version=a.kernel.version)
    out["valid_effect"] = ok and len(a.kernel.effects) == 1

    # I3: provider/session replacement preserves persistent actor authority binding.
    a = SharedKernelSocietyAdapter(spec, seed * 100 + 3)
    a.propose(); a.approve(); fence = a.issue_fence()
    new_session = a.swap_executor_session()
    ok, _, _ = a.effect(auth=a.ids["auth"], fence=fence, expected_version=a.kernel.version, session=new_session)
    commit_actors = {r.actor_id for r in a.kernel.receipts if r.kind == "EXECUTE" and r.outcome == "COMMIT"}
    out["session_swap_identity"] = ok and commit_actors == {a.ids["executor_actor"]}

    # I4: stale writer rejected after a committed version advance.
    a = SharedKernelSocietyAdapter(spec, seed * 100 + 4)
    a.propose(); a.approve(); fence = a.issue_fence(); v0 = a.kernel.version
    ok1, _, _ = a.effect(auth=a.ids["auth"], fence=fence, expected_version=v0, key=a.ids["key"] + ":1")
    ok2, _, _ = a.effect(auth=a.ids["auth"], fence=fence, expected_version=v0, key=a.ids["key"] + ":2")
    out["stale_writer_rejected"] = ok1 and not ok2 and len(a.kernel.effects) == 1

    # I5: same externally visible intent cannot commit twice.
    a = SharedKernelSocietyAdapter(spec, seed * 100 + 5)
    a.propose(); a.approve(); fence = a.issue_fence()
    ok1, _, _ = a.effect(auth=a.ids["auth"], fence=fence, expected_version=a.kernel.version)
    new_session = a.swap_executor_session()
    ok2, _, _ = a.effect(auth=a.ids["auth"], fence=fence, expected_version=a.kernel.version, session=new_session)
    out["duplicate_suppressed"] = ok1 and not ok2 and len(a.kernel.effects) == 1

    # I6: invalid fence cannot authorize a write/effect.
    a = SharedKernelSocietyAdapter(spec, seed * 100 + 6)
    a.propose(); a.approve(); fence = a.issue_fence()
    ok, _, _ = a.effect(auth=a.ids["auth"], fence=fence + 99, expected_version=a.kernel.version)
    out["invalid_fence_rejected"] = not ok and len(a.kernel.effects) == 0

    # I7: receipt attribution tamper must be detected.
    a = SharedKernelSocietyAdapter(spec, seed * 100 + 7)
    a.propose(); a.approve(); fence = a.issue_fence()
    ok, _, _ = a.effect(auth=a.ids["auth"], fence=fence, expected_version=a.kernel.version)
    receipts = list(a.kernel.receipts)
    idx = next(i for i, r in enumerate(receipts) if r.kind == "EXECUTE" and r.outcome == "COMMIT")
    receipts[idx] = replace(receipts[idx], actor_id=f"{spec.society}:actor:tampered")
    audit_ok, _, _ = a.kernel.reconstruct(receipts)
    out["tamper_detected"] = ok and not audit_ok

    # I8: restart/restore preserves durable governed state before a new effect.
    a = SharedKernelSocietyAdapter(spec, seed * 100 + 8)
    a.propose(); a.approve(); fence = a.issue_fence()
    ok, _, _ = a.effect(auth=a.ids["auth"], fence=fence, expected_version=a.kernel.version)
    before_effects = list(a.kernel.effects)
    before_receipts = list(a.kernel.receipts)
    a.restart()
    audit_ok, n, actors = a.kernel.reconstruct()
    out["restart_reconstructs"] = (
        ok
        and a.kernel.effects == before_effects
        and a.kernel.receipts == before_receipts
        and audit_ok
        and n == 1
        and actors == {a.ids["executor_actor"]}
    )

    return out


def run_matrix(trials: int, seed: int) -> dict:
    societies = [COMPANY, TRADING]
    counts = {s.society: {inv: 0 for inv in INVARIANTS} for s in societies}
    for n in range(trials):
        trial_seed = seed + n
        for spec in societies:
            result = run_conformance(spec, trial_seed)
            for inv, ok in result.items():
                counts[spec.society][inv] += int(ok)

    rates = {
        society: {inv: counts[society][inv] / trials for inv in INVARIANTS}
        for society in counts
    }
    vectors_equal = all(rates["company"][inv] == rates["trading"][inv] for inv in INVARIANTS)
    return {
        "seed": seed,
        "trials_per_society": trials,
        "invariants": INVARIANTS,
        "pass_rates": rates,
        "same_suite_same_kernel": True,
        "conformance_vectors_equal": vectors_equal,
        "all_company_pass": all(v == 1.0 for v in rates["company"].values()),
        "all_trading_pass": all(v == 1.0 for v in rates["trading"].values()),
        "market_performance_evaluated": False,
        "live_effects": False,
    }


def main() -> None:
    import argparse
    p = argparse.ArgumentParser()
    p.add_argument("--trials", type=int, default=1000)
    p.add_argument("--seed", type=int, default=20260827)
    p.add_argument("--output", type=Path, default=Path("experiments/flagship_governance_v0_1/results_society"))
    a = p.parse_args()
    result = run_matrix(a.trials, a.seed)
    a.output.mkdir(parents=True, exist_ok=True)
    (a.output / "society_conformance.json").write_text(json.dumps(result, indent=2, sort_keys=True), encoding="utf-8")
    print(json.dumps(result, indent=2, sort_keys=True))


if __name__ == "__main__":
    main()
