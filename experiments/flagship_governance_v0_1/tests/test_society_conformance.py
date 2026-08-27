from pathlib import Path
import sys
import unittest

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from society_conformance import COMPANY, TRADING, INVARIANTS, run_conformance, run_matrix


class TwoSocietyConformanceTests(unittest.TestCase):
    def test_company_and_trading_pass_same_invariants(self):
        c = run_conformance(COMPANY, 1)
        t = run_conformance(TRADING, 1)
        self.assertEqual(set(c), set(INVARIANTS))
        self.assertEqual(set(t), set(INVARIANTS))
        self.assertTrue(all(c.values()))
        self.assertTrue(all(t.values()))

    def test_conformance_vectors_match(self):
        result = run_matrix(10, 20260827)
        self.assertTrue(result["conformance_vectors_equal"])
        self.assertTrue(result["all_company_pass"])
        self.assertTrue(result["all_trading_pass"])

    def test_market_performance_is_not_part_of_flagship_conformance(self):
        result = run_matrix(2, 9)
        self.assertFalse(result["market_performance_evaluated"])
        self.assertFalse(result["live_effects"])

    def test_proposal_never_grants_authority_in_either_society(self):
        for spec in (COMPANY, TRADING):
            self.assertTrue(run_conformance(spec, 7)["proposal_not_authority"])

    def test_restart_and_tamper_invariants_in_both_societies(self):
        for spec in (COMPANY, TRADING):
            r = run_conformance(spec, 11)
            self.assertTrue(r["restart_reconstructs"])
            self.assertTrue(r["tamper_detected"])


if __name__ == "__main__":
    unittest.main()
