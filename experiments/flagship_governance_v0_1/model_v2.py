from __future__ import annotations

from dataclasses import dataclass, replace
import json
from typing import Dict, List, Optional, Set, Tuple

from model import Receipt, canonical_hash


@dataclass(frozen=True)
class GovernedFeatures:
    actor_binding: bool = True
    cas: bool = True
    fence: bool = True
    idempotency: bool = True
    tamper_evident_receipts: bool = True


class GovernedVariantSystem:
    """Configurable World 8 mechanism model for component ablation.

    Defaults represent the full governed mechanism set. Disabling exactly one feature
    creates a controlled ablation while keeping the rest of the path unchanged.
    """

    def __init__(self, object_id: str, features: GovernedFeatures = GovernedFeatures()) -> None:
        self.object_id = object_id
        self.features = features
        self.version = 0
        self.value = 0
        self.effects: List[str] = []
        self.actors: Dict[str, str] = {}
        self.sessions: Dict[str, str] = {}
        self.authorizations: Dict[str, dict] = {}
        self.revoked: Set[str] = set()
        self.current_fence = 0
        self.valid_fences: Set[int] = set()
        self.seen_idempotency: Set[str] = set()
        self.receipts: List[Receipt] = []
        self.policy_checks = 0

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

    def approve(self, reviewer_actor: str, reviewer_session: str, executor_actor: str, auth_id: str) -> None:
        self.authorizations[auth_id] = {
            "actor_id": executor_actor,
            "action": "WRITE",
            "object_id": self.object_id,
        }
        self._append("REVIEW", reviewer_actor, reviewer_session, "APPROVED", auth_id)

    def revoke(self, auth_id: str, actor_id: str, session_id: str) -> None:
        self.revoked.add(auth_id)
        self._append("AUTH_REVOKE", actor_id, session_id, "OK", auth_id)

    def issue_fence(self, actor_id: str, session_id: str) -> int:
        self.current_fence += 1
        self.valid_fences = {self.current_fence}
        self._append("LEASE", actor_id, session_id, "ISSUED", str(self.current_fence))
        return self.current_fence

    def execute(self, actor_id: str, session_id: str, auth_id: Optional[str], fence: Optional[int],
                expected_version: int, idempotency_key: str) -> Tuple[bool, str, int]:
        start_checks = self.policy_checks

        if self.features.actor_binding:
            self.policy_checks += 1
            if self.sessions.get(session_id) != actor_id:
                self._append("EXECUTE", actor_id, session_id, "DENY", "IDENTITY_BINDING")
                return False, "IDENTITY_BINDING", self.policy_checks - start_checks

        self.policy_checks += 1
        if not auth_id or auth_id not in self.authorizations:
            self._append("EXECUTE", actor_id, session_id, "DENY", "MISSING_AUTH")
            return False, "MISSING_AUTH", self.policy_checks - start_checks

        self.policy_checks += 1
        if auth_id in self.revoked:
            self._append("EXECUTE", actor_id, session_id, "DENY", "REVOKED")
            return False, "REVOKED", self.policy_checks - start_checks

        auth = self.authorizations[auth_id]
        self.policy_checks += 1
        expected_scope = {"actor_id": actor_id, "action": "WRITE", "object_id": self.object_id}
        if self.features.actor_binding:
            scope_ok = auth == expected_scope
        else:
            scope_ok = auth.get("action") == "WRITE" and auth.get("object_id") == self.object_id
        if not scope_ok:
            self._append("EXECUTE", actor_id, session_id, "DENY", "AUTH_SCOPE")
            return False, "AUTH_SCOPE", self.policy_checks - start_checks

        if self.features.fence:
            self.policy_checks += 1
            if fence is None or fence not in self.valid_fences or fence != self.current_fence:
                self._append("EXECUTE", actor_id, session_id, "DENY", "FENCE")
                return False, "FENCE", self.policy_checks - start_checks

        if self.features.cas:
            self.policy_checks += 1
            if expected_version != self.version:
                self._append("EXECUTE", actor_id, session_id, "DENY", "STALE_VERSION")
                return False, "STALE_VERSION", self.policy_checks - start_checks

        if self.features.idempotency:
            self.policy_checks += 1
            if idempotency_key in self.seen_idempotency:
                self._append("EXECUTE", actor_id, session_id, "DENY", "DUPLICATE")
                return False, "DUPLICATE", self.policy_checks - start_checks

        self.seen_idempotency.add(idempotency_key)
        self.value += 1
        self.version += 1
        self.effects.append(idempotency_key)
        self._append("EXECUTE", actor_id, session_id, "COMMIT", idempotency_key)
        return True, "COMMIT", self.policy_checks - start_checks

    def verify_receipts(self, receipts: List[Receipt]) -> bool:
        if not self.features.tamper_evident_receipts:
            # Ablation intentionally trusts the supplied event sequence without hash proof.
            return all(r.seq == idx for idx, r in enumerate(receipts, start=1))
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
        actors = {r.actor_id for r in commits}
        return True, len(commits), actors

    def restart_runtime(self) -> "GovernedVariantSystem":
        new = GovernedVariantSystem(self.object_id, self.features)
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
        new.policy_checks = self.policy_checks
        return new


class HardenedSessionBaseline:
    """Stronger conventional baseline.

    Mechanisms intentionally present:
    - session role binding;
    - explicit approval token scoped to action/object (not persistent actor);
    - revoke-at-effect-time check;
    - compare-and-set version check;
    - durable idempotency across session replacement;
    - durable mutable audit log.

    Mechanisms intentionally absent:
    - persistent actor identity independent of session/provider;
    - actor-bound authorization;
    - fencing/lease token;
    - tamper-evident append-only receipt proof.
    """

    def __init__(self, object_id: str) -> None:
        self.object_id = object_id
        self.version = 0
        self.value = 0
        self.effects: List[str] = []
        self.session_roles: Dict[str, str] = {}
        self.approvals: Dict[str, dict] = {}
        self.revoked: Set[str] = set()
        self.seen_idempotency: Set[str] = set()
        self.mutable_log: List[dict] = []
        self.policy_checks = 0

    def bind_session(self, session_id: str, role: str) -> None:
        self.session_roles[session_id] = role
        self.mutable_log.append({"kind": "BIND", "session": session_id, "role": role})

    def replace_session(self, old_session_id: str, new_session_id: str) -> None:
        role = self.session_roles.get(old_session_id)
        if role is not None:
            self.bind_session(new_session_id, role)

    def request(self, session_id: str) -> None:
        self.mutable_log.append({"kind": "REQUEST", "session": session_id})

    def approve(self, reviewer_session: str, approval_id: str) -> None:
        self.approvals[approval_id] = {"action": "WRITE", "object_id": self.object_id}
        self.mutable_log.append({"kind": "REVIEW", "session": reviewer_session, "outcome": "APPROVED", "approval": approval_id})

    def revoke(self, approval_id: str) -> None:
        self.revoked.add(approval_id)
        self.mutable_log.append({"kind": "REVOKE", "approval": approval_id})

    def execute(self, session_id: str, approval_id: Optional[str], expected_version: int,
                idempotency_key: str) -> Tuple[bool, str, int]:
        start = self.policy_checks
        self.policy_checks += 1
        if self.session_roles.get(session_id) != "executor":
            self.mutable_log.append({"kind": "EXECUTE", "session": session_id, "outcome": "DENY_ROLE"})
            return False, "DENY_ROLE", self.policy_checks - start

        self.policy_checks += 1
        if not approval_id or approval_id not in self.approvals:
            self.mutable_log.append({"kind": "EXECUTE", "session": session_id, "outcome": "MISSING_APPROVAL"})
            return False, "MISSING_APPROVAL", self.policy_checks - start

        self.policy_checks += 1
        if approval_id in self.revoked:
            self.mutable_log.append({"kind": "EXECUTE", "session": session_id, "outcome": "REVOKED"})
            return False, "REVOKED", self.policy_checks - start

        approval = self.approvals[approval_id]
        self.policy_checks += 1
        if approval != {"action": "WRITE", "object_id": self.object_id}:
            self.mutable_log.append({"kind": "EXECUTE", "session": session_id, "outcome": "APPROVAL_SCOPE"})
            return False, "APPROVAL_SCOPE", self.policy_checks - start

        self.policy_checks += 1
        if expected_version != self.version:
            self.mutable_log.append({"kind": "EXECUTE", "session": session_id, "outcome": "STALE_VERSION"})
            return False, "STALE_VERSION", self.policy_checks - start

        self.policy_checks += 1
        if idempotency_key in self.seen_idempotency:
            self.mutable_log.append({"kind": "EXECUTE", "session": session_id, "outcome": "DUPLICATE"})
            return False, "DUPLICATE", self.policy_checks - start

        self.seen_idempotency.add(idempotency_key)
        self.value += 1
        self.version += 1
        self.effects.append(idempotency_key)
        self.mutable_log.append({"kind": "EXECUTE", "session": session_id, "outcome": "COMMIT", "key": idempotency_key})
        return True, "COMMIT", self.policy_checks - start

    def reconstruct(self) -> Tuple[bool, int, Set[str]]:
        commits = [r for r in self.mutable_log if r.get("kind") == "EXECUTE" and r.get("outcome") == "COMMIT"]
        sessions = {r.get("session", "") for r in commits}
        ok = bool(self.mutable_log) and len(commits) == len(self.effects)
        return ok, len(commits), sessions

    def restart_runtime(self) -> "HardenedSessionBaseline":
        new = HardenedSessionBaseline(self.object_id)
        new.version = self.version
        new.value = self.value
        new.effects = list(self.effects)
        # Durable controls/log survive; runtime session identity does not.
        new.approvals = json.loads(json.dumps(self.approvals))
        new.revoked = set(self.revoked)
        new.seen_idempotency = set(self.seen_idempotency)
        new.mutable_log = json.loads(json.dumps(self.mutable_log))
        new.policy_checks = self.policy_checks
        return new
