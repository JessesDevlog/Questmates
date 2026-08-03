extends Control

@onready var prop_list: ItemList = %PropList
@onready var base_root: Node3D = %BaseRoot
@onready var status_label: Label = %StatusLabel

var _pending: String = ""


func _ready() -> void:
	%BackButton.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/ui/hub_screen.tscn"))
	%BuyPropButton.pressed.connect(_buy_prop)
	%RefreshButton.pressed.connect(_refresh_placed)
	SupabaseClient.request_completed.connect(_on_request_completed)
	ShopService.shop_updated.connect(_on_shop_updated)
	ShopService.fetch_shop_items()
	_refresh_placed()


func _on_shop_updated(items: Array) -> void:
	prop_list.clear()
	for item_variant in items:
		if typeof(item_variant) != TYPE_DICTIONARY:
			continue
		var item: Dictionary = item_variant
		if item.get("type", "") == "env_asset":
			prop_list.add_item("%s - %d coins" % [item.get("name", ""), int(item.get("price", 0))])


func _buy_prop() -> void:
	var idx := prop_list.get_selected_items()
	if idx.is_empty():
		return
	var env_items: Array = _get_env_shop_items()
	if idx[0] >= env_items.size():
		return
	var shop_item: Dictionary = env_items[idx[0]]
	ShopService.purchase_item(String(shop_item.get("id", "")))
	SupabaseClient.insert("home_base_items", {
		"household_id": GameState.household_id,
		"content_item_id": shop_item.get("content_item_id", null),
		"position": {"x": randi_range(0, 4), "y": 0, "z": randi_range(0, 4)},
		"placed_by_profile_id": GameState.profile_id,
	})
	status_label.text = "Placed %s in home base" % String(shop_item.get("name", ""))
	call_deferred("_refresh_placed")


func _get_env_shop_items() -> Array:
	var env_items: Array = []
	for item_variant in ShopService.get_items():
		if typeof(item_variant) != TYPE_DICTIONARY:
			continue
		var item: Dictionary = item_variant
		if item.get("type", "") == "env_asset":
			env_items.append(item)
	return env_items


func _refresh_placed() -> void:
	if GameState.household_id.is_empty():
		return
	_pending = "home_base"
	SupabaseClient.select("home_base_items", "*", "&household_id=eq.%s" % GameState.household_id)


func _on_request_completed(result: Dictionary) -> void:
	if _pending != "home_base":
		return
	_pending = ""
	var data: Variant = result.get("data", [])
	if typeof(data) != TYPE_ARRAY:
		return
	for c in base_root.get_children():
		c.queue_free()
	for row_variant in data:
		if typeof(row_variant) != TYPE_DICTIONARY:
			continue
		var row: Dictionary = row_variant
		var pos_variant: Variant = row.get("position", {})
		var pos: Dictionary = pos_variant if pos_variant is Dictionary else {}
		var mesh_instance := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.4, 0.6, 0.4)
		mesh_instance.mesh = mesh
		mesh_instance.position = Vector3(
			float(pos.get("x", 0)),
			float(pos.get("y", 0)),
			float(pos.get("z", 0))
		)
		base_root.add_child(mesh_instance)
