from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
files = {
    "contract": ROOT / "architecture/contracts/world8-engineering-entry-gateway-v0.4.yaml",
    "doc": ROOT / "docs/engineering/ENGINEERING_ENTRY_GATEWAY.md",
    "sql": ROOT / "supabase/drafts/20260828_world8_academy_entry_gateway_v04.sql",
    "model": ROOT / "services/academy/entry_gateway.py",
}
for name, path in files.items():
    if not path.exists():
        raise SystemExit(f"missing {name}: {path}")
texts = {k:p.read_text(encoding="utf-8") for k,p in files.items()}
all_text = "\n".join(texts.values())
required = [
    "world8_academy_coding_entry_receipts",
    "world8_dev_prewrite_recovery_receipts",
    "world8_dev_admission_entry_bindings",
    "world8_academy_coding_entry_issue_v1",
    "world8_dev_admission_check_v3",
    "world8_dev_acquire_lease_v5",
    "ACADEMY_ENTRY_IDEMPOTENCY_COLLISION",
    "authority_effect",
    "NONE",
    "DB_TOUCHING",
    "DB_RUNTIME_SNAPSHOT_REQUIRED",
    "TRAINING != QUALIFICATION != AUTHORITY",
    "REVOKE_DIRECT_SERVICE_ROLE_EXECUTE_ON_ADMISSION_V2_AND_LEASE_V4",
]
missing = [x for x in required if x not in all_text]
if missing:
    raise SystemExit(f"missing contract markers: {missing}")
for forbidden in ("password_value","secret_value","api_key_value","access_token_value","credential_value"):
    if re.search(rf"\b{forbidden}\b", all_text, re.I):
        raise SystemExit(f"raw secret marker forbidden: {forbidden}")
if "issued_at" not in texts["sql"] or "semantic_hash" not in texts["sql"]:
    raise SystemExit("receipt temporal/semantic fields required")
match = re.search(r"v_semantic\s*:=\s*jsonb_build_object\((.*?)\);", texts["sql"], re.S)
if not match:
    raise SystemExit("Entry semantic hash payload not found")
if "issued_at" in match.group(1):
    raise SystemExit("volatile issued_at leaked into Entry semantic hash")
legacy_revoke_markers = [
    "revoke execute on function public.world8_dev_admission_check_v2(text,text,text,text,jsonb,jsonb,integer) from service_role;",
    "revoke execute on function public.world8_dev_acquire_lease_v4(text,text,text,text,text,integer,text) from service_role;",
]
for marker in legacy_revoke_markers:
    if marker not in texts["sql"].lower():
        raise SystemExit(f"legacy service-role bypass remains: {marker}")
if "LOCAL_NON_CANONICAL_CANDIDATE" in texts["contract"] or "LOCAL NON-CANONICAL CANDIDATE" in texts["doc"]:
    raise SystemExit("promotion-unstable local-only status wording remains")
print("World 8 Academy Entry Gateway v0.4 static validation PASS")
