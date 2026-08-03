-- Phase 2: real-world treat loop — partner pricing, requester redeem, fulfillment log

alter table public.treat_requests
  add column if not exists fulfilled_at timestamptz;

alter table public.treat_requests
  drop constraint if exists treat_requests_status_check;

alter table public.treat_requests
  add constraint treat_requests_status_check
  check (status in ('pending_price', 'available', 'redeemed', 'fulfilled'));

-- Partner (not requester) sets coin price
create or replace function public.price_treat(
  treat_id uuid,
  pricer_profile_id uuid,
  p_price int
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  t record;
  pricer_household uuid;
begin
  if p_price <= 0 then
    raise exception 'Price must be positive';
  end if;

  select * into t from public.treat_requests where id = treat_id for update;
  if not found then
    raise exception 'Treat not found';
  end if;
  if t.status != 'pending_price' then
    raise exception 'Treat is not awaiting a price';
  end if;
  if t.requested_by_profile_id = pricer_profile_id then
    raise exception 'Requester cannot price their own treat';
  end if;

  select household_id into pricer_household
  from public.profiles where id = pricer_profile_id;
  if pricer_household is null or pricer_household != t.household_id then
    raise exception 'Pricer not in household';
  end if;

  update public.treat_requests
    set price = p_price,
        priced_by_profile_id = pricer_profile_id,
        status = 'available'
  where id = treat_id;

  return jsonb_build_object('ok', true, 'treat_id', treat_id, 'price', p_price);
end;
$$;

-- Requester redeems with coins (trust-based)
create or replace function public.redeem_treat(treat_id uuid, buyer_profile_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  t record;
  buyer_name text;
begin
  select * into t from public.treat_requests where id = treat_id for update;
  if not found then
    raise exception 'Treat not found';
  end if;
  if t.status != 'available' or t.price is null then
    raise exception 'Treat not available';
  end if;
  if t.requested_by_profile_id != buyer_profile_id then
    raise exception 'Only the requester can redeem this treat';
  end if;

  update public.profiles
    set coins = coins - t.price
    where id = buyer_profile_id and coins >= t.price;
  if not found then
    raise exception 'Insufficient coins';
  end if;

  update public.treat_requests
    set status = 'redeemed',
        redeemed_at = now()
  where id = treat_id;

  select display_name into buyer_name
  from public.profiles where id = buyer_profile_id;

  return jsonb_build_object(
    'ok', true,
    'title', t.title,
    'buyer_name', coalesce(buyer_name, 'Partner'),
    'buyer_profile_id', buyer_profile_id,
    'price', t.price
  );
end;
$$;

-- Partner marks real-world fulfillment complete
create or replace function public.mark_treat_fulfilled(
  treat_id uuid,
  actor_profile_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  t record;
  actor_household uuid;
begin
  select * into t from public.treat_requests where id = treat_id for update;
  if not found then
    raise exception 'Treat not found';
  end if;
  if t.status != 'redeemed' then
    raise exception 'Treat is not awaiting fulfillment';
  end if;
  if t.requested_by_profile_id = actor_profile_id then
    raise exception 'Requester cannot mark their own treat fulfilled';
  end if;

  select household_id into actor_household
  from public.profiles where id = actor_profile_id;
  if actor_household is null or actor_household != t.household_id then
    raise exception 'Actor not in household';
  end if;

  update public.treat_requests
    set status = 'fulfilled',
        fulfilled_at = now()
  where id = treat_id;

  return jsonb_build_object('ok', true, 'treat_id', treat_id, 'title', t.title);
end;
$$;

grant execute on function public.price_treat(uuid, uuid, int) to authenticated;
grant execute on function public.mark_treat_fulfilled(uuid, uuid) to authenticated;
