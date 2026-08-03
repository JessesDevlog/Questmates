extends Control

@onready var main_panel: VBoxContainer = %MainPanel
@onready var character_panel: VBoxContainer = %CharacterPanel
@onready var homestead_panel: VBoxContainer = %HomesteadPanel
@onready var name_input: LineEdit = %NameInput
@onready var gender_option: OptionButton = %GenderOption
@onready var avatar_preview: SubViewportContainer = %AvatarPreview
@onready var homestead_name_label: Label = %HomesteadNameLabel
@onready var invite_code_label: Label = %InviteCodeLabel
@onready var rename_input: LineEdit = %RenameInput
@onready var join_code_input: LineEdit = %JoinCodeInput
@onready var status_label: Label = %StatusLabel

var _loading_session: bool = false


func _ready() -> void:
	%PlayButton.pressed.connect(_on_play)
	%CharacterButton.pressed.connect(_show_character)
	%HomesteadButton.pressed.connect(_show_homestead)
	%LogOutButton.pressed.connect(_log_out)
	%CharacterBackButton.pressed.connect(_show_main)
	%SaveCharacterButton.pressed.connect(_save_character)
	%HomesteadBackButton.pressed.connect(_show_main)
	%RenameButton.pressed.connect(_rename_homestead)
	%LeaveButton.pressed.connect(_leave_homestead)
	%JoinHomesteadButton.pressed.connect(_join_homestead)
	%CreateHomesteadButton.pressed.connect(_create_homestead)
	gender_option.item_selected.connect(func(_i): _refresh_avatar_preview())
	HomesteadService.operation_finished.connect(_on_operation_finished)
	HomesteadService.operation_failed.connect(_on_operation_failed)
	_setup_gender_options()
	_populate_fields()
	_show_main()
	_loading_session = true
	status_label.text = "Loading..."
	HomesteadService.load_session_context(_on_session_ready)


func _setup_gender_options() -> void:
	gender_option.clear()
	gender_option.add_item("Male", 0)
	gender_option.set_item_metadata(0, "male")
	gender_option.add_item("Female", 1)
	gender_option.set_item_metadata(1, "female")


func _on_session_ready() -> void:
	_loading_session = false
	status_label.text = ""
	_populate_fields()


func _populate_fields() -> void:
	name_input.text = String(GameState.profile.get("display_name", ""))
	var gender := String(GameState.profile.get("avatar_config", {}).get("gender", "male"))
	for i in gender_option.item_count:
		if gender_option.get_item_metadata(i) == gender:
			gender_option.select(i)
			break
	_refresh_avatar_preview()

	homestead_name_label.text = "Homestead: %s" % String(GameState.household.get("name", "—"))
	invite_code_label.text = "Invite code: %s" % HomesteadService.get_invite_code()
	%RenameRow.visible = HomesteadService.is_household_owner() and not GameState.household_id.is_empty()
	rename_input.text = String(GameState.household.get("name", ""))
	%JoinRow.visible = GameState.household_id.is_empty()
	%CreateHomesteadButton.visible = GameState.household_id.is_empty()
	%LeaveRow.visible = not GameState.household_id.is_empty()
	%PlayButton.disabled = not GameState.is_onboarding_complete()


func _refresh_avatar_preview() -> void:
	if avatar_preview == null or not avatar_preview.has_method("show_avatar"):
		return
	var config: Dictionary = GameState.profile.get("avatar_config", {})
	if typeof(config) != TYPE_DICTIONARY:
		config = {}
	var gender := String(gender_option.get_item_metadata(gender_option.selected))
	config["gender"] = gender
	if not config.has("armor"):
		config["armor"] = "armor_default"
	avatar_preview.show_avatar(config)


func _show_main() -> void:
	main_panel.visible = true
	character_panel.visible = false
	homestead_panel.visible = false
	status_label.text = ""


func _show_character() -> void:
	main_panel.visible = false
	character_panel.visible = true
	homestead_panel.visible = false
	_populate_fields()


func _show_homestead() -> void:
	main_panel.visible = false
	character_panel.visible = false
	homestead_panel.visible = true
	_populate_fields()


func _on_play() -> void:
	if _loading_session:
		return
	get_tree().change_scene_to_file("res://scenes/world/town.tscn")


func _save_character() -> void:
	var display_name := name_input.text.strip_edges()
	if display_name.is_empty():
		status_label.text = "Enter a display name."
		return
	var gender := String(gender_option.get_item_metadata(gender_option.selected))
	status_label.text = "Saving..."
	HomesteadService.update_character(display_name, gender)


func _rename_homestead() -> void:
	var new_name := rename_input.text.strip_edges()
	if new_name.is_empty():
		status_label.text = "Enter a homestead name."
		return
	status_label.text = "Renaming..."
	HomesteadService.rename_homestead(new_name)


func _leave_homestead() -> void:
	status_label.text = "Leaving homestead..."
	HomesteadService.leave_homestead()


func _create_homestead() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/homestead_setup.tscn")


func _join_homestead() -> void:
	var code := join_code_input.text.strip_edges()
	if code.is_empty():
		status_label.text = "Enter an invite code."
		return
	status_label.text = "Joining..."
	HomesteadService.join_homestead(
		String(GameState.profile.get("display_name", "Adventurer")),
		String(GameState.profile.get("avatar_config", {}).get("gender", "male")),
		code
	)


func _on_operation_finished(action: String, _data: Variant) -> void:
	match action:
		"update_character":
			status_label.text = "Character saved."
			_refresh_avatar_preview()
		"rename_homestead":
			status_label.text = "Homestead renamed."
			_populate_fields()
		"leave_homestead":
			status_label.text = "Left homestead."
			_populate_fields()
			_show_homestead()
		"join_homestead":
			status_label.text = "Joined homestead!"
			HomesteadService.load_session_context(_populate_fields)


func _on_operation_failed(_action: String, error: String) -> void:
	status_label.text = error


func _log_out() -> void:
	GameState.clear_session()
	GameState.clear_onboarding_temp()
	get_tree().change_scene_to_file("res://scenes/ui/login_screen.tscn")
