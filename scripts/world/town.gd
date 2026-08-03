extends Node3D

const TownLayout = preload("res://scripts/world/town_layout.gd")

const TILE_COLORS: Dictionary = {
	0: Color(0.62, 0.82, 0.55),
	1: Color(0.88, 0.78, 0.62),
	2: Color(0.72, 0.9, 0.68),
	3: Color(0.72, 0.68, 0.62),
	4: Color(0.95, 0.9, 0.78),
}

const GRID_LINE_COLOR := Color(0.55, 0.5, 0.45)

const POI_COLORS: Dictionary = {
	"dungeon_gate": Color(0.95, 0.55, 0.5),
	"shop_cosmetics": Color(0.95, 0.7, 0.85),
	"shop_weapons": Color(0.9, 0.65, 0.45),
	"quest_board": Color(0.98, 0.88, 0.55),
	"builder_yard": Color(0.55, 0.85, 0.95),
	"home_profile": Color(0.65, 0.8, 0.98),
	"shop_treats": Color(0.98, 0.75, 0.5),
	"pet_corner": Color(0.7, 0.95, 0.65),
}

@onready var ground_root: Node3D = %GroundRoot
@onready var props_root: Node3D = %PropsRoot
@onready var poi_root: Node3D = %PoiRoot
@onready var player: Node3D = %Player
@onready var hud: CanvasLayer = %TownHUD
@onready var overlay_layer: CanvasLayer = %OverlayLayer
@onready var overlay_root: Control = %OverlayRoot
@onready var input_controller: Node = %InputController
@onready var overlay_router: Node = %OverlayRouter
@onready var markers_root: Node3D = %MarkersRoot

var _layout: Dictionary = {}
var _tiles: Array = []
var _pois: Array = []
var _poi_tile_map: Dictionary = {}
var _placed_props: Dictionary = {}
var _build_mode: bool = false
var _selected_build_item: Dictionary = {}
var _selected_build_item_key: String = ""
var _pending_fetch: String = ""
var _plot_highlights: Array = []
var _pending_poi_id: String = ""
var _applied_avatar_signature: String = ""
var _destination_marker: MeshInstance3D = null
var _pause_menu: CanvasLayer = null
var _dev_knobs: CanvasLayer = null


func _ready() -> void:
	_layout = TownLayout.create_starter_layout()
	_tiles = _layout.get("tiles", [])
	_pois = _layout.get("pois", [])
	_build_poi_tile_map()

	_build_ground()
	_spawn_pois()
	_setup_player()
	_setup_camera()
	_setup_input()
	_setup_hud()
	_setup_destination_marker()
	_setup_pause_and_dev()

	apply_dev_settings()
	SpiritSystem.apply_penalty_on_open()
	SupabaseClient.request_completed.connect(_on_request_completed)
	SupabaseRealtime.channel_message.connect(_on_realtime)
	InventoryService.item_placed.connect(_on_item_placed)
	InventoryService.inventory_updated.connect(func(_i): hud.refresh_stats())
	GameState.profile_changed.connect(refresh_player_avatar)
	_fetch_placements()
	ShopService.fetch_shop_items()
	InventoryService.fetch_inventory()


func try_interact() -> void:
	if overlay_router.is_open():
		return
	var poi_id: String = player.get_adjacent_poi_id(_pois)
	if poi_id.is_empty():
		return
	overlay_router.open_poi(poi_id)


func toggle_build_mode() -> void:
	if overlay_router.is_open():
		return
	_build_mode = not _build_mode
	if not _build_mode:
		_selected_build_item = {}
		_selected_build_item_key = ""
	_update_build_highlights()
	var detail := ""
	if not _selected_build_item.is_empty():
		detail = "Placing: %s" % _selected_build_item.get("name", "")
	hud.set_build_mode(_build_mode, detail)


func open_inventory() -> void:
	if overlay_router.is_open():
		return
	overlay_router.open_inventory()


func enter_build_with_item(item: Dictionary) -> void:
	var item_key: String = _resolve_item_key(item)
	if item_key.is_empty():
		return
	enter_build_with_item_key(item_key)


func enter_build_with_item_key(item_key: String) -> void:
	if item_key.is_empty():
		return
	_selected_build_item_key = item_key
	_selected_build_item = {
		"item_key": item_key,
		"name": InventoryService.get_display_name(item_key),
	}
	_build_mode = true
	overlay_router.close_overlay()
	_update_build_highlights()
	hud.set_build_mode(true, "Placing: %s" % _selected_build_item.get("name", ""))


func _on_tile_tapped(tile: Vector2i) -> void:
	if overlay_router.is_open():
		return
	if _build_mode:
		_on_build_tile_tapped(tile)
		return

	var poi_id: String = _get_poi_id_at_tile(tile)
	if not poi_id.is_empty():
		if player.is_adjacent_to_tile(tile):
			overlay_router.open_poi(poi_id)
			_clear_destination_marker()
			return
		var approach: Vector2i = _find_best_approach_tile(tile)
		if approach == Vector2i(-1, -1):
			return
		_pending_poi_id = poi_id
		_show_destination_marker(approach)
		player.path_to(approach)
		return

	if not TownLayout.is_walkable(_tiles, tile):
		return
	_pending_poi_id = ""
	_show_destination_marker(tile)
	player.path_to(tile)


func _build_poi_tile_map() -> void:
	_poi_tile_map.clear()
	for poi_variant in _pois:
		if typeof(poi_variant) != TYPE_DICTIONARY:
			continue
		var poi: Dictionary = poi_variant
		var t := Vector2i(int(poi.get("x", 0)), int(poi.get("y", 0)))
		_poi_tile_map[t] = String(poi.get("id", ""))


func _get_poi_id_at_tile(tile: Vector2i) -> String:
	return String(_poi_tile_map.get(tile, ""))


func _find_best_approach_tile(poi_tile: Vector2i) -> Vector2i:
	var candidates: Array = []
	for dir in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var adj: Vector2i = poi_tile + dir
		if TownLayout.is_walkable(_tiles, adj):
			candidates.append(adj)
	if candidates.is_empty():
		return Vector2i(-1, -1)
	var best: Vector2i = candidates[0]
	var best_len: int = 9999
	for c_variant in candidates:
		var c: Vector2i = c_variant
		var path: Array = player.find_path_to(c)
		var len: int = path.size()
		if len < best_len:
			best_len = len
			best = c
	return best


func _setup_player() -> void:
	var spawn: Dictionary = _layout.get("spawn", {"x": 10, "y": 10})
	var start := Vector2i(int(spawn.get("x", 10)), int(spawn.get("y", 10)))
	player.setup(_tiles, start)
	player.tile_changed.connect(_on_player_tile_changed)
	player.move_finished.connect(_on_player_step)
	player.path_completed.connect(_on_player_path_completed)

	refresh_player_avatar()


func refresh_player_avatar() -> void:
	var config_variant: Variant = GameState.profile.get("avatar_config", {})
	var config: Dictionary = config_variant if config_variant is Dictionary else {}
	var signature: String = JSON.stringify(config)
	if signature == _applied_avatar_signature:
		if player.has_method("refresh_avatar_animation"):
			player.refresh_avatar_animation()
		return
	_applied_avatar_signature = signature
	CharacterCustomizer.apply_avatar_to_node(player, config)
	if player.has_method("refresh_avatar_animation"):
		player.call_deferred("refresh_avatar_animation")


func _setup_camera() -> void:
	var cam: Camera3D = %IsometricCamera
	if cam.has_method("set_target"):
		cam.set_target(player)


func _setup_input() -> void:
	input_controller.tile_tapped.connect(_on_tile_tapped)
	input_controller.interact_requested.connect(try_interact)
	input_controller.build_tile_tapped.connect(_on_build_tile_tapped)
	input_controller.build_mode = false


func open_pause_menu() -> void:
	if _pause_menu and _pause_menu.has_method("open"):
		_pause_menu.open()


func apply_dev_settings() -> void:
	player.move_duration = DevKnobsSettings.move_duration
	_apply_camera_orientation()


func _apply_camera_orientation() -> void:
	var cam: Camera3D = %IsometricCamera
	if cam == null or not cam.has_method("set_ortho_size"):
		return
	cam.set_ortho_size(PlayerSettings.get_camera_ortho_size(DisplaySettings.is_landscape))


func _setup_pause_and_dev() -> void:
	var pause_packed: PackedScene = load("res://scenes/ui/pause_menu.tscn")
	_pause_menu = pause_packed.instantiate()
	add_child(_pause_menu)
	_pause_menu.bind_town(self)

	var dev_packed: PackedScene = load("res://scenes/debug/dev_knobs.tscn")
	_dev_knobs = dev_packed.instantiate()
	add_child(_dev_knobs)
	_dev_knobs.bind_town(self)

	if not DisplaySettings.orientation_changed.is_connected(_on_display_orientation_changed):
		DisplaySettings.orientation_changed.connect(_on_display_orientation_changed)


func _on_display_orientation_changed(_is_landscape: bool) -> void:
	_apply_camera_orientation()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			if _dev_knobs and _dev_knobs.visible:
				return
			if _pause_menu and _pause_menu.visible:
				_pause_menu.close()
			elif overlay_router.is_open():
				overlay_router.close_overlay()
			else:
				open_pause_menu()


func _setup_hud() -> void:
	overlay_router.setup(overlay_root)
	overlay_router.overlay_closed.connect(_on_overlay_closed)
	hud.setup(self)


func _on_overlay_closed() -> void:
	hud.refresh_stats()
	if player.has_method("refresh_avatar_animation"):
		player.refresh_avatar_animation()


func _setup_destination_marker() -> void:
	_destination_marker = MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(TownLayout.CELL_SIZE * 0.88, 0.06, TownLayout.CELL_SIZE * 0.88)
	_destination_marker.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.92, 0.45, 0.75)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.85, 0.4)
	mat.emission_energy_multiplier = 0.35
	_destination_marker.material_override = mat
	_destination_marker.visible = false
	markers_root.add_child(_destination_marker)


func _show_destination_marker(tile: Vector2i) -> void:
	if _destination_marker == null:
		return
	_destination_marker.visible = true
	_destination_marker.position = TownLayout.tile_to_world(tile)
	_destination_marker.position.y = 0.1


func _clear_destination_marker() -> void:
	if _destination_marker:
		_destination_marker.visible = false


func _on_player_tile_changed(_tile: Vector2i) -> void:
	_update_interact_prompt()


func _on_player_step(_tile: Vector2i) -> void:
	if not _pending_poi_id.is_empty():
		if player.get_adjacent_poi_id(_pois) == _pending_poi_id and player.is_path_idle():
			overlay_router.open_poi(_pending_poi_id)
			_pending_poi_id = ""
			_clear_destination_marker()


func _on_player_path_completed(_tile: Vector2i) -> void:
	if not _pending_poi_id.is_empty():
		if player.get_adjacent_poi_id(_pois) == _pending_poi_id:
			overlay_router.open_poi(_pending_poi_id)
			_pending_poi_id = ""
	else:
		_clear_destination_marker()
	_update_interact_prompt()


func _update_interact_prompt() -> void:
	var poi_id: String = player.get_adjacent_poi_id(_pois)
	if poi_id.is_empty():
		hud.set_interact_prompt("", false)
		return
	for poi_variant in _pois:
		if typeof(poi_variant) != TYPE_DICTIONARY:
			continue
		var poi: Dictionary = poi_variant
		if poi.get("id", "") == poi_id:
			hud.set_interact_prompt("Tap %s or Interact" % poi.get("label", poi_id), true)
			return


func _build_ground() -> void:
	for y in _tiles.size():
		var row: Array = _tiles[y]
		for x in row.size():
			var tile_type: int = int(row[x])
			_spawn_tile(x, y, tile_type)


func _spawn_tile(x: int, y: int, tile_type: int) -> void:
	var tile_root := Node3D.new()
	tile_root.position = Vector3(x * TownLayout.CELL_SIZE, 0.0, y * TownLayout.CELL_SIZE)
	ground_root.add_child(tile_root)

	var center_offset := Vector3(
		TownLayout.CELL_SIZE * 0.5,
		0.0,
		TownLayout.CELL_SIZE * 0.5
	)
	var is_wall: bool = tile_type == 3

	if not is_wall:
		var outline := MeshInstance3D.new()
		var outline_mesh := BoxMesh.new()
		outline_mesh.size = Vector3(TownLayout.CELL_SIZE, 0.04, TownLayout.CELL_SIZE)
		outline.mesh = outline_mesh
		var outline_mat := StandardMaterial3D.new()
		outline_mat.albedo_color = GRID_LINE_COLOR
		outline.material_override = outline_mat
		outline.position = center_offset
		outline.position.y = -0.08
		tile_root.add_child(outline)

	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(TownLayout.CELL_SIZE * 0.96, 0.12, TownLayout.CELL_SIZE * 0.96)
	mesh_instance.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = TILE_COLORS.get(tile_type, Color.GRAY)
	mesh_instance.material_override = mat
	mesh_instance.position = center_offset
	mesh_instance.position.y = -0.04
	tile_root.add_child(mesh_instance)


func _spawn_pois() -> void:
	for poi_variant in _pois:
		if typeof(poi_variant) != TYPE_DICTIONARY:
			continue
		var poi: Dictionary = poi_variant
		var poi_node := Node3D.new()
		poi_node.set_script(load("res://scripts/world/poi_interactable.gd"))
		poi_root.add_child(poi_node)
		poi_node.setup(poi)

		var marker := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.65, 1.1, 0.65)
		marker.mesh = mesh
		var mat := StandardMaterial3D.new()
		var poi_id: String = String(poi.get("id", ""))
		mat.albedo_color = POI_COLORS.get(poi_id, Color(0.9, 0.9, 0.9))
		mat.emission_enabled = true
		mat.emission = mat.albedo_color * 0.35
		mat.emission_energy_multiplier = 0.25
		marker.material_override = mat
		marker.position.y = 0.55
		poi_node.add_child(marker)


func _fetch_placements() -> void:
	if GameState.household_id.is_empty():
		return
	_pending_fetch = "placements"
	SupabaseClient.select("home_base_items", "*", "&household_id=eq.%s" % GameState.household_id)


func _on_request_completed(result: Dictionary) -> void:
	if _pending_fetch != "placements":
		return
	_pending_fetch = ""
	var data: Variant = result.get("data", [])
	if typeof(data) != TYPE_ARRAY:
		return
	_clear_props()
	for row_variant in data:
		if typeof(row_variant) != TYPE_DICTIONARY:
			continue
		_spawn_placed_prop(row_variant)


func _on_realtime(_channel: String, payload: Dictionary) -> void:
	if payload.get("type", "") == "db_change":
		_fetch_placements()


func _clear_props() -> void:
	for c in props_root.get_children():
		c.queue_free()
	_placed_props.clear()
	for h in _plot_highlights:
		if is_instance_valid(h):
			h.queue_free()
	_plot_highlights.clear()


func _spawn_placed_prop(row: Dictionary) -> void:
	var pos_variant: Variant = row.get("position", {})
	var pos: Dictionary = pos_variant if pos_variant is Dictionary else {}
	var tile := Vector2i(
		int(pos.get("tile_x", pos.get("x", 0))),
		int(pos.get("tile_y", pos.get("z", 0)))
	)
	if _placed_props.has(tile):
		return

	var item_key: String = String(pos.get("item_key", "env_plant"))
	var world_pos: Vector3 = TownLayout.tile_to_world(tile)
	var prop_root := Node3D.new()
	prop_root.position = world_pos
	props_root.add_child(prop_root)

	var path: String = ItemCatalog.get_asset_path(item_key)
	if path.is_empty():
		path = "res://assets/placeholder/box.tscn"
	if ResourceLoader.exists(path):
		var scene: Resource = load(path)
		if scene:
			var inst: Node = scene.instantiate()
			prop_root.add_child(inst)
	else:
		var mesh_instance := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.5, 0.8, 0.5)
		mesh_instance.mesh = mesh
		prop_root.add_child(mesh_instance)

	_placed_props[tile] = prop_root


func _on_build_tile_tapped(tile: Vector2i) -> void:
	if not _build_mode:
		return
	if not TownLayout.is_buildable(_tiles, tile):
		return
	if _placed_props.has(tile):
		return
	if _selected_build_item_key.is_empty():
		return
	if GameState.household_id.is_empty():
		return
	if not InventoryService.has_item(_selected_build_item_key):
		return

	InventoryService.place_env_item(_selected_build_item_key, {
		"tile_x": tile.x,
		"tile_y": tile.y,
		"rotation": 0,
	})


func _on_item_placed(_result: Dictionary) -> void:
	_build_mode = false
	_selected_build_item = {}
	_selected_build_item_key = ""
	_update_build_highlights()
	hud.set_build_mode(false)
	hud.refresh_stats()
	_fetch_placements()


func _resolve_item_key(item: Dictionary) -> String:
	var direct: String = String(item.get("item_key", ""))
	if not direct.is_empty():
		return direct
	var meta_variant: Variant = item.get("metadata", {})
	var meta: Dictionary = meta_variant if meta_variant is Dictionary else {}
	var meta_key: String = String(meta.get("item_key", ""))
	if not meta_key.is_empty():
		return meta_key
	var item_name: String = String(item.get("name", ""))
	for key in ItemCatalog.get_all_items().keys():
		var catalog: Dictionary = ItemCatalog.get_item(String(key))
		if String(catalog.get("name", "")) == item_name:
			return String(key)
	return item_name


func _update_build_highlights() -> void:
	for h in _plot_highlights:
		if is_instance_valid(h):
			h.queue_free()
	_plot_highlights.clear()
	if not _build_mode:
		input_controller.build_mode = false
		return
	for y in _tiles.size():
		var row: Array = _tiles[y]
		for x in row.size():
			var tile := Vector2i(x, y)
			if not TownLayout.is_buildable(_tiles, tile) or _placed_props.has(tile):
				continue
			var highlight := MeshInstance3D.new()
			var mesh := BoxMesh.new()
			mesh.size = Vector3(TownLayout.CELL_SIZE * 0.9, 0.05, TownLayout.CELL_SIZE * 0.9)
			highlight.mesh = mesh
			var mat := StandardMaterial3D.new()
			mat.albedo_color = Color(1.0, 0.9, 0.2, 0.45)
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			highlight.material_override = mat
			highlight.position = TownLayout.tile_to_world(tile)
			highlight.position.y = 0.08
			ground_root.add_child(highlight)
			_plot_highlights.append(highlight)

	input_controller.build_mode = _build_mode
