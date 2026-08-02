extends Node

signal household_reset_completed

var _pending_action: String = ""


func _ready() -> void:
	SupabaseClient.request_completed.connect(_on_request_completed)


func toggle_hardcore(enabled: bool) -> void:
	if not GameState.is_online or GameState.household_id.is_empty():
		return
	_pending_action = "toggle"
	SupabaseClient.update("households", "id=eq.%s" % GameState.household_id, {
		"hardcore_mode": enabled,
	})


func reset_household() -> void:
	if not GameState.is_online or GameState.household_id.is_empty():
		return
	_pending_action = "reset"
	SupabaseClient.call_rpc("reset_household", {"household_id": GameState.household_id})


func _on_request_completed(result: Dictionary) -> void:
	if _pending_action == "reset":
		household_reset_completed.emit()
	_pending_action = ""
