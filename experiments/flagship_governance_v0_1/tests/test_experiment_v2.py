from pathlib import Path
import sys
import unittest

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from model_v2 import GovernedFeatures
from run_experiment_v2 import _governed, _hardened


class HardenedBaselineAndAblationTests(unittest.TestCase):
    def test_hardened_baseline_matches_cas_and_idempotency_controls(self):
        for scenario in ("F3", "F4", "F5", "F6", "F8"):
            h = _hardened(scenario, 100 + int(scenario[1]))
            self.assertTrue(h.invalid_attempt_blocked, scenario)

    def test_full_world8_retains_distinct_actor_binding_advantage(self):
        w = _governed("world8_full", GovernedFeatures(), "F2", 201)
        h = _hardened("F2", 201)
        self.assertTrue(w.invalid_attempt_blocked)
        self.assertEqual(w.effect_count, 0)
        self.assertFalse(h.invalid_attempt_blocked)
        self.assertTrue(h.unauthorized_effect)

    def test_full_world8_retains_fence_advantage(self):
        w = _governed("world8_full", GovernedFeatures(), "F7", 202)
        h = _hardened("F7", 202)
        self.assertTrue(w.invalid_attempt_blocked)
        self.assertFalse(h.invalid_attempt_blocked)
        self.assertTrue(h.unauthorized_effect)

    def test_hardened_restart_reconstructs_but_not_actor_identity(self):
        h = _hardened("F10", 203)
        self.assertTrue(h.audit_correct)
        self.assertTrue(h.evidence_complete)
        self.assertFalse(h.actor_continuity)

    def test_hash_chain_isolated_by_ablation(self):
        full = _governed("world8_full", GovernedFeatures(), "F9", 204)
        ablated = _governed(
            "w8_ablate_hash_chain",
            GovernedFeatures(tamper_evident_receipts=False),
            "F9",
            204,
        )
        self.assertTrue(full.audit_correct)
        self.assertFalse(ablated.audit_correct)

    def test_actor_binding_ablation_exposes_impersonation(self):
        r = _governed(
            "w8_ablate_actor_binding",
            GovernedFeatures(actor_binding=False),
            "F2",
            205,
        )
        self.assertFalse(r.invalid_attempt_blocked)
        self.assertTrue(r.unauthorized_effect)

    def test_cas_ablation_exposes_stale_and_race(self):
        features = GovernedFeatures(cas=False)
        stale = _governed("w8_ablate_cas", features, "F4", 206)
        race = _governed("w8_ablate_cas", features, "F8", 207)
        self.assertTrue(stale.stale_write_accepted)
        self.assertTrue(race.duplicate_or_extra_effect)

    def test_fence_ablation_exposes_invalid_lease_attempt(self):
        r = _governed(
            "w8_ablate_fence",
            GovernedFeatures(fence=False),
            "F7",
            208,
        )
        self.assertFalse(r.invalid_attempt_blocked)
        self.assertTrue(r.unauthorized_effect)

    def test_idempotency_ablation_exposes_retry_duplicate(self):
        r = _governed(
            "w8_ablate_idempotency",
            GovernedFeatures(idempotency=False),
            "F5",
            209,
        )
        self.assertTrue(r.duplicate_or_extra_effect)
        self.assertGreater(r.effect_count, 1)

    def test_compound_revoke_race_is_fail_closed_in_full_and_hardened(self):
        full = _governed("world8_full", GovernedFeatures(), "C1_REVOKE_RACE", 210)
        hard = _hardened("C1_REVOKE_RACE", 210)
        self.assertTrue(full.invalid_attempt_blocked)
        self.assertEqual(full.effect_count, 0)
        self.assertTrue(hard.invalid_attempt_blocked)
        self.assertEqual(hard.effect_count, 0)

    def test_compound_restart_tamper_distinguishes_audit_proof(self):
        full = _governed("world8_full", GovernedFeatures(), "C3_RESTART_TAMPER", 211)
        hard = _hardened("C3_RESTART_TAMPER", 211)
        self.assertTrue(full.audit_correct)
        self.assertFalse(hard.audit_correct)


if __name__ == "__main__":
    unittest.main()
