from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MIGRATION = ROOT / "supabase/migrations/20260827155324_world8_provider_execution_adapter_foundation_v01.sql"
DOC = ROOT / "docs/engineering/PROVIDER_EXECUTION_ADAPTER.md"

assert MIGRATION.exists(), "provider execution adapter migration missing"
assert DOC.exists(), "provider execution adapter documentation missing"

sql = MIGRATION.read_text(encoding="utf-8")
doc = DOC.read_text(encoding="utf-8")

required_sql = [
    "world8_provider_execution_adapters",
    "world8_provider_execution_requests",
    "world8_provider_execution_receipts",
    "world8_provider_execution_adapter_register_v1",
    "world8_provider_execution_readiness_v1",
    "world8_provider_execution_enqueue_v1",
    "world8_provider_execution_claim_v1",
    "world8_provider_execution_heartbeat_v1",
    "world8_provider_execution_complete_v1",
    "world8_provider_execution_fail_v1",
    "world8_provider_execution_snapshot_v1",
    "world8_actor_start_execution_v1",
    "world8_mason_pool_bind_execution_v1",
    "OPAQUE_CREDENTIAL_REF_REQUIRED",
    "CREDENTIAL_BROKER_NOT_IMPLEMENTED",
    "WORLD8_PROVIDER_EXECUTION_RECEIPTS_APPEND_ONLY",
    "EXECUTION_IDEMPOTENCY_COLLISION",
    "ASSIGNMENT_ACTOR_WORK_WORKSPACE_BINDING_REQUIRED",
    "EXECUTION_REQUEST_SECRET_OR_PRIVATE_REASONING_REJECTED",
    "live_provider_invoked",
]
for marker in required_sql:
    assert marker in sql, f"missing provider execution invariant: {marker}"

# v0.1 is deliberately fail-closed for real external providers.
assert "adapter_kind='MOCK_INTERNAL'" in sql
assert "gate_state','BLOCKED'" in sql
assert "credential_state" in sql
assert "credential_ref !~ '^(secretref:|vault:|envref:|connector:)" in sql
assert "grant execute" in sql and "service_role" in sql
assert "from public,anon,authenticated" in sql

required_doc = [
    "Actor identity persists",
    "provider/model belongs only to Execution",
    "OPAQUE_REF_ONLY",
    "CREDENTIAL_BROKER_NOT_IMPLEMENTED",
    "No raw provider secrets",
    "No claim of live provider invocation",
    "100 concurrent Mason",
]
for marker in required_doc:
    assert marker in doc, f"missing provider execution documentation invariant: {marker}"

print("Provider Execution Adapter validation: PASS")
