import json
from pathlib import Path
import sys
import unittest

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from model import Receipt, World8GovernedSystem
from run_experiment import _baseline_trial, _world8_trial, run_trials, summarize


class FlagshipGovernanceExperimentTests(unittest.TestCase):
    def test_world8_valid_path_succeeds(self):
        r = _world8_trial("F0", 1)
        self.assertTrue(r.valid_primary_effect_succeeded)
        self.assertEqual(r.effect_count, 1)
        self.assertTrue(r.reconstruction_success)
        self.assertTrue(r.evidence_complete)
        self.assertFalse(r.unauthorized_effect)

    def test_session_swap_preserves_world8_actor_continuity(self):
        w = _world8_trial("F1", 2)
        b = _baseline_trial("F1", 2)
        self.assertTrue(w.valid_primary_effect_succeeded)
        self.assertTrue(w.actor_attribution_continuity)
        self.assertTrue(b.valid_primary_effect_succeeded)
        self.assertFalse(b.actor_attribution_continuity)

    def test_impersonation_is_blocked_by_actor_bound_authorization(self):
        w = _world8_trial("F2", 3)
        b = _baseline_trial("F2", 3)
        self.assertEqual(w.effect_count, 0)
        self.assertTrue(w.invalid_attempt_blocked)
        self.assertFalse(w.unauthorized_effect)
        self.assertGreaterEqual(b.effect_count, 1)
        self.assertTrue(b.unauthorized_effect)

    def test_revocation_is_checked_at_effect_time(self):
        w = _world8_trial("F3", 4)
        b = _baseline_trial("F3", 4)
        self.assertEqual(w.effect_count, 0)
        self.assertTrue(w.invalid_attempt_blocked)
        # Baseline has a current role-permission revoke safeguard too.
        self.assertEqual(b.effect_count, 0)
        self.assertTrue(b.invalid_attempt_blocked)

    def test_stale_write_and_fence_fail_closed(self):
        stale_w = _world8_trial("F4", 5)
        stale_b = _baseline_trial("F4", 5)
        fence_w = _world8_trial("F7", 6)
        fence_b = _baseline_trial("F7", 6)
        self.assertFalse(stale_w.stale_write_accepted)
        self.assertTrue(stale_w.invalid_attempt_blocked)
        self.assertTrue(stale_b.stale_write_accepted)
        self.assertTrue(fence_w.invalid_attempt_blocked)
        self.assertEqual(fence_w.effect_count, 0)
        self.assertTrue(fence_b.unauthorized_effect)

    def test_duplicate_survives_session_change_only_in_governed_path(self):
        w = _world8_trial("F5", 7)
        b = _baseline_trial("F5", 7)
        self.assertEqual(w.effect_count, 1)
        self.assertFalse(w.duplicate_effect)
        self.assertTrue(w.invalid_attempt_blocked)
        self.assertEqual(b.effect_count, 2)
        self.assertTrue(b.duplicate_effect)
        self.assertFalse(b.invalid_attempt_blocked)

    def test_missing_authorization_evidence_fails_closed(self):
        w = _world8_trial("F6", 8)
        b = _baseline_trial("F6", 8)
        self.assertEqual(w.effect_count, 0)
        self.assertTrue(w.invalid_attempt_blocked)
        self.assertTrue(b.unauthorized_effect)

    def test_concurrent_single_winner_semantics(self):
        w = _world8_trial("F8", 9)
        b = _baseline_trial("F8", 9)
        self.assertEqual(w.effect_count, 1)
        self.assertTrue(w.invalid_attempt_blocked)
        self.assertEqual(b.effect_count, 2)
        self.assertTrue(b.duplicate_effect)

    def test_tamper_is_detected_by_hash_chain(self):
        w = _world8_trial("F9", 10)
        b = _baseline_trial("F9", 10)
        self.assertTrue(w.reconstruction_success)
        self.assertFalse(b.reconstruction_success)

    def test_restart_reconstruction(self):
        w = _world8_trial("F10", 11)
        b = _baseline_trial("F10", 11)
        self.assertTrue(w.reconstruction_success)
        self.assertTrue(w.evidence_complete)
        self.assertFalse(b.reconstruction_success)
        self.assertFalse(b.evidence_complete)

    def test_receipt_hash_chain_rejects_modified_payload(self):
        s = World8GovernedSystem("obj")
        s.bind_actor("a", "executor", "s")
        original = list(s.receipts)
        self.assertTrue(World8GovernedSystem.verify_receipts(original))
        r = original[0]
        tampered = [Receipt(
            seq=r.seq,
            kind=r.kind,
            actor_id="different",
            session_id=r.session_id,
            object_id=r.object_id,
            outcome=r.outcome,
            detail=r.detail,
            prev_hash=r.prev_hash,
            receipt_hash=r.receipt_hash,
        )]
        self.assertFalse(World8GovernedSystem.verify_receipts(tampered))

    def test_seeded_run_is_deterministic(self):
        a = summarize(run_trials(5, 12345))
        b = summarize(run_trials(5, 12345))
        self.assertEqual(json.dumps(a, sort_keys=True), json.dumps(b, sort_keys=True))


if __name__ == "__main__":
    unittest.main()
