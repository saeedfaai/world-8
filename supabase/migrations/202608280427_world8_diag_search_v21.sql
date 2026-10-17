-- World 8 Diagnostic Search v2.1
-- Prevents known-experience false negatives: token-based matching + TEST_CONTRACT indexing.

create or replace function public.world8_diag_search_v2(
  p_query text default null,
  p_tags text[] default null,
  p_entity_kinds text[] default null,
  p_limit integer default 50
) returns jsonb
language sql stable security definer set search_path='public','extensions' as $$
with entities as (
  select 'INCIDENT'::text entity_kind, i.incident_id entity_id,
         coalesce(i.error_code,'') title,
         concat_ws(' ',i.error_code,i.error_class,i.stage,i.component_ref,i.normalized_message) search_text,
         jsonb_build_object('observed_at',i.observed_at,'stage',i.stage,'component_ref',i.component_ref,'error_code',i.error_code,'error_class',i.error_class,'resolution_state',i.resolution_state,'matched_signature_id',i.matched_signature_id,'matched_playbook_id',i.matched_playbook_id) payload
  from public.world8_diag_incidents i
  union all
  select 'SIGNATURE',s.signature_id,s.signature_id,
         concat_ws(' ',s.signature_id,s.error_class,s.component_ref,s.match_spec::text,s.likely_causes::text),
         jsonb_build_object('error_class',s.error_class,'match_kind',s.match_kind,'match_spec',s.match_spec,'component_ref',s.component_ref,'validation_state',s.validation_state,'confidence_class',s.confidence_class)
  from public.world8_diag_signatures s
  union all
  select 'PLAYBOOK',p.playbook_id,p.title,
         concat_ws(' ',p.playbook_id,p.title,p.description,p.component_refs::text,p.repair_steps::text,p.verification_test_ids::text),
         jsonb_build_object('title',p.title,'risk_class',p.risk_class,'status',p.status,'auto_apply_allowed',p.auto_apply_allowed,'repair_steps',p.repair_steps,'verification_test_ids',p.verification_test_ids)
  from public.world8_diag_playbooks p
  union all
  select 'TEST_CONTRACT',t.test_id,t.title,
         concat_ws(' ',t.test_id,t.component_ref,t.stage,t.probe_type,t.title,t.input_contract::text,t.expected_contract::text,t.failure_codes::text),
         jsonb_build_object('title',t.title,'component_ref',t.component_ref,'stage',t.stage,'probe_type',t.probe_type,'expected_contract',t.expected_contract,'failure_codes',t.failure_codes,'risk_class',t.risk_class,'status',t.status)
  from public.world8_diag_test_contracts t
), tagged as (
  select e.*,coalesce(array_agg(distinct b.tag_key order by b.tag_key) filter(where b.tag_key is not null),array[]::text[]) tags
  from entities e left join public.world8_diag_tag_bindings b on b.entity_kind=e.entity_kind and b.entity_id=e.entity_id
  group by e.entity_kind,e.entity_id,e.title,e.search_text,e.payload
), filtered as (
  select * from tagged
  where (p_query is null or trim(p_query)='' or not exists(
      select 1 from regexp_split_to_table(lower(trim(p_query)),'\s+') tok
      where tok<>'' and lower(search_text) not like '%'||tok||'%'
    ))
    and (p_tags is null or cardinality(p_tags)=0 or tags @> (select array_agg(upper(trim(x))) from unnest(p_tags) x))
    and (p_entity_kinds is null or cardinality(p_entity_kinds)=0 or entity_kind=any(select upper(trim(x)) from unnest(p_entity_kinds) x))
  order by case entity_kind when 'INCIDENT' then 1 when 'SIGNATURE' then 2 when 'PLAYBOOK' then 3 else 4 end,entity_id desc
  limit greatest(1,least(coalesce(p_limit,50),200))
)
select jsonb_build_object(
  'schema','WORLD8_DIAG_SEARCH/2.1','query',p_query,'query_mode','TOKEN_ALL',
  'tags',coalesce(to_jsonb(p_tags),'[]'::jsonb),
  'results',coalesce(jsonb_agg(jsonb_build_object('entity_kind',entity_kind,'entity_id',entity_id,'title',title,'tags',tags,'payload',payload)),'[]'::jsonb)
) from filtered;
$$;
