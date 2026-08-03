extends Node

## Runtime display orientation + window size for desktop testing.

signal orientation_changed(is_landscape: bool)
signal orientation_failed(message: String)

const PORTRAIT_VIEWPORT := Vector2i(390, 844)
const LANDSCAPE_VIEWPORT := Vector2i(844, 390)
const CONFIG_PATH := "user://display_settings.cfg"
const DESKTOP_DISPLAY_SCALE := 2
const SOFT_LANDSCAPE_HINT := (
	"Editor game window cannot rotate. Landscape layout applied without resizing the window."
)

var is_landscape: bool = false
var uses_soft_landscape: bool = false

var _pending_landscape: bool = false
var _revert_landscape: bool = false


func _ready() -> void:
	_load_preference()
	call_deferred("_apply_window_size")


func set_portrait() -> void:
	_begin_orientation_change(false)


func set_landscape() -> void:
	_begin_orientation_change(true)


func toggle_orientation() -> void:
	if is_landscape:
		set_portrait()
	else:
		set_landscape()


func get_viewport_size() -> Vector2i:
	return LANDSCAPE_VIEWPORT if is_landscape else PORTRAIT_VIEWPORT


func _begin_orientation_change(target_landscape: bool) -> void:
	_revert_landscape = is_landscape
	_pending_landscape = target_landscape
	is_landscape = target_landscape
	_save_preference()
	_apply_window_size()


func _apply_window_size() -> void:
	uses_soft_landscape = false
	var viewport_size: Vector2i = get_viewport_size()
	var window: Window = get_tree().root

	if OS.has_feature("mobile"):
		var orientation: DisplayServer.ScreenOrientation = (
			DisplayServer.SCREEN_LANDSCAPE if is_landscape else DisplayServer.SCREEN_PORTRAIT
		)
		DisplayServer.screen_set_orientation(orientation)
		call_deferred("_finish_apply", viewport_size, _pending_landscape)
		return

	_request_desktop_resize(window, viewport_size)


func _request_desktop_resize(window: Window, viewport_size: Vector2i) -> void:
	window.mode = Window.MODE_WINDOWED
	window.unresizable = false
	window.min_size = Vector2i.ZERO
	window.max_size = Vector2i.ZERO

	var window_size: Vector2i = viewport_size * DESKTOP_DISPLAY_SCALE
	var window_id: int = window.get_window_id()
	DisplayServer.window_set_min_size(Vector2i.ZERO, window_id)
	DisplayServer.window_set_max_size(Vector2i(16384, 16384), window_id)
	DisplayServer.window_set_size(window_size, window_id)
	window.size = window_size

	call_deferred("_finish_apply", viewport_size, _pending_landscape)


func _finish_apply(viewport_size: Vector2i, target_landscape: bool) -> void:
	await get_tree().process_frame
	await get_tree().process_frame

	var window: Window = get_tree().root
	var actual_size: Vector2i = window.size

	if _size_matches_orientation(actual_size, target_landscape):
		uses_soft_landscape = false
		window.content_scale_size = viewport_size
		orientation_changed.emit(is_landscape)
		return

	if _apply_soft_landscape(window, actual_size, target_landscape):
		return

	is_landscape = _revert_landscape
	_save_preference()

	var reason: String = (
		"Window resize failed (%dx%d). Disable editor game embedding or run a detached game window."
		% [actual_size.x, actual_size.y]
	)
	if window.is_embedded():
		reason = "Embedded game window cannot resize. Disable embed in the editor Game tab."

	print(
		"[DisplaySettings] %s embedded=%s content_scale=%s"
		% [reason, window.is_embedded(), window.content_scale_size]
	)
	orientation_failed.emit(reason)


func _apply_soft_landscape(window: Window, actual_size: Vector2i, target_landscape: bool) -> bool:
	if not target_landscape:
		return false

	uses_soft_landscape = true
	is_landscape = true
	_save_preference()

	# Keep stretch scale stable: logical size matches the physical portrait window.
	window.content_scale_size = _viewport_for_physical_size(actual_size)
	orientation_changed.emit(true)
	orientation_failed.emit(SOFT_LANDSCAPE_HINT)
	return true


func _viewport_for_physical_size(window_size: Vector2i) -> Vector2i:
	var logical_width: int = maxi(1, int(round(float(window_size.x) / float(DESKTOP_DISPLAY_SCALE))))
	var logical_height: int = maxi(1, int(round(float(window_size.y) / float(DESKTOP_DISPLAY_SCALE))))
	return Vector2i(logical_width, logical_height)


func _size_matches_orientation(size: Vector2i, want_landscape: bool) -> bool:
	if want_landscape:
		return size.x > size.y
	return size.y >= size.x


func _load_preference() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(CONFIG_PATH) == OK:
		is_landscape = bool(cfg.get_value("display", "landscape", false))
	_pending_landscape = is_landscape
	_revert_landscape = is_landscape


func _save_preference() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("display", "landscape", is_landscape)
	cfg.save(CONFIG_PATH)
