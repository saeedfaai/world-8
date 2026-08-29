from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
SQL = ROOT / "supabase/drafts/20260829_world8_repo_aware_academy_bridge_v05.sql"
CONTRACT = ROOT / "architecture/contracts/world8-engineering-repo-aware-git-v0.5.yaml"
DOC = ROOT / "docs/engineering/WORLD9_REPO_AWARE_ACADEMY_BRIDGE.md"

for path in (SQL, CONTRACT, DOC):
    if not path.exists():
        raise SystemExit(f"missing bridge artifact: {path}")

sql = SQL.read_text(encoding="utf-8")
contract = CONTRACT.read_text(encoding="utf-8")
doc = DOC.read_text(encoding="utf-8")
all_text = "\n".join((sql, contract, doc))

required = [
    "world8_dev_workspace_git_bindings",
    "world8_academy_entry_git_bindings",
    "world8_dev_canonical_git_resource_current_v1",
    "world8_dev_register_workspace_v2",
    "world8_academy_coding_entry_issue_v2",
    "world8_dev_admission_check_v4",
    "world8_dev_acquire_lease_v5",
    "canonical_architecture_and_code_source",
    "canonical_head_commit",
    "CANONICAL_BRANCH_WRITE_FORBIDDEN",
    "STALE_CANONICAL_RESOURCE_BINDING",
    "ACADEMY_ENTRY_AUTHORITY_EFFECT_FORBIDDEN",
    "world8_authorize_v1",
    "canonical_resource_id",
    "authority_effect",
    "NONE",
]
missing = [marker for marker in required if marker not in all_text]
if missing:
    raise SystemExit(f"missing repo-aware bridge markers: {missing}")

# The additive bridge must not replace the legacy World8-only public path.
for legacy in (
    "create or replace function public.world8_dev_register_workspace_v1",
    "create or replace function public.world8_academy_coding_entry_issue_v1",
    "create or replace function public.world8_dev_admission_check_v2",
    "create or replace function public.world8_dev_admission_check_v3",
    "create or replace function public.world8_dev_acquire_lease_v5",
):
    if legacy in sql.lower():
        raise SystemExit(f"legacy function replacement forbidden in additive v0.5: {legacy}")

# Resource enrollment belongs to a separate governed action.
if re.search(r"insert\s+into\s+(?:public\.)?world8_dev_external_resources", sql, re.I):
    raise SystemExit("v0.5 migration must not enroll an external repository")

# Migration source must be deployable; transaction rollback belongs in the test harness, not the migration.
if re.search(r"\brollback\s*;", sql, re.I):
    raise SystemExit("migration source contains rollback wrapper")

# Exact repo/head/currentness markers must exist in executable SQL.
for expression in (
    "r.resource_type<>'GITHUB'",
    "metadata->>'canonical'",
    "metadata->>'role'",
    "provider_ref",
    "canonical_head",
    "default_branch",
    "NON_CANONICAL_REPO_FOR_RESOURCE",
    "STALE_CANONICAL_RESOURCE_BASE",
    "WORKSPACE_GIT_BINDING_IDEMPOTENCY_COLLISION",
    "ACADEMY_ENTRY_CANONICAL_RESOURCE_BINDING_REQUIRED",
    "ENTRY_WORKSPACE_GIT_BINDING_MISMATCH",
):
    if expression not in sql:
        raise SystemExit(f"missing fail-closed SQL marker: {expression}")

# Workspace/Entry bindings must be immutable evidence.
if sql.count("world8_academy_evidence_append_only_v1") < 2:
    raise SystemExit("append-only triggers missing for Git binding evidence")

# Entry v2 must remain zero-authority and Admission v4 must preserve Authority Fabric separation.
entry_match = re.search(
    r"create or replace function public\.world8_academy_coding_entry_issue_v2\(.*?\nend\$\$;",
    sql,
    re.S | re.I,
)
if not entry_match or "'authority_effect','NONE'" not in entry_match.group(0):
    raise SystemExit("Entry v2 authority_effect NONE not proven")
if "world8_dev_assignment_check_v1" not in sql or "world8_authorize_v1" not in sql:
    raise SystemExit("Admission v4 must preserve qualification/authorization separation")

# No raw secret material or provider execution primitive may be introduced.
for forbidden in (
    "password_value",
    "secret_value",
    "api_key_value",
    "access_token_value",
    "credential_value",
    "provider_execute(",
):
    if re.search(rf"\b{re.escape(forbidden)}", all_text, re.I):
        raise SystemExit(f"forbidden secret/effect marker: {forbidden}")

print("World 8 repo-aware Academy bridge v0.5 static validation PASS")
