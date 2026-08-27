#!/usr/bin/env python3
"""Static fail-closed checks for World 8 Identity & Authority migrations."""
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
MIGRATIONS = ROOT / "supabase" / "migrations"

files = sorted(MIGRATIONS.glob("*world8_identity_authority_verifier*.sql"))
if not files:
    raise SystemExit("IDENTITY_AUTHORITY_MIGRATION_MISSING")

sql = "\n".join(p.read_text(encoding="utf-8") for p in files)

required = {
    "authority_rule_ledger": "world8_authority_rules",
    "authorization_receipts": "world8_authorization_receipts",
    "unified_verifier": "world8_authorize_v1",
    "admission_v2": "world8_dev_admission_check_v2",
    "lease_v3": "world8_dev_acquire_lease_v3",
    "default_deny": "NO_MATCHING_AUTHORITY_RULE",
    "explicit_deny": "EXPLICIT_DENY_OR_REVOKE",
    "append_only": "WORLD8_AUTHORITY_LEDGER_APPEND_ONLY",
    "bypass_closed": "AUTHORIZATION_BYPASS_CLOSED_USE_ADMISSION_V2_AND_LEASE_V3",
    "condition_match": "coalesce(p_conditions,'{}'::jsonb) @> r.conditions",
    "route_non_terminal": "v_route_allow boolean",
    "receipt_v11": "WORLD8_AUTHORIZATION_RECEIPT/1.1",
    "hash_access_identity": "'require_access_identity',p_require_access_identity",
    "hash_assurance": "'required_assurance',p_required_assurance",
    "w0_evidence": "require_world_boot_approved",
    "w1_evidence": "require_world_running_approved",
    "w2_evidence": "w2_authorization_id",
    "owner_step_up": "owner_step_up_scope",
}

missing = [name for name, marker in required.items() if marker not in sql]
if missing:
    print("Identity/Authority validation FAILED. Missing:", ", ".join(missing))
    sys.exit(1)

# Guard against re-introducing the permissive v0.1 condition matcher as the final repair.
repair_files = [p for p in files if "v011" in p.name]
if not repair_files:
    raise SystemExit("IDENTITY_AUTHORITY_V011_REPAIR_MISSING")
repair_sql = "\n".join(p.read_text(encoding="utf-8") for p in repair_files)
for marker in (
    "coalesce(p_conditions,'{}'::jsonb) @> r.conditions",
    "v_route_allow boolean",
    "'require_access_identity',p_require_access_identity",
    "'required_assurance',p_required_assurance",
):
    if marker not in repair_sql:
        raise SystemExit(f"IDENTITY_AUTHORITY_SECURITY_REPAIR_MISSING:{marker}")

print(f"Identity/Authority validation PASS ({len(files)} migration files)")
