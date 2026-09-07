import re
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
SQL_PATH = ROOT / "supabase/drafts/20260829_world8_repo_aware_academy_bridge_v05.sql"
CONTRACT_PATH = ROOT / "architecture/contracts/world8-engineering-repo-aware-git-v0.5.yaml"
DOC_PATH = ROOT / "docs/engineering/WORLD9_REPO_AWARE_ACADEMY_BRIDGE.md"


class RepoAwareBridgeTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.sql = SQL_PATH.read_text(encoding="utf-8")
        cls.sql_lower = cls.sql.lower()
        cls.contract = CONTRACT_PATH.read_text(encoding="utf-8")
        cls.doc = DOC_PATH.read_text(encoding="utf-8")

    def test_additive_entry_points_exist(self):
        for name in (
            "world8_dev_canonical_git_resource_current_v1",
            "world8_dev_register_workspace_v2",
            "world8_academy_coding_entry_issue_v2",
            "world8_dev_admission_check_v4",
        ):
            self.assertIn(name, self.sql)

    def test_existing_v1_v3_v5_functions_are_not_replaced(self):
        forbidden_replacements = (
            "create or replace function public.world8_dev_register_workspace_v1",
            "create or replace function public.world8_academy_coding_entry_issue_v1",
            "create or replace function public.world8_dev_admission_check_v2",
            "create or replace function public.world8_dev_admission_check_v3",
            "create or replace function public.world8_dev_acquire_lease_v5",
        )
        for marker in forbidden_replacements:
            self.assertNotIn(marker, self.sql_lower)

    def test_migration_does_not_enroll_world9_or_any_repo(self):
        self.assertIsNone(re.search(r"insert\s+into\s+(?:public\.)?world8_dev_external_resources", self.sql, re.I))
        self.assertNotIn("resource-github-world9-runtime-canonical'", self.sql)

    def test_canonical_resource_is_not_caller_asserted(self):
        for marker in (
            "r.resource_type<>'GITHUB'",
            "metadata->>'canonical'",
            "metadata->>'role'",
            "canonical_architecture_and_code_source",
            "canonical_head_commit",
            "CANONICAL_GIT_RESOURCE_REQUIRED",
        ):
            self.assertIn(marker, self.sql)

    def test_workspace_requires_exact_resource_repo_and_head(self):
        for marker in (
            "NON_CANONICAL_REPO_FOR_RESOURCE",
            "STALE_CANONICAL_RESOURCE_BASE",
            "CANONICAL_BRANCH_WRITE_FORBIDDEN",
            "WORKSPACE_GIT_BINDING_IDEMPOTENCY_COLLISION",
        ):
            self.assertIn(marker, self.sql)

    def test_workspace_binding_is_append_only(self):
        self.assertIn("world8_dev_workspace_git_bindings", self.sql)
        self.assertIn("world8_workspace_git_binding_append_only_trg", self.sql)
        self.assertGreaterEqual(self.sql.count("world8_academy_evidence_append_only_v1"), 2)

    def test_entry_binds_same_canonical_resource_and_stays_zero_authority(self):
        for marker in (
            "world8_academy_entry_git_bindings",
            "ACADEMY_ENTRY_CANONICAL_RESOURCE_BINDING_REQUIRED",
            "'authority_effect','NONE'",
        ):
            self.assertIn(marker, self.sql)

    def test_admission_rejects_resource_or_head_movement(self):
        for marker in (
            "ENTRY_WORKSPACE_GIT_BINDING_MISMATCH",
            "STALE_CANONICAL_RESOURCE_BINDING",
            "ACADEMY_ENTRY_AUTHORITY_EFFECT_FORBIDDEN",
        ):
            self.assertIn(marker, self.sql)

    def test_admission_preserves_qualification_authorization_separation(self):
        self.assertIn("world8_dev_assignment_check_v1", self.sql)
        self.assertIn("world8_authorize_v1", self.sql)
        for scope_key in (
            "work_id",
            "workspace_id",
            "execution_id",
            "canonical_resource_id",
            "repo_ref",
            "branch_ref",
            "canonical_head",
        ):
            self.assertIn(f"'{scope_key}'", self.sql)

    def test_lease_v5_is_reused_not_forked(self):
        self.assertIn("world8_dev_acquire_lease_v5", self.contract)
        self.assertIn("Lease v5", self.doc)
        self.assertNotIn("create or replace function public.world8_dev_acquire_lease_v5", self.sql_lower)

    def test_service_role_gets_only_new_public_repo_aware_entry_points(self):
        for signature in (
            "world8_dev_register_workspace_v2",
            "world8_academy_coding_entry_issue_v2",
            "world8_dev_admission_check_v4",
        ):
            self.assertRegex(self.sql_lower, rf"grant execute on function public\.{signature}\([^;]+\)\s*to service_role;")
        self.assertRegex(
            self.sql_lower,
            r"revoke all on function public\.world8_dev_canonical_git_resource_current_v1\(text\)\s*from public,anon,authenticated,service_role;",
        )

    def test_migration_has_no_rollback_wrapper(self):
        self.assertIsNone(re.search(r"\brollback\s*;", self.sql, re.I))

    def test_contract_keeps_world9_enrollment_separate(self):
        self.assertIn("enrollment_state: NOT_ENROLLED", self.contract)
        self.assertIn("enrollment_requires_separate_governed_action: true", self.contract)
        self.assertIn("arbitrary_repo_input_allowed: false", self.contract)

    def test_no_raw_secret_or_provider_effect_markers(self):
        all_text = "\n".join((self.sql, self.contract, self.doc)).lower()
        for marker in ("password_value", "secret_value", "api_key_value", "access_token_value", "credential_value"):
            self.assertNotIn(marker, all_text)
        self.assertNotIn("provider_execute(", all_text)


if __name__ == "__main__":
    unittest.main()
