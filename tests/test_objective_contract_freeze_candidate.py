import unittest
from pathlib import Path

from scripts.validate_objective_contract_freeze_candidate import (
    DEFAULT_CANDIDATE,
    validate_file,
    validate_text,
)


class ObjectiveContractFreezeCandidateTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.text = DEFAULT_CANDIDATE.read_text(encoding="utf-8")

    def test_candidate_passes_validator(self):
        result = validate_file()
        self.assertTrue(result.ok, result.errors)

    def test_candidate_is_explicitly_not_frozen_or_canonical(self):
        self.assertIn("status: CANDIDATE_NOT_FROZEN", self.text)
        self.assertIn("canonical: false", self.text)
        self.assertIn("pre_schema: true", self.text)

    def test_development_surface_cannot_become_canonical_by_status(self):
        mutant = self.text.replace(
            "development_active_is_canonical_active: false",
            "development_active_is_canonical_active: true",
            1,
        )
        result = validate_text(mutant)
        self.assertFalse(result.ok)
        self.assertTrue(any("development_active_is_canonical_active: false" in e for e in result.errors))

    def test_authoritative_writer_must_remain_pre_schema_unbound(self):
        mutant = self.text.replace("implementation_binding: UNBOUND_PRE_SCHEMA", "implementation_binding: rpc.fake_writer", 1)
        result = validate_text(mutant)
        self.assertFalse(result.ok)

    def test_schema_authoring_must_remain_forbidden(self):
        mutant = self.text.replace("schema_authoring_allowed_now: false", "schema_authoring_allowed_now: true", 1)
        result = validate_text(mutant)
        self.assertFalse(result.ok)

    def test_sql_ddl_is_rejected(self):
        result = validate_text(self.text + "\nCREATE TABLE objective_contract_versions(id text);\n")
        self.assertFalse(result.ok)
        self.assertTrue(any(e.startswith("SCHEMA_IMPLEMENTATION_SMUGGLED_IN") for e in result.errors))

    def test_hard_constraints_are_required(self):
        mutant = self.text.replace("  - hard_constraints\n", "", 1)
        result = validate_text(mutant)
        self.assertFalse(result.ok)
        self.assertIn("MISSING_LOGICAL_FIELD:hard_constraints", result.errors)

    def test_authority_ceiling_is_required(self):
        mutant = self.text.replace("  - authority_ceiling_ref\n", "", 1)
        result = validate_text(mutant)
        self.assertFalse(result.ok)
        self.assertIn("MISSING_LOGICAL_FIELD:authority_ceiling_ref", result.errors)

    def test_protected_metric_contract_refs_are_required(self):
        mutant = self.text.replace("  - protected_metric_contract_refs\n", "", 1)
        result = validate_text(mutant)
        self.assertFalse(result.ok)
        self.assertIn("MISSING_LOGICAL_FIELD:protected_metric_contract_refs", result.errors)

    def test_structural_fail_to_activation_is_forbidden(self):
        mutant = self.text.replace("  - STRUCTURAL_FAIL_TO_CHILD_ACTIVATION\n", "", 1)
        result = validate_text(mutant)
        self.assertFalse(result.ok)
        self.assertIn("MISSING_FORBIDDEN_TRANSITION:STRUCTURAL_FAIL_TO_CHILD_ACTIVATION", result.errors)

    def test_stale_cas_write_is_forbidden(self):
        mutant = self.text.replace("  - STALE_CAS_OR_FENCING_TO_CANONICAL_WRITE\n", "", 1)
        result = validate_text(mutant)
        self.assertFalse(result.ok)
        self.assertIn("MISSING_FORBIDDEN_TRANSITION:STALE_CAS_OR_FENCING_TO_CANONICAL_WRITE", result.errors)

    def test_all_five_world8_planes_are_explicit(self):
        for token in (
            "CANONICAL_SPINE:",
            "OPERATIONAL:",
            "OBSERVATION:",
            "DEVELOPMENT_MASON:",
            "EVIDENCE_GOVERNANCE:",
            "sixth_plane: false",
        ):
            with self.subTest(token=token):
                self.assertIn(token, self.text)

    def test_recovery_and_replay_enforcement_is_required(self):
        mutant = self.text.replace("  - RECOVERY_AND_REPLAY\n", "", 1)
        result = validate_text(mutant)
        self.assertFalse(result.ok)
        self.assertIn("MISSING_ENFORCEMENT_POINT:RECOVERY_AND_REPLAY", result.errors)

    def test_high_risk_evidence_cannot_be_requester_only(self):
        mutant = self.text.replace(
            "requester_only_evidence_for_high_risk: forbidden",
            "requester_only_evidence_for_high_risk: allowed",
            1,
        )
        result = validate_text(mutant)
        self.assertFalse(result.ok)
        self.assertIn("HIGH_RISK_EVIDENCE_INDEPENDENCE_MISSING", result.errors)


if __name__ == "__main__":
    unittest.main()
