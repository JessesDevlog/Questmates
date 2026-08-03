extends Node

const TownLayout = preload("res://scripts/world/town_layout.gd")

signal tile_tapped(tile: Vector2i)
signal interact_requested
signal build_tile_tapped(tile: Vector2i)

@export var walker_path: NodePath
@export var camera_path: NodePath
@export var ground_path: NodePath

var build_mode: bool = false

var _walker: Node3D = null
var _camera: Camera3D = null
var _ground: Node3D = null


func _ready() -> void:
	if walker_path:
		_walker = get_node_or_null(walker_path)
	if camera_path:
		_camera = get_node_or_null(camera_path)
	if ground_path:
		_ground = get_node_or_null(ground_path)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		_handle_key(event.keycode)
	elif event is InputEventScreenTouch and event.pressed:
		_handle_tap(event.position)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_handle_tap(event.position)


func request_interact() -> void:
	interact_requested.emit()


func _handle_tap(screen_pos: Vector2) -> void:
	var tile: Vector2i = _screen_to_tile(screen_pos)
	if tile == Vector2i(-1, -1):
		return
	if build_mode:
		build_tile_tapped.emit(tile)
	else:
		tile_tapped.emit(tile)


func _handle_key(keycode: Key) -> void:
	if _walker == null:
		return
	match keycode:
		KEY_W, KEY_UP:
			_nudge(Vector2i(0, -1))
		KEY_S, KEY_DOWN:
			_nudge(Vector2i(0, 1))
		KEY_A, KEY_LEFT:
			_nudge(Vector2i(-1, 0))
		KEY_D, KEY_RIGHT:
			_nudge(Vector2i(1, 0))
		KEY_E, KEY_SPACE, KEY_ENTER:
			interact_requested.emit()


func _nudge(direction: Vector2i) -> void:
	tile_tapped.emit(_walker.current_tile + direction)


func _screen_to_tile(screen_pos: Vector2) -> Vector2i:
	if _camera == null or _ground == null:
		return Vector2i(-1, -1)
	var from: Vector3 = _camera.project_ray_origin(screen_pos)
	var dir: Vector3 = _camera.project_ray_normal(screen_pos)
	var plane := Plane(Vector3.UP, 0.0)
	var hit: Variant = plane.intersects_ray(from, dir)
	if hit == null:
		return Vector2i(-1, -1)
	return TownLayout.world_to_tile(hit)
