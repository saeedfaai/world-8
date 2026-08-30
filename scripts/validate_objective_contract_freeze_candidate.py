from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
import sys


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_CANDIDATE = ROOT / "architecture" / "proposals" / "world8-objective-contract-freeze-candidate-v0.1.yaml"


@dataclass(frozen=True)
class ValidationResult:
    ok: bool
    errors: tuple[str, ...]


REQUIRED_TOKENS = (
    "schema: WORLD8_OBJECTIVE_CONTRACT_FREEZE_CANDIDATE/0.1",
    "status: CANDIDATE_NOT_FROZEN",
    "canonical: false",
    "production: false",
    "pre_schema: true",
    "object_ownership:",
    "authoritative_writer:",
    "state_machine:",
    "forbidden_transitions:",
    "evidence_requirement:",
    "recovery_behavior:",
    "world8_plane_mapping:",
    "enforcement_points:",
    "concurrency_contract:",
    "implementation_after_freeze:",
    "current_development_table: public.world8_dev_objectives",
    "development_active_is_canonical_active: false",
    "logical_role: CanonicalSpineObjectiveContractWriter",
    "implementation_binding: UNBOUND_PRE_SCHEMA",
    "immutable_after_admission: true",
    "version_payload_mutable: false",
    "semantic_can_override_structural_fail: false",
    "semantic_can_mint_authority: false",
    "schema_authoring_allowed_now: false",
    "migration_authoring_allowed_now: false",
    "canonical_writer_implementation_allowed_now: false",
    "INDEPENDENT_REVIEW_REQUIRED",
)

REQUIRED_LOGICAL_FIELDS = (
    "objective_id",
    "objective_version",
    "entity_id",
    "hard_constraints",
    "authority_ceiling_ref",
    "risk_policy_ref",
    "observation_policy_ref",
    "promotion_policy_ref",
    "protected_metric_contract_refs",
    "evidence_pack_ref",
    "content_digest",
    "promotion_decision_ref",
)

REQUIRED_FORBIDDEN_TRANSITIONS = (
    "DEVELOPMENT_ACTIVE_TO_CANONICAL_ACTIVE_WITHOUT_GOVERNANCE",
    "MUTATE_ADMITTED_VERSION_PAYLOAD",
    "BIND_TO_MISSING_OR_DEVELOPMENT_ONLY_VERSION",
    "SEMANTIC_ASSESSMENT_TO_CANONICAL_ADMISSION",
    "STRUCTURAL_FAIL_TO_CHILD_ACTIVATION",
    "STALE_CAS_OR_FENCING_TO_CANONICAL_WRITE",
    "SELF_PROMOTION_WHERE_INDEPENDENCE_REQUIRED",
    "DELETE_REPLAY_REQUIRED_CANONICAL_HISTORY",
)

REQUIRED_PLANES = (
    "CANONICAL_SPINE:",
    "OPERATIONAL:",
    "OBSERVATION:",
    "DEVELOPMENT_MASON:",
    "EVIDENCE_GOVERNANCE:",
    "sixth_plane: false",
)

REQUIRED_ENFORCEMENT_POINTS = (
    "CANONICAL_VERSION_ADMISSION",
    "OBJECTIVE_BINDING_CREATE_OR_CHANGE",
    "PRINCIPAL_ACTIVATION",
    "REFINEMENT_PROMOTION",
    "EFFECT_AND_COMMIT_PATH_OBJECTIVE_VERIFICATION",
    "RECOVERY_AND_REPLAY",
)

FORBIDDEN_IMPLEMENTATION_MARKERS = (
    "CREATE TABLE",
    "ALTER TABLE",
    "CREATE FUNCTION",
    "CREATE OR REPLACE FUNCTION",
    "CREATE POLICY",
    "supabase/migrations/",
)


def validate_text(text: str) -> ValidationResult:
    errors: list[str] = []

    for token in REQUIRED_TOKENS:
        if token not in text:
            errors.append(f"MISSING_REQUIRED_TOKEN:{token}")

    for field in REQUIRED_LOGICAL_FIELDS:
        if f"- {field}" not in text:
            errors.append(f"MISSING_LOGICAL_FIELD:{field}")

    for transition in REQUIRED_FORBIDDEN_TRANSITIONS:
        if transition not in text:
            errors.append(f"MISSING_FORBIDDEN_TRANSITION:{transition}")

    for plane in REQUIRED_PLANES:
        if plane not in text:
            errors.append(f"MISSING_PLANE_MAPPING:{plane}")

    for point in REQUIRED_ENFORCEMENT_POINTS:
        if point not in text:
            errors.append(f"MISSING_ENFORCEMENT_POINT:{point}")

    for marker in FORBIDDEN_IMPLEMENTATION_MARKERS:
        if marker.lower() in text.lower():
            errors.append(f"SCHEMA_IMPLEMENTATION_SMUGGLED_IN:{marker}")

    if "objective_instances: CANONICAL_SPINE_REQUIRED_NOT_IMPLEMENTED" not in text:
        errors.append("CANONICAL_INSTANCE_BOUNDARY_NOT_EXPLICIT")
    if "development_surface: DCP_NON_CANONICAL" not in text:
        errors.append("DEVELOPMENT_SURFACE_NOT_EXPLICITLY_NONCANONICAL")
    if "expected_head_or_cas_required: true" not in text or "fencing_required: true" not in text:
        errors.append("CONCURRENCY_FAIL_CLOSED_CONTRACT_INCOMPLETE")
    if "requester_only_evidence_for_high_risk: forbidden" not in text:
        errors.append("HIGH_RISK_EVIDENCE_INDEPENDENCE_MISSING")

    return ValidationResult(not errors, tuple(sorted(set(errors))))


def validate_file(path: Path = DEFAULT_CANDIDATE) -> ValidationResult:
    if not path.exists():
        return ValidationResult(False, (f"CANDIDATE_FILE_MISSING:{path}",))
    return validate_text(path.read_text(encoding="utf-8"))


def main(argv: list[str] | None = None) -> int:
    args = list(sys.argv[1:] if argv is None else argv)
    path = Path(args[0]) if args else DEFAULT_CANDIDATE
    result = validate_file(path)
    if result.ok:
        print("WORLD8_OBJECTIVE_CONTRACT_FREEZE_CANDIDATE_VALIDATION: PASS")
        return 0
    print("WORLD8_OBJECTIVE_CONTRACT_FREEZE_CANDIDATE_VALIDATION: FAIL")
    for error in result.errors:
        print(error)
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
