-- Inventory accountability: unique stacks, potion purchase, use + place RPCs

-- Consolidate duplicate inventory rows before unique constraint
with merged as (
  select profile_id, item_key, sum(quantity)::int as total_qty, min(acquired_at) as first_at
  from public.inventory_items
  group by profile_id, item_key
  having count(*) > 1
)
update public.inventory_items i
set quantity = m.total_qty
from merged m
where i.profile_id = m.profile_id and i.item_key = m.item_key
  and i.acquired_at = m.first_at;

delete from public.inventory_items i
using (
  select profile_id, item_key, min(id) as keep_id
  from public.inventory_items
  group by profile_id, item_key
  having count(*) > 1
) d
where i.profile_id = d.profile_id and i.item_key = d.item_key and i.id != d.keep_id;

create unique index if not exists inventory_items_profile_item_key_idx
  on public.inventory_items (profile_id, item_key);

-- Purchase shop item (potions go to inventory; stack on duplicate keys)
create or replace function public.purchase_shop_item(shop_item_id uuid, buyer_profile_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  item record;
  content record;
  resolved_key text;
begin
  select * into item from public.shop_items where id = shop_item_id and is_active = true;
  if not found then raise exception 'Item not found'; end if;

  update public.profiles set coins = coins - item.price where id = buyer_profile_id and coins >= item.price;
  if not found then raise exception 'Insufficient coins'; end if;

  if item.type = 'card' then
    select * into content from public.content_items where id = item.content_item_id;
    insert into public.card_collection (profile_id, card_id)
    values (buyer_profile_id, coalesce(content.item_key, item.metadata->>'card_id', 'card_slash'))
    on conflict (profile_id, card_id) do nothing;
    resolved_key := coalesce(content.item_key, item.metadata->>'card_id', 'card_slash');
  else
    select item_key into resolved_key from public.content_items where id = item.content_item_id;
    if resolved_key is null then
      resolved_key := item.name;
    end if;
    insert into public.inventory_items (profile_id, item_key, quantity)
    values (buyer_profile_id, resolved_key, 1)
    on conflict (profile_id, item_key) do update
      set quantity = public.inventory_items.quantity + 1;
  end if;

  return jsonb_build_object('ok', true, 'name', item.name, 'type', item.type, 'item_key', resolved_key);
end;
$$;

-- Use inventory item (potions restore Spirit; no extra coin charge)
create or replace function public.use_inventory_item(
  user_profile_id uuid,
  item_key text,
  target_profile_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  inv record;
  content record;
  restore_amt int;
  user_household uuid;
  target_household uuid;
  old_spirit int;
  new_spirit int;
begin
  select household_id into user_household from public.profiles where id = user_profile_id;
  select household_id into target_household from public.profiles where id = target_profile_id;
  if user_household is null or target_household is null or user_household != target_household then
    raise exception 'Target not in household';
  end if;

  select * into inv from public.inventory_items
  where profile_id = user_profile_id and inventory_items.item_key = use_inventory_item.item_key
  for update;
  if not found or inv.quantity < 1 then
    raise exception 'Item not in inventory';
  end if;

  select * into content from public.content_items where content_items.item_key = use_inventory_item.item_key;
  if not found or content.type != 'potion' then
    raise exception 'Item is not a usable potion';
  end if;

  restore_amt := coalesce((content.metadata->>'spirit_restore')::int, 0);
  if restore_amt <= 0 then
    raise exception 'Potion has no effect';
  end if;

  if inv.quantity <= 1 then
    delete from public.inventory_items where id = inv.id;
  else
    update public.inventory_items set quantity = quantity - 1 where id = inv.id;
  end if;

  select spirit into old_spirit from public.profiles where id = target_profile_id for update;
  update public.profiles
    set spirit = least(100, spirit + restore_amt)
    where id = target_profile_id
    returning spirit into new_spirit;

  return jsonb_build_object(
    'ok', true,
    'item_key', item_key,
    'target_profile_id', target_profile_id,
    'spirit_before', old_spirit,
    'spirit_after', new_spirit,
    'spirit_restored', new_spirit - old_spirit
  );
end;
$$;

-- Place env asset from inventory onto town grid
create or replace function public.place_home_base_item(
  household_id uuid,
  placer_profile_id uuid,
  item_key text,
  position jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  inv record;
  content record;
  placer_household uuid;
  placement_id uuid;
begin
  select profiles.household_id into placer_household
  from public.profiles where id = placer_profile_id;
  if placer_household is null or placer_household != place_home_base_item.household_id then
    raise exception 'Placer not in household';
  end if;

  select * into content from public.content_items where content_items.item_key = place_home_base_item.item_key;
  if not found or content.type != 'env_asset' then
    raise exception 'Item is not a placeable env asset';
  end if;

  select * into inv from public.inventory_items
  where profile_id = placer_profile_id and inventory_items.item_key = place_home_base_item.item_key
  for update;
  if not found or inv.quantity < 1 then
    raise exception 'Item not in inventory';
  end if;

  if inv.quantity <= 1 then
    delete from public.inventory_items where id = inv.id;
  else
    update public.inventory_items set quantity = quantity - 1 where id = inv.id;
  end if;

  insert into public.home_base_items (household_id, content_item_id, position, placed_by_profile_id)
  values (
    place_home_base_item.household_id,
    content.id,
    position || jsonb_build_object('item_key', place_home_base_item.item_key),
    placer_profile_id
  )
  returning id into placement_id;

  return jsonb_build_object('ok', true, 'placement_id', placement_id, 'item_key', item_key);
end;
$$;

-- Dungeon bank loot: stack inventory on conflict
create or replace function public.bank_dungeon_run(run_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  r record;
  loot jsonb;
  card_key text;
  p_id uuid;
begin
  select * into r from public.dungeon_runs where id = run_id for update;
  if not found then raise exception 'Run not found'; end if;

  loot := coalesce(r.state->'banked_loot', '[]'::jsonb);

  for p_id in select unnest(array[r.player_a_profile_id, r.player_b_profile_id])
  loop
    if p_id is null then continue; end if;
    for card_key in select jsonb_array_elements_text(loot)
    loop
      if card_key like 'card_%' then
        insert into public.card_collection (profile_id, card_id) values (p_id, card_key) on conflict do nothing;
      else
        insert into public.inventory_items (profile_id, item_key, quantity) values (p_id, card_key, 1)
        on conflict (profile_id, item_key) do update
          set quantity = public.inventory_items.quantity + 1;
      end if;
    end loop;
    update public.profiles set coins = coins + (r.depth * 2) where id = p_id;
  end loop;

  update public.dungeon_runs set status = 'banked', completed_at = now() where id = run_id;
  return jsonb_build_object('ok', true, 'depth', r.depth);
end;
$$;

grant execute on function public.use_inventory_item(uuid, text, uuid) to authenticated;
grant execute on function public.place_home_base_item(uuid, uuid, text, jsonb) to authenticated;
