-- QuestMates RPC functions

-- Approve quest: grant coins/xp to assignee
create or replace function public.approve_quest(quest_id uuid, approver_profile_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  q record;
begin
  select * into q from public.quests where id = quest_id for update;
  if not found then
    raise exception 'Quest not found';
  end if;
  if q.creator_profile_id != approver_profile_id then
    raise exception 'Only creator can approve';
  end if;
  if q.status != 'submitted' then
    raise exception 'Quest not submitted';
  end if;

  update public.quests set status = 'approved', updated_at = now() where id = quest_id;

  if q.assignee_profile_id is not null then
    update public.profiles
      set coins = coins + q.coin_reward,
          xp = xp + q.xp_reward,
          level = greatest(1, 1 + (xp + q.xp_reward) / 100),
          card_loadout_slots = least(6, 3 + greatest(0, (xp + q.xp_reward) / 100))
    where id = q.assignee_profile_id;
  end if;

  return jsonb_build_object('ok', true, 'quest_id', quest_id);
end;
$$;

-- Manual missed-quest penalties (v1)
create or replace function public.apply_missed_quest_penalties(household_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  q record;
  applied int := 0;
  hh record;
begin
  select * into hh from public.households where id = household_id for update;

  for q in
    select * from public.quests
    where household_id = apply_missed_quest_penalties.household_id
      and status in ('open', 'accepted')
      and deadline_at < now()
  loop
    update public.quests set status = 'missed', updated_at = now() where id = q.id;
    update public.profiles
      set spirit = greatest(0, spirit - q.spirit_penalty)
      where id = q.creator_profile_id;
    applied := applied + 1;

    if hh.hardcore_mode then
      perform public.reset_household(household_id);
      return jsonb_build_object('ok', true, 'applied', applied, 'hardcore_reset', true);
    end if;
  end loop;

  return jsonb_build_object('ok', true, 'applied', applied);
end;
$$;

-- Restore spirit (assignee pays)
create or replace function public.restore_spirit(
  target_profile_id uuid,
  buyer_profile_id uuid,
  amount int,
  cost int
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.profiles set coins = coins - cost where id = buyer_profile_id and coins >= cost;
  if not found then
    raise exception 'Insufficient coins';
  end if;
  update public.profiles set spirit = least(100, spirit + amount) where id = target_profile_id;
  return jsonb_build_object('ok', true);
end;
$$;

-- Purchase shop item
create or replace function public.purchase_shop_item(shop_item_id uuid, buyer_profile_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  item record;
  content record;
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
  elsif item.type = 'potion' then
    -- potion effect handled client-side after purchase; inventory optional
    null;
  else
    insert into public.inventory_items (profile_id, item_key, quantity)
    values (buyer_profile_id, coalesce((select item_key from public.content_items where id = item.content_item_id), item.name), 1);
  end if;

  return jsonb_build_object('ok', true, 'name', item.name, 'type', item.type);
end;
$$;

-- Purchase for child profile
create or replace function public.purchase_shop_item_for_child(shop_item_id uuid, child_profile_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  item record;
begin
  select * into item from public.shop_items where id = shop_item_id and is_active = true;
  if not found then raise exception 'Item not found'; end if;

  update public.child_profiles set coins = coins - item.price where id = child_profile_id and coins >= item.price;
  if not found then raise exception 'Insufficient child coins'; end if;

  if item.type = 'pet_food' then
    update public.child_profiles
      set pet_config = jsonb_set(pet_config, '{hunger}', to_jsonb(least(100, coalesce((pet_config->>'hunger')::int, 0) + 20)))
    where id = child_profile_id;
  end if;

  return jsonb_build_object('ok', true, 'name', item.name);
end;
$$;

-- Redeem treat (trust-based)
create or replace function public.redeem_treat(treat_id uuid, buyer_profile_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  t record;
begin
  select * into t from public.treat_requests where id = treat_id for update;
  if not found then raise exception 'Treat not found'; end if;
  if t.status != 'available' or t.price is null then
    raise exception 'Treat not available';
  end if;

  update public.profiles set coins = coins - t.price where id = buyer_profile_id and coins >= t.price;
  if not found then raise exception 'Insufficient coins'; end if;

  update public.treat_requests set status = 'redeemed', redeemed_at = now() where id = treat_id;
  return jsonb_build_object('ok', true, 'title', t.title);
end;
$$;

-- Dungeon lobby join (duo-required)
create or replace function public.join_dungeon_lobby(run_id uuid, profile_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  r record;
begin
  select * into r from public.dungeon_runs where id = run_id for update;
  if not found then raise exception 'Run not found'; end if;
  if r.status != 'lobby' then raise exception 'Run not in lobby'; end if;

  if r.player_b_profile_id is null and r.player_a_profile_id != profile_id then
    update public.dungeon_runs set player_b_profile_id = profile_id where id = run_id;
  end if;

  return jsonb_build_object('ok', true, 'run_id', run_id);
end;
$$;

-- Start dungeon (both players required)
create or replace function public.start_dungeon_run(run_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  r record;
begin
  select * into r from public.dungeon_runs where id = run_id for update;
  if not found then raise exception 'Run not found'; end if;
  if r.player_a_profile_id is null or r.player_b_profile_id is null then
    raise exception 'Both players required';
  end if;

  update public.dungeon_runs
    set status = 'active', depth = 1, started_at = now(),
        state = jsonb_build_object('level_cleared', false, 'banked_loot', '[]'::jsonb)
  where id = run_id;

  return jsonb_build_object('ok', true, 'status', 'active');
end;
$$;

-- Bank loot and exit
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
        insert into public.inventory_items (profile_id, item_key, quantity) values (p_id, card_key, 1);
      end if;
    end loop;
    update public.profiles set coins = coins + (r.depth * 2) where id = p_id;
  end loop;

  update public.dungeon_runs set status = 'banked', completed_at = now() where id = run_id;
  return jsonb_build_object('ok', true, 'depth', r.depth);
end;
$$;

-- Descend to next level
create or replace function public.descend_dungeon(run_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  r record;
begin
  select * into r from public.dungeon_runs where id = run_id for update;
  if not found then raise exception 'Run not found'; end if;
  if coalesce((r.state->>'level_cleared')::boolean, false) = false then
    raise exception 'Level not cleared';
  end if;

  update public.dungeon_runs
    set depth = depth + 1,
        state = jsonb_set(r.state, '{level_cleared}', 'false'::jsonb)
  where id = run_id;

  return jsonb_build_object('ok', true, 'depth', r.depth + 1);
end;
$$;

-- Mark level cleared and bank loot key
create or replace function public.mark_level_cleared(run_id uuid, loot_key text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  r record;
  loot jsonb;
begin
  select * into r from public.dungeon_runs where id = run_id for update;
  if not found then raise exception 'Run not found'; end if;
  loot := coalesce(r.state->'banked_loot', '[]'::jsonb);
  loot := loot || to_jsonb(loot_key);
  update public.dungeon_runs
    set state = jsonb_set(
      jsonb_set(r.state, '{level_cleared}', 'true'::jsonb),
      '{banked_loot}', loot
    )
  where id = run_id;
  return jsonb_build_object('ok', true, 'loot_key', loot_key);
end;
$$;

-- Spawn quest from template
create or replace function public.spawn_quest_from_template(
  template_id uuid,
  assignee_profile_id uuid,
  deadline_hours int default 24
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  t record;
  qid uuid;
begin
  select * into t from public.quest_templates where id = template_id;
  if not found then raise exception 'Template not found'; end if;

  insert into public.quests (
    household_id, creator_profile_id, assignee_profile_id,
    title, description, coin_reward, xp_reward, spirit_penalty,
    deadline_at, status, recurring_template_id
  ) values (
    t.household_id, public.current_profile_id(), assignee_profile_id,
    t.title, t.description, t.coin_reward, t.xp_reward, t.spirit_penalty,
    now() + (deadline_hours || ' hours')::interval, 'open', template_id
  ) returning id into qid;

  return jsonb_build_object('ok', true, 'quest_id', qid);
end;
$$;

-- Household-wide hardcore reset
create or replace function public.reset_household(household_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.profiles
    set spirit = 100, coins = 0, xp = 0, level = 1,
        card_loadout_slots = 3, card_loadout = '[]'::jsonb,
        avatar_config = '{}'::jsonb
  where profiles.household_id = reset_household.household_id;

  update public.child_profiles
    set coins = 0, avatar_config = '{}'::jsonb, pet_config = '{"species":"egg"}'::jsonb
  where child_profiles.household_id = reset_household.household_id;

  delete from public.inventory_items where profile_id in (select id from public.profiles where household_id = reset_household.household_id);
  delete from public.card_collection where profile_id in (select id from public.profiles where household_id = reset_household.household_id);
  delete from public.home_base_items where home_base_items.household_id = reset_household.household_id;

  return jsonb_build_object('ok', true, 'reset', true);
end;
$$;

grant execute on all functions in schema public to authenticated;
