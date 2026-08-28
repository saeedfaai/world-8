#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
AUTH = ROOT / "supabase/migrations/202608280426_world8_authority_rule_issuer_v01.sql"
DIAG = ROOT / "supabase/migrations/202608280427_world8_diag_search_v21.sql"
UI = ROOT / "web/authority-approval/index.html"

required = {
    AUTH: [
        "world8_authority_rule_request_v1",
        "world8_human_root_session_context(true)",
        "world8_authority_rule_ceremony_v1",
        "world8_authority_rule_issue_v1",
        "req.issue_expires_at",
        "world8_authority_rule_revoke_closed_work_v1",
        "WORKSPACE_MUST_BE_RELEASED_BEFORE_AUTHORITY_REVOKE",
    ],
    DIAG: [
        "WORLD8_DIAG_SEARCH/2.1",
        "TOKEN_ALL",
        "TEST_CONTRACT",
        "regexp_split_to_table",
    ],
    UI: [
        "world8_authority_rule_pending_v1",
        "world8_authority_rule_get_v1",
        "world8_authority_rule_ceremony_v1",
        "mfa.verify",
        "AAL2",
    ],
}

for path, markers in required.items():
    if not path.exists():
        raise SystemExit(f"MISSING:{path.relative_to(ROOT)}")
    text = path.read_text(encoding="utf-8")
    for marker in markers:
        if marker not in text:
            raise SystemExit(f"MISSING_MARKER:{path.relative_to(ROOT)}:{marker}")

# Browser-facing UI must be static source; direct HTML Edge UI links are not canonical delivery.
ui = UI.read_text(encoding="utf-8")
if "/functions/v1/world8-authority-approval" in ui:
    raise SystemExit("DIRECT_EDGE_UI_FORBIDDEN")
if "service_role" in ui.lower():
    raise SystemExit("SERVICE_ROLE_MUST_NOT_APPEAR_IN_BROWSER_UI")

print("AUTHORITY_RULE_ISSUER_VALIDATION_PASS")
