-- World 8 Guardian Diagnostic Context Repair v0.1.2.1
-- Corrective overlay: a direct Supabase Edge Function URL is itself a browser-rendering risk.
-- This keeps the environment classifier fail-safe even when the Mason summary omits words
-- such as "render", "HTML", or "UI delivery".

create or replace function public.world8_guardian_environment_tags_v1(
  p_text text,
  p_environment_ref jsonb default '{}'::jsonb
) returns text[]
language plpgsql stable security definer set search_path=public as $$
declare
  v_text text:=lower(coalesce(p_text,'')||' '||coalesce(p_environment_ref,'{}'::jsonb)::text);
  v_tags text[]:=array['WORLD','MASON'];
  v_tag text;
begin
  if jsonb_typeof(coalesce(p_environment_ref,'{}'::jsonb))<>'object' then
    raise exception 'GUARDIAN_ENVIRONMENT_REF_OBJECT_REQUIRED';
  end if;

  if jsonb_typeof(coalesce(p_environment_ref->'context_tags','[]'::jsonb))='array' then
    for v_tag in select jsonb_array_elements_text(coalesce(p_environment_ref->'context_tags','[]'::jsonb)) loop
      v_tags:=array_append(v_tags,upper(trim(v_tag)));
    end loop;
  end if;
  if jsonb_typeof(coalesce(p_environment_ref->'diagnostic_tags','[]'::jsonb))='array' then
    for v_tag in select jsonb_array_elements_text(coalesce(p_environment_ref->'diagnostic_tags','[]'::jsonb)) loop
      v_tags:=array_append(v_tags,upper(trim(v_tag)));
    end loop;
  end if;

  if v_text ~ '(telegram|bot|webhook)' then v_tags:=array_append(v_tags,'TELEGRAM'); end if;
  if v_text ~ '(api|rpc|webhook|endpoint|provider|connector)' then v_tags:=array_append(v_tags,'API'); end if;
  if v_text ~ '(backup|mirror|continuity|export)' then v_tags:=array_append(v_tags,'BACKUP'); end if;
  if v_text ~ '(genesis|recovery|recover|restore|reconstruct|checkpoint|crash)' then v_tags:=array_append(v_tags,'RECOVERY'); end if;
  if v_text ~ '(database|sql|schema|postgres|table|column|migration)' then v_tags:=array_append(v_tags,'DATABASE'); end if;
  if v_text ~ '(schema|column|field|function signature|migration)' then v_tags:=array_append(v_tags,'SCHEMA'); end if;
  if v_text ~ '(auth|permission|privilege|identity|authority|authorization|admission)' then v_tags:=array_append(v_tags,'AUTH'); end if;
  if v_text ~ '(secret|credential|security|token|password)' then v_tags:=array_append(v_tags,'SECURITY'); end if;
  if v_text ~ '(secretary|proforma|invoice|pdf)' then v_tags:=array_append(v_tags,'SECRETARY'); end if;
  if v_text ~ '(trading|forecast|market|order|portfolio)' then v_tags:=array_append(v_tags,'TRADING'); end if;
  if v_text ~ '(company|sales|quote|customer|supplier)' then v_tags:=array_append(v_tags,'COMPANY'); end if;
  if v_text ~ '(mason|preflight|postflight|coding|code |workspace|work claim)' then v_tags:=array_append(v_tags,'MASON'); end if;
  if v_text ~ '(dcp|development control|workspace|work claim|handoff|postflight)' then v_tags:=array_append(v_tags,'DCP'); end if;
  if v_text ~ '(supabase|edge function|supabase\.co/functions)' then v_tags:=array_append(v_tags,'SUPABASE'); end if;
  if v_text ~ '(github|git |branch|commit|pull request|workflow|ci)' then v_tags:=array_append(v_tags,'GITHUB'); end if;
  if v_text ~ '(connectivity|vpn|proxy|route|lifeline)' then v_tags:=array_append(v_tags,'CONNECTIVITY'); end if;
  if v_text ~ '(access mesh|control surface|shadow panel|approval ui|browser ui|world8-authority-approval)' then v_tags:=array_append(v_tags,'ACCESS_MESH'); end if;
  if v_text ~ '(render|raw html|html source|source code visible|dom|content[- ]type|ui delivery|direct edge url|browser rendering|supabase\.co/functions)' then v_tags:=array_append(v_tags,'RENDER'); end if;

  select coalesce(array_agg(distinct x order by x),array[]::text[]) into v_tags
  from unnest(v_tags) x
  where coalesce(trim(x),'')<>''
    and exists(select 1 from public.world8_diag_tags t where t.tag_key=x and t.status='ACTIVE');

  return v_tags;
end $$;
