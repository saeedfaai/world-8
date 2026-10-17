-- World 8 N-Mason exact-existing-actor assignment repair v0.2
-- Purpose: allow a pre-existing Work already canonically bound to an Actor
-- to obtain a governed Mason Assignment for that exact Actor without
-- changing Work.actor_ref, fabricating rows outside the Mason subsystem,
-- or stealing another live Assignment.

create or replace function public.world8_mason_pool_reserve_exact_work_actor_v1(
  p_pool_id text,
  p_requested_by text,
  p_work_id text,
  p_provider_hint text default null,
  p_required_qualifications jsonb default '[]'::jsonb,
  p_ttl_minutes integer default 120
)
returns jsonb
language plpgsql
security definer
set search_path to 'public','extensions'
as $function$
declare
  v_pool public.world8_mason_pools%rowtype;
  v_work public.world8_dev_work_items%rowtype;
  v_member public.world8_mason_pool_members%rowtype;
  v_existing public.world8_mason_assignments%rowtype;
  v_now timestamptz := clock_timestamp();
  v_actor_id text;
  v_head text;
  v_id text;
begin
  if p_ttl_minutes < 15 or p_ttl_minutes > 720 then
    raise exception 'ASSIGNMENT_TTL_OUT_OF_RANGE';
  end if;
  if jsonb_typeof(coalesce(p_required_qualifications,'[]'::jsonb)) <> 'array' then
    raise exception 'QUALIFICATIONS_MUST_BE_ARRAY';
  end if;

  select * into v_pool
  from public.world8_mason_pools
  where pool_id = p_pool_id and status = 'ACTIVE';
  if not found or not v_pool.coding_enabled then
    raise exception 'MASON_POOL_CODING_DISABLED';
  end if;

  select * into v_work
  from public.world8_dev_work_items
  where work_id = p_work_id;
  if not found then
    raise exception 'WORK_NOT_FOUND';
  end if;

  v_actor_id := nullif(v_work.actor_ref,'');
  if v_actor_id is null then
    raise exception 'WORK_ACTOR_REQUIRED';
  end if;

  -- Expiry cleanup is identical in spirit to the generic reservation path.
  update public.world8_mason_assignments
     set state = 'EXPIRED', updated_at = v_now
   where pool_id = p_pool_id
     and state in ('RESERVED','WORK_BOUND','EXECUTING','CODING','READY_FOR_REVIEW')
     and expires_at <= v_now;

  -- Lock the exact Actor's pool membership. The generic reserve path also
  -- locks pool-member rows, so this prevents it from concurrently selecting
  -- the same Actor while this exact-actor adoption is being decided.
  select * into v_member
  from public.world8_mason_pool_members
  where pool_id = p_pool_id
    and actor_id = v_actor_id
    and status = 'ACTIVE'
  for update;
  if not found then
    raise exception 'EXACT_WORK_ACTOR_NOT_ACTIVE_POOL_MEMBER';
  end if;

  if p_provider_hint is not null
     and jsonb_array_length(v_member.provider_hints) > 0
     and not (v_member.provider_hints ? p_provider_hint) then
    raise exception 'EXACT_WORK_ACTOR_PROVIDER_HINT_INCOMPATIBLE';
  end if;

  if exists (
    select 1
    from jsonb_array_elements(coalesce(p_required_qualifications,'[]'::jsonb)) req
    where coalesce(req->>'qualification_ref','') = ''
       or not exists (
         select 1
         from public.world8_actor_qualifications q
         where q.actor_id = v_actor_id
           and q.status = 'ACTIVE'
           and q.qualification_ref = req->>'qualification_ref'
           and (q.expires_at is null or q.expires_at > v_now)
           and (
             coalesce(req->>'required_version','') = ''
             or q.qualification_version = req->>'required_version'
           )
       )
  ) then
    raise exception 'EXACT_WORK_ACTOR_QUALIFICATION_REQUIRED';
  end if;

  -- Idempotent replay is allowed only for the exact same pool/work/actor.
  select * into v_existing
  from public.world8_mason_assignments
  where work_id = p_work_id
    and state in ('WORK_BOUND','EXECUTING','CODING','READY_FOR_REVIEW')
    and expires_at > v_now
  for update;
  if found then
    if v_existing.actor_id <> v_actor_id then
      raise exception 'WORK_ACTIVE_ASSIGNMENT_ACTOR_MISMATCH';
    end if;
    if v_existing.pool_id <> p_pool_id then
      raise exception 'WORK_ACTIVE_ASSIGNMENT_POOL_MISMATCH';
    end if;
    return jsonb_build_object(
      'schema','WORLD8_MASON_ASSIGNMENT/1.1',
      'assignment_id',v_existing.assignment_id,
      'pool_id',v_existing.pool_id,
      'actor_id',v_existing.actor_id,
      'work_id',v_existing.work_id,
      'state',v_existing.state,
      'canonical_head',v_existing.canonical_head_at_reservation,
      'expires_at',v_existing.expires_at,
      'exact_existing_actor_adoption',true,
      'idempotent_replay',true
    );
  end if;

  -- Never steal/rebind an Actor that is doing another live Work.
  if exists (
    select 1
    from public.world8_mason_assignments a
    where a.actor_id = v_actor_id
      and a.state in ('RESERVED','WORK_BOUND','EXECUTING','CODING','READY_FOR_REVIEW')
      and a.expires_at > v_now
  ) then
    raise exception 'ACTOR_ACTIVE_ASSIGNMENT_CONFLICT';
  end if;

  -- Never overwrite a live Assignment already bound to this Work.
  if exists (
    select 1
    from public.world8_mason_assignments a
    where a.work_id = p_work_id
      and a.state in ('WORK_BOUND','EXECUTING','CODING','READY_FOR_REVIEW')
      and a.expires_at > v_now
  ) then
    raise exception 'WORK_ACTIVE_ASSIGNMENT_CONFLICT';
  end if;

  select metadata->>'canonical_head_commit' into v_head
  from public.world8_dev_external_resources
  where resource_id = 'resource-github-world8-canonical'
    and status = 'ACTIVE';
  if coalesce(v_head,'') = '' then
    raise exception 'CANONICAL_GIT_REQUIRED';
  end if;

  v_id := 'assignment-' || substr(
    encode(extensions.digest(
      p_pool_id || '|' || v_actor_id || '|' || p_work_id || '|' || p_requested_by || '|' || v_now::text,
      'sha256'
    ),'hex'),
    1,32
  );

  begin
    insert into public.world8_mason_assignments(
      assignment_id,pool_id,actor_id,work_id,provider_hint,source_room,
      required_qualifications,state,reserved_by,canonical_head_at_reservation,
      expires_at,metadata
    ) values (
      v_id,p_pool_id,v_actor_id,p_work_id,p_provider_hint,v_work.source_room,
      coalesce(p_required_qualifications,'[]'::jsonb),'WORK_BOUND',p_requested_by,
      v_head,v_now + make_interval(mins => p_ttl_minutes),
      jsonb_build_object(
        'provider_is_hint_only',true,
        'exact_existing_actor_adoption',true,
        'work_actor_is_canonical_source',true,
        'work_actor_ref',v_actor_id
      )
    );
  exception when unique_violation then
    raise exception 'ASSIGNMENT_CONCURRENCY_CONFLICT_RETRY';
  end;

  return jsonb_build_object(
    'schema','WORLD8_MASON_ASSIGNMENT/1.1',
    'assignment_id',v_id,
    'pool_id',p_pool_id,
    'actor_id',v_actor_id,
    'ordinal',v_member.ordinal,
    'work_id',p_work_id,
    'state','WORK_BOUND',
    'provider_hint',p_provider_hint,
    'canonical_head',v_head,
    'expires_at',v_now + make_interval(mins => p_ttl_minutes),
    'exact_existing_actor_adoption',true,
    'idempotent_replay',false
  );
end
$function$;

comment on function public.world8_mason_pool_reserve_exact_work_actor_v1(text,text,text,text,jsonb,integer)
is 'Fail-closed exact-existing-actor Mason Assignment adoption for pre-existing Work. Work.actor_ref is canonical; never steals another live assignment.';
