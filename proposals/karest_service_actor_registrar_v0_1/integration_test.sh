#!/usr/bin/env bash
set -euo pipefail

PSQL=(psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -X -qAt)
SQL_DIR="$(cd "$(dirname "$0")" && pwd)"

"${PSQL[@]}" <<'SQL'
create table world8_actor_registry (
  actor_id text primary key,
  world_id text not null default 'world-001',
  actor_kind text not null,
  display_name text not null,
  home_scope text not null default 'WORLD',
  status text not null default 'ACTIVE',
  identity_version text not null default '1.0',
  authority_ref text null,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default clock_timestamp(),
  updated_at timestamptz not null default clock_timestamp()
);
SQL

"${PSQL[@]}" -f "$SQL_DIR/reference.sql"

first=$("${PSQL[@]}" -c "select world8_register_karest_advisory_service_actor_v1()->>'disposition';")
[[ "$first" == "RECORDED" ]]
second=$("${PSQL[@]}" -c "select world8_register_karest_advisory_service_actor_v1()->>'disposition';")
[[ "$second" == "REPLAY" ]]
count=$("${PSQL[@]}" -c "select count(*) from world8_actor_registry where actor_id='service-karest-advisory-broker-001';")
[[ "$count" == "1" ]]

"${PSQL[@]}" -c "select case when actor_kind='SERVICE' and home_scope='COMPANY' and authority_ref is null and metadata->>'authority_effect'='NONE' and metadata->>'credential_access'='NONE' and (metadata->>'consequential_effects')::boolean=false and (metadata->>'provider_tools')::boolean=false and (metadata->>'code_write')::boolean=false and (metadata->>'spend')::boolean=false then 'SAFE' else 'UNSAFE' end from world8_actor_registry where actor_id='service-karest-advisory-broker-001';" | grep -qx SAFE

# Protected-field conflict must fail, never overwrite.
"${PSQL[@]}" -c "update world8_actor_registry set display_name='tampered' where actor_id='service-karest-advisory-broker-001';"
if "${PSQL[@]}" -c "select world8_register_karest_advisory_service_actor_v1();" >/tmp/conflict.out 2>/tmp/conflict.err; then
  echo 'expected IDENTITY_CONFLICT but call succeeded' >&2
  exit 1
fi
grep -q 'IDENTITY_CONFLICT' /tmp/conflict.err

# Non-ACTIVE lifecycle state must not be silently reactivated.
"${PSQL[@]}" -c "update world8_actor_registry set display_name='KAREST Advisory Broker', status='SUSPENDED' where actor_id='service-karest-advisory-broker-001';"
if "${PSQL[@]}" -c "select world8_register_karest_advisory_service_actor_v1();" >/tmp/inactive.out 2>/tmp/inactive.err; then
  echo 'expected ACTOR_NOT_ACTIVE but call succeeded' >&2
  exit 1
fi
grep -q 'ACTOR_NOT_ACTIVE' /tmp/inactive.err
status=$("${PSQL[@]}" -c "select status from world8_actor_registry where actor_id='service-karest-advisory-broker-001';")
[[ "$status" == "SUSPENDED" ]]

# Concurrent duplicate enrollment: exactly one canonical row; dispositions are one RECORDED and one REPLAY.
"${PSQL[@]}" -c "truncate world8_actor_registry;"
("${PSQL[@]}" -c "select world8_register_karest_advisory_service_actor_v1()->>'disposition';" > /tmp/a.out) &
p1=$!
("${PSQL[@]}" -c "select world8_register_karest_advisory_service_actor_v1()->>'disposition';" > /tmp/b.out) &
p2=$!
wait "$p1"
wait "$p2"
cat /tmp/a.out /tmp/b.out | sort > /tmp/dispositions.out
printf 'RECORDED\nREPLAY\n' | sort > /tmp/expected.out
diff -u /tmp/expected.out /tmp/dispositions.out
count2=$("${PSQL[@]}" -c "select count(*) from world8_actor_registry;")
[[ "$count2" == "1" ]]

echo 'KAREST_SERVICE_ACTOR_REGISTRAR_SQL_HARNESS_PASS'
