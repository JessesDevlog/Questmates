extends RefCounted
class_name CharacterCustomizer

static func apply_avatar_to_node(root: Node3D, avatar_config: Dictionary) -> void:
	for child in root.get_children():
		child.queue_free()

	var body_key := avatar_config.get("body", "default_body")
	var outfit_key := avatar_config.get("outfit", "")
	var hat_key := avatar_config.get("hat", "")

	var body_path := ItemCatalog.get_asset_path(body_key)
	if body_path.is_empty():
		body_path = "res://assets/placeholder/body.tscn"
	_spawn_part(root, body_path)

	if not outfit_key.is_empty():
		_spawn_part(root, ItemCatalog.get_asset_path(outfit_key))
	if not hat_key.is_empty():
		_spawn_part(root, ItemCatalog.get_asset_path(hat_key))


static func _spawn_part(parent: Node3D, path: String) -> void:
	if path.is_empty() or not ResourceLoader.exists(path):
		path = "res://assets/placeholder/box.tscn"
	var scene := load(path)
	if scene:
		var inst := scene.instantiate()
		parent.add_child(inst)
