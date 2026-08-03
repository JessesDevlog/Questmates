extends Control

@onready var spirit_label: Label = %SpiritLabel
@onready var coins_label: Label = %CoinsLabel
@onready var partner_label: Label = %PartnerLabel


func _ready() -> void:
	%QuestsButton.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/ui/quest_board.tscn"))
	%ShopButton.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/ui/shop_screen.tscn"))
	%ProfileButton.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/ui/profile_screen.tscn"))
	%TreatsButton.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/ui/treat_screen.tscn"))
	%PetCornerButton.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/ui/pet_corner.tscn"))
	%HomeBaseButton.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/ui/home_base.tscn"))
	%DungeonButton.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/ui/dungeon_lobby.tscn"))
	%HardcoreToggle.pressed.connect(_toggle_hardcore)
	SpiritSystem.apply_penalty_on_open()
	_refresh()


func _refresh() -> void:
	var spirit := int(GameState.profile.get("spirit", 100))
	spirit_label.text = "Spirit: %d (%s)" % [spirit, GameState.get_spirit_tier(spirit)]
	coins_label.text = "Coins: %d" % int(GameState.profile.get("coins", 0))
	var partner_name: String = String(GameState.partner_profile.get("display_name", "Partner"))
	var partner_spirit := int(GameState.partner_profile.get("spirit", 100))
	partner_label.text = "%s Spirit: %d" % [partner_name, partner_spirit]
	%HardcoreToggle.text = "Hardcore: %s" % ("ON" if bool(GameState.household.get("hardcore_mode", false)) else "OFF")


func _toggle_hardcore() -> void:
	var enabled: bool = not bool(GameState.household.get("hardcore_mode", false))
	HardcoreService.toggle_hardcore(enabled)
	GameState.household["hardcore_mode"] = enabled
	_refresh()
