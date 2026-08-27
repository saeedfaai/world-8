-- World 8 Crash-Safe Development Continuity v0.1.1.1
-- Defense-in-depth for N-Mason review: verify Assignment -> Work -> Workspace actor binding,
-- then require a current crash-safe Scribe checkpoint created after CODING began.

create or replace function public.world8_mason_pool_mark_ready_v1(
  p_assignment_id text,p_actor_id text,p_metadata jsonb default '{}'::jsonb
) returns jsonb
language plpgsql security definer set search_path='public' as $$
declare
  v_a public.world8_mason_assignments%rowtype;
  v_w public.world8_dev_work_items%rowtype;
  v_ws public.world8_dev_workspaces%rowtype;
  v_guard jsonb:='{}'::jsonb;
  v_cp public.world8_dev_session_checkpoints%rowtype;
begin
  select * into v_a from public.world8_mason_assignments where assignment_id=p_assignment_id for update;
  if not found or v_a.actor_id<>p_actor_id or v_a.state<>'CODING' or v_a.work_id is null or v_a.workspace_id is null then
    raise exception 'CODING_ASSIGNMENT_REQUIRED';
  end if;

  select * into v_w from public.world8_dev_work_items where work_id=v_a.work_id;
  if not found then raise exception 'WORK_NOT_FOUND'; end if;
  if v_w.actor_ref<>p_actor_id then raise exception 'ASSIGNMENT_WORK_ACTOR_MISMATCH'; end if;

  select * into v_ws from public.world8_dev_workspaces where workspace_id=v_a.workspace_id and state='ACTIVE';
  if not found or v_ws.work_id<>v_a.work_id or v_ws.actor_id<>p_actor_id then
    raise exception 'ASSIGNMENT_WORKSPACE_BINDING_MISMATCH';
  end if;

  if coalesce((v_w.metadata->>'crash_safe_required')::boolean,false) then
    v_guard:=public.world8_dev_scribe_guard_v1(v_a.work_id,p_actor_id,v_w.source_room);
    if coalesce(v_guard->>'gate_state','BLOCKED')<>'PASS' then
      raise exception 'SCRIBE_CHECKPOINT_REQUIRED' using detail=v_guard::text;
    end if;

    select c.* into v_cp
    from public.world8_dev_session_checkpoints c
    join public.world8_dev_session_liveness s on s.session_id=c.session_id
    where c.work_id=v_a.work_id and s.actor_id=p_actor_id and s.source_room=v_w.source_room and s.status='ACTIVE'
      and c.created_at>=v_a.updated_at
      and c.checkpoint_kind in ('MILESTONE','COMMIT','TEST','MANUAL')
    order by c.created_at desc limit 1;
    if not found then raise exception 'SCRIBE_REVIEW_CHECKPOINT_REQUIRED'; end if;
  end if;

  update public.world8_mason_assignments
  set state='READY_FOR_REVIEW',metadata=metadata||coalesce(p_metadata,'{}'::jsonb)||jsonb_build_object('scribe_checkpoint_id',v_cp.checkpoint_id),updated_at=clock_timestamp()
  where assignment_id=p_assignment_id;

  return jsonb_build_object('assignment_id',p_assignment_id,'state','READY_FOR_REVIEW','scribe_checkpoint_id',v_cp.checkpoint_id);
end;
$$;

comment on function public.world8_mason_pool_mark_ready_v1(text,text,jsonb) is 'READY_FOR_REVIEW gate; verifies Assignment/Work/Workspace actor binding and requires post-CODING Scribe evidence for crash-safe Work.';
