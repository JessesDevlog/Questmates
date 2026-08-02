extends Node3D

@onready var dungeon_controller: Node = %DungeonController
@onready var status_label: Label = %StatusLabel


func _ready() -> void:
	var run := DungeonService.get_current_run()
	if run.is_empty():
		status_label.text = "No active run"
		return
	SupabaseRealtime.connect_dungeon_channel(run.get("id", ""))
	dungeon_controller.start_run(run)
	%AttackButton.pressed.connect(_basic_attack)
	%DescendButton.pressed.connect(_descend)
	%ExitButton.pressed.connect(_exit_run)
	DungeonService.dungeon_event_received.connect(_on_event)


func _basic_attack() -> void:
	var enemies: Array = dungeon_controller._level_data.get("enemies", [])
	if enemies.is_empty():
		return
	dungeon_controller.process_turn({
		"type": "basic_attack",
		"profile_id": GameState.profile_id,
		"target_enemy_id": enemies[0].get("id", ""),
	})


func _descend() -> void:
	if dungeon_controller.try_descend():
		status_label.text = "Descended deeper"
	else:
		status_label.text = "Clear all enemies first"


func _exit_run() -> void:
	dungeon_controller.exit_run()
	get_tree().change_scene_to_file("res://scenes/ui/hub_screen.tscn")


func _on_event(event: Dictionary) -> void:
	status_label.text = "Event: %s" % JSON.stringify(event)
