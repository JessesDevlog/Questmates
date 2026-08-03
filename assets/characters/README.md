# Character models

Drop full-body animated GLTF/GLB files here for playable characters.

## Layout

```
assets/characters/
  male/armor/       # male full-body armor sets (.glb / .gltf)
  female/armor/     # female full-body armor sets (same set name per gender)
  hats/             # hat meshes (shared across genders)
```

## Naming

Use the same base filename for both genders of an armor set:

| Armor set | Male | Female |
|-----------|------|--------|
| Default | `male/armor/default.glb` | `female/armor/default.glb` |
| Leather | `male/armor/leather.glb` | `female/armor/leather.glb` |

Hats use a single file, e.g. `hats/red.glb`.

## HatSocket

Each armor GLTF must include a `Node3D` named **`HatSocket`** where hats attach (typically at the head). If missing, hats parent to the armor root and a warning is logged.

## Animations

All character GLTFs should include locomotion clips. Names are matched flexibly (case-insensitive, substring). Mixamo-style names work out of the box:

| State | Typical names |
|-------|----------------|
| Standing still | `Idle`, `idle` |
| Moving on the grid | `Walking`, `walk`, `Running` (fallback) |

Rest/bind poses such as `Armature|mixamo_com|Layer0` are ignored automatically.

`CharacterAnimator` rotates the model to face the movement direction. Mixamo-style rigs default to a `180` degree yaw offset; tweak `model_yaw_offset_degrees` on the player's `CharacterAnimator` if yours faces the wrong way.

## Registering a new armor set

1. Drop `male/armor/<name>.glb` and `female/armor/<name>.glb`.
2. Add a catalog entry in `scripts/autoload/item_catalog.gd` (or a `content_items` row):

```gdscript
register_item("armor_leather", {
  "type": "armor",
  "name": "Leather Armor",
  "asset_path": "res://assets/placeholder/body.tscn",  # fallback until import
  "metadata": {
    "slot": "armor",
    "models": {
      "male": "res://assets/characters/male/armor/leather.glb",
      "female": "res://assets/characters/female/armor/leather.glb",
    },
  },
})
```

3. Equip via `avatar_config`: `{ "gender": "male", "armor": "armor_leather", "hat": "cosmetic_hat_red" }`.

Until GLTF files exist, the catalog falls back to `asset_path` (placeholder scenes).
