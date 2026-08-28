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
]
missing = [x for x in required if x not in all_text]
if missing:
    raise SystemExit(f"missing contract markers: {missing}")
for forbidden in ("password_value","secret_value","api_key_value","access_token_value","credential_value"):
    if re.search(rf"\b{forbidden}\b", all_text, re.I):
        raise SystemExit(f"raw secret marker forbidden: {forbidden}")
if "issued_at" not in texts["sql"] or "semantic_hash" not in texts["sql"]:
    raise SystemExit("receipt temporal/semantic fields required")
if "issued_at" in re.search(r"v_semantic\s*:=\s*jsonb_build_object\((.*?)\);", texts["sql"], re.S).group(1):
    raise SystemExit("volatile issued_at leaked into Entry semantic hash")
print("World 8 Academy Entry Gateway v0.4 static validation PASS")
