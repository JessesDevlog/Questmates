extends Camera3D

@export var target_path: NodePath
@export var ortho_size: float = 14.0
@export var follow_smooth: float = 8.0

var _target: Node3D = null


func _ready() -> void:
	projection = Camera3D.PROJECTION_ORTHOGONAL
	size = ortho_size
	rotation_degrees = Vector3(-35.264, 45.0, 0.0)
	if target_path:
		_target = get_node_or_null(target_path)


func set_target(node: Node3D) -> void:
	_target = node


func set_ortho_size(value: float) -> void:
	ortho_size = value
	size = value


func _process(delta: float) -> void:
	if _target == null:
		return
	var offset := Vector3(10.0, 12.0, 10.0)
	var desired: Vector3 = _target.global_position + offset
	global_position = global_position.lerp(desired, min(1.0, follow_smooth * delta))
	look_at(_target.global_position, Vector3.UP)
