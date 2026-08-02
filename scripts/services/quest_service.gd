extends Node

signal quests_updated(quests: Array)

var _quests: Array = []
var _pending_action: String = ""


func _ready() -> void:
	SupabaseClient.request_completed.connect(_on_request_completed)


func fetch_quests() -> void:
	if GameState.household_id.is_empty():
		return
	_pending_action = "fetch"
	var filters := "&household_id=eq.%s&order=created_at.desc" % GameState.household_id
	SupabaseClient.select("quests", "*", filters)


func create_quest(payload: Dictionary) -> void:
	if not GameState.is_online:
		return
	_pending_action = "create"
	payload["household_id"] = GameState.household_id
	payload["creator_profile_id"] = GameState.profile_id
	payload["status"] = "open"
	SupabaseClient.insert("quests", payload)


func accept_quest(quest_id: String) -> void:
	_update_status(quest_id, "accepted", {"assignee_profile_id": GameState.profile_id})


func decline_quest(quest_id: String) -> void:
	_update_status(quest_id, "open", {"assignee_profile_id": null})


func submit_quest(quest_id: String, photo_url: String = "") -> void:
	var extra := {"status": "submitted"}
	if not photo_url.is_empty():
		extra["submitted_photo_url"] = photo_url
	_update_status(quest_id, "submitted", extra)


func approve_quest(quest_id: String) -> void:
	if not GameState.is_online:
		return
	_pending_action = "approve"
	SupabaseClient.rpc("approve_quest", {"quest_id": quest_id, "approver_profile_id": GameState.profile_id})


func reject_quest(quest_id: String, note: String = "") -> void:
	_update_status(quest_id, "rejected", {"rejection_note": note})


func apply_missed_quest_penalties() -> void:
	if not GameState.is_online:
		return
	_pending_action = "penalties"
	SupabaseClient.rpc("apply_missed_quest_penalties", {"household_id": GameState.household_id})


func spawn_from_template(template_id: String, assignee_profile_id: String, deadline_hours: int = 24) -> void:
	if not GameState.is_online:
		return
	_pending_action = "spawn_template"
	SupabaseClient.rpc("spawn_quest_from_template", {
		"template_id": template_id,
		"assignee_profile_id": assignee_profile_id,
		"deadline_hours": deadline_hours,
	})


func get_quests() -> Array:
	return _quests.duplicate()


func _update_status(quest_id: String, status: String, extra: Dictionary = {}) -> void:
	if not GameState.is_online:
		return
	_pending_action = "update"
	var payload := extra.duplicate()
	payload["status"] = status
	payload["updated_at"] = Time.get_datetime_string_from_system(true)
	SupabaseClient.update("quests", "id=eq.%s" % quest_id, payload)


func _on_request_completed(result: Dictionary) -> void:
	var action := _pending_action
	match action:
		"fetch":
			var data: Variant = result.get("data", [])
			if typeof(data) == TYPE_ARRAY:
				_quests = data
				quests_updated.emit(_quests.duplicate())
		"approve", "spawn_template":
			fetch_quests()
		"penalties":
			fetch_quests()
			_refresh_profiles()
		"create", "update":
			fetch_quests()
		"refresh_profiles":
			_apply_profile_refresh(result.get("data", []))
	if action != "refresh_profiles":
		_pending_action = ""


func _refresh_profiles() -> void:
	if GameState.household_id.is_empty():
		return
	_pending_action = "refresh_profiles"
	SupabaseClient.select("profiles", "*", "&household_id=eq.%s" % GameState.household_id)


func _apply_profile_refresh(data: Variant) -> void:
	if typeof(data) != TYPE_ARRAY:
		return
	for row in data:
		if row.get("id", "") == GameState.profile_id:
			GameState.set_profile_data(row)
			SpiritSystem.check_hardcore_reset(int(row.get("spirit", 100)))
		elif row.get("id", "") == GameState.partner_profile.get("id", ""):
			GameState.set_partner_profile(row)
			SpiritSystem.check_hardcore_reset(int(row.get("spirit", 100)))
	_pending_action = ""
