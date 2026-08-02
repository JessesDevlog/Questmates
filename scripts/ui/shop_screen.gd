extends Control

@onready var item_list: ItemList = %ItemList
@onready var status_label: Label = %StatusLabel


func _ready() -> void:
	%BackButton.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/ui/hub_screen.tscn"))
	%BuyButton.pressed.connect(_buy_selected)
	ShopService.shop_updated.connect(_on_shop_updated)
	ShopService.purchase_completed.connect(func(item): status_label.text = "Purchased: %s" % item.get("name", ""))
	ShopService.fetch_shop_items()


func _on_shop_updated(items: Array) -> void:
	item_list.clear()
	for item in items:
		item_list.add_item("%s - %d coins (%s)" % [item.get("name", ""), int(item.get("price", 0)), item.get("type", "")])


func _buy_selected() -> void:
	var idx := item_list.get_selected_items()
	if idx.is_empty():
		return
	var items := ShopService.get_items()
	if idx[0] >= items.size():
		return
	ShopService.purchase_item(items[idx[0]].get("id", ""))
