from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ACADEMY = ROOT / "supabase/migrations/20260827201500_world8_academy_access_runtime_v01.sql"
CHECKRIDE_REFS = ROOT / "supabase/migrations/20260827201830_world8_academy_checkride_required_refs_v02.sql"
CHECKRIDE_MACHINE = ROOT / "supabase/migrations/20260827202030_world8_academy_machine_checkride_v03.sql"
COCKPIT = ROOT / "supabase/migrations/20260827202330_world8_artifact_bound_lease_and_cockpit_v01.sql"
ACCESS_V2 = ROOT / "supabase/migrations/20260827202500_world8_developer_access_grant_v02.sql"
EXPIRY = ROOT / "supabase/migrations/20260827202900_world8_authorization_expiry_recheck_v01.sql"
WORKFLOW = ROOT / ".github/workflows/validate-architecture.yml"

for path in (ACADEMY, CHECKRIDE_REFS, CHECKRIDE_MACHINE, COCKPIT, ACCESS_V2, EXPIRY, WORKFLOW):
    assert path.exists(), f"required file missing: {path.relative_to(ROOT)}"

academy = ACADEMY.read_text(encoding="utf-8").lower()
refs = CHECKRIDE_REFS.read_text(encoding="utf-8").lower()
machine = CHECKRIDE_MACHINE.read_text(encoding="utf-8").lower()
cockpit = COCKPIT.read_text(encoding="utf-8").lower()
access = ACCESS_V2.read_text(encoding="utf-8").lower()
expiry = EXPIRY.read_text(encoding="utf-8").lower()
workflow = WORKFLOW.read_text(encoding="utf-8").lower()
combined = "\n".join((academy, refs, machine, cockpit, access, expiry))

for marker in (
    "world8_academy_curricula",
    "world8_academy_checkride_receipts",
    "world8_academy_record_checkride_v1",
    "world8_academy_issue_license_v1",
    "authorization_granted",
):
    assert marker in academy, f"Academy v0.1 marker missing: {marker}"

assert "required_refs_verified" in refs
assert "pass_checkride_evidence_or_score_insufficient" in refs

for marker in (
    "world8_academy_mason_core_checkride_v2",
    "mason_core/2.0",
    "machine_verified",
    "machine_preflight_pass_required",
    "machine_academy_shadow_current_required",
    "machine_workspace_base_fresh_required",
    "machine_scribe_pass_required",
    "machine_guardian_attached_required",
    "machine_diagnostic_search_capture_required",
    "world8_academy_issue_license_v2",
):
    assert marker in machine, f"Machine Checkride marker missing: {marker}"

for marker in (
    "world8_dev_acquire_lease_v4",
    "authorization_artifact_mismatch",
    "authorization_resource_bound",
    "world8_dev_cockpit_receipts",
    "world8_dev_cockpit_receipt_v1",
    "projection_only",
):
    assert marker in cockpit, f"Cockpit/Lease marker missing: {marker}"

for marker in (
    "world8_dev_access_grant_issue_v2",
    "active_machine_verified_mason_core_required",
    "pass_developer_admission_required",
    "checked_authorization_allow_required",
    "github_branch_must_match_isolated_workspace",
    "opaque_approved_connector_ref_required",
    "revoke all on function public.world8_dev_access_grant_issue_v1",
):
    assert marker in access, f"Developer Access v2 marker missing: {marker}"

for marker in (
    "authorization_evidence_expired",
    "developer_access_exceeds_authorization_expiry",
    "lease_ttl_exceeds_authorization_expiry",
    "access_authorization_evidence_expired",
    "lease_authorization_evidence_expired",
    "world8_dev_cockpit_receipt/1.1",
    "world8_dev_lease/4.1",
    "world8_dev_access_grant/2.1",
):
    assert marker in expiry, f"Authorization expiry invariant missing: {marker}"

for forbidden in (
    "api_key_value",
    "password_value",
    "token_value",
    "private_key_value",
    "credential_value",
    "raw_secret_value",
):
    assert forbidden not in combined, f"raw secret storage field forbidden: {forbidden}"

assert "qualification does not" in combined or "qualification != authority" in combined or "qualification_not_authority" in combined
assert "authority_granted',false" in combined or "authority_granted\",false" in combined
assert "python scripts/validate_academy_access_cockpit.py" in workflow

print("Academy / Developer Access / Lease / Cockpit static validation: PASS")
