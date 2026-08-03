-- QuestMates initial schema
-- Run in Supabase SQL Editor after creating your project.

create extension if not exists "pgcrypto";

-- Households
create table if not exists public.households (
  id uuid primary key default gen_random_uuid(),
  name text not null default 'Our Household',
  hardcore_mode boolean not null default false,
  schema_version int not null default 1,
  content_version int not null default 1,
  created_at timestamptz not null default now()
);

-- Adult profiles (authenticated)
create table if not exists public.profiles (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households(id) on delete cascade,
  auth_user_id uuid not null unique references auth.users(id) on delete cascade,
  display_name text not null,
  role text not null default 'adult' check (role in ('adult')),
  avatar_config jsonb not null default '{}'::jsonb,
  spirit int not null default 100 check (spirit >= 0 and spirit <= 100),
  coins int not null default 0 check (coins >= 0),
  xp int not null default 0 check (xp >= 0),
  level int not null default 1 check (level >= 1),
  card_loadout_slots int not null default 3 check (card_loadout_slots >= 3),
  card_loadout jsonb not null default '[]'::jsonb,
  created_at timestamptz not null default now()
);

-- Child profiles (no auth — parent-mediated)
create table if not exists public.child_profiles (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households(id) on delete cascade,
  display_name text not null,
  coins int not null default 0 check (coins >= 0),
  avatar_config jsonb not null default '{}'::jsonb,
  pet_config jsonb not null default '{"species":"egg"}'::jsonb,
  created_at timestamptz not null default now()
);

-- Remote content catalog (add items without app updates)
create table if not exists public.content_items (
  id uuid primary key default gen_random_uuid(),
  item_key text not null unique,
  type text not null,
  name text not null,
  description text not null default '',
  metadata jsonb not null default '{}'::jsonb,
  asset_path text not null default '',
  is_active boolean not null default true,
  min_client_version int not null default 1,
  created_at timestamptz not null default now()
);

-- Quest templates
create table if not exists public.quest_templates (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households(id) on delete cascade,
  title text not null,
  description text not null default '',
  coin_reward int not null default 5,
  xp_reward int not null default 5,
  spirit_penalty int not null default 10,
  recurrence_rule text not null default 'none',
  created_at timestamptz not null default now()
);

-- Quests
create table if not exists public.quests (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households(id) on delete cascade,
  creator_profile_id uuid not null references public.profiles(id) on delete cascade,
  assignee_profile_id uuid references public.profiles(id) on delete set null,
  title text not null,
  description text not null default '',
  coin_reward int not null default 5,
  xp_reward int not null default 5,
  spirit_penalty int not null default 10,
  deadline_at timestamptz not null,
  status text not null default 'open' check (status in ('open','accepted','submitted','approved','rejected','missed')),
  recurring_template_id uuid references public.quest_templates(id) on delete set null,
  submitted_photo_url text,
  rejection_note text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Shop
create table if not exists public.shop_items (
  id uuid primary key default gen_random_uuid(),
  household_id uuid references public.households(id) on delete cascade,
  content_item_id uuid references public.content_items(id) on delete set null,
  type text not null,
  name text not null,
  description text not null default '',
  price int not null default 0 check (price >= 0),
  metadata jsonb not null default '{}'::jsonb,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

-- Inventory
create table if not exists public.inventory_items (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references public.profiles(id) on delete cascade,
  item_key text not null,
  quantity int not null default 1 check (quantity > 0),
  acquired_at timestamptz not null default now()
);

-- Card collection
create table if not exists public.card_collection (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references public.profiles(id) on delete cascade,
  card_id text not null,
  acquired_at timestamptz not null default now(),
  unique(profile_id, card_id)
);

-- Treat requests
create table if not exists public.treat_requests (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households(id) on delete cascade,
  requested_by_profile_id uuid not null references public.profiles(id) on delete cascade,
  priced_by_profile_id uuid references public.profiles(id) on delete set null,
  title text not null,
  description text not null default '',
  price int,
  status text not null default 'pending_price' check (status in ('pending_price','available','redeemed')),
  redeemed_at timestamptz,
  created_at timestamptz not null default now()
);

-- Home base placements
create table if not exists public.home_base_items (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households(id) on delete cascade,
  content_item_id uuid references public.content_items(id) on delete set null,
  position jsonb not null default '{}'::jsonb,
  placed_by_profile_id uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now()
);

-- Dungeon runs (duo-required)
create table if not exists public.dungeon_runs (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households(id) on delete cascade,
  status text not null default 'lobby' check (status in ('lobby','active','banked','abandoned')),
  depth int not null default 0,
  run_seed int not null default 0,
  state jsonb not null default '{}'::jsonb,
  player_a_profile_id uuid references public.profiles(id) on delete set null,
  player_b_profile_id uuid references public.profiles(id) on delete set null,
  started_at timestamptz,
  completed_at timestamptz,
  created_at timestamptz not null default now()
);

create table if not exists public.dungeon_events (
  id uuid primary key default gen_random_uuid(),
  dungeon_run_id uuid not null references public.dungeon_runs(id) on delete cascade,
  profile_id uuid references public.profiles(id) on delete set null,
  event_type text not null,
  payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

-- Helper: current user's profile
create or replace function public.current_profile_id()
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  select id from public.profiles where auth_user_id = auth.uid();
$$;

create or replace function public.current_household_id()
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  select household_id from public.profiles where auth_user_id = auth.uid();
$$;

-- Auto-create household + profile on signup
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  hh_id uuid;
  display text;
begin
  display := coalesce(new.raw_user_meta_data->>'display_name', split_part(new.email, '@', 1));
  select id into hh_id from public.households limit 1;
  if hh_id is null then
    insert into public.households (name) values ('Our Household') returning id into hh_id;
  end if;
  insert into public.profiles (household_id, auth_user_id, display_name)
  values (hh_id, new.id, display);
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- RLS
alter table public.households enable row level security;
alter table public.profiles enable row level security;
alter table public.child_profiles enable row level security;
alter table public.quest_templates enable row level security;
alter table public.quests enable row level security;
alter table public.shop_items enable row level security;
alter table public.inventory_items enable row level security;
alter table public.card_collection enable row level security;
alter table public.treat_requests enable row level security;
alter table public.home_base_items enable row level security;
alter table public.dungeon_runs enable row level security;
alter table public.dungeon_events enable row level security;
alter table public.content_items enable row level security;

create policy households_select on public.households for select using (id = public.current_household_id());
create policy households_update on public.households for update using (id = public.current_household_id());

create policy profiles_select_own on public.profiles for select using (auth_user_id = auth.uid());
create policy profiles_select_household on public.profiles for select using (household_id = public.current_household_id());
create policy profiles_update on public.profiles for update using (id = public.current_profile_id() or household_id = public.current_household_id());

create policy child_profiles_all on public.child_profiles for all using (household_id = public.current_household_id()) with check (household_id = public.current_household_id());

create policy quest_templates_all on public.quest_templates for all using (household_id = public.current_household_id()) with check (household_id = public.current_household_id());

create policy quests_all on public.quests for all using (household_id = public.current_household_id()) with check (household_id = public.current_household_id());

create policy shop_items_select on public.shop_items for select using (household_id is null or household_id = public.current_household_id());
create policy inventory_all on public.inventory_items for all using (profile_id = public.current_profile_id() or profile_id in (select id from public.profiles where household_id = public.current_household_id())) with check (profile_id = public.current_profile_id() or profile_id in (select id from public.profiles where household_id = public.current_household_id()));

create policy card_collection_all on public.card_collection for all using (profile_id = public.current_profile_id() or profile_id in (select id from public.profiles where household_id = public.current_household_id())) with check (profile_id = public.current_profile_id());

create policy treat_requests_all on public.treat_requests for all using (household_id = public.current_household_id()) with check (household_id = public.current_household_id());

create policy home_base_all on public.home_base_items for all using (household_id = public.current_household_id()) with check (household_id = public.current_household_id());

create policy dungeon_runs_all on public.dungeon_runs for all using (household_id = public.current_household_id()) with check (household_id = public.current_household_id());

create policy dungeon_events_all on public.dungeon_events for all using (
  dungeon_run_id in (select id from public.dungeon_runs where household_id = public.current_household_id())
) with check (
  dungeon_run_id in (select id from public.dungeon_runs where household_id = public.current_household_id())
);

create policy content_items_select on public.content_items for select using (is_active = true);

-- Realtime
alter publication supabase_realtime add table public.dungeon_events;
alter publication supabase_realtime add table public.dungeon_runs;
alter publication supabase_realtime add table public.quests;

-- PostgREST role grants
grant usage on schema public to anon, authenticated;
grant select, insert, update, delete on all tables in schema public to anon, authenticated;
grant usage, select on all sequences in schema public to anon, authenticated;
grant execute on all functions in schema public to anon, authenticated;
