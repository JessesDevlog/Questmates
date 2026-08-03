extends Node3D

const TownLayout = preload("res://scripts/world/town_layout.gd")

@export var poi_id: String = ""
@export var label_text: String = "POI"

var tile: Vector2i = Vector2i.ZERO


func setup(poi: Dictionary) -> void:
	poi_id = String(poi.get("id", ""))
	label_text = String(poi.get("label", poi_id))
	tile = Vector2i(int(poi.get("x", 0)), int(poi.get("y", 0)))
	global_position = TownLayout.tile_to_world(tile)
	global_position.y = 0.5
