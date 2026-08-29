-- World 8 repo-aware Academy bridge v0.5 ACL hardening
-- Follow-up to runtime conformance finding: bridge evidence tables must not be directly writable
-- by public API roles or service_role. Writes occur only through reviewed SECURITY DEFINER entry points.

alter table public.world8_dev_workspace_git_bindings enable row level security;
alter table public.world8_academy_entry_git_bindings enable row level security;

revoke all on table public.world8_dev_workspace_git_bindings
from public, anon, authenticated, service_role;

revoke all on table public.world8_academy_entry_git_bindings
from public, anon, authenticated, service_role;

select jsonb_build_object(
  'result','WORLD8_REPO_AWARE_ACADEMY_BRIDGE_V05_ACL_HARDENING_LOADED',
  'direct_service_role_table_write',false,
  'rls_enabled',true,
  'resource_enrollment_performed',false
) as bridge_v05_acl_hardening_marker;
