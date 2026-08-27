from pathlib import Path
import sys
import unittest

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from compound_fault_gate_v1 import run_gate


class CompoundFaultGateTests(unittest.TestCase):
    def test_gate_passes(self):
        result = run_gate(trials=25, seed=20260827)
        self.assertEqual(result["gate_state"], "PASS")

    def test_world8_is_safe_in_all_compound_cases(self):
        result = run_gate(trials=10, seed=11)
        for name, rates in result["rates"].items():
            if name.startswith("CF"):
                self.assertEqual(rates["world8_safe"], 1.0)

    def test_valid_paths_have_zero_false_denies(self):
        result = run_gate(trials=10, seed=19)
        for rate in result["world8_false_deny_rate_valid_paths"].values():
            self.assertEqual(rate, 0.0)

    def test_gate_is_reference_only(self):
        result = run_gate(trials=2, seed=5)
        self.assertFalse(result["runtime_db_mutated"])
        self.assertEqual(result["evidence_level"], "REFERENCE_MODEL_COMPOUND_FAULT")


if __name__ == "__main__":
    unittest.main()
