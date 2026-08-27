from __future__ import annotations

from dataclasses import dataclass, asdict
import hashlib
import json
from typing import Dict, List, Optional, Set, Tuple


def canonical_hash(payload: dict) -> str:
    raw = json.dumps(payload, sort_keys=True, separators=(",", ":")).encode("utf-8")
    return hashlib.sha256(raw).hexdigest()


@dataclass(frozen=True)
class Receipt:
    seq: int
    kind: str
    actor_id: str
    session_id: str
    object_id: str
    outcome: str
    detail: str
    prev_hash: str
    receipt_hash: str

    @staticmethod
    def build(seq: int, kind: str, actor_id: str, session_id: str, object_id: str,
              outcome: str, detail: str, prev_hash: str) -> "Receipt":
        body = {
            "seq": seq,
            "kind": kind,
            "actor_id": actor_id,
            "session_id": session_id,
            "object_id": object_id,
            "outcome": outcome,
            "detail": detail,
            "prev_hash": prev_hash,
        }
        return Receipt(receipt_hash=canonical_hash(body), **body)


@dataclass
class TrialObservation:
    system: str
    fault: str
    valid_primary_effect_expected: bool
    effect_count: int
    unauthorized_effect: bool
    stale_write_accepted: bool
    duplicate_effect: bool
    reconstruction_success: bool
    actor_attribution_continuity: bool
    evidence_complete: bool
    invalid_attempt_present: bool
    invalid_attempt_blocked: bool
    valid_primary_effect_succeeded: bool
    failure_classification: str

    def to_dict(self) -> dict:
        return asdict(self)


class World8GovernedSystem:
    """Small executable reference model for measured World 8 mechanisms.

    This is not the production runtime. It is a deterministic experiment model whose
    semantics are intentionally limited to the mechanisms frozen in PROTOCOL.md.
    """

    def __init__(self, object_id: str = "object-1") -> None:
        self.object_id = object_id
        self.version = 0
        self.value = 0
        self.effects: List[str] = []
        self.actors: Dict[str, str] = {}  # actor_id -> role
        self.sessions: Dict[str, str] = {}  # session_id -> actor_id
        self.authorizations: Dict[str, dict] = {}
        self.revoked: Set[str] = set()
        self.current_fence = 0
        self.valid_fences: Set[int] = set()
        self.seen_idempotency: Set[str] = set()
        self.receipts: List[Receipt] = []

    def _append(self, kind: str, actor_id: str, session_id: str, outcome: str, detail: str) -> None:
        prev = self.receipts[-1].receipt_hash if self.receipts else "GENESIS"
        self.receipts.append(Receipt.build(
            seq=len(self.receipts) + 1,
            kind=kind,
            actor_id=actor_id,
            session_id=session_id,
            object_id=self.object_id,
            outcome=outcome,
            detail=detail,
            prev_hash=prev,
        ))

    def bind_actor(self, actor_id: str, role: str, session_id: str) -> None:
        self.actors[actor_id] = role
        self.sessions[session_id] = actor_id
        self._append("ACTOR_BIND", actor_id, session_id, "OK", role)

    def replace_session(self, actor_id: str, new_session_id: str) -> None:
        if actor_id not in self.actors:
            raise KeyError(actor_id)
        self.sessions[new_session_id] = actor_id
        self._append("SESSION_REPLACE", actor_id, new_session_id, "OK", self.actors[actor_id])

    def request(self, actor_id: str, session_id: str) -> None:
        self._append("REQUEST", actor_id, session_id, "OK", "change_requested")

    def approve(self, actor_id: str, session_id: str, executor_actor_id: str, auth_id: str) -> None:
        self.authorizations[auth_id] = {
            "actor_id": executor_actor_id,
            "action": "WRITE",
            "object_id": self.object_id,
        }
        self._append("REVIEW", actor_id, session_id, "APPROVED", auth_id)

    def revoke(self, auth_id: str, actor_id: str, session_id: str) -> None:
        self.revoked.add(auth_id)
        self._append("AUTH_REVOKE", actor_id, session_id, "OK", auth_id)

    def issue_fence(self, actor_id: str, session_id: str) -> int:
        self.current_fence += 1
        self.valid_fences = {self.current_fence}
        self._append("LEASE", actor_id, session_id, "ISSUED", str(self.current_fence))
        return self.current_fence

    def execute(self, actor_id: str, session_id: str, auth_id: Optional[str], fence: Optional[int],
                expected_version: int, idempotency_key: str) -> Tuple[bool, str]:
        bound_actor = self.sessions.get(session_id)
        if bound_actor != actor_id:
            self._append("EXECUTE", actor_id, session_id, "DENY", "IDENTITY_BINDING")
            return False, "IDENTITY_BINDING"
        if not auth_id or auth_id not in self.authorizations:
            self._append("EXECUTE", actor_id, session_id, "DENY", "MISSING_AUTH")
            return False, "MISSING_AUTH"
        auth = self.authorizations[auth_id]
        if auth_id in self.revoked:
            self._append("EXECUTE", actor_id, session_id, "DENY", "REVOKED")
            return False, "REVOKED"
        if auth != {"actor_id": actor_id, "action": "WRITE", "object_id": self.object_id}:
            self._append("EXECUTE", actor_id, session_id, "DENY", "AUTH_SCOPE")
            return False, "AUTH_SCOPE"
        if fence is None or fence not in self.valid_fences or fence != self.current_fence:
            self._append("EXECUTE", actor_id, session_id, "DENY", "FENCE")
            return False, "FENCE"
        if expected_version != self.version:
            self._append("EXECUTE", actor_id, session_id, "DENY", "STALE_VERSION")
            return False, "STALE_VERSION"
        if idempotency_key in self.seen_idempotency:
            self._append("EXECUTE", actor_id, session_id, "DENY", "DUPLICATE")
            return False, "DUPLICATE"

        self.seen_idempotency.add(idempotency_key)
        self.value += 1
        self.version += 1
        self.effects.append(idempotency_key)
        self._append("EXECUTE", actor_id, session_id, "COMMIT", idempotency_key)
        return True, "COMMIT"

    @staticmethod
    def verify_receipts(receipts: List[Receipt]) -> bool:
        prev = "GENESIS"
        for expected_seq, r in enumerate(receipts, start=1):
            if r.seq != expected_seq or r.prev_hash != prev:
                return False
            body = {
                "seq": r.seq,
                "kind": r.kind,
                "actor_id": r.actor_id,
                "session_id": r.session_id,
                "object_id": r.object_id,
                "outcome": r.outcome,
                "detail": r.detail,
                "prev_hash": r.prev_hash,
            }
            if canonical_hash(body) != r.receipt_hash:
                return False
            prev = r.receipt_hash
        return True

    def reconstruct(self, receipts: Optional[List[Receipt]] = None) -> Tuple[bool, int, Set[str]]:
        rs = list(receipts if receipts is not None else self.receipts)
        if not self.verify_receipts(rs):
            return False, 0, set()
        commits = [r for r in rs if r.kind == "EXECUTE" and r.outcome == "COMMIT"]
        actor_ids = {r.actor_id for r in commits}
        return True, len(commits), actor_ids

    def restart_runtime(self) -> "World8GovernedSystem":
        """Reconstruct durable experiment state from receipts and canonical state.

        The reference model persists actor bindings, authorization decisions, fences,
        idempotency and receipts as durable state for the purpose of this experiment.
        """
        new = World8GovernedSystem(self.object_id)
        new.version = self.version
        new.value = self.value
        new.effects = list(self.effects)
        new.actors = dict(self.actors)
        new.sessions = dict(self.sessions)
        new.authorizations = json.loads(json.dumps(self.authorizations))
        new.revoked = set(self.revoked)
        new.current_fence = self.current_fence
        new.valid_fences = set(self.valid_fences)
        new.seen_idempotency = set(self.seen_idempotency)
        new.receipts = list(self.receipts)
        return new


class SessionScopedBaseline:
    """Narrow baseline: session identity + in-memory permissions/shared state.

    It intentionally has some safeguards (role permissions and session-local duplicate
    memory) so the comparison is not simply 'no security versus security'.
    """

    def __init__(self, object_id: str = "object-1") -> None:
        self.object_id = object_id
        self.version = 0
        self.value = 0
        self.effects: List[str] = []
        self.session_roles: Dict[str, str] = {}
        self.permissions: Dict[str, bool] = {"executor": True}
        self.session_seen: Dict[str, Set[str]] = {}
        self.mutable_log: List[dict] = []

    def bind_session(self, session_id: str, role: str) -> None:
        self.session_roles[session_id] = role
        self.session_seen.setdefault(session_id, set())
        self.mutable_log.append({"kind": "BIND", "session": session_id, "role": role})

    def replace_session(self, old_session_id: str, new_session_id: str) -> None:
        role = self.session_roles.get(old_session_id)
        if role is not None:
            self.bind_session(new_session_id, role)

    def revoke_executor(self) -> None:
        self.permissions["executor"] = False
        self.mutable_log.append({"kind": "REVOKE", "role": "executor"})

    def request(self, session_id: str) -> None:
        self.mutable_log.append({"kind": "REQUEST", "session": session_id})

    def approve(self, session_id: str) -> None:
        self.mutable_log.append({"kind": "REVIEW", "session": session_id, "outcome": "APPROVED"})

    def execute(self, session_id: str, idempotency_key: str) -> Tuple[bool, str]:
        role = self.session_roles.get(session_id)
        if role != "executor" or not self.permissions.get("executor", False):
            self.mutable_log.append({"kind": "EXECUTE", "session": session_id, "outcome": "DENY_ROLE"})
            return False, "DENY_ROLE"
        seen = self.session_seen.setdefault(session_id, set())
        if idempotency_key in seen:
            self.mutable_log.append({"kind": "EXECUTE", "session": session_id, "outcome": "DUPLICATE"})
            return False, "DUPLICATE"
        seen.add(idempotency_key)
        self.value += 1
        self.version += 1
        self.effects.append(idempotency_key)
        self.mutable_log.append({"kind": "EXECUTE", "session": session_id, "outcome": "COMMIT", "key": idempotency_key})
        return True, "COMMIT"

    def reconstruct(self) -> Tuple[bool, int, Set[str]]:
        commits = [r for r in self.mutable_log if r.get("kind") == "EXECUTE" and r.get("outcome") == "COMMIT"]
        sessions = {r.get("session", "") for r in commits}
        # Mutable log has no integrity proof; reconstruction is only considered successful
        # if the log remains present and its commit count matches current effects.
        ok = bool(self.mutable_log) and len(commits) == len(self.effects)
        return ok, len(commits), sessions

    def restart_runtime(self) -> "SessionScopedBaseline":
        # Shared object state may survive outside the orchestrator, but ephemeral identity,
        # permission, duplicate-memory and audit log are lost.
        new = SessionScopedBaseline(self.object_id)
        new.version = self.version
        new.value = self.value
        new.effects = list(self.effects)
        return new
