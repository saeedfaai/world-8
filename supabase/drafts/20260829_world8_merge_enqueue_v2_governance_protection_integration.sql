-- Enqueue-side integration for World8 Governance Protection.

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
  v_check public.world8_operational_checks%rowtype;
  v_resource jsonb;
  v_canonical text;
  v_state text;
  v_gate text:=null;
  v_conflicts jsonb:='[]'::jsonb;
  v_id text;
  v_protection jsonb;
begin
  if p_priority<0 or p_priority>1000 then raise exception 'INVALID_MERGE_PRIORITY'; end if;
  if coalesce(btrim(p_head_commit),'')='' then raise exception 'HEAD_COMMIT_REQUIRED'; end if;
  if jsonb_typeof(coalesce(p_touches,'[]'::jsonb))<>'array' then raise exception 'TOUCHES_MUST_BE_ARRAY'; end if;

  select * into v_a from public.world8_mason_assignments where assignment_id=p_assignment_id;
  if not found or v_a.state<>'READY_FOR_REVIEW' or v_a.work_id is null or v_a.workspace_id is null then raise exception 'READY_ASSIGNMENT_REQUIRED'; end if;
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
  if not exists(select 1 from public.world8_mason_pools where pool_id=v_a.pool_id and status='ACTIVE') then raise exception 'ACTIVE_MASON_POOL_REQUIRED'; end if;

  select * into v_check from public.world8_operational_checks where check_id=p_validation_check_id;
  if not found or v_check.status<>'PASS' then raise exception 'PASS_VALIDATION_CHECK_REQUIRED'; end if;
  if coalesce(v_check.metadata->>'head_commit','')<>p_head_commit then raise exception 'VALIDATION_HEAD_MISMATCH'; end if;
  if coalesce(v_check.metadata->>'repo_ref','')<>v_ws.repo_ref then raise exception 'VALIDATION_REPO_MISMATCH'; end if;

  if v_ws.base_commit<>v_canonical then
    v_state:='STALE_REBASE_REQUIRED'; v_gate:='STALE_CANONICAL_BASE';
  else
    v_state:='QUEUED';
  end if;

  v_protection:=public.world8_merge_protection_gate_v1(v_a.pool_id,v_bind.canonical_resource_id,p_validation_check_id,p_head_commit);
  if coalesce(v_protection->>'gate_state','BLOCKED')<>'PASS' then
    v_gate:=case when v_gate is null then v_protection->>'reason_code' else v_gate||'+'||coalesce(v_protection->>'reason_code','PROTECTION_BLOCKED') end;
  end if;

  select coalesce(jsonb_agg(jsonb_build_object('queue_id',q.queue_id,'work_id',q.work_id,'branch_ref',q.branch_ref,'state',q.state)),'[]'::jsonb)
  into v_conflicts from public.world8_merge_queue q
  where q.canonical_resource_id=v_bind.canonical_resource_id and q.repo_ref=v_ws.repo_ref
    and q.state in ('WAITING_CI','QUEUED','MERGING','STALE_REBASE_REQUIRED')
    and exists(select 1 from jsonb_array_elements_text(q.touches) x(value)
      join jsonb_array_elements_text(coalesce(p_touches,'[]'::jsonb)) y(value) on x.value=y.value);

  v_id:='mergeq-'||substr(encode(extensions.digest(v_a.pool_id||'|'||v_a.assignment_id||'|'||p_head_commit||'|'||v_bind.canonical_resource_id||'|'||v_now::text,'sha256'),'hex'),1,32);
  insert into public.world8_merge_queue(queue_id,pool_id,assignment_id,work_id,actor_id,workspace_id,repo_ref,branch_ref,base_commit,head_commit,
    pr_number,ci_run_id,ci_state,touches,priority,state,gate_reason,conflict_refs,canonical_head_at_enqueue,canonical_resource_id,metadata,created_at,updated_at)
  values(v_id,v_a.pool_id,v_a.assignment_id,v_a.work_id,v_a.actor_id,v_a.workspace_id,v_ws.repo_ref,v_ws.branch_ref,v_ws.base_commit,p_head_commit,
    p_pr_number,null,'PASS',coalesce(p_touches,'[]'::jsonb),p_priority,v_state,v_gate,v_conflicts,v_canonical,v_bind.canonical_resource_id,
    coalesce(p_metadata,'{}'::jsonb)||jsonb_build_object('validation_check_id',p_validation_check_id,'validation_source','WORLD8_EXTERNAL_VALIDATION','protection_gate',v_protection),v_now,v_now);

  return jsonb_build_object('schema','WORLD8_MERGE_QUEUE/2.1','queue_id',v_id,'pool_id',v_a.pool_id,'work_id',v_a.work_id,'actor_id',v_a.actor_id,
    'branch_ref',v_ws.branch_ref,'head_commit',p_head_commit,'state',v_state,'gate_reason',v_gate,'canonical_resource_id',v_bind.canonical_resource_id,
    'canonical_head',v_canonical,'validation_check_id',p_validation_check_id,'protection',v_protection,'conflicts',v_conflicts);
end$$;
