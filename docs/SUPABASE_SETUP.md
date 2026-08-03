# Supabase setup for QuestMates

You already ran the SQL migrations — that covers the **database** side. What remains is **connecting the app** to your project and optional **GitHub auto-migrations** for future changes.

## What I (the codebase) cannot do for you

These require your Supabase account in the browser:

- Creating the Supabase project
- Copying the **Project URL** and **anon** key (Settings → API)
- Linking GitHub in the Supabase dashboard (if you want push-to-deploy migrations)

Never commit real keys to git. `secrets.gd` stays local and gitignored.

## What you must do once (about 5 minutes)

### 1. Confirm migrations applied

In Supabase **SQL Editor**, run:

```sql
-- Paste contents of docs/SUPABASE_VERIFY.sql
```

You should see `profiles`, `quests`, `content_items`, etc. and RPCs like `approve_quest`.

### 2. Auth settings (important for login)

**Authentication → Providers → Email**

- Turn **OFF** “Confirm email” while developing (otherwise Sign In fails until you click the email link).

**Authentication → URL configuration** (optional for desktop testing)

- Site URL can stay default; email/password auth works without extra redirect URLs for this app.

### 3. Wire the Godot app

```bash
cp secrets.gd.example secrets.gd
```

Edit `secrets.gd`:

```gdscript
const SUPABASE_URL := "https://YOUR_PROJECT_REF.supabase.co"
const SUPABASE_PUBLISHABLE_KEY := "sb_publishable_..."
```

Get these from **Project Settings → API Keys**:

- **Publishable key** (recommended): tab **“Publishable and secret API keys”** → copy the default publishable key (`sb_publishable_...`). Safe for the Godot app (RLS still applies).
- **Legacy anon key** (still works until ~late 2026): tab **“Legacy anon, service_role API keys”** → copy `anon`. You can paste it into `SUPABASE_PUBLISHABLE_KEY` — same `apikey` header usage.

**Never** put the **secret** key (`sb_secret_...` or `service_role`) in the game — that bypasses RLS.

Restart Godot (F5). The login status line should no longer mention missing configuration.

### 4. Create accounts

1. Run migration `supabase/migrations/009_homestead_onboarding.sql` in the SQL Editor (invite codes, onboarding RPCs).
2. **Sign Up** — email and password only (character + homestead setup happens after first login).
3. On first login: pick **Male/Female**, enter your **display name**, then **Create Homestead** (you get an invite code) or **Join** with your partner's code.
4. Second partner: **Sign Up** → onboarding → **Join** with the invite code (max 2 adults per homestead).
5. After onboarding, the **main menu** offers Play, Character, Homestead, and Log Out.
6. Later use **Sign In** with email + password.

## Optional: Supabase + GitHub

If you connected git to Supabase in the dashboard:

1. Repo should contain `supabase/config.toml` and `supabase/migrations/*.sql`.
2. In Supabase: **Project Settings → Integrations → GitHub** → link this repo and enable migrations.
3. **Future** schema changes: add a new file in `supabase/migrations/` (timestamp prefix recommended for CLI, e.g. `20260802120000_add_feature.sql`), push to git — Supabase applies it.

**Note:** You already ran `001`, `002`, `003` manually. Do not re-run them on the same project unless you reset the DB. New migrations should be additive only.

For the inventory + Spirit accountability loop, also run:

- `supabase/migrations/007_inventory_accountability.sql` — potions go to inventory, `use_inventory_item` and `place_home_base_item` RPCs

For the real-world treat loop (Phase 2), also run:

- `supabase/migrations/008_treat_loop.sql` — partner-only pricing, requester redeem, fulfillment log (`price_treat`, `mark_treat_fulfilled`)

For homestead onboarding (invite codes + main menu flow), also run:

- `supabase/migrations/009_homestead_onboarding.sql` — nullable `household_id` until onboarding, `create_homestead` / `join_homestead` / `rename_homestead` / `leave_homestead` / `update_character` RPCs

### Optional: Supabase CLI (local)

```bash
brew install supabase/tap/supabase
supabase login
supabase link --project-ref YOUR_PROJECT_REF
```

Then `supabase db push` applies any new migrations from this folder.

## Troubleshooting login

| Symptom | Fix |
|--------|-----|
| “Configure secrets.gd” | Fill in real URL/key in `secrets.gd` |
| HTTP 400 on sign in | Wrong password, or email not confirmed |
| “Profile missing” | Run `009_homestead_onboarding.sql` (updated `handle_new_user` trigger) |
| “Already in a homestead” / join fails | Leave homestead from main menu first, or use the correct invite code |
| Empty shop | Re-run `003_seed_content.sql` |
| HTTP 403 permission denied for table profiles | Run `supabase/migrations/004_fix_profiles_rls.sql` in SQL Editor (grants + RLS + profile backfill) |

## Security

- **Publishable key** (or legacy anon) in the mobile app is OK — RLS protects data. QuestMates sends it only in the `apikey` header, not as a Bearer token (required for new `sb_publishable_` keys).
- **Secret / service_role** keys must never ship in the Godot app or `secrets.gd`.
