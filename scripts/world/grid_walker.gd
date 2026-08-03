extends Node3D
class_name GridWalker

const TownLayout = preload("res://scripts/world/town_layout.gd")

signal tile_changed(tile: Vector2i)
signal move_finished(tile: Vector2i)
signal path_completed(tile: Vector2i)
signal movement_changed(is_moving: bool)
signal facing_changed(facing: Vector2i)

@export var move_duration: float = 0.32

var current_tile: Vector2i = Vector2i.ZERO
var facing: Vector2i = Vector2i(0, 1)

var _tiles: Array = []
var _is_moving: bool = false
var _move_t: float = 0.0
var _from_pos: Vector3 = Vector3.ZERO
var _to_pos: Vector3 = Vector3.ZERO
var _path_queue: Array = []
var _was_in_motion: bool = false
var _character_animator: CharacterAnimator


func setup(tiles: Array, start_tile: Vector2i) -> void:
	_tiles = tiles
	current_tile = start_tile
	_place_on_tile(start_tile)


func _place_on_tile(tile: Vector2i) -> void:
	var center: Vector3 = TownLayout.tile_to_world(tile)
	global_position = Vector3(center.x, 0.0, center.z)


func is_path_idle() -> bool:
	return not _is_moving and _path_queue.is_empty()


func is_in_motion() -> bool:
	return _is_moving or not _path_queue.is_empty()


func refresh_avatar_animation() -> void:
	_ensure_character_animator()
	if _character_animator and is_instance_valid(_character_animator):
		_character_animator.refresh()


func path_to(target: Vector2i) -> bool:
	if target == current_tile:
		path_completed.emit(current_tile)
		return true
	var path: Array = _find_path(current_tile, target)
	if path.is_empty():
		return false
	_path_queue = path
	if not _is_moving:
		_advance_path()
	return true


func cancel_path() -> void:
	_path_queue.clear()
	_notify_motion_state()


func get_adjacent_poi_id(pois: Array) -> String:
	for poi_variant in pois:
		if typeof(poi_variant) != TYPE_DICTIONARY:
			continue
		var poi: Dictionary = poi_variant
		var poi_tile := Vector2i(int(poi.get("x", 0)), int(poi.get("y", 0)))
		if _is_adjacent(current_tile, poi_tile):
			return String(poi.get("id", ""))
	return ""


func is_adjacent_to_tile(tile: Vector2i) -> bool:
	return _is_adjacent(current_tile, tile)


func find_path_to(target: Vector2i) -> Array:
	return _find_path(current_tile, target)


func _find_path(from: Vector2i, to: Vector2i) -> Array:
	if not TownLayout.is_walkable(_tiles, to):
		return []
	var queue: Array = [from]
	var came_from: Dictionary = {from: null}
	var head: int = 0
	while head < queue.size():
		var current: Vector2i = queue[head]
		head += 1
		if current == to:
			break
		for dir in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var next: Vector2i = current + dir
			if not TownLayout.is_walkable(_tiles, next):
				continue
			if came_from.has(next):
				continue
			came_from[next] = current
			queue.append(next)
	if not came_from.has(to):
		return []
	var path: Array = []
	var cur: Variant = to
	while cur != from:
		path.append(cur)
		cur = came_from[cur]
	path.reverse()
	return path


func _advance_path() -> void:
	if _path_queue.is_empty():
		return
	var next: Vector2i = _path_queue[0]
	_path_queue.remove_at(0)
	_set_facing(next - current_tile)
	_begin_step(next)


func _set_facing(direction: Vector2i) -> void:
	if direction == Vector2i.ZERO:
		return
	facing = direction
	facing_changed.emit(facing)


func _is_adjacent(a: Vector2i, b: Vector2i) -> bool:
	return abs(a.x - b.x) + abs(a.y - b.y) == 1


func _begin_step(next: Vector2i) -> void:
	_is_moving = true
	_move_t = 0.0
	_from_pos = TownLayout.tile_to_world(current_tile)
	_to_pos = TownLayout.tile_to_world(next)
	current_tile = next
	tile_changed.emit(current_tile)
	_notify_motion_state()


func _ready() -> void:
	_ensure_character_animator()


func _ensure_character_animator() -> void:
	if _character_animator and is_instance_valid(_character_animator):
		return
	_character_animator = get_node_or_null("CharacterAnimator") as CharacterAnimator
	if _character_animator:
		_character_animator.setup(self, self)
		return
	_character_animator = CharacterAnimator.new()
	_character_animator.name = "CharacterAnimator"
	add_child(_character_animator)
	_character_animator.setup(self, self)


func _notify_motion_state() -> void:
	var moving: bool = is_in_motion()
	if moving == _was_in_motion:
		return
	_was_in_motion = moving
	movement_changed.emit(moving)


func _process(delta: float) -> void:
	if not _is_moving:
		return
	_move_t += delta / move_duration
	if _move_t >= 1.0:
		global_position = _to_pos
		_is_moving = false
		move_finished.emit(current_tile)
		if not _path_queue.is_empty():
			_advance_path()
		else:
			path_completed.emit(current_tile)
		_notify_motion_state()
		return
	var t := smoothstep(0.0, 1.0, _move_t)
	global_position = _from_pos.lerp(_to_pos, t)
