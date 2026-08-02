extends Control

@onready var child_list: ItemList = %ChildList
@onready var pet_root: Node3D = %PetRoot
@onready var status_label: Label = %StatusLabel


func _ready() -> void:
	%BackButton.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/ui/hub_screen.tscn"))
	%FeedButton.pressed.connect(_feed_pet)
	%DressButton.pressed.connect(_dress_pet)
	_populate_children()


func _populate_children() -> void:
	child_list.clear()
	for child in GameState.child_profiles:
		child_list.add_item("%s (%d coins)" % [child.get("display_name", ""), int(child.get("coins", 0))])


func _get_selected_child() -> Dictionary:
	var idx := child_list.get_selected_items()
	if idx.is_empty():
		return {}
	if idx[0] >= GameState.child_profiles.size():
		return {}
	return GameState.child_profiles[idx[0]]


func _feed_pet() -> void:
	var child := _get_selected_child()
	if child.is_empty():
		status_label.text = "Select a child profile"
		return
	for item in ShopService.get_items():
		if item.get("type", "") == "pet_food":
			ShopService.purchase_for_child(item.get("id", ""), child.get("id", ""))
			status_label.text = "Fed pet for %s" % child.get("display_name", "")
			_refresh_pet(child)
			return
	status_label.text = "No pet food in shop"


func _dress_pet() -> void:
	var child := _get_selected_child()
	if child.is_empty():
		return
	var config := child.get("pet_config", {})
	if typeof(config) != TYPE_DICTIONARY:
		config = {}
	config["outfit"] = "cosmetic_outfit_blue"
	SupabaseClient.update("child_profiles", "id=eq.%s" % child.get("id", ""), {"pet_config": config})
	status_label.text = "Outfit applied for %s" % child.get("display_name", "")
	_refresh_pet(child)


func _refresh_pet(child: Dictionary) -> void:
	for c in pet_root.get_children():
		c.queue_free()
	var pet_config := child.get("pet_config", {})
	if typeof(pet_config) != TYPE_DICTIONARY:
		pet_config = {}
	CharacterCustomizer.apply_avatar_to_node(pet_root, pet_config)
