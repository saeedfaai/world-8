import unittest

from scripts.validate_entity_identity_contract_freeze_candidate import (
    DEFAULT_CANDIDATE,
    DEFAULT_INVENTORY,
    validate_file,
    validate_text,
)


class EntityIdentityContractFreezeCandidateTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.candidate = DEFAULT_CANDIDATE.read_text(encoding="utf-8")
        cls.inventory = DEFAULT_INVENTORY.read_text(encoding="utf-8")

    def test_candidate_passes_validator(self):
        result = validate_file()
        self.assertTrue(result.ok, result.errors)

    def test_candidate_is_pre_schema_noncanonical(self):
        for line in (
            "status: CANDIDATE_NOT_FROZEN",
            "canonical: false",
            "production: false",
            "pre_schema: true",
        ):
            self.assertIn(line, self.candidate)

    def test_actor_registry_cannot_be_aliased_to_entity(self):
        mutant = self.candidate.replace(
            "actor_registry_disposition: DO_NOT_ALIAS_AS_ENTITY",
            "actor_registry_disposition: CANONICAL_ENTITY_SOURCE",
            1,
        )
        result = validate_text(mutant, self.inventory)
        self.assertFalse(result.ok)

    def test_auth_identity_cannot_substitute_entity(self):
        mutant = self.candidate.replace(
            "auth_identity_must_not_substitute_entity: true",
            "auth_identity_must_not_substitute_entity: false",
            1,
        )
        result = validate_text(mutant, self.inventory)
        self.assertFalse(result.ok)

    def test_provider_model_session_cannot_define_entity_identity(self):
        mutant = self.candidate.replace(
            "provider_model_session_must_not_define_entity_identity: true",
            "provider_model_session_must_not_define_entity_identity: false",
            1,
        )
        result = validate_text(mutant, self.inventory)
        self.assertFalse(result.ok)

    def test_principal_must_reference_existing_entity(self):
        mutant = self.candidate.replace(
            "principal_identity_must_reference_existing_entity: true",
            "principal_identity_must_reference_existing_entity: false",
            1,
        )
        result = validate_text(mutant, self.inventory)
        self.assertFalse(result.ok)

    def test_principal_cannot_create_entity_implicitly(self):
        mutant = self.candidate.replace(
            "principal_row_does_not_create_entity_implicitly: true",
            "principal_row_does_not_create_entity_implicitly: false",
            1,
        )
        result = validate_text(mutant, self.inventory)
        self.assertFalse(result.ok)

    def test_entity_id_is_required(self):
        mutant = self.candidate.replace("    - entity_id\n", "", 1)
        result = validate_text(mutant, self.inventory)
        self.assertFalse(result.ok)
        self.assertIn("MISSING_ENTITY_FIELD:entity_id", result.errors)

    def test_genesis_ref_is_required(self):
        mutant = self.candidate.replace("    - genesis_ref\n", "", 1)
        result = validate_text(mutant, self.inventory)
        self.assertFalse(result.ok)
        self.assertIn("MISSING_ENTITY_FIELD:genesis_ref", result.errors)

    def test_entity_id_reuse_for_different_genesis_is_forbidden(self):
        mutant = self.candidate.replace("  - REUSE_ENTITY_ID_FOR_DIFFERENT_GENESIS\n", "", 1)
        result = validate_text(mutant, self.inventory)
        self.assertFalse(result.ok)
        self.assertIn("MISSING_FORBIDDEN_TRANSITION:REUSE_ENTITY_ID_FOR_DIFFERENT_GENESIS", result.errors)

    def test_tombstone_resurrection_is_forbidden(self):
        mutant = self.candidate.replace("  - TOMBSTONED_TO_ACTIVE_RESURRECTION\n", "", 1)
        result = validate_text(mutant, self.inventory)
        self.assertFalse(result.ok)

    def test_self_promotion_is_forbidden(self):
        mutant = self.candidate.replace("  - SELF_PROMOTION_OF_ENTITY_IDENTITY\n", "", 1)
        result = validate_text(mutant, self.inventory)
        self.assertFalse(result.ok)

    def test_noncanonical_recovery_is_forbidden(self):
        mutant = self.candidate.replace("  - RECOVER_ENTITY_FROM_NONCANONICAL_PROJECTION_ONLY\n", "", 1)
        result = validate_text(mutant, self.inventory)
        self.assertFalse(result.ok)

    def test_actor_registry_is_not_recovery_authority(self):
        mutant = self.candidate.replace(
            "actor_registry_authoritative_for_entity_identity: false",
            "actor_registry_authoritative_for_entity_identity: true",
            1,
        )
        result = validate_text(mutant, self.inventory)
        self.assertFalse(result.ok)

    def test_schema_authoring_stays_forbidden_before_freeze(self):
        mutant = self.candidate.replace(
            "schema_authoring_allowed_now: false",
            "schema_authoring_allowed_now: true",
            1,
        )
        result = validate_text(mutant, self.inventory)
        self.assertFalse(result.ok)

    def test_ddl_is_rejected(self):
        result = validate_text(self.candidate + "\nCREATE TABLE world8_entities(id text);\n", self.inventory)
        self.assertFalse(result.ok)
        self.assertTrue(any(e.startswith("SCHEMA_IMPLEMENTATION_SMUGGLED_IN") for e in result.errors))

    def test_inventory_must_record_no_entity_id_on_existing_principal_contract(self):
        mutant_inventory = self.inventory.replace("no `entity_id` column", "entity id status unknown", 1)
        result = validate_text(self.candidate, mutant_inventory)
        self.assertFalse(result.ok)
        self.assertTrue(any("no `entity_id` column" in e for e in result.errors))

    def test_independent_review_remains_required(self):
        mutant = self.candidate.replace("  - INDEPENDENT_REVIEW_REQUIRED\n", "", 1)
        result = validate_text(mutant, self.inventory)
        self.assertFalse(result.ok)

    def test_high_risk_identity_evidence_independence_is_required(self):
        mutant = self.candidate.replace(
            "requester_only_evidence_for_high_risk_identity_change: forbidden",
            "requester_only_evidence_for_high_risk_identity_change: allowed",
            1,
        )
        result = validate_text(mutant, self.inventory)
        self.assertFalse(result.ok)
        self.assertIn("HIGH_RISK_IDENTITY_EVIDENCE_INDEPENDENCE_MISSING", result.errors)


if __name__ == "__main__":
    unittest.main()
