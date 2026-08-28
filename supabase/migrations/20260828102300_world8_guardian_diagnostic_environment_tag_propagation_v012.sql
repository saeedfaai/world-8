-- World 8 Engineering Guardian / Mason Diagnostic Context Repair v0.1.2
-- Purpose: prevent recurrence of known errors when the current Work/Tool/Environment
-- already carries matching Diagnostic Memory tags.
--
-- DESIGN RULE:
--   Environment/Action tags -> Diagnostic Memory -> Guardian/Mason context before action.
--
-- This migration is committed to the isolated runtime branch only. It is NOT applied to
-- production by this commit. Production application still requires governed Admission + Lease.

create or replace function public.world8_guardian_environment_tags_v1(
  p_text text,
  p_environment_ref jsonb default '{}'::jsonb
) returns text[]
language plpgsql stable security definer set search_path=public as $$
declare
  v_text text:=lower(coalesce(p_text,'')||' '||coalesce(p_environment_ref,'{}'::jsonb)::text);
  v_tags text[]:=array['WORLD','MASON'];
  v_tag text;
begin
  if jsonb_typeof(coalesce(p_environment_ref,'{}'::jsonb))<>'object' then
    raise exception 'GUARDIAN_ENVIRONMENT_REF_OBJECT_REQUIRED';
  end if;

  if jsonb_typeof(coalesce(p_environment_ref->'context_tags','[]'::jsonb))='array' then
    for v_tag in select jsonb_array_elements_text(coalesce(p_environment_ref->'context_tags','[]'::jsonb)) loop
      v_tags:=array_append(v_tags,upper(trim(v_tag)));
    end loop;
  end if;
  if jsonb_typeof(coalesce(p_environment_ref->'diagnostic_tags','[]'::jsonb))='array' then
    for v_tag in select jsonb_array_elements_text(coalesce(p_environment_ref->'diagnostic_tags','[]'::jsonb)) loop
      v_tags:=array_append(v_tags,upper(trim(v_tag)));
    end loop;
  end if;

  if v_text ~ '(telegram|bot|webhook)' then v_tags:=array_append(v_tags,'TELEGRAM'); end if;
  if v_text ~ '(api|rpc|webhook|endpoint|provider|connector)' then v_tags:=array_append(v_tags,'API'); end if;
  if v_text ~ '(backup|mirror|continuity|export)' then v_tags:=array_append(v_tags,'BACKUP'); end if;
  if v_text ~ '(genesis|recovery|recover|restore|reconstruct|checkpoint|crash)' then v_tags:=array_append(v_tags,'RECOVERY'); end if;
  if v_text ~ '(database|sql|schema|postgres|table|column|migration)' then v_tags:=array_append(v_tags,'DATABASE'); end if;
  if v_text ~ '(schema|column|field|function signature|migration)' then v_tags:=array_append(v_tags,'SCHEMA'); end if;
  if v_text ~ '(auth|permission|privilege|identity|authority|authorization|admission)' then v_tags:=array_append(v_tags,'AUTH'); end if;
  if v_text ~ '(secret|credential|security|token|password)' then v_tags:=array_append(v_tags,'SECURITY'); end if;
  if v_text ~ '(secretary|proforma|invoice|pdf)' then v_tags:=array_append(v_tags,'SECRETARY'); end if;
  if v_text ~ '(trading|forecast|market|order|portfolio)' then v_tags:=array_append(v_tags,'TRADING'); end if;
  if v_text ~ '(company|sales|quote|customer|supplier)' then v_tags:=array_append(v_tags,'COMPANY'); end if;
  if v_text ~ '(mason|preflight|postflight|coding|code |workspace|work claim)' then v_tags:=array_append(v_tags,'MASON'); end if;
  if v_text ~ '(dcp|development control|workspace|work claim|handoff|postflight)' then v_tags:=array_append(v_tags,'DCP'); end if;
  if v_text ~ '(supabase|edge function|supabase\.co/functions)' then v_tags:=array_append(v_tags,'SUPABASE'); end if;
  if v_text ~ '(github|git |branch|commit|pull request|workflow|ci)' then v_tags:=array_append(v_tags,'GITHUB'); end if;
  if v_text ~ '(connectivity|vpn|proxy|route|lifeline)' then v_tags:=array_append(v_tags,'CONNECTIVITY'); end if;
  if v_text ~ '(access mesh|control surface|shadow panel|approval ui|browser ui|world8-authority-approval)' then v_tags:=array_append(v_tags,'ACCESS_MESH'); end if;
  if v_text ~ '(render|raw html|html source|source code visible|dom|content[- ]type|ui delivery|direct edge url|browser rendering)' then v_tags:=array_append(v_tags,'RENDER'); end if;

  select coalesce(array_agg(distinct x order by x),array[]::text[]) into v_tags
  from unnest(v_tags) x
  where coalesce(trim(x),'')<>''
    and exists(select 1 from public.world8_diag_tags t where t.tag_key=x and t.status='ACTIVE');

  return v_tags;
end $$;

create or replace function public.world8_diag_context_search_v1(
  p_query text default null,
  p_context_tags text[] default array[]::text[],
  p_limit integer default 50
) returns jsonb
language plpgsql stable security definer set search_path=public as $$
declare
  v_tags text[]:=array[]::text[];
  v_results jsonb:='[]'::jsonb;
begin
  if p_limit<1 or p_limit>200 then raise exception 'DIAG_CONTEXT_LIMIT_OUT_OF_RANGE'; end if;

  select coalesce(array_agg(distinct upper(trim(x)) order by upper(trim(x))),array[]::text[]) into v_tags
  from unnest(coalesce(p_context_tags,array[]::text[])) x
  where coalesce(trim(x),'')<>''
    and exists(select 1 from public.world8_diag_tags t where t.tag_key=upper(trim(x)) and t.status='ACTIVE');

  with candidates as (
    select e.value as item
    from unnest(v_tags) t(tag)
    cross join lateral jsonb_array_elements(
      coalesce((public.world8_diag_search_v2(null,array[t.tag],null,least(p_limit,50))->'results'),'[]'::jsonb)
    ) e
    union all
    select e.value as item
    from jsonb_array_elements(
      case when coalesce(trim(p_query),'')=''
        then '[]'::jsonb
        else coalesce((public.world8_diag_search_v2(p_query,null,null,least(p_limit,50))->'results'),'[]'::jsonb)
      end
    ) e
  ), dedup as (
    select distinct item from candidates
  )
  select coalesce(jsonb_agg(item),'[]'::jsonb) into v_results
  from (select item from dedup limit p_limit) q;

  return jsonb_build_object(
    'schema','WORLD8_DIAG_CONTEXT_SEARCH/1.0',
    'query_mode','TOKEN_ANY_PER_TAG_UNION',
    'tags',to_jsonb(v_tags),
    'query',p_query,
    'results',v_results,
    'result_count',jsonb_array_length(v_results),
    'generated_at',clock_timestamp()
  );
end $$;

create or replace function public.world8_guardian_context_classify_v1(
  p_work_id text,
  p_artifact_ids jsonb default '[]'::jsonb,
  p_paths jsonb default '[]'::jsonb,
  p_db_objects jsonb default '[]'::jsonb,
  p_tool_kind text default null,
  p_action_kind text default null,
  p_error_code text default null
) returns jsonb
language plpgsql stable security definer set search_path=public as $$
declare
  v_w public.world8_dev_work_items%rowtype;
  v_text text:='';
  v_tags text[]:=array[]::text[];
begin
  select * into v_w from public.world8_dev_work_items where work_id=p_work_id;
  if not found then raise exception 'WORK_NOT_FOUND'; end if;
  if jsonb_typeof(coalesce(p_artifact_ids,'[]'::jsonb))<>'array'
     or jsonb_typeof(coalesce(p_paths,'[]'::jsonb))<>'array'
     or jsonb_typeof(coalesce(p_db_objects,'[]'::jsonb))<>'array' then
    raise exception 'GUARDIAN_CONTEXT_ARRAYS_REQUIRED';
  end if;

  v_text:=concat_ws(' ',
    v_w.goal,
    v_w.architecture_ref,
    v_w.touches::text,
    coalesce(p_artifact_ids,'[]'::jsonb)::text,
    coalesce(p_paths,'[]'::jsonb)::text,
    coalesce(p_db_objects,'[]'::jsonb)::text,
    p_tool_kind,
    p_action_kind,
    p_error_code
  );
  v_tags:=public.world8_guardian_environment_tags_v1(v_text,'{}'::jsonb);

  return jsonb_build_object(
    'schema','WORLD8_GUARDIAN_CONTEXT_CLASS/1.1',
    'work_id',p_work_id,
    'tags',to_jsonb(v_tags),
    'tool_kind',p_tool_kind,
    'action_kind',p_action_kind,
    'error_code',p_error_code,
    'classifier_mode','DETERMINISTIC_CANONICAL_TAGS_PLUS_ENVIRONMENT'
  );
end $$;

create or replace function public.world8_mason_preflight_v1(
  p_actor_ref text,
  p_source_room text,
  p_intent_summary text,
  p_target_artifact_ids jsonb default '[]'::jsonb,
  p_environment_ref jsonb default '{}'::jsonb,
  p_valid_minutes integer default 120
) returns jsonb
language plpgsql security definer set search_path='public','extensions' as $$
declare
  v_rule public.world8_mason_rulebase_versions%rowtype;
  v_now timestamptz:=clock_timestamp(); v_id text; v_targets text[];
  v_missing jsonb:='[]'::jsonb; v_reviewed jsonb:='[]'::jsonb; v_leases jsonb:='[]'::jsonb; v_incidents jsonb:='[]'::jsonb; v_blockers jsonb:='[]'::jsonb; v_gate text:='PASS';
  v_now_snapshot jsonb:='{}'::jsonb; v_inbox jsonb:='[]'::jsonb; v_attention jsonb:='[]'::jsonb; v_access jsonb:='{}'::jsonb; v_sync jsonb:='{}'::jsonb;
  v_diag_tags text[]:=array[]::text[]; v_diag_search jsonb:='{}'::jsonb; v_diag_text text; v_diag_query text;
  v_payload jsonb; v_hash text;
begin
  if p_valid_minutes < 15 or p_valid_minutes > 720 then raise exception 'PREFLIGHT_VALIDITY_OUT_OF_RANGE'; end if;
  if jsonb_typeof(coalesce(p_environment_ref,'{}'::jsonb))<>'object' then raise exception 'PREFLIGHT_ENVIRONMENT_REF_OBJECT_REQUIRED'; end if;
  select * into v_rule from public.world8_mason_rulebase_versions where world_id='world-001' and status='ACTIVE' order by effective_at desc limit 1;
  if not found then raise exception 'ACTIVE_MASON_RULEBASE_NOT_FOUND'; end if;
  select coalesce(array_agg(value),array[]::text[]) into v_targets from jsonb_array_elements_text(coalesce(p_target_artifact_ids,'[]'::jsonb));

  select coalesce(jsonb_agg(jsonb_build_object('artifact_id',a.artifact_id,'name',a.name)), '[]'::jsonb) into v_missing
  from public.world8_dev_artifacts a where a.artifact_id=any(v_targets)
    and not exists(select 1 from public.world8_code_shadow_manifests s where s.artifact_id=a.artifact_id and s.status='ACTIVE' and s.completeness_state='COMPLETE');

  select coalesce(jsonb_agg(jsonb_build_object('artifact_id',s.artifact_id,'shadow_id',s.shadow_id,'artifact_revision',s.artifact_revision,'shadow_revision',s.shadow_revision,'content_hash',s.content_hash)), '[]'::jsonb) into v_reviewed
  from public.world8_code_shadow_manifests s where s.artifact_id=any(v_targets) and s.status='ACTIVE' and s.completeness_state='COMPLETE';

  select coalesce(jsonb_agg(jsonb_build_object('lease_id',l.lease_id,'artifact_id',l.artifact_id,'holder_ref',l.holder_ref,'source_room',l.source_room,'mode',l.mode,'expires_at',l.expires_at)), '[]'::jsonb) into v_leases
  from public.world8_dev_leases l where l.status='ACTIVE' and l.artifact_id=any(v_targets) and l.expires_at>v_now;

  select coalesce(jsonb_agg(jsonb_build_object('incident_id',i.incident_id,'component_ref',i.component_ref,'error_code',i.error_code,'resolution_state',i.resolution_state,'observed_at',i.observed_at)), '[]'::jsonb) into v_incidents
  from public.world8_diag_incidents i where i.resolution_state='OPEN' and i.component_ref=any(v_targets);

  -- Critical repair: environment_ref is part of diagnostic classification, not merely stored evidence.
  v_diag_text:=concat_ws(' ',coalesce(p_intent_summary,''),coalesce(p_target_artifact_ids::text,''),coalesce(p_environment_ref::text,''));
  v_diag_tags:=public.world8_guardian_environment_tags_v1(v_diag_text,coalesce(p_environment_ref,'{}'::jsonb));
  v_diag_query:=nullif(trim(coalesce(p_environment_ref->>'component_ref',p_environment_ref->>'target_ref','')),'');
  v_diag_search:=public.world8_diag_context_search_v1(v_diag_query,v_diag_tags,50);

  v_now_snapshot:=public.world8_now_snapshot_v2(p_actor_ref);
  v_inbox:=coalesce(v_now_snapshot->'my_inbox','[]'::jsonb);
  v_attention:=coalesce(v_now_snapshot->'my_attention_queue','[]'::jsonb);
  v_access:=coalesce(v_now_snapshot->'access_mesh','{}'::jsonb);
  v_sync:=coalesce(v_now_snapshot->'continuity_sync','{}'::jsonb);

  if jsonb_array_length(v_missing)>0 then
    v_gate:='BLOCKED'; v_blockers:=v_blockers || jsonb_build_array(jsonb_build_object('code','CODE_SHADOW_REQUIRED','artifacts',v_missing));
  end if;
  if exists(select 1 from public.world8_dev_leases l where l.status='ACTIVE' and l.artifact_id=any(v_targets) and l.mode='EXCLUSIVE_WRITE' and l.expires_at>v_now) then
    v_gate:='BLOCKED'; v_blockers:=v_blockers || jsonb_build_array(jsonb_build_object('code','ACTIVE_EXCLUSIVE_LEASE_PRESENT','leases',v_leases));
  end if;

  v_payload:=jsonb_build_object(
    'rulebase_version_id',v_rule.rulebase_version_id,
    'actor_ref',p_actor_ref,
    'source_room',p_source_room,
    'intent_summary',p_intent_summary,
    'target_artifact_ids',coalesce(p_target_artifact_ids,'[]'::jsonb),
    'environment_ref',coalesce(p_environment_ref,'{}'::jsonb),
    'reviewed_shadow_ids',v_reviewed,
    'active_lease_snapshot',v_leases,
    'open_incident_snapshot',v_incidents,
    'diagnostic_tags_snapshot',to_jsonb(v_diag_tags),
    'diagnostic_search_snapshot',v_diag_search,
    'inbox_snapshot',v_inbox,
    'attention_snapshot',v_attention,
    'access_snapshot',v_access,
    'continuity_sync_snapshot',v_sync,
    'blockers',v_blockers,
    'gate_state',v_gate,
    'issued_at',v_now
  );
  v_hash:=encode(extensions.digest(v_payload::text,'sha256'),'hex');
  v_id:='mason-preflight-'||substr(encode(extensions.digest(p_actor_ref||'|'||p_source_room||'|'||p_intent_summary||'|'||v_now::text,'sha256'),'hex'),1,28);

  insert into public.world8_mason_preflight_receipts(
    preflight_receipt_id,rulebase_version_id,actor_ref,source_room,intent_summary,target_artifact_ids,environment_ref,
    architecture_ref,bootstrap_ref,rescue_ref,diagnostics_ref,reviewed_document_refs,reviewed_shadow_ids,
    active_lease_snapshot,open_incident_snapshot,obligations_ack,blockers,gate_state,issued_at,expires_at,content_hash,
    now_snapshot,inbox_snapshot,attention_snapshot,access_snapshot,continuity_sync_snapshot,diagnostic_tags_snapshot,diagnostic_search_snapshot
  ) values(
    v_id,v_rule.rulebase_version_id,p_actor_ref,p_source_room,p_intent_summary,coalesce(p_target_artifact_ids,'[]'::jsonb),coalesce(p_environment_ref,'{}'::jsonb),
    'World_8_Z0-A','WORLD8_DEV_BOOTSTRAP_v1','WORLD8_RESCUE_INDEX_LIVE_v1','WORLD8_DIAGNOSTIC_KNOWLEDGE_POLICY_LIVE_v1',
    jsonb_build_array('WORLD8_HUMAN_START_HERE_v1','WORLD8_MASON_RULEBASE_LIVE_v1','WORLD8_MASON_CODE_STANDARD_LIVE_v1','WORLD8_CODE_SHADOW_STANDARD_LIVE_v1','WORLD8_NOW/2.0','WORLD8_ACCESS_MESH_CONNECTIVITY_LIFELINE_LIVE_v1','WORLD8_ACCESS_MESH_CHANNEL_CATALOG_LIVE_v1','WORLD8_POSTFLIGHT_CONTINUITY_SYNC_LIVE_v1','WORLD8_RECONSTRUCTION_RUNBOOK_LIVE_v1'),
    v_reviewed,v_leases,v_incidents,v_rule.principles || v_rule.mandatory_preflight,v_blockers,v_gate,v_now,v_now+make_interval(mins=>p_valid_minutes),v_hash,
    v_now_snapshot,v_inbox,v_attention,v_access,v_sync,to_jsonb(v_diag_tags),v_diag_search
  );

  return jsonb_build_object(
    'preflight_receipt_id',v_id,
    'gate_state',v_gate,
    'rulebase_version_id',v_rule.rulebase_version_id,
    'blockers',v_blockers,
    'reviewed_shadows',v_reviewed,
    'diagnostic_tags',to_jsonb(v_diag_tags),
    'diagnostic_result_count',jsonb_array_length(coalesce(v_diag_search->'results','[]'::jsonb)),
    'diagnostic_query_mode',v_diag_search->>'query_mode',
    'inbox_count',jsonb_array_length(v_inbox),
    'attention_count',jsonb_array_length(v_attention),
    'access_channel_count',jsonb_array_length(coalesce(v_access->'channels','[]'::jsonb)),
    'expires_at',v_now+make_interval(mins=>p_valid_minutes),
    'content_hash',v_hash
  );
end $$;

create or replace function public.world8_guardian_pre_action_v1(
  p_dev_session_id text,
  p_action_kind text,
  p_target_ref text,
  p_target_artifact_id text,
  p_safe_summary text
) returns jsonb
language plpgsql security definer set search_path='public' as $$
declare
  v_s public.world8_dev_session_liveness%rowtype;
  v_write_required boolean;
  v_lease jsonb:='{}'::jsonb;
  v_lease_ok boolean:=true;
  v_observe jsonb;
  v_existing_hard jsonb:='[]'::jsonb;
  v_gate text:='PASS';
  v_recommendation text:='PROCEED_UNDER_EXISTING_GOVERNANCE';
  v_action_text text;
  v_action_tags text[]:=array[]::text[];
  v_diag jsonb:='{}'::jsonb;
  v_known_recurrence boolean:=false;
begin
  if coalesce(trim(p_safe_summary),'')='' then raise exception 'GUARDIAN_SAFE_SUMMARY_REQUIRED'; end if;
  select * into v_s from public.world8_dev_session_liveness where session_id=p_dev_session_id;
  if not found then raise exception 'DEV_SESSION_NOT_FOUND'; end if;

  v_write_required:=upper(trim(coalesce(p_action_kind,''))) in ('WRITE','CODE_WRITE','MIGRATION','AUTHORITY_WRITE','MERGE','DEPLOY');
  if v_write_required and p_target_artifact_id is not null then
    select coalesce((select jsonb_build_object(
      'lease_id',l.lease_id,'mode',l.mode,'fencing_token',l.fencing_token,'expires_at',l.expires_at,
      'authorization_checked',coalesce((l.metadata->>'authorization_checked')::boolean,false),'admission_id',l.metadata->>'admission_id'
    ) from public.world8_dev_leases l
      where l.work_id=v_s.work_id and l.holder_ref=v_s.actor_id and l.artifact_id=p_target_artifact_id
        and l.status='ACTIVE' and l.expires_at>clock_timestamp() and l.mode in ('SHARED_WRITE','EXCLUSIVE_WRITE')
      order by l.issued_at desc limit 1),'{}'::jsonb) into v_lease;
    v_lease_ok:=v_lease<>'{}'::jsonb and coalesce((v_lease->>'authorization_checked')::boolean,false);
  end if;

  v_action_text:=concat_ws(' ',p_action_kind,p_target_ref,p_target_artifact_id,p_safe_summary);
  v_action_tags:=public.world8_guardian_environment_tags_v1(
    v_action_text,
    jsonb_build_object('target_ref',p_target_ref,'component_ref',p_target_ref,'action_kind',p_action_kind)
  );
  v_diag:=public.world8_diag_context_search_v1(nullif(trim(p_target_ref),''),v_action_tags,50);

  select exists(
    select 1
    from jsonb_array_elements(coalesce(v_diag->'results','[]'::jsonb)) e
    where upper(coalesce(e->>'title','')) in (
      'EDGE_HTML_SOURCE_RENDERED',
      'DIRECT_EDGE_UI_FORBIDDEN',
      'UI_CONTENT_TYPE_MISMATCH',
      'GUARDIAN_ENVIRONMENT_TAG_PROPAGATION_GAP'
    )
    or upper(coalesce(e->'payload'->>'error_code','')) in (
      'EDGE_HTML_SOURCE_RENDERED',
      'DIRECT_EDGE_UI_FORBIDDEN',
      'UI_CONTENT_TYPE_MISMATCH',
      'GUARDIAN_ENVIRONMENT_TAG_PROPAGATION_GAP'
    )
  ) into v_known_recurrence;

  v_observe:=public.world8_guardian_observe_v1(
    p_dev_session_id,
    case when p_target_artifact_id is null then '[]'::jsonb else jsonb_build_array(p_target_artifact_id) end,
    '[]'::jsonb,
    '[]'::jsonb,
    case when 'SUPABASE'=any(v_action_tags) then 'SUPABASE_EDGE_UI' else null end,
    p_action_kind,
    case when v_known_recurrence then 'KNOWN_DIAGNOSTIC_RECURRENCE_RISK' else null end,
    v_action_text,
    jsonb_build_object('target_ref',p_target_ref,'target_artifact_id',p_target_artifact_id,'diagnostic_context_tags',to_jsonb(v_action_tags))
  );
  v_existing_hard:=coalesce(v_observe->'context_bundle'->'awareness'->'hard_gate_mirrors','[]'::jsonb);

  if not v_lease_ok then
    v_gate:='BLOCKED_BY_EXISTING_GOVERNANCE';
    v_recommendation:='STOP_UNTIL_EXISTING_AUTHORIZATION_ADMISSION_LEASE_GATE_PASSES';
  elsif jsonb_array_length(v_existing_hard)>0 then
    v_gate:='BLOCKED_BY_EXISTING_GOVERNANCE';
    v_recommendation:='STOP_AND_RESOLVE_EXISTING_HARD_GATE_MIRRORS';
  elsif v_known_recurrence then
    v_recommendation:='STOP_AND_REVIEW_KNOWN_DIAGNOSTIC_BEFORE_ACTION';
  end if;

  if v_known_recurrence and exists(
    select 1 from public.world8_guardian_companion_sessions c where c.dev_session_id=p_dev_session_id and c.status='ACTIVE'
  ) then
    perform public.world8_guardian_record_event_v1(
      p_dev_session_id,
      'ADVISORY',
      'REQUIRED',
      'ADVISORY_ONLY',
      v_action_tags,
      p_target_ref,
      p_action_kind,
      'Known Diagnostic Memory recurrence risk surfaced before action. Review the matching Incident/Signature/Playbook/Test Contract before proceeding.',
      jsonb_build_object('diagnostic_search',v_diag,'target_ref',p_target_ref,'known_recurrence_risk',true),
      jsonb_build_array('diagnostic-memory:tag-context','pre-action:known-recurrence')
    );
  end if;

  return jsonb_build_object(
    'schema','WORLD8_GUARDIAN_PRE_ACTION/1.1',
    'dev_session_id',p_dev_session_id,
    'action_kind',p_action_kind,
    'target_ref',p_target_ref,
    'target_artifact_id',p_target_artifact_id,
    'existing_governance_gate',v_gate,
    'current_write_lease',v_lease,
    'existing_hard_gate_mirrors',v_existing_hard,
    'diagnostic_context_tags',to_jsonb(v_action_tags),
    'diagnostic_search',v_diag,
    'known_recurrence_risk',v_known_recurrence,
    'recommendation',v_recommendation,
    'guardian_creates_authority',false,
    'guardian_hard_block',false,
    'guardian_mode','ADVISORY_ONLY_MIRROR_EXISTING_GATES',
    'observation',v_observe
  );
end $$;

-- Least-privilege: preserve existing execution surface; no table DML grants are added here.
-- Runtime application must be reviewed with current grants before deployment.
