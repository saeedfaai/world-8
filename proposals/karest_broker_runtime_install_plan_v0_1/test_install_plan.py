import pathlib
import unittest

TEXT = (pathlib.Path(__file__).resolve().parent / 'INSTALL_PLAN.md').read_text()

class InstallPlanGate(unittest.TestCase):
    def test_all_review_issues_are_mandatory(self):
        for issue in ('#65', '#68', '#69', '#72', '#74'):
            self.assertIn(issue, TEXT)
        self.assertIn('PENDING, silence', TEXT)

    def test_exact_dependency_heads_are_pinned(self):
        for sha in (
            '5c8f87f535a32b56b24579a3f34c564b2ba7335a',
            'c6d4d66f7fa19f3d15937f67407efe635bfab0eb',
            'b00164aeea119f00de9fe3e6e9e8d79c3003cbdc',
            'c324123a930963f9cab97d84fe33121805e1da65',
            'e33716771898993ba32155cd4c2041b1d762e8be',
            'fab68b004317c95d396ccf6d752a79cc96b098a7',
        ):
            self.assertIn(sha, TEXT)

    def test_canonical_writers_only(self):
        self.assertIn('world8_dev_create_work_claim_v3', TEXT)
        self.assertIn('world8_dev_register_workspace_v2', TEXT)
        self.assertIn('world8_dev_release_workspace_v1', TEXT)

    def test_read_only_workspace(self):
        self.assertIn('access_mode = `READ_ONLY`', TEXT)
        self.assertIn('isolation_mode = `REMOTE_WORKSPACE`', TEXT)
        self.assertIn('canonical mutation = false', TEXT)

    def test_secret_and_key_boundaries(self):
        self.assertIn('never read/export raw provider secret', TEXT)
        self.assertIn('private signing material stays KAREST server-side', TEXT)
        self.assertIn('NOT executed by this plan', TEXT)

    def test_advisory_only_live_ceiling(self):
        self.assertIn('no tools;', TEXT)
        self.assertIn('no consequential effect;', TEXT)
        self.assertIn('no paid fallback;', TEXT)
        self.assertIn('not FULL_RELEASE_PASS', TEXT)

    def test_actor_is_persistent_not_deleted(self):
        self.assertIn('do not DELETE it as rollback', TEXT)
        self.assertIn('registrar must never reactivate it', TEXT)

    def test_plan_performs_no_runtime_mutation(self):
        self.assertIn('PLAN_ONLY / NOT_EXECUTED / NO_RUNTIME_MUTATION', TEXT)
        self.assertIn('No World 8 runtime DDL', TEXT)
        self.assertIn('migration 046', TEXT)

if __name__ == '__main__':
    unittest.main(verbosity=2)
