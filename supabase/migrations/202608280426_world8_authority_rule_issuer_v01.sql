-- World 8 Authority Rule Issuer v0.1
-- Capability-neutral bootstrap repair: request -> Human-root AAL2 approval -> issue.
-- No rule is seeded by this migration. Qualification remains separate from Authority.

create table if not exists public.world8_authority_rule_requests(
  request_id text primary key,
  world_id text not null default 'world-001',
  requested_by text not null,
  rule_key text not null,
  subject_ref text not null,
  action text not null,
  resource_kind text not null,
  resource_ref text not null,
  scope jsonb not null default '{}'::jsonb check(jsonb_typeof(scope)='object'),
  decision text not null check(decision in ('ALLOW','DENY','REVOKE')),
  conditions jsonb not null default '{}'::jsonb check(jsonb_typeof(conditions)='object'),
  evidence_refs jsonb not null default '[]'::jsonb check(jsonb_typeof(evidence_refs)='array'),
  provenance jsonb not null default '{}'::jsonb check(jsonb_typeof(provenance)='object'),
  status text not null check(status in ('REQUESTED','APPROVED','ISSUED','REJECTED','EXPIRED')),
  challenge_id text not null unique,
  request_hash text not null,
  created_at timestamptz not null default clock_timestamp(),
  challenge_expires_at timestamptz not null,
  approved_at timestamptz,
  issue_expires_at timestamptz,
  issued_at timestamptz,
  issued_rule_id text,
  check(challenge_expires_at>created_at)
);

create table if not exists public.world8_authority_rule_challenges(
  challenge_id text primary key,
  request_id text not null unique references public.world8_authority_rule_requests(request_id),
  nonce_hash text not null,
  token_salt text not null,
  status text not null check(status in ('PENDING','APPROVED','REJECTED','EXPIRED')),
  expires_at timestamptz not null,
  approved_auth_subject uuid,
  approved_subject_fingerprint text,
  approved_at timestamptz,
  created_at timestamptz not null default clock_timestamp()
);

create table if not exists public.world8_authority_rule_approvals(
  approval_id text primary key,
  request_id text not null unique references public.world8_authority_rule_requests(request_id),
  challenge_id text not null unique references public.world8_authority_rule_challenges(challenge_id),
  auth_subject uuid not null,
  subject_fingerprint text not null,
  aal text not null check(aal='aal2'),
  approved_at timestamptz not null,
  issue_expires_at timestamptz not null,
  content_hash text not null,
  check(issue_expires_at>approved_at)
);

create or replace function public.world8_authority_rule_hash_v1()
returns trigger language plpgsql security definer set search_path='public','extensions' as $$
declare v_payload jsonb;
begin
  v_payload:=jsonb_build_object(
    'schema','WORLD8_AUTHORITY_RULE/1.0','world_id',new.world_id,'rule_key',new.rule_key,'rule_version',new.rule_version,
    'subject_kind',new.subject_kind,'subject_ref',new.subject_ref,'action',new.action,'resource_kind',new.resource_kind,
    'resource_ref',new.resource_ref,'scope',new.scope,'decision',new.decision,'conditions',new.conditions,'valid_from',new.valid_from,
    'expires_at',new.expires_at,'evidence_refs',new.evidence_refs,'provenance',new.provenance,'created_by',new.created_by
  );
  new.content_hash:=encode(extensions.digest(convert_to(v_payload::text,'UTF8'),'sha256'),'hex');
  return new;
end $$;

drop trigger if exists world8_authority_rules_hash_trg on public.world8_authority_rules;
create trigger world8_authority_rules_hash_trg before insert on public.world8_authority_rules
for each row execute function public.world8_authority_rule_hash_v1();

create or replace function public.world8_authority_rule_request_v1(
 p_request_id text,p_requested_by text,p_rule_key text,p_subject_ref text,p_action text,
 p_resource_kind text,p_resource_ref text,p_scope jsonb default '{}'::jsonb,p_decision text default 'ALLOW',
 p_conditions jsonb default '{}'::jsonb,p_evidence_refs jsonb default '[]'::jsonb,p_provenance jsonb default '{}'::jsonb,
 p_ttl_seconds integer default 300
) returns jsonb language plpgsql security definer set search_path='public','extensions' as $$
declare
  v_now timestamptz:=clock_timestamp(); v_existing public.world8_authority_rule_requests%rowtype;
  v_hash text; v_challenge_id text; v_token_salt text; v_token text; v_token_hash text; v_payload jsonb;
begin
  if p_request_id is null or p_request_id !~ '^[A-Za-z0-9._:-]{1,128}$' then raise exception 'AUTHORITY_REQUEST_ID_INVALID' using errcode='22023'; end if;
  if p_rule_key is null or p_rule_key !~ '^[A-Za-z0-9._:-]{1,160}$' then raise exception 'AUTHORITY_RULE_KEY_INVALID' using errcode='22023'; end if;
  if coalesce(btrim(p_requested_by),'')='' or coalesce(btrim(p_subject_ref),'')='' or coalesce(btrim(p_action),'')='' or coalesce(btrim(p_resource_kind),'')='' or coalesce(btrim(p_resource_ref),'')='' then raise exception 'AUTHORITY_REQUEST_FIELDS_REQUIRED' using errcode='22023'; end if;
  if p_decision not in ('ALLOW','DENY','REVOKE') then raise exception 'AUTHORITY_REQUEST_DECISION_INVALID' using errcode='22023'; end if;
  if jsonb_typeof(coalesce(p_scope,'{}'::jsonb))<>'object' or jsonb_typeof(coalesce(p_conditions,'{}'::jsonb))<>'object' or jsonb_typeof(coalesce(p_evidence_refs,'[]'::jsonb))<>'array' or jsonb_typeof(coalesce(p_provenance,'{}'::jsonb))<>'object' then raise exception 'AUTHORITY_REQUEST_JSON_CONTRACT_INVALID' using errcode='22023'; end if;
  if p_ttl_seconds<60 or p_ttl_seconds>900 then raise exception 'AUTHORITY_CHALLENGE_TTL_INVALID' using errcode='22023'; end if;
  if not exists(select 1 from public.world8_actor_registry a where a.actor_id=p_requested_by and a.status='ACTIVE') then raise exception 'ACTIVE_REQUESTER_ACTOR_REQUIRED' using errcode='55000'; end if;
  if not exists(select 1 from public.world8_actor_registry a where a.actor_id=p_subject_ref and a.status='ACTIVE') then raise exception 'ACTIVE_SUBJECT_ACTOR_REQUIRED' using errcode='55000'; end if;
  v_payload:=jsonb_build_object('schema','WORLD8_AUTHORITY_RULE_REQUEST/1.0','request_id',p_request_id,'world_id','world-001','requested_by',p_requested_by,'rule_key',p_rule_key,'subject_ref',p_subject_ref,'action',p_action,'resource_kind',p_resource_kind,'resource_ref',p_resource_ref,'scope',coalesce(p_scope,'{}'::jsonb),'decision',p_decision,'conditions',coalesce(p_conditions,'{}'::jsonb),'evidence_refs',coalesce(p_evidence_refs,'[]'::jsonb),'provenance',coalesce(p_provenance,'{}'::jsonb));
  v_hash:=encode(extensions.digest(convert_to(v_payload::text,'UTF8'),'sha256'),'hex');
  select * into v_existing from public.world8_authority_rule_requests where request_id=p_request_id;
  if found then
    if v_existing.request_hash<>v_hash then raise exception 'AUTHORITY_REQUEST_IDEMPOTENCY_COLLISION' using errcode='23505'; end if;
    select c.token_salt into v_token_salt from public.world8_authority_rule_challenges c where c.challenge_id=v_existing.challenge_id;
    v_token:=public.world8_challenge_token_from_salt(v_existing.challenge_id,p_request_id,v_token_salt);
    return jsonb_build_object('schema','WORLD8_AUTHORITY_RULE_REQUEST/1.0','request_id',v_existing.request_id,'challenge_id',v_existing.challenge_id,'challenge_token',v_token,'status',v_existing.status,'challenge_expires_at',v_existing.challenge_expires_at,'request_hash',v_existing.request_hash,'idempotent_replay',true);
  end if;
  v_challenge_id:='arch-'||encode(extensions.gen_random_bytes(16),'hex'); v_token_salt:=encode(extensions.gen_random_bytes(32),'hex');
  v_token:=public.world8_challenge_token_from_salt(v_challenge_id,p_request_id,v_token_salt);
  v_token_hash:=encode(extensions.digest(convert_to(v_token,'UTF8'),'sha256'),'hex');
  insert into public.world8_authority_rule_requests(request_id,world_id,requested_by,rule_key,subject_ref,action,resource_kind,resource_ref,scope,decision,conditions,evidence_refs,provenance,status,challenge_id,request_hash,created_at,challenge_expires_at)
  values(p_request_id,'world-001',p_requested_by,p_rule_key,p_subject_ref,p_action,p_resource_kind,p_resource_ref,coalesce(p_scope,'{}'::jsonb),p_decision,coalesce(p_conditions,'{}'::jsonb),coalesce(p_evidence_refs,'[]'::jsonb),coalesce(p_provenance,'{}'::jsonb),'REQUESTED',v_challenge_id,v_hash,v_now,v_now+make_interval(secs=>p_ttl_seconds));
  insert into public.world8_authority_rule_challenges(challenge_id,request_id,nonce_hash,token_salt,status,expires_at) values(v_challenge_id,p_request_id,v_token_hash,v_token_salt,'PENDING',v_now+make_interval(secs=>p_ttl_seconds));
  return jsonb_build_object('schema','WORLD8_AUTHORITY_RULE_REQUEST/1.0','request_id',p_request_id,'challenge_id',v_challenge_id,'challenge_token',v_token,'status','REQUESTED','challenge_expires_at',v_now+make_interval(secs=>p_ttl_seconds),'request_hash',v_hash,'idempotent_replay',false);
end $$;

create or replace function public.world8_authority_rule_pending_v1()
returns jsonb language plpgsql security definer set search_path='public' as $$
declare ctx record; v_items jsonb;
begin
  select * into ctx from public.world8_human_root_session_context(false);
  select coalesce(jsonb_agg(jsonb_build_object('request_id',r.request_id,'challenge_id',r.challenge_id,'requested_by',r.requested_by,'rule_key',r.rule_key,'subject_ref',r.subject_ref,'action',r.action,'resource_kind',r.resource_kind,'resource_ref',r.resource_ref,'scope',r.scope,'decision',r.decision,'conditions',r.conditions,'status',r.status,'created_at',r.created_at,'challenge_expires_at',r.challenge_expires_at) order by r.created_at),'[]'::jsonb) into v_items
  from public.world8_authority_rule_requests r where r.status='REQUESTED' and r.challenge_expires_at>clock_timestamp();
  return jsonb_build_object('schema','WORLD8_AUTHORITY_RULE_PENDING/1.0','viewer','human-root','subject_fingerprint',ctx.subject_fingerprint,'items',v_items,'observed_at',clock_timestamp());
end $$;

create or replace function public.world8_authority_rule_get_v1(p_request_id text)
returns jsonb language plpgsql security definer set search_path='public' as $$
declare ctx record; req public.world8_authority_rule_requests%rowtype; ch public.world8_authority_rule_challenges%rowtype; v_token text; v_effective_status text;
begin
  select * into ctx from public.world8_human_root_session_context(false);
  select * into req from public.world8_authority_rule_requests where request_id=p_request_id;
  if not found then raise exception 'AUTHORITY_RULE_REQUEST_NOT_FOUND' using errcode='55000'; end if;
  select * into ch from public.world8_authority_rule_challenges where challenge_id=req.challenge_id;
  if not found then raise exception 'AUTHORITY_RULE_CHALLENGE_NOT_FOUND' using errcode='55000'; end if;
  v_token:=public.world8_challenge_token_from_salt(ch.challenge_id,req.request_id,ch.token_salt);
  v_effective_status:=case when req.status='REQUESTED' and req.challenge_expires_at<=clock_timestamp() then 'EXPIRED' else req.status end;
  return jsonb_build_object('schema','WORLD8_AUTHORITY_RULE_REQUEST_DETAIL/1.0','request_id',req.request_id,'challenge_id',req.challenge_id,'challenge_token',v_token,'requested_by',req.requested_by,'rule_key',req.rule_key,'subject_ref',req.subject_ref,'action',req.action,'resource_kind',req.resource_kind,'resource_ref',req.resource_ref,'scope',req.scope,'decision',req.decision,'conditions',req.conditions,'status',v_effective_status,'created_at',req.created_at,'challenge_expires_at',req.challenge_expires_at,'request_hash',req.request_hash,'viewer','human-root','viewer_subject_fingerprint',ctx.subject_fingerprint);
end $$;

create or replace function public.world8_authority_rule_approve_v1(p_challenge_id text,p_challenge_token text)
returns jsonb language plpgsql security definer set search_path='public','extensions' as $$
declare ctx record; ch public.world8_authority_rule_challenges%rowtype; req public.world8_authority_rule_requests%rowtype; v_now timestamptz:=clock_timestamp(); v_token_hash text; v_approval_id text; v_issue_expires_at timestamptz; v_payload jsonb; v_hash text;
begin
  select * into ctx from public.world8_human_root_session_context(true);
  select * into ch from public.world8_authority_rule_challenges where challenge_id=p_challenge_id for update; if not found then raise exception 'AUTHORITY_CHALLENGE_NOT_FOUND' using errcode='55000'; end if;
  select * into req from public.world8_authority_rule_requests where request_id=ch.request_id for update;
  if ch.status='APPROVED' and req.status in ('APPROVED','ISSUED') then select approval_id,issue_expires_at into v_approval_id,v_issue_expires_at from public.world8_authority_rule_approvals where request_id=req.request_id; return jsonb_build_object('schema','WORLD8_AUTHORITY_RULE_APPROVAL/1.0','request_id',req.request_id,'challenge_id',ch.challenge_id,'approval_id',v_approval_id,'status',req.status,'issue_expires_at',v_issue_expires_at,'idempotent_replay',true); end if;
  if ch.status<>'PENDING' or req.status<>'REQUESTED' then raise exception 'AUTHORITY_CHALLENGE_NOT_PENDING' using errcode='23514'; end if;
  if ch.expires_at<=v_now or req.challenge_expires_at<=v_now then update public.world8_authority_rule_challenges set status='EXPIRED' where challenge_id=ch.challenge_id; update public.world8_authority_rule_requests set status='EXPIRED' where request_id=req.request_id; raise exception 'AUTHORITY_CHALLENGE_EXPIRED' using errcode='23514'; end if;
  v_token_hash:=encode(extensions.digest(convert_to(coalesce(p_challenge_token,''),'UTF8'),'sha256'),'hex'); if v_token_hash<>ch.nonce_hash then raise exception 'AUTHORITY_CHALLENGE_TOKEN_INVALID' using errcode='42501'; end if;
  v_issue_expires_at:=v_now+interval '5 minutes'; v_approval_id:='ara-'||left(encode(extensions.digest(convert_to(req.request_id||':'||ch.challenge_id||':'||ctx.subject_fingerprint,'UTF8'),'sha256'),'hex'),40);
  v_payload:=jsonb_build_object('schema','WORLD8_AUTHORITY_RULE_APPROVAL/1.0','approval_id',v_approval_id,'request_id',req.request_id,'challenge_id',ch.challenge_id,'subject_fingerprint',ctx.subject_fingerprint,'aal','aal2','approved_at',v_now,'issue_expires_at',v_issue_expires_at); v_hash:=encode(extensions.digest(convert_to(v_payload::text,'UTF8'),'sha256'),'hex');
  insert into public.world8_authority_rule_approvals(approval_id,request_id,challenge_id,auth_subject,subject_fingerprint,aal,approved_at,issue_expires_at,content_hash) values(v_approval_id,req.request_id,ch.challenge_id,ctx.auth_subject,ctx.subject_fingerprint,'aal2',v_now,v_issue_expires_at,v_hash);
  update public.world8_authority_rule_challenges set status='APPROVED',approved_auth_subject=ctx.auth_subject,approved_subject_fingerprint=ctx.subject_fingerprint,approved_at=v_now where challenge_id=ch.challenge_id;
  update public.world8_authority_rule_requests set status='APPROVED',approved_at=v_now,issue_expires_at=v_issue_expires_at where request_id=req.request_id;
  return v_payload||jsonb_build_object('status','APPROVED','content_hash',v_hash,'idempotent_replay',false);
end $$;

create or replace function public.world8_authority_rule_issue_v1(p_request_id text)
returns jsonb language plpgsql security definer set search_path='public','extensions' as $$
declare req public.world8_authority_rule_requests%rowtype; ap public.world8_authority_rule_approvals%rowtype; v_now timestamptz:=clock_timestamp(); v_version integer; v_rule_id text; v_rule public.world8_authority_rules%rowtype;
begin
  select * into req from public.world8_authority_rule_requests where request_id=p_request_id for update; if not found then raise exception 'AUTHORITY_RULE_REQUEST_NOT_FOUND' using errcode='55000'; end if;
  if req.status='ISSUED' then select * into v_rule from public.world8_authority_rules where rule_id=req.issued_rule_id; return jsonb_build_object('schema','WORLD8_AUTHORITY_RULE_ISSUE/1.1','request_id',req.request_id,'rule_id',v_rule.rule_id,'rule_key',v_rule.rule_key,'rule_version',v_rule.rule_version,'decision',v_rule.decision,'expires_at',v_rule.expires_at,'status','ISSUED','idempotent_replay',true); end if;
  if req.status<>'APPROVED' then raise exception 'AUTHORITY_RULE_REQUEST_NOT_APPROVED' using errcode='42501'; end if;
  select * into ap from public.world8_authority_rule_approvals where request_id=req.request_id; if not found then raise exception 'AUTHORITY_RULE_APPROVAL_EVIDENCE_REQUIRED' using errcode='42501'; end if;
  if ap.issue_expires_at<=v_now or req.issue_expires_at is null or req.issue_expires_at<=v_now then raise exception 'AUTHORITY_RULE_APPROVAL_EXPIRED' using errcode='42501'; end if;
  perform pg_advisory_xact_lock(hashtextextended(req.rule_key,0)); select coalesce(max(rule_version),0)+1 into v_version from public.world8_authority_rules where rule_key=req.rule_key;
  v_rule_id:='authority-rule-'||left(encode(extensions.digest(convert_to(req.request_id||':'||ap.approval_id||':'||v_version::text,'UTF8'),'sha256'),'hex'),40);
  insert into public.world8_authority_rules(rule_id,world_id,rule_key,rule_version,subject_kind,subject_ref,action,resource_kind,resource_ref,scope,decision,conditions,valid_from,expires_at,evidence_refs,provenance,created_by)
  values(v_rule_id,req.world_id,req.rule_key,v_version,'ACTOR',req.subject_ref,req.action,req.resource_kind,req.resource_ref,req.scope,req.decision,req.conditions,v_now,req.issue_expires_at,req.evidence_refs||jsonb_build_array('authority-request:'||req.request_id,'authority-challenge:'||req.challenge_id,'authority-approval:'||ap.approval_id),req.provenance||jsonb_build_object('issuer','world8_authority_rule_issue_v1','approved_by','human-root','approved_subject_fingerprint',ap.subject_fingerprint,'approval_id',ap.approval_id,'bootstrap_issuer_version','0.1','expiry_enforced',true),'human-root');
  update public.world8_authority_rule_requests set status='ISSUED',issued_at=v_now,issued_rule_id=v_rule_id where request_id=req.request_id; select * into v_rule from public.world8_authority_rules where rule_id=v_rule_id;
  return jsonb_build_object('schema','WORLD8_AUTHORITY_RULE_ISSUE/1.1','request_id',req.request_id,'approval_id',ap.approval_id,'rule_id',v_rule.rule_id,'rule_key',v_rule.rule_key,'rule_version',v_rule.rule_version,'decision',v_rule.decision,'expires_at',v_rule.expires_at,'status','ISSUED','content_hash',v_rule.content_hash,'idempotent_replay',false);
end $$;

create or replace function public.world8_authority_rule_ceremony_v1(p_challenge_id text,p_challenge_token text)
returns jsonb language plpgsql security definer set search_path='public' as $$
declare v_approval jsonb; v_issue jsonb;
begin
  v_approval:=public.world8_authority_rule_approve_v1(p_challenge_id,p_challenge_token);
  v_issue:=public.world8_authority_rule_issue_v1(v_approval->>'request_id');
  return jsonb_build_object('schema','WORLD8_AUTHORITY_RULE_CEREMONY/1.0','gate_state','PASS','approval',v_approval,'issue',v_issue);
end $$;

create or replace function public.world8_authority_rule_revoke_closed_work_v1(p_rule_id text,p_work_id text,p_workspace_id text,p_reason text default 'WORK_CLOSED')
returns jsonb language plpgsql security definer set search_path='public','extensions' as $$
declare v_rule public.world8_authority_rules%rowtype; v_ws public.world8_dev_workspaces%rowtype; v_now timestamptz:=clock_timestamp(); v_version integer; v_id text; v_existing public.world8_authority_rules%rowtype;
begin
  select * into v_rule from public.world8_authority_rules where rule_id=p_rule_id; if not found then raise exception 'AUTHORITY_RULE_NOT_FOUND'; end if;
  if v_rule.decision<>'ALLOW' then raise exception 'ONLY_ALLOW_RULE_CAN_BE_REVOKED_BY_WORK_CLOSE'; end if;
  if coalesce(v_rule.scope->>'work_id','')<>p_work_id or coalesce(v_rule.scope->>'workspace_id','')<>p_workspace_id then raise exception 'AUTHORITY_RULE_WORKSPACE_SCOPE_MISMATCH'; end if;
  select * into v_ws from public.world8_dev_workspaces where workspace_id=p_workspace_id; if not found then raise exception 'WORKSPACE_NOT_FOUND'; end if;
  if v_ws.work_id<>p_work_id then raise exception 'WORKSPACE_WORK_MISMATCH'; end if;
  if v_ws.state<>'RELEASED' then raise exception 'WORKSPACE_MUST_BE_RELEASED_BEFORE_AUTHORITY_REVOKE'; end if;
  perform pg_advisory_xact_lock(hashtextextended(v_rule.rule_key,0));
  select * into v_existing from public.world8_authority_rules where rule_key=v_rule.rule_key and decision in ('DENY','REVOKE') order by rule_version desc,created_at desc limit 1;
  if found and v_existing.rule_version>v_rule.rule_version then return jsonb_build_object('schema','WORLD8_AUTHORITY_RULE_REVOKE/1.0','gate_state','PASS','idempotent_replay',true,'rule_id',v_existing.rule_id,'rule_version',v_existing.rule_version,'decision',v_existing.decision); end if;
  select coalesce(max(rule_version),0)+1 into v_version from public.world8_authority_rules where rule_key=v_rule.rule_key;
  v_id:='authority-rule-'||left(encode(extensions.digest(convert_to(v_rule.rule_id||':revoke:'||v_version::text,'UTF8'),'sha256'),'hex'),40);
  insert into public.world8_authority_rules(rule_id,world_id,rule_key,rule_version,subject_kind,subject_ref,action,resource_kind,resource_ref,scope,decision,conditions,valid_from,expires_at,evidence_refs,provenance,created_by)
  values(v_id,v_rule.world_id,v_rule.rule_key,v_version,v_rule.subject_kind,v_rule.subject_ref,v_rule.action,v_rule.resource_kind,v_rule.resource_ref,v_rule.scope,'REVOKE',jsonb_build_object('reason',coalesce(nullif(p_reason,''),'WORK_CLOSED')),v_now,null,v_rule.evidence_refs||jsonb_build_array('superseded-rule:'||v_rule.rule_id,'work:'||p_work_id,'workspace:'||p_workspace_id),v_rule.provenance||jsonb_build_object('revoker','world8_authority_rule_revoke_closed_work_v1','revoked_at',v_now,'authority_reduction_only',true),'service-world8-authority-revoker');
  return jsonb_build_object('schema','WORLD8_AUTHORITY_RULE_REVOKE/1.0','gate_state','PASS','idempotent_replay',false,'rule_id',v_id,'rule_version',v_version,'decision','REVOKE');
end $$;

revoke all on table public.world8_authority_rule_requests from public,anon,authenticated;
revoke all on table public.world8_authority_rule_challenges from public,anon,authenticated;
revoke all on table public.world8_authority_rule_approvals from public,anon,authenticated;
revoke all on function public.world8_authority_rule_request_v1(text,text,text,text,text,text,text,jsonb,text,jsonb,jsonb,jsonb,integer) from public,anon,authenticated;
grant execute on function public.world8_authority_rule_request_v1(text,text,text,text,text,text,text,jsonb,text,jsonb,jsonb,jsonb,integer) to service_role;
revoke all on function public.world8_authority_rule_issue_v1(text) from public,anon,authenticated;
grant execute on function public.world8_authority_rule_issue_v1(text) to service_role;
revoke all on function public.world8_authority_rule_revoke_closed_work_v1(text,text,text,text) from public,anon,authenticated;
grant execute on function public.world8_authority_rule_revoke_closed_work_v1(text,text,text,text) to service_role;
revoke all on function public.world8_authority_rule_pending_v1() from public,anon,authenticated;
grant execute on function public.world8_authority_rule_pending_v1() to authenticated;
revoke all on function public.world8_authority_rule_get_v1(text) from public,anon,authenticated;
grant execute on function public.world8_authority_rule_get_v1(text) to authenticated;
revoke all on function public.world8_authority_rule_approve_v1(text,text) from public,anon,authenticated;
grant execute on function public.world8_authority_rule_approve_v1(text,text) to authenticated;
revoke all on function public.world8_authority_rule_ceremony_v1(text,text) from public,anon,authenticated;
grant execute on function public.world8_authority_rule_ceremony_v1(text,text) to authenticated;

comment on function public.world8_authority_rule_ceremony_v1(text,text) is 'Atomic Human-root AAL2 ceremony: approve exact pending request, then issue only within the five-minute issue window.';
comment on function public.world8_authority_rule_revoke_closed_work_v1(text,text,text,text) is 'Authority-reduction-only cleanup: appends REVOKE after the exact scoped workspace has been RELEASED.';
