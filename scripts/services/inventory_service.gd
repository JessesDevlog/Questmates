extends Node

signal inventory_updated(items: Array)
signal item_used(result: Dictionary)
signal item_placed(result: Dictionary)

var _items: Array = []
var _pending_action: String = ""


func _ready() -> void:
	SupabaseClient.request_completed.connect(_on_request_completed)
	GameState.profile_changed.connect(_on_profile_changed)


func fetch_inventory() -> void:
	if GameState.profile_id.is_empty():
		return
	_pending_action = "fetch"
	SupabaseClient.select(
		"inventory_items",
		"*",
		"&profile_id=eq.%s&order=acquired_at.desc" % GameState.profile_id
	)


func use_item(item_key: String, target_profile_id: String) -> void:
	if not GameState.is_online or item_key.is_empty() or target_profile_id.is_empty():
		return
	_pending_action = "use"
	SupabaseClient.call_rpc("use_inventory_item", {
		"user_profile_id": GameState.profile_id,
		"item_key": item_key,
		"target_profile_id": target_profile_id,
	})


func place_env_item(item_key: String, position: Dictionary) -> void:
	if not GameState.is_online or item_key.is_empty() or GameState.household_id.is_empty():
		return
	_pending_action = "place"
	SupabaseClient.call_rpc("place_home_base_item", {
		"household_id": GameState.household_id,
		"placer_profile_id": GameState.profile_id,
		"item_key": item_key,
		"position": position,
	})


func get_items() -> Array:
	return _items.duplicate()


func get_by_type(item_type: String) -> Array:
	var filtered: Array = []
	for row_variant in _items:
		if typeof(row_variant) != TYPE_DICTIONARY:
			continue
		var row: Dictionary = row_variant
		var key: String = String(row.get("item_key", ""))
		var catalog: Dictionary = ItemCatalog.get_item(key)
		if String(catalog.get("type", "")) == item_type:
			filtered.append(row)
	return filtered


func has_item(item_key: String) -> bool:
	return get_quantity(item_key) > 0


func get_quantity(item_key: String) -> int:
	for row_variant in _items:
		if typeof(row_variant) != TYPE_DICTIONARY:
			continue
		var row: Dictionary = row_variant
		if String(row.get("item_key", "")) == item_key:
			return int(row.get("quantity", 0))
	return 0


func get_owned_cosmetic_keys() -> Array:
	var keys: Array = []
	for row_variant in get_by_type("cosmetic"):
		if typeof(row_variant) != TYPE_DICTIONARY:
			continue
		var row: Dictionary = row_variant
		keys.append(String(row.get("item_key", "")))
	return keys


func get_owned_armor_keys() -> Array:
	var keys: Array = []
	for row_variant in get_by_type("armor"):
		if typeof(row_variant) != TYPE_DICTIONARY:
			continue
		var row: Dictionary = row_variant
		keys.append(String(row.get("item_key", "")))
	return keys


func get_display_name(item_key: String) -> String:
	var catalog: Dictionary = ItemCatalog.get_item(item_key)
	var name: String = String(catalog.get("name", ""))
	if name.is_empty():
		return item_key
	return name


func refresh_profiles() -> void:
	if GameState.household_id.is_empty():
		return
	_pending_action = "refresh_profiles"
	SupabaseClient.select("profiles", "*", "&household_id=eq.%s" % GameState.household_id)


func _on_profile_changed() -> void:
	fetch_inventory()


func _on_request_completed(result: Dictionary) -> void:
	var action := _pending_action
	match action:
		"fetch":
			var data: Variant = result.get("data", [])
			if typeof(data) == TYPE_ARRAY:
				_items = data
				inventory_updated.emit(_items.duplicate())
		"use":
			var data: Variant = result.get("data", {})
			if typeof(data) == TYPE_DICTIONARY:
				item_used.emit(data)
			fetch_inventory()
			refresh_profiles()
		"place":
			var data: Variant = result.get("data", {})
			if typeof(data) == TYPE_DICTIONARY:
				item_placed.emit(data)
			fetch_inventory()
		"refresh_profiles":
			_apply_profile_refresh(result.get("data", []))
	if action != "refresh_profiles":
		_pending_action = ""


func _apply_profile_refresh(data: Variant) -> void:
	if typeof(data) != TYPE_ARRAY:
		_pending_action = ""
		return
	for row_variant in data:
		if typeof(row_variant) != TYPE_DICTIONARY:
			continue
		var row: Dictionary = row_variant
		if row.get("id", "") == GameState.profile_id:
			GameState.set_profile_data(row)
			SpiritSystem.check_hardcore_reset(int(row.get("spirit", 100)))
		elif row.get("id", "") == GameState.partner_profile.get("id", ""):
			GameState.set_partner_profile(row)
			SpiritSystem.check_hardcore_reset(int(row.get("spirit", 100)))
	_pending_action = ""
