-- Additional town builder env items and shop listings

insert into public.content_items (item_key, type, name, description, asset_path, metadata) values
  ('env_tree', 'env_asset', 'Oak Tree', 'Tall town tree', 'res://assets/placeholder/town/tree.tscn', '{"item_key":"env_tree"}'),
  ('env_bush', 'env_asset', 'Green Bush', 'Shrubbery for plots', 'res://assets/placeholder/town/bush.tscn', '{"item_key":"env_bush"}'),
  ('env_fence', 'env_asset', 'Wooden Fence', 'Border your yard', 'res://assets/placeholder/town/fence.tscn', '{"item_key":"env_fence"}'),
  ('env_flower', 'env_asset', 'Flower Patch', 'Bright flowers', 'res://assets/placeholder/town/flower.tscn', '{"item_key":"env_flower"}')
on conflict (item_key) do update set
  asset_path = excluded.asset_path,
  metadata = excluded.metadata;

update public.content_items
set metadata = '{"item_key":"env_plant"}'::jsonb
where item_key = 'env_plant';

insert into public.shop_items (household_id, content_item_id, type, name, description, price, metadata)
select null, c.id, c.type, c.name, c.description,
  case c.item_key
    when 'env_tree' then 18
    when 'env_bush' then 8
    when 'env_fence' then 12
    when 'env_flower' then 6
    else 10
  end,
  c.metadata
from public.content_items c
where c.item_key in ('env_tree', 'env_bush', 'env_fence', 'env_flower')
  and c.is_active = true
  and not exists (
    select 1 from public.shop_items s
    where s.content_item_id = c.id and s.household_id is null
  );
