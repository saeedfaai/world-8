-- World 8 Address Mesh v0.1 — Role Recipient Resolution
-- STATUS: DRAFT ONLY / NOT APPLIED / NOT EVIDENCED
-- Role text is a selector, never an Actor identity or authority grant.

create or replace function public.world8_address_role_recipients_v1(
  p_subscriber_ref text,
  p_society_scope text default null,
  p_limit integer default 500
) returns jsonb
language plpgsql stable security definer set search_path=public as $$
declare
  v_role text:=upper(trim(split_part(coalesce(p_subscriber_ref,''),':',2)));
  v_recipients jsonb:='[]'::jsonb;
begin
  if p_limit<1 or p_limit>1000 then raise exception 'ROLE_RECIPIENT_LIMIT_OUT_OF_RANGE'; end if;
  if lower(coalesce(p_subscriber_ref,'')) not like 'role:%' then
    return jsonb_build_object(
      'schema','WORLD8_ADDRESS_ROLE_RECIPIENTS/1.0',
      'subscriber_ref',p_subscriber_ref,
      'mode','DIRECT',
      'recipients',jsonb_build_array(p_subscriber_ref)
    );
  end if;

  if v_role='MASON' then
    select coalesce(jsonb_agg(actor_id order by actor_id),'[]'::jsonb) into v_recipients
    from (
      select actor_id
      from public.world8_actor_registry
      where status='ACTIVE'
        and actor_kind='AI_MASON'
        and (p_society_scope is null or home_scope=p_society_scope or home_scope='SHARED_CORE')
      order by actor_id
      limit p_limit
    ) q;
  else
    -- No fuzzy role/name inference. Other role classes require explicit governed Actor/Binding mapping.
    v_recipients:='[]'::jsonb;
  end if;

  return jsonb_build_object(
    'schema','WORLD8_ADDRESS_ROLE_RECIPIENTS/1.0',
    'subscriber_ref',p_subscriber_ref,
    'role',v_role,
    'society_scope',p_society_scope,
    'resolution_mode',case when v_role='MASON' then 'ACTOR_KIND_AI_MASON_V0_1' else 'UNRESOLVED_FAIL_CLOSED' end,
    'recipients',v_recipients,
    'recipient_count',jsonb_array_length(v_recipients),
    'authority_effect','NONE'
  );
end $$;

-- Future GUARDIAN / EVALUATOR / OBSERVER role mappings must come from explicit Actor/Binding
-- truth. Display-name matching and string guessing are forbidden.
