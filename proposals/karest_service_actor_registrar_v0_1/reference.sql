-- PROPOSAL_ONLY / NOT_APPLIED / NO_RUNTIME_MUTATION
-- Reference semantics for a future governed registrar.
-- This file is intentionally not a migration.

create or replace function world8_register_karest_advisory_service_actor_v1()
returns jsonb
language plpgsql
as $$
declare
  v_existing world8_actor_registry%rowtype;
  v_now timestamptz := clock_timestamp();
begin
  -- Stable per-identity transaction advisory lock prevents duplicate concurrent decisions.
  perform pg_advisory_xact_lock(hashtextextended('service-karest-advisory-broker-001', 0));

  select * into v_existing
  from world8_actor_registry
  where actor_id = 'service-karest-advisory-broker-001';

  if found then
    if v_existing.actor_kind <> 'SERVICE'
       or v_existing.display_name <> 'KAREST Advisory Broker'
       or v_existing.home_scope <> 'COMPANY'
       or v_existing.authority_ref is not null
       or v_existing.identity_version <> '1.0'
       or coalesce(v_existing.metadata->>'authority_effect', '') <> 'NONE'
       or coalesce((v_existing.metadata->>'consequential_effects')::boolean, true) <> false
       or coalesce((v_existing.metadata->>'provider_tools')::boolean, true) <> false
       or coalesce(v_existing.metadata->>'credential_access', '') <> 'NONE'
       or coalesce((v_existing.metadata->>'code_write')::boolean, true) <> false
       or coalesce((v_existing.metadata->>'spend')::boolean, true) <> false
    then
      raise exception 'IDENTITY_CONFLICT: protected KAREST SERVICE actor fields differ';
    end if;

    if v_existing.status <> 'ACTIVE' then
      raise exception 'ACTOR_NOT_ACTIVE: registrar cannot reactivate lifecycle state';
    end if;

    return jsonb_build_object(
      'actor_id', v_existing.actor_id,
      'disposition', 'REPLAY',
      'actor_kind', v_existing.actor_kind,
      'home_scope', v_existing.home_scope,
      'authority_ref', v_existing.authority_ref,
      'identity_version', v_existing.identity_version,
      'recorded_at', v_existing.created_at
    );
  end if;

  insert into world8_actor_registry (
    actor_id, actor_kind, display_name, home_scope, status,
    identity_version, authority_ref, metadata, created_at, updated_at
  ) values (
    'service-karest-advisory-broker-001',
    'SERVICE',
    'KAREST Advisory Broker',
    'COMPANY',
    'ACTIVE',
    '1.0',
    null,
    jsonb_build_object(
      'purpose', 'KAREST advisory broker execution attribution only',
      'authority_effect', 'NONE',
      'consequential_effects', false,
      'provider_tools', false,
      'credential_access', 'NONE',
      'code_write', false,
      'spend', false,
      'canonical_mutation_authority', false
    ),
    v_now,
    v_now
  );

  return jsonb_build_object(
    'actor_id', 'service-karest-advisory-broker-001',
    'disposition', 'RECORDED',
    'actor_kind', 'SERVICE',
    'home_scope', 'COMPANY',
    'authority_ref', null,
    'identity_version', '1.0',
    'recorded_at', v_now
  );
end;
$$;
