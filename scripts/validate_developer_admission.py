from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
base_migration = ROOT / "supabase" / "migrations" / "202608271004_world8_developer_admission_workspace_v01.sql"
fix_migration = ROOT / "supabase" / "migrations" / "202608271016_world8_developer_admission_order_fix_v011.sql"
doc = ROOT / "docs" / "engineering" / "DEVELOPER_ADMISSION.md"
start = ROOT / "START_HERE.md"
catalog = ROOT / "catalog" / "components.yaml"

for path in (base_migration, fix_migration, doc, start, catalog):
    if not path.exists():
        raise SystemExit(f"Missing required Developer Admission file: {path.relative_to(ROOT)}")

base_sql = base_migration.read_text(encoding="utf-8")
fix_sql = fix_migration.read_text(encoding="utf-8")
all_sql = base_sql + "\n" + fix_sql

required = [
    "world8_dev_workspaces",
    "world8_dev_admission_receipts",
    "world8_dev_register_workspace_v1",
    "world8_dev_admission_check_v1",
    "world8_dev_acquire_lease_v2",
    "CANONICAL_BRANCH_WRITE_FORBIDDEN",
    "STALE_CANONICAL_BASE",
    "AUTHORIZATION_VERIFIER_NOT_IMPLEMENTED",
    "ADMISSION_WORK_MISMATCH",
    "WRITE_AUTHORIZATION_EVIDENCE_REQUIRED",
    "DEPRECATED_USE_WORK_CLAIM_V2_THEN_ADMISSION_THEN_LEASE_V2",
]
missing = [x for x in required if x not in all_sql]
if missing:
    raise SystemExit(f"Developer Admission migration set missing required markers: {missing}")

for forbidden in ("password_value", "secret_value", "api_key_value", "access_token_value", "credential_value"):
    if re.search(rf"\b{re.escape(forbidden)}\b", all_sql, re.IGNORECASE):
        raise SystemExit(f"Forbidden raw secret storage marker found: {forbidden}")

catalog_text = catalog.read_text(encoding="utf-8")
doc_text = doc.read_text(encoding="utf-8")
start_text = start.read_text(encoding="utf-8")

if "world8.developer-admission" not in catalog_text:
    raise SystemExit("Component catalog missing world8.developer-admission")
if "Qualification != Authorization" not in doc_text:
    raise SystemExit("Admission doc must preserve Qualification != Authorization")
if "Work Claim -> isolated Workspace -> Qualification -> Authorization -> Admission Receipt -> Lease" not in doc_text:
    raise SystemExit("Admission doc must encode Work-before-Admission-before-Lease ordering")
if "Create/claim the governed Work Item" not in start_text:
    raise SystemExit("START_HERE must claim Work before workspace/admission")
if "Only after Admission may a write Lease be issued" not in start_text:
    raise SystemExit("START_HERE must gate write Lease after Admission")

print("World 8 Developer Admission static validation PASS")
