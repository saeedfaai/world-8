-- World 8 Engineering Guardian Foundation v0.1
-- Advisory orchestration only. Reuses canonical Work/Session/Authority/Diagnostic/Code Shadow/Dispatch truth.

create table if not exists public.world8_guardian_companion_sessions (
  companion_id text primary key,
  world_id text not null default 'world-001',
  dev_session_id text not null unique references public.world8_dev_session_liveness(session_id),
  work_id text not null references public.world8_dev_work_items(work_id),
  actor_id text not null references public.world8_actor_registry(actor_id),
  execution_id text null,
  workspace_id text not null references public.world8_dev_workspaces(workspace_id),
  source_room text not null,
  status text not null check (status in ('ACTIVE','CLOSED')),
  authority_mode text not null default 'ADVISORY_ONLY' check (authority_mode='ADVISORY_ONLY'),
  context_tags text[] not null default array[]::text[],
  current_context jsonb not null default '{}'::jsonb,
  welcome_snapshot jsonb not null default '{}'::jsonb,
  welcome_count integer not null default 0 check (welcome_count>=0),
  last_welcome_at timestamptz null,
  last_context_at timestamptz null,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default clock_timestamp(),
  updated_at timestamptz not null default clock_timestamp()
);
create index if not exists world8_guardian_companion_work_idx on public.world8_guardian_companion_sessions(work_id,status);
create index if not exists world8_guardian_companion_actor_idx on public.world8_guardian_companion_sessions(actor_id,status);

create table if not exists public.world8_guardian_context_events (
  event_id text primary key,
  companion_id text not null references public.world8_guardian_companion_sessions(companion_id),
  dev_session_id text not null references public.world8_dev_session_liveness(session_id),
  work_id text not null references public.world8_dev_work_items(work_id),
  actor_id text not null references public.world8_actor_registry(actor_id),
  event_kind text not null check (event_kind in ('WELCOME','CONTEXT','OBSERVATION','ADVISORY','QUESTION','ANSWER_HINT','RECOVERY')),
  severity text not null check (severity in ('INFO','ADVICE','WARNING','REQUIRED','BLOCK_MIRROR')),
  enforcement_mode text not null default 'ADVISORY_ONLY' check (enforcement_mode in ('ADVISORY_ONLY','MIRROR_EXISTING_GATE')),
  context_tags text[] not null default array[]::text[],
  subject_ref text null,
  action_kind text null,
  summary text not null,
  payload jsonb not null default '{}'::jsonb,
  evidence_refs jsonb not null default '[]'::jsonb,
  content_hash text not null,
  created_at timestamptz not null default clock_timestamp()
);
create index if not exists world8_guardian_events_session_idx on public.world8_guardian_context_events(dev_session_id,created_at desc);
create index if not exists world8_guardian_events_work_idx on public.world8_guardian_context_events(work_id,created_at desc);
create index if not exists world8_guardian_events_tags_gin on public.world8_guardian_context_events using gin(context_tags);

create or replace function public.world8_guardian_prevent_event_mutation_v1()
returns trigger language plpgsql security definer set search_path=public as $$
begin raise exception 'WORLD8_GUARDIAN_EVENTS_APPEND_ONLY'; end $$;
drop trigger if exists world8_guardian_events_append_only_trg on public.world8_guardian_context_events;
create trigger world8_guardian_events_append_only_trg before update or delete on public.world8_guardian_context_events
for each row execute function public.world8_guardian_prevent_event_mutation_v1();

create or replace function public.world8_guardian_context_classify_v1(
  p_work_id text,p_artifact_ids jsonb default '[]'::jsonb,p_paths jsonb default '[]'::jsonb,
  p_db_objects jsonb default '[]'::jsonb,p_tool_kind text default null,p_action_kind text default null,p_error_code text default null
) returns jsonb language plpgsql stable security definer set search_path=public as $$
declare v_w public.world8_dev_work_items%rowtype; v_text text:=''; v_tags text[]:=array['WORLD','MASON'];
begin
  select * into v_w from public.world8_dev_work_items where work_id=p_work_id; if not found then raise exception 'WORK_NOT_FOUND'; end if;
  if jsonb_typeof(coalesce(p_artifact_ids,'[]'::jsonb))<>'array' or jsonb_typeof(coalesce(p_paths,'[]'::jsonb))<>'array' or jsonb_typeof(coalesce(p_db_objects,'[]'::jsonb))<>'array' then raise exception 'GUARDIAN_CONTEXT_ARRAYS_REQUIRED'; end if;
  v_text:=lower(concat_ws(' ',v_w.goal,v_w.architecture_ref,v_w.touches::text,coalesce(p_artifact_ids,'[]'::jsonb)::text,coalesce(p_paths,'[]'::jsonb)::text,coalesce(p_db_objects,'[]'::jsonb)::text,p_tool_kind,p_action_kind,p_error_code));
  if v_text ~ '(database|postgres|sql|table|column|migration|schema|supabase|rpc)' then v_tags:=array_append(v_tags,'DATABASE'); end if;
  if v_text ~ '(supabase|edge function)' then v_tags:=array_append(v_tags,'SUPABASE'); end if;
  if v_text ~ '(schema|column|field|migration)' then v_tags:=array_append(v_tags,'SCHEMA'); end if;
  if v_text ~ '(github|git|branch|commit|pull request|\bpr\b|workflow|ci)' then v_tags:=array_append(v_tags,'GITHUB'); end if;
  if v_text ~ '(lease|fencing|cas|concurr|stale|overlap|merge)' then v_tags:=array_append(v_tags,'CONCURRENCY'); end if;
  if v_text ~ '(auth|authority|authorization|admission|permission|capability)' then v_tags:=array_append(v_tags,'AUTH'); v_tags:=array_append(v_tags,'SECURITY'); end if;
  if v_text ~ '(secret|credential|token|api[_ -]?key|password)' then v_tags:=array_append(v_tags,'SECRETS'); v_tags:=array_append(v_tags,'SECURITY'); end if;
  if v_text ~ '(resume|recovery|checkpoint|restore|reconnect|crash)' then v_tags:=array_append(v_tags,'RECOVERY'); end if;
  if v_text ~ '(dcp|development control|mason|workspace|work claim|postflight|handoff)' then v_tags:=array_append(v_tags,'DCP'); end if;
  if v_text ~ '(api|rpc|webhook|provider|connector)' then v_tags:=array_append(v_tags,'API'); end if;
  if v_text ~ '(code shadow|shadow manifest)' then v_tags:=array_append(v_tags,'CODE_SHADOW'); end if;
  if v_text ~ '(backup|mirror|export|continuity)' then v_tags:=array_append(v_tags,'BACKUP'); end if;
  if v_text ~ '(trading|market|forecast|order|portfolio)' then v_tags:=array_append(v_tags,'TRADING'); end if;
  if v_text ~ '(company|sales|supplier|customer)' then v_tags:=array_append(v_tags,'COMPANY'); end if;
  if v_text ~ '(telegram|bot)' then v_tags:=array_append(v_tags,'TELEGRAM'); end if;
  select coalesce(array_agg(distinct x order by x),array[]::text[]) into v_tags from unnest(v_tags) x where exists(select 1 from public.world8_diag_tags t where t.tag_key=x and t.status='ACTIVE');
  return jsonb_build_object('schema','WORLD8_GUARDIAN_CONTEXT_CLASS/1.0','work_id',p_work_id,'tags',to_jsonb(v_tags),'tool_kind',p_tool_kind,'action_kind',p_action_kind,'error_code',p_error_code,'classifier_mode','DETERMINISTIC_CANONICAL_TAGS');
end $$;

create or replace function public.world8_guardian_awareness_snapshot_v1(p_work_id text,p_actor_id text)
returns jsonb language plpgsql stable security definer set search_path=public as $$
declare
  v_w public.world8_dev_work_items%rowtype; v_canonical jsonb:='{}'::jsonb; v_head text; v_sessions jsonb:='[]'::jsonb; v_workspaces jsonb:='[]'::jsonb; v_leases jsonb:='[]'::jsonb; v_overlaps jsonb:='[]'::jsonb; v_other_leases jsonb:='[]'::jsonb; v_admission jsonb:='{}'::jsonb; v_hard jsonb:='[]'::jsonb; v_base text;
begin
  select * into v_w from public.world8_dev_work_items where work_id=p_work_id; if not found then raise exception 'WORK_NOT_FOUND'; end if; if v_w.actor_ref<>p_actor_id then raise exception 'WORK_ACTOR_MISMATCH'; end if;
  select coalesce(jsonb_build_object('resource_id',resource_id,'uri',uri,'status',status,'metadata',metadata,'updated_at',updated_at),'{}'::jsonb) into v_canonical from public.world8_dev_external_resources where resource_id='resource-github-world8-canonical'; v_head:=v_canonical->'metadata'->>'canonical_head_commit';
  select coalesce(jsonb_agg(jsonb_build_object('session_id',session_id,'actor_id',actor_id,'source_room',source_room,'workspace_id',workspace_id,'status',status,'last_heartbeat_at',last_heartbeat_at,'last_checkpoint_at',last_checkpoint_at,'checkpoint_due_at',checkpoint_due_at) order by started_at),'[]'::jsonb) into v_sessions from public.world8_dev_session_liveness where work_id=p_work_id;
  select coalesce(jsonb_agg(jsonb_build_object('workspace_id',workspace_id,'repo_ref',repo_ref,'branch_ref',branch_ref,'base_commit',base_commit,'state',state,'access_mode',access_mode) order by updated_at desc),'[]'::jsonb) into v_workspaces from public.world8_dev_workspaces where work_id=p_work_id;
  select coalesce(jsonb_agg(jsonb_build_object('lease_id',lease_id,'artifact_id',artifact_id,'status',status,'mode',mode,'fencing_token',fencing_token,'expires_at',expires_at) order by issued_at desc),'[]'::jsonb) into v_leases from public.world8_dev_leases where work_id=p_work_id;
  select coalesce(jsonb_agg(jsonb_build_object('work_id',o.work_id,'actor_ref',o.actor_ref,'source_room',o.source_room,'goal',o.goal,'touches',o.touches,'development_state',o.development_state,'updated_at',o.updated_at) order by o.updated_at desc),'[]'::jsonb) into v_overlaps from public.world8_dev_work_items o where o.work_id<>p_work_id and o.development_state in ('CLAIMED','IMPLEMENTING','IMPLEMENTED','BLOCKED') and o.deployment_state<>'RETIRED' and exists(select 1 from jsonb_array_elements_text(coalesce(v_w.touches,'[]'::jsonb)) a join jsonb_array_elements_text(coalesce(o.touches,'[]'::jsonb)) b on a.value=b.value) and exists(select 1 from public.world8_dev_session_liveness s where s.work_id=o.work_id and s.status='ACTIVE');
  select coalesce(jsonb_agg(jsonb_build_object('lease_id',l.lease_id,'work_id',l.work_id,'artifact_id',l.artifact_id,'holder_ref',l.holder_ref,'mode',l.mode,'fencing_token',l.fencing_token,'expires_at',l.expires_at) order by l.artifact_id,l.fencing_token desc),'[]'::jsonb) into v_other_leases from public.world8_dev_leases l where l.work_id<>p_work_id and l.status='ACTIVE' and l.expires_at>clock_timestamp() and exists(select 1 from jsonb_array_elements_text(coalesce(v_w.touches,'[]'::jsonb)) a where a.value=l.artifact_id);
  select coalesce(jsonb_build_object('admission_id',admission_id,'gate_state',gate_state,'qualification_result',qualification_result,'authorization_result',authorization_result,'workspace_result',workspace_result,'issued_at',issued_at,'expires_at',expires_at),'{}'::jsonb) into v_admission from public.world8_dev_admission_receipts where work_id=p_work_id order by issued_at desc limit 1;
  select base_commit into v_base from public.world8_dev_workspaces where work_id=p_work_id and state='ACTIVE' order by updated_at desc limit 1;
  if v_base is not null and v_head is not null and v_base<>v_head then v_hard:=v_hard||jsonb_build_array(jsonb_build_object('code','STALE_CANONICAL_BASE','source','EXISTING_WORKSPACE_FRESHNESS_GATE','base_commit',v_base,'canonical_head',v_head)); end if;
  if jsonb_array_length(v_other_leases)>0 then v_hard:=v_hard||jsonb_build_array(jsonb_build_object('code','ACTIVE_OVERLAPPING_LEASE','source','EXISTING_LEASE_GATE','leases',v_other_leases)); end if;
  if v_admission<>'{}'::jsonb and coalesce(v_admission->>'gate_state','BLOCKED')<>'PASS' then v_hard:=v_hard||jsonb_build_array(jsonb_build_object('code','ADMISSION_NOT_PASS','source','EXISTING_ADMISSION_GATE','admission',v_admission)); end if;
  return jsonb_build_object('schema','WORLD8_GUARDIAN_AWARENESS/1.0','work_id',p_work_id,'actor_id',p_actor_id,'canonical',v_canonical,'sessions',v_sessions,'workspaces',v_workspaces,'leases',v_leases,'overlapping_active_works',v_overlaps,'other_active_leases',v_other_leases,'latest_admission',v_admission,'hard_gate_mirrors',v_hard,'guardian_authority','NONE','policy_mode','ADVISORY_ONLY_MIRROR_EXISTING_GATES','generated_at',clock_timestamp());
end $$;

create or replace function public.world8_guardian_diagnostic_advisory_v1(p_work_id text,p_context_tags jsonb default '[]'::jsonb,p_query text default null,p_artifact_ids jsonb default '[]'::jsonb)
returns jsonb language plpgsql stable security definer set search_path=public as $$
declare v_tag text; v_tag_hits jsonb:='[]'::jsonb; v_query_hits jsonb:='{}'::jsonb; v_shadows jsonb:='[]'::jsonb; v_compat jsonb:='[]'::jsonb; v_art text;
begin
  if jsonb_typeof(coalesce(p_context_tags,'[]'::jsonb))<>'array' or jsonb_typeof(coalesce(p_artifact_ids,'[]'::jsonb))<>'array' then raise exception 'GUARDIAN_DIAGNOSTIC_ARRAYS_REQUIRED'; end if;
  if coalesce(trim(p_query),'')<>'' then v_query_hits:=public.world8_diag_search_v2(p_query,null,null,20); end if;
  for v_tag in select jsonb_array_elements_text(coalesce(p_context_tags,'[]'::jsonb)) loop v_tag_hits:=v_tag_hits||jsonb_build_array(jsonb_build_object('tag',v_tag,'search',public.world8_diag_search_v2(null,array[v_tag],null,8))); end loop;
  for v_art in select jsonb_array_elements_text(coalesce(p_artifact_ids,'[]'::jsonb)) loop v_shadows:=v_shadows||jsonb_build_array(public.world8_code_shadow_lookup_v1(v_art)); v_compat:=v_compat||jsonb_build_array(public.world8_diag_compatibility_lookup_v1(v_art)); end loop;
  return jsonb_build_object('schema','WORLD8_GUARDIAN_DIAGNOSTIC_ADVISORY/1.0','work_id',p_work_id,'context_tags',coalesce(p_context_tags,'[]'::jsonb),'query_matches',v_query_hits,'tag_matches',v_tag_hits,'code_shadows',v_shadows,'compatibility',v_compat,'source_of_truth','CANONICAL_DIAGNOSTIC_MEMORY_AND_CODE_SHADOW','generated_at',clock_timestamp());
end $$;

create or replace function public.world8_guardian_context_bundle_v1(p_dev_session_id text,p_artifact_ids jsonb default '[]'::jsonb,p_paths jsonb default '[]'::jsonb,p_db_objects jsonb default '[]'::jsonb,p_tool_kind text default null,p_action_kind text default null,p_error_code text default null,p_query text default null)
returns jsonb language plpgsql stable security definer set search_path=public as $$
declare v_s public.world8_dev_session_liveness%rowtype; v_ctx jsonb; v_tags jsonb; v_aw jsonb; v_diag jsonb; v_resume jsonb; v_dispatch jsonb:='[]'::jsonb; v_subs jsonb:='[]'::jsonb; v_artifacts jsonb;
begin
  select * into v_s from public.world8_dev_session_liveness where session_id=p_dev_session_id; if not found then raise exception 'DEV_SESSION_NOT_FOUND'; end if;
  v_artifacts:=case when jsonb_array_length(coalesce(p_artifact_ids,'[]'::jsonb))>0 then p_artifact_ids else coalesce((select touches from public.world8_dev_work_items where work_id=v_s.work_id),'[]'::jsonb) end;
  v_ctx:=public.world8_guardian_context_classify_v1(v_s.work_id,v_artifacts,p_paths,p_db_objects,p_tool_kind,p_action_kind,p_error_code); v_tags:=v_ctx->'tags';
  v_aw:=public.world8_guardian_awareness_snapshot_v1(v_s.work_id,v_s.actor_id); v_diag:=public.world8_guardian_diagnostic_advisory_v1(v_s.work_id,v_tags,p_query,v_artifacts); v_resume:=public.world8_dev_resume_capsule_v2(v_s.work_id);
  select coalesce(jsonb_agg(jsonb_build_object('message_id',m.message_id,'thread_id',m.thread_id,'sender_ref',m.sender_ref,'message_type',m.message_type,'subject',m.subject,'body',m.body,'priority',m.priority,'requires_ack',m.requires_ack,'state',m.state,'linked_refs',m.linked_refs,'created_at',m.created_at) order by m.created_at desc),'[]'::jsonb) into v_dispatch from (select * from public.world8_internal_messages where recipient_refs ? v_s.actor_id order by created_at desc limit 20) m;
  select coalesce(jsonb_agg(jsonb_build_object('subscription_id',subscription_id,'match_kind',match_kind,'match_value',match_value,'status',status,'metadata',metadata) order by updated_at desc),'[]'::jsonb) into v_subs from public.world8_dispatch_subscriptions where actor_id=v_s.actor_id and status='ACTIVE';
  return jsonb_build_object('schema','WORLD8_GUARDIAN_CONTEXT_BUNDLE/1.0','dev_session_id',p_dev_session_id,'work_id',v_s.work_id,'actor_id',v_s.actor_id,'workspace_id',v_s.workspace_id,'context',v_ctx,'resume',v_resume,'awareness',v_aw,'diagnostic_advisory',v_diag,'dispatch_messages',v_dispatch,'dispatch_subscriptions',v_subs,'authority_boundary','Guardian does not grant authorization, admission, lease, merge, promotion or canonical mutation authority.','consultation_pending',true,'generated_at',clock_timestamp());
end $$;

create or replace function public.world8_guardian_record_event_v1(p_dev_session_id text,p_event_kind text,p_severity text,p_enforcement_mode text,p_context_tags text[],p_subject_ref text,p_action_kind text,p_summary text,p_payload jsonb,p_evidence_refs jsonb)
returns jsonb language plpgsql security definer set search_path=public,extensions as $$
declare v_s public.world8_dev_session_liveness%rowtype; v_c public.world8_guardian_companion_sessions%rowtype; v_now timestamptz:=clock_timestamp(); v_id text; v_hash text; v_body jsonb;
begin
  if p_event_kind not in ('WELCOME','CONTEXT','OBSERVATION','ADVISORY','QUESTION','ANSWER_HINT','RECOVERY') then raise exception 'GUARDIAN_EVENT_KIND_INVALID'; end if;
  if p_severity not in ('INFO','ADVICE','WARNING','REQUIRED','BLOCK_MIRROR') then raise exception 'GUARDIAN_SEVERITY_INVALID'; end if;
  if p_enforcement_mode not in ('ADVISORY_ONLY','MIRROR_EXISTING_GATE') then raise exception 'GUARDIAN_ENFORCEMENT_MODE_INVALID'; end if;
  select * into v_s from public.world8_dev_session_liveness where session_id=p_dev_session_id; if not found then raise exception 'DEV_SESSION_NOT_FOUND'; end if;
  select * into v_c from public.world8_guardian_companion_sessions where dev_session_id=p_dev_session_id; if not found then raise exception 'GUARDIAN_COMPANION_NOT_ATTACHED'; end if;
  v_body:=jsonb_build_object('companion_id',v_c.companion_id,'session_id',p_dev_session_id,'work_id',v_s.work_id,'actor_id',v_s.actor_id,'event_kind',p_event_kind,'severity',p_severity,'enforcement_mode',p_enforcement_mode,'context_tags',to_jsonb(coalesce(p_context_tags,array[]::text[])),'subject_ref',p_subject_ref,'action_kind',p_action_kind,'summary',p_summary,'payload',coalesce(p_payload,'{}'::jsonb),'evidence_refs',coalesce(p_evidence_refs,'[]'::jsonb),'created_at',v_now);
  v_hash:=encode(extensions.digest(convert_to(v_body::text,'UTF8'),'sha256'),'hex'); v_id:='guardian-event-'||substr(v_hash,1,28);
  insert into public.world8_guardian_context_events(event_id,companion_id,dev_session_id,work_id,actor_id,event_kind,severity,enforcement_mode,context_tags,subject_ref,action_kind,summary,payload,evidence_refs,content_hash,created_at)
  values(v_id,v_c.companion_id,p_dev_session_id,v_s.work_id,v_s.actor_id,p_event_kind,p_severity,p_enforcement_mode,coalesce(p_context_tags,array[]::text[]),p_subject_ref,p_action_kind,p_summary,coalesce(p_payload,'{}'::jsonb),coalesce(p_evidence_refs,'[]'::jsonb),v_hash,v_now) on conflict(event_id) do nothing;
  return jsonb_build_object('schema','WORLD8_GUARDIAN_EVENT/1.0','event_id',v_id,'content_hash',v_hash,'created_at',v_now);
end $$;

create or replace function public.world8_guardian_attach_v1(p_dev_session_id text,p_actor_id text default null)
returns jsonb language plpgsql security definer set search_path=public,extensions as $$
declare v_s public.world8_dev_session_liveness%rowtype; v_id text; v_now timestamptz:=clock_timestamp(); v_exists boolean:=false; v_bundle jsonb; v_tags text[]:=array[]::text[]; v_welcome jsonb;
begin
  select * into v_s from public.world8_dev_session_liveness where session_id=p_dev_session_id; if not found then raise exception 'DEV_SESSION_NOT_FOUND'; end if; if p_actor_id is not null and v_s.actor_id<>p_actor_id then raise exception 'GUARDIAN_SESSION_ACTOR_MISMATCH'; end if;
  select exists(select 1 from public.world8_guardian_companion_sessions where dev_session_id=p_dev_session_id) into v_exists; v_id:='guardian-companion-'||substr(encode(extensions.digest(convert_to(p_dev_session_id,'UTF8'),'sha256'),'hex'),1,28);
  insert into public.world8_guardian_companion_sessions(companion_id,dev_session_id,work_id,actor_id,execution_id,workspace_id,source_room,status,authority_mode,metadata)
  values(v_id,v_s.session_id,v_s.work_id,v_s.actor_id,v_s.execution_id,v_s.workspace_id,v_s.source_room,case when v_s.status='CLOSED' then 'CLOSED' else 'ACTIVE' end,'ADVISORY_ONLY',jsonb_build_object('auto_attach',true,'provider_independent',true))
  on conflict(dev_session_id) do update set status=excluded.status,execution_id=excluded.execution_id,workspace_id=excluded.workspace_id,updated_at=v_now returning companion_id into v_id;
  v_bundle:=public.world8_guardian_context_bundle_v1(p_dev_session_id,'[]'::jsonb,'[]'::jsonb,'[]'::jsonb,null,'SESSION_START',null,'welcome'); select coalesce(array_agg(x),array[]::text[]) into v_tags from jsonb_array_elements_text(v_bundle->'context'->'tags') x;
  v_welcome:=jsonb_build_object('schema','WORLD8_GUARDIAN_WELCOME/1.0','companion_id',v_id,'dev_session_id',p_dev_session_id,'actor_id',v_s.actor_id,'work_id',v_s.work_id,'workspace_id',v_s.workspace_id,'source_room',v_s.source_room,'message','Welcome to World 8 Engineering. Guardian is attached to this session and will surface relevant architecture, diagnostics, conflicts, advisories and existing safety gates as context changes.','context_tags',to_jsonb(v_tags),'resume_state',v_bundle->'resume'->>'resume_state','next_safe_action',v_bundle->'resume'->>'next_safe_action','awareness',v_bundle->'awareness','diagnostic_advisory',v_bundle->'diagnostic_advisory','dispatch_messages',v_bundle->'dispatch_messages','authority_boundary',v_bundle->>'authority_boundary','consultation_pending',true,'generated_at',v_now);
  update public.world8_guardian_companion_sessions set context_tags=v_tags,current_context=v_bundle,welcome_snapshot=v_welcome,welcome_count=welcome_count+1,last_welcome_at=v_now,last_context_at=v_now,updated_at=v_now where companion_id=v_id;
  if not v_exists then perform public.world8_guardian_record_event_v1(p_dev_session_id,'WELCOME','INFO','ADVISORY_ONLY',v_tags,'world8://engineering/guardian-v0.1','SESSION_START','Guardian attached and Welcome Bundle generated.',v_welcome,jsonb_build_array('work:'||v_s.work_id,'session:'||p_dev_session_id,'workspace:'||v_s.workspace_id)); end if;
  return jsonb_build_object('schema','WORLD8_GUARDIAN_ATTACH/1.0','companion_id',v_id,'already_attached',v_exists,'welcome',v_welcome);
end $$;

create or replace function public.world8_guardian_welcome_v1(p_dev_session_id text,p_refresh boolean default false)
returns jsonb language plpgsql security definer set search_path=public as $$
declare v_c public.world8_guardian_companion_sessions%rowtype; v_a jsonb;
begin select * into v_c from public.world8_guardian_companion_sessions where dev_session_id=p_dev_session_id; if not found or p_refresh then v_a:=public.world8_guardian_attach_v1(p_dev_session_id,null); return v_a->'welcome'; end if; return v_c.welcome_snapshot; end $$;

create or replace function public.world8_guardian_observe_v1(p_dev_session_id text,p_artifact_ids jsonb default '[]'::jsonb,p_paths jsonb default '[]'::jsonb,p_db_objects jsonb default '[]'::jsonb,p_tool_kind text default null,p_action_kind text default null,p_error_code text default null,p_query text default null,p_payload jsonb default '{}'::jsonb)
returns jsonb language plpgsql security definer set search_path=public as $$
declare v_bundle jsonb; v_tags text[]:=array[]::text[]; v_hard jsonb; v_sev text:='ADVICE'; v_mode text:='ADVISORY_ONLY'; v_event jsonb; v_id text;
begin
  if not exists(select 1 from public.world8_guardian_companion_sessions where dev_session_id=p_dev_session_id) then perform public.world8_guardian_attach_v1(p_dev_session_id,null); end if;
  v_bundle:=public.world8_guardian_context_bundle_v1(p_dev_session_id,p_artifact_ids,p_paths,p_db_objects,p_tool_kind,p_action_kind,p_error_code,p_query); select coalesce(array_agg(x),array[]::text[]) into v_tags from jsonb_array_elements_text(v_bundle->'context'->'tags') x; v_hard:=coalesce(v_bundle->'awareness'->'hard_gate_mirrors','[]'::jsonb);
  if jsonb_array_length(v_hard)>0 then v_sev:='BLOCK_MIRROR'; v_mode:='MIRROR_EXISTING_GATE'; elsif p_error_code is not null then v_sev:='WARNING'; else v_sev:='ADVICE'; end if;
  v_event:=public.world8_guardian_record_event_v1(p_dev_session_id,'OBSERVATION',v_sev,v_mode,v_tags,coalesce(p_action_kind,p_tool_kind),p_action_kind,'Guardian context observation completed.',jsonb_build_object('input',coalesce(p_payload,'{}'::jsonb),'bundle',v_bundle),jsonb_build_array('work:'||(v_bundle->>'work_id'),'session:'||p_dev_session_id));
  select companion_id into v_id from public.world8_guardian_companion_sessions where dev_session_id=p_dev_session_id; update public.world8_guardian_companion_sessions set context_tags=v_tags,current_context=v_bundle,last_context_at=clock_timestamp(),updated_at=clock_timestamp() where companion_id=v_id;
  return jsonb_build_object('schema','WORLD8_GUARDIAN_OBSERVATION/1.0','severity',v_sev,'enforcement_mode',v_mode,'event',v_event,'context_bundle',v_bundle,'note','BLOCK_MIRROR never creates new authority; it only reflects existing canonical hard gates.');
end $$;

create or replace function public.world8_guardian_ask_v1(p_dev_session_id text,p_question text,p_focus jsonb default '{}'::jsonb)
returns jsonb language plpgsql security definer set search_path=public as $$
declare v_bundle jsonb; v_tags text[]:=array[]::text[]; v_event jsonb;
begin
  if coalesce(trim(p_question),'')='' then raise exception 'GUARDIAN_QUESTION_REQUIRED'; end if; if not exists(select 1 from public.world8_guardian_companion_sessions where dev_session_id=p_dev_session_id) then perform public.world8_guardian_attach_v1(p_dev_session_id,null); end if;
  v_bundle:=public.world8_guardian_context_bundle_v1(p_dev_session_id,coalesce(p_focus->'artifact_ids','[]'::jsonb),coalesce(p_focus->'paths','[]'::jsonb),coalesce(p_focus->'db_objects','[]'::jsonb),p_focus->>'tool_kind',p_focus->>'action_kind',p_focus->>'error_code',p_question); select coalesce(array_agg(x),array[]::text[]) into v_tags from jsonb_array_elements_text(v_bundle->'context'->'tags') x;
  v_event:=public.world8_guardian_record_event_v1(p_dev_session_id,'QUESTION','INFO','ADVISORY_ONLY',v_tags,null,p_focus->>'action_kind','Guardian dialogue question received.',jsonb_build_object('question',p_question,'focus',coalesce(p_focus,'{}'::jsonb)),jsonb_build_array('session:'||p_dev_session_id,'work:'||(v_bundle->>'work_id')));
  return jsonb_build_object('schema','WORLD8_GUARDIAN_DIALOGUE_CONTEXT/1.0','question',p_question,'context_bundle',v_bundle,'requires_brain',true,'response_contract',jsonb_build_object('grounding','Use only bundle evidence plus explicitly fetched canonical evidence.','claim_classes',jsonb_build_array('FACT','WARNING','SUGGESTION','POLICY'),'evidence_refs_required_for_policy_or_warning',true,'authority_rule','Never infer or grant authority from Guardian advice.','private_reasoning','Do not store chain-of-thought; store concise operational answer/receipt only.'),'question_event',v_event);
end $$;

create or replace function public.world8_guardian_session_checkpoint_attach_trg_v1()
returns trigger language plpgsql security definer set search_path=public as $$
begin if new.checkpoint_kind='SESSION_START' then perform public.world8_guardian_attach_v1(new.session_id,new.actor_id); end if; return new; end $$;
drop trigger if exists world8_guardian_session_checkpoint_attach_trg on public.world8_dev_session_checkpoints;
create trigger world8_guardian_session_checkpoint_attach_trg after insert on public.world8_dev_session_checkpoints for each row when (new.checkpoint_kind='SESSION_START') execute function public.world8_guardian_session_checkpoint_attach_trg_v1();

create or replace function public.world8_guardian_session_status_sync_trg_v1()
returns trigger language plpgsql security definer set search_path=public as $$
begin if old.status is distinct from new.status then update public.world8_guardian_companion_sessions set status=case when new.status='CLOSED' then 'CLOSED' else 'ACTIVE' end,updated_at=clock_timestamp() where dev_session_id=new.session_id; end if; return new; end $$;
drop trigger if exists world8_guardian_session_status_sync_trg on public.world8_dev_session_liveness;
create trigger world8_guardian_session_status_sync_trg after update of status on public.world8_dev_session_liveness for each row execute function public.world8_guardian_session_status_sync_trg_v1();

revoke all on public.world8_guardian_companion_sessions from public,anon,authenticated;
revoke all on public.world8_guardian_context_events from public,anon,authenticated;
revoke execute on function public.world8_guardian_context_classify_v1(text,jsonb,jsonb,jsonb,text,text,text) from public,anon,authenticated;
revoke execute on function public.world8_guardian_awareness_snapshot_v1(text,text) from public,anon,authenticated;
revoke execute on function public.world8_guardian_diagnostic_advisory_v1(text,jsonb,text,jsonb) from public,anon,authenticated;
revoke execute on function public.world8_guardian_context_bundle_v1(text,jsonb,jsonb,jsonb,text,text,text,text) from public,anon,authenticated;
revoke execute on function public.world8_guardian_record_event_v1(text,text,text,text,text[],text,text,text,jsonb,jsonb) from public,anon,authenticated;
revoke execute on function public.world8_guardian_attach_v1(text,text) from public,anon,authenticated;
revoke execute on function public.world8_guardian_welcome_v1(text,boolean) from public,anon,authenticated;
revoke execute on function public.world8_guardian_observe_v1(text,jsonb,jsonb,jsonb,text,text,text,text,jsonb) from public,anon,authenticated;
revoke execute on function public.world8_guardian_ask_v1(text,text,jsonb) from public,anon,authenticated;
grant select,insert,update on public.world8_guardian_companion_sessions to service_role;
grant select,insert on public.world8_guardian_context_events to service_role;
grant execute on function public.world8_guardian_context_classify_v1(text,jsonb,jsonb,jsonb,text,text,text) to service_role;
grant execute on function public.world8_guardian_awareness_snapshot_v1(text,text) to service_role;
grant execute on function public.world8_guardian_diagnostic_advisory_v1(text,jsonb,text,jsonb) to service_role;
grant execute on function public.world8_guardian_context_bundle_v1(text,jsonb,jsonb,jsonb,text,text,text,text) to service_role;
grant execute on function public.world8_guardian_record_event_v1(text,text,text,text,text[],text,text,text,jsonb,jsonb) to service_role;
grant execute on function public.world8_guardian_attach_v1(text,text) to service_role;
grant execute on function public.world8_guardian_welcome_v1(text,boolean) to service_role;
grant execute on function public.world8_guardian_observe_v1(text,jsonb,jsonb,jsonb,text,text,text,text,jsonb) to service_role;
grant execute on function public.world8_guardian_ask_v1(text,text,jsonb) to service_role;
