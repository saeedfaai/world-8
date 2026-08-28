-- World 8 Address Mesh v0.1 — Idempotent Attention Delivery
-- STATUS: DRAFT ONLY / NOT APPLIED / NOT EVIDENCED
-- Depends on UAG schema draft and existing world8_attention_create_v1.
-- Does NOT create a second attention/message truth store.

create or replace function public.world8_address_deliver_attention_v1(
  p_delivery_receipt_id text,
  p_subscription_id text,
  p_recipient_ref text,
  p_source_kind text,
  p_source_ref text,
  p_title text,
  p_summary text,
  p_priority text,
  p_matched_entity_ids jsonb default '[]'::jsonb,
  p_created_by text default 'world8-address-mesh'
) returns jsonb
language plpgsql security definer set search_path=public as $$
declare
  v_existing public.world8_address_delivery_receipts%rowtype;
  v_attention jsonb;
  v_attention_id text;
  v_content_hash text;
begin
  if coalesce(trim(p_delivery_receipt_id),'')='' then raise exception 'DELIVERY_RECEIPT_ID_REQUIRED'; end if;
  if coalesce(trim(p_recipient_ref),'')='' then raise exception 'DELIVERY_RECIPIENT_REQUIRED'; end if;
  if p_priority not in ('LOW','NORMAL','HIGH','CRITICAL') then raise exception 'DELIVERY_PRIORITY_INVALID'; end if;
  if jsonb_typeof(coalesce(p_matched_entity_ids,'[]'::jsonb))<>'array' then
    raise exception 'DELIVERY_MATCHED_ENTITY_IDS_ARRAY_REQUIRED';
  end if;

  -- Serialize retries/concurrent materialization for this deterministic delivery identity.
  perform pg_advisory_xact_lock(hashtextextended(p_delivery_receipt_id,0));

  select * into v_existing
  from public.world8_address_delivery_receipts
  where delivery_receipt_id=p_delivery_receipt_id;
  if found then
    return jsonb_build_object(
      'schema','WORLD8_ADDRESS_ATTENTION_DELIVERY/1.0',
      'status','IDEMPOTENT_REPLAY',
      'delivery_receipt_id',v_existing.delivery_receipt_id,
      'attention_id',v_existing.context_ref,
      'recipient_ref',v_existing.recipient_ref
    );
  end if;

  if not exists(
    select 1 from public.world8_address_subscriptions s
    where s.subscription_id=p_subscription_id
      and s.subscriber_ref=p_recipient_ref
      and s.status='ACTIVE'
      and s.delivery_mode='ATTENTION'
  ) then
    raise exception 'ACTIVE_ATTENTION_SUBSCRIPTION_NOT_FOUND';
  end if;

  v_attention:=public.world8_attention_create_v1(
    p_recipient_ref,
    p_source_kind,
    p_source_ref,
    p_title,
    p_summary,
    p_priority,
    'ACK',
    p_created_by,
    null,
    jsonb_build_array(
      jsonb_build_object('delivery_receipt_id',p_delivery_receipt_id),
      jsonb_build_object('subscription_id',p_subscription_id),
      jsonb_build_object('matched_entity_ids',coalesce(p_matched_entity_ids,'[]'::jsonb))
    )
  );
  v_attention_id:=v_attention->>'attention_id';
  if coalesce(v_attention_id,'')='' then raise exception 'ATTENTION_CREATE_RETURNED_NO_ID'; end if;

  v_content_hash:=encode(extensions.digest(
    concat_ws('|',p_delivery_receipt_id,p_subscription_id,p_recipient_ref,p_source_kind,
      p_source_ref,v_attention_id,p_priority,coalesce(p_matched_entity_ids,'[]'::jsonb)::text),
    'sha256'),'hex');

  insert into public.world8_address_delivery_receipts(
    delivery_receipt_id,source_kind,source_ref,message_id,subscription_id,recipient_ref,
    context_ref,delivery_mode,matched_entity_ids,resolver_version,selector_hash,content_hash
  ) values(
    p_delivery_receipt_id,p_source_kind,p_source_ref,null,p_subscription_id,p_recipient_ref,
    v_attention_id,'ATTENTION',coalesce(p_matched_entity_ids,'[]'::jsonb),
    'world8-address-resolver-v0.1',null,v_content_hash
  );

  return jsonb_build_object(
    'schema','WORLD8_ADDRESS_ATTENTION_DELIVERY/1.0',
    'status','DELIVERED',
    'delivery_receipt_id',p_delivery_receipt_id,
    'attention_id',v_attention_id,
    'recipient_ref',p_recipient_ref
  );
end $$;

-- Security stance for executable migration:
-- * no anon/authenticated direct insert to delivery receipts;
-- * only narrow Address Mesh service RPC may invoke delivery;
-- * this RPC never grants code/effect/promotion/revoke authority;
-- * source_kind/source_ref must cite an existing authoritative event/message/diagnostic in
--   the caller's governed resolver path before this function is invoked.
