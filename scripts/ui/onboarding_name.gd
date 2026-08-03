extends Control

@onready var name_input: LineEdit = %NameInput
@onready var status_label: Label = %StatusLabel


func _ready() -> void:
	%ContinueButton.pressed.connect(_on_continue)
	if not GameState.onboarding_display_name.is_empty():
		name_input.text = GameState.onboarding_display_name
	elif not GameState.profile.get("display_name", "").is_empty():
		name_input.text = String(GameState.profile.get("display_name", ""))


func _on_continue() -> void:
	var display_name := name_input.text.strip_edges()
	if display_name.is_empty():
		status_label.text = "Enter a display name."
		return
	GameState.onboarding_display_name = display_name
	get_tree().change_scene_to_file("res://scenes/ui/homestead_setup.tscn")
