-- World 8 Academy Checkride hardening v0.2
-- A PASS must evidence every frozen curriculum required_ref; qualification still grants no authority.
create or replace function public.world8_academy_record_checkride_v1(
  p_subject_actor_id text,p_evaluator_actor_id text,p_curriculum_id text,p_result text,p_score numeric,
  p_evidence_refs jsonb default '[]'::jsonb,p_metadata jsonb default '{}'::jsonb
) returns jsonb language plpgsql security definer set search_path=public,extensions as $$
declare c public.world8_academy_curricula%rowtype; v_now timestamptz:=clock_timestamp(); v_hash text; v_id text; v_missing jsonb;
begin
  if p_subject_actor_id=p_evaluator_actor_id then raise exception 'CHECKRIDE_SELF_EVALUATION_FORBIDDEN'; end if;
  if p_result not in ('PASS','FAIL') then raise exception 'INVALID_CHECKRIDE_RESULT'; end if;
  if p_score<0 or p_score>1 then raise exception 'INVALID_CHECKRIDE_SCORE'; end if;
  if jsonb_typeof(coalesce(p_evidence_refs,'[]'::jsonb))<>'array' then raise exception 'EVIDENCE_REFS_MUST_BE_ARRAY'; end if;
  if not exists(select 1 from public.world8_actor_registry where actor_id=p_subject_actor_id and status='ACTIVE') then raise exception 'ACTIVE_SUBJECT_ACTOR_REQUIRED'; end if;
  if not exists(select 1 from public.world8_actor_registry where actor_id=p_evaluator_actor_id and status='ACTIVE') then raise exception 'ACTIVE_EVALUATOR_ACTOR_REQUIRED'; end if;
  select * into c from public.world8_academy_curricula where curriculum_id=p_curriculum_id and status='FROZEN';
  if not found then raise exception 'ACTIVE_CURRICULUM_NOT_FOUND'; end if;
  select coalesce(jsonb_agg(req), '[]'::jsonb) into v_missing
  from jsonb_array_elements_text(c.required_refs) req
  where not (coalesce(p_evidence_refs,'[]'::jsonb) ? req);
  if p_result='PASS' and (p_score<c.min_score or jsonb_array_length(coalesce(p_evidence_refs,'[]'::jsonb))=0 or jsonb_array_length(v_missing)>0) then
    raise exception 'PASS_CHECKRIDE_EVIDENCE_OR_SCORE_INSUFFICIENT missing=%',v_missing;
  end if;
  v_hash:=encode(extensions.digest(p_subject_actor_id||'|'||p_evaluator_actor_id||'|'||p_curriculum_id||'|'||p_result||'|'||p_score::text||'|'||coalesce(p_evidence_refs,'[]'::jsonb)::text||'|'||v_now::text,'sha256'),'hex');
  v_id:='academy-checkride-'||substr(v_hash,1,28);
  insert into public.world8_academy_checkride_receipts(checkride_receipt_id,subject_actor_id,evaluator_actor_id,curriculum_id,qualification_kind,qualification_ref,qualification_version,result,score,evidence_refs,metadata,content_hash,created_at)
  values(v_id,p_subject_actor_id,p_evaluator_actor_id,p_curriculum_id,c.qualification_kind,c.qualification_ref,c.qualification_version,p_result,p_score,coalesce(p_evidence_refs,'[]'::jsonb),coalesce(p_metadata,'{}'::jsonb)||jsonb_build_object('authorization_granted',false,'required_refs_verified',true),v_hash,v_now);
  return jsonb_build_object('schema','WORLD8_ACADEMY_CHECKRIDE/1.1','checkride_receipt_id',v_id,'subject_actor_id',p_subject_actor_id,'result',p_result,'score',p_score,'qualification_ref',c.qualification_ref,'qualification_version',c.qualification_version,'required_refs_verified',true,'authorization_granted',false,'content_hash',v_hash);
end $$;
