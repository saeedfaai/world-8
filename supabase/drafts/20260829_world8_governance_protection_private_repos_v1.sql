-- World8 Governance Protection fallback v1
-- Native protection remains preferred. Private fallback requires exact-head
-- validation proving CI infrastructure failed before tests ran.
create or replace function public.world8_merge_protection_gate_v1(p_pool_id text,p_canonical_resource_id text,p_validation_check_id text default null,p_head_commit text default null)
returns jsonb language plpgsql security definer set search_path to 'public' as $$
declare v_pool public.world8_mason_pools%rowtype; v_res public.world8_dev_external_resources%rowtype; v_check public.world8_operational_checks%rowtype; v_native text; v_repo text;
begin
 select * into v_pool from public.world8_mason_pools where pool_id=p_pool_id and status='ACTIVE'; if not found then return jsonb_build_object('gate_state','BLOCKED','reason_code','ACTIVE_MASON_POOL_REQUIRED'); end if;
 select * into v_res from public.world8_dev_external_resources where resource_id=p_canonical_resource_id and status='ACTIVE'; if not found then return jsonb_build_object('gate_state','BLOCKED','reason_code','ACTIVE_CANONICAL_RESOURCE_REQUIRED'); end if;
 v_native:=coalesce(v_res.metadata->>'branch_protection','UNCONFIGURED'); v_repo:=coalesce(v_res.metadata->>'repo_ref',replace(v_res.provider_ref,'github:',''));
 if not v_pool.branch_protection_required then return jsonb_build_object('gate_state','PASS','protection_mode','POOL_NOT_REQUIRED'); end if;
 if v_native in ('ENFORCED','RULESET_ENFORCED','PROTECTED') then return jsonb_build_object('gate_state','PASS','protection_mode','GITHUB_NATIVE'); end if;
 if lower(coalesce(v_res.metadata->>'visibility',''))<>'private' or not coalesce((v_res.metadata->>'branch_protection_limitation_acknowledged')::boolean,false) or not coalesce((v_res.metadata->>'no_world9_git_write')::boolean,false) then return jsonb_build_object('gate_state','BLOCKED','reason_code','GITHUB_BRANCH_PROTECTION_REQUIRED'); end if;
 if coalesce(p_validation_check_id,'')='' or coalesce(p_head_commit,'')='' then return jsonb_build_object('gate_state','BLOCKED','reason_code','GOVERNANCE_PROTECTION_EXACT_HEAD_VALIDATION_REQUIRED'); end if;
 select * into v_check from public.world8_operational_checks where check_id=p_validation_check_id;
 if not found or v_check.status<>'PASS' or coalesce(v_check.metadata->>'head_commit','')<>p_head_commit or lower(coalesce(v_check.metadata->>'repo_ref',''))<>lower(v_repo) then return jsonb_build_object('gate_state','BLOCKED','reason_code','GOVERNANCE_PROTECTION_VALIDATION_MISMATCH'); end if;
 if coalesce(v_check.metadata->>'failure_class','')<>'INFRASTRUCTURE_PRE_STEP' or coalesce((v_check.metadata->>'github_actions_runner_assigned')::boolean,true) then return jsonb_build_object('gate_state','BLOCKED','reason_code','EXTERNAL_VALIDATION_SUBSTITUTION_NOT_ELIGIBLE'); end if;
 return jsonb_build_object('gate_state','PASS','protection_mode','WORLD8_GOVERNED_PRIVATE_REPO_FALLBACK','validation_check_id',p_validation_check_id,'head_commit',p_head_commit);
end$$;

create or replace function public.world8_merge_claim_next_v2(p_pool_id text,p_merger_actor text,p_canonical_resource_id text)
returns jsonb language plpgsql security definer set search_path to 'public' as $$
declare v_resource jsonb; v_head text; v_q public.world8_merge_queue%rowtype; v_gate jsonb; v_validation text;
begin
 perform pg_advisory_xact_lock(hashtext('world8:canonical-merge:'||p_canonical_resource_id)); v_resource:=public.world8_dev_canonical_git_resource_current_v1(p_canonical_resource_id); v_head:=v_resource->>'canonical_head';
 if exists(select 1 from public.world8_merge_queue where pool_id=p_pool_id and canonical_resource_id=p_canonical_resource_id and state='MERGING') then return jsonb_build_object('gate_state','BLOCKED','reason_code','MERGE_ALREADY_IN_PROGRESS'); end if;
 update public.world8_merge_queue set state='STALE_REBASE_REQUIRED',gate_reason='STALE_CANONICAL_BASE_AFTER_OTHER_MERGE',updated_at=clock_timestamp() where pool_id=p_pool_id and canonical_resource_id=p_canonical_resource_id and state in ('QUEUED','WAITING_CI') and base_commit<>v_head;
 select * into v_q from public.world8_merge_queue where pool_id=p_pool_id and canonical_resource_id=p_canonical_resource_id and state='QUEUED' and ci_state='PASS' and base_commit=v_head order by priority desc,created_at for update skip locked limit 1;
 if not found then return jsonb_build_object('gate_state','PASS','state','NO_READY_CANDIDATE','canonical_resource_id',p_canonical_resource_id,'canonical_head',v_head); end if;
 v_validation:=v_q.metadata->>'validation_check_id'; v_gate:=public.world8_merge_protection_gate_v1(p_pool_id,p_canonical_resource_id,v_validation,v_q.head_commit);
 if v_gate->>'gate_state'<>'PASS' then return v_gate||jsonb_build_object('queue_id',v_q.queue_id,'canonical_resource_id',p_canonical_resource_id,'canonical_head',v_head); end if;
 update public.world8_merge_queue set state='MERGING',claimed_by=p_merger_actor,claimed_at=clock_timestamp(),gate_reason=null,metadata=metadata||jsonb_build_object('protection_gate_at_claim',v_gate),updated_at=clock_timestamp() where queue_id=v_q.queue_id;
 return jsonb_build_object('gate_state','PASS','state','MERGING','queue_id',v_q.queue_id,'work_id',v_q.work_id,'actor_id',v_q.actor_id,'branch_ref',v_q.branch_ref,'head_commit',v_q.head_commit,'pr_number',v_q.pr_number,'canonical_resource_id',p_canonical_resource_id,'canonical_head',v_head,'protection',v_gate,'conflicts',v_q.conflict_refs);
end$$;

create or replace function public.world8_merge_complete_v2(p_queue_id text,p_merger_actor text,p_new_canonical_head text,p_merge_evidence_refs jsonb default '[]'::jsonb)
returns jsonb language plpgsql security definer set search_path to 'public','extensions' as $$
declare v_now timestamptz:=clock_timestamp(); v_q public.world8_merge_queue%rowtype; v_resource jsonb; v_old text; v_gate jsonb; v_validation text; v_stale jsonb:='[]'::jsonb; v_payload jsonb; v_hash text; v_receipt text;
begin
 if coalesce(btrim(p_new_canonical_head),'')='' then raise exception 'NEW_CANONICAL_HEAD_REQUIRED'; end if; if jsonb_typeof(coalesce(p_merge_evidence_refs,'[]'::jsonb))<>'array' then raise exception 'MERGE_EVIDENCE_MUST_BE_ARRAY'; end if;
 select * into v_q from public.world8_merge_queue where queue_id=p_queue_id for update; if not found or v_q.state<>'MERGING' or v_q.claimed_by<>p_merger_actor or v_q.canonical_resource_id is null then raise exception 'CLAIMED_REPO_AWARE_MERGE_REQUIRED'; end if;
 perform pg_advisory_xact_lock(hashtext('world8:canonical-merge:'||v_q.canonical_resource_id)); v_resource:=public.world8_dev_canonical_git_resource_current_v1(v_q.canonical_resource_id); v_old:=v_resource->>'canonical_head'; if v_q.base_commit<>v_old then raise exception 'STALE_CANONICAL_BASE'; end if;
 v_validation:=v_q.metadata->>'validation_check_id'; v_gate:=public.world8_merge_protection_gate_v1(v_q.pool_id,v_q.canonical_resource_id,v_validation,v_q.head_commit); if v_gate->>'gate_state'<>'PASS' then raise exception 'GOVERNANCE_PROTECTION_REQUIRED: %',coalesce(v_gate->>'reason_code','BLOCKED'); end if;
 update public.world8_merge_queue set state='MERGED',gate_reason=null,metadata=metadata||jsonb_build_object('protection_gate_at_complete',v_gate),updated_at=v_now where queue_id=p_queue_id;
 update public.world8_dev_external_resources set metadata=metadata||jsonb_build_object('canonical_head_commit',p_new_canonical_head,'head_observed_at',v_now,'head_sync_reason','N_MASON_REPO_AWARE_SERIALIZED_MERGE','last_merge_queue_id',p_queue_id,'last_merge_actor',p_merger_actor),updated_at=v_now where resource_id=v_q.canonical_resource_id;
 update public.world8_merge_queue set state='STALE_REBASE_REQUIRED',gate_reason='STALE_CANONICAL_BASE_AFTER_OTHER_MERGE',updated_at=v_now where pool_id=v_q.pool_id and canonical_resource_id=v_q.canonical_resource_id and queue_id<>p_queue_id and state in ('QUEUED','WAITING_CI') and base_commit<>p_new_canonical_head;
 select coalesce(jsonb_agg(queue_id),'[]'::jsonb) into v_stale from public.world8_merge_queue where pool_id=v_q.pool_id and canonical_resource_id=v_q.canonical_resource_id and queue_id<>p_queue_id and state='STALE_REBASE_REQUIRED' and updated_at=v_now;
 v_payload:=jsonb_build_object('schema','WORLD8_MERGE_RECEIPT/2.1','canonical_resource_id',v_q.canonical_resource_id,'pool_id',v_q.pool_id,'queue_id',p_queue_id,'work_id',v_q.work_id,'actor_id',v_q.actor_id,'merger_actor',p_merger_actor,'old_canonical_head',v_old,'new_canonical_head',p_new_canonical_head,'pr_number',v_q.pr_number,'protection',v_gate,'merge_evidence_refs',coalesce(p_merge_evidence_refs,'[]'::jsonb),'stale_queue_refs',v_stale,'merged_at',v_now);
 v_hash:=encode(extensions.digest(convert_to(v_payload::text,'UTF8'),'sha256'),'hex'); v_receipt:='merge-receipt-'||substr(v_hash,1,32); insert into public.world8_merge_receipts(merge_receipt_id,pool_id,queue_id,work_id,actor_id,merger_actor,old_canonical_head,new_canonical_head,pr_number,merge_evidence_refs,stale_queue_refs,merged_at,content_hash) values(v_receipt,v_q.pool_id,p_queue_id,v_q.work_id,v_q.actor_id,p_merger_actor,v_old,p_new_canonical_head,v_q.pr_number,coalesce(p_merge_evidence_refs,'[]'::jsonb),v_stale,v_now,v_hash);
 return v_payload||jsonb_build_object('merge_receipt_id',v_receipt,'content_hash',v_hash,'gate_state','PASS');
end$$;
