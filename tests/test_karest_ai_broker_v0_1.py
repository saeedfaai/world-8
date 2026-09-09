from datetime import datetime, timedelta, timezone
from hashlib import sha256
import importlib.util
from pathlib import Path
import sys
import unittest

MODULE = Path('proposals/karest_ai_broker_v0_1/reference.py')
spec = importlib.util.spec_from_file_location('karest_ai_broker_reference', MODULE)
assert spec and spec.loader
mod = importlib.util.module_from_spec(spec)
sys.modules[spec.name] = mod
spec.loader.exec_module(mod)


def make_request(now: datetime):
    prompt = 'Summarize current inventory as advisory text only.'
    return {
        'schema': mod.SCHEMA,
        'request_id': 'req-karest-001',
        'service_id': mod.SERVICE_ID,
        'issued_at': now.isoformat(),
        'expires_at': (now + timedelta(seconds=30)).isoformat(),
        'nonce': 'nonce-karest-001',
        'operation': mod.OPERATION,
        'context_ref': 'context-probe',
        'actor_ref_hash': 'a' * 64,
        'prompt_sha256': sha256(prompt.encode()).hexdigest(),
        'prompt': prompt,
        'policy': dict(mod.REQUIRED_POLICY),
        'signature': 'signed-envelope-probe',
    }


def admit_ok(r, now, seen=None):
    return mod.admit(r, now=now, seen_nonces=set() if seen is None else seen, verify_signature=lambda _: True)


class KarestAiBrokerAdmissionTests(unittest.TestCase):
    def test_valid_request_is_advisory_only_and_cannot_call_worker_directly(self):
        now = datetime.now(timezone.utc)
        result = admit_ok(make_request(now), now)
        self.assertTrue(result.advisory_only)
        self.assertFalse(result.provider_tools_allowed)
        self.assertFalse(result.consequential_effect_allowed)
        self.assertFalse(result.paid_fallback_allowed)
        self.assertFalse(result.direct_worker_invocation_allowed)
        self.assertFalse(result.raw_secret_returned)

    def test_invalid_signature_fails_closed_and_does_not_consume_nonce(self):
        now = datetime.now(timezone.utc)
        r = make_request(now)
        seen = set()
        with self.assertRaisesRegex(mod.BrokerAdmissionError, '^BROKER_SIGNATURE_INVALID$'):
            mod.admit(r, now=now, seen_nonces=seen, verify_signature=lambda _: False)
        self.assertNotIn(r['nonce'], seen)

    def test_expired_request_fails_closed(self):
        now = datetime.now(timezone.utc)
        r = make_request(now - timedelta(minutes=2))
        with self.assertRaisesRegex(mod.BrokerAdmissionError, '^BROKER_REQUEST_EXPIRED$'):
            admit_ok(r, now)

    def test_replay_fails_closed(self):
        now = datetime.now(timezone.utc)
        r = make_request(now)
        seen = set()
        admit_ok(r, now, seen)
        with self.assertRaisesRegex(mod.BrokerAdmissionError, '^BROKER_REPLAY_BLOCKED$'):
            admit_ok(r, now, seen)

    def test_policy_widening_fails_closed(self):
        now = datetime.now(timezone.utc)
        for key, value in [
            ('providerToolsAllowed', True),
            ('consequentialEffectAllowed', True),
            ('paidFallbackAllowed', True),
            ('advisoryOnly', False),
        ]:
            with self.subTest(key=key):
                r = make_request(now)
                r['nonce'] = f'nonce-{key}'
                r['policy'][key] = value
                with self.assertRaisesRegex(mod.BrokerAdmissionError, '^BROKER_POLICY_WIDENING_FORBIDDEN$'):
                    admit_ok(r, now)

    def test_prompt_hash_mismatch_fails_closed(self):
        now = datetime.now(timezone.utc)
        r = make_request(now)
        r['prompt_sha256'] = '0' * 64
        with self.assertRaisesRegex(mod.BrokerAdmissionError, '^BROKER_PROMPT_HASH_MISMATCH$'):
            admit_ok(r, now)

    def test_unknown_or_extra_fields_fail_closed(self):
        now = datetime.now(timezone.utc)
        r = make_request(now)
        r['provider_api_key'] = 'forbidden'
        with self.assertRaisesRegex(mod.BrokerAdmissionError, '^BROKER_SCHEMA_FIELDS_INVALID$'):
            admit_ok(r, now)

    def test_reference_source_contains_no_provider_secret_or_direct_worker_endpoint(self):
        text = MODULE.read_text()
        self.assertNotIn('gsk_', text)
        self.assertNotIn('GROQ_API_KEY4', text)
        self.assertNotIn('world8-provider-worker-generic-v01', text)
        self.assertNotIn('api.groq.com', text)


if __name__ == '__main__':
    unittest.main()
