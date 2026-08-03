extends RefCounted
class_name OverlayContentHelper

## Prepares town overlay roots for OverlayShell (fit + scroll).
## Do not assign Control.layout_mode from GDScript — Godot 4.6 rejects
## integer/enum assignments that .tscn files still use internally.


static func prepare_overlay_content(root: Control) -> void:
	var bg: Node = root.get_node_or_null("Background")
	if bg is CanvasItem:
		bg.visible = false

	_unwrap_nested_scrolls(root)
	_fix_item_lists(root)
	_wrap_bare_node3ds(root)

	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical = Control.SIZE_SHRINK_BEGIN

	var vbox: Control = null
	if root is MarginContainer and root.get_child_count() > 0:
		vbox = root.get_child(0) as Control
	elif root is VBoxContainer:
		vbox = root
	else:
		# Plain Control: keep Margin full-rect so children remain visible.
		var margin: Control = root.get_node_or_null("Margin") as Control
		if margin:
			margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			vbox = margin.get_node_or_null("VBox") as Control
		if vbox == null:
			vbox = root.find_child("VBox", true, false) as Control

	var min_h: float = 1.0
	if vbox:
		vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		vbox.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		min_h = maxf(vbox.get_combined_minimum_size().y, 1.0)
	root.custom_minimum_size = Vector2(maxf(root.custom_minimum_size.x, 280.0), min_h)


static func _unwrap_nested_scrolls(node: Node) -> void:
	for child in node.get_children():
		_unwrap_nested_scrolls(child)
	if not (node is ScrollContainer):
		return
	var parent: Node = node.get_parent()
	if parent == null:
		return
	var insert_at: int = node.get_index()
	var moved: Array = node.get_children()
	for grandchild in moved:
		node.remove_child(grandchild)
		parent.add_child(grandchild)
		parent.move_child(grandchild, insert_at)
		insert_at += 1
	parent.remove_child(node)
	node.queue_free()


static func _fix_item_lists(node: Node) -> void:
	for child in node.get_children():
		if child is ItemList:
			var list: ItemList = child
			list.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
			if list.custom_minimum_size.y < 96.0:
				list.custom_minimum_size.y = 96.0
		_fix_item_lists(child)


static func _wrap_bare_node3ds(node: Node) -> void:
	for child in node.get_children():
		_wrap_bare_node3ds(child)
		if not (child is Node3D):
			continue
		var node_3d: Node3D = child
		var parent: Node = node_3d.get_parent()
		if parent == null or parent is SubViewportContainer:
			continue
		if String(parent.name).ends_with("PreviewSlot"):
			continue
		if not (parent is VBoxContainer or parent is HBoxContainer):
			continue
		var slot := Control.new()
		slot.name = "%sPreviewSlot" % node_3d.name
		slot.custom_minimum_size = Vector2(0, 160)
		slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slot.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		var index: int = node_3d.get_index()
		parent.add_child(slot)
		parent.move_child(slot, index)
		parent.remove_child(node_3d)
		slot.add_child(node_3d)
