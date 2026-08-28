-- World 8 Address Mesh v0.1 — Mason/Guardian Context Integration
-- STATUS: DRAFT ONLY / NOT APPLIED / NOT EVIDENCED
-- Depends on: 20260828_world8_universal_address_graph_v01.sql
-- Reuses existing world8_internal_messages, world8_attention_items and Diagnostic Memory.
-- Messaging/attention remains non-authoritative.

alter table public.world8_mason_preflight_receipts
  add column if not exists address_context_snapshot jsonb not null default '{}'::jsonb;

-- Resolve a bounded context around explicit address refs/tags supplied by a Work/Tool/Environment.
-- This function deliberately does NOT infer authority from address membership or messages.
create or replace function public.world8_address_context_resolve_v1(
  p_actor_ref text,
  p_environment_ref jsonb default '{}'::jsonb,
  p_limit integer default 100
) returns jsonb
language plpgsql stable security definer set search_path=public as $$
declare
  v_entity_ids text[]:=array[]::text[];
  v_addresses text[]:=array[]::text[];
  v_tags text[]:=array[]::text[];
  v_entities jsonb:='[]'::jsonb;
  v_messages jsonb:='[]'::jsonb;
  v_subscriptions jsonb:='[]'::jsonb;
  v_diagnostics jsonb:='[]'::jsonb;
  v_relations jsonb:='[]'::jsonb;
begin
  if p_limit<1 or p_limit>500 then raise exception 'ADDRESS_CONTEXT_LIMIT_OUT_OF_RANGE'; end if;
  if jsonb_typeof(coalesce(p_environment_ref,'{}'::jsonb))<>'object' then
    raise exception 'ADDRESS_CONTEXT_ENVIRONMENT_OBJECT_REQUIRED';
  end if;

  if jsonb_typeof(coalesce(p_environment_ref->'address_entity_ids','[]'::jsonb))='array' then
    select coalesce(array_agg(distinct value),array[]::text[]) into v_entity_ids
    from jsonb_array_elements_text(coalesce(p_environment_ref->'address_entity_ids','[]'::jsonb));
  end if;
  if jsonb_typeof(coalesce(p_environment_ref->'address_refs','[]'::jsonb))='array' then
    select coalesce(array_agg(distinct value),array[]::text[]) into v_addresses
    from jsonb_array_elements_text(coalesce(p_environment_ref->'address_refs','[]'::jsonb));
  end if;
  if jsonb_typeof(coalesce(p_environment_ref->'address_tags','[]'::jsonb))='array' then
    select coalesce(array_agg(distinct upper(trim(value))),array[]::text[]) into v_tags
    from jsonb_array_elements_text(coalesce(p_environment_ref->'address_tags','[]'::jsonb));
  end if;

  with selected as (
    select e.*
    from public.world8_address_entities e
    where e.status='ACTIVE'
      and (
        e.entity_id=any(v_entity_ids)
        or e.canonical_address=any(v_addresses)
        or exists(
          select 1 from unnest(v_tags) t(tag)
          where e.tags ? t.tag
             or e.tags ? split_part(t.tag,':',2) -- legacy flat Diagnostic tag compatibility
        )
      )
    order by e.entity_id
    limit p_limit
  )
  select coalesce(jsonb_agg(jsonb_build_object(
    'entity_id',entity_id,'entity_kind',entity_kind,'canonical_address',canonical_address,
    'society_id',society_id,'project_id',project_id,'artifact_id',artifact_id,
    'owner_ref',owner_ref,'role_refs',role_refs,'tags',tags,'revision',revision
  )),'[]'::jsonb) into v_entities from selected;

  -- Direct recipients plus exact/tag/role/artifact-tree routing targets.
  -- Arbitrary JSON selector targets remain resolver-versioned and are evaluated by the
  -- Address Mesh selector engine; this SQL path intentionally does not invent partial semantics.
  with selected_ids as (
    select value#>>'{}' as entity_id from jsonb_array_elements(v_entities->0) limit 0
  ), entity_rows as (
    select e.* from public.world8_address_entities e
    where e.entity_id in (select x->>'entity_id' from jsonb_array_elements(v_entities) x)
  ), candidate_messages as (
    select distinct m.message_id,m.sender_ref,m.subject,m.priority,m.state,m.linked_refs,m.created_at
    from public.world8_internal_messages m
    left join public.world8_internal_message_targets t on t.message_id=m.message_id
    where m.state not in ('RESOLVED','SUPERSEDED')
      and (
        m.recipient_refs ? p_actor_ref
        or (t.target_type='ENTITY_ID' and exists(select 1 from entity_rows e where e.entity_id=t.target_ref))
        or (t.target_type='ADDRESS' and exists(select 1 from entity_rows e where e.canonical_address=t.target_ref))
        or (t.target_type='TAG' and exists(select 1 from entity_rows e where e.tags ? upper(t.target_ref) or e.tags ? t.target_ref))
        or (t.target_type='ROLE' and exists(select 1 from entity_rows e where e.role_refs ? t.target_ref))
        or (t.target_type='ARTIFACT_TREE' and exists(select 1 from entity_rows e where e.artifact_id=t.target_ref))
      )
    order by m.created_at desc
    limit p_limit
  )
  select coalesce(jsonb_agg(to_jsonb(candidate_messages)),'[]'::jsonb) into v_messages from candidate_messages;

  select coalesce(jsonb_agg(jsonb_build_object(
    'subscription_id',s.subscription_id,'subscriber_ref',s.subscriber_ref,
    'selector',s.selector,'event_kinds',s.event_kinds,'delivery_mode',s.delivery_mode,
    'minimum_priority',s.minimum_priority,'revision',s.revision
  )),'[]'::jsonb) into v_subscriptions
  from public.world8_address_subscriptions s
  where s.status='ACTIVE' and s.subscriber_ref=p_actor_ref
  limit p_limit;

  -- Reuse Diagnostic Memory by unioning address tags with current environment tags.
  v_diagnostics:=public.world8_diag_context_search_v1(
    null,
    (select coalesce(array_agg(distinct x),array[]::text[])
     from unnest(v_tags || public.world8_guardian_environment_tags_v1(coalesce(p_environment_ref::text,''),p_environment_ref)) x),
    least(p_limit,200)
  );

  with entity_ids as (
    select x->>'entity_id' entity_id from jsonb_array_elements(v_entities) x
  )
  select coalesce(jsonb_agg(jsonb_build_object(
    'relation_id',r.relation_id,'source_entity_id',r.source_entity_id,
    'relation_type',r.relation_type,'target_entity_id',r.target_entity_id,
    'source_ref',r.source_ref,'revision',r.revision
  )),'[]'::jsonb) into v_relations
  from public.world8_address_relations r
  where r.source_entity_id in (select entity_id from entity_ids)
     or r.target_entity_id in (select entity_id from entity_ids)
  limit p_limit;

  return jsonb_build_object(
    'schema','WORLD8_ADDRESS_CONTEXT/1.0',
    'actor_ref',p_actor_ref,
    'entity_ids',to_jsonb(v_entity_ids),
    'address_refs',to_jsonb(v_addresses),
    'address_tags',to_jsonb(v_tags),
    'entities',v_entities,
    'messages',v_messages,
    'subscriptions',v_subscriptions,
    'diagnostics',v_diagnostics,
    'relations',v_relations,
    'authority_effect','NONE',
    'generated_at',clock_timestamp()
  );
end $$;

-- Integration patch for existing Mason Preflight implementation:
--   v_address_context := public.world8_address_context_resolve_v1(p_actor_ref,p_environment_ref,100);
--   store it in address_context_snapshot and include in the receipt payload hash.
--
-- Integration patch for Engineering Guardian pre_action:
--   resolve the same address context from the current target/environment and surface
--   message/diagnostic/required-test refs in advisory.context_snapshot.
--
-- REQUIRED FAIL-CLOSED RULE:
-- If address tables/functions are unavailable, existing Preflight/Guardian behavior continues;
-- absence of Address Mesh never grants authority or suppresses Diagnostic Memory.
