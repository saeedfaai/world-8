import pathlib
import unittest

TEXT = (pathlib.Path(__file__).resolve().parent / 'INSTALL_PLAN.md').read_text()

class InstallPlanGate(unittest.TestCase):
    def test_review_gates_are_explicit(self):
        for issue in ('#65', '#68', '#69', '#72', '#74', '#77', '#80', '#81'):
            self.assertIn(issue, TEXT)
        self.assertIn('PENDING, silence', TEXT)
        self.assertIn('BASE_ONLY', TEXT)

    def test_exact_dependency_heads_are_pinned(self):
        for sha in (
            '5c8f87f535a32b56b24579a3f34c564b2ba7335a',
            'c6d4d66f7fa19f3d15937f67407efe635bfab0eb',
            '4cee1cf38e923c0919633ab2b7d6ead854dfd4cc',
            'b00164aeea119f00de9fe3e6e9e8d79c3003cbdc',
            'c324123a930963f9cab97d84fe33121805e1da65',
            'e33716771898993ba32155cd4c2041b1d762e8be',
            'fab68b004317c95d396ccf6d752a79cc96b098a7',
            'cc251f05911d5b9dd09ca3ac16102b32b1ab1111',
            '3fc5535ef2ab8eafe3fbb227e236bd1dc6f2779e',
        ):
            self.assertIn(sha, TEXT)

    def test_live_writer_drift_is_corrected(self):
        self.assertIn('world8_dev_create_work_claim_v2', TEXT)
        self.assertIn('world8_dev_create_work_claim_v3` is explicitly forbidden', TEXT)
        self.assertIn('DEPRECATED_USE_WORK_CLAIM_V2_THEN_ADMISSION_THEN_LEASE_V2', TEXT)
        self.assertIn('world8_dev_record_search_receipt_v1', TEXT)
        self.assertIn('world8_mason_preflight_v1', TEXT)

    def test_canonical_resource_gap_is_closed_without_raw_insert(self):
        self.assertIn('world8_register_karest_company_runtime_resource_v1', TEXT)
        self.assertIn('resource-github-karest-company-runtime-production', TEXT)
        self.assertIn('A raw INSERT is forbidden', TEXT)
        self.assertIn('world8_dev_canonical_git_resource_current_v1', TEXT)

    def test_hardened_registrar_security_is_mandatory(self):
        self.assertIn('SECURITY DEFINER', TEXT)
        self.assertIn('fixed `pg_catalog, public` search_path', TEXT)
        self.assertIn('denied to PUBLIC/anon/authenticated', TEXT)
        self.assertIn('service_role', TEXT)

    def test_canonical_writers_only(self):
        self.assertIn('world8_dev_register_workspace_v2', TEXT)
        self.assertIn('world8_dev_release_workspace_v1', TEXT)
        self.assertIn('world8_provider_execution_enqueue_v2', TEXT)
        self.assertIn('world8_provider_execution_dispatch_via_worker_v1', TEXT)

    def test_read_only_workspace_has_no_write_lease(self):
        self.assertIn('access_mode = `READ_ONLY`', TEXT)
        self.assertIn('isolation_mode = `REMOTE_WORKSPACE`', TEXT)
        self.assertIn('No write lease is created for this READ_ONLY workspace', TEXT)

    def test_security_posture_is_fail_closed(self):
        self.assertIn('RLS disabled', TEXT)
        self.assertIn('no `anon`/`authenticated` grants', TEXT)
        self.assertIn('confused deputy', TEXT)
        self.assertIn('unresolved Issue #77', TEXT)

    def test_hardened_edge_is_mandatory(self):
        self.assertIn('Hardened broker Edge PR #78', TEXT)
        self.assertIn('bounded body', TEXT)
        self.assertIn('exact envelope keys', TEXT)
        self.assertIn('public Ed25519 verification key only', TEXT)
        self.assertIn('raw_secret_returned=false', TEXT)

    def test_secret_and_key_boundaries(self):
        self.assertIn('never read/export raw provider secret', TEXT)
        self.assertIn('private signing material stays KAREST server-side', TEXT)
        self.assertIn('absence of secret-manager capability is a STOP', TEXT)

    def test_advisory_only_live_ceiling(self):
        self.assertIn('no tools;', TEXT)
        self.assertIn('no consequential effect;', TEXT)
        self.assertIn('no paid fallback;', TEXT)
        self.assertIn('not FULL_RELEASE_PASS', TEXT)

    def test_persistent_evidence_not_deleted(self):
        self.assertIn('do not DELETE them as rollback', TEXT)
        self.assertIn('must never reactivate lifecycle state', TEXT)
        self.assertIn('silently change canonical resource head', TEXT)

    def test_plan_performs_no_runtime_mutation(self):
        self.assertIn('PLAN_ONLY / NOT_EXECUTED / NO_RUNTIME_MUTATION', TEXT)
        self.assertIn('performs no World 8 runtime DDL', TEXT)
        self.assertIn('Company-runtime migration 046', TEXT)

if __name__ == '__main__':
    unittest.main(verbosity=2)
