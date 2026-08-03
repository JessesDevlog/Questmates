extends Node

signal dungeon_state_updated(state: Dictionary)
signal dungeon_event_received(event: Dictionary)
signal lobby_updated(run: Dictionary)

var _current_run: Dictionary = {}
var _pending_action: String = ""


func _ready() -> void:
	SupabaseClient.request_completed.connect(_on_request_completed)
	SupabaseRealtime.channel_message.connect(_on_realtime_message)


func fetch_active_run() -> void:
	if GameState.household_id.is_empty():
		return
	_pending_action = "fetch_run"
	var filters := "&household_id=eq.%s&status=in.(lobby,active)&order=created_at.desc&limit=1" % GameState.household_id
	SupabaseClient.select("dungeon_runs", "*", filters)


func create_lobby() -> void:
	if not GameState.is_online:
		return
	_pending_action = "create_lobby"
	SupabaseClient.insert("dungeon_runs", {
		"household_id": GameState.household_id,
		"status": "lobby",
		"depth": 0,
		"run_seed": randi(),
		"player_a_profile_id": GameState.profile_id,
		"state": {"players_ready": [GameState.profile_id]},
	})


func join_lobby(run_id: String) -> void:
	if not GameState.is_online:
		return
	_pending_action = "join_lobby"
	SupabaseClient.call_rpc("join_dungeon_lobby", {
		"run_id": run_id,
		"profile_id": GameState.profile_id,
	})


func start_run(run_id: String) -> void:
	if not GameState.is_online:
		return
	_pending_action = "start"
	SupabaseClient.call_rpc("start_dungeon_run", {"run_id": run_id})


func send_event(run_id: String, event_type: String, payload: Dictionary) -> void:
	if not GameState.is_online:
		return
	_pending_action = "event"
	SupabaseClient.insert("dungeon_events", {
		"dungeon_run_id": run_id,
		"profile_id": GameState.profile_id,
		"event_type": event_type,
		"payload": payload,
	})
	SupabaseRealtime.send_broadcast(event_type, payload)


func exit_and_bank(run_id: String) -> void:
	if not GameState.is_online:
		return
	_pending_action = "exit"
	SupabaseClient.call_rpc("bank_dungeon_run", {"run_id": run_id})


func descend(run_id: String) -> void:
	if not GameState.is_online:
		return
	_pending_action = "descend"
	SupabaseClient.call_rpc("descend_dungeon", {"run_id": run_id})


func get_current_run() -> Dictionary:
	return _current_run.duplicate()


func get_combat_modifiers() -> Dictionary:
	var my_mult := GameState.get_combat_multiplier(int(GameState.profile.get("spirit", 100)))
	var partner_mult := 1.0
	if not GameState.partner_profile.is_empty():
		partner_mult = GameState.get_combat_multiplier(int(GameState.partner_profile.get("spirit", 100)))
	return {
		"player_damage_mult": my_mult,
		"player_defense_mult": my_mult,
		"partner_damage_mult": partner_mult,
		"partner_defense_mult": partner_mult,
	}


func _on_request_completed(result: Dictionary) -> void:
	match _pending_action:
		"fetch_run", "create_lobby", "join_lobby", "start", "exit", "descend":
			var data: Variant = result.get("data", [])
			if typeof(data) == TYPE_ARRAY and data.size() > 0:
				var row_variant: Variant = data[0]
				if row_variant is Dictionary:
					_current_run = row_variant
			elif typeof(data) == TYPE_DICTIONARY:
				_current_run = data
			lobby_updated.emit(_current_run.duplicate())
			dungeon_state_updated.emit(_current_run.duplicate())
		"event":
			var data: Variant = result.get("data", [])
			if typeof(data) == TYPE_ARRAY and data.size() > 0:
				var row_variant: Variant = data[0]
				if row_variant is Dictionary:
					dungeon_event_received.emit(row_variant)
			elif typeof(data) == TYPE_DICTIONARY:
				dungeon_event_received.emit(data)
	_pending_action = ""


func _on_realtime_message(_channel: String, payload: Dictionary) -> void:
	if payload.has("event"):
		dungeon_event_received.emit(payload)
