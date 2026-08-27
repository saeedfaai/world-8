from __future__ import annotations

import argparse
import asyncio
from dataclasses import asdict, dataclass
from hashlib import sha256
import importlib.metadata
import json
from pathlib import Path
from typing import Dict, List, Optional

from autogen_core import AgentId, MessageContext, RoutedAgent, SingleThreadedAgentRuntime, message_handler


@dataclass
class EffectRequest:
    approval_id: str
    expected_version: int
    idempotency_key: str
    fence_token: Optional[int] = None


@dataclass
class EffectResult:
    ok: bool
    code: str
    runtime_actor: str
    logical_actor: str


@dataclass
class Receipt:
    seq: int
    kind: str
    actor: str
    detail: str
    prev_hash: str
    receipt_hash: str


class GovernanceStore:
    """Application governance wrapped around a real AutoGen Core runtime.

    `hardened` intentionally includes generic controls already granted to the E1
    hardened baseline: approval, revoke, CAS/version and durable idempotency.

    `full_governance` adds the mechanisms under test: persistent logical Actor
    mapping independent of AutoGen runtime AgentId, actor-bound approval, fencing,
    tamper-evident receipts and a recovery gate before effects resume.
    """

    def __init__(self, mode: str, object_id: str) -> None:
        if mode not in {"hardened", "full_governance"}:
            raise ValueError(mode)
        self.mode = mode
        self.object_id = object_id
        self.version = 0
        self.effects: List[str] = []
        self.approvals: Dict[str, dict] = {}
        self.revoked: set[str] = set()
        self.seen: set[str] = set()
        self.runtime_to_actor: Dict[str, str] = {}
        self.current_fence = 0
        self.recovery_ready = True
        self.mutable_log: List[dict] = []
        self.receipts: List[Receipt] = []
        self.checks = 0

    @staticmethod
    def rid(agent_id: AgentId) -> str:
        return f"{agent_id.type}/{agent_id.key}"

    def bind_runtime(self, agent_id: AgentId, logical_actor: str) -> None:
        rid = self.rid(agent_id)
        self.runtime_to_actor[rid] = logical_actor
        self._record("BIND", logical_actor, rid)

    def logical_actor(self, runtime_actor: str) -> str:
        if self.mode == "full_governance":
            return self.runtime_to_actor.get(runtime_actor, "UNBOUND")
        return runtime_actor

    def approve(self, approval_id: str, logical_actor: str) -> None:
        record = {"action": "EFFECT", "object_id": self.object_id}
        if self.mode == "full_governance":
            record["actor_id"] = logical_actor
        self.approvals[approval_id] = record
        self._record("APPROVE", logical_actor, approval_id)

    def revoke(self, approval_id: str) -> None:
        self.revoked.add(approval_id)
        self._record("REVOKE", "reviewer", approval_id)

    def issue_fence(self, logical_actor: str) -> int:
        self.current_fence += 1
        self._record("FENCE", logical_actor, str(self.current_fence))
        return self.current_fence

    def restart(self) -> None:
        if self.mode == "full_governance":
            self.recovery_ready = False
        self._record("RESTART", "runtime", self.mode)

    def recover(self) -> bool:
        if self.mode == "full_governance":
            ok = self.verify_receipts()
            self.recovery_ready = ok
            self._record("RECOVER", "runtime", "PASS" if ok else "BLOCKED")
            return ok
        self._record("RECOVER", "runtime", "UNGUARDED")
        return True

    def execute(self, runtime_actor: str, req: EffectRequest) -> EffectResult:
        logical_actor = self.logical_actor(runtime_actor)
        start = self.checks

        if self.mode == "full_governance":
            self.checks += 1
            if logical_actor == "UNBOUND":
                return self._deny("UNBOUND_RUNTIME", runtime_actor, logical_actor, start)
            self.checks += 1
            if not self.recovery_ready:
                return self._deny("RECOVERY_GATE", runtime_actor, logical_actor, start)

        self.checks += 1
        approval = self.approvals.get(req.approval_id)
        if approval is None:
            return self._deny("MISSING_APPROVAL", runtime_actor, logical_actor, start)

        self.checks += 1
        if req.approval_id in self.revoked:
            return self._deny("REVOKED", runtime_actor, logical_actor, start)

        self.checks += 1
        expected = {"action": "EFFECT", "object_id": self.object_id}
        if self.mode == "full_governance":
            expected["actor_id"] = logical_actor
        if approval != expected:
            return self._deny("APPROVAL_SCOPE", runtime_actor, logical_actor, start)

        if self.mode == "full_governance":
            self.checks += 1
            if req.fence_token != self.current_fence:
                return self._deny("FENCE", runtime_actor, logical_actor, start)

        self.checks += 1
        if req.expected_version != self.version:
            return self._deny("STALE_VERSION", runtime_actor, logical_actor, start)

        self.checks += 1
        if req.idempotency_key in self.seen:
            return self._deny("DUPLICATE", runtime_actor, logical_actor, start)

        self.seen.add(req.idempotency_key)
        self.effects.append(req.idempotency_key)
        self.version += 1
        self._record("EFFECT", logical_actor, req.idempotency_key)
        return EffectResult(True, "COMMIT", runtime_actor, logical_actor)

    def _deny(self, code: str, runtime_actor: str, logical_actor: str, start: int) -> EffectResult:
        self._record("DENY", logical_actor, code)
        return EffectResult(False, code, runtime_actor, logical_actor)

    def _record(self, kind: str, actor: str, detail: str) -> None:
        if self.mode == "hardened":
            self.mutable_log.append({"kind": kind, "actor": actor, "detail": detail})
            return
        prev = self.receipts[-1].receipt_hash if self.receipts else "GENESIS"
        body = {"seq": len(self.receipts) + 1, "kind": kind, "actor": actor, "detail": detail, "prev_hash": prev}
        digest = sha256(json.dumps(body, sort_keys=True, separators=(",", ":")).encode()).hexdigest()
        self.receipts.append(Receipt(receipt_hash=digest, **body))

    def verify_receipts(self, receipts: Optional[List[Receipt]] = None) -> bool:
        if self.mode == "hardened":
            return True  # mutable audit has no cryptographic verification contract
        rs = list(self.receipts if receipts is None else receipts)
        prev = "GENESIS"
        for idx, r in enumerate(rs, start=1):
            if r.seq != idx or r.prev_hash != prev:
                return False
            body = {"seq": r.seq, "kind": r.kind, "actor": r.actor, "detail": r.detail, "prev_hash": r.prev_hash}
            digest = sha256(json.dumps(body, sort_keys=True, separators=(",", ":")).encode()).hexdigest()
            if digest != r.receipt_hash:
                return False
            prev = r.receipt_hash
        return True

    def tamper_and_detect(self) -> bool:
        if self.mode == "hardened":
            if self.mutable_log:
                self.mutable_log[-1]["actor"] = "attacker"
            return False
        if not self.receipts:
            return False
        altered = list(self.receipts)
        last = altered[-1]
        altered[-1] = Receipt(last.seq, last.kind, "attacker", last.detail, last.prev_hash, last.receipt_hash)
        return not self.verify_receipts(altered)


class ExecutorAgent(RoutedAgent):
    def __init__(self, store: GovernanceStore) -> None:
        super().__init__(description="Deterministic effect executor; no LLM or external provider")
        self.store = store

    @message_handler
    async def handle_effect(self, message: EffectRequest, ctx: MessageContext) -> EffectResult:
        return self.store.execute(self.store.rid(self.id), message)


@dataclass
class Observation:
    variant: str
    scenario: str
    safe: bool
    valid_success: bool
    false_deny: bool
    effect_count: int
    terminal_code: str
    actor_continuity: bool
    tamper_detected: Optional[bool]


async def run_case(mode: str, scenario: str, seed: int) -> Observation:
    store = GovernanceStore(mode, f"obj_{seed}")
    runtime = SingleThreadedAgentRuntime()
    await ExecutorAgent.register(runtime, "executor", lambda: ExecutorAgent(store))
    runtime.start()

    primary = AgentId("executor", f"primary_{seed}")
    swap = AgentId("executor", f"swap_{seed}")
    attacker = AgentId("executor", f"attacker_{seed}")
    logical_executor = f"actor_executor_{seed}"
    logical_attacker = f"actor_attacker_{seed}"
    if mode == "full_governance":
        store.bind_runtime(primary, logical_executor)
        store.bind_runtime(swap, logical_executor)
        store.bind_runtime(attacker, logical_attacker)

    approval = f"approval_{seed}"
    store.approve(approval, logical_executor)
    fence = store.issue_fence(logical_executor)
    key1, key2 = f"effect_{seed}_1", f"effect_{seed}_2"

    async def send(agent: AgentId, key: str, version: int, use_fence: Optional[int] = fence) -> EffectResult:
        return await runtime.send_message(
            EffectRequest(approval, version, key, use_fence),
            recipient=agent,
            sender=AgentId("caller", f"caller_{seed}"),
        )

    valid_success = False
    safe = True
    false_deny = False
    actor_continuity = True
    tamper_detected: Optional[bool] = None
    terminal = "NONE"

    if scenario == "V1_NORMAL":
        r = await send(primary, key1, store.version)
        valid_success = r.ok
        safe = r.ok
        false_deny = not r.ok
        terminal = r.code
    elif scenario == "V2_RUNTIME_SWAP_SAME_ACTOR":
        r = await send(swap, key1, store.version)
        valid_success = r.ok
        safe = r.ok
        false_deny = not r.ok
        terminal = r.code
        actor_continuity = (r.logical_actor == logical_executor) if mode == "full_governance" else False
    elif scenario == "V3_RESTART_RECOVER":
        store.restart()
        store.recover()
        r = await send(primary, key1, store.version)
        valid_success = r.ok
        safe = r.ok
        false_deny = not r.ok
        terminal = r.code
    elif scenario == "X1_STOLEN_APPROVAL_AFTER_SWAP":
        r = await send(attacker, key1, store.version)
        safe = not r.ok
        terminal = r.code
        actor_continuity = not r.ok
    elif scenario == "X2_REVOKED_BEFORE_EFFECT":
        store.revoke(approval)
        r = await send(primary, key1, store.version)
        safe = not r.ok
        terminal = r.code
    elif scenario == "X3_STALE_VERSION":
        r = await send(primary, key1, store.version - 1)
        safe = not r.ok
        terminal = r.code
    elif scenario == "X4_DUPLICATE_RETRY":
        r1 = await send(primary, key1, store.version)
        r2 = await send(primary, key1, store.version)
        safe = r1.ok and not r2.ok and len(store.effects) == 1
        terminal = r2.code
    elif scenario == "X5_STALE_FENCE_AFTER_ROTATION":
        stale = fence
        store.issue_fence(logical_executor)
        r = await send(primary, key1, store.version, stale)
        safe = not r.ok
        terminal = r.code
    elif scenario == "X6_EVIDENCE_TAMPER":
        r = await send(primary, key1, store.version)
        tamper_detected = store.tamper_and_detect()
        safe = r.ok and bool(tamper_detected)
        terminal = "TAMPER_DETECTED" if tamper_detected else "TAMPER_MISSED"
    elif scenario == "X7_EFFECT_BEFORE_RECOVERY":
        store.restart()
        r = await send(primary, key1, store.version)
        safe = not r.ok
        terminal = r.code
    else:
        raise ValueError(scenario)

    await runtime.stop_when_idle()
    return Observation(mode, scenario, safe, valid_success, false_deny, len(store.effects), terminal, actor_continuity, tamper_detected)


SCENARIOS = [
    "V1_NORMAL",
    "V2_RUNTIME_SWAP_SAME_ACTOR",
    "V3_RESTART_RECOVER",
    "X1_STOLEN_APPROVAL_AFTER_SWAP",
    "X2_REVOKED_BEFORE_EFFECT",
    "X3_STALE_VERSION",
    "X4_DUPLICATE_RETRY",
    "X5_STALE_FENCE_AFTER_ROTATION",
    "X6_EVIDENCE_TAMPER",
    "X7_EFFECT_BEFORE_RECOVERY",
]


async def run_all(trials: int, seed: int) -> dict:
    rows: List[Observation] = []
    for mode in ("hardened", "full_governance"):
        for idx, scenario in enumerate(SCENARIOS):
            for n in range(trials):
                rows.append(await run_case(mode, scenario, seed + idx * 100000 + n))

    rates: Dict[str, dict] = {}
    for mode in ("hardened", "full_governance"):
        rates[mode] = {}
        for scenario in SCENARIOS:
            sr = [r for r in rows if r.variant == mode and r.scenario == scenario]
            rates[mode][scenario] = {
                "trials": len(sr),
                "safe_rate": sum(r.safe for r in sr) / len(sr),
                "valid_success_rate": sum(r.valid_success for r in sr) / len(sr),
                "false_deny_rate": sum(r.false_deny for r in sr) / len(sr),
                "actor_continuity_rate": sum(r.actor_continuity for r in sr) / len(sr),
                "mean_effect_count": sum(r.effect_count for r in sr) / len(sr),
            }

    return {
        "schema": "WORLD8_W8P01_AUTOGEN_EXTERNAL_BASELINE/1.0",
        "seed": seed,
        "trials_per_case": trials,
        "autogen_core_version": importlib.metadata.version("autogen-core"),
        "llm_used": False,
        "external_effects": False,
        "interpretation_scope": "AutoGen Core runtime plus explicitly documented application governance wrappers",
        "rates": rates,
        "rows": [asdict(r) for r in rows],
    }


def main() -> None:
    p = argparse.ArgumentParser()
    p.add_argument("--trials", type=int, default=100)
    p.add_argument("--seed", type=int, default=20260827)
    p.add_argument("--output", type=Path, default=Path("experiments/flagship_governance_v0_1/results_external_autogen"))
    a = p.parse_args()
    result = asyncio.run(run_all(a.trials, a.seed))
    a.output.mkdir(parents=True, exist_ok=True)
    compact = dict(result)
    rows = compact.pop("rows")
    (a.output / "autogen_external_summary.json").write_text(json.dumps(compact, indent=2, sort_keys=True), encoding="utf-8")
    with (a.output / "autogen_external_trials.jsonl").open("w", encoding="utf-8") as f:
        for row in rows:
            f.write(json.dumps(row, sort_keys=True) + "\n")
    print(json.dumps(compact, indent=2, sort_keys=True))


if __name__ == "__main__":
    main()
