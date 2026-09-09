import unittest
from pathlib import Path

DOC = Path('architecture/proposals/KAREST_BROKER_ENROLLMENT_v0_1.md').read_text()

class KarestBrokerEnrollmentProposalTests(unittest.TestCase):
    def test_actor_identity_is_service_company_without_authority(self):
        for marker in [
            '`actor_id`: `service-karest-advisory-broker-001`',
            '`actor_kind`: `SERVICE`',
            '`home_scope`: `COMPANY`',
            '`authority_ref`: `NULL`',
            '"authority_effect": "NONE"',
            '"runtime_authority_effect": "NONE"',
        ]:
            self.assertIn(marker, DOC)

    def test_actor_cannot_gain_effect_or_business_authority(self):
        for marker in [
            '"may_write_code": false',
            '"may_promote": false',
            '"may_purchase": false',
            '"may_grant_authority": false',
            '"may_execute_provider_tools": false',
            '"may_create_consequential_effect": false',
            '"may_access_provider_secret": false',
        ]:
            self.assertIn(marker, DOC)

    def test_workspace_is_exact_and_read_only(self):
        for marker in [
            '`repo_ref`: `saeedfaai/Company-runtime`',
            '`branch_ref`: `karest/auth-account-session-shell-v0-1`',
            '`access_mode`: `READ_ONLY`',
            '`isolation_mode`: `REMOTE_WORKSPACE`',
            '"canonical_mutation": false',
            '"no_code_mutation": true',
        ]:
            self.assertIn(marker, DOC)
        self.assertIn('A later change to `WRITE` requires a separate governed proposal', DOC)

    def test_provider_route_is_pinned_but_secret_is_not(self):
        for marker in [
            'adapter-groq-external-v01',
            'transport-supabase-groq-generic-v01',
            'binding-groq-envref-key4-v01',
            'openai/gpt-oss-20b',
        ]:
            self.assertIn(marker, DOC)
        self.assertNotIn('gsk_', DOC)
        self.assertNotIn('GROQ_API_KEY4', DOC)

    def test_only_advisory_operations_and_policy_are_allowed(self):
        for marker in [
            '`advisory.generate.submit`',
            '`advisory.generate.status`',
            '"advisoryOnly": true',
            '"providerToolsAllowed": false',
            '"consequentialEffectAllowed": false',
            '"paidFallbackAllowed": false',
        ]:
            self.assertIn(marker, DOC)

    def test_enrollment_cannot_replace_provider_pipeline(self):
        self.assertIn('Enrollment is not dispatch authority', DOC)
        for marker in [
            'KAREST signature/time/hash/policy fence',
            'World 8 provider readiness',
            'canonical enqueue/idempotency',
            'worker challenge',
            'worker claim',
            'output/evidence/receipt',
        ]:
            self.assertIn(marker, DOC)

    def test_revocation_conditions_fail_closed(self):
        for marker in [
            'Actor status changes from ACTIVE',
            'Workspace is RELEASED / STALE / BLOCKED',
            'Workspace access_mode ceases to be READ_ONLY',
            'request policy widens beyond advisory-only',
        ]:
            self.assertIn(marker, DOC)

    def test_proposal_has_no_runtime_mutation_or_secret(self):
        self.assertIn('PROPOSAL_ONLY / PRE_RUNTIME / NO DDL / NO INSERT / NO AUTHORITY CREATION', DOC)
        for forbidden in ['INSERT INTO', 'UPDATE public.', 'CREATE TABLE', 'PRIVATE KEY-----', 'service_role_key', 'gsk_']:
            self.assertNotIn(forbidden, DOC)

    def test_negative_test_contract_is_explicit(self):
        self.assertIn('Required negative tests before runtime enrollment', DOC)
        self.assertIn('Workspace `WRITE` rejected', DOC)
        self.assertIn('enrollment alone cannot mint authority', DOC)
        self.assertIn('provider secret cannot enter enrollment artifacts', DOC)

if __name__ == '__main__':
    unittest.main()
