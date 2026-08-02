extends RefCounted
class_name EnemyAI

static func get_next_move(enemy: Dictionary, player_positions: Array, tiles: Array) -> Vector2i:
	var pos := Vector2i(enemy.get("x", 0), enemy.get("y", 0))
	var aggro_range := int(enemy.get("aggro_range", 4))

	var closest: Vector2i = Vector2i(-1, -1)
	var closest_dist := 9999
	for p in player_positions:
		if typeof(p) != TYPE_DICTIONARY:
			continue
		var player_pos := Vector2i(p.get("x", 0), p.get("y", 0))
		var dist := abs(player_pos.x - pos.x) + abs(player_pos.y - pos.y)
		if dist < closest_dist:
			closest_dist = dist
			closest = player_pos

	if closest_dist > aggro_range:
		return pos

	var dx := sign(closest.x - pos.x)
	var dy := sign(closest.y - pos.y)
	var candidates: Array = [
		Vector2i(pos.x + dx, pos.y),
		Vector2i(pos.x, pos.y + dy),
	]
	for candidate in candidates:
		if _is_walkable(candidate, tiles):
			return candidate
	return pos


static func _is_walkable(pos: Vector2i, tiles: Array) -> bool:
	if pos.y < 0 or pos.y >= tiles.size():
		return false
	var row: Array = tiles[pos.y]
	if pos.x < 0 or pos.x >= row.size():
		return false
	return row[pos.x] == 0
