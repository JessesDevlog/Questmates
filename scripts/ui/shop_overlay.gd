extends Control

@onready var item_list: ItemList = %ItemList
@onready var status_label: Label = %StatusLabel
@onready var title_label: Label = %TitleLabel

var _category: String = ""
var _close_callback: Callable


func setup_overlay(_context: String, close_callback: Callable) -> void:
	_close_callback = close_callback


func set_shop_category(category: String) -> void:
	_category = category
	match category:
		"cosmetic":
			title_label.text = "Clothes Caravan"
		"card":
			title_label.text = "Weapons Caravan"
		"env_asset":
			title_label.text = "Builder Supplies"
		"potion":
			title_label.text = "Spirit Potions"
		_:
			title_label.text = "Merchant"
	_refresh_list()


func _on_shop_updated(_items: Array) -> void:
	_refresh_list()


func _refresh_list() -> void:
	item_list.clear()
	for item_variant in ShopService.get_items_by_category(_category):
		if typeof(item_variant) != TYPE_DICTIONARY:
			continue
		var item: Dictionary = item_variant
		item_list.add_item("%s - %d coins" % [item.get("name", ""), int(item.get("price", 0))])


func _ready() -> void:
	%BackButton.pressed.connect(_on_close)
	%BuyButton.pressed.connect(_buy_selected)
	ShopService.shop_updated.connect(_on_shop_updated)
	ShopService.purchase_completed.connect(_on_purchase_completed)
	ShopService.fetch_shop_items()


func _on_close() -> void:
	if _close_callback.is_valid():
		_close_callback.call()


func _on_purchase_completed(item_variant: Variant) -> void:
	if typeof(item_variant) != TYPE_DICTIONARY:
		return
	var item: Dictionary = item_variant
	status_label.text = "Purchased: %s" % item.get("name", "")


func _buy_selected() -> void:
	var idx := item_list.get_selected_items()
	if idx.is_empty():
		return
	var items: Array = ShopService.get_items_by_category(_category)
	if idx[0] >= items.size():
		return
	var item_variant: Variant = items[idx[0]]
	if typeof(item_variant) != TYPE_DICTIONARY:
		return
	var item: Dictionary = item_variant
	ShopService.purchase_item(String(item.get("id", "")))
