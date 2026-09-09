#!/usr/bin/env bash
set -euo pipefail
PSQL=(psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -X -qAt)
DIR="$(cd "$(dirname "$0")" && pwd)"

"${PSQL[@]}" <<'SQL'
create role anon noinherit;
create role authenticated noinherit;
create role service_role noinherit;
create table public.world8_actor_registry (
  actor_id text primary key,
  world_id text not null default 'world-001',
  actor_kind text not null check(actor_kind in('HUMAN','AI_MASON','AI_ARCHITECT','OBSERVER','SERVICE','SYSTEM')),
  display_name text not null,
  home_scope text not null default 'WORLD' check(home_scope in('WORLD','SHARED_CORE','COMPANY','TRADING','INFRASTRUCTURE')),
  status text not null default 'ACTIVE' check(status in('ACTIVE','SUSPENDED','RETIRED')),
  identity_version text not null default '1.0',
  authority_ref text null,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default clock_timestamp(),
  updated_at timestamptz not null default clock_timestamp()
);
create table public.world8_dev_external_resources (
  resource_id text primary key,
  world_id text not null default 'world-001',
  resource_type text not null check(resource_type in('GITHUB','GOOGLE_DRIVE','ZENODO','WEBSITE','SUPABASE','DOCUMENT','OTHER')),
  title text not null,
  uri text null,
  provider_ref text null,
  owner_scope text not null default 'WORLD',
  status text not null default 'ACTIVE',
  content_hash text null,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
SQL

"${PSQL[@]}" -f "$DIR/runtime_prereqs.sql"

# ACL: only service_role among public API principals may EXECUTE.
"${PSQL[@]}" -c "select has_function_privilege('service_role','public.world8_register_karest_advisory_service_actor_v1()','EXECUTE');" | grep -qx t
"${PSQL[@]}" -c "select has_function_privilege('anon','public.world8_register_karest_advisory_service_actor_v1()','EXECUTE');" | grep -qx f
"${PSQL[@]}" -c "select has_function_privilege('authenticated','public.world8_register_karest_advisory_service_actor_v1()','EXECUTE');" | grep -qx f
"${PSQL[@]}" -c "select has_function_privilege('service_role','public.world8_register_karest_company_runtime_resource_v1(text)','EXECUTE');" | grep -qx t
"${PSQL[@]}" -c "select has_function_privilege('anon','public.world8_register_karest_company_runtime_resource_v1(text)','EXECUTE');" | grep -qx f
"${PSQL[@]}" -c "select has_function_privilege('authenticated','public.world8_register_karest_company_runtime_resource_v1(text)','EXECUTE');" | grep -qx f

# Actor: first RECORDED, exact replay REPLAY, no authority.
actor_first=$("${PSQL[@]}" -c "select public.world8_register_karest_advisory_service_actor_v1()->>'disposition';")
[[ "$actor_first" == "RECORDED" ]]
actor_replay=$("${PSQL[@]}" -c "select public.world8_register_karest_advisory_service_actor_v1()->>'disposition';")
[[ "$actor_replay" == "REPLAY" ]]
"${PSQL[@]}" -c "select case when actor_kind='SERVICE' and home_scope='COMPANY' and authority_ref is null and metadata->>'authority_effect'='NONE' and (metadata->>'consequential_effects')::boolean=false and (metadata->>'provider_tools')::boolean=false and metadata->>'credential_access'='NONE' and (metadata->>'code_write')::boolean=false and (metadata->>'spend')::boolean=false and (metadata->>'canonical_mutation_authority')::boolean=false then 'SAFE' else 'UNSAFE' end from public.world8_actor_registry where actor_id='service-karest-advisory-broker-001';" | grep -qx SAFE

# Lifecycle replay cannot reactivate.
"${PSQL[@]}" -c "update public.world8_actor_registry set status='SUSPENDED' where actor_id='service-karest-advisory-broker-001';"
if "${PSQL[@]}" -c "select public.world8_register_karest_advisory_service_actor_v1();" >/tmp/actor.out 2>/tmp/actor.err; then exit 1; fi
grep -q ACTOR_NOT_ACTIVE /tmp/actor.err
"${PSQL[@]}" -c "select status from public.world8_actor_registry where actor_id='service-karest-advisory-broker-001';" | grep -qx SUSPENDED
"${PSQL[@]}" -c "truncate public.world8_actor_registry;"

# Concurrency: exactly one RECORDED and one REPLAY.
("${PSQL[@]}" -c "select public.world8_register_karest_advisory_service_actor_v1()->>'disposition';" >/tmp/a1.out) & p1=$!
("${PSQL[@]}" -c "select public.world8_register_karest_advisory_service_actor_v1()->>'disposition';" >/tmp/a2.out) & p2=$!
wait "$p1"; wait "$p2"
cat /tmp/a1.out /tmp/a2.out | sort > /tmp/actual_actor.txt
printf 'RECORDED\nREPLAY\n' | sort > /tmp/expected_actor.txt
diff -u /tmp/expected_actor.txt /tmp/actual_actor.txt
"${PSQL[@]}" -c "select count(*) from public.world8_actor_registry;" | grep -qx 1

# Canonical Company-runtime resource: exact head registration and replay only.
HEAD=3fc5535ef2ab8eafe3fbb227e236bd1dc6f2779e
resource_first=$("${PSQL[@]}" -c "select public.world8_register_karest_company_runtime_resource_v1('$HEAD')->>'disposition';")
[[ "$resource_first" == "RECORDED" ]]
resource_replay=$("${PSQL[@]}" -c "select public.world8_register_karest_company_runtime_resource_v1('$HEAD')->>'disposition';")
[[ "$resource_replay" == "REPLAY" ]]
"${PSQL[@]}" -c "select case when resource_type='GITHUB' and provider_ref='github:saeedfaai/Company-runtime' and owner_scope='COMPANY' and status='ACTIVE' and (metadata->>'canonical')::boolean=true and metadata->>'role'='canonical_architecture_and_code_source' and metadata->>'default_branch'='karest/auth-account-session-shell-v0-1' and metadata->>'canonical_head_commit'='$HEAD' and metadata->>'authority_effect'='NONE' and metadata->>'write_authority'='NONE' then 'SAFE' else 'UNSAFE' end from public.world8_dev_external_resources where resource_id='resource-github-karest-company-runtime-production';" | grep -qx SAFE

# Different head cannot silently mutate the protected registration.
if "${PSQL[@]}" -c "select public.world8_register_karest_company_runtime_resource_v1('aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa');" >/tmp/res.out 2>/tmp/res.err; then exit 1; fi
grep -q RESOURCE_IDENTITY_CONFLICT /tmp/res.err
"${PSQL[@]}" -c "select metadata->>'canonical_head_commit' from public.world8_dev_external_resources where resource_id='resource-github-karest-company-runtime-production';" | grep -qx "$HEAD"

# Invalid head rejected.
if "${PSQL[@]}" -c "select public.world8_register_karest_company_runtime_resource_v1('not-a-sha');" >/tmp/invalid.out 2>/tmp/invalid.err; then exit 1; fi
grep -q KAREST_CANONICAL_HEAD_INVALID /tmp/invalid.err

echo KAREST_RUNTIME_PREREQ_HARDENING_POSTGRES_PASS
