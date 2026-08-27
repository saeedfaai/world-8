from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
migration = ROOT / "supabase" / "migrations" / "202608271004_world8_developer_admission_workspace_v01.sql"
doc = ROOT / "docs" / "engineering" / "DEVELOPER_ADMISSION.md"
start = ROOT / "START_HERE.md"
catalog = ROOT / "catalog" / "components.yaml"

for path in (migration, doc, start, catalog):
    if not path.exists():
        raise SystemExit(f"Missing required Developer Admission file: {path.relative_to(ROOT)}")

sql = migration.read_text(encoding="utf-8")
required_sql = [
    "world8_dev_workspaces",
    "world8_dev_admission_receipts",
    "world8_dev_register_workspace_v1",
    "world8_dev_admission_check_v1",
    "world8_dev_create_work_claim_v3",
    "CANONICAL_BRANCH_WRITE_FORBIDDEN",
    "STALE_CANONICAL_BASE",
    "AUTHORIZATION_VERIFIER_NOT_IMPLEMENTED",
]
missing = [x for x in required_sql if x not in sql]
if missing:
    raise SystemExit(f"Developer Admission migration missing required markers: {missing}")

# We permit words such as 'credentials' in policy comments/docs, but never schema fields
# that store raw secret material.
for forbidden in ("password_value", "secret_value", "api_key_value", "access_token_value", "credential_value"):
    if re.search(rf"\b{re.escape(forbidden)}\b", sql, re.IGNORECASE):
        raise SystemExit(f"Forbidden raw secret storage marker found: {forbidden}")

if "world8.developer-admission" not in catalog.read_text(encoding="utf-8"):
    raise SystemExit("Component catalog missing world8.developer-admission")
if "Qualification != Authorization" not in doc.read_text(encoding="utf-8"):
    raise SystemExit("Admission doc must preserve Qualification != Authorization")
if "isolated workspace" not in start.read_text(encoding="utf-8"):
    raise SystemExit("START_HERE must require isolated workspace for code writes")

print("World 8 Developer Admission static validation PASS")
