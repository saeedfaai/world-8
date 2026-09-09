import pathlib
import unittest

SRC=(pathlib.Path(__file__).resolve().parent/'edge_entry.ts').read_text()

class EdgeHardeningGate(unittest.TestCase):
    def test_body_is_stream_bounded(self):
        self.assertIn('MAX_BODY_BYTES=32768', SRC)
        self.assertIn('req.body.getReader()', SRC)
        self.assertIn('total>MAX_BODY_BYTES', SRC)
        self.assertIn('BROKER_BODY_TOO_LARGE', SRC)

    def test_exact_envelope_keys_required(self):
        self.assertIn('exactEnvelopeKeys', SRC)
        self.assertIn('BROKER_ENVELOPE_FIELDS_INVALID', SRC)
        self.assertIn('Object.keys(b).sort()', SRC)

    def test_operation_shape_is_exact(self):
        self.assertIn('exactOperationShape', SRC)
        self.assertIn('b.target_request_id===null', SRC)
        self.assertIn('b.prompt===null&&b.prompt_sha256===null', SRC)

    def test_verify_jwk_is_public_ed25519_only(self):
        self.assertIn('jwk.kty!=="OKP"', SRC)
        self.assertIn('jwk.crv!=="Ed25519"', SRC)
        self.assertIn('typeof jwk.x!=="string"', SRC)
        self.assertIn('typeof jwk.d==="string"', SRC)

    def test_readiness_must_not_return_secret(self):
        self.assertIn('ready?.raw_secret_returned!==false', SRC)

    def test_service_role_never_returned(self):
        self.assertIn('SUPABASE_SERVICE_ROLE_KEY', SRC)
        self.assertNotIn('service_role_key:', SRC.lower())
        self.assertIn('raw_secret_returned:false', SRC)

    def test_canonical_pipeline_preserved(self):
        self.assertIn('world8_provider_execution_readiness_v2', SRC)
        self.assertIn('world8_provider_execution_enqueue_v2', SRC)
        self.assertIn('world8_provider_execution_dispatch_via_worker_v1', SRC)

    def test_no_direct_provider_endpoint(self):
        lower=SRC.lower()
        self.assertNotIn('api.groq.com', lower)
        self.assertNotIn('api.openai.com', lower)

if __name__=='__main__': unittest.main(verbosity=2)
