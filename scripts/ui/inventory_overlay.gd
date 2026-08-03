extends Control

@onready var item_list: ItemList = %ItemList
@onready var status_label: Label = %StatusLabel
@onready var partner_spirit_label: Label = %PartnerSpiritLabel
@onready var use_partner_button: Button = %UsePartnerButton
@onready var use_self_button: Button = %UseSelfButton
@onready var equip_button: Button = %EquipButton
@onready var place_button: Button = %PlaceButton

var _close_callback: Callable
var _item_keys: Array = []


func setup_overlay(_context: String, close_callback: Callable) -> void:
	_close_callback = close_callback


func _ready() -> void:
	%BackButton.pressed.connect(_on_close)
	use_partner_button.pressed.connect(_use_on_partner)
	use_self_button.pressed.connect(_use_on_self)
	equip_button.pressed.connect(_equip_selected)
	place_button.pressed.connect(_place_selected)
	item_list.item_selected.connect(_on_item_selected)
	InventoryService.inventory_updated.connect(_on_inventory_updated)
	InventoryService.item_used.connect(_on_item_used)
	InventoryService.fetch_inventory()
	_refresh_partner_spirit()
	_update_action_buttons()


func _on_close() -> void:
	if _close_callback.is_valid():
		_close_callback.call()


func _on_inventory_updated(_items: Array) -> void:
	_refresh_list()
	_refresh_partner_spirit()


func _on_item_used(result: Dictionary) -> void:
	var restored: int = int(result.get("spirit_restored", 0))
	var after: int = int(result.get("spirit_after", 0))
	status_label.text = "Restored %d Spirit (now %d)" % [restored, after]
	_refresh_partner_spirit()


func _refresh_partner_spirit() -> void:
	var partner_name: String = String(GameState.partner_profile.get("display_name", "Partner"))
	var partner_spirit: int = int(GameState.partner_profile.get("spirit", 100))
	partner_spirit_label.text = "%s Spirit: %d" % [partner_name, partner_spirit]


func _refresh_list() -> void:
	item_list.clear()
	_item_keys.clear()
	for row_variant in InventoryService.get_items():
		if typeof(row_variant) != TYPE_DICTIONARY:
			continue
		var row: Dictionary = row_variant
		var key: String = String(row.get("item_key", ""))
		if key.is_empty():
			continue
		var catalog: Dictionary = ItemCatalog.get_item(key)
		var item_type: String = String(catalog.get("type", ""))
		if item_type == "card":
			continue
		_item_keys.append(key)
		var qty: int = int(row.get("quantity", 1))
		var label: String = "%s x%d (%s)" % [
			InventoryService.get_display_name(key),
			qty,
			item_type if not item_type.is_empty() else "item",
		]
		item_list.add_item(label)
	if item_list.item_count == 0:
		status_label.text = "Your bag is empty. Visit a merchant in town to buy items."
	elif status_label.text.begins_with("Your bag is empty"):
		status_label.text = ""
	if item_list.item_count > 0 and item_list.get_selected_items().is_empty():
		item_list.select(0)
	_on_item_selected(0)


func _get_selected_key() -> String:
	var selected := item_list.get_selected_items()
	if selected.is_empty() or selected[0] >= _item_keys.size():
		return ""
	return String(_item_keys[selected[0]])


func _get_selected_type(item_key: String) -> String:
	if item_key.is_empty():
		return ""
	return String(ItemCatalog.get_item(item_key).get("type", ""))


func _on_item_selected(_index: int) -> void:
	_update_action_buttons()


func _update_action_buttons() -> void:
	var key: String = _get_selected_key()
	var item_type: String = _get_selected_type(key)
	var slot: String = ItemCatalog.get_slot(key)
	use_partner_button.visible = item_type == "potion"
	use_self_button.visible = item_type == "potion"
	equip_button.visible = slot == "hat" or slot == "armor"
	place_button.visible = item_type == "env_asset"


func _use_on_partner() -> void:
	var key: String = _get_selected_key()
	if key.is_empty():
		return
	var partner_id: String = String(GameState.partner_profile.get("id", ""))
	if partner_id.is_empty():
		status_label.text = "No partner profile found"
		return
	InventoryService.use_item(key, partner_id)


func _use_on_self() -> void:
	var key: String = _get_selected_key()
	if key.is_empty():
		return
	InventoryService.use_item(key, GameState.profile_id)


func _equip_selected() -> void:
	var key: String = _get_selected_key()
	if key.is_empty():
		return
	var slot: String = ItemCatalog.get_slot(key)
	if slot.is_empty():
		status_label.text = "Cannot equip this item"
		return
	var config_variant: Variant = GameState.profile.get("avatar_config", {}).duplicate()
	var config: Dictionary = config_variant if config_variant is Dictionary else {}
	config[slot] = key
	var profile: Dictionary = GameState.profile.duplicate()
	profile["avatar_config"] = config
	GameState.set_profile_data(profile)
	SupabaseClient.update("profiles", "id=eq.%s" % GameState.profile_id, {"avatar_config": config})
	var town: Node = get_tree().current_scene
	if town and town.has_method("refresh_player_avatar"):
		town.refresh_player_avatar()
	status_label.text = "Equipped %s" % InventoryService.get_display_name(key)


func _place_selected() -> void:
	var key: String = _get_selected_key()
	if key.is_empty():
		return
	var town: Node = get_tree().current_scene
	if town and town.has_method("enter_build_with_item_key"):
		town.enter_build_with_item_key(key)
		if _close_callback.is_valid():
			_close_callback.call()
