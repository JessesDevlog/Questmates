extends Node
class_name CharacterAnimator

enum AnimationIntent { IDLE, WALK }

@export var idle_animation: String = "idle"
@export var walk_animation: String = "walk"
@export var blend_time: float = 0.15
@export var model_yaw_offset_degrees: float = 180.0

const _REST_POSE_HINTS: Array[String] = [
	"layer0",
	"rest",
	"bind",
	"tpose",
	"t-pose",
	"t_pose",
	"mixamo",
	"reference",
]

const _IDLE_HINTS: Array[String] = ["idle", "stand", "breath"]
const _WALK_HINTS: Array[String] = ["walk", "walking"]
const _RUN_HINTS: Array[String] = ["run", "running", "jog"]

var _avatar_root: Node3D = null
var _walker: Node = null
var _anim_player: AnimationPlayer = null
var _current_animation: String = ""
var _is_walking: bool = false


func setup(avatar_root: Node3D, walker: Node = null) -> void:
	_avatar_root = avatar_root
	if walker != null and walker != _walker:
		if _walker:
			if _walker.has_signal("movement_changed") and _walker.movement_changed.is_connected(_on_movement_changed):
				_walker.movement_changed.disconnect(_on_movement_changed)
			if _walker.has_signal("facing_changed") and _walker.facing_changed.is_connected(_on_facing_changed):
				_walker.facing_changed.disconnect(_on_facing_changed)
		_walker = walker
		if _walker.has_signal("movement_changed"):
			_walker.movement_changed.connect(_on_movement_changed)
		if _walker.has_signal("facing_changed"):
			_walker.facing_changed.connect(_on_facing_changed)
	refresh()


func _on_facing_changed(direction: Vector2i) -> void:
	_apply_facing(direction)


func refresh() -> void:
	_current_animation = ""
	var walking: bool = false
	if _walker and _walker.has_method("is_in_motion"):
		walking = _walker.call("is_in_motion")
	call_deferred("_finish_refresh", walking)


func _finish_refresh(walking: bool) -> void:
	if _avatar_root == null or not is_instance_valid(_avatar_root):
		return
	_anim_player = _find_animation_player(_avatar_root)
	_force_motion_state(walking)
	if _walker is GridWalker:
		_apply_facing(_walker.facing)


func _on_movement_changed(is_moving: bool) -> void:
	_set_walking(is_moving)


func _force_motion_state(walking: bool) -> void:
	_is_walking = not walking
	_set_walking(walking)


func _set_walking(walking: bool) -> void:
	if _is_walking == walking:
		return
	_is_walking = walking
	_play_intent(AnimationIntent.WALK if walking else AnimationIntent.IDLE)


func _play_intent(intent: AnimationIntent) -> void:
	if _anim_player == null:
		return
	var resolved: String = _resolve_animation_for_intent(_anim_player, intent)
	if resolved.is_empty():
		push_warning("CharacterAnimator: No animation found for intent %s on %s" % [
			"walk" if intent == AnimationIntent.WALK else "idle",
			_avatar_root.name if _avatar_root else "avatar",
		])
		return
	if _current_animation == resolved and _anim_player.is_playing():
		return
	_current_animation = resolved
	_ensure_looping(resolved)
	_anim_player.play(resolved, blend_time)


func _resolve_animation_for_intent(player: AnimationPlayer, intent: AnimationIntent) -> String:
	var candidates: Array[String] = _usable_animation_names(player)
	if candidates.is_empty():
		return ""

	match intent:
		AnimationIntent.IDLE:
			return _pick_best_match(candidates, _IDLE_HINTS, _RUN_HINTS + _WALK_HINTS)
		AnimationIntent.WALK:
			var walk_match: String = _pick_best_match(candidates, _WALK_HINTS, _RUN_HINTS)
			if not walk_match.is_empty():
				return walk_match
			return _pick_best_match(candidates, _RUN_HINTS, _IDLE_HINTS)
	return ""


func _usable_animation_names(player: AnimationPlayer) -> Array[String]:
	var names: Array[String] = []
	for anim_name in player.get_animation_list():
		var name: String = String(anim_name)
		if _is_rest_pose(name):
			continue
		names.append(name)
	return names


func _is_rest_pose(animation_name: String) -> bool:
	var lower: String = animation_name.to_lower()
	for hint in _REST_POSE_HINTS:
		if hint in lower:
			return true
	return false


func _pick_best_match(
	candidates: Array[String],
	preferred_hints: Array[String],
	deprioritized_hints: Array[String]
) -> String:
	var best_name: String = ""
	var best_score: int = -1
	for candidate in candidates:
		var score: int = _score_animation_name(candidate, preferred_hints, deprioritized_hints)
		if score > best_score:
			best_score = score
			best_name = candidate
	return best_name if best_score > 0 else ""


func _score_animation_name(
	animation_name: String,
	preferred_hints: Array[String],
	deprioritized_hints: Array[String]
) -> int:
	var lower: String = animation_name.to_lower()
	var base_name: String = lower.split("/")[-1]
	for hint in deprioritized_hints:
		if hint == base_name or hint in base_name:
			return 0
	for i in preferred_hints.size():
		var hint: String = preferred_hints[i]
		if base_name == hint:
			return 100 - i
		if hint in base_name:
			return 80 - i
		if base_name in hint:
			return 60 - i
	return 0


func _ensure_looping(animation_name: String) -> void:
	var animation: Animation = _anim_player.get_animation(animation_name)
	if animation == null:
		return
	animation.loop_mode = Animation.LOOP_LINEAR


func _apply_facing(direction: Vector2i) -> void:
	var visual: Node3D = _get_visual_root()
	if visual == null or direction == Vector2i.ZERO:
		return
	var world_dir := Vector3(float(direction.x), 0.0, float(direction.y))
	if world_dir.length_squared() < 0.001:
		return
	visual.look_at(visual.global_position + world_dir, Vector3.UP)
	if model_yaw_offset_degrees != 0.0:
		visual.rotate_object_local(Vector3.UP, deg_to_rad(model_yaw_offset_degrees))


func _get_visual_root() -> Node3D:
	if _avatar_root == null:
		return null
	for child in _avatar_root.get_children():
		if child is CharacterAnimator:
			continue
		if child is Node3D:
			return child
	if _avatar_root is Node3D:
		return _avatar_root
	return null


func _find_animation_player(root: Node) -> AnimationPlayer:
	if root == null:
		return null
	if root is AnimationPlayer:
		return root
	for child in root.get_children():
		var found: AnimationPlayer = _find_animation_player(child)
		if found:
			return found
	return null
