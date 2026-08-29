-- World8 Governance Protection fallback v1
-- Native GitHub branch protection remains preferred. This fallback is only
-- eligible for private canonical resources where native protection is unavailable.

create or replace function public.world8_merge_protection_gate_v1(
  p_pool_id text,
  p_canonical_resource_id text,
  p_validation_check_id text default null,
  p_head_commit text default null
) returns jsonb
language plpgsql security definer
set search_path to 'public'
as $$
declare
  v_pool public.world8_mason_pools%rowtype;
  v_res public.world8_dev_external_resources%rowtype;
  v_check public.world8_operational_checks%rowtype;
  v_native text;
  v_fallback boolean:=false;
begin
  select * into v_pool from public.world8_mason_pools where pool_id=p_pool_id and status='ACTIVE';
  if not found then return jsonb_build_object('gate_state','BLOCKED','reason_code','ACTIVE_MASON_POOL_REQUIRED'); end if;
  select * into v_res from public.world8_dev_external_resources where resource_id=p_canonical_resource_id and status='ACTIVE';
  if not found then return jsonb_build_object('gate_state','BLOCKED','reason_code','ACTIVE_CANONICAL_RESOURCE_REQUIRED'); end if;
  v_native:=coalesce(v_res.metadata->>'branch_protection','UNCONFIGURED');
  if not v_pool.branch_protection_required then return jsonb_build_object('gate_state','PASS','protection_mode','POOL_NOT_REQUIRED'); end if;
  if v_native in ('ENFORCED','RULESET_ENFORCED','PROTECTED') then return jsonb_build_object('gate_state','PASS','protection_mode','GITHUB_NATIVE'); end if;

  v_fallback := coalesce(v_res.metadata->>'visibility','')='private'
    and coalesce((v_res.metadata->>'branch_protection_limitation_acknowledged')::boolean,false)
    and coalesce((v_res.metadata->>'no_world9_git_write')::boolean,false);
  if not v_fallback then return jsonb_build_object('gate_state','BLOCKED','reason_code','GITHUB_BRANCH_PROTECTION_REQUIRED'); end if;
  if coalesce(p_validation_check_id,'')='' or coalesce(p_head_commit,'')='' then
    return jsonb_build_object('gate_state','BLOCKED','reason_code','GOVERNANCE_PROTECTION_EXACT_HEAD_VALIDATION_REQUIRED');
  end if;
  select * into v_check from public.world8_operational_checks where check_id=p_validation_check_id;
  if not found or v_check.status<>'PASS'
     or coalesce(v_check.metadata->>'head_commit','')<>p_head_commit
     or coalesce(v_check.metadata->>'repo_ref','')<>coalesce(v_res.metadata->>'repo_ref',replace(v_res.provider_ref,'github:','')) then
    return jsonb_build_object('gate_state','BLOCKED','reason_code','GOVERNANCE_PROTECTION_VALIDATION_MISMATCH');
  end if;
  if coalesce(v_check.metadata->>'failure_class','')<>'INFRASTRUCTURE_PRE_STEP'
     or coalesce((v_check.metadata->>'github_actions_runner_assigned')::boolean,true) then
    return jsonb_build_object('gate_state','BLOCKED','reason_code','EXTERNAL_VALIDATION_SUBSTITUTION_NOT_ELIGIBLE');
  end if;
  return jsonb_build_object('gate_state','PASS','protection_mode','WORLD8_GOVERNED_PRIVATE_REPO_FALLBACK','validation_check_id',p_validation_check_id,'head_commit',p_head_commit);
end$$;
