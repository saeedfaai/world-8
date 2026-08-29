from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
MIGRATION = ROOT / "supabase" / "drafts" / "20260829_world8_repo_aware_academy_bridge_v05_acl_hardening.sql"


class RepoAwareBridgeAclHardeningTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.sql = MIGRATION.read_text(encoding="utf-8").lower()

    def test_rls_enabled_on_bridge_binding_tables(self):
        self.assertIn("alter table public.world8_dev_workspace_git_bindings enable row level security", self.sql)
        self.assertIn("alter table public.world8_academy_entry_git_bindings enable row level security", self.sql)

    def test_direct_api_and_service_role_table_access_revoked(self):
        for table in (
            "public.world8_dev_workspace_git_bindings",
            "public.world8_academy_entry_git_bindings",
        ):
            self.assertIn(f"revoke all on table {table}", self.sql)
        self.assertIn("from public, anon, authenticated, service_role", self.sql)

    def test_hardening_does_not_enroll_world9_resource(self):
        self.assertIn("'resource_enrollment_performed',false", self.sql)
        self.assertNotIn("resource-github-world9-runtime-canonical", self.sql)


if __name__ == "__main__":
    unittest.main()
