extends Control

@onready var title_input: LineEdit = %TitleInput
@onready var description_input: TextEdit = %DescriptionInput
@onready var pending_list: ItemList = %PendingList
@onready var available_list: ItemList = %AvailableList
@onready var log_list: ItemList = %LogList
@onready var price_input: LineEdit = %PriceInput
@onready var status_label: Label = %StatusLabel
@onready var receipt_panel: PanelContainer = %ReceiptPanel
@onready var receipt_label: Label = %ReceiptLabel
@onready var set_price_button: Button = %SetPriceButton
@onready var redeem_button: Button = %RedeemButton
@onready var fulfill_button: Button = %FulfillButton

var _close_callback: Callable
var _pending_ids: Array = []
var _available_ids: Array = []
var _log_ids: Array = []


func setup_overlay(_context: String, close_callback: Callable) -> void:
	_close_callback = close_callback


func _ready() -> void:
	%BackButton.pressed.connect(_on_close)
	%RequestButton.pressed.connect(_request_treat)
	set_price_button.pressed.connect(_set_price)
	redeem_button.pressed.connect(_redeem_selected)
	fulfill_button.pressed.connect(_fulfill_selected)
	pending_list.item_selected.connect(func(_i): _update_action_buttons())
	available_list.item_selected.connect(func(_i): _update_action_buttons())
	log_list.item_selected.connect(func(_i): _update_action_buttons())
	TreatService.treats_updated.connect(_on_treats_updated)
	TreatService.treat_redeemed.connect(_on_treat_redeemed)
	TreatService.treat_fulfilled.connect(_on_treat_fulfilled)
	receipt_panel.visible = false
	TreatService.fetch_treats()


func _on_close() -> void:
	if _close_callback.is_valid():
		_close_callback.call()


func _on_treats_updated(_treats: Array) -> void:
	_refresh_lists()
	_update_action_buttons()


func _on_treat_redeemed(result: Dictionary) -> void:
	var buyer_name: String = String(result.get("buyer_name", "Partner"))
	var title: String = String(result.get("title", "Treat"))
	var price: int = int(result.get("price", 0))
	receipt_label.text = "%s redeemed: %s!\n\nHonor this in real life (%d coins spent)." % [
		buyer_name, title, price
	]
	receipt_panel.visible = true
	status_label.text = "Redeemed — check the receipt above."


func _on_treat_fulfilled(result: Dictionary) -> void:
	var title: String = String(result.get("title", "Treat"))
	status_label.text = "Marked fulfilled: %s" % title


func _refresh_lists() -> void:
	pending_list.clear()
	available_list.clear()
	log_list.clear()
	_pending_ids.clear()
	_available_ids.clear()
	_log_ids.clear()

	for treat_variant in TreatService.get_pending_price():
		if typeof(treat_variant) != TYPE_DICTIONARY:
			continue
		var treat: Dictionary = treat_variant
		var requester: String = TreatService.get_requester_name(treat)
		var line: String = "%s — %s" % [treat.get("title", ""), requester]
		if TreatService.can_price(treat):
			line += " (tap to price)"
		elif String(treat.get("requested_by_profile_id", "")) == GameState.profile_id:
			line += " (waiting for partner)"
		pending_list.add_item(line)
		_pending_ids.append(String(treat.get("id", "")))

	for treat_variant in TreatService.get_available():
		if typeof(treat_variant) != TYPE_DICTIONARY:
			continue
		var treat: Dictionary = treat_variant
		var requester: String = TreatService.get_requester_name(treat)
		available_list.add_item("%s — %s — %d coins" % [
			treat.get("title", ""),
			requester,
			int(treat.get("price", 0)),
		])
		_available_ids.append(String(treat.get("id", "")))

	for treat_variant in TreatService.get_redemption_log():
		if typeof(treat_variant) != TYPE_DICTIONARY:
			continue
		var treat: Dictionary = treat_variant
		var requester: String = TreatService.get_requester_name(treat)
		var status: String = String(treat.get("status", ""))
		var suffix: String = " (done)" if status == "fulfilled" else " (needs fulfillment)"
		log_list.add_item("%s — %s%s" % [treat.get("title", ""), requester, suffix])
		_log_ids.append(String(treat.get("id", "")))

	if pending_list.item_count == 0:
		pending_list.add_item("No treats awaiting a price.")
	if available_list.item_count == 0:
		available_list.add_item("No treats available to redeem.")
	if log_list.item_count == 0:
		log_list.add_item("No redeemed treats yet.")


func _update_action_buttons() -> void:
	set_price_button.visible = false
	redeem_button.visible = false
	fulfill_button.visible = false
	price_input.visible = false

	var pending_idx := pending_list.get_selected_items()
	if not pending_idx.is_empty() and pending_idx[0] < _pending_ids.size():
		var treat_id: String = String(_pending_ids[pending_idx[0]])
		var treat: Dictionary = _find_treat(treat_id)
		if TreatService.can_price(treat):
			set_price_button.visible = true
			price_input.visible = true

	var available_idx := available_list.get_selected_items()
	if not available_idx.is_empty() and available_idx[0] < _available_ids.size():
		var treat_id: String = String(_available_ids[available_idx[0]])
		var treat: Dictionary = _find_treat(treat_id)
		if TreatService.can_redeem(treat):
			redeem_button.visible = true

	var log_idx := log_list.get_selected_items()
	if not log_idx.is_empty() and log_idx[0] < _log_ids.size():
		var treat_id: String = String(_log_ids[log_idx[0]])
		var treat: Dictionary = _find_treat(treat_id)
		if TreatService.can_fulfill(treat):
			fulfill_button.visible = true


func _find_treat(treat_id: String) -> Dictionary:
	for treat_variant in TreatService.get_treats():
		if typeof(treat_variant) != TYPE_DICTIONARY:
			continue
		var treat: Dictionary = treat_variant
		if String(treat.get("id", "")) == treat_id:
			return treat
	return {}


func _request_treat() -> void:
	var title: String = title_input.text.strip_edges()
	if title.is_empty():
		status_label.text = "Enter a treat title first."
		return
	TreatService.request_treat(title, description_input.text)
	title_input.text = ""
	description_input.text = ""
	status_label.text = "Treat requested — waiting for partner to set a price."


func _set_price() -> void:
	var idx := pending_list.get_selected_items()
	if idx.is_empty() or idx[0] >= _pending_ids.size():
		status_label.text = "Select a treat to price."
		return
	var price: int = int(price_input.text) if price_input.text.is_valid_int() else 0
	if price <= 0:
		status_label.text = "Enter a valid coin price."
		return
	TreatService.set_price(String(_pending_ids[idx[0]]), price)
	status_label.text = "Price set — treat is now available to redeem."


func _redeem_selected() -> void:
	var idx := available_list.get_selected_items()
	if idx.is_empty() or idx[0] >= _available_ids.size():
		status_label.text = "Select an available treat to redeem."
		return
	TreatService.redeem_treat(String(_available_ids[idx[0]]))


func _fulfill_selected() -> void:
	var idx := log_list.get_selected_items()
	if idx.is_empty() or idx[0] >= _log_ids.size():
		status_label.text = "Select a redeemed treat to mark fulfilled."
		return
	TreatService.mark_fulfilled(String(_log_ids[idx[0]]))
