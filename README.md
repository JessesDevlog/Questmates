# QuestMates

Co-op chore gamification RPG for iOS, built with Godot 4 and Supabase.

## Quick Start

### 1. Prerequisites

- [Godot 4.3+](https://godotengine.org/download)
- [Xcode](https://developer.apple.com/xcode/) (for iOS export)
- [Supabase](https://supabase.com) free account

### 2. Supabase Setup

1. Create a new Supabase project.
2. In the SQL Editor, run migrations in order:
   - `supabase/migrations/001_initial_schema.sql`
   - `supabase/migrations/002_functions.sql`
   - `supabase/migrations/003_seed_content.sql`
3. Copy your project URL and anon key from Settings → API.

### 3. Configure Secrets

```bash
cp secrets.gd.example secrets.gd
```

Edit `secrets.gd` with your Supabase URL and anon key.

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
supabase/migrations/ SQL schema, RPC functions, seed content
docs/            iOS export and distribution guides
```

## Adding Assets

All visuals are referenced by `item_key` in `ItemCatalog` and `content_items` table.
Replace files at paths in `assets/placeholder/` or add rows to `content_items` — no code changes needed.

## Features Implemented

- Quest loop (create/accept/submit/approve/miss)
- Spirit system with manual penalty-on-open
- Merchant shop (potions, cosmetics, cards, env assets)
- Character customization (data-driven)
- Real-world treats (trust-based redemption)
- Pet Corner (parent-mediated kids)
- Home base building
- Duo-required dungeon with deck-builder combat
- Household-wide hardcore reset
- Content pipeline via `content_items` table

## License

Private family project — not for public distribution.
