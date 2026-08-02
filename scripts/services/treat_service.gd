extends Node

signal treats_updated(treats: Array)

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
		"title": title,
		"description": description,
		"status": "pending_price",
	})


func set_price(treat_id: String, price: int) -> void:
	if not GameState.is_online:
		return
	_pending_action = "price"
	SupabaseClient.update("treat_requests", "id=eq.%s" % treat_id, {
		"price": price,
		"priced_by_profile_id": GameState.profile_id,
		"status": "available",
	})


func redeem_treat(treat_id: String) -> void:
	if not GameState.is_online:
		return
	_pending_action = "redeem"
	SupabaseClient.call_rpc("redeem_treat", {
		"treat_id": treat_id,
		"buyer_profile_id": GameState.profile_id,
	})


func get_treats() -> Array:
	return _treats.duplicate()


func _on_request_completed(result: Dictionary) -> void:
	match _pending_action:
		"fetch":
			var data: Variant = result.get("data", [])
			if typeof(data) == TYPE_ARRAY:
				_treats = data
				treats_updated.emit(_treats.duplicate())
		"request", "price", "redeem":
			fetch_treats()
	_pending_action = ""
