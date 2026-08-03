extends SubViewportContainer

@export var preview_width: int = 160
@export var preview_height: int = 200

var _viewport: SubViewport
var _avatar_root: Node3D
var _animator: CharacterAnimator


func _ready() -> void:
	custom_minimum_size = Vector2(preview_width, preview_height)
	stretch = true
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(preview_width, preview_height)
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport.own_world_3d = true
	add_child(_viewport)

	var world_env := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.16, 0.18, 0.22, 1)
	world_env.environment = env
	_viewport.add_child(world_env)

	var cam := Camera3D.new()
	cam.position = Vector3(0, 1.1, 2.6)
	cam.look_at(Vector3(0, 0.85, 0))
	_viewport.add_child(cam)

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45, 35, 0)
	_viewport.add_child(light)

	_avatar_root = Node3D.new()
	_avatar_root.name = "AvatarRoot"
	_viewport.add_child(_avatar_root)

	_animator = CharacterAnimator.new()
	_animator.name = "PreviewAnimator"
	_avatar_root.add_child(_animator)


func show_avatar(avatar_config: Dictionary) -> void:
	if _avatar_root == null:
		return
	CharacterCustomizer.apply_avatar_to_node(_avatar_root, avatar_config)
	_animator.setup(_avatar_root)
	_animator.refresh()
