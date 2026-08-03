extends Control

@onready var item_list: ItemList = %ItemList
@onready var status_label: Label = %StatusLabel


func _ready() -> void:
	%BackButton.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/ui/hub_screen.tscn"))
	%BuyButton.pressed.connect(_buy_selected)
	ShopService.shop_updated.connect(_on_shop_updated)
	ShopService.purchase_completed.connect(_on_purchase_completed)
	ShopService.fetch_shop_items()


func _on_shop_updated(items: Array) -> void:
	item_list.clear()
	for item_variant in items:
		if typeof(item_variant) != TYPE_DICTIONARY:
			continue
		var item: Dictionary = item_variant
		item_list.add_item("%s - %d coins (%s)" % [item.get("name", ""), int(item.get("price", 0)), item.get("type", "")])


func _on_purchase_completed(item_variant: Variant) -> void:
	if typeof(item_variant) != TYPE_DICTIONARY:
		return
	var item: Dictionary = item_variant
	status_label.text = "Purchased: %s" % item.get("name", "")


func _buy_selected() -> void:
	var idx := item_list.get_selected_items()
	if idx.is_empty():
		return
	var items: Array = ShopService.get_items()
	if idx[0] >= items.size():
		return
	var item_variant: Variant = items[idx[0]]
	if typeof(item_variant) != TYPE_DICTIONARY:
		return
	var item: Dictionary = item_variant
	ShopService.purchase_item(String(item.get("id", "")))
