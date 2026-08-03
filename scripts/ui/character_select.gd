extends Control

@onready var male_preview: SubViewportContainer = %MalePreview
@onready var female_preview: SubViewportContainer = %FemalePreview
@onready var status_label: Label = %StatusLabel

var _selected_gender: String = "male"


func _ready() -> void:
	%MaleButton.pressed.connect(func(): _select_gender("male"))
	%FemaleButton.pressed.connect(func(): _select_gender("female"))
	%ContinueButton.pressed.connect(_on_continue)
	_select_gender(GameState.onboarding_gender if not GameState.onboarding_gender.is_empty() else "male")
	call_deferred("_refresh_previews")


func _select_gender(gender: String) -> void:
	_selected_gender = gender
	GameState.onboarding_gender = gender
	%MaleButton.button_pressed = gender == "male"
	%FemaleButton.button_pressed = gender == "female"
	status_label.text = "Selected: %s" % gender.capitalize()


func _refresh_previews() -> void:
	if male_preview.has_method("show_avatar"):
		male_preview.show_avatar({"gender": "male", "armor": "armor_default"})
	if female_preview.has_method("show_avatar"):
		female_preview.show_avatar({"gender": "female", "armor": "armor_default"})


func _on_continue() -> void:
	if _selected_gender.is_empty():
		status_label.text = "Pick a character."
		return
	GameState.onboarding_gender = _selected_gender
	get_tree().change_scene_to_file("res://scenes/ui/onboarding_name.tscn")
