from pathlib import Path
import asyncio
import sys
import unittest

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from external_autogen_baseline import run_case


class AutoGenExternalBaselineTests(unittest.TestCase):
    def test_generic_hardening_handles_generic_controls(self):
        async def go():
            for scenario in ("V1_NORMAL", "V2_RUNTIME_SWAP_SAME_ACTOR", "V3_RESTART_RECOVER", "X2_REVOKED_BEFORE_EFFECT", "X3_STALE_VERSION", "X4_DUPLICATE_RETRY"):
                r = await run_case("hardened", scenario, 101)
                self.assertTrue(r.safe, scenario)
        asyncio.run(go())

    def test_hardened_baseline_exposes_governance_specific_faults(self):
        async def go():
            for scenario in ("X1_STOLEN_APPROVAL_AFTER_SWAP", "X5_STALE_FENCE_AFTER_ROTATION", "X6_EVIDENCE_TAMPER", "X7_EFFECT_BEFORE_RECOVERY"):
                r = await run_case("hardened", scenario, 202)
                self.assertFalse(r.safe, scenario)
        asyncio.run(go())

    def test_full_governance_variant_closes_all_frozen_faults(self):
        async def go():
            for scenario in (
                "V1_NORMAL", "V2_RUNTIME_SWAP_SAME_ACTOR", "V3_RESTART_RECOVER",
                "X1_STOLEN_APPROVAL_AFTER_SWAP", "X2_REVOKED_BEFORE_EFFECT",
                "X3_STALE_VERSION", "X4_DUPLICATE_RETRY",
                "X5_STALE_FENCE_AFTER_ROTATION", "X6_EVIDENCE_TAMPER",
                "X7_EFFECT_BEFORE_RECOVERY",
            ):
                r = await run_case("full_governance", scenario, 303)
                self.assertTrue(r.safe, scenario)
                if scenario.startswith("V"):
                    self.assertFalse(r.false_deny, scenario)
        asyncio.run(go())

    def test_persistent_actor_continuity_is_not_auto_claimed_for_hardened_runtime_id(self):
        async def go():
            h = await run_case("hardened", "V2_RUNTIME_SWAP_SAME_ACTOR", 404)
            g = await run_case("full_governance", "V2_RUNTIME_SWAP_SAME_ACTOR", 404)
            self.assertFalse(h.actor_continuity)
            self.assertTrue(g.actor_continuity)
        asyncio.run(go())


if __name__ == "__main__":
    unittest.main()
