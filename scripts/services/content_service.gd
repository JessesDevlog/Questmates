extends Node

signal content_updated

var _pending_action: String = ""


func _ready() -> void:
	SupabaseClient.request_completed.connect(_on_request_completed)


func fetch_remote_content() -> void:
	_pending_action = "fetch"
	SupabaseClient.select("content_items", "*", "&is_active=eq.true")
	ShopService.fetch_shop_items()


func _on_request_completed(result: Dictionary) -> void:
	if _pending_action == "fetch":
		var data: Variant = result.get("data", [])
		if typeof(data) == TYPE_ARRAY:
			ItemCatalog.merge_remote_content(data)
			content_updated.emit()
	_pending_action = ""
