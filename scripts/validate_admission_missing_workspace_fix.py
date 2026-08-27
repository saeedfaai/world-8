from pathlib import Path

MIGRATION = Path('supabase/migrations/20260827193000_world8_admission_missing_workspace_receipt_fix_v021.sql')


def require(text: str, needle: str) -> None:
    if needle not in text:
        raise SystemExit(f'MISSING_REQUIRED_PATTERN: {needle}')


def forbid(text: str, needle: str) -> None:
    if needle in text:
        raise SystemExit(f'FORBIDDEN_PATTERN_PRESENT: {needle}')


def main() -> None:
    text = MIGRATION.read_text(encoding='utf-8')

    require(text, "v_receipt_workspace_id text:=null")
    require(text, "v_receipt_workspace_id:=null")
    require(text, "v_receipt_workspace_id:=v_ws.workspace_id")
    require(text, "'requested_workspace_id',p_workspace_id")
    require(text, "'resolved_workspace_id',v_receipt_workspace_id")
    require(text, "p_work_id,v_receipt_workspace_id")
    require(text, "'workspace-request:'||coalesce(p_workspace_id,'')")
    require(text, "'workspace-resolved:'||coalesce(v_receipt_workspace_id,'none')")
    require(text, "'schema','WORLD8_DEV_ADMISSION/0.2.1'")

    # Regression guard: the receipt INSERT must not blindly write the requested
    # workspace id into the FK slot after an ACTIVE-workspace lookup has failed.
    forbid(text, "p_work_id,p_workspace_id,\n   coalesce(p_required_qualifications")

    print('PASS: unresolved workspace is preserved as requested evidence while the receipt FK uses only the resolved ACTIVE workspace id.')


if __name__ == '__main__':
    main()
