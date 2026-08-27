-- World 8 Engineering Guardian policy/attribution hardening v0.1.1
-- Guardian is a SYSTEM SERVICE, not an Actor, and has no authority effect.
create table if not exists public.world8_guardian_policy_revisions (
  policy_revision text primary key,
  service_id text not null,
  service_kind text not null check (service_kind='SYSTEM_SERVICE'),
  authority_mode text not null check (authority_mode='NONE'),
  status text not null check (status in ('FREEZE_CANDIDATE','FROZEN','RETIRED')),
  policy jsonb not null,
  source_refs jsonb not null default '[]'::jsonb,
  approved_by_ref text null,
  frozen_at timestamptz null,
  content_hash text not null,
  created_at timestamptz not null default clock_timestamp()
);
create or replace function public.world8_guardian_prevent_policy_mutation_v1() returns trigger language plpgsql security definer set search_path=public as $$ begin raise exception 'WORLD8_GUARDIAN_POLICY_APPEND_ONLY'; end $$;
drop trigger if exists world8_guardian_policy_append_only_trg on public.world8_guardian_policy_revisions;
create trigger world8_guardian_policy_append_only_trg before update or delete on public.world8_guardian_policy_revisions for each row execute function public.world8_guardian_prevent_policy_mutation_v1();

alter table public.world8_guardian_companion_sessions add column if not exists guardian_service_id text not null default 'service-world8-engineering-guardian';
alter table public.world8_guardian_companion_sessions add column if not exists policy_revision text not null default 'guardian-policy-v0.1';
alter table public.world8_guardian_context_events add column if not exists issued_by_service text not null default 'service-world8-engineering-guardian';
alter table public.world8_guardian_context_events add column if not exists policy_revision text not null default 'guardian-policy-v0.1';
alter table public.world8_guardian_context_events add column if not exists authority_effect text not null default 'NONE' check (authority_effect='NONE');

with p as (select jsonb_build_object(
 'service_kind','SYSTEM_SERVICE','authority','NONE','companion_state','STATELESS','auto_fix','DISABLED_V0_1','new_block_mode','MIRROR_EXISTING_HARD_GATES_ONLY',
 'sensitive_sync_actions',jsonb_build_array('CANONICAL_WRITE','SCHEMA_CHANGE','CONTRACT_CHANGE','AUTHORITY_ACTION','LEASE_ACQUISITION','LOCK_ACQUISITION','MERGE','DEPLOY','RELEASE'),
 'fail_closed',jsonb_build_array('AUTHORITY','SCHEMA_CHANGE','CONTRACT_CHANGE','LEASE','LOCK','MERGE','DEPLOY','RELEASE','WRITE_OUTSIDE_WORKSPACE'),
 'fail_open_with_warning',jsonb_build_array('READ','SEARCH','LOCAL_ISOLATED_WORKSPACE_WRITE','SUGGESTION'),
 'context_precedence',jsonb_build_array('ACTIVE_WORK','ARTIFACT_DB_OBJECT_PUBLIC_CONTRACT','CODE_SHADOW','FILE','TOOL_COMMAND','ERROR_SIGNATURE','TAGS','GIT_ENVIRONMENT'),
 'preload',jsonb_build_array('ACTOR_IDENTITY','WORK','WORKSPACE','QUALIFICATION','ACTIVE_LEASES_CONFLICTS','LATEST_CHECKPOINT','RECENT_RELEVANT_INCIDENTS'),
 'on_demand',jsonb_build_array('FULL_CODE_SHADOW','DEPENDENCY_GRAPH','ADR_HISTORY','FULL_PLAYBOOK','LONG_CHANGE_HISTORY'),
 'advice_freshness',jsonb_build_object('requires',jsonb_build_array('EVIDENCE_REF','ARCHITECTURE_VERSION','SCHEMA_VERSION','EXPIRY'),'version_change_state','NEEDS_REVALIDATION'),
 'semantic_overlap_v01',jsonb_build_array('ARTIFACT_DEPENDENCY','WORK_GRAPH','DB_OBJECT','PUBLIC_CONTRACT','SEMANTIC_DOMAIN_TAG'),
 'message_classes',jsonb_build_array('FACT','WARNING','SUGGESTION','POLICY'),'evidence_required_for',jsonb_build_array('WARNING','POLICY'),
 'propagation_scopes',jsonb_build_array('GLOBAL','SOCIETY','ARTIFACT','TAG','TOOL','ENVIRONMENT'),
 'policy_change_path','PROPOSAL_REVIEW_ADR_APPROVAL_FROZEN_REVISION','override_policy','DEFERRED_V0_2') as j)
insert into public.world8_guardian_policy_revisions(policy_revision,service_id,service_kind,authority_mode,status,policy,source_refs,approved_by_ref,frozen_at,content_hash)
select 'guardian-policy-v0.1','service-world8-engineering-guardian','SYSTEM_SERVICE','NONE','FROZEN',j,
 jsonb_build_array('consultation:claude','consultation:deepseek','consultation:grok','human-root:proceed'),'human-root',clock_timestamp(),encode(extensions.digest(convert_to(j::text,'UTF8'),'sha256'),'hex') from p
on conflict(policy_revision) do nothing;

create or replace function public.world8_guardian_policy_v1() returns jsonb language sql stable security definer set search_path=public as $$
 select jsonb_build_object('schema','WORLD8_GUARDIAN_POLICY/1.0','policy_revision',policy_revision,'service_id',service_id,'service_kind',service_kind,'authority_mode',authority_mode,'status',status,'policy',policy,'source_refs',source_refs,'approved_by_ref',approved_by_ref,'frozen_at',frozen_at,'content_hash',content_hash) from public.world8_guardian_policy_revisions where policy_revision='guardian-policy-v0.1'; $$;

create or replace function public.world8_guardian_welcome_v1(p_dev_session_id text,p_refresh boolean default false) returns jsonb language plpgsql security definer set search_path=public as $$
declare v_c public.world8_guardian_companion_sessions%rowtype; v_a jsonb; v_w jsonb;
begin
 select * into v_c from public.world8_guardian_companion_sessions where dev_session_id=p_dev_session_id;
 if not found or p_refresh then v_a:=public.world8_guardian_attach_v1(p_dev_session_id,null); v_w:=v_a->'welcome'; else v_w:=v_c.welcome_snapshot; end if;
 return coalesce(v_w,'{}'::jsonb)||jsonb_build_object('issued_by_service','service-world8-engineering-guardian','authorized_by',null,'authority_effect','NONE','policy_revision','guardian-policy-v0.1');
end $$;

create or replace function public.world8_guardian_record_event_v1(p_dev_session_id text,p_event_kind text,p_severity text,p_enforcement_mode text,p_context_tags text[],p_subject_ref text,p_action_kind text,p_summary text,p_payload jsonb,p_evidence_refs jsonb)
returns jsonb language plpgsql security definer set search_path=public,extensions as $$
declare v_s public.world8_dev_session_liveness%rowtype; v_c public.world8_guardian_companion_sessions%rowtype; v_now timestamptz:=clock_timestamp(); v_id text; v_hash text; v_body jsonb; v_scan text;
begin
 if p_event_kind not in ('WELCOME','CONTEXT','OBSERVATION','ADVISORY','QUESTION','ANSWER_HINT','RECOVERY') then raise exception 'GUARDIAN_EVENT_KIND_INVALID'; end if;
 if p_severity not in ('INFO','ADVICE','WARNING','REQUIRED','BLOCK_MIRROR') then raise exception 'GUARDIAN_SEVERITY_INVALID'; end if;
 if p_enforcement_mode not in ('ADVISORY_ONLY','MIRROR_EXISTING_GATE') then raise exception 'GUARDIAN_ENFORCEMENT_MODE_INVALID'; end if;
 if length(coalesce(p_summary,''))>1200 then raise exception 'GUARDIAN_SUMMARY_TOO_LONG'; end if;
 v_scan:=coalesce(p_summary,'')||' '||coalesce(p_payload,'{}'::jsonb)::text;
 if v_scan ~* '(password|api[_ -]?key|access[_ -]?token|secret)[[:space:]\"'']*[:=][[:space:]\"'']*[^, }[:space:]]+' then raise exception 'GUARDIAN_RAW_SECRET_REJECTED'; end if;
 if v_scan ~* '(chain[_ -]?of[_ -]?thought|reasoning[_ -]?trace|private[_ -]?reasoning)' then raise exception 'GUARDIAN_PRIVATE_REASONING_REJECTED'; end if;
 select * into v_s from public.world8_dev_session_liveness where session_id=p_dev_session_id; if not found then raise exception 'DEV_SESSION_NOT_FOUND'; end if;
 select * into v_c from public.world8_guardian_companion_sessions where dev_session_id=p_dev_session_id; if not found then raise exception 'GUARDIAN_COMPANION_NOT_ATTACHED'; end if;
 v_body:=jsonb_build_object('issued_by_service','service-world8-engineering-guardian','authorized_by',null,'authority_effect','NONE','policy_revision','guardian-policy-v0.1','companion_id',v_c.companion_id,'session_id',p_dev_session_id,'work_id',v_s.work_id,'actor_id',v_s.actor_id,'event_kind',p_event_kind,'severity',p_severity,'enforcement_mode',p_enforcement_mode,'context_tags',to_jsonb(coalesce(p_context_tags,array[]::text[])),'subject_ref',p_subject_ref,'action_kind',p_action_kind,'summary',p_summary,'payload',coalesce(p_payload,'{}'::jsonb),'evidence_refs',coalesce(p_evidence_refs,'[]'::jsonb),'created_at',v_now);
 v_hash:=encode(extensions.digest(convert_to(v_body::text,'UTF8'),'sha256'),'hex'); v_id:='guardian-event-'||substr(v_hash,1,28);
 insert into public.world8_guardian_context_events(event_id,companion_id,dev_session_id,work_id,actor_id,event_kind,severity,enforcement_mode,context_tags,subject_ref,action_kind,summary,payload,evidence_refs,content_hash,created_at,issued_by_service,policy_revision,authority_effect)
 values(v_id,v_c.companion_id,p_dev_session_id,v_s.work_id,v_s.actor_id,p_event_kind,p_severity,p_enforcement_mode,coalesce(p_context_tags,array[]::text[]),p_subject_ref,p_action_kind,p_summary,coalesce(p_payload,'{}'::jsonb),coalesce(p_evidence_refs,'[]'::jsonb),v_hash,v_now,'service-world8-engineering-guardian','guardian-policy-v0.1','NONE') on conflict(event_id) do nothing;
 return jsonb_build_object('schema','WORLD8_GUARDIAN_EVENT/1.2','event_id',v_id,'content_hash',v_hash,'created_at',v_now,'issued_by_service','service-world8-engineering-guardian','authorized_by',null,'authority_effect','NONE','policy_revision','guardian-policy-v0.1');
end $$;

revoke all on table public.world8_guardian_policy_revisions from public,anon,authenticated;
grant select on table public.world8_guardian_policy_revisions to service_role;
revoke all on function public.world8_guardian_policy_v1() from public,anon,authenticated;
grant execute on function public.world8_guardian_policy_v1() to service_role;