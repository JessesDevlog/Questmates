extends Control

@onready var avatar_root: Node3D = %AvatarRoot
@onready var gender_option: OptionButton = %GenderOption
@onready var hat_list: ItemList = %HatList
@onready var outfit_list: ItemList = %OutfitList
@onready var loadout_list: ItemList = %LoadoutList
@onready var status_label: Label = %StatusLabel

const DEFAULT_ARMOR_KEY := "armor_default"

var _hat_keys: Array = []
var _armor_keys: Array = []
var _close_callback: Callable
var _avatar_animator: CharacterAnimator


func setup_overlay(_context: String, close_callback: Callable) -> void:
	_close_callback = close_callback


func _ready() -> void:
	%BackButton.pressed.connect(_on_close)
	%InventoryButton.pressed.connect(_open_inventory)
	%SaveAvatarButton.pressed.connect(_save_avatar)
	%SaveLoadoutButton.pressed.connect(_save_loadout)
	gender_option.item_selected.connect(_on_gender_selected)
	hat_list.item_selected.connect(func(_i): _refresh_avatar())
	outfit_list.item_selected.connect(func(_i): _refresh_avatar())
	CardService.cards_updated.connect(_on_cards_updated)
	InventoryService.inventory_updated.connect(_on_inventory_updated)
	_setup_gender_options()
	_avatar_animator = CharacterAnimator.new()
	_avatar_animator.name = "AvatarAnimator"
	add_child(_avatar_animator)
	_populate_cosmetics()
	_refresh_avatar()
	CardService.fetch_collection()
	InventoryService.fetch_inventory()


func _setup_gender_options() -> void:
	gender_option.clear()
	gender_option.add_item("Male", 0)
	gender_option.set_item_metadata(0, "male")
	gender_option.add_item("Female", 1)
	gender_option.set_item_metadata(1, "female")


func _on_close() -> void:
	if _close_callback.is_valid():
		_close_callback.call()
	else:
		get_tree().change_scene_to_file("res://scenes/world/town.tscn")


func _open_inventory() -> void:
	var town: Node = get_tree().current_scene
	if town and town.has_method("open_inventory"):
		if _close_callback.is_valid():
			_close_callback.call()
		town.open_inventory()


func _on_inventory_updated(_items: Array) -> void:
	_populate_cosmetics()


func _on_gender_selected(_index: int) -> void:
	_refresh_avatar()


func _populate_cosmetics() -> void:
	hat_list.clear()
	outfit_list.clear()
	_hat_keys.clear()
	_armor_keys.clear()

	for key in InventoryService.get_owned_cosmetic_keys():
		var item_key: String = String(key)
		if ItemCatalog.get_slot(item_key) != "hat":
			continue
		var item: Dictionary = ItemCatalog.get_item(item_key)
		if item.is_empty():
			continue
		hat_list.add_item(item.get("name", item_key))
		_hat_keys.append(item_key)

	_armor_keys.append(DEFAULT_ARMOR_KEY)
	outfit_list.add_item(ItemCatalog.get_item(DEFAULT_ARMOR_KEY).get("name", DEFAULT_ARMOR_KEY))
	for key in InventoryService.get_owned_armor_keys():
		var item_key: String = String(key)
		if item_key == DEFAULT_ARMOR_KEY:
			continue
		var item: Dictionary = ItemCatalog.get_item(item_key)
		if item.is_empty():
			continue
		outfit_list.add_item(item.get("name", item_key))
		_armor_keys.append(item_key)

	var config_variant: Variant = GameState.profile.get("avatar_config", {})
	var config: Dictionary = config_variant if config_variant is Dictionary else {}
	_select_current_cosmetic(hat_list, _hat_keys, String(config.get("hat", "")))
	_select_current_cosmetic(outfit_list, _armor_keys, String(config.get("armor", DEFAULT_ARMOR_KEY)))
	_select_gender(String(config.get("gender", "male")))


func _select_gender(gender: String) -> void:
	var target: String = "female" if gender == "female" else "male"
	for i in gender_option.item_count:
		if String(gender_option.get_item_metadata(i)) == target:
			gender_option.select(i)
			return


func _select_current_cosmetic(list: ItemList, keys: Array, current_key: String) -> void:
	if current_key.is_empty():
		return
	for i in keys.size():
		if String(keys[i]) == current_key:
			list.select(i)
			return


func _get_selected_gender() -> String:
	var selected: int = gender_option.get_selected()
	if selected < 0:
		return "male"
	return String(gender_option.get_item_metadata(selected))


func _refresh_avatar() -> void:
	var config_variant: Variant = GameState.profile.get("avatar_config", {})
	var config: Dictionary = config_variant if config_variant is Dictionary else {}
	var preview: Dictionary = config.duplicate()
	preview["gender"] = _get_selected_gender()
	if outfit_list.get_selected_items().size() > 0:
		var idx: int = outfit_list.get_selected_items()[0]
		if idx < _armor_keys.size():
			preview["armor"] = _armor_keys[idx]
	if hat_list.get_selected_items().size() > 0:
		var idx: int = hat_list.get_selected_items()[0]
		if idx < _hat_keys.size():
			preview["hat"] = _hat_keys[idx]
	CharacterCustomizer.apply_avatar_to_node(avatar_root, preview)
	_avatar_animator.setup(avatar_root)


func _save_avatar() -> void:
	var config_variant: Variant = GameState.profile.get("avatar_config", {}).duplicate()
	var config: Dictionary = config_variant if config_variant is Dictionary else {}
	config["gender"] = _get_selected_gender()
	if hat_list.get_selected_items().size() > 0:
		var idx: int = hat_list.get_selected_items()[0]
		if idx < _hat_keys.size():
			config["hat"] = _hat_keys[idx]
	if outfit_list.get_selected_items().size() > 0:
		var idx: int = outfit_list.get_selected_items()[0]
		if idx < _armor_keys.size():
			config["armor"] = _armor_keys[idx]
	GameState.profile["avatar_config"] = config
	var profile: Dictionary = GameState.profile.duplicate()
	profile["avatar_config"] = config
	GameState.set_profile_data(profile)
	SupabaseClient.update("profiles", "id=eq.%s" % GameState.profile_id, {"avatar_config": config})
	_refresh_avatar()
	status_label.text = "Avatar saved"


func _on_cards_updated(cards: Array) -> void:
	loadout_list.clear()
	for card_variant in cards:
		if typeof(card_variant) != TYPE_DICTIONARY:
			continue
		var card: Dictionary = card_variant
		loadout_list.add_item(card.get("card_id", ""))


func _save_loadout() -> void:
	var selected := loadout_list.get_selected_items()
	var ids: Array = []
	for idx in selected:
		var card_variant: Variant = CardService.get_collection()[idx]
		if typeof(card_variant) != TYPE_DICTIONARY:
			continue
		var card_row: Dictionary = card_variant
		ids.append(card_row.get("card_id", ""))
	if ids.is_empty():
		ids = CardService.get_default_cards()
	CardService.set_loadout(ids)
	status_label.text = "Loadout saved"
