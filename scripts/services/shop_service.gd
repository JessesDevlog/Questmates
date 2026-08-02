extends Node

signal shop_updated(items: Array)
signal purchase_completed(item: Dictionary)

var _items: Array = []
var _pending_action: String = ""


func _ready() -> void:
	SupabaseClient.request_completed.connect(_on_request_completed)


func fetch_shop_items() -> void:
	_pending_action = "fetch"
	var filters := "&is_active=eq.true&order=price.asc"
	if not GameState.household_id.is_empty():
		filters += "&or=(household_id.is.null,household_id.eq.%s)" % GameState.household_id
	SupabaseClient.select("shop_items", "*", filters)


func purchase_item(shop_item_id: String) -> void:
	if not GameState.is_online:
		return
	_pending_action = "purchase"
	SupabaseClient.rpc("purchase_shop_item", {
		"shop_item_id": shop_item_id,
		"buyer_profile_id": GameState.profile_id,
	})


func purchase_for_child(shop_item_id: String, child_profile_id: String) -> void:
	if not GameState.is_online:
		return
	_pending_action = "purchase_child"
	SupabaseClient.rpc("purchase_shop_item_for_child", {
		"shop_item_id": shop_item_id,
		"child_profile_id": child_profile_id,
	})


func get_items() -> Array:
	return _items.duplicate()


func _on_request_completed(result: Dictionary) -> void:
	match _pending_action:
		"fetch":
			var data: Variant = result.get("data", [])
			if typeof(data) == TYPE_ARRAY:
				_items = data
				shop_updated.emit(_items.duplicate())
		"purchase", "purchase_child":
			var data: Variant = result.get("data", {})
			if typeof(data) == TYPE_DICTIONARY:
				purchase_completed.emit(data)
			fetch_shop_items()
	_pending_action = ""
