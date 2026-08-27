from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MIGRATIONS = ROOT / "supabase" / "migrations"
DOC = ROOT / "docs" / "engineering" / "CREDENTIAL_BROKER_EXTERNAL_WORKER.md"

files = sorted(MIGRATIONS.glob("*credential_broker_external_worker*.sql")) + sorted(MIGRATIONS.glob("*provider_live_execution_bridge*.sql"))
assert files, "credential broker / live bridge migrations missing"
sql = "\n".join(p.read_text(encoding="utf-8") for p in files)
assert DOC.exists(), "credential broker documentation missing"
doc = DOC.read_text(encoding="utf-8")

required_sql = [
    "world8_provider_credential_bindings",
    "world8_provider_credential_verification_receipts",
    "world8_provider_worker_transports",
    "world8_provider_worker_verification_receipts",
    "world8_provider_worker_challenges",
    "world8_provider_credential_probe_challenges",
    "world8_provider_worker_challenge_issue_v1",
    "world8_provider_worker_challenge_attest_v1",
    "world8_provider_credential_probe_issue_v1",
    "world8_provider_credential_probe_attest_v1",
    "world8_provider_execution_readiness_v2",
    "world8_provider_execution_enqueue_v2",
    "world8_provider_execution_claim_v2",
    "world8_provider_execution_dispatch_envelope_v2",
    "world8_provider_execution_complete_v2",
    "world8_provider_worker_dispatch_receipts",
    "OPAQUE",
    "raw_secret",
    "private_reasoning",
    "append_only",
    "service_role",
    "from public,anon,authenticated",
    "REAL_PROVIDER_INVOCATION_EVIDENCE_REQUIRED",
]
for marker in required_sql:
    assert marker.lower() in sql.lower(), f"missing broker/live invariant: {marker}"

# Security and truth boundaries.
assert "envref:OPENAI_API_KEY" in sql
assert "raw_secret_stored',false" in sql or "raw_secret_stored\",false" in sql
assert "raw_secret_returned',false" in sql or "raw_secret_returned\",false" in sql
assert "live_provider_invoked',false" in sql or "live_provider_invoked\",false" in sql
assert "CREDENTIAL_BINDING_NOT_VERIFIED" in sql
assert "WORKER_TRANSPORT_NOT_VERIFIED" in sql
assert "verification_state='VERIFIED'" in sql
assert "claim_token" in sql
assert "token_hash" in sql
assert "EXECUTION_IDEMPOTENCY_COLLISION" in sql

required_doc = [
    "OPAQUE_REF_ONLY",
    "Actor identity persists",
    "provider/model belongs only to Execution",
    "CREDENTIAL_BINDING_NOT_VERIFIED",
    "WORKER_TRANSPORT_NOT_VERIFIED",
    "No live OpenAI/provider invocation",
    "1 real canary -> 5 -> 20 -> 100",
]
for marker in required_doc:
    assert marker in doc, f"missing broker documentation invariant: {marker}"

print(f"Credential Broker + External Worker validation: PASS ({len(files)} migration files)")
