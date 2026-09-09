import pathlib
import unittest

ROOT = pathlib.Path(__file__).resolve().parent
SQL = (ROOT / 'reference.sql').read_text()
CONTRACT = (ROOT / 'CONTRACT.md').read_text()

class RegistrarSourceGate(unittest.TestCase):
    def test_proposal_only_not_migration(self):
        self.assertIn('PROPOSAL_ONLY / NOT_APPLIED / NO_RUNTIME_MUTATION', SQL)
        self.assertIn('intentionally not a migration', SQL)

    def test_exact_stable_identity(self):
        self.assertGreaterEqual(SQL.count("service-karest-advisory-broker-001"), 4)
        self.assertIn("'SERVICE'", SQL)
        self.assertIn("'COMPANY'", SQL)

    def test_no_authority_ref(self):
        self.assertIn('v_existing.authority_ref is not null', SQL)
        self.assertIn("'authority_effect', 'NONE'", SQL)
        self.assertIn('authority_ref, metadata', SQL)

    def test_no_consequential_or_provider_tool_authority(self):
        self.assertIn("'consequential_effects', false", SQL)
        self.assertIn("'provider_tools', false", SQL)
        self.assertIn("'canonical_mutation_authority', false", SQL)

    def test_no_credential_code_write_or_spend(self):
        self.assertIn("'credential_access', 'NONE'", SQL)
        self.assertIn("'code_write', false", SQL)
        self.assertIn("'spend', false", SQL)

    def test_concurrency_lock_present(self):
        self.assertIn('pg_advisory_xact_lock', SQL)
        self.assertIn("hashtextextended('service-karest-advisory-broker-001', 0)", SQL)

    def test_idempotent_replay_and_conflict(self):
        self.assertIn("'disposition', 'REPLAY'", SQL)
        self.assertIn('IDENTITY_CONFLICT', SQL)
        self.assertIn("'disposition', 'RECORDED'", SQL)

    def test_no_silent_reactivation(self):
        self.assertIn("v_existing.status <> 'ACTIVE'", SQL)
        self.assertIn('ACTOR_NOT_ACTIVE', SQL)
        self.assertIn('registrar cannot reactivate lifecycle state', SQL)

    def test_receipt_is_identity_only(self):
        self.assertIn('receipt is evidence of identity registration only', CONTRACT.lower())
        self.assertIn("'identity_version'", SQL)
        self.assertIn("'recorded_at'", SQL)

    def test_downstream_canonical_writers_preserved(self):
        self.assertIn('world8_dev_create_work_claim_v3', CONTRACT)
        self.assertIn('world8_dev_register_workspace_v2', CONTRACT)
        self.assertIn('readiness -> enqueue_v2 -> dispatch_via_worker_v1', CONTRACT)

    def test_no_grant_or_provider_invocation_in_sql(self):
        lower = SQL.lower()
        self.assertNotIn(' grant ', lower)
        self.assertNotIn('http', lower)
        self.assertNotIn('groq', lower)
        self.assertNotIn('openai', lower)

if __name__ == '__main__':
    unittest.main(verbosity=2)
