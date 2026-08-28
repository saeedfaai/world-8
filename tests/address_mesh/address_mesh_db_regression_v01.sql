-- World 8 Address Mesh v0.1 DB regression
-- PRECONDITION: Address Mesh draft SQL has been applied only to an authorized disposable/dev DB.
-- Rolls back fixture data.

begin;

-- AM-DB01: Address rebind preserves entity ID and creates immutable previous-address alias.
insert into public.world8_address_entities(
  entity_id,entity_kind,canonical_address,world_id,society_id,project_id,artifact_id,
  authoritative_ref_kind,authoritative_ref,tags,role_refs,revision,content_hash
) values(
  'W8-FN-TEST-REBIND','FUNCTION','w8://society/company/project/test/artifact/test/symbol/old',
  'world-001','company','test',null,'CODE_SYMBOL','a.py#old','["DOMAIN:TEST"]'::jsonb,
  '["MASON"]'::jsonb,1,'hash-v1'
);

do $$
declare r jsonb;
begin
  r:=public.world8_address_rebind_v1(
    'W8-FN-TEST-REBIND',1,
    'w8://society/company/project/test/artifact/test/symbol/new',
    'b.py#new','git:test-rename','["review:test"]'::jsonb
  );
  if r->>'entity_id'<>'W8-FN-TEST-REBIND' or (r->>'revision')::bigint<>2 then
    raise exception 'AM_DB01_REBIND_IDENTITY_FAILED';
  end if;
  if not exists(select 1 from public.world8_address_aliases where alias_address='w8://society/company/project/test/artifact/test/symbol/old' and entity_id='W8-FN-TEST-REBIND') then
    raise exception 'AM_DB01_ALIAS_MISSING';
  end if;
end $$;

-- AM-DB02: stale rebind CAS fails.
do $$
begin
  begin
    perform public.world8_address_rebind_v1(
      'W8-FN-TEST-REBIND',1,
      'w8://society/company/project/test/artifact/test/symbol/again',
      'c.py#again','git:stale','["review:test"]'::jsonb
    );
    raise exception 'AM_DB02_EXPECTED_CAS_FAILURE_NOT_RAISED';
  exception when others then
    if sqlerrm not like '%ADDRESS_ENTITY_CAS_CONFLICT%' then raise; end if;
  end;
end $$;

-- AM-DB03: alias history is append-only.
do $$
begin
  begin
    update public.world8_address_aliases set source_ref='tampered'
    where alias_address='w8://society/company/project/test/artifact/test/symbol/old';
    raise exception 'AM_DB03_EXPECTED_APPEND_ONLY_FAILURE_NOT_RAISED';
  exception when others then
    if sqlerrm not like '%WORLD8_ADDRESS_HISTORY_APPEND_ONLY%' then raise; end if;
  end;
end $$;

-- AM-DB04: MASON role resolves from Actor Registry, not string-name guessing.
do $$
declare r jsonb;
begin
  r:=public.world8_address_role_recipients_v1('role:MASON','SHARED_CORE',500);
  if (r->>'recipient_count')::integer<1 then raise exception 'AM_DB04_MASON_ROLE_EMPTY'; end if;
end $$;

-- AM-DB05: unknown role fails closed with zero recipients.
do $$
declare r jsonb;
begin
  r:=public.world8_address_role_recipients_v1('role:MADE_UP_ROLE',null,500);
  if (r->>'recipient_count')::integer<>0 then raise exception 'AM_DB05_UNKNOWN_ROLE_NOT_CLOSED'; end if;
end $$;

-- AM-DB06: direct address context resolves an entity and remains authority_effect=NONE.
do $$
declare r jsonb;
begin
  r:=public.world8_address_context_resolve_v1(
    'human-root',
    jsonb_build_object('address_entity_ids',jsonb_build_array('W8-FN-TEST-REBIND'),'address_tags',jsonb_build_array('DOMAIN:TEST')),
    50
  );
  if r->>'authority_effect'<>'NONE' then raise exception 'AM_DB06_CONTEXT_GAINED_AUTHORITY'; end if;
  if jsonb_array_length(r->'entities')<1 then raise exception 'AM_DB06_ENTITY_NOT_RESOLVED'; end if;
end $$;

-- AM-DB07/08 Attention idempotency requires an ACTIVE ATTENTION subscription fixture.
insert into public.world8_address_subscriptions(
  subscription_id,subscriber_ref,selector,event_kinds,minimum_priority,delivery_mode,
  society_scope,revision,status,created_by
) values(
  'sub-test-attn','human-root','{"entity_id":"W8-FN-TEST-REBIND"}'::jsonb,
  '["ERROR"]'::jsonb,'HIGH','ATTENTION','company',1,'ACTIVE','test'
);

do $$
declare first_result jsonb; replay_result jsonb; c bigint;
begin
  first_result:=public.world8_address_deliver_attention_v1(
    'delivery-test-1','sub-test-attn','human-root','DIAGNOSTIC_INCIDENT','incident-test',
    'Address Mesh test','Regression attention','HIGH','["W8-FN-TEST-REBIND"]'::jsonb,'test'
  );
  replay_result:=public.world8_address_deliver_attention_v1(
    'delivery-test-1','sub-test-attn','human-root','DIAGNOSTIC_INCIDENT','incident-test',
    'Address Mesh test','Regression attention','HIGH','["W8-FN-TEST-REBIND"]'::jsonb,'test'
  );
  if first_result->>'status'<>'DELIVERED' then raise exception 'AM_DB07_INITIAL_DELIVERY_FAILED'; end if;
  if replay_result->>'status'<>'IDEMPOTENT_REPLAY' then raise exception 'AM_DB08_REPLAY_NOT_IDEMPOTENT'; end if;
  select count(*) into c from public.world8_address_delivery_receipts where delivery_receipt_id='delivery-test-1';
  if c<>1 then raise exception 'AM_DB08_DUPLICATE_RECEIPT'; end if;
end $$;

rollback;
