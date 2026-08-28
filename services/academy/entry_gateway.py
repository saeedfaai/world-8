from __future__ import annotations

from dataclasses import dataclass, field
from hashlib import sha256
import json
from typing import Tuple


class EntryGateError(ValueError):
    pass


def _hash(payload: dict) -> str:
    return sha256(json.dumps(payload, sort_keys=True, separators=(",", ":")).encode()).hexdigest()


@dataclass(frozen=True)
class EntryContext:
    actor_id: str
    execution_id: str
    work_id: str
    workspace_id: str
    dev_session_id: str
    preflight_receipt_id: str
    qualification_id: str
    canonical_head: str
    preflight_hash: str
    academy_shadow_hash: str
    guardian_companion_id: str
    checkpoint_id: str
    role_ref: str
    architecture_loaded: bool = True
    inbox_loaded: bool = True
    attention_loaded: bool = True
    access_loaded: bool = True
    continuity_loaded: bool = True
    diagnostics_loaded: bool = True
    guardian_attached: bool = True
    qualification_current: bool = True
    preflight_pass: bool = True
    workspace_fresh: bool = True
    session_active: bool = True
    execution_active: bool = True

    def blockers(self) -> Tuple[str, ...]:
        checks = {
            "ACTIVE_EXECUTION_REQUIRED": self.execution_active,
            "ACTIVE_DEV_SESSION_REQUIRED": self.session_active,
            "PREFLIGHT_PASS_REQUIRED": self.preflight_pass,
            "CURRENT_QUALIFICATION_REQUIRED": self.qualification_current,
            "FRESH_WORKSPACE_REQUIRED": self.workspace_fresh,
            "GUARDIAN_ATTACHED_REQUIRED": self.guardian_attached,
            "ARCHITECTURE_CONTEXT_REQUIRED": self.architecture_loaded,
            "INBOX_CONTEXT_REQUIRED": self.inbox_loaded,
            "ATTENTION_CONTEXT_REQUIRED": self.attention_loaded,
            "ACCESS_CONTEXT_REQUIRED": self.access_loaded,
            "CONTINUITY_CONTEXT_REQUIRED": self.continuity_loaded,
            "DIAGNOSTIC_CONTEXT_REQUIRED": self.diagnostics_loaded,
        }
        return tuple(k for k, ok in checks.items() if not ok)

    def semantic_payload(self) -> dict:
        return {
            "schema": "WORLD8_ACADEMY_CODING_ENTRY/0.4",
            "actor_id": self.actor_id,
            "execution_id": self.execution_id,
            "work_id": self.work_id,
            "workspace_id": self.workspace_id,
            "dev_session_id": self.dev_session_id,
            "preflight_receipt_id": self.preflight_receipt_id,
            "qualification_id": self.qualification_id,
            "canonical_head": self.canonical_head,
            "preflight_hash": self.preflight_hash,
            "academy_shadow_hash": self.academy_shadow_hash,
            "guardian_companion_id": self.guardian_companion_id,
            "checkpoint_id": self.checkpoint_id,
            "role_ref": self.role_ref,
            "authority_effect": "NONE",
        }


@dataclass(frozen=True)
class CodingEntryReceipt:
    entry_receipt_id: str
    semantic_hash: str
    execution_id: str
    work_id: str
    workspace_id: str
    authority_effect: str = "NONE"


def issue_entry(ctx: EntryContext, existing: CodingEntryReceipt | None = None) -> CodingEntryReceipt:
    blockers = ctx.blockers()
    if blockers:
        raise EntryGateError("ACADEMY_ENTRY_BLOCKED:" + ",".join(blockers))
    semantic_hash = _hash(ctx.semantic_payload())
    entry_id = "academy-entry-" + semantic_hash[:32]
    if existing is not None:
        same_identity = (existing.execution_id, existing.work_id, existing.workspace_id) == (ctx.execution_id, ctx.work_id, ctx.workspace_id)
        if same_identity and existing.semantic_hash == semantic_hash:
            return existing
        if same_identity:
            raise EntryGateError("ACADEMY_ENTRY_IDEMPOTENCY_COLLISION")
    return CodingEntryReceipt(entry_id, semantic_hash, ctx.execution_id, ctx.work_id, ctx.workspace_id)


@dataclass(frozen=True)
class RecoveryContext:
    entry_receipt_id: str
    actor_id: str
    execution_id: str
    work_id: str
    workspace_id: str
    canonical_head: str
    checkpoint_id: str
    recovery_class: str
    runtime_snapshot_id: str | None = None
    restore_strategy_ref: str | None = None
    evidence_refs: Tuple[str, ...] = field(default_factory=tuple)

    def validate(self) -> None:
        if self.recovery_class not in {"CODE_ONLY", "DB_TOUCHING"}:
            raise EntryGateError("RECOVERY_CLASS_INVALID")
        if not self.canonical_head or not self.checkpoint_id:
            raise EntryGateError("RECOVERY_BASELINE_REQUIRED")
        if self.recovery_class == "DB_TOUCHING":
            if not self.runtime_snapshot_id:
                raise EntryGateError("DB_RUNTIME_SNAPSHOT_REQUIRED")
            if not self.restore_strategy_ref:
                raise EntryGateError("DB_RESTORE_STRATEGY_REQUIRED")

    def semantic_payload(self) -> dict:
        self.validate()
        return {"schema":"WORLD8_PREWRITE_RECOVERY/0.4","entry_receipt_id":self.entry_receipt_id,"actor_id":self.actor_id,"execution_id":self.execution_id,"work_id":self.work_id,"workspace_id":self.workspace_id,"canonical_head":self.canonical_head,"checkpoint_id":self.checkpoint_id,"recovery_class":self.recovery_class,"runtime_snapshot_id":self.runtime_snapshot_id,"restore_strategy_ref":self.restore_strategy_ref,"evidence_refs":sorted(self.evidence_refs),"authority_effect":"NONE"}


def recovery_receipt_id(ctx: RecoveryContext) -> str:
    return "recovery-" + _hash(ctx.semantic_payload())[:32]


def admission_v3_gate(*, actor_id: str, execution_id: str, work_id: str, workspace_id: str, entry: CodingEntryReceipt, entry_current: bool) -> None:
    if not entry_current:
        raise EntryGateError("CURRENT_ACADEMY_ENTRY_REQUIRED")
    if (entry.execution_id, entry.work_id, entry.workspace_id) != (execution_id, work_id, workspace_id):
        raise EntryGateError("ACADEMY_ENTRY_BINDING_MISMATCH")
    if entry.authority_effect != "NONE":
        raise EntryGateError("ACADEMY_ENTRY_AUTHORITY_EFFECT_FORBIDDEN")


def lease_v5_gate(*, actor_id: str, execution_id: str, work_id: str, workspace_id: str, entry: CodingEntryReceipt, recovery: RecoveryContext, entry_current: bool, recovery_current: bool, required_recovery_class: str) -> None:
    admission_v3_gate(actor_id=actor_id, execution_id=execution_id, work_id=work_id, workspace_id=workspace_id, entry=entry, entry_current=entry_current)
    if not recovery_current:
        raise EntryGateError("CURRENT_PREWRITE_RECOVERY_REQUIRED")
    recovery.validate()
    if (recovery.entry_receipt_id, recovery.execution_id, recovery.work_id, recovery.workspace_id) != (entry.entry_receipt_id, execution_id, work_id, workspace_id):
        raise EntryGateError("RECOVERY_BINDING_MISMATCH")
    if required_recovery_class == "DB_TOUCHING" and recovery.recovery_class != "DB_TOUCHING":
        raise EntryGateError("DB_TOUCHING_RECOVERY_REQUIRED")
