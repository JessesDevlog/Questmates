extends Node3D

@export var grid_cell_size: float = 1.0

var _run_id: String = ""
var _level_data: Dictionary = {}
var _combat: CombatManager = CombatManager.new()
var _player_positions: Array = []
var _turn_index: int = 0
var _depth: int = 1


func start_run(run: Dictionary) -> void:
	_run_id = run.get("id", "")
	_depth = int(run.get("depth", 1))
	var seed_value := int(run.get("run_seed", randi()))
	_level_data = LevelGenerator.generate_level(seed_value, _depth)
	_player_positions = [
		{"profile_id": run.get("player_a_profile_id", ""), "x": 1, "y": 1},
		{"profile_id": run.get("player_b_profile_id", ""), "x": 2, "y": 1},
	]
	_combat.setup(_player_positions, _level_data.get("enemies", []), DungeonService.get_combat_modifiers())
	var loadout: Array = CardService.get_loadout()
	if loadout.is_empty():
		loadout = CardService.get_default_cards()
	_combat.init_loadout(loadout)
	_render_level()


func _render_level() -> void:
	for child in get_children():
		if child.name != "Camera3D":
			child.queue_free()

	var tiles_data: Array = _level_data.get("tiles", [])
	for y in tiles_data.size():
		var row_variant: Variant = tiles_data[y]
		if typeof(row_variant) != TYPE_ARRAY:
			continue
		var row: Array = row_variant
		for x in row.size():
			if row[x] == 1:
				_spawn_tile(x, y, Color(0.3, 0.3, 0.35))
			else:
				_spawn_tile(x, y, Color(0.5, 0.55, 0.6))

	for enemy_variant in _level_data.get("enemies", []):
		if typeof(enemy_variant) != TYPE_DICTIONARY:
			continue
		var enemy: Dictionary = enemy_variant
		_spawn_marker(int(enemy.get("x", 0)), int(enemy.get("y", 0)), Color(0.9, 0.2, 0.2))

	for p_variant in _player_positions:
		if typeof(p_variant) != TYPE_DICTIONARY:
			continue
		var p: Dictionary = p_variant
		_spawn_marker(int(p.get("x", 0)), int(p.get("y", 0)), Color(0.2, 0.7, 0.9))


func _spawn_tile(x: int, y: int, color: Color) -> void:
	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(grid_cell_size, 0.1, grid_cell_size)
	mesh_instance.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mesh_instance.material_override = mat
	mesh_instance.position = Vector3(x * grid_cell_size, 0, y * grid_cell_size)
	add_child(mesh_instance)


func _spawn_marker(x: int, y: int, color: Color) -> void:
	var mesh_instance := MeshInstance3D.new()
	var mesh := CapsuleMesh.new()
	mesh.radius = 0.25
	mesh.height = 0.8
	mesh_instance.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mesh_instance.material_override = mat
	mesh_instance.position = Vector3(x * grid_cell_size, 0.5, y * grid_cell_size)
	add_child(mesh_instance)


func process_turn(action: Dictionary) -> void:
	var profile_id: String = String(action.get("profile_id", GameState.profile_id))
	var action_type: String = String(action.get("type", "basic_attack"))

	var result: Dictionary
	if action_type == "basic_attack":
		result = _combat.basic_attack(profile_id, action.get("target_enemy_id", ""))
	elif action_type == "card":
		result = _combat.play_card(profile_id, action.get("card_id", ""), action)
	else:
		result = {"ok": false}

	DungeonService.send_event(_run_id, "combat_action", result)

	if _combat.all_enemies_defeated():
		_level_data["cleared"] = true
		var loot_options := ["card_slash", "card_arrow", "card_heal", "card_fire", "cosmetic_hat_red"]
		var loot_key: String = loot_options[randi() % loot_options.size()]
		SupabaseClient.call_rpc("mark_level_cleared", {"run_id": _run_id, "loot_key": loot_key})
		DungeonService.send_event(_run_id, "level_cleared", {"depth": _depth, "loot_key": loot_key})
	else:
		_process_enemy_turns()


func _process_enemy_turns() -> void:
	var tiles: Array = _level_data.get("tiles", [])
	for enemy_variant in _level_data.get("enemies", []):
		if typeof(enemy_variant) != TYPE_DICTIONARY:
			continue
		var enemy: Dictionary = enemy_variant
		if int(enemy.get("hp", 0)) <= 0:
			continue
		var next: Vector2i = EnemyAI.get_next_move(enemy, _player_positions, tiles)
		enemy["x"] = next.x
		enemy["y"] = next.y
	_render_level()


func try_descend() -> bool:
	if not _level_data.get("cleared", false):
		return false
	DungeonService.descend(_run_id)
	_depth += 1
	var seed_value := int(DungeonService.get_current_run().get("run_seed", randi()))
	_level_data = LevelGenerator.generate_level(seed_value, _depth)
	_level_data["cleared"] = false
	_render_level()
	return true


func exit_run() -> void:
	DungeonService.exit_and_bank(_run_id)
