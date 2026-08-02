extends Control

@onready var avatar_root: Node3D = %AvatarRoot
@onready var hat_list: ItemList = %HatList
@onready var outfit_list: ItemList = %OutfitList
@onready var loadout_list: ItemList = %LoadoutList
@onready var status_label: Label = %StatusLabel


func _ready() -> void:
	%BackButton.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/ui/hub_screen.tscn"))
	%SaveAvatarButton.pressed.connect(_save_avatar)
	%SaveLoadoutButton.pressed.connect(_save_loadout)
	CardService.cards_updated.connect(_on_cards_updated)
	_populate_cosmetics()
	_refresh_avatar()
	CardService.fetch_collection()


func _populate_cosmetics() -> void:
	hat_list.clear()
	outfit_list.clear()
	for key in ItemCatalog.get_all_items().keys():
		var item := ItemCatalog.get_item(key)
		if item.get("type", "") == "cosmetic":
			if "hat" in key:
				hat_list.add_item(item.get("name", key))
			if "outfit" in key:
				outfit_list.add_item(item.get("name", key))


func _refresh_avatar() -> void:
	var config := GameState.profile.get("avatar_config", {})
	if typeof(config) != TYPE_DICTIONARY:
		config = {}
	CharacterCustomizer.apply_avatar_to_node(avatar_root, config)


func _save_avatar() -> void:
	var config := GameState.profile.get("avatar_config", {}).duplicate()
	if typeof(config) != TYPE_DICTIONARY:
		config = {}
	if hat_list.get_selected_items().size() > 0:
		config["hat"] = "cosmetic_hat_red"
	if outfit_list.get_selected_items().size() > 0:
		config["outfit"] = "cosmetic_outfit_blue"
	GameState.profile["avatar_config"] = config
	SupabaseClient.update("profiles", "id=eq.%s" % GameState.profile_id, {"avatar_config": config})
	_refresh_avatar()
	status_label.text = "Avatar saved"


func _on_cards_updated(cards: Array) -> void:
	loadout_list.clear()
	for card in cards:
		loadout_list.add_item(card.get("card_id", ""))


func _save_loadout() -> void:
	var selected := loadout_list.get_selected_items()
	var ids: Array = []
	for idx in selected:
		var card_row := CardService.get_collection()[idx]
		ids.append(card_row.get("card_id", ""))
	if ids.is_empty():
		ids = CardService.get_default_cards()
	CardService.set_loadout(ids)
	status_label.text = "Loadout saved"
