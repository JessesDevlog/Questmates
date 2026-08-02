extends Node

## Maps stable item IDs to asset paths and metadata.

var _catalog: Dictionary = {}


func _ready() -> void:
	_load_builtin_catalog()


func get_asset_path(item_key: String) -> String:
	if _catalog.has(item_key):
		return String(_catalog[item_key].get("asset_path", ""))
	return "res://assets/placeholder/box.tscn"


func get_item(item_key: String) -> Dictionary:
	return _catalog.get(item_key, {})


func get_all_items() -> Dictionary:
	return _catalog.duplicate()


func register_item(item_key: String, data: Dictionary) -> void:
	_catalog[item_key] = data


func merge_remote_content(items: Array) -> void:
	for item_variant in items:
		if typeof(item_variant) != TYPE_DICTIONARY:
			continue
		var item: Dictionary = item_variant
		var key: String = String(item.get("item_key", ""))
		if key.is_empty():
			continue
		var metadata_variant: Variant = item.get("metadata", {})
		var metadata: Dictionary = metadata_variant if metadata_variant is Dictionary else {}
		_catalog[key] = {
			"type": String(item.get("type", "")),
			"name": String(item.get("name", key)),
			"description": String(item.get("description", "")),
			"asset_path": String(item.get("asset_path", "res://assets/placeholder/box.tscn")),
			"metadata": metadata,
		}


func _load_builtin_catalog() -> void:
	register_item("cosmetic_hat_red", {
		"type": "cosmetic",
		"name": "Red Hat",
		"asset_path": "res://assets/placeholder/hat_red.tscn",
	})
	register_item("cosmetic_outfit_blue", {
		"type": "cosmetic",
		"name": "Blue Outfit",
		"asset_path": "res://assets/placeholder/outfit_blue.tscn",
	})
	register_item("potion_spirit_small", {
		"type": "potion",
		"name": "Spirit Potion",
		"metadata": {"spirit_restore": 25},
		"asset_path": "res://assets/placeholder/potion.tscn",
	})
	register_item("env_plant", {
		"type": "env_asset",
		"name": "Potted Plant",
		"asset_path": "res://assets/placeholder/plant.tscn",
	})
	register_item("card_slash", {
		"type": "card",
		"name": "Slash",
		"metadata": {"card_type": "short_range", "damage": 3},
		"asset_path": "res://assets/placeholder/card.tscn",
	})
	register_item("card_arrow", {
		"type": "card",
		"name": "Arrow Shot",
		"metadata": {"card_type": "long_range", "damage": 2},
		"asset_path": "res://assets/placeholder/card.tscn",
	})
	register_item("card_heal", {
		"type": "card",
		"name": "Heal",
		"metadata": {"card_type": "healing", "heal": 4},
		"asset_path": "res://assets/placeholder/card.tscn",
	})
	register_item("card_dash", {
		"type": "card",
		"name": "Dash",
		"metadata": {"card_type": "movement", "range": 3},
		"asset_path": "res://assets/placeholder/card.tscn",
	})
	register_item("card_fire", {
		"type": "card",
		"name": "Fire Bolt",
		"metadata": {"card_type": "magic", "damage": 4},
		"asset_path": "res://assets/placeholder/card.tscn",
	})
	register_item("pet_egg", {
		"type": "pet",
		"name": "Mystery Egg",
		"asset_path": "res://assets/placeholder/egg.tscn",
	})
	register_item("pet_food", {
		"type": "pet_food",
		"name": "Pet Treat",
		"metadata": {"hunger_restore": 20},
		"asset_path": "res://assets/placeholder/pet_food.tscn",
	})
