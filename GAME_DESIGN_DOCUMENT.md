# QuestMates — Game Design Document

*A co-op chore-gamification RPG for two (or more) players, built in Godot for iOS.*

**Status:** In Development
**Doc version:** 1.1 — Aug 2, 2026 (locked decisions applied)

---

## 1. Executive Summary

QuestMates turns household chores and responsibilities into a persistent, shared RPG that a couple (and optionally their kids) play together. One partner posts "quests" (chores) with coin/XP rewards and a deadline; the other accepts, completes, and submits them for approval. Missed deadlines drain the *quest-giver's* **Spirit**, creating mutual accountability and directly affecting dungeon combat buffs/nerfs. Earned coins are spent in a merchant shop on cosmetics, pets, potions, environment-building assets, and partner-approved real-world treats. A lightweight, cooperative turn-based dungeon/adventure mode gives the "actual game" payoff — exploring, fighting, and looting as a shared avatar party in a stylized low-poly isometric world.

The hardest problems in this project are **not** the chore-tracking logic (that's a straightforward CRUD app) — they are:

1. **Distributing an iOS build to your wife without App Store hoops or recurring pain.**
2. **Syncing shared, persistent world/character state between two phones for ~free.**
3. **Shipping new content/features over time without wiping save progress or requiring cables/USB installs.**

This document front-loads the architecture decisions that solve those three problems, then covers the full game design, art direction, data model, cost breakdown, risks, and a phased roadmap. All open decisions are consolidated in **Section 13** with a recommended default so you can start building immediately and revisit them later.

**Bottom line recommendation:** Godot 4.x → iOS native export, distributed via **TestFlight** under a **$99/yr Apple Developer account** (this is the only reliable way to get "install and auto-update, no cables" on iOS), with **Supabase** (free tier) as the shared backend for accounts, persistent world state, and near-real-time sync between the two of you. Total recurring cost: **$99/year**, likely **$0** if you use the free sideloading fallback described in Section 3.

---

## 2. Recommended Tech Stack

| Layer | Choice | Why |
|---|---|---|
| Engine | **Godot 4.x (latest stable, e.g. 4.4/4.5)** | Free, open-source, first-class 2.5D/isometric tools, native iOS export, GDScript is fast to iterate in |
| Target platform | **iOS (native export)**, architected so an Android/Web export is nearly free later | You asked for iOS; Godot exports the same project to Android/Web with minimal extra work if you ever want it |
| Distribution | **USB sideload first** (free Personal Team, 7-day builds), then **TestFlight** ($99/yr) once MVP validated | Start $0 during prototyping; switch to TestFlight for frictionless updates |
| Backend | **Supabase** (Postgres + Auth + Realtime + Storage + Edge Functions), free tier | Reachable directly over plain HTTP/WebSocket from GDScript — no fragile third-party plugin required |
| Multiplayer model | **Server-mediated shared state**, not peer-to-peer netcode | The game is turn-based/async (chores, shop, turn-based combat), not a twitch shooter — you don't need UDP/ENet-style real-time netcode |
| Auth | Supabase Auth (email/password or magic link), 2 adult accounts + child sub-profiles | Free, built-in, works from mobile via REST |
| Data format for content (quests templates, items, cosmetics) | Godot `Resource` files (`.tres`) checked into the game bundle **plus** a small "remote content" table in Supabase for anything you want to add without a full app update | Enables adding shop items/cosmetics without recompiling the app |
| Art style | Stylized low-poly, isometric, hand-painted-flat textures | Cheap to produce/buy, performant on iPhone GPUs, ages well visually |
| Push notifications (optional, Phase 2+) | Apple Push Notification service (APNs) via a small Supabase Edge Function | Needs the paid Apple Developer account anyway (see below), so it's "free" marginal cost once you're enrolled |

---

## 3. Platform & Distribution Strategy — "share it with my wife easily"

This is the single biggest constraint on the whole project, so it's addressed first. There are exactly four realistic paths to get a Godot-built iOS app onto your wife's phone. All were verified against Apple's current developer program terms.

### Option A — Apple Developer Program + TestFlight (Recommended)

- **Cost:** $99/year (flat, covers unlimited internal builds/testers for your family).
- **How it works:** You build the app in Xcode (Godot exports an Xcode project), upload it to App Store Connect, add your wife's email as an **internal tester**. She installs the free **TestFlight** app once, accepts the invite, and from then on every new build you upload shows up as an "Update" button in TestFlight — exactly like a normal App Store update. No cables, no re-installing profiles, no Mac needed on her end.
- **Review:** Internal TestFlight builds do **not** go through full App Store review (only external/public TestFlight groups require the first-build review). Builds are typically available in minutes to a couple of hours.
- **Limits:** Builds expire after 90 days if not refreshed (just re-upload periodically — trivial if you're actively developing). Up to 100 internal testers, way more than you need.
- **Why this wins:** It's the only option that gives you real "tap update and go" behavior with zero ongoing friction for your wife, which was an explicit requirement.

### Option B — Free Apple ID "Personal Team" sideload (no paid account)

- **Cost:** $0.
- **How it works:** Build in Xcode using a free Apple ID, plug her iPhone into your Mac (or hers, if it has Xcode — it won't on iOS, so it must be your Mac), and install directly.
- **The dealbreaker:** Apps signed this way **expire after 7 days** and must be re-signed/reinstalled from a Mac with a physical cable each time. That is precisely the "jumping through hoops / plugging in devices" pain you explicitly want to avoid. This option only makes sense as a **zero-cost fallback during early prototyping** before you care about giving builds to your wife.

### Option C — Progressive Web App (PWA) via Godot's Web export

- **Cost:** $0 (hosting on GitHub Pages / Cloudflare Pages / itch.io, all free).
- **How it works:** Export the Godot project to HTML5/WebAssembly, host it, she opens the URL in Safari and taps "Add to Home Screen." Updates are instant (just refreshing the deployed site — no install step at all).
- **Trade-offs:**
  - Godot's Web/WebGL export has historically weaker performance than native, especially for 3D/shader-heavy scenes; iOS Safari's WebGL support is decent but not on par with native Metal.
  - No access to native push notifications, limited background execution, occasional Safari storage eviction for PWAs.
  - No App Store presence at all (not necessarily a con for you).
- **Verdict:** A very reasonable **zero-cost alternative** if $99/yr is a hard no, or as a companion "quick check your quests" lightweight web view alongside the native app. Not recommended as the *only* delivery method for the "actual game" (dungeon crawler) because of performance risk, but excellent for the low-intensity chore/shop screens.

### Option D — Ad-hoc / Enterprise distribution

- Ad-hoc distribution still requires the paid $99/yr Developer Program (it's a feature *of* that program, not a free alternative — see Section 1's Apple comparison). Apple Developer **Enterprise** Program ($299/yr) is for large organizations distributing to employees and is explicitly against Apple's terms for personal apps — not relevant here, more expensive, and against ToS for this use case. Skip it.

### Recommendation & Rationale

Pay the **$99/year** and use **TestFlight**. It's the only path that satisfies "easy to share, no hoops, no paying much" simultaneously — $99/yr is close enough to "little to nothing" for the amount of friction it removes, and it also happens to be a **prerequisite for push notifications** (APNs), which you'll want for "your quest deadline is approaching" or "your partner submitted a quest for approval" alerts later. If you want to start at $0 today, prototype with Option B or C and upgrade to Option A the moment you're ready to hand a build to your wife.

---

## 4. Backend & Multiplayer Architecture — "pay little to nothing, shared world"

### What kind of "multiplayer" does this game actually need?

Be precise about this, because it changes the whole architecture: you do **not** need real-time, low-latency netcode (the kind used for shooters/platformers). Every mechanic you described is either:
- **Asynchronous** (post a quest, accept it hours later, approve it later still), or
- **Turn-based** (card game / dungeon combat), or
- **Shared-state-but-not-frame-critical** (seeing your partner's character standing in the shared world, walking around).

This means a **thin client + shared cloud database with realtime subscriptions** is not just "good enough," it is actually the *better* architecture than traditional peer-to-peer game netcode, because:
- It naturally gives you persistence (nothing to "host," no game server to keep running).
- It works even when only one of you has the app open (the quest board doesn't need both players online simultaneously).
- It avoids Godot's native WebRTC/ENet stack, whose iOS support is genuinely shaky (native WebRTC on iOS requires a third-party GDExtension plugin with no confirmed iOS testers as of this writing, and ENet-over-UDP peer-to-peer requires punching through carrier NAT, which is unreliable on cellular networks).

### Backend Options Considered

| Option | Cost | Pros | Cons |
|---|---|---|---|
| **Supabase** (Postgres) | Free tier: 500MB DB, 5GB egress/mo, 50k MAU, 2M realtime messages/mo, pg_cron included | Plain REST + WebSocket, no SDK plugin dependency, real Postgres (relational — great fit for quests/items/inventory), built-in Auth, scheduled jobs (`pg_cron`) for automated deadline penalties | Free project auto-pauses after 7 days of *zero* traffic (trivially avoided — any request, even from a cron ping, keeps it warm) |
| **Firebase** (Firestore) | Free "Spark" tier: 1GB storage, 50k reads/20k writes per day | Very generous free tier, mature realtime listeners | No official Godot SDK — you'd depend on a community GDExtension plugin (maintenance/version-compat risk) or hand-roll REST calls (more code than Supabase's REST is designed for a NoSQL doc store, awkward for relational chore/quest data) |
| **Self-hosted Nakama / Colyseus on a free VM** (e.g., Oracle Cloud free tier, Fly.io free tier) | $0, but "free" cloud VMs are frequently throttled/reclaimed | Full control, purpose-built game server features (matchmaking, rooms) | Massive overkill for a 2-person async game; you now own server uptime, security patching, and scaling — a chore in itself |
| **PlayFab / GameSparks-style BaaS** | Free tiers exist but skew toward larger live-service games | Lots of built-in game-specific features | Steeper setup, less flexible for a custom relational chore/quest model, another account/vendor to manage |
| **Pure peer-to-peer (Godot WebRTC/ENet)** | $0, no backend at all | No hosting, ever | No persistence without *someone's* device being the source of truth; iOS native WebRTC support is unproven; both devices must be online simultaneously for anything to sync; you'd still need a signaling server for WebRTC, so it's not even truly "no backend" |

### Recommendation

**Supabase**, called directly from GDScript via Godot's built-in `HTTPRequest` node (REST) for reads/writes, and its **Realtime** WebSocket channel for "live" updates (e.g., seeing your partner's avatar move, or getting an instant nudge when a quest is approved). This is:
- **$0/month** at your scale (two adults + a couple of kid profiles is nowhere close to the free tier's 50k MAU or 500MB DB limits).
- Backed by real SQL, which maps naturally onto quests, items, inventory, and player stats (foreign keys, transactions for "spend coins atomically," etc.).
- Not dependent on any unofficial Godot plugin — you're just doing HTTP calls and parsing JSON, which is trivial and won't break when Godot or Supabase update independently.
- Includes `pg_cron` **on the free tier**, which solves the "automatically apply missed-quest penalties" problem (Section 9) without you needing to pay for a server.

**Shared world state model:** Treat Supabase as the single source of truth. Each device is a thin client: on open, pull current state (quests, inventory, character stats, world/dungeon progress); subscribe to a Realtime channel scoped to your "household" (a `household_id` shared by both accounts) for live updates while the app is open; write back changes (accept quest, submit quest, buy item, combat move) as normal API calls. This gives you "shared game world" without ever needing both phones network-connected to each other directly.

---

## 5. Content & Update Strategy — "easy to add features/assets without losing progress"

This is a design discipline more than a technology choice, but it drives several concrete decisions:

1. **Never store player progress only on-device.** All persistent state (coins, XP, inventory, quest history, character appearance, unlocked cosmetics, pet stats, dungeon/story progress) lives in Supabase, keyed by account, with a local cache for offline play that reconciles/syncs on reconnect. This means shipping a brand-new app binary (via TestFlight) **never touches save data** — the new binary just reads the same rows it always did. This directly solves "update the app without losing progress."
2. **Data-drive all content, don't hardcode it.** Quest templates, shop items, cosmetics, pet species, dungeon room layouts, and enemy stats should be defined as data (Godot `Resource`/`.tres` files bundled with the app for anything that needs custom art/behavior, or rows in a Supabase `content` table for simple numeric/text tweaks like "add a new shop item priced at 40 coins"). Adding a new potion or cosmetic that reuses existing art/behavior can be done by inserting a database row — **zero app update required**. Adding genuinely new art/animations still requires a new build, but no data migration.
3. **Additive schema evolution.** When you add new tables/columns, always add them with sensible defaults rather than renaming/restructuring existing ones. Treat your Supabase schema like a public API: additive changes are free, breaking changes require a small migration script (Supabase's SQL migrations, run once from your machine — your wife never sees this).
4. **Versioned client, tolerant server.** Store a `schema_version` and `content_version` the client checks on launch; if the client is older than the minimum supported content version, show a friendly "please update from TestFlight" prompt rather than corrupting state.
5. **Update cadence:** Because TestFlight builds are just an "Update" tap for your wife, you can ship as often as you like (daily, if you want) without any burden on her.

---

## 6. Core Game Design

### 6.1 Game Pillars

1. **Mutual accountability, not nagging.** The health-drain-on-missed-quest mechanic turns "please take out the trash" into a shared stake in the game, reframing chore reminders as gameplay.
2. **Cozy co-op, not competitive.** No PvP; you're always on the same team, whether managing the household economy or exploring the dungeon together.
3. **Small, frequent rewards.** Coins/XP/loot should trickle in constantly (every submitted quest, every dungeon run) to keep the loop satisfying even when "the game" itself is played for 10 minutes at a time.
4. **Real life and game life reinforce each other.** Redeeming an actual wishlist treat using in-game coins is the emotional core feature — make sure the UI treats it as a first-class, celebratory action.

### 6.2 The Quest Loop (Chore Gamification)

**Flow:** `Create → (Open) → Accept/Decline → In Progress → Submit → Approve/Reject → Rewarded`

- **Create:** Either partner can author a quest: title, description, coin reward, XP reward, deadline, and (optionally) a health-penalty severity if missed. Quests can be one-off or recurring templates (e.g., "Dishes" spawns daily).
- **Accept/Decline:** The assignee sees open quests on a shared board and accepts or declines (declining should be low-friction and blame-free — maybe it just returns to the open pool, no penalty for declining before a deadline exists).
- **Submit:** Assignee marks it done, optionally attaching a photo (nice touch for accountability/fun, stored in Supabase Storage — free tier includes 1GB).
- **Approve/Reject:** The creator approves (grants coins + XP) or rejects with a note (sends it back to "in progress").
- **Missed:** If the deadline passes with no submission, it's marked **Missed**, which drains the *creator's* health (see 6.3) — the idea being the creator "needed" that chore done and now suffers for the household task being incomplete, while the assignee bears the cost of fixing it.

### 6.3 Spirit & Penalty System

- Each player has a unified **Spirit** stat (0–100). Spirit drains when a quest **they created** is missed by their partner.
- The **assignee** (who missed it) must spend **their own coins** on potions from the merchant to restore the creator's Spirit — your inaction costs your partner Spirit, and you personally pay to fix it.
- **Spirit affects dungeon combat:** High Spirit applies combat buffs (damage/defense multipliers > 1.0); low Spirit applies nerfs (< 1.0), making the dungeon harder for the affected partner. Spirit modifiers are applied at dungeon entry based on current Spirit tier.
- Spirit cannot go below 0 in normal mode (sits at 0 as a visible "running on empty" state) but triggers a **household-wide hardcore reset** when hardcore mode is enabled (6.9).
- **Manual application (v1):** Penalties are calculated and applied when the app is opened — checking overdue quests and applying Spirit drain at that moment. Automated `pg_cron` upgrade remains optional for later.

### 6.4 Economy: Coins, XP, and the Merchant Shop

- **Coins:** Primary currency, earned from approved quests and dungeon loot, spent in the shop.
- **XP/Levels:** Cosmetic/character progression — leveling up could unlock new customization slots, higher potion effectiveness, or new dungeon regions, giving long-term goals beyond the shop.
- **Merchant Shop categories:**
  - **Potions** — restore Spirit (the accountability sink described above).
  - **Cosmetics** — outfits, hats, hair, skins for characters and pets.
  - **Pets** — companions with their own small progression (fed with coins/treats).
  - **Environment-building assets** — decorative items for a shared "home base" you both build up over time (a nice persistent visual trophy case of your progress).
  - **Stat-boosting items** — minor combat buffs for the adventure mode.
  - **Real-world treats** (see 6.5) — the standout feature.

### 6.5 Real-World Wishlist Treats

- Either partner can **request** a real-world treat (e.g., "order sushi," "buy that book," "let me sleep in Saturday") which appears as a pending item.
- The **other partner sets the coin price** before it becomes purchasable in the shop — this keeps pricing a deliberate, mutual negotiation rather than a one-sided ask.
- Once priced, it shows up in the shop like any other item; redeeming it in-game should trigger a clear real-world notification/receipt (e.g., "🎉 [Name] redeemed: Sushi night!") so it actually gets honored.
- Recommend a lightweight **redemption log** screen so redeemed-but-not-yet-fulfilled treats don't get forgotten.

### 6.6 Cooperative Adventure Mode ("the actual game")

A **turn-based, deck-building, low-poly isometric dungeon crawler** — both partners must be **live and connected** to enter a run.

- **Duo-required:** No solo or AI-companion fallback. Both profiles must join a `dungeon_run` session before it starts. Turn sync via Supabase Realtime + `dungeon_events` table.
- **Roguelite structure:** Semi-random generated levels; players dive deeper and deeper, exit at any level to bank loot. Each level must be fully cleared of enemies before descending. Random loot crates per level (cosmetics + cards).
- **Enemy AI:** Simple tile-based movement; aggro based on tile distance from players.
- **Combat & cards:** Turn-based combat with unlimited basic weapon attacks plus a **loadout of special cards** (short-range, long-range, magic, movement, healing). Pick 3 cards as loadout at start (each usable once per run, refills next run). Character level unlocks more loadout slots (3 → 4 → 5…). Earn new cards from merchant, dungeon loot, and loot crates. Deck-building over time — choose which cards to bring before each run.
- **Spirit integration:** Spirit tier at dungeon entry applies buff/nerf multipliers to combat stats.
- **Progression:** Loot feeds back into shop/inventory; persistent home base shows shared progress.

### 6.7 Character Customization

- Base body/skin, hair, outfit, accessory slots — start with a small set (5–8 options per slot) sourced from an affordable stylized asset pack (see Section 7) rather than custom art, to control cost; expand over time via shop unlocks.
- Store customization as structured data (`{body: id, hair: id, outfit: id, ...}`) rather than baked sprites, so new cosmetic *options* can be added via content updates without new app binaries if you keep the underlying rig/attachment system fixed. Genuinely new *rigs/animations* still need an app update.

### 6.8 Kids' Profiles & Pet Corner

- Kids are **not authenticated users**. Each child is a lightweight `child_profile` row (name, coin balance, cosmetic/pet config) under the household — no separate login.
- **Pet Corner:** A parent-mediated screen. Either parent opens Pet Corner and lets the child see their character/pet, pick outfits, feed the pet, etc. Child spends earned coins on cosmetics. Simple incentive: "finish your cheerios and you get to pick an outfit for your QuestMates character."
- Pets/eggs can be dressed up; items earned from completed chores. Short 2–5 minute sessions; no kid account management required.
- Parental controls: kid chore quest approval remains parent-only (kids submit, parents approve rewards).

### 6.9 Hardcore Mode

- **Household-wide toggle:** If either profile's Spirit reaches 0 with hardcore enabled, **everything resets** for the entire household: both characters' levels, inventories, card collections, cosmetics, and coins. Implemented as a single `reset_household()` transaction.
- Intentionally severe mutual-stakes design — one partner's missed quests drain the other's Spirit, and hardcore mode makes the whole household accountable. Both partners must consent to enable it.

---

## 7. Art & Technical Direction

- **Style:** Stylized low-poly, isometric camera, flat-shaded or simple painted-texture materials. This style is both aesthetically trendy and cheap: low-poly meshes render fast on iPhone GPUs (important — even modern iPhones budget thermal/battery headroom, and you don't want a chores app draining the battery), and forgiving of imperfect solo/AI-assisted art.
- **Rendering:** Use Godot 4's **Forward Mobile** renderer (designed specifically for mobile/iOS performance, as opposed to Forward+ which targets desktop). Keep dynamic lights minimal; bake lighting where possible.
- **Camera/world:** True isometric or a fixed-angle 3D perspective (recommend 3D low-poly meshes over 2D isometric sprites — easier to reuse assets across camera angles, easier to source affordable asset packs like Kenney.nl (free/CC0) or Synty Studios "POLYGON" series (paid but inexpensive, industry-standard for exactly this look), and Godot's 3D tooling is mature).
- **Performance budget:** Target mid-range iPhone (e.g., iPhone 12/13 class) as your performance floor since that's realistically what most households own; keep draw calls and triangle counts modest (low-poly art style naturally enforces this), avoid heavy post-processing.
- **UI:** The chore/shop/quest-board screens are plain 2D UI (Godot `Control` nodes) — build these first since they're the highest-value, lowest-risk part of the app.

---

## 8. Data Model Sketch

High-level Supabase (Postgres) schema — refine during implementation, but this shape supports everything above:

```
households (id, name, created_at)
profiles (id, household_id, display_name, role[adult], auth_user_id, avatar_config JSON, spirit, coins, xp, level, card_loadout_slots, created_at)
child_profiles (id, household_id, display_name, coins, avatar_config JSON, pet_config JSON, created_at)
quests (id, household_id, creator_profile_id, assignee_profile_id, title, description,
        coin_reward, xp_reward, spirit_penalty, deadline_at, status[open|accepted|submitted|approved|rejected|missed],
        recurring_template_id NULLABLE, submitted_photo_url NULLABLE, created_at, updated_at)
quest_templates (id, household_id, title, description, coin_reward, xp_reward, spirit_penalty, recurrence_rule)
inventory_items (id, profile_id, item_id, quantity, acquired_at)
card_collection (id, profile_id, card_id, acquired_at)
shop_items (id, household_id NULLABLE, content_item_id, type[cosmetic|pet|potion|treat|env_asset|card|stat_boost],
            name, description, price, metadata JSON, is_active)
content_items (id, item_key, type, name, description, metadata JSON, asset_path, is_active, min_client_version)
treat_requests (id, household_id, requested_by_profile_id, priced_by_profile_id NULLABLE,
                title, price NULLABLE, status[pending_price|available|redeemed], created_at)
pets (id, profile_id, species_id, name, level, hunger, happiness, cosmetic_config JSON)
dungeon_runs (id, household_id, status, depth, run_seed, state JSON, player_a_profile_id, player_b_profile_id, started_at, completed_at)
dungeon_events (id, dungeon_run_id, profile_id, event_type, payload JSON, created_at)
home_base_items (id, household_id, content_item_id, position JSON, placed_by_profile_id)
```

Row-Level Security (Supabase RLS) should scope every table to `household_id` matching the authenticated user's household — trivial to set up and gives you real data isolation between different households if you ever add more couples later, at no extra cost.

---

## 9. Notifications & Automation

- **Manual penalty application (v1, $0, ships fastest):** On app open, client queries for any `quests` past `deadline_at` still `accepted`/`open`, marks them `missed`, and applies the health penalty client-side via an authenticated write. Matches exactly what you described. Simple, no extra infra.
- **Automatic penalty application (recommended upgrade, still $0):** A Supabase **Edge Function** (small TypeScript function, free tier gives 500k invocations/month) scheduled via the built-in `pg_cron` (enabled by default on free projects) runs e.g. every 15–60 minutes, finds overdue quests, and applies penalties server-side — so health drains even if nobody opens the app that day. This is a same-day addition once the manual version works, and keeps the game "alive" without anyone launching it.
- **Push notifications (Phase 2+, requires the $99/yr Apple account you already have for TestFlight):** APNs push for "quest submitted, needs your approval," "quest deadline in 1 hour," "your health is critically low." Implemented via a Supabase Edge Function calling APNs directly, or a lightweight third-party push relay (OneSignal has a free tier). Recommended once the core loop is proven — nagging via push notification is literally the point of a chore app, so this is high value, just sequenced after MVP.

---

## 10. Development Roadmap

**Phase 0 — Foundation (you are here)**
- Set up Godot 4 project, Supabase project, Apple Developer enrollment.
- Basic auth + household/profile creation, get a "Hello Household" build running via TestFlight on both phones.

**Phase 1 — MVP: The Chore Loop**
- Quest CRUD (create/accept/decline/submit/approve/miss), coins/XP, health drain, manual "apply penalties on open."
- Bare-bones merchant shop (potions + a handful of cosmetics), basic character customization (a few slots).
- This alone is already a usable, fun product for the two of you — ship it before touching the dungeon mode.

**Phase 2 — Shared World Polish**
- Real-world treat request/pricing/redemption flow.
- Kid sub-profiles + pets.
- Automated penalty cron via Edge Function; push notifications.
- Home-base/environment-building visuals using coin-purchased assets.

**Phase 3 — The Adventure Mode**
- Turn-based/card combat prototype, a handful of hand-built rooms, one short story arc.
- Loot integration back into the shared shop/inventory system.
- Hardcore mode toggle.

**Phase 4 — Content Treadmill**
- Recurring quest templates, seasonal cosmetics, more dungeon regions/story beats — all shipped primarily as content-table rows + occasional small builds, exercising the update pipeline from Section 5.

---

## 11. Cost Summary

| Item | Cost | Notes |
|---|---|---|
| Godot Engine | $0 | Open source (MIT) |
| Apple Developer Program | $99/year | Required for TestFlight; can defer if starting with Option B/C from Section 3 |
| Supabase | $0/month | Free tier comfortably covers a 2–4 person household; would need real growth (thousands of users) to hit paid tiers |
| Art assets (optional) | $0–~$150 one-time | Kenney.nl assets are free/CC0; a Synty POLYGON-style pack is a common one-time $20–60 purchase; fully custom art is $0 in cash but costs your own time |
| Push notification relay (optional, Phase 2) | $0 | OneSignal free tier, or direct APNs calls from a Supabase Edge Function (also free) |
| **Total recurring** | **$99/year** (or **$0/year** if using the PWA/sideload fallback) | |

---

## 12. Risks & Difficulties

| Risk | Impact | Mitigation |
|---|---|---|
| Native WebRTC/P2P multiplayer on iOS is unproven/fragile | Would block a P2P approach | Avoided entirely by using Supabase's HTTP/WebSocket backend instead of native netcode (Section 4) |
| Scope creep — chore app + shop + pets + dungeon crawler + kids' mode is a lot for a solo/small team | Slips timelines indefinitely | Strict phased roadmap (Section 10); ship Phase 1 as a complete, satisfying product before starting the adventure mode |
| Supabase free project auto-pauses after 7 days of zero traffic | Wife opens app after a week away, sees a cold-start delay or transient error | Trivial to avoid: any cron ping or app open resumes it; consider a trivial keep-alive ping if this becomes annoying — still $0 |
| App Store/TestFlight builds expire after 90 days | A build could go stale if you stop developing for 3 months | Re-upload periodically; a non-issue during active development |
| Save-data conflicts if both phones edit offline and reconnect | Confusing state (e.g., double-spent coins) | Server-authoritative writes with atomic SQL transactions for anything that spends currency (e.g., "buy item" is one transaction that checks balance and deducts in the same statement) prevents most real problems; full offline-first conflict resolution is complex — recommend requiring connectivity for state-changing actions in v1 and treating true offline play as read-only/Phase-2-later |
| Content/asset production is the real long-pole, not code | Underestimating art time is the most common indie-project failure mode | Lean hard on purchased low-poly asset packs and data-driven reuse (Section 5) rather than bespoke art for every item |
| Apple review rejects the app even for internal TestFlight (rare but possible, e.g., missing privacy policy for account creation) | Delays first ship | Keep privacy/account deletion flows simple and compliant from day one; a one-page privacy policy hosted for free (GitHub Pages) satisfies most requirements |
| Kids' data and parental controls | COPPA-type concerns if this were ever public | Not a concern for a private family app never published publicly on the App Store (internal TestFlight only) — flagged here only because it would matter if you ever expanded beyond your own household |

---

## 13. Locked Decisions (Aug 2, 2026)

| # | Decision |
|---|---|
| 1 | Start with free USB sideload (7-day Personal Team builds); enroll $99/yr TestFlight once MVP validated |
| 2 | Supabase backend |
| 3 | Manual missed-quest penalty application on app open (v1) |
| 4 | Unified **Spirit** stat (0–100); high Spirit = combat buffs, low Spirit = combat nerfs for that partner |
| 5 | Semi-random dungeon levels, deck-builder with 3-card loadout (scales with level), tile-based enemy AI, full-clear to descend, exit anytime to bank loot |
| 6 | Dungeon requires both players live — no AI companion |
| 7 | Hardcore mode: household-wide total reset (both characters, all items, everything) on Spirit death |
| 8 | Real-world treats: trust-based with redemption log |
| 9 | Kids: parent-mediated Pet Corner only — no kid auth; pet/character dress-up with earned coins |
| 10 | Data-driven asset pipeline with placeholders; drop-in real assets at catalog paths later |
| 11 | Connectivity required for writes; read-only offline cache for viewing |

**Open tuning (not blocking):** Exact Spirit→buff/nerf curve; whether exiting dungeon early banks current-level loot crate or only previously cleared levels.
