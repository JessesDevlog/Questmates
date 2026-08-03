extends CanvasLayer

@onready var panel: PanelContainer = %Panel
@onready var move_slider: HSlider = %MoveSlider
@onready var orient_button: Button = %OrientButton
@onready var orient_hint_label: Label = %OrientHintLabel

var _town: Node = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	move_slider.value = DevKnobsSettings.move_duration
	_update_orient_label()
	%CloseButton.pressed.connect(_hide)
	move_slider.value_changed.connect(_on_move_changed)
	orient_button.pressed.connect(_on_orient_toggle)
	DisplaySettings.orientation_changed.connect(_on_orientation_changed)
	DisplaySettings.orientation_failed.connect(_on_orientation_failed)


func bind_town(town: Node) -> void:
	_town = town
	_apply_to_town()


func toggle() -> void:
	visible = not visible
	if visible:
		_apply_to_town()


func _hide() -> void:
	visible = false


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_EQUAL:
			toggle()
			get_viewport().set_input_as_handled()


func _on_move_changed(value: float) -> void:
	DevKnobsSettings.set_move_duration(value)
	_apply_to_town()


func _on_orient_toggle() -> void:
	DisplaySettings.toggle_orientation()


func _on_orientation_changed(_is_landscape: bool) -> void:
	_clear_orient_hint()
	_update_orient_label()


func _on_orientation_failed(message: String) -> void:
	orient_hint_label.text = message
	if message.begins_with("Editor game window"):
		orient_hint_label.add_theme_color_override("font_color", Color(0.45, 0.4, 0.3, 1))
	else:
		orient_hint_label.add_theme_color_override("font_color", Color(0.75, 0.35, 0.3, 1))
	_update_orient_label()


func _clear_orient_hint() -> void:
	orient_hint_label.text = ""


func _update_orient_label() -> void:
	orient_button.text = "Orientation: %s" % ("Landscape" if DisplaySettings.is_landscape else "Portrait")


func _apply_to_town() -> void:
	if _town == null:
		return
	if _town.has_method("apply_dev_settings"):
		_town.apply_dev_settings()
