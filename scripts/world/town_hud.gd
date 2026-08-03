extends CanvasLayer

@onready var spirit_bar: ProgressBar = %SpiritBar
@onready var spirit_value_label: Label = %SpiritValueLabel
@onready var coins_value_label: Label = %CoinsValueLabel
@onready var interact_label: Label = %InteractLabel
@onready var build_label: Label = %BuildLabel

var _town: Node = null


func setup(town: Node) -> void:
	_town = town
	_refresh_stats()
	GameState.profile_changed.connect(_refresh_stats)
	%InteractButton.pressed.connect(_on_interact)
	%BuildButton.pressed.connect(_on_build_toggle)
	%PauseButton.pressed.connect(_on_pause)
	if %BagButton:
		%BagButton.pressed.connect(_on_bag)


func open_inventory() -> void:
	if _town and _town.has_method("open_inventory"):
		_town.open_inventory()


func refresh_stats() -> void:
	_refresh_stats()


func set_interact_prompt(text: String, visible_prompt: bool) -> void:
	interact_label.text = text
	%InteractButton.visible = visible_prompt


func set_build_mode(active: bool, detail: String = "") -> void:
	build_label.visible = active
	if active:
		build_label.text = "Build Mode: tap a plot to place\n%s" % detail
		%BuildButton.text = "Exit"
	else:
		%BuildButton.text = "Build"


func _refresh_stats() -> void:
	var spirit: int = int(GameState.profile.get("spirit", 100))
	spirit_bar.value = spirit
	spirit_value_label.text = str(spirit)
	coins_value_label.text = str(int(GameState.profile.get("coins", 0)))


func _on_interact() -> void:
	if _town and _town.has_method("try_interact"):
		_town.try_interact()


func _on_build_toggle() -> void:
	if _town and _town.has_method("toggle_build_mode"):
		_town.toggle_build_mode()


func _on_pause() -> void:
	if _town and _town.has_method("open_pause_menu"):
		_town.open_pause_menu()


func _on_bag() -> void:
	open_inventory()
