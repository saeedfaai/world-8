-- World 8 Crash-Safe Development Continuity v0.1.1 — enforcement
-- New developer Work is crash-safe by default. Review/Handoff/Postflight fail closed
-- when required progress/checkpoint/closure evidence is missing.

create or replace function public.world8_dev_work_crash_safe_default_v1()
returns trigger language plpgsql security definer set search_path='public' as $$
begin
  new.metadata := coalesce(new.metadata,'{}'::jsonb) || jsonb_build_object(
    'crash_safe_required', true,
    'crash_safe_policy_version', '0.1.1'
  );
  return new;
end;
$$;

drop trigger if exists world8_dev_work_crash_safe_default_trg on public.world8_dev_work_items;
create trigger world8_dev_work_crash_safe_default_trg
before insert on public.world8_dev_work_items
for each row execute function public.world8_dev_work_crash_safe_default_v1();

create or replace function public.world8_dev_scribe_guard_v1(
  p_work_id text,
  p_actor_id text default null,
  p_source_room text default null
) returns jsonb
language plpgsql security definer set search_path='public' as $$
declare
  v_now timestamptz:=clock_timestamp();
  v_sessions jsonb:='[]'::jsonb;
  v_blockers jsonb:='[]'::jsonb;
  r record;
  v_dirty integer;
  v_latest public.world8_dev_session_checkpoints%rowtype;
begin
  for r in
    select * from public.world8_dev_session_liveness s
    where s.work_id=p_work_id and s.status='ACTIVE'
      and (p_actor_id is null or s.actor_id=p_actor_id)
      and (p_source_room is null or s.source_room=p_source_room)
    order by s.started_at
  loop
    v_latest:=null;
    select * into v_latest
    from public.world8_dev_session_checkpoints c
    where c.session_id=r.session_id
    order by c.created_at desc limit 1;

    select count(*) into v_dirty
    from public.world8_dev_session_journal j
    where j.session_id=r.session_id and j.requires_checkpoint
      and (v_latest.created_at is null or j.created_at>v_latest.created_at);

    v_sessions:=v_sessions||jsonb_build_array(jsonb_build_object(
      'session_id',r.session_id,'source_room',r.source_room,
      'last_heartbeat_at',r.last_heartbeat_at,
      'heartbeat_age_seconds',extract(epoch from (v_now-r.last_heartbeat_at))::integer,
      'last_checkpoint_id',v_latest.checkpoint_id,'last_checkpoint_at',v_latest.created_at,
      'next_safe_action',v_latest.next_safe_action,'dirty_checkpoint_events',v_dirty,
      'checkpoint_due',(v_now>=r.checkpoint_due_at or v_dirty>0),
      'checkpoint_due_at',r.checkpoint_due_at,
      'crash_suspected',(v_now-r.last_heartbeat_at>make_interval(secs=>r.crash_after_seconds))
    ));

    if v_latest.checkpoint_id is null then
      v_blockers:=v_blockers||jsonb_build_array(jsonb_build_object('code','CHECKPOINT_REQUIRED','session_id',r.session_id));
    end if;
    if v_dirty>0 then
      v_blockers:=v_blockers||jsonb_build_array(jsonb_build_object('code','UNCHECKPOINTED_PROGRESS','session_id',r.session_id,'count',v_dirty));
    end if;
    if v_now>=r.checkpoint_due_at then
      v_blockers:=v_blockers||jsonb_build_array(jsonb_build_object('code','CHECKPOINT_INTERVAL_EXCEEDED','session_id',r.session_id,'checkpoint_due_at',r.checkpoint_due_at));
    end if;
    if v_latest.checkpoint_id is not null and coalesce(btrim(v_latest.next_safe_action),'')='' then
      v_blockers:=v_blockers||jsonb_build_array(jsonb_build_object('code','NEXT_SAFE_ACTION_REQUIRED','session_id',r.session_id));
    end if;
  end loop;

  if jsonb_array_length(v_sessions)=0 then
    v_blockers:=v_blockers||jsonb_build_array(jsonb_build_object('code','ACTIVE_DEV_SESSION_REQUIRED'));
  end if;

  return jsonb_build_object(
    'schema','WORLD8_SCRIBE_GUARD/1.1','work_id',p_work_id,
    'gate_state',case when jsonb_array_length(v_blockers)=0 then 'PASS' else 'BLOCKED' end,
    'blockers',v_blockers,'sessions',v_sessions,'observed_at',v_now
  );
end;
$$;

create or replace function public.world8_dev_scribe_closure_guard_v1(
  p_work_id text,
  p_actor_id text default null,
  p_source_room text default null
) returns jsonb
language plpgsql security definer set search_path='public' as $$
declare
  v_work public.world8_dev_work_items%rowtype;
  v_required boolean:=false;
  v_sessions jsonb:='[]'::jsonb;
  v_blockers jsonb:='[]'::jsonb;
  v_latest_closure text;
  v_count integer:=0;
  v_dirty integer;
  r record;
  v_cp public.world8_dev_session_checkpoints%rowtype;
begin
  select * into v_work from public.world8_dev_work_items where work_id=p_work_id;
  if not found then raise exception 'WORK_NOT_FOUND'; end if;

  v_required:=coalesce((v_work.metadata->>'crash_safe_required')::boolean,false);
  if not v_required then
    return jsonb_build_object('schema','WORLD8_SCRIBE_CLOSURE_GUARD/1.0','work_id',p_work_id,'required',false,'gate_state','PASS','state','LEGACY_NOT_REQUIRED','blockers','[]'::jsonb,'sessions','[]'::jsonb);
  end if;

  for r in
    select * from public.world8_dev_session_liveness s
    where s.work_id=p_work_id
      and (p_actor_id is null or s.actor_id=p_actor_id)
      and (p_source_room is null or s.source_room=p_source_room)
    order by s.started_at
  loop
    v_count:=v_count+1;
    v_cp:=null;
    select * into v_cp from public.world8_dev_session_checkpoints c
      where c.session_id=r.session_id order by c.created_at desc limit 1;

    select count(*) into v_dirty from public.world8_dev_session_journal j
      where j.session_id=r.session_id and j.requires_checkpoint
        and (v_cp.created_at is null or j.created_at>v_cp.created_at);

    v_sessions:=v_sessions||jsonb_build_array(jsonb_build_object(
      'session_id',r.session_id,'status',r.status,'source_room',r.source_room,
      'last_checkpoint_id',v_cp.checkpoint_id,'last_checkpoint_kind',v_cp.checkpoint_kind,
      'last_checkpoint_at',v_cp.created_at,'next_safe_action',v_cp.next_safe_action,
      'dirty_checkpoint_events',v_dirty,'closed_at',r.closed_at
    ));

    if r.status='ACTIVE' then
      v_blockers:=v_blockers||jsonb_build_array(jsonb_build_object('code','ACTIVE_DEV_SESSION_MUST_CLOSE','session_id',r.session_id));
    elsif r.status='STALE' then
      v_blockers:=v_blockers||jsonb_build_array(jsonb_build_object('code','STALE_SESSION_RECOVERY_REQUIRED','session_id',r.session_id));
    end if;
    if v_cp.checkpoint_id is null then
      v_blockers:=v_blockers||jsonb_build_array(jsonb_build_object('code','CLOSURE_CHECKPOINT_REQUIRED','session_id',r.session_id));
    elsif r.status='CLOSED' and v_cp.checkpoint_kind<>'BEFORE_HANDOFF' then
      v_blockers:=v_blockers||jsonb_build_array(jsonb_build_object('code','BEFORE_HANDOFF_CHECKPOINT_REQUIRED','session_id',r.session_id,'observed_kind',v_cp.checkpoint_kind));
    end if;
    if v_dirty>0 then
      v_blockers:=v_blockers||jsonb_build_array(jsonb_build_object('code','UNCHECKPOINTED_PROGRESS','session_id',r.session_id,'count',v_dirty));
    end if;
    if v_cp.checkpoint_id is not null and coalesce(btrim(v_cp.next_safe_action),'')='' then
      v_blockers:=v_blockers||jsonb_build_array(jsonb_build_object('code','NEXT_SAFE_ACTION_REQUIRED','session_id',r.session_id));
    end if;
  end loop;

  if v_count=0 then
    v_blockers:=v_blockers||jsonb_build_array(jsonb_build_object('code','DEV_SESSION_REQUIRED'));
  end if;

  select c.checkpoint_id into v_latest_closure
  from public.world8_dev_session_checkpoints c
  join public.world8_dev_session_liveness s on s.session_id=c.session_id
  where c.work_id=p_work_id and s.status='CLOSED' and c.checkpoint_kind='BEFORE_HANDOFF'
    and (p_actor_id is null or s.actor_id=p_actor_id)
    and (p_source_room is null or s.source_room=p_source_room)
  order by c.created_at desc limit 1;

  return jsonb_build_object(
    'schema','WORLD8_SCRIBE_CLOSURE_GUARD/1.0','work_id',p_work_id,'required',true,
    'gate_state',case when jsonb_array_length(v_blockers)=0 then 'PASS' else 'BLOCKED' end,
    'blockers',v_blockers,'sessions',v_sessions,
    'latest_closure_checkpoint_id',v_latest_closure,'observed_at',clock_timestamp()
  );
end;
$$;

create or replace function public.world8_dev_record_handoff_v1(
  p_work_id text, p_created_by text, p_architecture_ref text, p_lease_id text,
  p_base_revision jsonb, p_working_revision jsonb, p_completed jsonb, p_remaining jsonb,
  p_artifacts_touched jsonb, p_files_changed jsonb, p_db_objects_touched jsonb,
  p_migrations_applied jsonb, p_tests_passed jsonb, p_tests_failed jsonb,
  p_evidence_refs jsonb, p_decisions jsonb, p_adr_refs jsonb, p_known_issues jsonb,
  p_open_conflicts jsonb, p_external_effects_attempted jsonb, p_ambiguous_effects jsonb,
  p_required_capabilities jsonb, p_next_safe_action text, p_do_not_do jsonb, p_environment_ref jsonb
) returns jsonb
language plpgsql security definer set search_path='public','extensions' as $$
declare
  v_id text; v_now timestamptz:=clock_timestamp();
  v_work public.world8_dev_work_items%rowtype;
  v_scribe jsonb:='{}'::jsonb;
  v_evidence jsonb;
begin
  select * into v_work from public.world8_dev_work_items where work_id=p_work_id;
  if not found then raise exception 'WORK_NOT_FOUND'; end if;
  if v_work.actor_ref<>p_created_by then raise exception 'WORK_ACTOR_MISMATCH'; end if;
  if coalesce(btrim(p_next_safe_action),'')='' then raise exception 'NEXT_SAFE_ACTION_REQUIRED'; end if;

  if coalesce((v_work.metadata->>'crash_safe_required')::boolean,false) then
    v_scribe:=public.world8_dev_scribe_closure_guard_v1(p_work_id,null,null);
    if coalesce(v_scribe->>'gate_state','BLOCKED')<>'PASS' then
      raise exception 'SCRIBE_CLOSURE_REQUIRED' using detail=v_scribe::text;
    end if;
  end if;

  v_evidence:=coalesce(p_evidence_refs,'[]'::jsonb);
  if coalesce(v_scribe->>'latest_closure_checkpoint_id','')<>'' then
    v_evidence:=v_evidence||jsonb_build_array('checkpoint:'||(v_scribe->>'latest_closure_checkpoint_id'));
  end if;

  v_id:='handoff-'||substr(encode(extensions.digest(p_work_id||'|'||p_created_by||'|'||v_now::text,'sha256'),'hex'),1,28);
  insert into public.world8_dev_handoffs(
    handoff_id,work_id,architecture_ref,lease_id,base_revision,working_revision,completed,remaining,
    artifacts_touched,files_changed,db_objects_touched,migrations_applied,tests_passed,tests_failed,
    evidence_refs,decisions,adr_refs,known_issues,open_conflicts,external_effects_attempted,ambiguous_effects,
    required_capabilities,next_safe_action,do_not_do,environment_ref,created_by,created_at
  ) values(
    v_id,p_work_id,p_architecture_ref,p_lease_id,coalesce(p_base_revision,'{}'::jsonb),coalesce(p_working_revision,'{}'::jsonb),
    coalesce(p_completed,'[]'::jsonb),coalesce(p_remaining,'[]'::jsonb),coalesce(p_artifacts_touched,'[]'::jsonb),
    coalesce(p_files_changed,'[]'::jsonb),coalesce(p_db_objects_touched,'[]'::jsonb),coalesce(p_migrations_applied,'[]'::jsonb),
    coalesce(p_tests_passed,'[]'::jsonb),coalesce(p_tests_failed,'[]'::jsonb),v_evidence,coalesce(p_decisions,'[]'::jsonb),
    coalesce(p_adr_refs,'[]'::jsonb),coalesce(p_known_issues,'[]'::jsonb),coalesce(p_open_conflicts,'[]'::jsonb),
    coalesce(p_external_effects_attempted,'[]'::jsonb),coalesce(p_ambiguous_effects,'[]'::jsonb),coalesce(p_required_capabilities,'[]'::jsonb),
    p_next_safe_action,coalesce(p_do_not_do,'[]'::jsonb),coalesce(p_environment_ref,'{}'::jsonb)||jsonb_build_object('scribe_guard',v_scribe),p_created_by,v_now
  );
  return jsonb_build_object('handoff_id',v_id,'work_id',p_work_id,'created_at',v_now,'scribe_guard',v_scribe);
end;
$$;

create or replace function public.world8_mason_postflight_v1(
  p_actor_ref text,p_source_room text,p_work_id text,p_change_packet_ref text,p_handoff_ref text,
  p_runtime_snapshot_ref text,p_mirror_sync_refs jsonb,p_diagnostic_incident_refs jsonb,p_unresolved jsonb
) returns jsonb
language plpgsql security definer set search_path='public','extensions' as $$
declare
  v_work public.world8_dev_work_items%rowtype;
  v_change public.world8_dev_change_packets%rowtype;
  v_now timestamptz:=clock_timestamp();
  v_stale jsonb:='[]'::jsonb;
  v_required_mirror_fail jsonb:='[]'::jsonb;
  v_blockers jsonb:='[]'::jsonb;
  v_gate text:='PASS';
  v_breaking_propagated boolean:=true;
  v_scribe jsonb:='{}'::jsonb;
  v_check jsonb; v_hash text; v_id text;
begin
  select * into v_work from public.world8_dev_work_items where work_id=p_work_id;
  if not found then raise exception 'WORK_NOT_FOUND'; end if;
  if v_work.actor_ref<>p_actor_ref then raise exception 'WORK_ACTOR_MISMATCH'; end if;
  if v_work.source_room<>p_source_room then raise exception 'WORK_ROOM_MISMATCH'; end if;

  if coalesce((v_work.metadata->>'crash_safe_required')::boolean,false) then
    v_scribe:=public.world8_dev_scribe_closure_guard_v1(p_work_id,null,null);
    if coalesce(v_scribe->>'gate_state','BLOCKED')<>'PASS' then
      v_blockers:=v_blockers||jsonb_build_array(jsonb_build_object('code','SCRIBE_CLOSURE_REQUIRED','details',v_scribe));
    end if;
    if p_handoff_ref is null or not exists(select 1 from public.world8_dev_handoffs h where h.handoff_id=p_handoff_ref and h.work_id=p_work_id) then
      v_blockers:=v_blockers||jsonb_build_array(jsonb_build_object('code','HANDOFF_REQUIRED_AFTER_SCRIBE_CLOSURE'));
    end if;
  end if;

  select coalesce(jsonb_agg(jsonb_build_object('artifact_id',a.artifact_id,'artifact_revision',a.artifact_revision)),'[]'::jsonb) into v_stale
  from public.world8_dev_artifacts a
  where a.artifact_id in (select value from jsonb_array_elements_text(coalesce(v_work.touches,'[]'::jsonb)))
    and not exists(select 1 from public.world8_code_shadow_manifests s where s.artifact_id=a.artifact_id and s.status='ACTIVE' and s.completeness_state='COMPLETE' and s.artifact_revision=a.artifact_revision);
  if jsonb_array_length(v_stale)>0 then v_blockers:=v_blockers||jsonb_build_array(jsonb_build_object('code','CODE_SHADOW_STALE_OR_MISSING','artifacts',v_stale)); end if;

  select coalesce(jsonb_agg(jsonb_build_object('mirror_id',m.mirror_id,'status',coalesce(s.status,'MISSING'))),'[]'::jsonb) into v_required_mirror_fail
  from public.world8_mirror_targets m
  left join lateral (select csr.status,csr.observed_at from public.world8_continuity_sync_receipts csr where csr.mirror_id=m.mirror_id and csr.work_id=p_work_id order by csr.observed_at desc limit 1) s on true
  where m.required_for_postflight and m.status in ('ACTIVE','DEGRADED') and coalesce(s.status,'MISSING')<>'PASS';
  if jsonb_array_length(v_required_mirror_fail)>0 then v_blockers:=v_blockers||jsonb_build_array(jsonb_build_object('code','REQUIRED_MIRROR_NOT_SYNCED','mirrors',v_required_mirror_fail)); end if;

  if p_change_packet_ref is null then
    v_blockers:=v_blockers||jsonb_build_array(jsonb_build_object('code','CHANGE_PACKET_REQUIRED'));
  else
    select * into v_change from public.world8_dev_change_packets where change_id=p_change_packet_ref;
    if not found then
      v_blockers:=v_blockers||jsonb_build_array(jsonb_build_object('code','CHANGE_PACKET_NOT_FOUND','change_id',p_change_packet_ref));
    elsif v_change.breaking then
      select exists(select 1 from public.world8_dev_change_impact_receipts where change_id=p_change_packet_ref and propagation_state='ROUTED') into v_breaking_propagated;
      if not v_breaking_propagated then v_blockers:=v_blockers||jsonb_build_array(jsonb_build_object('code','BREAKING_CHANGE_PROPAGATION_REQUIRED','change_id',p_change_packet_ref)); end if;
    end if;
  end if;

  if jsonb_array_length(v_blockers)>0 then v_gate:='BLOCKED';
  elsif jsonb_array_length(coalesce(p_unresolved,'[]'::jsonb))>0 then v_gate:='PARTIAL';
  else v_gate:='PASS'; end if;

  v_check:=jsonb_build_object(
    'shadow_current',jsonb_array_length(v_stale)=0,
    'required_mirrors_synced',jsonb_array_length(v_required_mirror_fail)=0,
    'change_packet_present',p_change_packet_ref is not null,
    'breaking_change',coalesce(v_change.breaking,false),
    'breaking_change_propagated',v_breaking_propagated,
    'handoff_ref',p_handoff_ref,'runtime_snapshot_ref',p_runtime_snapshot_ref,'scribe_guard',v_scribe
  );

  v_hash:=encode(extensions.digest(p_actor_ref||'|'||p_source_room||'|'||p_work_id||'|'||coalesce(p_change_packet_ref,'')||'|'||v_check::text||'|'||coalesce(p_unresolved,'[]'::jsonb)::text||'|'||v_now::text,'sha256'),'hex');
  v_id:='mason-postflight-'||substr(v_hash,1,28);
  insert into public.world8_mason_postflight_receipts(postflight_receipt_id,actor_ref,source_room,work_id,change_packet_ref,handoff_ref,runtime_snapshot_ref,mirror_sync_refs,diagnostic_incident_refs,checklist,blockers,unresolved,gate_state,content_hash,created_at)
  values(v_id,p_actor_ref,p_source_room,p_work_id,p_change_packet_ref,p_handoff_ref,p_runtime_snapshot_ref,coalesce(p_mirror_sync_refs,'[]'::jsonb),coalesce(p_diagnostic_incident_refs,'[]'::jsonb),v_check,v_blockers,coalesce(p_unresolved,'[]'::jsonb),v_gate,v_hash,v_now);
  return jsonb_build_object('postflight_receipt_id',v_id,'gate_state',v_gate,'blockers',v_blockers,'checklist',v_check,'content_hash',v_hash);
end;
$$;

revoke all on function public.world8_dev_scribe_closure_guard_v1(text,text,text) from public,anon,authenticated;
grant execute on function public.world8_dev_scribe_closure_guard_v1(text,text,text) to service_role;

comment on function public.world8_dev_scribe_closure_guard_v1(text,text,text) is 'Fail-closed closure guard for crash-safe developer Work. Requires all sessions closed/recovered with final BEFORE_HANDOFF checkpoints.';
