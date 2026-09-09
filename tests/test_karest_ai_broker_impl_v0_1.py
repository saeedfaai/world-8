import unittest
from pathlib import Path

SRC = Path('proposals/karest_ai_broker_impl_v0_1/edge_entry.ts').read_text()

class KarestAiBrokerImplementationTests(unittest.TestCase):
    def test_exact_world8_route_is_pinned(self):
        self.assertIn('adapter-groq-external-v01', SRC)
        self.assertIn('transport-supabase-groq-generic-v01', SRC)
        self.assertIn('binding-groq-envref-key4-v01', SRC)
        self.assertIn('openai/gpt-oss-20b', SRC)

    def test_uses_canonical_pipeline_only(self):
        self.assertIn('world8_provider_execution_readiness_v2', SRC)
        self.assertIn('world8_provider_execution_enqueue_v2', SRC)
        self.assertIn('world8_provider_execution_dispatch_via_worker_v1', SRC)
        self.assertNotIn('world8-provider-worker-generic-v01', SRC)
        self.assertNotIn('api.groq.com', SRC)

    def test_enrollment_is_mandatory(self):
        self.assertIn('KAREST_WORLD8_ACTOR_ID', SRC)
        self.assertIn('KAREST_WORLD8_WORK_ID', SRC)
        self.assertIn('KAREST_WORLD8_WORKSPACE_ID', SRC)
        self.assertIn('KAREST_WORLD8_ENROLLMENT_REQUIRED', SRC)

    def test_signature_and_time_fences_exist(self):
        self.assertIn('KAREST_BROKER_VERIFY_JWK', SRC)
        self.assertIn('Ed25519', SRC)
        self.assertIn('BROKER_SIGNATURE_INVALID', SRC)
        self.assertIn('BROKER_TIME_FENCE_REJECTED', SRC)
        self.assertIn('target_request_id:b.target_request_id??null', SRC)

    def test_policy_cannot_widen(self):
        for marker in ['advisoryOnly:true','providerToolsAllowed:false','consequentialEffectAllowed:false','paidFallbackAllowed:false','BROKER_POLICY_WIDENING_FORBIDDEN']:
            self.assertIn(marker, SRC)

    def test_prompt_is_hash_bound_and_bounded(self):
        self.assertIn('BROKER_PROMPT_INVALID', SRC)
        self.assertIn('b.prompt.length>12000', SRC)
        self.assertIn('sha256Hex(b.prompt)', SRC)

    def test_replay_does_not_redispatch(self):
        self.assertIn('p_idempotency_key:idem', SRC)
        self.assertIn('enq?.idempotent_replay===true', SRC)
        self.assertIn('dispatch_repeated:false', SRC)
        self.assertIn('state:"IDEMPOTENT_REPLAY"', SRC)

    def test_status_is_bound_to_enrolled_actor_work_workspace(self):
        self.assertIn('world8_provider_execution_requests?request_id=eq.', SRC)
        self.assertIn('&actor_id=eq.', SRC)
        self.assertIn('&work_id=eq.', SRC)
        self.assertIn('&workspace_id=eq.', SRC)
        self.assertIn('world8_provider_execution_outputs?request_id=eq.', SRC)

    def test_no_provider_secret_literals(self):
        self.assertNotIn('gsk_', SRC)
        self.assertNotIn('GROQ_API_KEY4', SRC)
        self.assertNotIn('OPENAI_API_KEY', SRC)
        self.assertIn('raw_secret_returned:false', SRC)

    def test_candidate_remains_non_deployed(self):
        self.assertIn('PROPOSAL ONLY', SRC)
        self.assertIn('deployed:false', SRC)

if __name__ == '__main__':
    unittest.main()