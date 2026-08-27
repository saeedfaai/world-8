from pathlib import Path
import sys
import unittest

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from langgraph_baseline_v1 import run_benchmark


class LangGraphBaselineTests(unittest.TestCase):
    def test_durable_restart_and_reject_paths(self):
        result = run_benchmark(3)
        self.assertEqual(result["gate_state"], "PASS")
        self.assertEqual(result["metrics"]["approved_restart_resume_rate"], 1.0)
        self.assertEqual(result["metrics"]["rejected_restart_resume_rate"], 1.0)

    def test_effect_counts_match_bounded_decision(self):
        result = run_benchmark(2)
        self.assertEqual(result["metrics"]["approved_effect_exact_count_rate"], 1.0)
        self.assertEqual(result["metrics"]["rejected_zero_effect_rate"], 1.0)

    def test_checkpoint_history_exists(self):
        result = run_benchmark(2)
        self.assertEqual(result["metrics"]["checkpoint_history_present_rate"], 1.0)

    def test_no_external_llm_or_network_calls(self):
        result = run_benchmark(1)
        self.assertFalse(result["external_network_or_llm_calls"])


if __name__ == "__main__":
    unittest.main()
