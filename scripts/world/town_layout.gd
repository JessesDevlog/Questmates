extends RefCounted
class_name TownLayout

enum TileType {
	GRASS = 0,
	ROAD = 1,
	PLOT = 2,
	WALL = 3,
	PLAZA = 4,
}

const WIDTH := 20
const HEIGHT := 20
const CELL_SIZE := 1.0

static func create_starter_layout() -> Dictionary:
	var tiles: Array = []
	for y in HEIGHT:
		var row: Array = []
		for x in WIDTH:
			row.append(_default_tile(x, y))
		tiles.append(row)

	# Plaza center
	for y in range(8, 12):
		for x in range(8, 12):
			tiles[y][x] = TileType.PLAZA

	# Roads to POIs
	_stamp_road(tiles, Vector2i(10, 8), Vector2i(10, 5)) # quest board
	_stamp_road(tiles, Vector2i(8, 10), Vector2i(2, 2)) # dungeon
	_stamp_road(tiles, Vector2i(8, 10), Vector2i(5, 3)) # cosmetics
	_stamp_road(tiles, Vector2i(12, 10), Vector2i(15, 3)) # weapons
	_stamp_road(tiles, Vector2i(12, 10), Vector2i(17, 10)) # builder
	_stamp_road(tiles, Vector2i(10, 12), Vector2i(10, 15)) # home
	_stamp_road(tiles, Vector2i(8, 12), Vector2i(3, 17)) # treats
	_stamp_road(tiles, Vector2i(12, 12), Vector2i(15, 17)) # pet corner

	# Buildable plots beside roads
	for y in HEIGHT:
		for x in WIDTH:
			if tiles[y][x] == TileType.GRASS and _near_road_or_plaza(tiles, x, y):
				tiles[y][x] = TileType.PLOT

	# Border walls
	for x in WIDTH:
		tiles[0][x] = TileType.WALL
		tiles[HEIGHT - 1][x] = TileType.WALL
	for y in HEIGHT:
		tiles[y][0] = TileType.WALL
		tiles[y][WIDTH - 1] = TileType.WALL

	# Keep spawn walkable
	tiles[10][10] = TileType.PLAZA

	var pois: Array = [
		{"id": "dungeon_gate", "x": 2, "y": 2, "label": "Dungeon Gate"},
		{"id": "shop_cosmetics", "x": 5, "y": 3, "label": "Clothes Caravan"},
		{"id": "shop_weapons", "x": 15, "y": 3, "label": "Weapons Caravan"},
		{"id": "quest_board", "x": 10, "y": 5, "label": "Quest Board"},
		{"id": "builder_yard", "x": 17, "y": 10, "label": "Builder Yard"},
		{"id": "home_profile", "x": 10, "y": 15, "label": "Your Home"},
		{"id": "shop_treats", "x": 3, "y": 17, "label": "Treats Caravan"},
		{"id": "pet_corner", "x": 15, "y": 17, "label": "Pet Corner"},
	]

	return {
		"width": WIDTH,
		"height": HEIGHT,
		"tiles": tiles,
		"pois": pois,
		"spawn": {"x": 10, "y": 10},
	}


static func tile_to_world(tile: Vector2i) -> Vector3:
	return Vector3(
		(tile.x + 0.5) * CELL_SIZE,
		0.0,
		(tile.y + 0.5) * CELL_SIZE
	)


static func world_to_tile(world: Vector3) -> Vector2i:
	return Vector2i(
		int(floor(world.x / CELL_SIZE)),
		int(floor(world.z / CELL_SIZE))
	)


static func is_walkable(tiles: Array, tile: Vector2i) -> bool:
	if tile.x < 0 or tile.y < 0 or tile.y >= tiles.size():
		return false
	var row: Array = tiles[tile.y]
	if tile.x >= row.size():
		return false
	var t: int = int(row[tile.x])
	return t != TileType.WALL


static func is_buildable(tiles: Array, tile: Vector2i) -> bool:
	if tile.x < 0 or tile.y < 0 or tile.y >= tiles.size():
		return false
	var row: Array = tiles[tile.y]
	if tile.x >= row.size():
		return false
	return int(row[tile.x]) == TileType.PLOT


static func _default_tile(x: int, y: int) -> int:
	return TileType.GRASS


static func _stamp_road(tiles: Array, from: Vector2i, to: Vector2i) -> void:
	var x: int = from.x
	var y: int = from.y
	while x != to.x:
		if tiles[y][x] != TileType.PLAZA:
			tiles[y][x] = TileType.ROAD
		x += 1 if to.x > x else -1
	while y != to.y:
		if tiles[y][x] != TileType.PLAZA:
			tiles[y][x] = TileType.ROAD
		y += 1 if to.y > y else -1
	if tiles[y][x] != TileType.PLAZA:
		tiles[y][x] = TileType.ROAD


static func _near_road_or_plaza(tiles: Array, x: int, y: int) -> bool:
	for dy in [-1, 0, 1]:
		for dx in [-1, 0, 1]:
			var nx: int = x + dx
			var ny: int = y + dy
			if ny < 0 or ny >= tiles.size():
				continue
			var row: Array = tiles[ny]
			if nx < 0 or nx >= row.size():
				continue
			var t: int = int(row[nx])
			if t == TileType.ROAD or t == TileType.PLAZA:
				return true
	return false
