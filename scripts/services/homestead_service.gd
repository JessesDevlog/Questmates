extends Node

signal operation_finished(action: String, data: Variant)
signal operation_failed(action: String, error: String)
signal session_context_loaded

var _pending_action: String = ""
var _session_callback: Callable = Callable()


func _ready() -> void:
	SupabaseClient.request_completed.connect(_on_request_completed)
	SupabaseClient.request_failed.connect(_on_request_failed)


func is_household_owner() -> bool:
	return String(GameState.household.get("owner_profile_id", "")) == GameState.profile_id


func get_invite_code() -> String:
	return String(GameState.household.get("invite_code", ""))


func create_homestead(display_name: String, gender: String, homestead_name: String) -> void:
	_pending_action = "create_homestead"
	SupabaseClient.call_rpc("create_homestead", {
		"display_name": display_name,
		"gender": gender,
		"homestead_name": homestead_name,
	})


func join_homestead(display_name: String, gender: String, invite_code: String) -> void:
	_pending_action = "join_homestead"
	SupabaseClient.call_rpc("join_homestead", {
		"display_name": display_name,
		"gender": gender,
		"invite_code": invite_code.strip_edges().to_upper(),
	})


func rename_homestead(new_name: String) -> void:
	_pending_action = "rename_homestead"
	SupabaseClient.call_rpc("rename_homestead", {"new_name": new_name})


func leave_homestead() -> void:
	_pending_action = "leave_homestead"
	SupabaseClient.call_rpc("leave_homestead", {})


func update_character(display_name: String, gender: String) -> void:
	_pending_action = "update_character"
	SupabaseClient.call_rpc("update_character", {
		"display_name": display_name,
		"gender": gender,
	})


func load_session_context(on_complete: Callable = Callable()) -> void:
	_session_callback = on_complete
	if GameState.household_id.is_empty() or GameState.profile_id.is_empty():
		_finish_session_callback()
		return
	_pending_action = "session_household"
	SupabaseClient.select("households", "*", "&id=eq.%s" % GameState.household_id)


func _on_request_failed(error: String) -> void:
	if _pending_action.is_empty():
		return
	var action := _pending_action
	_pending_action = ""
	operation_failed.emit(action, error)


func _on_request_completed(result: Dictionary) -> void:
	var action := _pending_action
	if action.is_empty():
		return

	var data: Variant = result.get("data", null)

	match action:
		"create_homestead", "join_homestead":
			if typeof(data) == TYPE_DICTIONARY:
				_apply_homestead_rpc_result(data)
			_pending_action = ""
			operation_finished.emit(action, data)
			return
		"rename_homestead":
			if typeof(data) == TYPE_DICTIONARY:
				GameState.set_household_data(data)
			_pending_action = ""
			operation_finished.emit(action, data)
			return
		"leave_homestead":
			if typeof(data) == TYPE_DICTIONARY:
				GameState.set_profile_data(data)
				GameState.set_household_data({})
				GameState.set_partner_profile({})
				GameState.set_child_profiles([])
			_pending_action = ""
			operation_finished.emit(action, data)
			return
		"update_character":
			if typeof(data) == TYPE_DICTIONARY:
				GameState.set_profile_data(data)
			_pending_action = ""
			operation_finished.emit(action, data)
			return
		"session_household":
			if typeof(data) == TYPE_ARRAY and not data.is_empty() and data[0] is Dictionary:
				GameState.set_household_data(data[0])
			_pending_action = "session_partner"
			var filters := "&household_id=eq.%s&id=neq.%s" % [GameState.household_id, GameState.profile_id]
			SupabaseClient.select("profiles", "*", filters)
			return
		"session_partner":
			GameState.set_partner_profile({})
			if typeof(data) == TYPE_ARRAY and not data.is_empty() and data[0] is Dictionary:
				GameState.set_partner_profile(data[0])
			_pending_action = "session_children"
			SupabaseClient.select("child_profiles", "*", "&household_id=eq.%s" % GameState.household_id)
			return
		"session_children":
			if typeof(data) == TYPE_ARRAY:
				GameState.set_child_profiles(data)
			ContentService.fetch_remote_content()
			SupabaseRealtime.connect_household_channel(GameState.household_id)
			_pending_action = ""
			session_context_loaded.emit()
			_finish_session_callback()
			return

	_pending_action = ""
	operation_finished.emit(action, data)


func _apply_homestead_rpc_result(data: Dictionary) -> void:
	var profile_variant: Variant = data.get("profile", {})
	if profile_variant is Dictionary:
		GameState.set_profile_data(profile_variant)
	var household_variant: Variant = data.get("household", {})
	if household_variant is Dictionary:
		GameState.set_household_data(household_variant)


func _finish_session_callback() -> void:
	if _session_callback.is_valid():
		var cb := _session_callback
		_session_callback = Callable()
		cb.call()
