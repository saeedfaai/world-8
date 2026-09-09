-- REVIEW CANDIDATE / NOT YET APPLIED TO WORLD 8 RUNTIME
-- Exact KAREST runtime prerequisite registrars.
-- No provider invocation, no secret movement, no business/effect authority.

create or replace function public.world8_register_karest_advisory_service_actor_v1()
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_existing public.world8_actor_registry%rowtype;
  v_now timestamptz := clock_timestamp();
begin
  perform pg_advisory_xact_lock(hashtextextended('service-karest-advisory-broker-001', 0));

  select * into v_existing
  from public.world8_actor_registry
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
       or coalesce((v_existing.metadata->>'canonical_mutation_authority')::boolean, true) <> false
    then
      raise exception 'IDENTITY_CONFLICT: protected KAREST SERVICE actor fields differ';
    end if;

    if v_existing.status <> 'ACTIVE' then
      raise exception 'ACTOR_NOT_ACTIVE: registrar cannot reactivate lifecycle state';
    end if;

    return jsonb_build_object(
      'schema', 'WORLD8_KAREST_SERVICE_ACTOR_REGISTRATION/1.0',
      'actor_id', v_existing.actor_id,
      'disposition', 'REPLAY',
      'actor_kind', v_existing.actor_kind,
      'home_scope', v_existing.home_scope,
      'authority_ref', v_existing.authority_ref,
      'identity_version', v_existing.identity_version,
      'recorded_at', v_existing.created_at,
      'authorization_granted', false
    );
  end if;

  insert into public.world8_actor_registry (
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
      'service_kind', 'KAREST_ADVISORY_BROKER',
      'authority_effect', 'NONE',
      'runtime_authority_effect', 'NONE',
      'consequential_effects', false,
      'provider_tools', false,
      'credential_access', 'NONE',
      'code_write', false,
      'spend', false,
      'canonical_mutation_authority', false,
      'advisory_only', true
    ),
    v_now,
    v_now
  );

  return jsonb_build_object(
    'schema', 'WORLD8_KAREST_SERVICE_ACTOR_REGISTRATION/1.0',
    'actor_id', 'service-karest-advisory-broker-001',
    'disposition', 'RECORDED',
    'actor_kind', 'SERVICE',
    'home_scope', 'COMPANY',
    'authority_ref', null,
    'identity_version', '1.0',
    'recorded_at', v_now,
    'authorization_granted', false
  );
end;
$$;

revoke all on function public.world8_register_karest_advisory_service_actor_v1() from public;
revoke all on function public.world8_register_karest_advisory_service_actor_v1() from anon;
revoke all on function public.world8_register_karest_advisory_service_actor_v1() from authenticated;
grant execute on function public.world8_register_karest_advisory_service_actor_v1() to service_role;

create or replace function public.world8_register_karest_company_runtime_resource_v1(p_canonical_head text)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_existing public.world8_dev_external_resources%rowtype;
  v_now timestamptz := clock_timestamp();
  v_resource_id constant text := 'resource-github-karest-company-runtime-production';
  v_provider_ref constant text := 'github:saeedfaai/Company-runtime';
  v_canonical_branch constant text := 'karest/auth-account-session-shell-v0-1';
begin
  if p_canonical_head is null or p_canonical_head !~ '^[0-9a-f]{40}$' then
    raise exception 'KAREST_CANONICAL_HEAD_INVALID';
  end if;

  perform pg_advisory_xact_lock(hashtextextended(v_resource_id, 0));

  select * into v_existing
  from public.world8_dev_external_resources
  where resource_id = v_resource_id;

  if found then
    if v_existing.resource_type <> 'GITHUB'
       or v_existing.provider_ref <> v_provider_ref
       or v_existing.owner_scope <> 'COMPANY'
       or coalesce((v_existing.metadata->>'canonical')::boolean, false) <> true
       or coalesce(v_existing.metadata->>'role', '') <> 'canonical_architecture_and_code_source'
       or coalesce(v_existing.metadata->>'default_branch', '') <> v_canonical_branch
       or coalesce(v_existing.metadata->>'canonical_head_commit', '') <> p_canonical_head
       or coalesce(v_existing.metadata->>'authority_effect', '') <> 'NONE'
       or coalesce(v_existing.metadata->>'write_authority', '') <> 'NONE'
    then
      raise exception 'RESOURCE_IDENTITY_CONFLICT: protected KAREST canonical resource fields differ';
    end if;

    if v_existing.status <> 'ACTIVE' then
      raise exception 'RESOURCE_NOT_ACTIVE: registrar cannot reactivate lifecycle state';
    end if;

    return jsonb_build_object(
      'schema', 'WORLD8_KAREST_CANONICAL_RESOURCE_REGISTRATION/1.0',
      'resource_id', v_existing.resource_id,
      'provider_ref', v_existing.provider_ref,
      'canonical_branch', v_canonical_branch,
      'canonical_head', p_canonical_head,
      'disposition', 'REPLAY',
      'authorization_granted', false
    );
  end if;

  insert into public.world8_dev_external_resources (
    resource_id, world_id, resource_type, title, uri, provider_ref,
    owner_scope, status, content_hash, metadata, created_at, updated_at
  ) values (
    v_resource_id,
    'world-001',
    'GITHUB',
    'KAREST Company-runtime Production Canonical Resource',
    'https://github.com/saeedfaai/Company-runtime',
    v_provider_ref,
    'COMPANY',
    'ACTIVE',
    null,
    jsonb_build_object(
      'canonical', true,
      'role', 'canonical_architecture_and_code_source',
      'visibility', 'private',
      'default_branch', v_canonical_branch,
      'repo_default_branch', 'main',
      'canonical_branch_ref', v_canonical_branch,
      'canonical_head_commit', p_canonical_head,
      'head_observed_at', v_now,
      'enrollment_reason', 'KAREST advisory broker READ_ONLY workspace prerequisite',
      'authority_effect', 'NONE',
      'write_authority', 'NONE',
      'no_world8_git_write', true
    ),
    v_now,
    v_now
  );

  return jsonb_build_object(
    'schema', 'WORLD8_KAREST_CANONICAL_RESOURCE_REGISTRATION/1.0',
    'resource_id', v_resource_id,
    'provider_ref', v_provider_ref,
    'canonical_branch', v_canonical_branch,
    'canonical_head', p_canonical_head,
    'disposition', 'RECORDED',
    'authorization_granted', false
  );
end;
$$;

revoke all on function public.world8_register_karest_company_runtime_resource_v1(text) from public;
revoke all on function public.world8_register_karest_company_runtime_resource_v1(text) from anon;
revoke all on function public.world8_register_karest_company_runtime_resource_v1(text) from authenticated;
grant execute on function public.world8_register_karest_company_runtime_resource_v1(text) to service_role;
