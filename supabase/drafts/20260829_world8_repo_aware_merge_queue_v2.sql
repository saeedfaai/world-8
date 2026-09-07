-- World8 Repo-Aware Merge Queue v2
-- Draft only. v1 remains intact until v2 validation and governed deployment.

alter table public.world8_merge_queue
  add column if not exists canonical_resource_id text;

update public.world8_merge_queue q
set canonical_resource_id=b.canonical_resource_id
from public.world8_dev_workspace_git_bindings b
where q.workspace_id=b.workspace_id
  and q.canonical_resource_id is null;

create index if not exists world8_merge_queue_resource_state_idx
  on public.world8_merge_queue(canonical_resource_id,pool_id,state,priority,created_at);

create or replace function public.world8_merge_enqueue_v2(
  p_assignment_id text,
  p_head_commit text,
  p_pr_number bigint,
  p_validation_check_id text,
  p_touches jsonb default '[]'::jsonb,
  p_priority integer default 100,
  p_metadata jsonb default '{}'::jsonb
) returns jsonb
language plpgsql security definer
set search_path to 'public','extensions'
as $$
declare
  v_now timestamptz:=clock_timestamp();
  v_a public.world8_mason_assignments%rowtype;
  v_w public.world8_dev_work_items%rowtype;
  v_ws public.world8_dev_workspaces%rowtype;
  v_bind public.world8_dev_workspace_git_bindings%rowtype;
  v_pool public.world8_mason_pools%rowtype;
  v_check public.world8_operational_checks%rowtype;
  v_resource jsonb;
  v_canonical text;
  v_protection text;
  v_state text;
  v_gate text:=null;
  v_conflicts jsonb:='[]'::jsonb;
  v_id text;
begin
  if p_priority<0 or p_priority>1000 then raise exception 'INVALID_MERGE_PRIORITY'; end if;
  if coalesce(btrim(p_head_commit),'')='' then raise exception 'HEAD_COMMIT_REQUIRED'; end if;
  if jsonb_typeof(coalesce(p_touches,'[]'::jsonb))<>'array' then raise exception 'TOUCHES_MUST_BE_ARRAY'; end if;

  select * into v_a from public.world8_mason_assignments where assignment_id=p_assignment_id;
  if not found or v_a.state<>'READY_FOR_REVIEW' or v_a.work_id is null or v_a.workspace_id is null then
    raise exception 'READY_ASSIGNMENT_REQUIRED';
  end if;
  select * into v_w from public.world8_dev_work_items where work_id=v_a.work_id;
  if not found or v_w.actor_ref<>v_a.actor_id then raise exception 'ASSIGNMENT_WORK_ACTOR_MISMATCH'; end if;
  select * into v_ws from public.world8_dev_workspaces where workspace_id=v_a.workspace_id and state='ACTIVE';
  if not found or v_ws.actor_id<>v_a.actor_id or v_ws.work_id<>v_a.work_id then raise exception 'ACTIVE_ASSIGNMENT_WORKSPACE_REQUIRED'; end if;
  select * into v_bind from public.world8_dev_workspace_git_bindings where workspace_id=v_ws.workspace_id;
  if not found then raise exception 'WORKSPACE_GIT_BINDING_REQUIRED'; end if;
  if lower(v_ws.branch_ref) in ('main','master',lower(v_bind.default_branch)) then raise exception 'CANONICAL_BRANCH_WRITE_FORBIDDEN'; end if;

  v_resource:=public.world8_dev_canonical_git_resource_current_v1(v_bind.canonical_resource_id);
  if lower(v_ws.repo_ref)<>lower(v_resource->>'repo_ref') then raise exception 'WORKSPACE_RESOURCE_REPO_MISMATCH'; end if;
  v_canonical:=v_resource->>'canonical_head';
  select metadata->>'branch_protection' into v_protection
  from public.world8_dev_external_resources where resource_id=v_bind.canonical_resource_id and status='ACTIVE';

  select * into v_pool from public.world8_mason_pools where pool_id=v_a.pool_id and status='ACTIVE';
  if not found then raise exception 'ACTIVE_MASON_POOL_REQUIRED'; end if;

  select * into v_check from public.world8_operational_checks where check_id=p_validation_check_id;
  if not found or v_check.status<>'PASS' then raise exception 'PASS_VALIDATION_CHECK_REQUIRED'; end if;
  if coalesce(v_check.metadata->>'head_commit','')<>p_head_commit then raise exception 'VALIDATION_HEAD_MISMATCH'; end if;
  if coalesce(v_check.metadata->>'repo_ref','')<>v_ws.repo_ref then raise exception 'VALIDATION_REPO_MISMATCH'; end if;

  if v_ws.base_commit<>v_canonical then
    v_state:='STALE_REBASE_REQUIRED'; v_gate:='STALE_CANONICAL_BASE';
  else
    v_state:='QUEUED';
  end if;
  if v_pool.branch_protection_required and coalesce(v_protection,'UNCONFIGURED') not in ('ENFORCED','RULESET_ENFORCED','PROTECTED') then
    v_gate:=case when v_gate is null then 'GITHUB_BRANCH_PROTECTION_REQUIRED' else v_gate||'+GITHUB_BRANCH_PROTECTION_REQUIRED' end;
  end if;

  select coalesce(jsonb_agg(jsonb_build_object('queue_id',q.queue_id,'work_id',q.work_id,'branch_ref',q.branch_ref,'state',q.state)),'[]'::jsonb)
  into v_conflicts
  from public.world8_merge_queue q
  where q.canonical_resource_id=v_bind.canonical_resource_id
    and q.repo_ref=v_ws.repo_ref
    and q.state in ('WAITING_CI','QUEUED','MERGING','STALE_REBASE_REQUIRED')
    and exists(
      select 1 from jsonb_array_elements_text(q.touches) x(value)
      join jsonb_array_elements_text(coalesce(p_touches,'[]'::jsonb)) y(value) on x.value=y.value
    );

  v_id:='mergeq-'||substr(encode(extensions.digest(v_a.pool_id||'|'||v_a.assignment_id||'|'||p_head_commit||'|'||v_bind.canonical_resource_id||'|'||v_now::text,'sha256'),'hex'),1,32);
  insert into public.world8_merge_queue(
    queue_id,pool_id,assignment_id,work_id,actor_id,workspace_id,repo_ref,branch_ref,base_commit,head_commit,
    pr_number,ci_run_id,ci_state,touches,priority,state,gate_reason,conflict_refs,canonical_head_at_enqueue,
    canonical_resource_id,metadata,created_at,updated_at
  ) values(
    v_id,v_a.pool_id,v_a.assignment_id,v_a.work_id,v_a.actor_id,v_a.workspace_id,v_ws.repo_ref,v_ws.branch_ref,v_ws.base_commit,p_head_commit,
    p_pr_number,null,'PASS',coalesce(p_touches,'[]'::jsonb),p_priority,v_state,v_gate,v_conflicts,v_canonical,
    v_bind.canonical_resource_id,coalesce(p_metadata,'{}'::jsonb)||jsonb_build_object('validation_check_id',p_validation_check_id,'validation_source','WORLD8_EXTERNAL_VALIDATION'),v_now,v_now
  );
  return jsonb_build_object('schema','WORLD8_MERGE_QUEUE/2.0','queue_id',v_id,'pool_id',v_a.pool_id,'work_id',v_a.work_id,
    'actor_id',v_a.actor_id,'branch_ref',v_ws.branch_ref,'head_commit',p_head_commit,'state',v_state,'gate_reason',v_gate,
    'canonical_resource_id',v_bind.canonical_resource_id,'canonical_head',v_canonical,'validation_check_id',p_validation_check_id,'conflicts',v_conflicts);
end$$;

create or replace function public.world8_merge_claim_next_v2(
  p_pool_id text,
  p_merger_actor text,
  p_canonical_resource_id text
) returns jsonb
language plpgsql security definer
set search_path to 'public'
as $$
declare
  v_pool public.world8_mason_pools%rowtype;
  v_resource jsonb;
  v_head text;
  v_protection text;
  v_q public.world8_merge_queue%rowtype;
begin
  perform pg_advisory_xact_lock(hashtext('world8:canonical-merge:'||p_canonical_resource_id));
  select * into v_pool from public.world8_mason_pools where pool_id=p_pool_id and status='ACTIVE';
  if not found then return jsonb_build_object('gate_state','BLOCKED','reason_code','ACTIVE_MASON_POOL_REQUIRED'); end if;
  v_resource:=public.world8_dev_canonical_git_resource_current_v1(p_canonical_resource_id);
  v_head:=v_resource->>'canonical_head';
  select metadata->>'branch_protection' into v_protection from public.world8_dev_external_resources where resource_id=p_canonical_resource_id and status='ACTIVE';
  if v_pool.branch_protection_required and coalesce(v_protection,'UNCONFIGURED') not in ('ENFORCED','RULESET_ENFORCED','PROTECTED') then
    return jsonb_build_object('gate_state','BLOCKED','reason_code','GITHUB_BRANCH_PROTECTION_REQUIRED','canonical_resource_id',p_canonical_resource_id,'canonical_head',v_head);
  end if;
  if exists(select 1 from public.world8_merge_queue where pool_id=p_pool_id and canonical_resource_id=p_canonical_resource_id and state='MERGING') then
    return jsonb_build_object('gate_state','BLOCKED','reason_code','MERGE_ALREADY_IN_PROGRESS');
  end if;
  update public.world8_merge_queue set state='STALE_REBASE_REQUIRED',gate_reason='STALE_CANONICAL_BASE_AFTER_OTHER_MERGE',updated_at=clock_timestamp()
  where pool_id=p_pool_id and canonical_resource_id=p_canonical_resource_id and state in ('QUEUED','WAITING_CI') and base_commit<>v_head;
  select * into v_q from public.world8_merge_queue
  where pool_id=p_pool_id and canonical_resource_id=p_canonical_resource_id and state='QUEUED' and ci_state='PASS' and base_commit=v_head
  order by priority desc,created_at for update skip locked limit 1;
  if not found then return jsonb_build_object('gate_state','PASS','state','NO_READY_CANDIDATE','canonical_resource_id',p_canonical_resource_id,'canonical_head',v_head); end if;
  update public.world8_merge_queue set state='MERGING',claimed_by=p_merger_actor,claimed_at=clock_timestamp(),gate_reason=null,updated_at=clock_timestamp() where queue_id=v_q.queue_id;
  return jsonb_build_object('gate_state','PASS','state','MERGING','queue_id',v_q.queue_id,'work_id',v_q.work_id,'actor_id',v_q.actor_id,'branch_ref',v_q.branch_ref,
    'head_commit',v_q.head_commit,'pr_number',v_q.pr_number,'canonical_resource_id',p_canonical_resource_id,'canonical_head',v_head,'conflicts',v_q.conflict_refs);
end$$;

create or replace function public.world8_merge_complete_v2(
  p_queue_id text,
  p_merger_actor text,
  p_new_canonical_head text,
  p_merge_evidence_refs jsonb default '[]'::jsonb
) returns jsonb
language plpgsql security definer
set search_path to 'public','extensions'
as $$
declare
  v_now timestamptz:=clock_timestamp();
  v_q public.world8_merge_queue%rowtype;
  v_pool public.world8_mason_pools%rowtype;
  v_resource jsonb;
  v_old text;
  v_protection text;
  v_stale jsonb:='[]'::jsonb;
  v_payload jsonb;
  v_hash text;
  v_receipt text;
begin
  if coalesce(btrim(p_new_canonical_head),'')='' then raise exception 'NEW_CANONICAL_HEAD_REQUIRED'; end if;
  if jsonb_typeof(coalesce(p_merge_evidence_refs,'[]'::jsonb))<>'array' then raise exception 'MERGE_EVIDENCE_MUST_BE_ARRAY'; end if;
  select * into v_q from public.world8_merge_queue where queue_id=p_queue_id for update;
  if not found or v_q.state<>'MERGING' or v_q.claimed_by<>p_merger_actor or v_q.canonical_resource_id is null then raise exception 'CLAIMED_REPO_AWARE_MERGE_REQUIRED'; end if;
  perform pg_advisory_xact_lock(hashtext('world8:canonical-merge:'||v_q.canonical_resource_id));
  select * into v_pool from public.world8_mason_pools where pool_id=v_q.pool_id and status='ACTIVE';
  if not found then raise exception 'ACTIVE_MASON_POOL_REQUIRED'; end if;
  v_resource:=public.world8_dev_canonical_git_resource_current_v1(v_q.canonical_resource_id);
  v_old:=v_resource->>'canonical_head';
  select metadata->>'branch_protection' into v_protection from public.world8_dev_external_resources where resource_id=v_q.canonical_resource_id and status='ACTIVE' for update;
  if v_pool.branch_protection_required and coalesce(v_protection,'UNCONFIGURED') not in ('ENFORCED','RULESET_ENFORCED','PROTECTED') then raise exception 'GITHUB_BRANCH_PROTECTION_REQUIRED'; end if;
  if v_q.base_commit<>v_old then raise exception 'STALE_CANONICAL_BASE'; end if;
  update public.world8_merge_queue set state='MERGED',gate_reason=null,updated_at=v_now where queue_id=p_queue_id;
  update public.world8_dev_external_resources
  set metadata=metadata||jsonb_build_object('canonical_head_commit',p_new_canonical_head,'head_observed_at',v_now,'head_sync_reason','N_MASON_REPO_AWARE_SERIALIZED_MERGE','last_merge_queue_id',p_queue_id,'last_merge_actor',p_merger_actor),updated_at=v_now
  where resource_id=v_q.canonical_resource_id;
  update public.world8_merge_queue
  set state='STALE_REBASE_REQUIRED',gate_reason='STALE_CANONICAL_BASE_AFTER_OTHER_MERGE',updated_at=v_now
  where pool_id=v_q.pool_id and canonical_resource_id=v_q.canonical_resource_id and queue_id<>p_queue_id and state in ('QUEUED','WAITING_CI') and base_commit<>p_new_canonical_head;
  select coalesce(jsonb_agg(queue_id),'[]'::jsonb) into v_stale from public.world8_merge_queue
  where pool_id=v_q.pool_id and canonical_resource_id=v_q.canonical_resource_id and queue_id<>p_queue_id and state='STALE_REBASE_REQUIRED' and updated_at=v_now;
  v_payload:=jsonb_build_object('schema','WORLD8_MERGE_RECEIPT/2.0','canonical_resource_id',v_q.canonical_resource_id,'pool_id',v_q.pool_id,'queue_id',p_queue_id,
    'work_id',v_q.work_id,'actor_id',v_q.actor_id,'merger_actor',p_merger_actor,'old_canonical_head',v_old,'new_canonical_head',p_new_canonical_head,
    'pr_number',v_q.pr_number,'merge_evidence_refs',coalesce(p_merge_evidence_refs,'[]'::jsonb),'stale_queue_refs',v_stale,'merged_at',v_now);
  v_hash:=encode(extensions.digest(convert_to(v_payload::text,'UTF8'),'sha256'),'hex');
  v_receipt:='merge-receipt-'||substr(v_hash,1,32);
  insert into public.world8_merge_receipts(merge_receipt_id,pool_id,queue_id,work_id,actor_id,merger_actor,old_canonical_head,new_canonical_head,pr_number,merge_evidence_refs,stale_queue_refs,merged_at,content_hash)
  values(v_receipt,v_q.pool_id,p_queue_id,v_q.work_id,v_q.actor_id,p_merger_actor,v_old,p_new_canonical_head,v_q.pr_number,coalesce(p_merge_evidence_refs,'[]'::jsonb),v_stale,v_now,v_hash);
  return v_payload||jsonb_build_object('merge_receipt_id',v_receipt,'content_hash',v_hash,'gate_state','PASS');
end$$;
