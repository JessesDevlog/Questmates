-- Homestead onboarding: invite codes, nullable household until onboarding, RPCs

-- 1) Schema changes
alter table public.profiles
  alter column household_id drop not null;

alter table public.households
  add column if not exists invite_code text,
  add column if not exists owner_profile_id uuid references public.profiles(id) on delete set null;

create unique index if not exists households_invite_code_key on public.households (invite_code)
  where invite_code is not null;

-- 2) Invite code generator
create or replace function public.generate_invite_code()
returns text
language plpgsql
as $$
declare
  chars text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  code text := '';
  i int;
  attempts int := 0;
begin
  loop
    code := '';
    for i in 1..6 loop
      code := code || substr(chars, 1 + floor(random() * length(chars))::int, 1);
    end loop;
    exit when not exists (select 1 from public.households h where h.invite_code = code);
    attempts := attempts + 1;
    if attempts > 50 then
      raise exception 'Could not generate unique invite code';
    end if;
  end loop;
  return code;
end;
$$;

-- 3) Backfill existing households
update public.households h
set invite_code = public.generate_invite_code()
where h.invite_code is null;

update public.households h
set owner_profile_id = sub.profile_id
from (
  select distinct on (p.household_id) p.household_id, p.id as profile_id
  from public.profiles p
  where p.household_id is not null
  order by p.household_id, p.created_at asc
) sub
where h.id = sub.household_id
  and h.owner_profile_id is null;

-- 4) Auth trigger: profile only, no auto-household
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  display text;
begin
  display := coalesce(new.raw_user_meta_data->>'display_name', split_part(new.email, '@', 1));
  insert into public.profiles (household_id, auth_user_id, display_name, avatar_config)
  values (null, new.id, display, '{}'::jsonb);
  return new;
end;
$$;

-- 5) Helpers
create or replace function public.normalize_gender(gender text)
returns text
language sql
immutable
as $$
  select case when lower(trim(coalesce(gender, ''))) = 'female' then 'female' else 'male' end;
$$;

create or replace function public.build_avatar_config(gender text)
returns jsonb
language sql
immutable
as $$
  select jsonb_build_object(
    'gender', public.normalize_gender(gender),
    'armor', 'armor_default'
  );
$$;

create or replace function public.require_profile_id()
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  select id from public.profiles where auth_user_id = auth.uid() limit 1;
$$;

-- 6) Create homestead
create or replace function public.create_homestead(
  display_name text,
  gender text,
  homestead_name text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  pid uuid;
  hh_id uuid;
  code text;
  clean_name text;
  clean_homestead text;
  hh_row public.households%rowtype;
  profile_row public.profiles%rowtype;
begin
  pid := public.require_profile_id();
  if pid is null then
    raise exception 'Profile not found';
  end if;

  select * into profile_row from public.profiles where id = pid for update;
  if profile_row.household_id is not null then
    raise exception 'Already in a homestead';
  end if;

  clean_name := trim(coalesce(display_name, ''));
  clean_homestead := trim(coalesce(homestead_name, ''));
  if clean_name = '' then
    raise exception 'Display name required';
  end if;
  if clean_homestead = '' then
    raise exception 'Homestead name required';
  end if;

  code := public.generate_invite_code();
  insert into public.households (name, invite_code, owner_profile_id)
  values (clean_homestead, code, pid)
  returning * into hh_row;

  update public.profiles
  set household_id = hh_row.id,
      display_name = clean_name,
      avatar_config = public.build_avatar_config(gender)
  where id = pid
  returning * into profile_row;

  return jsonb_build_object(
    'household', to_jsonb(hh_row),
    'profile', to_jsonb(profile_row),
    'invite_code', code
  );
end;
$$;

-- 7) Join homestead
create or replace function public.join_homestead(
  display_name text,
  gender text,
  invite_code text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  pid uuid;
  hh_row public.households%rowtype;
  profile_row public.profiles%rowtype;
  member_count int;
  clean_name text;
  clean_code text;
begin
  pid := public.require_profile_id();
  if pid is null then
    raise exception 'Profile not found';
  end if;

  select * into profile_row from public.profiles where id = pid for update;
  if profile_row.household_id is not null then
    raise exception 'Already in a homestead';
  end if;

  clean_name := trim(coalesce(display_name, ''));
  clean_code := upper(trim(coalesce(invite_code, '')));
  if clean_name = '' then
    raise exception 'Display name required';
  end if;
  if clean_code = '' then
    raise exception 'Invite code required';
  end if;

  select * into hh_row from public.households where invite_code = clean_code;
  if not found then
    raise exception 'Invalid invite code';
  end if;

  select count(*) into member_count from public.profiles where household_id = hh_row.id;
  if member_count >= 2 then
    raise exception 'Homestead is full';
  end if;

  update public.profiles
  set household_id = hh_row.id,
      display_name = clean_name,
      avatar_config = public.build_avatar_config(gender)
  where id = pid
  returning * into profile_row;

  return jsonb_build_object(
    'household', to_jsonb(hh_row),
    'profile', to_jsonb(profile_row),
    'invite_code', hh_row.invite_code
  );
end;
$$;

-- 8) Rename homestead (owner only)
create or replace function public.rename_homestead(new_name text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  pid uuid;
  hh_row public.households%rowtype;
  clean_name text;
begin
  pid := public.require_profile_id();
  clean_name := trim(coalesce(new_name, ''));
  if clean_name = '' then
    raise exception 'Homestead name required';
  end if;

  select * into hh_row from public.households
  where id = (select household_id from public.profiles where id = pid)
  for update;

  if not found then
    raise exception 'Not in a homestead';
  end if;
  if hh_row.owner_profile_id is distinct from pid then
    raise exception 'Only the homestead owner can rename';
  end if;

  update public.households set name = clean_name where id = hh_row.id
  returning * into hh_row;

  return to_jsonb(hh_row);
end;
$$;

-- 9) Leave homestead
create or replace function public.leave_homestead()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  pid uuid;
  hh_id uuid;
  was_owner boolean;
  new_owner uuid;
  profile_row public.profiles%rowtype;
begin
  pid := public.require_profile_id();
  select household_id into hh_id from public.profiles where id = pid for update;
  if hh_id is null then
    raise exception 'Not in a homestead';
  end if;

  select (owner_profile_id = pid) into was_owner from public.households where id = hh_id;

  update public.profiles
  set household_id = null
  where id = pid
  returning * into profile_row;

  if was_owner then
    select id into new_owner
    from public.profiles
    where household_id = hh_id and id <> pid
    order by created_at asc
    limit 1;

    update public.households
    set owner_profile_id = new_owner
    where id = hh_id;
  end if;

  return to_jsonb(profile_row);
end;
$$;

-- 10) Update character (name + gender, keep armor key)
create or replace function public.update_character(
  display_name text,
  gender text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  pid uuid;
  profile_row public.profiles%rowtype;
  config jsonb;
  armor_key text;
  hat_key text;
  clean_name text;
begin
  pid := public.require_profile_id();
  clean_name := trim(coalesce(display_name, ''));
  if clean_name = '' then
    raise exception 'Display name required';
  end if;

  select * into profile_row from public.profiles where id = pid for update;
  config := profile_row.avatar_config;
  armor_key := coalesce(nullif(config->>'armor', ''), 'armor_default');
  hat_key := coalesce(config->>'hat', '');

  config := jsonb_build_object(
    'gender', public.normalize_gender(gender),
    'armor', armor_key
  );
  if hat_key <> '' then
    config := config || jsonb_build_object('hat', hat_key);
  end if;

  update public.profiles
  set display_name = clean_name,
      avatar_config = config
  where id = pid
  returning * into profile_row;

  return to_jsonb(profile_row);
end;
$$;

-- 11) RLS: allow profile self-update without household
drop policy if exists profiles_update on public.profiles;
create policy profiles_update on public.profiles
  for update using (
    auth_user_id = auth.uid()
    or id = public.current_profile_id()
    or household_id = public.current_household_id()
  );

grant execute on function public.create_homestead(text, text, text) to authenticated;
grant execute on function public.join_homestead(text, text, text) to authenticated;
grant execute on function public.rename_homestead(text) to authenticated;
grant execute on function public.leave_homestead() to authenticated;
grant execute on function public.update_character(text, text) to authenticated;
