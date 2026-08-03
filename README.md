# QuestMates

Co-op chore gamification RPG for iOS, built with Godot 4 and Supabase.

## Quick Start

### 1. Prerequisites

- [Godot 4.3+](https://godotengine.org/download)
- [Xcode](https://developer.apple.com/xcode/) (for iOS export)
- [Supabase](https://supabase.com) free account

### 2. Supabase Setup

See **[docs/SUPABASE_SETUP.md](docs/SUPABASE_SETUP.md)** for the full checklist.

1. Create a Supabase project at [supabase.com](https://supabase.com).
2. Run migrations in SQL Editor (if not already done):
   - `supabase/migrations/001_initial_schema.sql`
   - `supabase/migrations/002_functions.sql`
   - `supabase/migrations/003_seed_content.sql`
   - `supabase/migrations/004_fix_profiles_rls.sql` (if login shows 403 on profiles)
   - `supabase/migrations/005_town_placement.sql`
   - `supabase/migrations/006_seed_town_items.sql`
   - `supabase/migrations/007_inventory_accountability.sql`
   - `supabase/migrations/008_treat_loop.sql`
3. Verify with `docs/SUPABASE_VERIFY.sql`.
4. Disable email confirmation (Auth → Email) for easier dev login.
5. Copy Project URL + **publishable** key into `secrets.gd` (legacy anon still works — see docs).

### 3. Configure Secrets

```bash
cp secrets.gd.example secrets.gd
```

Edit `secrets.gd` with your Supabase URL and publishable key (`sb_publishable_...`).

### 4. Run in Godot

Open the project in Godot and press Play (desktop for development).

### 5. iOS Export (USB sideload — free, 7-day builds)

See [docs/IOS_EXPORT.md](docs/IOS_EXPORT.md).

### 6. TestFlight (after MVP validation — $99/yr)

See [docs/TESTFLIGHT.md](docs/TESTFLIGHT.md).

## Project Structure

```
scenes/          UI and dungeon scenes
scripts/         Game logic, services, autoloads
assets/placeholder/  Drop-in-ready placeholder meshes
assets/characters/   Full-body armor GLTFs and hats (see assets/characters/README.md)
supabase/migrations/ SQL schema, RPC functions, seed content
docs/            iOS export and distribution guides
```

## Adding Assets

All visuals are referenced by `item_key` in `ItemCatalog` and `content_items` table.
Replace files at paths in `assets/placeholder/` or add rows to `content_items` — no code changes needed.

**Character armor:** Drop male/female full-body GLTFs under `assets/characters/` and register an `armor_*` item — see [assets/characters/README.md](assets/characters/README.md).

**Town overlays:** All bag/POI menus mount through `OverlayShell` (fit short content, scroll tall content). See `.cursor/rules/overlay-fit-or-scroll.mdc`. Do not use full-rect anchors or nested scroll containers inside overlay scenes.

## Features Implemented

- Quest loop (create/accept/submit/approve/miss)
- Spirit system with manual penalty-on-open
- Inventory: buy potions/cosmetics/env props, use potions to restore partner Spirit
- Merchant shop (potions, cosmetics, cards, env assets)
- Character customization (owned cosmetics, avatar in town)
- Real-world treats (request → partner prices → redeem → fulfillment log)
- Pet Corner (parent-mediated kids)
- Home base building
- Duo-required dungeon with deck-builder combat
- Household-wide hardcore reset
- Content pipeline via `content_items` table

## License

Private family project — not for public distribution.
