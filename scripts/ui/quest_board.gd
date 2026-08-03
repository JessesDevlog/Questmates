extends Control

@onready var quest_list: ItemList = %QuestList
@onready var title_input: LineEdit = %TitleInput
@onready var coin_input: LineEdit = %CoinInput
@onready var spirit_penalty_input: LineEdit = %SpiritPenaltyInput
@onready var status_label: Label = %StatusLabel


func _ready() -> void:
	%BackButton.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/world/town.tscn"))
	%CreateButton.pressed.connect(_create_quest)
	%AcceptButton.pressed.connect(_accept_selected)
	%SubmitButton.pressed.connect(_submit_selected)
	%ApproveButton.pressed.connect(_approve_selected)
	QuestService.quests_updated.connect(_on_quests_updated)
	QuestService.fetch_quests()


func _on_quests_updated(quests: Array) -> void:
	quest_list.clear()
	for quest_variant in quests:
		if typeof(quest_variant) != TYPE_DICTIONARY:
			continue
		var quest: Dictionary = quest_variant
		var line := "%s | %s | %d coins | spirit -%d" % [
			quest.get("title", ""),
			quest.get("status", ""),
			int(quest.get("coin_reward", 0)),
			int(quest.get("spirit_penalty", 0)),
		]
		quest_list.add_item(line)


func _get_selected_quest_id() -> String:
	var idx := quest_list.get_selected_items()
	if idx.is_empty():
		return ""
	var quests: Array = QuestService.get_quests()
	if idx[0] >= quests.size():
		return ""
	var quest_variant: Variant = quests[idx[0]]
	if typeof(quest_variant) != TYPE_DICTIONARY:
		return ""
	return String(quest_variant.get("id", ""))


func _create_quest() -> void:
	var deadline_unix := Time.get_unix_time_from_system() + 86400
	var deadline := Time.get_datetime_string_from_unix_time(deadline_unix, true)
	var payload := {
		"title": title_input.text,
		"description": "",
		"coin_reward": int(coin_input.text if coin_input.text.is_valid_int() else "5"),
		"xp_reward": 5,
		"spirit_penalty": int(spirit_penalty_input.text if spirit_penalty_input.text.is_valid_int() else "10"),
		"deadline_at": deadline,
	}
	var partner_id := String(GameState.partner_profile.get("id", ""))
	if not partner_id.is_empty():
		payload["assignee_profile_id"] = partner_id
	QuestService.create_quest(payload)
	status_label.text = "Quest created"


func _accept_selected() -> void:
	var id := _get_selected_quest_id()
	if id.is_empty():
		return
	QuestService.accept_quest(id)


func _submit_selected() -> void:
	var id := _get_selected_quest_id()
	if id.is_empty():
		return
	QuestService.submit_quest(id)


func _approve_selected() -> void:
	var id := _get_selected_quest_id()
	if id.is_empty():
		return
	QuestService.approve_quest(id)
