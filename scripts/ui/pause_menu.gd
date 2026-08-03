extends CanvasLayer

@onready var settings_panel: VBoxContainer = %SettingsPanel
@onready var main_panel: VBoxContainer = %MainPanel
@onready var zoom_slider: HSlider = %ZoomSlider
@onready var zoom_label: Label = %ZoomLabel
@onready var orient_button: Button = %OrientButton
@onready var orient_hint_label: Label = %OrientHintLabel

var _town: Node = null
var _syncing_zoom_slider: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	%ResumeButton.pressed.connect(_resume)
	%SettingsButton.pressed.connect(_show_settings)
	%MainMenuButton.pressed.connect(_main_menu)
	%BackButton.pressed.connect(_show_main)
	%LogOutButton.pressed.connect(_log_out)
	%QuitButton.pressed.connect(_quit)
	zoom_slider.min_value = PlayerSettings.ZOOM_MIN
	zoom_slider.max_value = PlayerSettings.ZOOM_MAX
	zoom_slider.value_changed.connect(_on_zoom_changed)
	orient_button.pressed.connect(_on_orient_toggle)
	DisplaySettings.orientation_changed.connect(_on_orientation_changed)
	DisplaySettings.orientation_failed.connect(_on_orientation_failed)
	_sync_zoom_ui()
	_update_orient_label()


func bind_town(town: Node) -> void:
	_town = town


func open() -> void:
	visible = true
	_show_main()
	_sync_zoom_ui()
	get_tree().paused = true


func close() -> void:
	visible = false
	get_tree().paused = false


func _resume() -> void:
	close()


func _show_settings() -> void:
	main_panel.visible = false
	settings_panel.visible = true
	_sync_zoom_ui()


func _show_main() -> void:
	settings_panel.visible = false
	main_panel.visible = true


func _log_out() -> void:
	close()
	GameState.clear_session()
	GameState.clear_onboarding_temp()
	get_tree().change_scene_to_file("res://scenes/ui/login_screen.tscn")


func _main_menu() -> void:
	close()
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")


func _quit() -> void:
	close()
	get_tree().quit()


func _on_zoom_changed(value: float) -> void:
	if _syncing_zoom_slider:
		return
	PlayerSettings.set_camera_ortho_size_for_current_orientation(value)
	if _town and _town.has_method("apply_dev_settings"):
		_town.apply_dev_settings()


func _on_orient_toggle() -> void:
	DisplaySettings.toggle_orientation()


func _on_orientation_changed(_is_landscape: bool) -> void:
	_clear_orient_hint()
	_update_orient_label()
	_sync_zoom_ui()
	if _town and _town.has_method("apply_dev_settings"):
		_town.apply_dev_settings()


func _on_orientation_failed(message: String) -> void:
	orient_hint_label.text = message
	if message.begins_with("Editor game window"):
		orient_hint_label.add_theme_color_override("font_color", Color(0.45, 0.4, 0.3, 1))
	else:
		orient_hint_label.add_theme_color_override("font_color", Color(0.75, 0.35, 0.3, 1))
	_update_orient_label()
	_sync_zoom_ui()


func _sync_zoom_ui() -> void:
	_syncing_zoom_slider = true
	zoom_slider.value = PlayerSettings.get_camera_ortho_size(DisplaySettings.is_landscape)
	_syncing_zoom_slider = false
	var mode: String = "Landscape" if DisplaySettings.is_landscape else "Portrait"
	zoom_label.text = "Camera zoom (%s)" % mode


func _clear_orient_hint() -> void:
	orient_hint_label.text = ""


func _update_orient_label() -> void:
	orient_button.text = "Orientation: %s" % ("Landscape" if DisplaySettings.is_landscape else "Portrait")
