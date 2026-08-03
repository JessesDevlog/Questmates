extends Control

@onready var item_list: ItemList = %ItemList
@onready var status_label: Label = %StatusLabel
@onready var mode_label: Label = %ModeLabel

var _close_callback: Callable
var _last_purchased: Dictionary = {}
var _show_owned: bool = false
var _listed_keys: Array = []
var _awaiting_purchase_place: bool = false


func setup_overlay(_context: String, close_callback: Callable) -> void:
	_close_callback = close_callback


func set_shop_category(_category: String) -> void:
	pass


func _ready() -> void:
	%BackButton.pressed.connect(_on_close)
	%BuyButton.pressed.connect(_buy_selected)
	%PlaceButton.pressed.connect(_place_in_town)
	%ToggleModeButton.pressed.connect(_toggle_mode)
	ShopService.shop_updated.connect(_on_shop_updated)
	ShopService.purchase_completed.connect(_on_purchase_completed)
	InventoryService.inventory_updated.connect(_on_inventory_updated)
	ShopService.fetch_shop_items()
	InventoryService.fetch_inventory()
	_refresh_list()


func _on_close() -> void:
	if _close_callback.is_valid():
		_close_callback.call()


func _toggle_mode() -> void:
	_show_owned = not _show_owned
	_refresh_list()


func _on_shop_updated(_items: Array) -> void:
	if not _show_owned:
		_refresh_list()


func _on_inventory_updated(_items: Array) -> void:
	if _awaiting_purchase_place:
		_awaiting_purchase_place = false
		%PlaceButton.visible = true
	if _show_owned:
		_refresh_list()


func _on_purchase_completed(item_variant: Variant) -> void:
	if typeof(item_variant) != TYPE_DICTIONARY:
		return
	_last_purchased = item_variant
	status_label.text = "Purchased: %s — tap Place in Town" % _last_purchased.get("name", "")
	_awaiting_purchase_place = true
	InventoryService.fetch_inventory()
	_show_owned = true
	_refresh_list()


func _refresh_list() -> void:
	item_list.clear()
	_listed_keys.clear()
	if _show_owned:
		mode_label.text = "Owned props (place from inventory)"
		%ToggleModeButton.text = "Show Shop"
		%BuyButton.visible = false
		for row_variant in InventoryService.get_by_type("env_asset"):
			if typeof(row_variant) != TYPE_DICTIONARY:
				continue
			var row: Dictionary = row_variant
			var key: String = String(row.get("item_key", ""))
			if key.is_empty():
				continue
			_listed_keys.append(key)
			item_list.add_item("%s x%d" % [
				InventoryService.get_display_name(key),
				int(row.get("quantity", 1)),
			])
	else:
		mode_label.text = "Shop — buy props to place in town"
		%ToggleModeButton.text = "Show Owned"
		%BuyButton.visible = true
		for item_variant in ShopService.get_items_by_category("env_asset"):
			if typeof(item_variant) != TYPE_DICTIONARY:
				continue
			var item: Dictionary = item_variant
			var key: String = _resolve_shop_item_key(item)
			_listed_keys.append(key)
			item_list.add_item("%s - %d coins" % [item.get("name", ""), int(item.get("price", 0))])


func _resolve_shop_item_key(item: Dictionary) -> String:
	var meta_variant: Variant = item.get("metadata", {})
	var meta: Dictionary = meta_variant if meta_variant is Dictionary else {}
	var meta_key: String = String(meta.get("item_key", ""))
	if not meta_key.is_empty():
		return meta_key
	var item_name: String = String(item.get("name", ""))
	for key in ItemCatalog.get_all_items().keys():
		var catalog: Dictionary = ItemCatalog.get_item(String(key))
		if String(catalog.get("name", "")) == item_name:
			return String(key)
	return item_name


func _get_selected_item() -> Dictionary:
	var idx := item_list.get_selected_items()
	if idx.is_empty() or idx[0] >= _listed_keys.size():
		return {}
	if _show_owned:
		var key: String = String(_listed_keys[idx[0]])
		return {"item_key": key, "name": InventoryService.get_display_name(key)}
	var items: Array = ShopService.get_items_by_category("env_asset")
	if idx[0] >= items.size():
		return {}
	var item_variant: Variant = items[idx[0]]
	return item_variant if item_variant is Dictionary else {}


func _buy_selected() -> void:
	if _show_owned:
		return
	var item: Dictionary = _get_selected_item()
	if item.is_empty():
		return
	ShopService.purchase_item(String(item.get("id", "")))


func _place_in_town() -> void:
	var item: Dictionary = _last_purchased
	if item.is_empty():
		item = _get_selected_item()
	if item.is_empty():
		status_label.text = "Select an owned prop first"
		return
	var town: Node = get_tree().current_scene
	if town and town.has_method("enter_build_with_item"):
		town.enter_build_with_item(item)
		if _close_callback.is_valid():
			_close_callback.call()
