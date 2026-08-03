extends Node

## Player-facing settings persisted locally.

signal camera_zoom_changed(ortho_size: float)

const CONFIG_PATH := "user://player_settings.cfg"
const ZOOM_MIN := 4.0
const ZOOM_MAX := 40.0
const ZOOM_DEFAULT := 14.0
const ZOOM_LANDSCAPE_DEFAULT := ZOOM_DEFAULT * 1.35

var camera_ortho_size_portrait: float = ZOOM_DEFAULT
var camera_ortho_size_landscape: float = ZOOM_LANDSCAPE_DEFAULT


func _ready() -> void:
	_load()


func get_camera_ortho_size(for_landscape: bool) -> float:
	return camera_ortho_size_landscape if for_landscape else camera_ortho_size_portrait


func set_camera_ortho_size(value: float, for_landscape: bool = false) -> void:
	var clamped: float = clampf(value, ZOOM_MIN, ZOOM_MAX)
	if for_landscape:
		camera_ortho_size_landscape = clamped
	else:
		camera_ortho_size_portrait = clamped
	_save()
	camera_zoom_changed.emit(clamped)


func set_camera_ortho_size_for_current_orientation(value: float) -> void:
	set_camera_ortho_size(value, DisplaySettings.is_landscape)


func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(CONFIG_PATH) != OK:
		_migrate_from_dev_knobs()
		return
	if cfg.has_section_key("settings", "camera_ortho_size_portrait"):
		camera_ortho_size_portrait = float(
			cfg.get_value("settings", "camera_ortho_size_portrait", ZOOM_DEFAULT)
		)
		camera_ortho_size_landscape = float(
			cfg.get_value("settings", "camera_ortho_size_landscape", ZOOM_LANDSCAPE_DEFAULT)
		)
	elif cfg.has_section_key("settings", "camera_ortho_size"):
		var legacy: float = float(cfg.get_value("settings", "camera_ortho_size", ZOOM_DEFAULT))
		camera_ortho_size_portrait = legacy
		camera_ortho_size_landscape = legacy * 1.35
	else:
		_migrate_from_dev_knobs()
		return
	_clamp_zoom_values()


func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("settings", "camera_ortho_size_portrait", camera_ortho_size_portrait)
	cfg.set_value("settings", "camera_ortho_size_landscape", camera_ortho_size_landscape)
	cfg.save(CONFIG_PATH)


func _migrate_from_dev_knobs() -> void:
	var legacy := ConfigFile.new()
	if legacy.load("user://dev_knobs.cfg") == OK:
		var value: float = float(legacy.get_value("knobs", "camera_ortho_size", ZOOM_DEFAULT))
		camera_ortho_size_portrait = value
		camera_ortho_size_landscape = value * 1.35
	_clamp_zoom_values()
	_save()


func _clamp_zoom_values() -> void:
	camera_ortho_size_portrait = clampf(camera_ortho_size_portrait, ZOOM_MIN, ZOOM_MAX)
	camera_ortho_size_landscape = clampf(camera_ortho_size_landscape, ZOOM_MIN, ZOOM_MAX)
