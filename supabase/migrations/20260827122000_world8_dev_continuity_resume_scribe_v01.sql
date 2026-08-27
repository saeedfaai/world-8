-- World 8 Crash-Safe Development Continuity v0.1 — resume/scribe
-- Extends existing continuity; does not replace Work/Handoff/Postflight or DCP.

create or replace function public.world8_dev_scribe_guard_v1(p_work_id text,p_actor_id text default null,p_source_room text default null)
returns jsonb language plpgsql security definer set search_path='public' as $$
declare v_now timestamptz:=clock_timestamp(); v_sessions jsonb:='[]'::jsonb; v_blockers jsonb:='[]'::jsonb; r record; v_dirty integer; v_latest public.world8_dev_session_checkpoints%rowtype;
begin
  for r in select * from public.world8_dev_session_liveness s where s.work_id=p_work_id and s.status='ACTIVE' and (p_actor_id is null or s.actor_id=p_actor_id) and (p_source_room is null or s.source_room=p_source_room) order by s.started_at loop
    v_latest:=null;
    select * into v_latest from public.world8_dev_session_checkpoints c where c.session_id=r.session_id order by c.created_at desc limit 1;
    select count(*) into v_dirty from public.world8_dev_session_journal j where j.session_id=r.session_id and j.requires_checkpoint and (v_latest.created_at is null or j.created_at>v_latest.created_at);
    v_sessions:=v_sessions||jsonb_build_array(jsonb_build_object('session_id',r.session_id,'source_room',r.source_room,'last_heartbeat_at',r.last_heartbeat_at,'heartbeat_age_seconds',extract(epoch from (v_now-r.last_heartbeat_at))::integer,'last_checkpoint_id',v_latest.checkpoint_id,'last_checkpoint_at',v_latest.created_at,'next_safe_action',v_latest.next_safe_action,'dirty_checkpoint_events',v_dirty,'checkpoint_due',(v_now>=r.checkpoint_due_at or v_dirty>0),'crash_suspected',(v_now-r.last_heartbeat_at>make_interval(secs=>r.crash_after_seconds))));
    if v_latest.checkpoint_id is null then v_blockers:=v_blockers||jsonb_build_array(jsonb_build_object('code','CHECKPOINT_REQUIRED','session_id',r.session_id)); end if;
    if v_dirty>0 then v_blockers:=v_blockers||jsonb_build_array(jsonb_build_object('code','UNCHECKPOINTED_PROGRESS','session_id',r.session_id,'count',v_dirty)); end if;
    if v_latest.checkpoint_id is not null and coalesce(btrim(v_latest.next_safe_action),'')='' then v_blockers:=v_blockers||jsonb_build_array(jsonb_build_object('code','NEXT_SAFE_ACTION_REQUIRED','session_id',r.session_id)); end if;
  end loop;
  if jsonb_array_length(v_sessions)=0 then v_blockers:=v_blockers||jsonb_build_array(jsonb_build_object('code','ACTIVE_DEV_SESSION_REQUIRED')); end if;
  return jsonb_build_object('schema','WORLD8_SCRIBE_GUARD/1.0','work_id',p_work_id,'gate_state',case when jsonb_array_length(v_blockers)=0 then 'PASS' else 'BLOCKED' end,'blockers',v_blockers,'sessions',v_sessions,'observed_at',v_now);
end;
$$;

create or replace function public.world8_dev_resume_capsule_v2(p_work_id text)
returns jsonb language plpgsql security definer set search_path='public' as $$
declare v_w public.world8_dev_work_items%rowtype; v_canonical jsonb:='{}'::jsonb; v_sessions jsonb:='[]'::jsonb; v_checkpoint jsonb:='{}'::jsonb; v_tail jsonb:='[]'::jsonb; v_workspaces jsonb:='[]'::jsonb; v_leases jsonb:='[]'::jsonb; v_handoff jsonb:='{}'::jsonb; v_next text;
begin
  select * into v_w from public.world8_dev_work_items where work_id=p_work_id; if not found then raise exception 'WORK_NOT_FOUND'; end if;
  select coalesce(jsonb_build_object('resource_id',resource_id,'uri',uri,'status',status,'metadata',metadata,'updated_at',updated_at),'{}'::jsonb) into v_canonical from public.world8_dev_external_resources where resource_id='resource-github-world8-canonical'; v_canonical:=coalesce(v_canonical,'{}'::jsonb);
  select coalesce(jsonb_agg(to_jsonb(s) order by s.started_at),'[]'::jsonb) into v_sessions from public.world8_dev_session_liveness s where s.work_id=p_work_id;
  select to_jsonb(c),c.next_safe_action into v_checkpoint,v_next from public.world8_dev_session_checkpoints c where c.work_id=p_work_id order by c.created_at desc limit 1; v_checkpoint:=coalesce(v_checkpoint,'{}'::jsonb);
  select coalesce(jsonb_agg(x.obj order by x.work_seq),'[]'::jsonb) into v_tail from (select j.work_seq,jsonb_build_object('event_id',j.event_id,'work_seq',j.work_seq,'session_id',j.session_id,'source_room',j.source_room,'event_kind',j.event_kind,'summary',j.summary,'requires_checkpoint',j.requires_checkpoint,'next_safe_action',j.next_safe_action,'content_hash',j.content_hash,'created_at',j.created_at) obj from public.world8_dev_session_journal j where j.work_id=p_work_id order by j.work_seq desc limit 20) x;
  select coalesce(jsonb_agg(jsonb_build_object('workspace_id',workspace_id,'actor_id',actor_id,'branch_ref',branch_ref,'base_commit',base_commit,'state',state,'updated_at',updated_at) order by updated_at desc),'[]'::jsonb) into v_workspaces from public.world8_dev_workspaces where work_id=p_work_id;
  select coalesce(jsonb_agg(jsonb_build_object('lease_id',lease_id,'artifact_id',artifact_id,'holder_ref',holder_ref,'status',status,'fencing_token',fencing_token,'expires_at',expires_at,'last_heartbeat_at',last_heartbeat_at) order by issued_at desc),'[]'::jsonb) into v_leases from public.world8_dev_leases where work_id=p_work_id;
  select to_jsonb(h) into v_handoff from public.world8_dev_handoffs h where h.work_id=p_work_id order by h.created_at desc limit 1; v_handoff:=coalesce(v_handoff,'{}'::jsonb);
  return jsonb_build_object('schema','WORLD8_DEV_RESUME_CAPSULE/2.0','work',jsonb_build_object('work_id',v_w.work_id,'source_room',v_w.source_room,'actor_ref',v_w.actor_ref,'goal',v_w.goal,'development_state',v_w.development_state,'validation_state',v_w.validation_state,'promotion_state',v_w.promotion_state,'deployment_state',v_w.deployment_state,'touches',v_w.touches,'blockers',v_w.blockers,'metadata',v_w.metadata,'updated_at',v_w.updated_at),'canonical',v_canonical,'sessions',v_sessions,'latest_checkpoint',v_checkpoint,'journal_tail',v_tail,'workspaces',v_workspaces,'leases',v_leases,'latest_handoff',v_handoff,'scribe_guard',public.world8_dev_scribe_guard_v1(p_work_id,null,null),'next_safe_action',coalesce(v_next,v_w.goal),'read_order',jsonb_build_array('START_HERE.md','docs/engineering/CRASH_SAFE_DEVELOPMENT.md','latest_checkpoint','journal_tail','Diagnostic Memory','Work Capsule'),'generated_at',clock_timestamp());
end;
$$;

create or replace function public.world8_dev_resume_board_v1(p_actor_id text default null,p_limit integer default 20)
returns jsonb language plpgsql security definer set search_path='public' as $$
declare v_items jsonb:='[]'::jsonb;
begin
  if p_limit<1 or p_limit>100 then raise exception 'RESUME_BOARD_LIMIT_OUT_OF_RANGE'; end if;
  select coalesce(jsonb_agg(x.obj order by x.last_activity desc),'[]'::jsonb) into v_items from (
    select w.work_id,
      greatest(w.updated_at,coalesce((select max(j.created_at) from public.world8_dev_session_journal j where j.work_id=w.work_id),w.updated_at),coalesce((select max(c.created_at) from public.world8_dev_session_checkpoints c where c.work_id=w.work_id),w.updated_at)) last_activity,
      jsonb_build_object('work_id',w.work_id,'source_room',w.source_room,'actor_ref',w.actor_ref,'goal',w.goal,'development_state',w.development_state,'validation_state',w.validation_state,'promotion_state',w.promotion_state,'deployment_state',w.deployment_state,'last_activity',greatest(w.updated_at,coalesce((select max(j.created_at) from public.world8_dev_session_journal j where j.work_id=w.work_id),w.updated_at),coalesce((select max(c.created_at) from public.world8_dev_session_checkpoints c where c.work_id=w.work_id),w.updated_at)),'latest_checkpoint',(select jsonb_build_object('checkpoint_id',c.checkpoint_id,'source_room',c.source_room,'kind',c.checkpoint_kind,'label',c.label,'next_safe_action',c.next_safe_action,'created_at',c.created_at) from public.world8_dev_session_checkpoints c where c.work_id=w.work_id order by c.created_at desc limit 1),'active_sessions',(select count(*) from public.world8_dev_session_liveness s where s.work_id=w.work_id and s.status='ACTIVE'),'crash_suspected_sessions',(select count(*) from public.world8_dev_session_liveness s where s.work_id=w.work_id and s.status='ACTIVE' and clock_timestamp()-s.last_heartbeat_at>make_interval(secs=>s.crash_after_seconds)),'active_workspaces',(select count(*) from public.world8_dev_workspaces ws where ws.work_id=w.work_id and ws.state='ACTIVE'),'active_leases',(select count(*) from public.world8_dev_leases l where l.work_id=w.work_id and l.status='ACTIVE' and l.expires_at>clock_timestamp())) obj
    from public.world8_dev_work_items w where w.development_state in ('CLAIMED','IMPLEMENTING','IMPLEMENTED','BLOCKED') and w.deployment_state<>'RETIRED' and (p_actor_id is null or w.actor_ref=p_actor_id)
    order by last_activity desc limit p_limit
  ) x;
  return jsonb_build_object('schema','WORLD8_DEV_RESUME_BOARD/1.0','actor_filter',p_actor_id,'items',v_items,'generated_at',clock_timestamp(),'start_instruction','Open the relevant work capsule. Read latest checkpoint before journal tail. Never reconstruct missing progress from memory.');
end;
$$;

create or replace function public.world8_dev_session_close_v1(p_session_id text,p_actor_id text,p_summary text,p_completed jsonb,p_remaining jsonb,p_known_issues jsonb,p_next_safe_action text,p_do_not_do jsonb default '[]'::jsonb,p_evidence_refs jsonb default '[]'::jsonb,p_metadata jsonb default '{}'::jsonb)
returns jsonb language plpgsql security definer set search_path='public' as $$
declare v_s public.world8_dev_session_liveness%rowtype; v_ws public.world8_dev_workspaces%rowtype; v_head text; v_cp jsonb; v_now timestamptz:=clock_timestamp();
begin
  select * into v_s from public.world8_dev_session_liveness where session_id=p_session_id for update; if not found or v_s.status<>'ACTIVE' then raise exception 'ACTIVE_DEV_SESSION_REQUIRED'; end if; if v_s.actor_id<>p_actor_id then raise exception 'DEV_SESSION_ACTOR_MISMATCH'; end if;
  if v_s.workspace_id is not null then select * into v_ws from public.world8_dev_workspaces where workspace_id=v_s.workspace_id; end if;
  select metadata->>'canonical_head_commit' into v_head from public.world8_dev_external_resources where resource_id='resource-github-world8-canonical';
  v_cp:=public.world8_dev_checkpoint_v1(p_session_id,p_actor_id,'BEFORE_HANDOFF','SESSION_CLOSE',p_summary,v_head,v_ws.branch_ref,null,p_completed,p_remaining,p_known_issues,p_next_safe_action,p_do_not_do,p_evidence_refs,p_metadata||jsonb_build_object('closure_checkpoint',true));
  perform public.world8_dev_journal_append_v1(p_session_id,p_actor_id,'CLOSURE','Session closed after final checkpoint; Handoff/Postflight remain required for governed work closure.',false,p_completed,p_remaining,'[]'::jsonb,'[]'::jsonb,'[]'::jsonb,p_evidence_refs,p_next_safe_action,p_do_not_do,p_metadata);
  update public.world8_dev_session_liveness set status='CLOSED',closed_at=v_now,last_heartbeat_at=v_now,updated_at=v_now where session_id=p_session_id;
  return jsonb_build_object('schema','WORLD8_DEV_SESSION_CLOSE/1.0','session_id',p_session_id,'work_id',v_s.work_id,'status','CLOSED','final_checkpoint',v_cp,'handoff_required',true,'postflight_required',true,'closed_at',v_now);
end;
$$;

-- Security: service role only. Liveness is mutable operational state; journal/checkpoint are immutable evidence.
revoke all on table public.world8_dev_session_liveness from public,anon,authenticated;
revoke all on table public.world8_dev_session_journal from public,anon,authenticated;
revoke all on table public.world8_dev_session_checkpoints from public,anon,authenticated;
revoke all on function public.world8_dev_journal_append_v1(text,text,text,text,boolean,jsonb,jsonb,jsonb,jsonb,jsonb,jsonb,text,jsonb,jsonb) from public,anon,authenticated;
revoke all on function public.world8_dev_checkpoint_v1(text,text,text,text,text,text,text,text,jsonb,jsonb,jsonb,text,jsonb,jsonb,jsonb) from public,anon,authenticated;
revoke all on function public.world8_dev_session_start_v1(text,text,text,text,text,integer,integer,jsonb) from public,anon,authenticated;
revoke all on function public.world8_dev_session_heartbeat_v1(text,text,jsonb) from public,anon,authenticated;
revoke all on function public.world8_dev_scribe_guard_v1(text,text,text) from public,anon,authenticated;
revoke all on function public.world8_dev_resume_capsule_v2(text) from public,anon,authenticated;
revoke all on function public.world8_dev_resume_board_v1(text,integer) from public,anon,authenticated;
revoke all on function public.world8_dev_session_close_v1(text,text,text,jsonb,jsonb,jsonb,text,jsonb,jsonb,jsonb) from public,anon,authenticated;
grant execute on function public.world8_dev_journal_append_v1(text,text,text,text,boolean,jsonb,jsonb,jsonb,jsonb,jsonb,jsonb,text,jsonb,jsonb) to service_role;
grant execute on function public.world8_dev_checkpoint_v1(text,text,text,text,text,text,text,text,jsonb,jsonb,jsonb,text,jsonb,jsonb,jsonb) to service_role;
grant execute on function public.world8_dev_session_start_v1(text,text,text,text,text,integer,integer,jsonb) to service_role;
grant execute on function public.world8_dev_session_heartbeat_v1(text,text,jsonb) to service_role;
grant execute on function public.world8_dev_scribe_guard_v1(text,text,text) to service_role;
grant execute on function public.world8_dev_resume_capsule_v2(text) to service_role;
grant execute on function public.world8_dev_resume_board_v1(text,integer) to service_role;
grant execute on function public.world8_dev_session_close_v1(text,text,text,jsonb,jsonb,jsonb,text,jsonb,jsonb,jsonb) to service_role;

comment on table public.world8_dev_session_journal is 'Append-only cross-Room engineering journal. Operational facts only; never private chain-of-thought.';
comment on table public.world8_dev_session_checkpoints is 'Immutable development recovery checkpoints. Latest checkpoint plus journal tail is the canonical resume surface.';
comment on table public.world8_dev_session_liveness is 'Mutable liveness state for crash suspicion and checkpoint cadence; not canonical evidence by itself.';
