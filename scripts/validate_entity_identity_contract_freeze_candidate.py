from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
import sys


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_CANDIDATE = ROOT / "architecture" / "proposals" / "world8-entity-identity-contract-freeze-candidate-v0.1.yaml"
DEFAULT_INVENTORY = ROOT / "architecture" / "proposals" / "WORLD8_ENTITY_IDENTITY_IMPLEMENTATION_INVENTORY_v0.1.md"


@dataclass(frozen=True)
class ValidationResult:
    ok: bool
    errors: tuple[str, ...]


REQUIRED_EXACT_LINES = (
    "schema: WORLD8_ENTITY_IDENTITY_CONTRACT_FREEZE_CANDIDATE/0.1",
    "status: CANDIDATE_NOT_FROZEN",
    "canonical: false",
    "production: false",
    "pre_schema: true",
    "canonical_entity_registry_observed: false",
    "canonical_entity_lifecycle_function_observed: false",
    "actor_registry_disposition: DO_NOT_ALIAS_AS_ENTITY",
    "owner_identity_disposition: DO_NOT_ALIAS_AS_ENTITY",
    "access_identity_binding_disposition: DO_NOT_ALIAS_AS_ENTITY",
    "legacy_world9_principal_contract_disposition: NOT_R0_1_ENTITY_BACKING",
    "target_plane: CANONICAL_SPINE",
    "target_logical_object: World8EntityRecord",
    "target_runtime_surface: UNIMPLEMENTED_PRE_SCHEMA",
    "dedicated_canonical_aggregate_required: true",
    "principal_contract_is_separate_aggregate: true",
    "principal_identity_must_reference_existing_entity: true",
    "actor_identity_must_not_substitute_entity: true",
    "auth_identity_must_not_substitute_entity: true",
    "provider_model_session_must_not_define_entity_identity: true",
    "stable_key: entity_id",
    "version_payload_immutable_after_admission: true",
    "identity_reuse_for_different_genesis: forbidden",
    "logical_role: CanonicalSpineEntityWriter",
    "implementation_binding: UNBOUND_PRE_SCHEMA",
    "requires_promotion_authority: true",
    "proposer_can_write: false",
    "evaluator_can_write: false",
    "actor_can_self_write: false",
    "principal_can_self_write: false",
    "model_or_provider_can_write: false",
    "principal_is_governed_entity_specialization: true",
    "principal_activation_fails_if_entity_missing: true",
    "principal_activation_fails_if_entity_not_active: true",
    "principal_activation_fails_if_entity_digest_mismatch: true",
    "principal_row_does_not_create_entity_implicitly: true",
    "actor_registry_authoritative_for_entity_identity: false",
    "owner_identity_table_authoritative_for_entity_identity: false",
    "access_identity_binding_authoritative_for_entity_identity: false",
    "sixth_plane: false",
    "expected_head_or_cas_required: true",
    "fencing_required: true",
    "duplicate_entity_id_distinct_genesis: fail",
    "status: READY_FOR_INDEPENDENT_REVIEW_NOT_FROZEN",
    "runtime_absence_is_explicit: true",
    "runtime_absence_does_not_authorize_schema_before_freeze: true",
    "schema_authoring_allowed_now: false",
    "migration_authoring_allowed_now: false",
    "canonical_writer_implementation_allowed_now: false",
)

REQUIRED_FIELDS = (
    "entity_id",
    "world_id",
    "entity_class",
    "identity_version",
    "lifecycle_state",
    "genesis_ref",
    "constitutional_root_ref",
    "content_digest",
    "created_by_governance_actor_ref",
    "created_at",
)

REQUIRED_FORBIDDEN = (
    "ACTOR_ID_ALIAS_TO_ENTITY_ID",
    "AUTH_USER_ID_ALIAS_TO_ENTITY_ID",
    "PRINCIPAL_ID_WITHOUT_ENTITY_RECORD",
    "PROVIDER_MODEL_SESSION_TO_ENTITY_ID",
    "MUTATE_ADMITTED_ENTITY_ID",
    "REUSE_ENTITY_ID_FOR_DIFFERENT_GENESIS",
    "DEVELOPMENT_ROW_TO_CANONICAL_ENTITY_WITHOUT_GOVERNANCE",
    "SELF_PROMOTION_OF_ENTITY_IDENTITY",
    "TOMBSTONED_TO_ACTIVE_RESURRECTION",
    "DELETE_ENTITY_LINEAGE_OR_TOMBSTONE_HISTORY",
    "RECOVER_ENTITY_FROM_NONCANONICAL_PROJECTION_ONLY",
)

REQUIRED_FREEZE_EXIT = (
    "ENTITY_OWNERSHIP_EXPLICIT",
    "ENTITY_STABLE_KEY_EXPLICIT",
    "AUTHORITATIVE_WRITER_EXPLICIT",
    "LIFECYCLE_EXPLICIT",
    "FORBIDDEN_TRANSITIONS_EXPLICIT",
    "PRINCIPAL_ENTITY_BINDING_EXPLICIT",
    "EVIDENCE_REQUIREMENT_EXPLICIT",
    "RECOVERY_BEHAVIOR_EXPLICIT",
    "WORLD8_PLANE_MAPPING_EXPLICIT",
    "ACTOR_ENTITY_SEPARATION_EXPLICIT",
    "IMPLEMENTATION_INVENTORY_COMPLETE",
    "INDEPENDENT_REVIEW_REQUIRED",
)

FORBIDDEN_IMPLEMENTATION_MARKERS = (
    "CREATE TABLE",
    "ALTER TABLE",
    "CREATE FUNCTION",
    "CREATE OR REPLACE FUNCTION",
    "CREATE POLICY",
    "supabase/migrations/",
)

INVENTORY_REQUIRED_PHRASES = (
    "none identified",
    "DO NOT ALIAS AS ENTITY",
    "world8_actor_registry",
    "world8_owner_identities",
    "world8_access_identity_bindings",
    "world9_principal_contract_versions",
    "no `entity_id` column",
    "dedicated canonical World 8 Entity aggregate",
    "does **not** authorize creating a table immediately",
)


def _lines(text: str) -> set[str]:
    return {line.strip() for line in text.splitlines() if line.strip()}


def validate_text(candidate: str, inventory: str) -> ValidationResult:
    errors: list[str] = []
    lines = _lines(candidate)

    for line in REQUIRED_EXACT_LINES:
        if line not in lines:
            errors.append(f"MISSING_EXACT_LINE:{line}")

    for field in REQUIRED_FIELDS:
        if f"- {field}" not in lines:
            errors.append(f"MISSING_ENTITY_FIELD:{field}")

    for transition in REQUIRED_FORBIDDEN:
        if f"- {transition}" not in lines:
            errors.append(f"MISSING_FORBIDDEN_TRANSITION:{transition}")

    for item in REQUIRED_FREEZE_EXIT:
        if f"- {item}" not in lines:
            errors.append(f"MISSING_FREEZE_EXIT_CRITERION:{item}")

    for marker in FORBIDDEN_IMPLEMENTATION_MARKERS:
        if marker.lower() in candidate.lower():
            errors.append(f"SCHEMA_IMPLEMENTATION_SMUGGLED_IN:{marker}")

    for phrase in INVENTORY_REQUIRED_PHRASES:
        if phrase.lower() not in inventory.lower():
            errors.append(f"INVENTORY_EVIDENCE_MISSING:{phrase}")

    if "- ACTIVE" not in lines or "- RETIRED" not in lines or "- TOMBSTONED" not in lines:
        errors.append("ENTITY_LIFECYCLE_STATES_INCOMPLETE")

    if "- entity_identity_version_or_digest" not in lines:
        errors.append("PRINCIPAL_ENTITY_VERSION_OR_DIGEST_BINDING_MISSING")

    if "requester_only_evidence_for_high_risk_identity_change: forbidden" not in lines:
        errors.append("HIGH_RISK_IDENTITY_EVIDENCE_INDEPENDENCE_MISSING")

    return ValidationResult(not errors, tuple(sorted(set(errors))))


def validate_file(candidate_path: Path = DEFAULT_CANDIDATE, inventory_path: Path = DEFAULT_INVENTORY) -> ValidationResult:
    if not candidate_path.exists():
        return ValidationResult(False, (f"CANDIDATE_FILE_MISSING:{candidate_path}",))
    if not inventory_path.exists():
        return ValidationResult(False, (f"INVENTORY_FILE_MISSING:{inventory_path}",))
    return validate_text(candidate_path.read_text(encoding="utf-8"), inventory_path.read_text(encoding="utf-8"))


def main(argv: list[str] | None = None) -> int:
    args = list(sys.argv[1:] if argv is None else argv)
    candidate = Path(args[0]) if args else DEFAULT_CANDIDATE
    inventory = Path(args[1]) if len(args) > 1 else DEFAULT_INVENTORY
    result = validate_file(candidate, inventory)
    if result.ok:
        print("WORLD8_ENTITY_IDENTITY_CONTRACT_FREEZE_CANDIDATE_VALIDATION: PASS")
        return 0
    print("WORLD8_ENTITY_IDENTITY_CONTRACT_FREEZE_CANDIDATE_VALIDATION: FAIL")
    for error in result.errors:
        print(error)
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
