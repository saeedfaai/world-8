-- World 8 Address Mesh v0.1 — Mason / Guardian integration wrappers
-- STATUS: DRAFT ONLY / NOT APPLIED / NOT EVIDENCED
-- Depends on:
--   * existing world8_mason_preflight_v1
--   * existing world8_guardian_pre_action_v1
--   * world8_address_context_resolve_v1
--   * address_context_snapshot column draft
--
-- v1 behavior remains the baseline. Address Mesh may add context, never remove a v1 blocker
-- or grant authority. If address resolution fails, wrapper returns fail-closed diagnostic metadata
-- and preserves the v1 decision.

create or replace function public.world8_mason_preflight_v2(
  p_actor_ref text,
  p_source_room text,
  p_intent_summary text,
  p_target_artifact_ids jsonb default '[]'::jsonb,
  p_environment_ref jsonb default '{}'::jsonb,
  p_valid_minutes integer default 120
) returns jsonb
language plpgsql security definer set search_path=public as $$
declare
  v_base jsonb;
  v_context jsonb:='{}'::jsonb;
  v_context_error text:=null;
  v_receipt_id text;
begin
  v_base:=public.world8_mason_preflight_v1(
    p_actor_ref,p_source_room,p_intent_summary,p_target_artifact_ids,p_environment_ref,p_valid_minutes
  );
  v_receipt_id:=v_base->>'preflight_receipt_id';

  begin
    v_context:=public.world8_address_context_resolve_v1(p_actor_ref,p_environment_ref,100);
  exception when others then
    v_context_error:=sqlerrm;
    v_context:=jsonb_build_object(
      'schema','WORLD8_ADDRESS_CONTEXT/1.0',
      'status','UNAVAILABLE_FAIL_CLOSED',
      'error_code','ADDRESS_CONTEXT_RESOLUTION_FAILED',
      'authority_effect','NONE'
    );
  end;

  if coalesce(v_receipt_id,'')<>'' then
    update public.world8_mason_preflight_receipts
    set address_context_snapshot=v_context
    where preflight_receipt_id=v_receipt_id;
  end if;

  return v_base || jsonb_build_object(
    'address_context',v_context,
    'address_context_error',v_context_error,
    'address_context_authority_effect','NONE'
  );
end $$;

create or replace function public.world8_guardian_pre_action_v2(
  p_dev_session_id text,
  p_action_kind text,
  p_target_ref text,
  p_target_artifact_id text,
  p_safe_summary text,
  p_environment_ref jsonb default '{}'::jsonb
) returns jsonb
language plpgsql security definer set search_path=public as $$
declare
  v_base jsonb;
  v_session public.world8_dev_session_liveness%rowtype;
  v_env jsonb:=coalesce(p_environment_ref,'{}'::jsonb);
  v_context jsonb:='{}'::jsonb;
  v_context_error text:=null;
begin
  select * into v_session
  from public.world8_dev_session_liveness
  where session_id=p_dev_session_id and status='ACTIVE';
  if not found then raise exception 'ACTIVE_DEV_SESSION_NOT_FOUND'; end if;

  -- Preserve exact v1 advisory/guard behavior first.
  v_base:=public.world8_guardian_pre_action_v1(
    p_dev_session_id,p_action_kind,p_target_ref,p_target_artifact_id,p_safe_summary
  );

  -- Enrich explicit address environment without guessing authority.
  v_env:=v_env || jsonb_build_object(
    'component_ref',coalesce(p_target_ref,''),
    'target_artifact_id',coalesce(p_target_artifact_id,''),
    'action_kind',coalesce(p_action_kind,''),
    'address_tags',coalesce(v_env->'address_tags','[]'::jsonb)
  );

  begin
    v_context:=public.world8_address_context_resolve_v1(v_session.actor_id,v_env,100);
  exception when others then
    v_context_error:=sqlerrm;
    v_context:=jsonb_build_object(
      'schema','WORLD8_ADDRESS_CONTEXT/1.0',
      'status','UNAVAILABLE_FAIL_CLOSED',
      'error_code','ADDRESS_CONTEXT_RESOLUTION_FAILED',
      'authority_effect','NONE'
    );
  end;

  return v_base || jsonb_build_object(
    'address_context',v_context,
    'address_context_error',v_context_error,
    'address_context_authority_effect','NONE'
  );
end $$;

-- Integration requirement:
-- New Mason clients SHOULD call world8_mason_preflight_v2 once deployed.
-- New Guardian clients SHOULD call world8_guardian_pre_action_v2 once deployed.
-- v1 stays available for rollback compatibility until v2 evidence gates pass.
-- No caller may treat absence of Address Mesh context as permission to proceed.
