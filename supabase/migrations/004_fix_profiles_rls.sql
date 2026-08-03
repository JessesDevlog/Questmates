-- Run in Supabase SQL Editor if you see:
-- "HTTP 403: permission denied for table profiles"

-- 1) Table privileges (required for PostgREST / anon + authenticated roles)
GRANT USAGE ON SCHEMA public TO anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO anon, authenticated;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO anon, authenticated;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO anon, authenticated;

-- 2) Profiles RLS: allow reading your own row (fixes first login / partner lookup)
DROP POLICY IF EXISTS profiles_select ON public.profiles;
DROP POLICY IF EXISTS profiles_select_own ON public.profiles;
DROP POLICY IF EXISTS profiles_select_household ON public.profiles;

CREATE POLICY profiles_select_own ON public.profiles
  FOR SELECT USING (auth_user_id = auth.uid());

CREATE POLICY profiles_select_household ON public.profiles
  FOR SELECT USING (household_id = public.current_household_id());

-- 3) Backfill profiles for users who signed up before the auth trigger existed
DO $$
DECLARE
  hh_id uuid;
BEGIN
  SELECT id INTO hh_id FROM public.households LIMIT 1;
  IF hh_id IS NULL THEN
    INSERT INTO public.households (name) VALUES ('Our Household') RETURNING id INTO hh_id;
  END IF;

  INSERT INTO public.profiles (household_id, auth_user_id, display_name)
  SELECT
    hh_id,
    u.id,
    coalesce(u.raw_user_meta_data->>'display_name', split_part(u.email, '@', 1))
  FROM auth.users u
  WHERE NOT EXISTS (
    SELECT 1 FROM public.profiles p WHERE p.auth_user_id = u.id
  );
END $$;
