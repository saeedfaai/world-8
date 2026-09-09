from datetime import datetime, timedelta, timezone
from hashlib import sha256
import importlib.util
from pathlib import Path
import sys

MODULE = Path('proposals/karest_ai_broker_v0_1/reference.py')
spec = importlib.util.spec_from_file_location('karest_ai_broker_reference', MODULE)
assert spec and spec.loader
mod = importlib.util.module_from_spec(spec)
sys.modules[spec.name] = mod
spec.loader.exec_module(mod)


def request(now: datetime):
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


def test_valid_request_is_advisory_only_and_cannot_call_worker_directly():
    now = datetime.now(timezone.utc)
    result = admit_ok(request(now), now)
    assert result.advisory_only is True
    assert result.provider_tools_allowed is False
    assert result.consequential_effect_allowed is False
    assert result.paid_fallback_allowed is False
    assert result.direct_worker_invocation_allowed is False
    assert result.raw_secret_returned is False


def test_invalid_signature_fails_closed_and_does_not_consume_nonce():
    now = datetime.now(timezone.utc)
    r = request(now)
    seen = set()
    try:
        mod.admit(r, now=now, seen_nonces=seen, verify_signature=lambda _: False)
    except mod.BrokerAdmissionError as exc:
        assert str(exc) == 'BROKER_SIGNATURE_INVALID'
    else:
        raise AssertionError('invalid signature passed')
    assert r['nonce'] not in seen


def test_expired_request_fails_closed():
    now = datetime.now(timezone.utc)
    r = request(now - timedelta(minutes=2))
    try:
        admit_ok(r, now)
    except mod.BrokerAdmissionError as exc:
        assert str(exc) == 'BROKER_REQUEST_EXPIRED'
    else:
        raise AssertionError('expired request passed')


def test_replay_fails_closed():
    now = datetime.now(timezone.utc)
    r = request(now)
    seen = set()
    admit_ok(r, now, seen)
    try:
        admit_ok(r, now, seen)
    except mod.BrokerAdmissionError as exc:
        assert str(exc) == 'BROKER_REPLAY_BLOCKED'
    else:
        raise AssertionError('replay passed')


def test_policy_widening_fails_closed():
    now = datetime.now(timezone.utc)
    for key, value in [
        ('providerToolsAllowed', True),
        ('consequentialEffectAllowed', True),
        ('paidFallbackAllowed', True),
        ('advisoryOnly', False),
    ]:
        r = request(now)
        r['nonce'] = f'nonce-{key}'
        r['policy'][key] = value
        try:
            admit_ok(r, now)
        except mod.BrokerAdmissionError as exc:
            assert str(exc) == 'BROKER_POLICY_WIDENING_FORBIDDEN'
        else:
            raise AssertionError(f'policy widening passed: {key}')


def test_prompt_hash_mismatch_fails_closed():
    now = datetime.now(timezone.utc)
    r = request(now)
    r['prompt_sha256'] = '0' * 64
    try:
        admit_ok(r, now)
    except mod.BrokerAdmissionError as exc:
        assert str(exc) == 'BROKER_PROMPT_HASH_MISMATCH'
    else:
        raise AssertionError('prompt hash mismatch passed')


def test_unknown_or_extra_fields_fail_closed():
    now = datetime.now(timezone.utc)
    r = request(now)
    r['provider_api_key'] = 'forbidden'
    try:
        admit_ok(r, now)
    except mod.BrokerAdmissionError as exc:
        assert str(exc) == 'BROKER_SCHEMA_FIELDS_INVALID'
    else:
        raise AssertionError('unknown field passed')


def test_reference_source_contains_no_provider_secret_or_direct_worker_endpoint():
    text = MODULE.read_text()
    assert 'gsk_' not in text
    assert 'GROQ_API_KEY4' not in text
    assert 'world8-provider-worker-generic-v01' not in text
    assert 'api.groq.com' not in text
