extends Node

## Maps stable item IDs to asset paths and metadata.

const FALLBACK_ARMOR_PATH := "res://assets/placeholder/body.tscn"

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


func get_slot(item_key: String) -> String:
	var item: Dictionary = get_item(item_key)
	if item.is_empty():
		return ""
	var metadata_variant: Variant = item.get("metadata", {})
	var metadata: Dictionary = metadata_variant if metadata_variant is Dictionary else {}
	var slot: String = String(metadata.get("slot", ""))
	if not slot.is_empty():
		return slot
	if "hat" in item_key:
		return "hat"
	if String(item.get("type", "")) == "armor" or "outfit" in item_key:
		return "armor"
	return ""


func get_armor_model_path(armor_key: String, gender: String) -> String:
	var item: Dictionary = get_item(armor_key)
	if item.is_empty():
		return FALLBACK_ARMOR_PATH
	var metadata_variant: Variant = item.get("metadata", {})
	var metadata: Dictionary = metadata_variant if metadata_variant is Dictionary else {}
	var models_variant: Variant = metadata.get("models", {})
	var models: Dictionary = models_variant if models_variant is Dictionary else {}
	var normalized_gender: String = "female" if gender == "female" else "male"
	if models.has(normalized_gender):
		var gender_path: String = String(models[normalized_gender])
		if not gender_path.is_empty() and ResourceLoader.exists(gender_path):
			return gender_path
	var opposite_gender: String = "male" if normalized_gender == "female" else "female"
	if models.has(opposite_gender):
		var opposite_path: String = String(models[opposite_gender])
		if not opposite_path.is_empty() and ResourceLoader.exists(opposite_path):
			return opposite_path
	var asset_path: String = String(item.get("asset_path", ""))
	if not asset_path.is_empty() and ResourceLoader.exists(asset_path):
		return asset_path
	return FALLBACK_ARMOR_PATH


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
	register_item("default_body", {
		"type": "cosmetic",
		"name": "Default Body",
		"asset_path": "res://assets/placeholder/body.tscn",
	})
	register_item("armor_default", {
		"type": "armor",
		"name": "Default Armor",
		"asset_path": "res://assets/placeholder/body.tscn",
		"metadata": {
			"slot": "armor",
			"models": {
				"male": "res://assets/characters/male/armor/default.glb",
				"female": "res://assets/characters/female/armor/default.glb",
			},
		},
	})
	register_item("cosmetic_hat_red", {
		"type": "cosmetic",
		"name": "Red Hat",
		"asset_path": "res://assets/placeholder/hat_red.tscn",
		"metadata": {
			"slot": "hat",
			"model": "res://assets/characters/hats/red.glb",
		},
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
	register_item("env_tree", {
		"type": "env_asset",
		"name": "Oak Tree",
		"asset_path": "res://assets/placeholder/town/tree.tscn",
	})
	register_item("env_bush", {
		"type": "env_asset",
		"name": "Green Bush",
		"asset_path": "res://assets/placeholder/town/bush.tscn",
	})
	register_item("env_fence", {
		"type": "env_asset",
		"name": "Wooden Fence",
		"asset_path": "res://assets/placeholder/town/fence.tscn",
	})
	register_item("env_flower", {
		"type": "env_asset",
		"name": "Flower Patch",
		"asset_path": "res://assets/placeholder/town/flower.tscn",
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
