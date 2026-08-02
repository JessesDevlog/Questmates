extends Control

@onready var status_label: Label = %StatusLabel


func _ready() -> void:
	%BackButton.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/ui/hub_screen.tscn"))
	%CreateLobbyButton.pressed.connect(_create_lobby)
	%JoinLobbyButton.pressed.connect(_join_lobby)
	%StartRunButton.pressed.connect(_start_run)
	%EnterDungeonButton.pressed.connect(_enter_dungeon)
	DungeonService.lobby_updated.connect(_on_lobby_updated)
	DungeonService.fetch_active_run()


func _on_lobby_updated(run: Dictionary) -> void:
	if run.is_empty():
		status_label.text = "No active run. Create or join lobby."
		return
	status_label.text = "Run %s | status: %s | depth: %d" % [
		run.get("id", ""),
		run.get("status", ""),
		int(run.get("depth", 0)),
	]


func _create_lobby() -> void:
	DungeonService.create_lobby()


func _join_lobby() -> void:
	var run := DungeonService.get_current_run()
	if run.is_empty():
		DungeonService.fetch_active_run()
		return
	DungeonService.join_lobby(run.get("id", ""))


func _start_run() -> void:
	var run := DungeonService.get_current_run()
	if run.is_empty():
		return
	DungeonService.start_run(run.get("id", ""))


func _enter_dungeon() -> void:
	var run := DungeonService.get_current_run()
	if run.get("status", "") != "active":
		status_label.text = "Both players must be ready and run must be active"
		return
	get_tree().change_scene_to_file("res://scenes/dungeon/dungeon_run.tscn")
