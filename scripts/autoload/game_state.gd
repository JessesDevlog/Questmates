extends Node

## Central session and household state cache.

signal profile_changed
signal household_changed
signal connectivity_changed(online: bool)

var access_token: String = ""
var refresh_token: String = ""
var user_id: String = ""
var household_id: String = ""
var profile_id: String = ""
var profile: Dictionary = {}
var household: Dictionary = {}
var partner_profile: Dictionary = {}
var child_profiles: Array = []
var is_online: bool = true
var cached_at: int = 0

const CACHE_PATH := "user://cache_state.json"


func _ready() -> void:
	_load_local_cache()


func set_session(token: String, refresh: String, uid: String) -> void:
	access_token = token
	refresh_token = refresh
	user_id = uid
	_save_local_cache()


func clear_session() -> void:
	access_token = ""
	refresh_token = ""
	user_id = ""
	household_id = ""
	profile_id = ""
	profile = {}
	household = {}
	partner_profile = {}
	child_profiles = []
	_save_local_cache()


func set_profile_data(data: Dictionary) -> void:
	profile = data
	profile_id = data.get("id", "")
	household_id = data.get("household_id", "")
	profile_changed.emit()
	_save_local_cache()


func set_household_data(data: Dictionary) -> void:
	household = data
	household_changed.emit()
	_save_local_cache()


func set_partner_profile(data: Dictionary) -> void:
	partner_profile = data
	_save_local_cache()


func set_child_profiles(data: Array) -> void:
	child_profiles = data
	_save_local_cache()


func set_online(online: bool) -> void:
	if is_online != online:
		is_online = online
		connectivity_changed.emit(online)


func get_spirit_tier(spirit: int) -> String:
	if spirit >= 80:
		return "high"
	if spirit >= 50:
		return "normal"
	if spirit >= 25:
		return "low"
	return "critical"


func get_combat_multiplier(spirit: int) -> float:
	match get_spirit_tier(spirit):
		"high":
			return 1.15
		"normal":
			return 1.0
		"low":
			return 0.85
		"critical":
			return 0.7
	return 1.0


func _save_local_cache() -> void:
	var payload := {
		"access_token": access_token,
		"refresh_token": refresh_token,
		"user_id": user_id,
		"household_id": household_id,
		"profile_id": profile_id,
		"profile": profile,
		"household": household,
		"partner_profile": partner_profile,
		"child_profiles": child_profiles,
		"cached_at": Time.get_unix_time_from_system(),
	}
	var file := FileAccess.open(CACHE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(payload))
		file.close()


func _load_local_cache() -> void:
	if not FileAccess.file_exists(CACHE_PATH):
		return
	var file := FileAccess.open(CACHE_PATH, FileAccess.READ)
	if not file:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	access_token = parsed.get("access_token", "")
	refresh_token = parsed.get("refresh_token", "")
	user_id = parsed.get("user_id", "")
	household_id = parsed.get("household_id", "")
	profile_id = parsed.get("profile_id", "")
	profile = parsed.get("profile", {})
	household = parsed.get("household", {})
	partner_profile = parsed.get("partner_profile", {})
	child_profiles = parsed.get("child_profiles", [])
	cached_at = int(parsed.get("cached_at", 0))
