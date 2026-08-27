from pathlib import Path
import sys
import unittest

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from mutation_gate_v1 import run_gate


class MutationGateTests(unittest.TestCase):
    def test_all_five_mutations_are_killed(self):
        result = run_gate(trials=25, seed=20260827)
        self.assertEqual(result["gate_state"], "PASS")
        self.assertEqual(result["killed"], 5)
        self.assertEqual(result["total"], 5)
        self.assertEqual(result["mutation_score"], 1.0)

    def test_full_system_has_zero_target_failure_rate(self):
        result = run_gate(trials=10, seed=7)
        for item in result["mutations"].values():
            self.assertEqual(item["full_system_failure_rate"], 0.0)
            self.assertEqual(item["mutant_failure_rate"], 1.0)

    def test_gate_does_not_claim_runtime_mutation(self):
        result = run_gate(trials=2, seed=1)
        self.assertFalse(result["runtime_db_mutated"])
        self.assertEqual(result["evidence_level"], "REFERENCE_MODEL_MUTATION")


if __name__ == "__main__":
    unittest.main()
