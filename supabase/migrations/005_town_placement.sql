-- Town placement uses home_base_items.position JSON:
-- { "tile_x": int, "tile_y": int, "rotation": int, "item_key": string }
-- Legacy world coords { x, y, z } still supported for reads.

comment on column public.home_base_items.position is
  'Tile placement: tile_x, tile_y, rotation, item_key for town rebuild props';
