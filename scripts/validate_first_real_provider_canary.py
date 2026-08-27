from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
WORKER = ROOT / "supabase/functions/world8-provider-worker-canary-v01/index.ts"
DOC = ROOT / "docs/engineering/FIRST_REAL_PROVIDER_CANARY.md"
MIGRATIONS = list((ROOT / "supabase/migrations").glob("*.sql"))

assert WORKER.exists(), "canary worker source missing"
assert DOC.exists(), "canary documentation missing"

worker = WORKER.read_text(encoding="utf-8")
doc = DOC.read_text(encoding="utf-8")
sql = "\n".join(p.read_text(encoding="utf-8") for p in MIGRATIONS)

required_worker = [
    'WORLD8_PROVIDER_WORKER_HEALTH/1.2',
    'credential_env_present',
    'provider_task_execution_enabled',
    'governed_queued_request_only',
    'world8_provider_execution_worker_claim_v1',
    'world8_provider_execution_output_record_v1',
    'world8_provider_execution_complete_v2',
    'world8_provider_execution_fail_v1',
    'https://api.openai.com/v1/responses',
    'raw_secret_returned: false',
    'private_reasoning_present: false',
]
for marker in required_worker:
    assert marker in worker, f"missing canary worker invariant: {marker}"

required_sql = [
    'world8_provider_worker_challenge_dispatch_v1',
    'world8_provider_credential_probe_dispatch_v1',
    'world8_provider_execution_output_record_v1',
    "v_a.state not in ('WORK_BOUND','CODING','EXECUTING')",
    'CODING_ASSIGNMENT_WORKSPACE_REQUIRED',
]
for marker in required_sql:
    assert marker in sql, f"missing canary SQL invariant: {marker}"

required_doc = [
    'LIVE_READY',
    'REAL_PROVIDER_REACHED',
    'CANARY_FAILED_OPENAI_429',
    'provider_invoked=true',
    'No raw provider secret',
    'No private chain-of-thought storage',
    'No scale-out before one real canary is `SUCCEEDED` with evidence.',
]
for marker in required_doc:
    assert marker in doc, f"missing canary evidence marker: {marker}"

# No secret values or private reasoning should ever be committed.
for forbidden in ['sk-proj-', 'sk-live-', 'BEGIN PRIVATE KEY', 'chain_of_thought":']:
    assert forbidden not in worker + doc + sql, f"forbidden sensitive material marker: {forbidden}"

print("First Real Provider Canary validation: PASS")
