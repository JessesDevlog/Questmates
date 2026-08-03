extends Control

@onready var create_panel: VBoxContainer = %CreatePanel
@onready var join_panel: VBoxContainer = %JoinPanel
@onready var homestead_name_input: LineEdit = %HomesteadNameInput
@onready var invite_code_input: LineEdit = %InviteCodeInput
@onready var invite_code_label: Label = %InviteCodeLabel
@onready var status_label: Label = %StatusLabel

var _created_invite_code: String = ""


func _ready() -> void:
	if GameState.onboarding_display_name.is_empty():
		GameState.onboarding_display_name = String(GameState.profile.get("display_name", "Adventurer"))
	if GameState.onboarding_gender.is_empty():
		var cfg: Variant = GameState.profile.get("avatar_config", {})
		if cfg is Dictionary:
			GameState.onboarding_gender = String(cfg.get("gender", "male"))
	%CreateTabButton.pressed.connect(_show_create)
	%JoinTabButton.pressed.connect(_show_join)
	%CreateButton.pressed.connect(_on_create)
	%JoinButton.pressed.connect(_on_join)
	%ContinueAfterCreateButton.pressed.connect(_enter_main_menu)
	HomesteadService.operation_finished.connect(_on_operation_finished)
	HomesteadService.operation_failed.connect(_on_operation_failed)
	_show_create()
	invite_code_label.visible = false
	%ContinueAfterCreateButton.visible = false


func _show_create() -> void:
	create_panel.visible = true
	join_panel.visible = false
	%CreateTabButton.button_pressed = true
	%JoinTabButton.button_pressed = false
	status_label.text = ""


func _show_join() -> void:
	create_panel.visible = false
	join_panel.visible = true
	%CreateTabButton.button_pressed = false
	%JoinTabButton.button_pressed = true
	status_label.text = ""


func _on_create() -> void:
	var homestead_name := homestead_name_input.text.strip_edges()
	if homestead_name.is_empty():
		status_label.text = "Enter a homestead name."
		return
	status_label.text = "Creating homestead..."
	HomesteadService.create_homestead(
		GameState.onboarding_display_name,
		GameState.onboarding_gender,
		homestead_name
	)


func _on_join() -> void:
	var code := invite_code_input.text.strip_edges()
	if code.is_empty():
		status_label.text = "Enter an invite code."
		return
	status_label.text = "Joining homestead..."
	HomesteadService.join_homestead(
		GameState.onboarding_display_name,
		GameState.onboarding_gender,
		code
	)


func _on_operation_finished(action: String, data: Variant) -> void:
	match action:
		"create_homestead":
			if typeof(data) == TYPE_DICTIONARY:
				_created_invite_code = String(data.get("invite_code", HomesteadService.get_invite_code()))
				invite_code_label.text = "Invite code: %s\nShare this with your partner." % _created_invite_code
				invite_code_label.visible = true
				%ContinueAfterCreateButton.visible = true
				status_label.text = "Homestead created!"
			HomesteadService.load_session_context()
		"join_homestead":
			status_label.text = "Joined homestead!"
			GameState.clear_onboarding_temp()
			HomesteadService.load_session_context(_enter_main_menu)


func _on_operation_failed(_action: String, error: String) -> void:
	status_label.text = error


func _enter_main_menu() -> void:
	GameState.clear_onboarding_temp()
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
