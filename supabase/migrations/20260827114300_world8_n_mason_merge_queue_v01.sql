-- World 8 N-Mason serialized merge queue v0.1
-- Many workers may code concurrently; only one canonical merge may be claimed at a time.

create table if not exists public.world8_merge_queue (
  queue_id text primary key,
  world_id text not null default 'world-001',
  pool_id text not null references public.world8_mason_pools(pool_id),
  assignment_id text not null references public.world8_mason_assignments(assignment_id),
  work_id text not null references public.world8_dev_work_items(work_id),
  actor_id text not null references public.world8_actor_registry(actor_id),
  workspace_id text not null references public.world8_dev_workspaces(workspace_id),
  repo_ref text not null,
  branch_ref text not null,
  base_commit text not null,
  head_commit text not null,
  pr_number bigint null,
  ci_run_id bigint null,
  ci_state text not null check (ci_state in ('PENDING','PASS','FAIL','CANCELLED','UNKNOWN')),
  touches jsonb not null default '[]'::jsonb check (jsonb_typeof(touches)='array'),
  priority integer not null default 100 check (priority between 0 and 1000),
  state text not null check (state in ('WAITING_CI','QUEUED','STALE_REBASE_REQUIRED','MERGING','MERGED','REJECTED','CANCELLED')),
  gate_reason text null,
  conflict_refs jsonb not null default '[]'::jsonb check (jsonb_typeof(conflict_refs)='array'),
  canonical_head_at_enqueue text not null,
  claimed_by text null,
  claimed_at timestamptz null,
  metadata jsonb not null default '{}'::jsonb check (jsonb_typeof(metadata)='object'),
  created_at timestamptz not null default clock_timestamp(),
  updated_at timestamptz not null default clock_timestamp(),
  unique(repo_ref,branch_ref,head_commit)
);

create index if not exists world8_merge_queue_ready_idx
  on public.world8_merge_queue(pool_id,state,ci_state,priority desc,created_at);
create index if not exists world8_merge_queue_work_idx
  on public.world8_merge_queue(work_id,created_at desc);

create table if not exists public.world8_merge_receipts (
  merge_receipt_id text primary key,
  world_id text not null default 'world-001',
  pool_id text not null references public.world8_mason_pools(pool_id),
  queue_id text not null references public.world8_merge_queue(queue_id),
  work_id text not null references public.world8_dev_work_items(work_id),
  actor_id text not null references public.world8_actor_registry(actor_id),
  merger_actor text not null,
  old_canonical_head text not null,
  new_canonical_head text not null,
  pr_number bigint null,
  merge_evidence_refs jsonb not null default '[]'::jsonb check (jsonb_typeof(merge_evidence_refs)='array'),
  stale_queue_refs jsonb not null default '[]'::jsonb check (jsonb_typeof(stale_queue_refs)='array'),
  merged_at timestamptz not null,
  content_hash text not null
);

create or replace function public.world8_prevent_merge_receipt_mutation_v1()
returns trigger language plpgsql security definer set search_path='public' as $$
begin raise exception 'WORLD8_MERGE_RECEIPT_APPEND_ONLY'; end $$;

drop trigger if exists world8_merge_receipts_append_only_trg on public.world8_merge_receipts;
create trigger world8_merge_receipts_append_only_trg
before update or delete on public.world8_merge_receipts
for each row execute function public.world8_prevent_merge_receipt_mutation_v1();

create or replace function public.world8_merge_enqueue_v1(
  p_assignment_id text,
  p_head_commit text,
  p_pr_number bigint,
  p_ci_run_id bigint,
  p_ci_state text,
  p_touches jsonb default '[]'::jsonb,
  p_priority integer default 100,
  p_metadata jsonb default '{}'::jsonb
) returns jsonb
language plpgsql security definer set search_path='public','extensions' as $$
declare
  v_now timestamptz:=clock_timestamp();
  v_a public.world8_mason_assignments%rowtype;
  v_w public.world8_dev_work_items%rowtype;
  v_ws public.world8_dev_workspaces%rowtype;
  v_pool public.world8_mason_pools%rowtype;
  v_canonical text;
  v_protection text;
  v_state text;
  v_gate text:=null;
  v_conflicts jsonb:='[]'::jsonb;
  v_id text;
begin
  if p_ci_state not in ('PENDING','PASS','FAIL','CANCELLED','UNKNOWN') then raise exception 'INVALID_CI_STATE'; end if;
  if p_priority<0 or p_priority>1000 then raise exception 'INVALID_MERGE_PRIORITY'; end if;
  if coalesce(btrim(p_head_commit),'')='' then raise exception 'HEAD_COMMIT_REQUIRED'; end if;
  if jsonb_typeof(coalesce(p_touches,'[]'::jsonb))<>'array' then raise exception 'TOUCHES_MUST_BE_ARRAY'; end if;
  select * into v_a from public.world8_mason_assignments where assignment_id=p_assignment_id;
  if not found or v_a.state<>'READY_FOR_REVIEW' or v_a.work_id is null or v_a.workspace_id is null then raise exception 'READY_ASSIGNMENT_REQUIRED'; end if;
  select * into v_w from public.world8_dev_work_items where work_id=v_a.work_id;
  if not found or v_w.actor_ref<>v_a.actor_id then raise exception 'ASSIGNMENT_WORK_ACTOR_MISMATCH'; end if;
  select * into v_ws from public.world8_dev_workspaces where workspace_id=v_a.workspace_id and state='ACTIVE';
  if not found or v_ws.actor_id<>v_a.actor_id or v_ws.work_id<>v_a.work_id then raise exception 'ACTIVE_ASSIGNMENT_WORKSPACE_REQUIRED'; end if;
  if lower(v_ws.branch_ref) in ('main','master') then raise exception 'CANONICAL_BRANCH_WRITE_FORBIDDEN'; end if;
  select * into v_pool from public.world8_mason_pools where pool_id=v_a.pool_id and status='ACTIVE';
  if not found then raise exception 'ACTIVE_MASON_POOL_REQUIRED'; end if;
  select metadata->>'canonical_head_commit',metadata->>'branch_protection' into v_canonical,v_protection
  from public.world8_dev_external_resources where resource_id='resource-github-world8-canonical' and status='ACTIVE';
  if coalesce(v_canonical,'')='' then raise exception 'CANONICAL_GIT_REQUIRED'; end if;
  if v_ws.base_commit<>v_canonical then v_state:='STALE_REBASE_REQUIRED'; v_gate:='STALE_CANONICAL_BASE';
  elsif p_ci_state='PASS' then v_state:='QUEUED';
  else v_state:='WAITING_CI'; v_gate:='CI_PASS_REQUIRED'; end if;
  if v_pool.branch_protection_required and coalesce(v_protection,'UNCONFIGURED') not in ('ENFORCED','RULESET_ENFORCED','PROTECTED') then
    v_gate:=case when v_gate is null then 'GITHUB_BRANCH_PROTECTION_REQUIRED' else v_gate||'+GITHUB_BRANCH_PROTECTION_REQUIRED' end;
  end if;
  select coalesce(jsonb_agg(jsonb_build_object('queue_id',q.queue_id,'work_id',q.work_id,'branch_ref',q.branch_ref,'state',q.state)),'[]'::jsonb)
  into v_conflicts
  from public.world8_merge_queue q
  where q.repo_ref=v_ws.repo_ref and q.state in ('WAITING_CI','QUEUED','MERGING','STALE_REBASE_REQUIRED')
    and exists(
      select 1
      from jsonb_array_elements_text(q.touches) x(value)
      join jsonb_array_elements_text(coalesce(p_touches,'[]'::jsonb)) y(value) on x.value=y.value
    );
  v_id:='mergeq-'||substr(encode(extensions.digest(v_a.pool_id||'|'||v_a.assignment_id||'|'||p_head_commit||'|'||v_now::text,'sha256'),'hex'),1,32);
  insert into public.world8_merge_queue(queue_id,pool_id,assignment_id,work_id,actor_id,workspace_id,repo_ref,branch_ref,base_commit,head_commit,pr_number,ci_run_id,ci_state,touches,priority,state,gate_reason,conflict_refs,canonical_head_at_enqueue,metadata,created_at,updated_at)
  values(v_id,v_a.pool_id,v_a.assignment_id,v_a.work_id,v_a.actor_id,v_a.workspace_id,v_ws.repo_ref,v_ws.branch_ref,v_ws.base_commit,p_head_commit,p_pr_number,p_ci_run_id,p_ci_state,coalesce(p_touches,'[]'::jsonb),p_priority,v_state,v_gate,v_conflicts,v_canonical,coalesce(p_metadata,'{}'::jsonb),v_now,v_now);
  return jsonb_build_object('schema','WORLD8_MERGE_QUEUE/1.0','queue_id',v_id,'pool_id',v_a.pool_id,'work_id',v_a.work_id,'actor_id',v_a.actor_id,'branch_ref',v_ws.branch_ref,'base_commit',v_ws.base_commit,'head_commit',p_head_commit,'state',v_state,'ci_state',p_ci_state,'gate_reason',v_gate,'conflicts',v_conflicts,'canonical_head',v_canonical);
end $$;

create or replace function public.world8_merge_refresh_v1(
  p_queue_id text,
  p_workspace_id text,
  p_head_commit text,
  p_ci_run_id bigint,
  p_ci_state text,
  p_actor_id text
) returns jsonb
language plpgsql security definer set search_path='public' as $$
declare
  v_q public.world8_merge_queue%rowtype;
  v_ws public.world8_dev_workspaces%rowtype;
  v_head text;
  v_protection text;
  v_state text;
  v_gate text:=null;
begin
  if p_ci_state not in ('PENDING','PASS','FAIL','CANCELLED','UNKNOWN') then raise exception 'INVALID_CI_STATE'; end if;
  select * into v_q from public.world8_merge_queue where queue_id=p_queue_id for update;
  if not found or v_q.actor_id<>p_actor_id or v_q.state not in ('STALE_REBASE_REQUIRED','WAITING_CI','QUEUED') then raise exception 'REFRESHABLE_QUEUE_ITEM_REQUIRED'; end if;
  select * into v_ws from public.world8_dev_workspaces where workspace_id=p_workspace_id and state='ACTIVE';
  if not found or v_ws.actor_id<>v_q.actor_id or v_ws.work_id<>v_q.work_id then raise exception 'ACTIVE_ASSIGNMENT_WORKSPACE_REQUIRED'; end if;
  select metadata->>'canonical_head_commit',metadata->>'branch_protection' into v_head,v_protection from public.world8_dev_external_resources where resource_id='resource-github-world8-canonical' and status='ACTIVE';
  if v_ws.base_commit<>v_head then v_state:='STALE_REBASE_REQUIRED'; v_gate:='STALE_CANONICAL_BASE';
  elsif p_ci_state='PASS' then v_state:='QUEUED';
  else v_state:='WAITING_CI'; v_gate:='CI_PASS_REQUIRED'; end if;
  if exists(select 1 from public.world8_mason_pools p where p.pool_id=v_q.pool_id and p.branch_protection_required)
     and coalesce(v_protection,'UNCONFIGURED') not in ('ENFORCED','RULESET_ENFORCED','PROTECTED') then
     v_gate:=case when v_gate is null then 'GITHUB_BRANCH_PROTECTION_REQUIRED' else v_gate||'+GITHUB_BRANCH_PROTECTION_REQUIRED' end;
  end if;
  update public.world8_merge_queue set workspace_id=p_workspace_id,branch_ref=v_ws.branch_ref,base_commit=v_ws.base_commit,head_commit=p_head_commit,ci_run_id=p_ci_run_id,ci_state=p_ci_state,state=v_state,gate_reason=v_gate,canonical_head_at_enqueue=v_head,claimed_by=null,claimed_at=null,updated_at=clock_timestamp() where queue_id=p_queue_id;
  return jsonb_build_object('queue_id',p_queue_id,'state',v_state,'gate_reason',v_gate,'base_commit',v_ws.base_commit,'head_commit',p_head_commit,'ci_state',p_ci_state,'canonical_head',v_head);
end $$;

create or replace function public.world8_merge_claim_next_v1(p_pool_id text,p_merger_actor text) returns jsonb
language plpgsql security definer set search_path='public' as $$
declare
  v_pool public.world8_mason_pools%rowtype;
  v_head text;
  v_protection text;
  v_q public.world8_merge_queue%rowtype;
begin
  perform pg_advisory_xact_lock(hashtext('world8:canonical-merge'));
  select * into v_pool from public.world8_mason_pools where pool_id=p_pool_id and status='ACTIVE';
  if not found then return jsonb_build_object('gate_state','BLOCKED','reason_code','ACTIVE_MASON_POOL_REQUIRED'); end if;
  select metadata->>'canonical_head_commit',metadata->>'branch_protection' into v_head,v_protection from public.world8_dev_external_resources where resource_id='resource-github-world8-canonical' and status='ACTIVE';
  if v_pool.branch_protection_required and coalesce(v_protection,'UNCONFIGURED') not in ('ENFORCED','RULESET_ENFORCED','PROTECTED') then
    return jsonb_build_object('gate_state','BLOCKED','reason_code','GITHUB_BRANCH_PROTECTION_REQUIRED','canonical_head',v_head,'branch_protection',coalesce(v_protection,'UNCONFIGURED'));
  end if;
  if exists(select 1 from public.world8_merge_queue where pool_id=p_pool_id and state='MERGING') then
    return jsonb_build_object('gate_state','BLOCKED','reason_code','MERGE_ALREADY_IN_PROGRESS');
  end if;
  update public.world8_merge_queue set state='STALE_REBASE_REQUIRED',gate_reason='STALE_CANONICAL_BASE_AFTER_OTHER_MERGE',updated_at=clock_timestamp()
  where pool_id=p_pool_id and state in ('QUEUED','WAITING_CI') and base_commit<>v_head;
  select * into v_q from public.world8_merge_queue
    where pool_id=p_pool_id and state='QUEUED' and ci_state='PASS' and base_commit=v_head
    order by priority desc,created_at
    for update skip locked limit 1;
  if not found then return jsonb_build_object('gate_state','PASS','state','NO_READY_CANDIDATE','canonical_head',v_head); end if;
  update public.world8_merge_queue set state='MERGING',claimed_by=p_merger_actor,claimed_at=clock_timestamp(),gate_reason=null,updated_at=clock_timestamp() where queue_id=v_q.queue_id;
  return jsonb_build_object('gate_state','PASS','state','MERGING','queue_id',v_q.queue_id,'work_id',v_q.work_id,'actor_id',v_q.actor_id,'branch_ref',v_q.branch_ref,'head_commit',v_q.head_commit,'pr_number',v_q.pr_number,'ci_run_id',v_q.ci_run_id,'canonical_head',v_head,'conflicts',v_q.conflict_refs);
end $$;

create or replace function public.world8_merge_complete_v1(
  p_queue_id text,
  p_merger_actor text,
  p_new_canonical_head text,
  p_merge_evidence_refs jsonb default '[]'::jsonb
) returns jsonb
language plpgsql security definer set search_path='public','extensions' as $$
declare
  v_now timestamptz:=clock_timestamp();
  v_q public.world8_merge_queue%rowtype;
  v_pool public.world8_mason_pools%rowtype;
  v_old text;
  v_protection text;
  v_stale jsonb:='[]'::jsonb;
  v_payload jsonb;
  v_hash text;
  v_receipt text;
begin
  perform pg_advisory_xact_lock(hashtext('world8:canonical-merge'));
  if coalesce(btrim(p_new_canonical_head),'')='' then raise exception 'NEW_CANONICAL_HEAD_REQUIRED'; end if;
  if jsonb_typeof(coalesce(p_merge_evidence_refs,'[]'::jsonb))<>'array' then raise exception 'MERGE_EVIDENCE_MUST_BE_ARRAY'; end if;
  select * into v_q from public.world8_merge_queue where queue_id=p_queue_id for update;
  if not found or v_q.state<>'MERGING' or v_q.claimed_by<>p_merger_actor then raise exception 'CLAIMED_MERGE_REQUIRED'; end if;
  select * into v_pool from public.world8_mason_pools where pool_id=v_q.pool_id and status='ACTIVE';
  if not found then raise exception 'ACTIVE_MASON_POOL_REQUIRED'; end if;
  select metadata->>'canonical_head_commit',metadata->>'branch_protection' into v_old,v_protection from public.world8_dev_external_resources where resource_id='resource-github-world8-canonical' and status='ACTIVE' for update;
  if v_pool.branch_protection_required and coalesce(v_protection,'UNCONFIGURED') not in ('ENFORCED','RULESET_ENFORCED','PROTECTED') then raise exception 'GITHUB_BRANCH_PROTECTION_REQUIRED'; end if;
  if v_q.base_commit<>v_old then raise exception 'STALE_CANONICAL_BASE'; end if;
  update public.world8_merge_queue set state='MERGED',gate_reason=null,updated_at=v_now where queue_id=p_queue_id;
  update public.world8_dev_external_resources
    set metadata=metadata||jsonb_build_object('canonical_head_commit',p_new_canonical_head,'head_observed_at',v_now,'head_sync_reason','N_MASON_SERIALIZED_MERGE','last_merge_queue_id',p_queue_id,'last_merge_actor',p_merger_actor),updated_at=v_now
    where resource_id='resource-github-world8-canonical';
  update public.world8_merge_queue
    set state='STALE_REBASE_REQUIRED',gate_reason='STALE_CANONICAL_BASE_AFTER_OTHER_MERGE',updated_at=v_now
    where pool_id=v_q.pool_id and queue_id<>p_queue_id and state in ('QUEUED','WAITING_CI') and base_commit<>p_new_canonical_head;
  select coalesce(jsonb_agg(queue_id),'[]'::jsonb) into v_stale from public.world8_merge_queue where pool_id=v_q.pool_id and queue_id<>p_queue_id and state='STALE_REBASE_REQUIRED' and updated_at=v_now;
  v_payload:=jsonb_build_object('schema','WORLD8_MERGE_RECEIPT/1.0','pool_id',v_q.pool_id,'queue_id',p_queue_id,'work_id',v_q.work_id,'actor_id',v_q.actor_id,'merger_actor',p_merger_actor,'old_canonical_head',v_old,'new_canonical_head',p_new_canonical_head,'pr_number',v_q.pr_number,'merge_evidence_refs',coalesce(p_merge_evidence_refs,'[]'::jsonb),'stale_queue_refs',v_stale,'merged_at',v_now);
  v_hash:=encode(extensions.digest(convert_to(v_payload::text,'UTF8'),'sha256'),'hex');
  v_receipt:='merge-receipt-'||substr(v_hash,1,32);
  insert into public.world8_merge_receipts(merge_receipt_id,pool_id,queue_id,work_id,actor_id,merger_actor,old_canonical_head,new_canonical_head,pr_number,merge_evidence_refs,stale_queue_refs,merged_at,content_hash)
  values(v_receipt,v_q.pool_id,p_queue_id,v_q.work_id,v_q.actor_id,p_merger_actor,v_old,p_new_canonical_head,v_q.pr_number,coalesce(p_merge_evidence_refs,'[]'::jsonb),v_stale,v_now,v_hash);
  return v_payload||jsonb_build_object('merge_receipt_id',v_receipt,'content_hash',v_hash,'gate_state','PASS');
end $$;

create or replace function public.world8_merge_queue_snapshot_v1(p_pool_id text) returns jsonb
language sql security definer set search_path='public' as $$
  select jsonb_build_object(
    'schema','WORLD8_MERGE_QUEUE_SNAPSHOT/1.0',
    'pool_id',p_pool_id,
    'counts',jsonb_build_object(
      'waiting_ci',count(*) filter(where state='WAITING_CI'),
      'queued',count(*) filter(where state='QUEUED'),
      'stale',count(*) filter(where state='STALE_REBASE_REQUIRED'),
      'merging',count(*) filter(where state='MERGING'),
      'merged',count(*) filter(where state='MERGED')
    ),
    'active',coalesce(jsonb_agg(jsonb_build_object('queue_id',queue_id,'work_id',work_id,'actor_id',actor_id,'branch_ref',branch_ref,'base_commit',base_commit,'head_commit',head_commit,'pr_number',pr_number,'ci_state',ci_state,'state',state,'gate_reason',gate_reason,'conflict_refs',conflict_refs,'priority',priority) order by priority desc,created_at) filter(where state in ('WAITING_CI','QUEUED','STALE_REBASE_REQUIRED','MERGING')),'[]'::jsonb),
    'observed_at',clock_timestamp()
  ) from public.world8_merge_queue where pool_id=p_pool_id;
$$;

revoke all on table public.world8_merge_queue from public,anon,authenticated;
revoke all on table public.world8_merge_receipts from public,anon,authenticated;
revoke all on function public.world8_merge_enqueue_v1(text,text,bigint,bigint,text,jsonb,integer,jsonb) from public,anon,authenticated;
revoke all on function public.world8_merge_refresh_v1(text,text,text,bigint,text,text) from public,anon,authenticated;
revoke all on function public.world8_merge_claim_next_v1(text,text) from public,anon,authenticated;
revoke all on function public.world8_merge_complete_v1(text,text,text,jsonb) from public,anon,authenticated;
revoke all on function public.world8_merge_queue_snapshot_v1(text) from public,anon,authenticated;
grant execute on function public.world8_merge_enqueue_v1(text,text,bigint,bigint,text,jsonb,integer,jsonb) to service_role;
grant execute on function public.world8_merge_refresh_v1(text,text,text,bigint,text,text) to service_role;
grant execute on function public.world8_merge_claim_next_v1(text,text) to service_role;
grant execute on function public.world8_merge_complete_v1(text,text,text,jsonb) to service_role;
grant execute on function public.world8_merge_queue_snapshot_v1(text) to service_role;

comment on table public.world8_merge_queue is 'Serialized canonical merge queue for N-Mason Engineering Fabric. Coding may be parallel; canonical merge claim is single-writer.';
comment on table public.world8_merge_receipts is 'Immutable receipts for serialized canonical merges. Branch protection is required before merge claim when pool policy requires it.';
