extends Node

## Persists developer tuning knobs ( "=" menu only).

const CONFIG_PATH := "user://dev_knobs.cfg"

var move_duration: float = 0.32


func _ready() -> void:
	_load()


func set_move_duration(value: float) -> void:
	move_duration = clampf(value, 0.1, 0.8)
	_save()


func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(CONFIG_PATH) != OK:
		return
	move_duration = float(cfg.get_value("knobs", "move_duration", 0.32))


func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("knobs", "move_duration", move_duration)
	cfg.save(CONFIG_PATH)
