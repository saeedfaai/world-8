-- Runtime regression for Guardian/Mason diagnostic environment propagation.
-- Run only on a disposable/dev database after applying the v0.1.2/v0.1.2.1 migrations.
-- Entire fixture is rolled back.

begin;

do $$
declare
  v_tags text[];
  v_incident jsonb;
  v_search jsonb;
begin
  v_tags:=public.world8_guardian_environment_tags_v1(
    'deliver approval link',
    jsonb_build_object(
      'target_ref','https://example.supabase.co/functions/v1/world8-authority-approval',
      'component_ref','world8-authority-approval',
      'context_tags',jsonb_build_array('ACCESS_MESH')
    )
  );

  if not ('SUPABASE'=any(v_tags)) then raise exception 'TEST_FAIL_SUPABASE_TAG_NOT_PROPAGATED'; end if;
  if not ('ACCESS_MESH'=any(v_tags)) then raise exception 'TEST_FAIL_ACCESS_MESH_TAG_NOT_PROPAGATED'; end if;
  if not ('RENDER'=any(v_tags)) then raise exception 'TEST_FAIL_DIRECT_EDGE_RENDER_TAG_NOT_PROPAGATED'; end if;

  v_incident:=public.world8_diag_record_incident_v2(
    'TEST',
    'world8-authority-approval',
    'TEST_EDGE_HTML_SOURCE_RENDERED',
    'UI_RENDERING_DELIVERY',
    'Synthetic regression fixture for environment-tag retrieval.',
    null,
    jsonb_build_object('fixture',true),
    jsonb_build_array('test:diagnostic_environment_tag_regression'),
    null,
    array['SUPABASE','ACCESS_MESH','RENDER']::text[]
  );

  v_search:=public.world8_diag_context_search_v1(null,array['SUPABASE','ACCESS_MESH','RENDER']::text[],100);

  if coalesce(v_search->>'query_mode','')<>'TOKEN_ANY_PER_TAG_UNION' then
    raise exception 'TEST_FAIL_CONTEXT_SEARCH_MODE';
  end if;

  if not exists(
    select 1
    from jsonb_array_elements(coalesce(v_search->'results','[]'::jsonb)) e
    where e->>'title'='TEST_EDGE_HTML_SOURCE_RENDERED'
       or e->'payload'->>'error_code'='TEST_EDGE_HTML_SOURCE_RENDERED'
  ) then
    raise exception 'TEST_FAIL_ENVIRONMENT_TAG_INCIDENT_NOT_SURFACED';
  end if;
end $$;

rollback;
