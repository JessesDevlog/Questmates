extends Node

signal treats_updated(treats: Array)
signal treat_redeemed(result: Dictionary)
signal treat_fulfilled(result: Dictionary)

var _treats: Array = []
var _pending_action: String = ""


func _ready() -> void:
	SupabaseClient.request_completed.connect(_on_request_completed)


func fetch_treats() -> void:
	if GameState.household_id.is_empty():
		return
	_pending_action = "fetch"
	var filters := "&household_id=eq.%s&order=created_at.desc" % GameState.household_id
	SupabaseClient.select("treat_requests", "*", filters)


func request_treat(title: String, description: String = "") -> void:
	if not GameState.is_online:
		return
	_pending_action = "request"
	SupabaseClient.insert("treat_requests", {
		"household_id": GameState.household_id,
		"requested_by_profile_id": GameState.profile_id,
		"title": title.strip_edges(),
		"description": description.strip_edges(),
		"status": "pending_price",
	})


func set_price(treat_id: String, price: int) -> void:
	if not GameState.is_online:
		return
	_pending_action = "price"
	SupabaseClient.call_rpc("price_treat", {
		"treat_id": treat_id,
		"pricer_profile_id": GameState.profile_id,
		"p_price": price,
	})


func redeem_treat(treat_id: String) -> void:
	if not GameState.is_online:
		return
	_pending_action = "redeem"
	SupabaseClient.call_rpc("redeem_treat", {
		"treat_id": treat_id,
		"buyer_profile_id": GameState.profile_id,
	})


func mark_fulfilled(treat_id: String) -> void:
	if not GameState.is_online:
		return
	_pending_action = "fulfill"
	SupabaseClient.call_rpc("mark_treat_fulfilled", {
		"treat_id": treat_id,
		"actor_profile_id": GameState.profile_id,
	})


func get_treats() -> Array:
	return _treats.duplicate()


func get_by_status(status: String) -> Array:
	var filtered: Array = []
	for treat_variant in _treats:
		if typeof(treat_variant) != TYPE_DICTIONARY:
			continue
		var treat: Dictionary = treat_variant
		if String(treat.get("status", "")) == status:
			filtered.append(treat)
	return filtered


func get_pending_price() -> Array:
	return get_by_status("pending_price")


func get_available() -> Array:
	return get_by_status("available")


func get_redemption_log() -> Array:
	var log: Array = []
	for status in ["redeemed", "fulfilled"]:
		for treat_variant in get_by_status(status):
			log.append(treat_variant)
	return log


func get_requester_name(treat: Dictionary) -> String:
	var requester_id: String = String(treat.get("requested_by_profile_id", ""))
	if requester_id == GameState.profile_id:
		return String(GameState.profile.get("display_name", "You"))
	if requester_id == String(GameState.partner_profile.get("id", "")):
		return String(GameState.partner_profile.get("display_name", "Partner"))
	return "Partner"


func can_price(treat: Dictionary) -> bool:
	if String(treat.get("status", "")) != "pending_price":
		return false
	return String(treat.get("requested_by_profile_id", "")) != GameState.profile_id


func can_redeem(treat: Dictionary) -> bool:
	if String(treat.get("status", "")) != "available":
		return false
	return String(treat.get("requested_by_profile_id", "")) == GameState.profile_id


func can_fulfill(treat: Dictionary) -> bool:
	if String(treat.get("status", "")) != "redeemed":
		return false
	return String(treat.get("requested_by_profile_id", "")) != GameState.profile_id


func _on_request_completed(result: Dictionary) -> void:
	var action := _pending_action
	match action:
		"fetch":
			var data: Variant = result.get("data", [])
			if typeof(data) == TYPE_ARRAY:
				_treats = data
				treats_updated.emit(_treats.duplicate())
		"request", "price":
			fetch_treats()
		"redeem":
			var data: Variant = result.get("data", {})
			if typeof(data) == TYPE_DICTIONARY:
				treat_redeemed.emit(data)
			fetch_treats()
			_refresh_profiles()
		"fulfill":
			var data: Variant = result.get("data", {})
			if typeof(data) == TYPE_DICTIONARY:
				treat_fulfilled.emit(data)
			fetch_treats()
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
		_pending_action = ""
		return
	for row_variant in data:
		if typeof(row_variant) != TYPE_DICTIONARY:
			continue
		var row: Dictionary = row_variant
		if row.get("id", "") == GameState.profile_id:
			GameState.set_profile_data(row)
		elif row.get("id", "") == GameState.partner_profile.get("id", ""):
			GameState.set_partner_profile(row)
	_pending_action = ""
