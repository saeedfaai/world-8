from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
POOL = ROOT / "supabase/migrations/20260827114000_world8_n_mason_pool_v01.sql"
MERGE = ROOT / "supabase/migrations/20260827114300_world8_n_mason_merge_queue_v01.sql"
DOC = ROOT / "docs/engineering/N_MASON_POOL.md"
WORKFLOW = ROOT / ".github/workflows/validate-architecture.yml"

for path in (POOL, MERGE, DOC, WORKFLOW):
    assert path.exists(), f"required file missing: {path.relative_to(ROOT)}"

pool = POOL.read_text(encoding="utf-8")
merge = MERGE.read_text(encoding="utf-8")
doc = DOC.read_text(encoding="utf-8")
workflow = WORKFLOW.read_text(encoding="utf-8")
combined = "\n".join((pool, merge, doc)).lower()

required_pool_markers = [
    "world8_mason_pools",
    "world8_mason_pool_members",
    "world8_mason_assignments",
    "world8_actor_registry",
    "world8_actor_executions",
    "identity_provider_independent",
    "for update skip locked",
    "world8_actor_qualifications",
    "pool_capacity_or_qualification_exhausted",
    "canonical_branch_write_forbidden",
    "world8_mason_pool_bind_execution_v1",
    "world8_mason_pool_bind_workspace_v1",
]
for marker in required_pool_markers:
    assert marker in pool.lower(), f"pool invariant marker missing: {marker}"

required_merge_markers = [
    "world8_merge_queue",
    "world8_merge_receipts",
    "world8_prevent_merge_receipt_mutation_v1",
    "world8_merge_receipts_append_only_trg",
    "pg_advisory_xact_lock",
    "world8:canonical-merge",
    "github_branch_protection_required",
    "stale_rebase_required",
    "ci_state='pass'",
    "canonical_branch_write_forbidden",
]
for marker in required_merge_markers:
    assert marker in merge.lower(), f"merge invariant marker missing: {marker}"

for forbidden in (
    "raw_secret",
    "password_value",
    "token_value",
    "credential_value",
    "api_key_value",
    "private_key_value",
):
    assert forbidden not in combined, f"secret-storage field forbidden: {forbidden}"

assert "provider belongs to execution, not actor" in doc.lower()
assert "pilot reservations, not an architectural limit" in doc.lower()
assert "grok lane remains reserved" in doc.lower()
assert "github branch-protection hard gate" in doc.lower()
assert "python scripts/validate_n_mason_pool.py" in workflow

print("N-Mason Pool static validation: PASS")
