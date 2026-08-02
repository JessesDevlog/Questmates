-- Seed content items and shop listings

insert into public.content_items (item_key, type, name, description, asset_path, metadata) values
  ('cosmetic_hat_red', 'cosmetic', 'Red Hat', 'A bold red hat', 'res://assets/placeholder/hat_red.tscn', '{}'),
  ('cosmetic_outfit_blue', 'cosmetic', 'Blue Outfit', 'Comfy blue outfit', 'res://assets/placeholder/outfit_blue.tscn', '{}'),
  ('potion_spirit_small', 'potion', 'Spirit Potion', 'Restores 25 Spirit', 'res://assets/placeholder/potion.tscn', '{"spirit_restore":25}'),
  ('env_plant', 'env_asset', 'Potted Plant', 'Home base decor', 'res://assets/placeholder/plant.tscn', '{}'),
  ('card_slash', 'card', 'Slash', 'Short range attack', 'res://assets/placeholder/card.tscn', '{"card_type":"short_range","damage":3}'),
  ('card_arrow', 'card', 'Arrow Shot', 'Long range attack', 'res://assets/placeholder/card.tscn', '{"card_type":"long_range","damage":2}'),
  ('card_heal', 'card', 'Heal', 'Restore HP', 'res://assets/placeholder/card.tscn', '{"card_type":"healing","heal":4}'),
  ('card_dash', 'card', 'Dash', 'Move quickly', 'res://assets/placeholder/card.tscn', '{"card_type":"movement","range":3}'),
  ('card_fire', 'card', 'Fire Bolt', 'Magic attack', 'res://assets/placeholder/card.tscn', '{"card_type":"magic","damage":4}'),
  ('pet_food', 'pet_food', 'Pet Treat', 'Feeds your pet', 'res://assets/placeholder/pet_food.tscn', '{"hunger_restore":20}'),
  ('pet_egg', 'pet', 'Mystery Egg', 'Hatch a pet', 'res://assets/placeholder/egg.tscn', '{}')
on conflict (item_key) do nothing;

insert into public.shop_items (household_id, content_item_id, type, name, description, price, metadata)
select null, c.id, c.type, c.name, c.description,
  case c.item_key
    when 'potion_spirit_small' then 15
    when 'cosmetic_hat_red' then 20
    when 'cosmetic_outfit_blue' then 25
    when 'env_plant' then 10
    when 'card_slash' then 30
    when 'card_fire' then 40
    when 'pet_food' then 5
    else 15
  end,
  c.metadata
from public.content_items c
where c.is_active = true
on conflict do nothing;

-- Default quest template (per household created manually or via trigger)
-- Add child profile example after household exists:
-- insert into public.child_profiles (household_id, display_name) values ('YOUR_HOUSEHOLD_ID', 'Kid');
