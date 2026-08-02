extends RefCounted
class_name LevelGenerator

const GRID_WIDTH := 10
const GRID_HEIGHT := 10


static func generate_level(seed_value: int, depth: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value + depth * 9973

	var tiles: Array = []
	for y in GRID_HEIGHT:
		var row: Array = []
		for x in GRID_WIDTH:
			var wall_chance := 0.15 + depth * 0.02
			row.append(1 if rng.randf() < wall_chance else 0)
		tiles.append(row)

	# Ensure spawn and exit are walkable
	tiles[1][1] = 0
	tiles[GRID_HEIGHT - 2][GRID_WIDTH - 2] = 0

	var enemies: Array = []
	var enemy_count := 2 + depth
	for i in enemy_count:
		var pos := Vector2i(rng.randi_range(2, GRID_WIDTH - 2), rng.randi_range(2, GRID_HEIGHT - 2))
		if tiles[pos.y][pos.x] == 0:
			enemies.append({
				"id": "enemy_%d" % i,
				"x": pos.x,
				"y": pos.y,
				"hp": 3 + depth,
				"aggro_range": 4,
			})

	return {
		"width": GRID_WIDTH,
		"height": GRID_HEIGHT,
		"tiles": tiles,
		"enemies": enemies,
		"loot_crate": {"x": GRID_WIDTH - 2, "y": GRID_HEIGHT - 2, "opened": false},
		"cleared": false,
	}
