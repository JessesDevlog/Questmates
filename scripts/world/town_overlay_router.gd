extends Node

const OverlayContentHelper = preload("res://scripts/ui/overlay_content_helper.gd")

signal overlay_opened(scene_path: String)
signal overlay_closed

const POI_SCENES: Dictionary = {
	"dungeon_gate": "res://scenes/ui/dungeon_lobby.tscn",
	"shop_cosmetics": "res://scenes/ui/shop_overlay.tscn",
	"shop_weapons": "res://scenes/ui/shop_overlay.tscn",
	"builder_yard": "res://scenes/ui/builder_overlay.tscn",
	"shop_treats": "res://scenes/ui/treat_screen.tscn",
	"quest_board": "res://scenes/ui/quest_board.tscn",
	"home_profile": "res://scenes/ui/profile_screen.tscn",
	"pet_corner": "res://scenes/ui/pet_corner.tscn",
	"inventory": "res://scenes/ui/inventory_overlay.tscn",
}

const POI_SHOP_CATEGORIES: Dictionary = {
	"shop_cosmetics": "cosmetic",
	"shop_weapons": "card",
}

var _overlay_root: Control = null
var _current_shell: Control = null
var _current_content: Control = null


func setup(overlay_root: Control) -> void:
	_overlay_root = overlay_root


func open_poi(poi_id: String) -> void:
	var scene_path: String = String(POI_SCENES.get(poi_id, ""))
	if scene_path.is_empty():
		return
	_open_overlay(scene_path, poi_id)


func open_inventory() -> void:
	_open_overlay("res://scenes/ui/inventory_overlay.tscn", "inventory")


func open_overlay(scene_path: String, context: String = "") -> void:
	_open_overlay(scene_path, context)


func close_overlay() -> void:
	if _current_shell:
		_current_shell.queue_free()
		_current_shell = null
	_current_content = null
	if _overlay_root:
		_overlay_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay_closed.emit()


func is_open() -> bool:
	return _current_shell != null


func _open_overlay(scene_path: String, context: String) -> void:
	close_overlay()
	var packed: PackedScene = load(scene_path)
	if packed == null:
		return

	var shell_packed: PackedScene = load("res://scenes/ui/overlay_shell.tscn")
	_current_shell = shell_packed.instantiate()
	_overlay_root.add_child(_current_shell)
	_current_shell.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_current_content = packed.instantiate()
	OverlayContentHelper.prepare_overlay_content(_current_content)
	_current_shell.mount_content(_current_content)

	if _overlay_root:
		_overlay_root.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay_opened.emit(scene_path)

	if _current_content.has_method("setup_overlay"):
		_current_content.setup_overlay(context, close_overlay)

	var category: String = String(POI_SHOP_CATEGORIES.get(context, ""))
	if category.is_empty() and context == "builder_yard":
		category = "env_asset"
	if not category.is_empty() and _current_content.has_method("set_shop_category"):
		_current_content.set_shop_category(category)

	_rewire_back_buttons(_current_content)


func _rewire_back_buttons(node: Node) -> void:
	var back: Node = node.find_child("BackButton", true, false)
	if back is Button:
		for conn in back.pressed.get_connections():
			back.pressed.disconnect(conn.callable)
		back.pressed.connect(close_overlay)
		back.text = "Close"
