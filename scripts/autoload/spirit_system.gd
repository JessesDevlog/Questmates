extends Node

## Spirit penalties and combat modifier helpers.

const DEFAULT_SPIRIT := 100
const MIN_SPIRIT := 0
const MAX_SPIRIT := 100


func clamp_spirit(value: int) -> int:
	return clampi(value, MIN_SPIRIT, MAX_SPIRIT)


func apply_penalty_on_open() -> void:
	if not GameState.is_online or GameState.household_id.is_empty():
		return
	QuestService.apply_missed_quest_penalties()


func restore_spirit(target_profile_id: String, amount: int, buyer_profile_id: String, cost: int) -> void:
	## Deprecated: use InventoryService.use_item with a potion from inventory instead.
	if not GameState.is_online:
		return
	SupabaseClient.call_rpc("restore_spirit", {
		"target_profile_id": target_profile_id,
		"buyer_profile_id": buyer_profile_id,
		"amount": amount,
		"cost": cost,
	})


func check_hardcore_reset(profile_spirit: int) -> void:
	if profile_spirit > 0:
		return
	if not GameState.household.get("hardcore_mode", false):
		return
	HardcoreService.reset_household()
