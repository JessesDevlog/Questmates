extends Node

signal cards_updated(cards: Array)

var _collection: Array = []
var _loadout: Array = []
var _pending_action: String = ""


func _ready() -> void:
	SupabaseClient.request_completed.connect(_on_request_completed)


func fetch_collection() -> void:
	if GameState.profile_id.is_empty():
		return
	_pending_action = "fetch"
	var filters := "&profile_id=eq.%s" % GameState.profile_id
	SupabaseClient.select("card_collection", "*", filters)


func set_loadout(card_ids: Array) -> void:
	var max_slots := int(GameState.profile.get("card_loadout_slots", 3))
	if card_ids.size() > max_slots:
		card_ids = card_ids.slice(0, max_slots)
	_loadout = card_ids.duplicate()
	if not GameState.is_online:
		return
	_pending_action = "loadout"
	SupabaseClient.update("profiles", "id=eq.%s" % GameState.profile_id, {
		"card_loadout": card_ids,
	})


func get_loadout() -> Array:
	return _loadout.duplicate()


func get_collection() -> Array:
	return _collection.duplicate()


func get_default_cards() -> Array:
	return ["card_slash", "card_arrow", "card_heal"]


func _on_request_completed(result: Dictionary) -> void:
	match _pending_action:
		"fetch":
			var data: Variant = result.get("data", [])
			if typeof(data) == TYPE_ARRAY:
				_collection = data
				cards_updated.emit(_collection.duplicate())
		"loadout":
			pass
	_pending_action = ""
