-- World 8 Crash-Safe Development Continuity v0.1 — core
-- Runtime migrations applied first under governed Work work-6e4c1ba447d4b85db010148b3cb2.
-- Operational facts only. Never store private chain-of-thought or raw credentials.

create table if not exists public.world8_dev_session_liveness (
  session_id text primary key,
  world_id text not null default 'world-001',
  work_id text not null references public.world8_dev_work_items(work_id),
  actor_id text not null references public.world8_actor_registry(actor_id),
  execution_id text null references public.world8_actor_executions(execution_id),
  workspace_id text null references public.world8_dev_workspaces(workspace_id),
  source_room text not null,
  status text not null default 'ACTIVE' check (status in ('ACTIVE','STALE','CLOSED')),
  checkpoint_interval_seconds integer not null default 300 check (checkpoint_interval_seconds between 60 and 3600),
  crash_after_seconds integer not null default 600 check (crash_after_seconds between 120 and 7200),
  last_heartbeat_at timestamptz not null default clock_timestamp(),
  last_checkpoint_at timestamptz null,
  checkpoint_due_at timestamptz not null default (clock_timestamp()+interval '5 minutes'),
  last_event_id text null,
  last_event_hash text null,
  metadata jsonb not null default '{}'::jsonb check (jsonb_typeof(metadata)='object'),
  started_at timestamptz not null default clock_timestamp(),
  closed_at timestamptz null,
  updated_at timestamptz not null default clock_timestamp()
);
create unique index if not exists world8_dev_session_one_active_room_idx on public.world8_dev_session_liveness(work_id,actor_id,source_room) where status='ACTIVE';
create index if not exists world8_dev_session_work_status_idx on public.world8_dev_session_liveness(work_id,status,last_heartbeat_at desc);

create table if not exists public.world8_dev_session_journal (
  event_id text primary key,
  world_id text not null default 'world-001',
  work_id text not null references public.world8_dev_work_items(work_id),
  work_seq bigint not null,
  session_id text not null references public.world8_dev_session_liveness(session_id),
  actor_id text not null references public.world8_actor_registry(actor_id),
  execution_id text null references public.world8_actor_executions(execution_id),
  workspace_id text null references public.world8_dev_workspaces(workspace_id),
  source_room text not null,
  event_kind text not null check (event_kind in ('START','HEARTBEAT','NOTE','DECISION','MILESTONE','CODE','TEST','ERROR','ERROR_REPAIRED','RECOVERY','HANDOFF_HINT','CLOSURE')),
  requires_checkpoint boolean not null default false,
  summary text not null check (length(btrim(summary))>0),
  completed jsonb not null default '[]'::jsonb check (jsonb_typeof(completed)='array'),
  remaining jsonb not null default '[]'::jsonb check (jsonb_typeof(remaining)='array'),
  files_changed jsonb not null default '[]'::jsonb check (jsonb_typeof(files_changed)='array'),
  db_objects_touched jsonb not null default '[]'::jsonb check (jsonb_typeof(db_objects_touched)='array'),
  test_refs jsonb not null default '[]'::jsonb check (jsonb_typeof(test_refs)='array'),
  evidence_refs jsonb not null default '[]'::jsonb check (jsonb_typeof(evidence_refs)='array'),
  next_safe_action text null,
  do_not_do jsonb not null default '[]'::jsonb check (jsonb_typeof(do_not_do)='array'),
  metadata jsonb not null default '{}'::jsonb check (jsonb_typeof(metadata)='object'),
  previous_event_hash text null,
  content_hash text not null,
  created_at timestamptz not null default clock_timestamp(),
  unique(work_id,work_seq)
);
create index if not exists world8_dev_session_journal_work_idx on public.world8_dev_session_journal(work_id,work_seq desc);
create index if not exists world8_dev_session_journal_session_idx on public.world8_dev_session_journal(session_id,created_at desc);

create table if not exists public.world8_dev_session_checkpoints (
  checkpoint_id text primary key,
  world_id text not null default 'world-001',
  work_id text not null references public.world8_dev_work_items(work_id),
  session_id text not null references public.world8_dev_session_liveness(session_id),
  actor_id text not null references public.world8_actor_registry(actor_id),
  workspace_id text null references public.world8_dev_workspaces(workspace_id),
  source_room text not null,
  checkpoint_kind text not null check (checkpoint_kind in ('AUTO','SESSION_START','MILESTONE','COMMIT','TEST','DECISION','ERROR_RECOVERY','BEFORE_HANDOFF','MANUAL','RECONNECT')),
  label text not null check (length(btrim(label))>0),
  journal_event_id text not null references public.world8_dev_session_journal(event_id),
  journal_event_hash text not null,
  canonical_head text null,
  branch_ref text null,
  commit_sha text null,
  completed jsonb not null default '[]'::jsonb check (jsonb_typeof(completed)='array'),
  remaining jsonb not null default '[]'::jsonb check (jsonb_typeof(remaining)='array'),
  known_issues jsonb not null default '[]'::jsonb check (jsonb_typeof(known_issues)='array'),
  next_safe_action text not null check (length(btrim(next_safe_action))>0),
  do_not_do jsonb not null default '[]'::jsonb check (jsonb_typeof(do_not_do)='array'),
  evidence_refs jsonb not null default '[]'::jsonb check (jsonb_typeof(evidence_refs)='array'),
  state_snapshot jsonb not null default '{}'::jsonb check (jsonb_typeof(state_snapshot)='object'),
  metadata jsonb not null default '{}'::jsonb check (jsonb_typeof(metadata)='object'),
  content_hash text not null,
  created_at timestamptz not null default clock_timestamp()
);
create index if not exists world8_dev_session_checkpoints_work_idx on public.world8_dev_session_checkpoints(work_id,created_at desc);
create index if not exists world8_dev_session_checkpoints_session_idx on public.world8_dev_session_checkpoints(session_id,created_at desc);

create or replace function public.world8_prevent_dev_continuity_mutation_v1() returns trigger language plpgsql security definer set search_path='public' as $$
begin raise exception 'WORLD8_DEV_CONTINUITY_EVIDENCE_APPEND_ONLY'; end;
$$;
drop trigger if exists world8_dev_session_journal_append_only_trg on public.world8_dev_session_journal;
create trigger world8_dev_session_journal_append_only_trg before update or delete on public.world8_dev_session_journal for each row execute function public.world8_prevent_dev_continuity_mutation_v1();
drop trigger if exists world8_dev_session_checkpoints_append_only_trg on public.world8_dev_session_checkpoints;
create trigger world8_dev_session_checkpoints_append_only_trg before update or delete on public.world8_dev_session_checkpoints for each row execute function public.world8_prevent_dev_continuity_mutation_v1();

create or replace function public.world8_dev_journal_append_v1(
  p_session_id text,p_actor_id text,p_event_kind text,p_summary text,p_requires_checkpoint boolean default false,
  p_completed jsonb default '[]'::jsonb,p_remaining jsonb default '[]'::jsonb,p_files_changed jsonb default '[]'::jsonb,
  p_db_objects_touched jsonb default '[]'::jsonb,p_test_refs jsonb default '[]'::jsonb,p_evidence_refs jsonb default '[]'::jsonb,
  p_next_safe_action text default null,p_do_not_do jsonb default '[]'::jsonb,p_metadata jsonb default '{}'::jsonb
) returns jsonb language plpgsql security definer set search_path='public','extensions' as $$
declare v_now timestamptz:=clock_timestamp(); v_s public.world8_dev_session_liveness%rowtype; v_seq bigint; v_prev text; v_id text; v_payload jsonb; v_hash text;
begin
  if p_event_kind not in ('START','HEARTBEAT','NOTE','DECISION','MILESTONE','CODE','TEST','ERROR','ERROR_REPAIRED','RECOVERY','HANDOFF_HINT','CLOSURE') then raise exception 'INVALID_JOURNAL_EVENT_KIND'; end if;
  if coalesce(btrim(p_summary),'')='' then raise exception 'JOURNAL_SUMMARY_REQUIRED'; end if;
  select * into v_s from public.world8_dev_session_liveness where session_id=p_session_id for update;
  if not found then raise exception 'DEV_SESSION_NOT_FOUND'; end if;
  if v_s.actor_id<>p_actor_id then raise exception 'DEV_SESSION_ACTOR_MISMATCH'; end if;
  if v_s.status<>'ACTIVE' and p_event_kind<>'RECOVERY' then raise exception 'ACTIVE_DEV_SESSION_REQUIRED'; end if;
  perform pg_advisory_xact_lock(hashtext('world8:dev-journal:'||v_s.work_id));
  select work_seq,content_hash into v_seq,v_prev from public.world8_dev_session_journal where work_id=v_s.work_id order by work_seq desc limit 1;
  v_seq:=coalesce(v_seq,0)+1;
  v_payload:=jsonb_build_object('work_id',v_s.work_id,'work_seq',v_seq,'session_id',p_session_id,'actor_id',p_actor_id,'execution_id',v_s.execution_id,'workspace_id',v_s.workspace_id,'source_room',v_s.source_room,'event_kind',p_event_kind,'requires_checkpoint',p_requires_checkpoint,'summary',p_summary,'completed',coalesce(p_completed,'[]'::jsonb),'remaining',coalesce(p_remaining,'[]'::jsonb),'files_changed',coalesce(p_files_changed,'[]'::jsonb),'db_objects_touched',coalesce(p_db_objects_touched,'[]'::jsonb),'test_refs',coalesce(p_test_refs,'[]'::jsonb),'evidence_refs',coalesce(p_evidence_refs,'[]'::jsonb),'next_safe_action',p_next_safe_action,'do_not_do',coalesce(p_do_not_do,'[]'::jsonb),'metadata',coalesce(p_metadata,'{}'::jsonb),'previous_event_hash',v_prev,'created_at',v_now);
  v_hash:=encode(extensions.digest(v_payload::text,'sha256'),'hex'); v_id:='devjournal-'||substr(v_hash,1,32);
  insert into public.world8_dev_session_journal(event_id,work_id,work_seq,session_id,actor_id,execution_id,workspace_id,source_room,event_kind,requires_checkpoint,summary,completed,remaining,files_changed,db_objects_touched,test_refs,evidence_refs,next_safe_action,do_not_do,metadata,previous_event_hash,content_hash,created_at)
  values(v_id,v_s.work_id,v_seq,p_session_id,p_actor_id,v_s.execution_id,v_s.workspace_id,v_s.source_room,p_event_kind,p_requires_checkpoint,p_summary,coalesce(p_completed,'[]'::jsonb),coalesce(p_remaining,'[]'::jsonb),coalesce(p_files_changed,'[]'::jsonb),coalesce(p_db_objects_touched,'[]'::jsonb),coalesce(p_test_refs,'[]'::jsonb),coalesce(p_evidence_refs,'[]'::jsonb),p_next_safe_action,coalesce(p_do_not_do,'[]'::jsonb),coalesce(p_metadata,'{}'::jsonb),v_prev,v_hash,v_now);
  update public.world8_dev_session_liveness set last_event_id=v_id,last_event_hash=v_hash,last_heartbeat_at=v_now,checkpoint_due_at=case when p_requires_checkpoint then least(checkpoint_due_at,v_now) else checkpoint_due_at end,updated_at=v_now where session_id=p_session_id;
  return jsonb_build_object('schema','WORLD8_DEV_JOURNAL/1.0','event_id',v_id,'work_id',v_s.work_id,'work_seq',v_seq,'event_kind',p_event_kind,'requires_checkpoint',p_requires_checkpoint,'content_hash',v_hash,'created_at',v_now);
end;
$$;

create or replace function public.world8_dev_checkpoint_v1(
  p_session_id text,p_actor_id text,p_checkpoint_kind text,p_label text,p_summary text,p_canonical_head text default null,p_branch_ref text default null,p_commit_sha text default null,
  p_completed jsonb default '[]'::jsonb,p_remaining jsonb default '[]'::jsonb,p_known_issues jsonb default '[]'::jsonb,p_next_safe_action text default null,p_do_not_do jsonb default '[]'::jsonb,p_evidence_refs jsonb default '[]'::jsonb,p_metadata jsonb default '{}'::jsonb
) returns jsonb language plpgsql security definer set search_path='public','extensions' as $$
declare v_now timestamptz; v_s public.world8_dev_session_liveness%rowtype; v_event jsonb; v_event_kind text; v_id text; v_payload jsonb; v_hash text; v_state jsonb;
begin
  if p_checkpoint_kind not in ('AUTO','SESSION_START','MILESTONE','COMMIT','TEST','DECISION','ERROR_RECOVERY','BEFORE_HANDOFF','MANUAL','RECONNECT') then raise exception 'INVALID_CHECKPOINT_KIND'; end if;
  if coalesce(btrim(p_label),'')='' or coalesce(btrim(p_summary),'')='' then raise exception 'CHECKPOINT_LABEL_SUMMARY_REQUIRED'; end if;
  if coalesce(btrim(p_next_safe_action),'')='' then raise exception 'NEXT_SAFE_ACTION_REQUIRED'; end if;
  select * into v_s from public.world8_dev_session_liveness where session_id=p_session_id for update;
  if not found or v_s.status<>'ACTIVE' then raise exception 'ACTIVE_DEV_SESSION_REQUIRED'; end if;
  if v_s.actor_id<>p_actor_id then raise exception 'DEV_SESSION_ACTOR_MISMATCH'; end if;
  v_event_kind:=case p_checkpoint_kind when 'MILESTONE' then 'MILESTONE' when 'COMMIT' then 'CODE' when 'TEST' then 'TEST' when 'DECISION' then 'DECISION' when 'ERROR_RECOVERY' then 'ERROR_REPAIRED' when 'BEFORE_HANDOFF' then 'HANDOFF_HINT' when 'RECONNECT' then 'RECOVERY' else 'NOTE' end;
  v_event:=public.world8_dev_journal_append_v1(p_session_id,p_actor_id,v_event_kind,p_summary,true,p_completed,p_remaining,'[]'::jsonb,'[]'::jsonb,case when p_checkpoint_kind='TEST' then p_evidence_refs else '[]'::jsonb end,p_evidence_refs,p_next_safe_action,p_do_not_do,p_metadata||jsonb_build_object('checkpoint_kind',p_checkpoint_kind,'label',p_label,'commit_sha',p_commit_sha));
  v_now:=clock_timestamp();
  v_state:=jsonb_build_object('work_id',v_s.work_id,'session_id',p_session_id,'workspace_id',v_s.workspace_id,'source_room',v_s.source_room,'checkpoint_kind',p_checkpoint_kind,'label',p_label,'canonical_head',p_canonical_head,'branch_ref',p_branch_ref,'commit_sha',p_commit_sha,'completed',coalesce(p_completed,'[]'::jsonb),'remaining',coalesce(p_remaining,'[]'::jsonb),'known_issues',coalesce(p_known_issues,'[]'::jsonb),'next_safe_action',p_next_safe_action,'do_not_do',coalesce(p_do_not_do,'[]'::jsonb));
  v_payload:=v_state||jsonb_build_object('journal_event_id',v_event->>'event_id','journal_event_hash',v_event->>'content_hash','evidence_refs',coalesce(p_evidence_refs,'[]'::jsonb),'metadata',coalesce(p_metadata,'{}'::jsonb),'created_at',v_now);
  v_hash:=encode(extensions.digest(v_payload::text,'sha256'),'hex'); v_id:='devcheckpoint-'||substr(v_hash,1,32);
  insert into public.world8_dev_session_checkpoints(checkpoint_id,work_id,session_id,actor_id,workspace_id,source_room,checkpoint_kind,label,journal_event_id,journal_event_hash,canonical_head,branch_ref,commit_sha,completed,remaining,known_issues,next_safe_action,do_not_do,evidence_refs,state_snapshot,metadata,content_hash,created_at)
  values(v_id,v_s.work_id,p_session_id,p_actor_id,v_s.workspace_id,v_s.source_room,p_checkpoint_kind,p_label,v_event->>'event_id',v_event->>'content_hash',p_canonical_head,p_branch_ref,p_commit_sha,coalesce(p_completed,'[]'::jsonb),coalesce(p_remaining,'[]'::jsonb),coalesce(p_known_issues,'[]'::jsonb),p_next_safe_action,coalesce(p_do_not_do,'[]'::jsonb),coalesce(p_evidence_refs,'[]'::jsonb),v_state,coalesce(p_metadata,'{}'::jsonb),v_hash,v_now);
  update public.world8_dev_session_liveness set last_checkpoint_at=v_now,checkpoint_due_at=v_now+make_interval(secs=>checkpoint_interval_seconds),last_heartbeat_at=v_now,updated_at=v_now where session_id=p_session_id;
  return jsonb_build_object('schema','WORLD8_DEV_CHECKPOINT/1.0','checkpoint_id',v_id,'work_id',v_s.work_id,'session_id',p_session_id,'checkpoint_kind',p_checkpoint_kind,'journal_event_id',v_event->>'event_id','content_hash',v_hash,'next_safe_action',p_next_safe_action,'created_at',v_now);
end;
$$;

create or replace function public.world8_dev_session_start_v1(p_work_id text,p_actor_id text,p_execution_id text,p_workspace_id text,p_source_room text,p_checkpoint_interval_seconds integer default 300,p_crash_after_seconds integer default 600,p_metadata jsonb default '{}'::jsonb)
returns jsonb language plpgsql security definer set search_path='public','extensions' as $$
declare v_now timestamptz:=clock_timestamp(); v_w public.world8_dev_work_items%rowtype; v_ws public.world8_dev_workspaces%rowtype; v_id text; v_existing text; v_head text; v_branch text; v_cp jsonb;
begin
  if coalesce(btrim(p_source_room),'')='' then raise exception 'SOURCE_ROOM_REQUIRED'; end if;
  if p_checkpoint_interval_seconds<60 or p_checkpoint_interval_seconds>3600 then raise exception 'CHECKPOINT_INTERVAL_OUT_OF_RANGE'; end if;
  if p_crash_after_seconds<120 or p_crash_after_seconds>7200 then raise exception 'CRASH_TIMEOUT_OUT_OF_RANGE'; end if;
  select * into v_w from public.world8_dev_work_items where work_id=p_work_id; if not found then raise exception 'WORK_NOT_FOUND'; end if; if v_w.actor_ref<>p_actor_id then raise exception 'WORK_ACTOR_MISMATCH'; end if;
  if p_execution_id is not null and not exists(select 1 from public.world8_actor_executions e where e.execution_id=p_execution_id and e.actor_id=p_actor_id and e.state='ACTIVE') then raise exception 'ACTIVE_EXECUTION_REQUIRED'; end if;
  if p_workspace_id is not null then select * into v_ws from public.world8_dev_workspaces where workspace_id=p_workspace_id and state='ACTIVE'; if not found or v_ws.actor_id<>p_actor_id or v_ws.work_id<>p_work_id then raise exception 'ACTIVE_WORKSPACE_BINDING_REQUIRED'; end if; v_branch:=v_ws.branch_ref; end if;
  select session_id into v_existing from public.world8_dev_session_liveness where work_id=p_work_id and actor_id=p_actor_id and source_room=p_source_room and status='ACTIVE' limit 1;
  if v_existing is not null then update public.world8_dev_session_liveness set last_heartbeat_at=v_now,metadata=metadata||coalesce(p_metadata,'{}'::jsonb),updated_at=v_now where session_id=v_existing; return jsonb_build_object('schema','WORLD8_DEV_SESSION/1.0','session_id',v_existing,'state','ALREADY_ACTIVE','action','CALL_RESUME_CAPSULE'); end if;
  v_id:='devsession-'||substr(encode(extensions.digest(p_work_id||'|'||p_actor_id||'|'||p_source_room||'|'||v_now::text,'sha256'),'hex'),1,32);
  insert into public.world8_dev_session_liveness(session_id,work_id,actor_id,execution_id,workspace_id,source_room,status,checkpoint_interval_seconds,crash_after_seconds,last_heartbeat_at,checkpoint_due_at,metadata,started_at,updated_at) values(v_id,p_work_id,p_actor_id,p_execution_id,p_workspace_id,p_source_room,'ACTIVE',p_checkpoint_interval_seconds,p_crash_after_seconds,v_now,v_now+make_interval(secs=>p_checkpoint_interval_seconds),coalesce(p_metadata,'{}'::jsonb),v_now,v_now);
  select metadata->>'canonical_head_commit' into v_head from public.world8_dev_external_resources where resource_id='resource-github-world8-canonical' and status='ACTIVE';
  perform public.world8_dev_journal_append_v1(v_id,p_actor_id,'START','Development session started; baseline checkpoint follows in the same transaction.',false,'[]'::jsonb,jsonb_build_array(v_w.goal),'[]'::jsonb,'[]'::jsonb,'[]'::jsonb,jsonb_build_array('work:'||p_work_id),v_w.goal,jsonb_build_array('Do not reconstruct missing progress from memory','Do not bypass Work/Workspace/Admission/Lease'),coalesce(p_metadata,'{}'::jsonb));
  v_cp:=public.world8_dev_checkpoint_v1(v_id,p_actor_id,'SESSION_START','SESSION_START','Baseline captured at session start.',v_head,v_branch,null,'[]'::jsonb,jsonb_build_array(v_w.goal),'[]'::jsonb,v_w.goal,jsonb_build_array('Do not reconstruct missing progress from memory','Do not bypass Work/Workspace/Admission/Lease'),jsonb_build_array('work:'||p_work_id),jsonb_build_object('auto_created',true));
  return jsonb_build_object('schema','WORLD8_DEV_SESSION/1.0','session_id',v_id,'state','ACTIVE','baseline_checkpoint',v_cp,'checkpoint_interval_seconds',p_checkpoint_interval_seconds,'crash_after_seconds',p_crash_after_seconds,'started_at',v_now);
end;
$$;

create or replace function public.world8_dev_session_heartbeat_v1(p_session_id text,p_actor_id text,p_metadata jsonb default '{}'::jsonb)
returns jsonb language plpgsql security definer set search_path='public' as $$
declare v_now timestamptz:=clock_timestamp(); v_s public.world8_dev_session_liveness%rowtype; v_dirty integer:=0; v_due boolean:=false;
begin
  select * into v_s from public.world8_dev_session_liveness where session_id=p_session_id for update; if not found then raise exception 'DEV_SESSION_NOT_FOUND'; end if; if v_s.actor_id<>p_actor_id then raise exception 'DEV_SESSION_ACTOR_MISMATCH'; end if; if v_s.status<>'ACTIVE' then raise exception 'ACTIVE_DEV_SESSION_REQUIRED'; end if;
  select count(*) into v_dirty from public.world8_dev_session_journal j where j.session_id=p_session_id and j.requires_checkpoint and (v_s.last_checkpoint_at is null or j.created_at>v_s.last_checkpoint_at);
  v_due:=(v_now>=v_s.checkpoint_due_at) or v_dirty>0;
  update public.world8_dev_session_liveness set last_heartbeat_at=v_now,metadata=metadata||coalesce(p_metadata,'{}'::jsonb),updated_at=v_now where session_id=p_session_id;
  return jsonb_build_object('schema','WORLD8_DEV_HEARTBEAT/1.0','session_id',p_session_id,'work_id',v_s.work_id,'checkpoint_due',v_due,'dirty_checkpoint_events',v_dirty,'last_checkpoint_at',v_s.last_checkpoint_at,'checkpoint_due_at',v_s.checkpoint_due_at,'crash_after_seconds',v_s.crash_after_seconds,'observed_at',v_now);
end;
$$;
