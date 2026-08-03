extends RefCounted
class_name CharacterCustomizer

const HAT_SOCKET_NAME := "HatSocket"
const DEFAULT_ARMOR_KEY := "armor_default"
const DEFAULT_GENDER := "male"
const PLACEHOLDER_ARMOR_PATH := "res://assets/placeholder/body.tscn"
const PLACEHOLDER_HAT_PATH := "res://assets/placeholder/box.tscn"


static func apply_avatar_to_node(root: Node3D, avatar_config: Dictionary) -> void:
	for child in root.get_children():
		if child is CharacterAnimator:
			continue
		child.queue_free()

	if not avatar_config.has("armor") and avatar_config.has("outfit"):
		_apply_legacy_avatar(root, avatar_config)
		return

	var gender: String = _normalize_gender(String(avatar_config.get("gender", DEFAULT_GENDER)))
	var armor_key: String = String(avatar_config.get("armor", DEFAULT_ARMOR_KEY))
	var hat_key: String = String(avatar_config.get("hat", ""))

	var armor_path: String = ItemCatalog.get_armor_model_path(armor_key, gender)
	var armor_inst: Node = _spawn_scene(root, armor_path, PLACEHOLDER_ARMOR_PATH)
	if armor_inst == null:
		return

	if hat_key.is_empty():
		return

	var hat_path: String = ItemCatalog.get_asset_path(hat_key)
	var hat_inst: Node = _spawn_scene(null, hat_path, PLACEHOLDER_HAT_PATH)
	if hat_inst == null:
		return

	var socket: Node3D = _find_hat_socket(armor_inst)
	if socket == armor_inst:
		push_warning(
			"CharacterCustomizer: HatSocket not found on armor '%s'; parenting hat to armor root." % armor_key
		)
	socket.add_child(hat_inst)


static func _apply_legacy_avatar(root: Node3D, avatar_config: Dictionary) -> void:
	var body_key: String = String(avatar_config.get("body", "default_body"))
	var outfit_key: String = String(avatar_config.get("outfit", ""))
	var hat_key: String = String(avatar_config.get("hat", ""))

	var body_path: String = ItemCatalog.get_asset_path(body_key)
	if body_path.is_empty():
		body_path = PLACEHOLDER_ARMOR_PATH
	_spawn_scene(root, body_path, PLACEHOLDER_ARMOR_PATH)

	if not outfit_key.is_empty():
		_spawn_scene(root, ItemCatalog.get_asset_path(outfit_key), PLACEHOLDER_HAT_PATH)
	if not hat_key.is_empty():
		_spawn_scene(root, ItemCatalog.get_asset_path(hat_key), PLACEHOLDER_HAT_PATH)


static func _normalize_gender(gender: String) -> String:
	if gender == "female":
		return "female"
	return "male"


static func _spawn_scene(parent: Node, path: String, fallback_path: String) -> Node:
	var resolved_path: String = path
	if resolved_path.is_empty() or not ResourceLoader.exists(resolved_path):
		resolved_path = fallback_path
	if not ResourceLoader.exists(resolved_path):
		return null
	var scene: Resource = load(resolved_path)
	if scene == null:
		return null
	var inst: Node = scene.instantiate()
	if parent:
		parent.add_child(inst)
	return inst


static func _find_hat_socket(armor_root: Node) -> Node3D:
	var socket: Node = armor_root.find_child(HAT_SOCKET_NAME, true, false)
	if socket is Node3D:
		return socket
	if armor_root is Node3D:
		return armor_root
	return null
