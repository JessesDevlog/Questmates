extends Control

@onready var treat_list: ItemList = %TreatList
@onready var title_input: LineEdit = %TitleInput
@onready var price_input: LineEdit = %PriceInput
@onready var status_label: Label = %StatusLabel


func _ready() -> void:
	%BackButton.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/ui/hub_screen.tscn"))
	%RequestButton.pressed.connect(_request_treat)
	%SetPriceButton.pressed.connect(_set_price)
	%RedeemButton.pressed.connect(_redeem_selected)
	TreatService.treats_updated.connect(_on_treats_updated)
	TreatService.fetch_treats()


func _on_treats_updated(treats: Array) -> void:
	treat_list.clear()
	for treat in treats:
		var price := treat.get("price", "pending")
		treat_list.add_item("%s | %s | %s coins" % [treat.get("title", ""), treat.get("status", ""), str(price)])


func _get_selected_treat_id() -> String:
	var idx := treat_list.get_selected_items()
	if idx.is_empty():
		return ""
	var treats := TreatService.get_treats()
	if idx[0] >= treats.size():
		return ""
	return treats[idx[0]].get("id", "")


func _request_treat() -> void:
	TreatService.request_treat(title_input.text)
	status_label.text = "Treat requested"


func _set_price() -> void:
	var id := _get_selected_treat_id()
	if id.is_empty():
		return
	TreatService.set_price(id, int(price_input.text if price_input.text.is_valid_int() else "20"))


func _redeem_selected() -> void:
	var id := _get_selected_treat_id()
	if id.is_empty():
		return
	TreatService.redeem_treat(id)
	status_label.text = "Redeemed (trust-based — fulfill in real life!)"
