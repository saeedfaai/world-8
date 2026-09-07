-- Integrate World8 Governance Protection into repo-aware Merge Queue v2.
-- Requires 20260829_world8_governance_protection_private_repos_v1.sql.

create or replace function public.world8_merge_claim_next_v2(
  p_pool_id text,
  p_merger_actor text,
  p_canonical_resource_id text
) returns jsonb
language plpgsql security definer
set search_path to 'public'
as $$
declare
  v_resource jsonb;
  v_head text;
  v_q public.world8_merge_queue%rowtype;
  v_protection jsonb;
  v_validation_check_id text;
begin
  perform pg_advisory_xact_lock(hashtext('world8:canonical-merge:'||p_canonical_resource_id));
  if not exists(select 1 from public.world8_mason_pools where pool_id=p_pool_id and status='ACTIVE') then
    return jsonb_build_object('gate_state','BLOCKED','reason_code','ACTIVE_MASON_POOL_REQUIRED');
  end if;
  v_resource:=public.world8_dev_canonical_git_resource_current_v1(p_canonical_resource_id);
  v_head:=v_resource->>'canonical_head';
  if exists(select 1 from public.world8_merge_queue where pool_id=p_pool_id and canonical_resource_id=p_canonical_resource_id and state='MERGING') then
    return jsonb_build_object('gate_state','BLOCKED','reason_code','MERGE_ALREADY_IN_PROGRESS');
  end if;
  update public.world8_merge_queue
  set state='STALE_REBASE_REQUIRED',gate_reason='STALE_CANONICAL_BASE_AFTER_OTHER_MERGE',updated_at=clock_timestamp()
  where pool_id=p_pool_id and canonical_resource_id=p_canonical_resource_id and state in ('QUEUED','WAITING_CI') and base_commit<>v_head;

  select * into v_q from public.world8_merge_queue
  where pool_id=p_pool_id and canonical_resource_id=p_canonical_resource_id and state='QUEUED' and ci_state='PASS' and base_commit=v_head
  order by priority desc,created_at for update skip locked limit 1;
  if not found then
    return jsonb_build_object('gate_state','PASS','state','NO_READY_CANDIDATE','canonical_resource_id',p_canonical_resource_id,'canonical_head',v_head);
  end if;

  v_validation_check_id:=v_q.metadata->>'validation_check_id';
  v_protection:=public.world8_merge_protection_gate_v1(p_pool_id,p_canonical_resource_id,v_validation_check_id,v_q.head_commit);
  if coalesce(v_protection->>'gate_state','BLOCKED')<>'PASS' then
    update public.world8_merge_queue set gate_reason=v_protection->>'reason_code',updated_at=clock_timestamp() where queue_id=v_q.queue_id;
    return v_protection||jsonb_build_object('queue_id',v_q.queue_id,'canonical_resource_id',p_canonical_resource_id,'canonical_head',v_head);
  end if;

  update public.world8_merge_queue set state='MERGING',claimed_by=p_merger_actor,claimed_at=clock_timestamp(),gate_reason=null,
    metadata=coalesce(metadata,'{}'::jsonb)||jsonb_build_object('protection_gate',v_protection),updated_at=clock_timestamp()
  where queue_id=v_q.queue_id;
  return jsonb_build_object('gate_state','PASS','state','MERGING','queue_id',v_q.queue_id,'work_id',v_q.work_id,'actor_id',v_q.actor_id,
    'branch_ref',v_q.branch_ref,'head_commit',v_q.head_commit,'pr_number',v_q.pr_number,'canonical_resource_id',p_canonical_resource_id,
    'canonical_head',v_head,'conflicts',v_q.conflict_refs,'protection',v_protection);
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
  v_resource jsonb;
  v_old text;
  v_stale jsonb:='[]'::jsonb;
  v_payload jsonb;
  v_hash text;
  v_receipt text;
  v_protection jsonb;
begin
  if coalesce(btrim(p_new_canonical_head),'')='' then raise exception 'NEW_CANONICAL_HEAD_REQUIRED'; end if;
  if jsonb_typeof(coalesce(p_merge_evidence_refs,'[]'::jsonb))<>'array' then raise exception 'MERGE_EVIDENCE_MUST_BE_ARRAY'; end if;
  select * into v_q from public.world8_merge_queue where queue_id=p_queue_id for update;
  if not found or v_q.state<>'MERGING' or v_q.claimed_by<>p_merger_actor or v_q.canonical_resource_id is null then
    raise exception 'CLAIMED_REPO_AWARE_MERGE_REQUIRED';
  end if;
  perform pg_advisory_xact_lock(hashtext('world8:canonical-merge:'||v_q.canonical_resource_id));
  if not exists(select 1 from public.world8_mason_pools where pool_id=v_q.pool_id and status='ACTIVE') then raise exception 'ACTIVE_MASON_POOL_REQUIRED'; end if;
  v_resource:=public.world8_dev_canonical_git_resource_current_v1(v_q.canonical_resource_id);
  v_old:=v_resource->>'canonical_head';
  v_protection:=public.world8_merge_protection_gate_v1(v_q.pool_id,v_q.canonical_resource_id,v_q.metadata->>'validation_check_id',v_q.head_commit);
  if coalesce(v_protection->>'gate_state','BLOCKED')<>'PASS' then raise exception 'MERGE_PROTECTION_GATE_BLOCKED:%',coalesce(v_protection->>'reason_code','UNKNOWN'); end if;
  if v_q.base_commit<>v_old then raise exception 'STALE_CANONICAL_BASE'; end if;
  update public.world8_merge_queue set state='MERGED',gate_reason=null,metadata=coalesce(metadata,'{}'::jsonb)||jsonb_build_object('completion_protection_gate',v_protection),updated_at=v_now where queue_id=p_queue_id;
  update public.world8_dev_external_resources
  set metadata=metadata||jsonb_build_object('canonical_head_commit',p_new_canonical_head,'head_observed_at',v_now,
    'head_sync_reason','N_MASON_REPO_AWARE_SERIALIZED_MERGE','last_merge_queue_id',p_queue_id,'last_merge_actor',p_merger_actor),updated_at=v_now
  where resource_id=v_q.canonical_resource_id;
  update public.world8_merge_queue set state='STALE_REBASE_REQUIRED',gate_reason='STALE_CANONICAL_BASE_AFTER_OTHER_MERGE',updated_at=v_now
  where pool_id=v_q.pool_id and canonical_resource_id=v_q.canonical_resource_id and queue_id<>p_queue_id and state in ('QUEUED','WAITING_CI') and base_commit<>p_new_canonical_head;
  select coalesce(jsonb_agg(queue_id),'[]'::jsonb) into v_stale from public.world8_merge_queue
  where pool_id=v_q.pool_id and canonical_resource_id=v_q.canonical_resource_id and queue_id<>p_queue_id and state='STALE_REBASE_REQUIRED' and updated_at=v_now;
  v_payload:=jsonb_build_object('schema','WORLD8_MERGE_RECEIPT/2.1','canonical_resource_id',v_q.canonical_resource_id,'pool_id',v_q.pool_id,'queue_id',p_queue_id,
    'work_id',v_q.work_id,'actor_id',v_q.actor_id,'merger_actor',p_merger_actor,'old_canonical_head',v_old,'new_canonical_head',p_new_canonical_head,
    'pr_number',v_q.pr_number,'merge_evidence_refs',coalesce(p_merge_evidence_refs,'[]'::jsonb),'stale_queue_refs',v_stale,'protection',v_protection,'merged_at',v_now);
  v_hash:=encode(extensions.digest(convert_to(v_payload::text,'UTF8'),'sha256'),'hex');
  v_receipt:='merge-receipt-'||substr(v_hash,1,32);
  insert into public.world8_merge_receipts(merge_receipt_id,pool_id,queue_id,work_id,actor_id,merger_actor,old_canonical_head,new_canonical_head,pr_number,merge_evidence_refs,stale_queue_refs,merged_at,content_hash)
  values(v_receipt,v_q.pool_id,p_queue_id,v_q.work_id,v_q.actor_id,p_merger_actor,v_old,p_new_canonical_head,v_q.pr_number,coalesce(p_merge_evidence_refs,'[]'::jsonb),v_stale,v_now,v_hash);
  return v_payload||jsonb_build_object('merge_receipt_id',v_receipt,'content_hash',v_hash,'gate_state','PASS');
end$$;
