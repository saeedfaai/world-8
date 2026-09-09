from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime, timezone
from hashlib import sha256
from typing import Callable, Mapping, MutableSet

SCHEMA = "WORLD8_KAREST_AI_BROKER_REQUEST/1.0"
SERVICE_ID = "service-karest-advisory-v01"
OPERATION = "ai.advisory.generate"
MAX_TTL_SECONDS = 60
MAX_CLOCK_SKEW_SECONDS = 10
MAX_PROMPT_BYTES = 48_000
REQUIRED_POLICY = {
    "advisoryOnly": True,
    "providerToolsAllowed": False,
    "consequentialEffectAllowed": False,
    "paidFallbackAllowed": False,
}


class BrokerAdmissionError(ValueError):
    pass


@dataclass(frozen=True)
class BrokerAdmission:
    request_id: str
    service_id: str
    context_ref: str
    actor_ref_hash: str
    operation: str
    advisory_only: bool = True
    provider_tools_allowed: bool = False
    consequential_effect_allowed: bool = False
    paid_fallback_allowed: bool = False
    direct_worker_invocation_allowed: bool = False
    raw_secret_returned: bool = False


def _parse_utc(value: object, code: str) -> datetime:
    if not isinstance(value, str) or not value:
        raise BrokerAdmissionError(code)
    try:
        dt = datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError as exc:
        raise BrokerAdmissionError(code) from exc
    if dt.tzinfo is None:
        raise BrokerAdmissionError(code)
    return dt.astimezone(timezone.utc)


def _plain_token(value: object, code: str, max_len: int = 160) -> str:
    if not isinstance(value, str) or not value or len(value) > max_len:
        raise BrokerAdmissionError(code)
    if any(ch.isspace() for ch in value):
        raise BrokerAdmissionError(code)
    return value


def admit(
    request: Mapping[str, object],
    *,
    now: datetime,
    seen_nonces: MutableSet[str],
    verify_signature: Callable[[Mapping[str, object]], bool],
) -> BrokerAdmission:
    if set(request) != {
        "schema", "request_id", "service_id", "issued_at", "expires_at", "nonce",
        "operation", "context_ref", "actor_ref_hash", "prompt_sha256", "prompt",
        "policy", "signature",
    }:
        raise BrokerAdmissionError("BROKER_SCHEMA_FIELDS_INVALID")
    if request.get("schema") != SCHEMA:
        raise BrokerAdmissionError("BROKER_SCHEMA_INVALID")
    if request.get("service_id") != SERVICE_ID:
        raise BrokerAdmissionError("BROKER_SERVICE_ID_FORBIDDEN")
    if request.get("operation") != OPERATION:
        raise BrokerAdmissionError("BROKER_OPERATION_FORBIDDEN")

    request_id = _plain_token(request.get("request_id"), "BROKER_REQUEST_ID_INVALID")
    nonce = _plain_token(request.get("nonce"), "BROKER_NONCE_INVALID")
    context_ref = _plain_token(request.get("context_ref"), "BROKER_CONTEXT_REF_INVALID", 256)
    actor_ref_hash = _plain_token(request.get("actor_ref_hash"), "BROKER_ACTOR_REF_HASH_INVALID", 128)
    signature = _plain_token(request.get("signature"), "BROKER_SIGNATURE_MISSING", 1024)
    if not signature:
        raise BrokerAdmissionError("BROKER_SIGNATURE_MISSING")

    issued = _parse_utc(request.get("issued_at"), "BROKER_ISSUED_AT_INVALID")
    expires = _parse_utc(request.get("expires_at"), "BROKER_EXPIRES_AT_INVALID")
    now = now.astimezone(timezone.utc)
    ttl = (expires - issued).total_seconds()
    if ttl <= 0 or ttl > MAX_TTL_SECONDS:
        raise BrokerAdmissionError("BROKER_TTL_INVALID")
    if (issued - now).total_seconds() > MAX_CLOCK_SKEW_SECONDS:
        raise BrokerAdmissionError("BROKER_CLOCK_SKEW")
    if now > expires:
        raise BrokerAdmissionError("BROKER_REQUEST_EXPIRED")

    if nonce in seen_nonces:
        raise BrokerAdmissionError("BROKER_REPLAY_BLOCKED")

    prompt = request.get("prompt")
    if not isinstance(prompt, str) or not prompt or len(prompt.encode("utf-8")) > MAX_PROMPT_BYTES:
        raise BrokerAdmissionError("BROKER_PROMPT_INVALID")
    expected_hash = sha256(prompt.encode("utf-8")).hexdigest()
    if request.get("prompt_sha256") != expected_hash:
        raise BrokerAdmissionError("BROKER_PROMPT_HASH_MISMATCH")

    policy = request.get("policy")
    if policy != REQUIRED_POLICY:
        raise BrokerAdmissionError("BROKER_POLICY_WIDENING_FORBIDDEN")

    if not verify_signature(request):
        raise BrokerAdmissionError("BROKER_SIGNATURE_INVALID")

    # Replay state is committed only after all validation, including signature.
    seen_nonces.add(nonce)
    return BrokerAdmission(
        request_id=request_id,
        service_id=SERVICE_ID,
        context_ref=context_ref,
        actor_ref_hash=actor_ref_hash,
        operation=OPERATION,
    )
