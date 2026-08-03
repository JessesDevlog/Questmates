extends RefCounted
class_name CombatManager

var modifiers: Dictionary = {}
var card_uses_remaining: Dictionary = {}
var player_hp: Dictionary = {}
var enemy_states: Array = []


func setup(players: Array, enemies: Array, combat_modifiers: Dictionary) -> void:
	modifiers = combat_modifiers
	enemy_states = enemies.duplicate(true)
	for p in players:
		player_hp[p.get("profile_id", "")] = 10
	card_uses_remaining.clear()


func init_loadout(card_ids: Array) -> void:
	for card_id in card_ids:
		card_uses_remaining[card_id] = 1


func basic_attack(attacker_id: String, target_enemy_id: String) -> Dictionary:
	var mult := float(modifiers.get("player_damage_mult", 1.0))
	var damage := int(2 * mult)
	return _damage_enemy(target_enemy_id, damage, "basic_attack", attacker_id)


func play_card(attacker_id: String, card_id: String, target: Dictionary) -> Dictionary:
	if not card_uses_remaining.has(card_id) or card_uses_remaining[card_id] <= 0:
		return {"ok": false, "error": "Card already used this run"}

	var item: Dictionary = ItemCatalog.get_item(card_id)
	var meta_variant: Variant = item.get("metadata", {})
	var meta: Dictionary = meta_variant if meta_variant is Dictionary else {}
	var mult := float(modifiers.get("player_damage_mult", 1.0))
	card_uses_remaining[card_id] -= 1

	match meta.get("card_type", ""):
		"healing":
			var heal := int(meta.get("heal", 2))
			player_hp[attacker_id] = player_hp.get(attacker_id, 10) + heal
			return {"ok": true, "type": "heal", "amount": heal}
		"movement":
			return {"ok": true, "type": "move", "range": int(meta.get("range", 2))}
		_:
			var damage := int(meta.get("damage", 2) * mult)
			return _damage_enemy(target.get("enemy_id", ""), damage, "card", attacker_id)


func _damage_enemy(enemy_id: String, damage: int, source: String, attacker_id: String) -> Dictionary:
	for enemy in enemy_states:
		if enemy.get("id", "") == enemy_id:
			enemy["hp"] = int(enemy.get("hp", 1)) - damage
			return {
				"ok": true,
				"type": "damage",
				"damage": damage,
				"source": source,
				"attacker_id": attacker_id,
				"enemy_id": enemy_id,
				"enemy_hp": enemy["hp"],
			}
	return {"ok": false, "error": "Enemy not found"}


func all_enemies_defeated() -> bool:
	for enemy in enemy_states:
		if int(enemy.get("hp", 0)) > 0:
			return false
	return true
