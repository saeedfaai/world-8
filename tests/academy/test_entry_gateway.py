import unittest
from services.academy.entry_gateway import *


def ctx(**overrides):
    values = dict(actor_id="a", execution_id="e1", work_id="w", workspace_id="ws", dev_session_id="s", preflight_receipt_id="pf", qualification_id="q", canonical_head="c"*40, preflight_hash="p"*64, academy_shadow_hash="h"*64, guardian_companion_id="g", checkpoint_id="cp", role_ref="MASTER_MASON")
    values.update(overrides)
    return EntryContext(**values)


class EntryTests(unittest.TestCase):
    def test_entry_pass_has_no_authority(self):
        self.assertEqual(issue_entry(ctx()).authority_effect, "NONE")

    def test_fresh_execution_is_mandatory(self):
        with self.assertRaisesRegex(EntryGateError, "ACTIVE_EXECUTION_REQUIRED"): issue_entry(ctx(execution_active=False))

    def test_context_loads_are_mandatory(self):
        for field, code in [("architecture_loaded","ARCHITECTURE_CONTEXT_REQUIRED"),("inbox_loaded","INBOX_CONTEXT_REQUIRED"),("attention_loaded","ATTENTION_CONTEXT_REQUIRED"),("access_loaded","ACCESS_CONTEXT_REQUIRED"),("continuity_loaded","CONTINUITY_CONTEXT_REQUIRED"),("diagnostics_loaded","DIAGNOSTIC_CONTEXT_REQUIRED")]:
            with self.subTest(field=field):
                with self.assertRaisesRegex(EntryGateError, code): issue_entry(ctx(**{field:False}))

    def test_same_semantic_retry_is_idempotent(self):
        first=issue_entry(ctx()); self.assertEqual(first, issue_entry(ctx(), existing=first))

    def test_same_execution_semantic_drift_collides(self):
        first=issue_entry(ctx())
        with self.assertRaisesRegex(EntryGateError,"ACADEMY_ENTRY_IDEMPOTENCY_COLLISION"): issue_entry(ctx(checkpoint_id="cp-new"), existing=first)

    def test_new_execution_gets_new_entry(self):
        first=issue_entry(ctx()); second=issue_entry(ctx(execution_id="e2"), existing=first); self.assertNotEqual(first.entry_receipt_id,second.entry_receipt_id)

    def test_code_recovery_minimum(self):
        first=issue_entry(ctx()); r=RecoveryContext(first.entry_receipt_id,"a","e1","w","ws","c"*40,"cp","CODE_ONLY"); self.assertTrue(recovery_receipt_id(r).startswith("recovery-"))

    def test_db_recovery_requires_runtime_snapshot(self):
        r=RecoveryContext(issue_entry(ctx()).entry_receipt_id,"a","e1","w","ws","c"*40,"cp","DB_TOUCHING",restore_strategy_ref="playbook:x")
        with self.assertRaisesRegex(EntryGateError,"DB_RUNTIME_SNAPSHOT_REQUIRED"): r.validate()

    def test_db_recovery_requires_restore_strategy(self):
        r=RecoveryContext(issue_entry(ctx()).entry_receipt_id,"a","e1","w","ws","c"*40,"cp","DB_TOUCHING",runtime_snapshot_id="runtime-db-x")
        with self.assertRaisesRegex(EntryGateError,"DB_RESTORE_STRATEGY_REQUIRED"): r.validate()

    def test_admission_requires_current_exact_entry(self):
        e=issue_entry(ctx()); admission_v3_gate(actor_id="a",execution_id="e1",work_id="w",workspace_id="ws",entry=e,entry_current=True)
        with self.assertRaisesRegex(EntryGateError,"ACADEMY_ENTRY_BINDING_MISMATCH"): admission_v3_gate(actor_id="a",execution_id="e2",work_id="w",workspace_id="ws",entry=e,entry_current=True)

    def test_lease_requires_recovery(self):
        e=issue_entry(ctx()); r=RecoveryContext(e.entry_receipt_id,"a","e1","w","ws","c"*40,"cp","CODE_ONLY")
        with self.assertRaisesRegex(EntryGateError,"CURRENT_PREWRITE_RECOVERY_REQUIRED"): lease_v5_gate(actor_id="a",execution_id="e1",work_id="w",workspace_id="ws",entry=e,recovery=r,entry_current=True,recovery_current=False,required_recovery_class="CODE_ONLY")

    def test_db_lease_rejects_code_only_recovery(self):
        e=issue_entry(ctx()); r=RecoveryContext(e.entry_receipt_id,"a","e1","w","ws","c"*40,"cp","CODE_ONLY")
        with self.assertRaisesRegex(EntryGateError,"DB_TOUCHING_RECOVERY_REQUIRED"): lease_v5_gate(actor_id="a",execution_id="e1",work_id="w",workspace_id="ws",entry=e,recovery=r,entry_current=True,recovery_current=True,required_recovery_class="DB_TOUCHING")

    def test_forged_entry_authority_effect_is_rejected(self):
        good=issue_entry(ctx()); forged=CodingEntryReceipt(good.entry_receipt_id,good.semantic_hash,good.execution_id,good.work_id,good.workspace_id,authority_effect="ALLOW")
        with self.assertRaisesRegex(EntryGateError,"ACADEMY_ENTRY_AUTHORITY_EFFECT_FORBIDDEN"): admission_v3_gate(actor_id="a",execution_id="e1",work_id="w",workspace_id="ws",entry=forged,entry_current=True)

    def test_recovery_from_other_execution_is_rejected(self):
        e=issue_entry(ctx()); r=RecoveryContext(e.entry_receipt_id,"a","other-execution","w","ws","c"*40,"cp","CODE_ONLY")
        with self.assertRaisesRegex(EntryGateError,"RECOVERY_BINDING_MISMATCH"): lease_v5_gate(actor_id="a",execution_id="e1",work_id="w",workspace_id="ws",entry=e,recovery=r,entry_current=True,recovery_current=True,required_recovery_class="CODE_ONLY")


if __name__ == "__main__": unittest.main()
