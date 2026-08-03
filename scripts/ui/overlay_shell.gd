extends Control

## Dim backdrop + soft card. Card fills available space; content scrolls inside.


func mount_content(content: Control) -> void:
	var slot: Control = %ContentSlot
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	slot.add_child(content)
	call_deferred("_finish_mount")


func _ready() -> void:
	%DimBackdrop.gui_input.connect(_on_backdrop_input)
	_resize_card()
	if not DisplaySettings.orientation_changed.is_connected(_on_orientation_changed):
		DisplaySettings.orientation_changed.connect(_on_orientation_changed)


func _on_orientation_changed(_is_landscape: bool) -> void:
	_resize_card()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_resize_card()


func _finish_mount() -> void:
	_resize_card()
	var scroll: ScrollContainer = %Scroll
	if scroll:
		scroll.scroll_vertical = 0
	_refresh_content_min_height()


func _refresh_content_min_height() -> void:
	var slot: Control = %ContentSlot
	if slot == null or slot.get_child_count() == 0:
		return
	var content: Control = slot.get_child(0) as Control
	if content == null:
		return
	var vbox: Control = content.find_child("VBox", true, false) as Control
	if vbox == null:
		return
	var min_h: float = vbox.get_combined_minimum_size().y
	if min_h > 1.0:
		content.custom_minimum_size = Vector2(maxf(content.custom_minimum_size.x, 280.0), min_h)


func _resize_card() -> void:
	var card: Control = %Card
	if card == null:
		return
	var viewport_size: Vector2 = get_viewport_rect().size
	var card_width: float = clampf(viewport_size.x - 32.0, 300.0, 720.0)
	var card_height: float = clampf(viewport_size.y - 140.0, 280.0, 640.0)
	card.custom_minimum_size = Vector2(card_width, card_height)
	card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	card.size_flags_vertical = Control.SIZE_SHRINK_CENTER


func _on_backdrop_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		pass
