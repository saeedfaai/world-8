-- World 8 Engineering Guardian v0.1.1
-- Repair a false positive where diagnostic/error identifiers such as
-- GUARDIAN_PRIVATE_REASONING_REJECTED were mistaken for private reasoning content.
-- Privacy remains fail-closed for explicit private-reasoning keys and natural-language content.

create or replace function public.world8_guardian_payload_has_private_reasoning_v1(p_payload jsonb)
returns boolean
language plpgsql
immutable
set search_path to 'public'
as $function$
declare
  v_key text;
  v_norm_key text;
  v_value jsonb;
  v_text text;
begin
  if p_payload is null then return false; end if;
  if jsonb_typeof(p_payload)='object' then
    for v_key,v_value in select key,value from jsonb_each(p_payload) loop
      v_norm_key:=lower(regexp_replace(v_key,'[^a-zA-Z0-9]','','g'));
      if v_norm_key in ('chainofthought','reasoningtrace','privatereasoning') then
        return true;
      end if;
      if jsonb_typeof(v_value)='string' and v_norm_key in ('analysis','reasoning','trace','text','content','message') then
        v_text:=trim(both '"' from v_value::text);
        if v_text ~* '(chain[ -]+of[ -]+thought|reasoning[ -]+trace|private[ -]+reasoning)' then
          return true;
        end if;
      end if;
      if jsonb_typeof(v_value) in ('object','array') and public.world8_guardian_payload_has_private_reasoning_v1(v_value) then
        return true;
      end if;
    end loop;
  elsif jsonb_typeof(p_payload)='array' then
    for v_value in select value from jsonb_array_elements(p_payload) loop
      if jsonb_typeof(v_value) in ('object','array') and public.world8_guardian_payload_has_private_reasoning_v1(v_value) then
        return true;
      end if;
    end loop;
  end if;
  return false;
end $function$;

create or replace function public.world8_guardian_record_event_v1(p_dev_session_id text, p_event_kind text, p_severity text, p_enforcement_mode text, p_context_tags text[], p_subject_ref text, p_action_kind text, p_summary text, p_payload jsonb, p_evidence_refs jsonb)
returns jsonb
language plpgsql
security definer
set search_path to 'public','extensions'
as $function$
declare v_s public.world8_dev_session_liveness%rowtype; v_c public.world8_guardian_companion_sessions%rowtype; v_now timestamptz:=clock_timestamp(); v_id text; v_hash text; v_body jsonb; v_scan text;
begin
 if p_event_kind not in ('WELCOME','CONTEXT','OBSERVATION','ADVISORY','QUESTION','ANSWER_HINT','RECOVERY') then raise exception 'GUARDIAN_EVENT_KIND_INVALID'; end if;
 if p_severity not in ('INFO','ADVICE','WARNING','REQUIRED','BLOCK_MIRROR') then raise exception 'GUARDIAN_SEVERITY_INVALID'; end if;
 if p_enforcement_mode not in ('ADVISORY_ONLY','MIRROR_EXISTING_GATE') then raise exception 'GUARDIAN_ENFORCEMENT_MODE_INVALID'; end if;
 if length(coalesce(p_summary,''))>1200 then raise exception 'GUARDIAN_SUMMARY_TOO_LONG'; end if;
 v_scan:=coalesce(p_summary,'')||' '||coalesce(p_payload,'{}'::jsonb)::text;
 if v_scan ~* '(password|api[_ -]?key|access[_ -]?token|secret)[[:space:]\\\"'']*[:=][[:space:]\\\"'']*[^, }[:space:]]+' then raise exception 'GUARDIAN_RAW_SECRET_REJECTED'; end if;
 if coalesce(p_summary,'') ~* '(chain[ -]+of[ -]+thought|reasoning[ -]+trace|private[ -]+reasoning)' or public.world8_guardian_payload_has_private_reasoning_v1(coalesce(p_payload,'{}'::jsonb)) then raise exception 'GUARDIAN_PRIVATE_REASONING_REJECTED'; end if;
 select * into v_s from public.world8_dev_session_liveness where session_id=p_dev_session_id; if not found then raise exception 'DEV_SESSION_NOT_FOUND'; end if;
 select * into v_c from public.world8_guardian_companion_sessions where dev_session_id=p_dev_session_id; if not found then raise exception 'GUARDIAN_COMPANION_NOT_ATTACHED'; end if;
 v_body:=jsonb_build_object('issued_by_service','service-world8-engineering-guardian','authorized_by',null,'authority_effect','NONE','policy_revision','guardian-policy-v0.1','companion_id',v_c.companion_id,'session_id',p_dev_session_id,'work_id',v_s.work_id,'actor_id',v_s.actor_id,'event_kind',p_event_kind,'severity',p_severity,'enforcement_mode',p_enforcement_mode,'context_tags',to_jsonb(coalesce(p_context_tags,array[]::text[])),'subject_ref',p_subject_ref,'action_kind',p_action_kind,'summary',p_summary,'payload',coalesce(p_payload,'{}'::jsonb),'evidence_refs',coalesce(p_evidence_refs,'[]'::jsonb),'created_at',v_now);
 v_hash:=encode(extensions.digest(convert_to(v_body::text,'UTF8'),'sha256'),'hex'); v_id:='guardian-event-'||substr(v_hash,1,28);
 insert into public.world8_guardian_context_events(event_id,companion_id,dev_session_id,work_id,actor_id,event_kind,severity,enforcement_mode,context_tags,subject_ref,action_kind,summary,payload,evidence_refs,content_hash,created_at,issued_by_service,policy_revision,authority_effect)
 values(v_id,v_c.companion_id,p_dev_session_id,v_s.work_id,v_s.actor_id,p_event_kind,p_severity,p_enforcement_mode,coalesce(p_context_tags,array[]::text[]),p_subject_ref,p_action_kind,p_summary,coalesce(p_payload,'{}'::jsonb),coalesce(p_evidence_refs,'[]'::jsonb),v_hash,v_now,'service-world8-engineering-guardian','guardian-policy-v0.1','NONE') on conflict(event_id) do nothing;
 return jsonb_build_object('schema','WORLD8_GUARDIAN_EVENT/1.2','event_id',v_id,'content_hash',v_hash,'created_at',v_now,'issued_by_service','service-world8-engineering-guardian','authorized_by',null,'authority_effect','NONE','policy_revision','guardian-policy-v0.1');
end $function$;
