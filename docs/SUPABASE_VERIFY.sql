-- Run in Supabase SQL Editor after migrations to verify setup.
-- Each check should return at least one row (or a success message).

-- Tables exist
select table_name
from information_schema.tables
where table_schema = 'public'
  and table_name in (
    'households', 'profiles', 'child_profiles', 'quests',
    'shop_items', 'content_items', 'dungeon_runs', 'treat_requests'
  )
order by table_name;

-- Seed content loaded
select count(*) as content_item_count from public.content_items;
select count(*) as shop_item_count from public.shop_items;

-- RPC functions exist
select routine_name
from information_schema.routines
where routine_schema = 'public'
  and routine_name in (
    'approve_quest',
    'apply_missed_quest_penalties',
    'purchase_shop_item',
    'use_inventory_item',
    'place_home_base_item',
    'price_treat',
    'redeem_treat',
    'mark_treat_fulfilled',
    'reset_household',
    'start_dungeon_run'
  )
order by routine_name;

-- Auth trigger exists (creates profile on sign-up)
select tgname
from pg_trigger
where tgname = 'on_auth_user_created';

-- Realtime publication includes key tables (optional)
select tablename
from pg_publication_tables
where pubname = 'supabase_realtime'
  and tablename in ('quests', 'dungeon_runs', 'dungeon_events');
