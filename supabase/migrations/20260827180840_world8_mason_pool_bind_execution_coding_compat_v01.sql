create or replace function public.world8_mason_pool_bind_execution_v1(p_assignment_id text, p_execution_id text)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_a public.world8_mason_assignments%rowtype;
  v_e public.world8_actor_executions%rowtype;
begin
  select * into v_a
  from public.world8_mason_assignments
  where assignment_id=p_assignment_id
  for update;

  if not found or v_a.state not in ('WORK_BOUND','CODING','EXECUTING') or v_a.work_id is null then
    raise exception 'WORK_BOUND_OR_CODING_ASSIGNMENT_REQUIRED';
  end if;
  if v_a.state='CODING' and v_a.workspace_id is null then
    raise exception 'CODING_ASSIGNMENT_WORKSPACE_REQUIRED';
  end if;

  select * into v_e
  from public.world8_actor_executions
  where execution_id=p_execution_id and state='ACTIVE';
  if not found then raise exception 'ACTIVE_EXECUTION_REQUIRED'; end if;
  if v_e.actor_id<>v_a.actor_id then raise exception 'ASSIGNMENT_EXECUTION_ACTOR_MISMATCH'; end if;

  update public.world8_mason_assignments
  set execution_id=p_execution_id,
      state='EXECUTING',
      updated_at=clock_timestamp(),
      metadata=metadata||jsonb_build_object(
        'actual_provider',v_e.provider,
        'model_id',v_e.model_id,
        'execution_binding_contract','1.1'
      )
  where assignment_id=p_assignment_id;

  return jsonb_build_object(
    'assignment_id',p_assignment_id,
    'actor_id',v_a.actor_id,
    'execution_id',p_execution_id,
    'provider',v_e.provider,
    'state','EXECUTING',
    'execution_binding_contract','1.1'
  );
end
$function$;
