-- World 8 Crash-Safe Development v0.1.2
-- Closure-aware Resume Capsule. Reuses canonical Work/Session/Handoff/Postflight stores.
create or replace function public.world8_dev_resume_capsule_v2(p_work_id text)
returns jsonb
language plpgsql
security definer
set search_path='public'
as $$
declare
  v_w public.world8_dev_work_items%rowtype;
  v_canonical jsonb:='{}'::jsonb;
  v_sessions jsonb:='[]'::jsonb;
  v_checkpoint jsonb:='{}'::jsonb;
  v_checkpoint_next text;
  v_tail jsonb:='[]'::jsonb;
  v_workspaces jsonb:='[]'::jsonb;
  v_leases jsonb:='[]'::jsonb;
  v_handoff jsonb:='{}'::jsonb;
  v_handoff_next text;
  v_postflight jsonb:='{}'::jsonb;
  v_postflight_gate text;
  v_active_count integer:=0;
  v_active_scribe jsonb:='{}'::jsonb;
  v_closure_guard jsonb:='{}'::jsonb;
  v_resume_state text;
  v_next text;
  v_next_source text;
begin
  select * into v_w from public.world8_dev_work_items where work_id=p_work_id;
  if not found then raise exception 'WORK_NOT_FOUND'; end if;

  select coalesce(jsonb_build_object('resource_id',resource_id,'uri',uri,'status',status,'metadata',metadata,'updated_at',updated_at),'{}'::jsonb)
    into v_canonical
  from public.world8_dev_external_resources
  where resource_id='resource-github-world8-canonical';
  v_canonical:=coalesce(v_canonical,'{}'::jsonb);

  select count(*) into v_active_count
  from public.world8_dev_session_liveness s
  where s.work_id=p_work_id and s.status='ACTIVE';

  select coalesce(jsonb_agg(to_jsonb(s) order by s.started_at),'[]'::jsonb)
    into v_sessions
  from public.world8_dev_session_liveness s where s.work_id=p_work_id;

  select to_jsonb(c),c.next_safe_action
    into v_checkpoint,v_checkpoint_next
  from public.world8_dev_session_checkpoints c
  where c.work_id=p_work_id order by c.created_at desc limit 1;
  v_checkpoint:=coalesce(v_checkpoint,'{}'::jsonb);

  select coalesce(jsonb_agg(x.obj order by x.work_seq),'[]'::jsonb)
    into v_tail
  from (
    select j.work_seq,jsonb_build_object(
      'event_id',j.event_id,'work_seq',j.work_seq,'session_id',j.session_id,'source_room',j.source_room,
      'event_kind',j.event_kind,'summary',j.summary,'requires_checkpoint',j.requires_checkpoint,
      'next_safe_action',j.next_safe_action,'content_hash',j.content_hash,'created_at',j.created_at
    ) obj
    from public.world8_dev_session_journal j
    where j.work_id=p_work_id order by j.work_seq desc limit 20
  ) x;

  select coalesce(jsonb_agg(jsonb_build_object(
      'workspace_id',workspace_id,'actor_id',actor_id,'branch_ref',branch_ref,'base_commit',base_commit,
      'state',state,'updated_at',updated_at) order by updated_at desc),'[]'::jsonb)
    into v_workspaces
  from public.world8_dev_workspaces where work_id=p_work_id;

  select coalesce(jsonb_agg(jsonb_build_object(
      'lease_id',lease_id,'artifact_id',artifact_id,'holder_ref',holder_ref,'status',status,
      'fencing_token',fencing_token,'expires_at',expires_at,'last_heartbeat_at',last_heartbeat_at)
      order by issued_at desc),'[]'::jsonb)
    into v_leases
  from public.world8_dev_leases where work_id=p_work_id;

  select to_jsonb(h),h.next_safe_action
    into v_handoff,v_handoff_next
  from public.world8_dev_handoffs h
  where h.work_id=p_work_id order by h.created_at desc limit 1;
  v_handoff:=coalesce(v_handoff,'{}'::jsonb);

  select jsonb_build_object(
      'postflight_receipt_id',p.postflight_receipt_id,'gate_state',p.gate_state,'blockers',p.blockers,
      'unresolved',p.unresolved,'handoff_ref',p.handoff_ref,'change_packet_ref',p.change_packet_ref,
      'runtime_snapshot_ref',p.runtime_snapshot_ref,'created_at',p.created_at),p.gate_state
    into v_postflight,v_postflight_gate
  from public.world8_mason_postflight_receipts p
  where p.work_id=p_work_id order by p.created_at desc limit 1;
  v_postflight:=coalesce(v_postflight,'{}'::jsonb);

  v_closure_guard:=public.world8_dev_scribe_closure_guard_v1(p_work_id,null,null);

  if v_active_count>0 then
    v_active_scribe:=public.world8_dev_scribe_guard_v1(p_work_id,null,null);
    v_next:=coalesce(v_checkpoint_next,v_w.goal);
    v_next_source:=case when v_checkpoint_next is not null then 'LATEST_CHECKPOINT' else 'WORK_GOAL' end;
    v_resume_state:=case when coalesce(v_active_scribe->>'gate_state','BLOCKED')='PASS' then 'ACTIVE_CLEAN' else 'ACTIVE_BLOCKED' end;
  else
    v_active_scribe:=jsonb_build_object(
      'schema','WORLD8_SCRIBE_GUARD/1.1','work_id',p_work_id,'gate_state','NOT_APPLICABLE',
      'blockers','[]'::jsonb,'sessions','[]'::jsonb,'reason','NO_ACTIVE_SESSION','observed_at',clock_timestamp());
    v_next:=coalesce(v_handoff_next,v_checkpoint_next,v_w.goal);
    v_next_source:=case when v_handoff_next is not null then 'FINAL_HANDOFF' when v_checkpoint_next is not null then 'LATEST_CHECKPOINT' else 'WORK_GOAL' end;
    v_resume_state:=case
      when coalesce(v_closure_guard->>'gate_state','BLOCKED')='PASS' and coalesce(v_postflight_gate,'')='PASS' then 'CLOSED_CLEAN'
      when coalesce(v_closure_guard->>'gate_state','BLOCKED')='PASS' then 'CLOSED_AWAITING_POSTFLIGHT'
      else 'CLOSED_BLOCKED'
    end;
  end if;

  return jsonb_build_object(
    'schema','WORLD8_DEV_RESUME_CAPSULE/2.1',
    'resume_state',v_resume_state,
    'work',jsonb_build_object(
      'work_id',v_w.work_id,'source_room',v_w.source_room,'actor_ref',v_w.actor_ref,'goal',v_w.goal,
      'development_state',v_w.development_state,'validation_state',v_w.validation_state,
      'promotion_state',v_w.promotion_state,'deployment_state',v_w.deployment_state,
      'touches',v_w.touches,'blockers',v_w.blockers,'metadata',v_w.metadata,'updated_at',v_w.updated_at),
    'canonical',v_canonical,'sessions',v_sessions,'active_session_count',v_active_count,
    'latest_checkpoint',v_checkpoint,'journal_tail',v_tail,'workspaces',v_workspaces,'leases',v_leases,
    'latest_handoff',v_handoff,'latest_postflight',v_postflight,
    'scribe_guard',v_active_scribe,'active_scribe_guard',v_active_scribe,'closure_guard',v_closure_guard,
    'next_safe_action',v_next,'next_action_source',v_next_source,
    'read_order',jsonb_build_array('START_HERE.md','docs/engineering/CRASH_SAFE_DEVELOPMENT.md','resume_state','latest_checkpoint','journal_tail','latest_handoff','latest_postflight','Diagnostic Memory','Work Capsule'),
    'generated_at',clock_timestamp());
end;
$$;
comment on function public.world8_dev_resume_capsule_v2(text) is 'Crash-Safe Resume Capsule v2.1: active Work resumes from latest checkpoint; closed Work resumes from final Handoff and exposes closure/postflight state without false active-session Scribe alarms.';
