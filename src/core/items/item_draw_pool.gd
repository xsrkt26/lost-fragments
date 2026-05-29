class_name ItemDrawPool
extends RefCounted

const CATEGORY_GENERAL := "general"
const CATEGORY_POLLUTION := "pollution"
const CATEGORY_DREAM_SEED := "dream_seed"
const CATEGORY_MECHANICAL := "mechanical"

const ROLE_STARTER := "starter"
const ROLE_CORE := "core"
const ROLE_LATE := "late"

const DEFAULT_DECK_SIZE := 60

const CATEGORY_WEIGHTS := {
	1: {CATEGORY_GENERAL: 100.0, CATEGORY_POLLUTION: 0.0, CATEGORY_DREAM_SEED: 0.0, CATEGORY_MECHANICAL: 0.0},
	2: {CATEGORY_GENERAL: 40.0, CATEGORY_POLLUTION: 20.0, CATEGORY_DREAM_SEED: 20.0, CATEGORY_MECHANICAL: 20.0},
	3: {CATEGORY_GENERAL: 28.0, CATEGORY_POLLUTION: 24.0, CATEGORY_DREAM_SEED: 24.0, CATEGORY_MECHANICAL: 24.0},
	4: {CATEGORY_GENERAL: 22.0, CATEGORY_POLLUTION: 26.0, CATEGORY_DREAM_SEED: 26.0, CATEGORY_MECHANICAL: 26.0},
	5: {CATEGORY_GENERAL: 18.0, CATEGORY_POLLUTION: 27.33, CATEGORY_DREAM_SEED: 27.33, CATEGORY_MECHANICAL: 27.33},
	6: {CATEGORY_GENERAL: 15.0, CATEGORY_POLLUTION: 28.33, CATEGORY_DREAM_SEED: 28.33, CATEGORY_MECHANICAL: 28.33},
}

const ROLE_WEIGHTS := {
	2: {ROLE_STARTER: 70.0, ROLE_CORE: 30.0, ROLE_LATE: 0.0},
	3: {ROLE_STARTER: 45.0, ROLE_CORE: 45.0, ROLE_LATE: 10.0},
	4: {ROLE_STARTER: 30.0, ROLE_CORE: 45.0, ROLE_LATE: 25.0},
	5: {ROLE_STARTER: 25.0, ROLE_CORE: 40.0, ROLE_LATE: 35.0},
	6: {ROLE_STARTER: 20.0, ROLE_CORE: 40.0, ROLE_LATE: 40.0},
}

const ITEM_RULES := {
	"baseball": {"category": CATEGORY_GENERAL, "unlock_act": 1, "role": ROLE_STARTER},
	"alarm_clock": {"category": CATEGORY_GENERAL, "unlock_act": 1, "role": ROLE_STARTER},
	"tin_can": {"category": CATEGORY_GENERAL, "unlock_act": 1, "role": ROLE_STARTER},
	"mineral_water_bottle": {"category": CATEGORY_GENERAL, "unlock_act": 1, "role": ROLE_STARTER},
	"apple": {"category": CATEGORY_GENERAL, "unlock_act": 1, "role": ROLE_STARTER},
	"cracked_lens": {"category": CATEGORY_GENERAL, "unlock_act": 2, "role": ROLE_STARTER},
	"gift_box": {"category": CATEGORY_GENERAL, "unlock_act": 2, "role": ROLE_CORE},
	"roast_chicken": {"category": CATEGORY_GENERAL, "unlock_act": 3, "role": ROLE_CORE},
	"insurance_contract": {"category": CATEGORY_GENERAL, "unlock_act": 4, "role": ROLE_LATE},

	"paper_ball": {"category": CATEGORY_POLLUTION, "unlock_act": 2, "role": ROLE_STARTER},
	"joker": {"category": CATEGORY_POLLUTION, "unlock_act": 2, "role": ROLE_STARTER},
	"sticky_note": {"category": CATEGORY_POLLUTION, "unlock_act": 2, "role": ROLE_CORE},
	"leaky_pen": {"category": CATEGORY_POLLUTION, "unlock_act": 2, "role": ROLE_STARTER},
	"sad_teddy_bear": {"category": CATEGORY_POLLUTION, "unlock_act": 3, "role": ROLE_CORE},
	"pill_bottle": {"category": CATEGORY_POLLUTION, "unlock_act": 3, "role": ROLE_CORE},
	"trash_bag": {"category": CATEGORY_POLLUTION, "unlock_act": 3, "role": ROLE_CORE},
	"old_soccer_ball": {"category": CATEGORY_POLLUTION, "unlock_act": 3, "role": ROLE_STARTER},
	"expired_medicine": {"category": CATEGORY_POLLUTION, "unlock_act": 4, "role": ROLE_CORE},
	"syringe": {"category": CATEGORY_POLLUTION, "unlock_act": 4, "role": ROLE_CORE},
	"leftover_box": {"category": CATEGORY_POLLUTION, "unlock_act": 4, "role": ROLE_CORE},
	"wet_cardboard_box": {"category": CATEGORY_POLLUTION, "unlock_act": 4, "role": ROLE_CORE},
	"trash_recycler": {"category": CATEGORY_POLLUTION, "unlock_act": 5, "role": ROLE_LATE},
	"rusty_gear": {"category": CATEGORY_POLLUTION, "unlock_act": 5, "role": ROLE_LATE},

	"iron_ball": {"category": CATEGORY_MECHANICAL, "unlock_act": 2, "role": ROLE_STARTER},
	"small_gear": {"category": CATEGORY_MECHANICAL, "unlock_act": 2, "role": ROLE_STARTER},
	"transmission_belt": {"category": CATEGORY_MECHANICAL, "unlock_act": 2, "role": ROLE_CORE},
	"left_transmission_elbow": {"category": CATEGORY_MECHANICAL, "unlock_act": 3, "role": ROLE_CORE},
	"right_transmission_elbow": {"category": CATEGORY_MECHANICAL, "unlock_act": 3, "role": ROLE_CORE},
	"brake_pad": {"category": CATEGORY_MECHANICAL, "unlock_act": 3, "role": ROLE_STARTER},
	"gear_rack": {"category": CATEGORY_MECHANICAL, "unlock_act": 3, "role": ROLE_CORE},
	"differential": {"category": CATEGORY_MECHANICAL, "unlock_act": 4, "role": ROLE_CORE},
	"dual_axis_wheel": {"category": CATEGORY_MECHANICAL, "unlock_act": 4, "role": ROLE_CORE},
	"energy_flywheel": {"category": CATEGORY_MECHANICAL, "unlock_act": 4, "role": ROLE_LATE},
	"crankshaft": {"category": CATEGORY_MECHANICAL, "unlock_act": 4, "role": ROLE_CORE},
	"counting_wheel": {"category": CATEGORY_MECHANICAL, "unlock_act": 4, "role": ROLE_CORE},
	"central_engine": {"category": CATEGORY_MECHANICAL, "unlock_act": 5, "role": ROLE_LATE},
	"terminal_computer": {"category": CATEGORY_MECHANICAL, "unlock_act": 5, "role": ROLE_LATE},
	"star_ring_bearing": {"category": CATEGORY_MECHANICAL, "unlock_act": 5, "role": ROLE_LATE},
}

static func build_deck(run_manager: Node, item_db: Node, draw_count: int = DEFAULT_DECK_SIZE) -> Array[String]:
	var deck: Array[String] = []
	for _i in range(max(0, draw_count)):
		var item_id := draw_item_id(run_manager, item_db)
		if item_id != "":
			deck.append(item_id)
	return deck

static func draw_item_id(run_manager: Node, item_db: Node) -> String:
	var act := _get_act(run_manager)
	var by_category := get_unlocked_items_by_category(item_db, act)
	var category_candidates := _build_category_candidates(act, by_category)
	var picked_category := _pick_weighted_key(category_candidates, run_manager)
	if picked_category == "":
		return ""

	var role_candidates := _build_role_candidates(act, Array(by_category.get(picked_category, [])))
	var picked_role := _pick_weighted_key(role_candidates, run_manager)
	if picked_role == "":
		return ""

	var item_candidates := _build_item_candidates(
		act,
		Array(by_category.get(picked_category, [])),
		picked_role,
		_get_owned_counts(run_manager)
	)
	return _pick_weighted_key(item_candidates, run_manager)

static func get_unlocked_items_by_category(item_db: Node, act: int) -> Dictionary:
	var result := {
		CATEGORY_GENERAL: [],
		CATEGORY_POLLUTION: [],
		CATEGORY_DREAM_SEED: [],
		CATEGORY_MECHANICAL: [],
	}
	if item_db == null or not item_db.has_method("get_item_by_id"):
		return result

	for item_id in ITEM_RULES.keys():
		var rule = ITEM_RULES[item_id]
		if int(rule.get("unlock_act", 1)) > act:
			continue
		var item = item_db.get_item_by_id(str(item_id))
		if item == null or not bool(item.can_draw):
			continue
		var category := str(rule.get("category", CATEGORY_GENERAL))
		if not result.has(category):
			result[category] = []
		result[category].append({
			"id": str(item_id),
			"role": str(rule.get("role", ROLE_STARTER)),
			"unlock_act": int(rule.get("unlock_act", 1)),
			"base_weight": float(rule.get("weight", 1.0)),
		})
	return result

static func get_item_rule(item_id: String) -> Dictionary:
	return Dictionary(ITEM_RULES.get(item_id, {})).duplicate(true)

static func get_category_weights(act: int) -> Dictionary:
	return Dictionary(CATEGORY_WEIGHTS.get(clamp(act, 1, 6), CATEGORY_WEIGHTS[6])).duplicate(true)

static func get_role_weights(act: int) -> Dictionary:
	if act <= 1:
		return {ROLE_STARTER: 100.0, ROLE_CORE: 0.0, ROLE_LATE: 0.0}
	return Dictionary(ROLE_WEIGHTS.get(clamp(act, 2, 6), ROLE_WEIGHTS[6])).duplicate(true)

static func _build_category_candidates(act: int, by_category: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var weights := get_category_weights(act)
	for category in [CATEGORY_GENERAL, CATEGORY_POLLUTION, CATEGORY_DREAM_SEED, CATEGORY_MECHANICAL]:
		var items := Array(by_category.get(category, []))
		if items.is_empty():
			continue
		var weight := float(weights.get(category, 0.0))
		if weight <= 0.0:
			continue
		result.append({"id": category, "weight": weight})
	return result

static func _build_role_candidates(act: int, category_items: Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var weights := get_role_weights(act)
	for role in [ROLE_STARTER, ROLE_CORE, ROLE_LATE]:
		if not _has_role_items(category_items, role):
			continue
		var weight := float(weights.get(role, 0.0))
		if weight <= 0.0:
			continue
		result.append({"id": role, "weight": weight})
	return result

static func _build_item_candidates(act: int, category_items: Array, role: String, owned_counts: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry in category_items:
		if not (entry is Dictionary) or str(entry.get("role", "")) != role:
			continue
		var item_id := str(entry.get("id", ""))
		var weight := float(entry.get("base_weight", 1.0))
		if int(entry.get("unlock_act", 1)) == act:
			weight *= 1.25
		weight *= _duplicate_modifier(int(owned_counts.get(item_id, 0)))
		result.append({"id": item_id, "weight": max(0.01, weight)})
	return result

static func _has_role_items(category_items: Array, role: String) -> bool:
	for entry in category_items:
		if entry is Dictionary and str(entry.get("role", "")) == role:
			return true
	return false

static func _duplicate_modifier(count: int) -> float:
	if count <= 0:
		return 1.0
	return max(0.4, pow(0.75, count))

static func _get_owned_counts(run_manager: Node) -> Dictionary:
	var counts := {}
	if run_manager == null:
		return counts
	for item_id in Array(run_manager.get("current_deck")):
		var key := str(item_id)
		counts[key] = int(counts.get(key, 0)) + 1
	for entry in Array(run_manager.get("current_backpack_items")):
		if not (entry is Dictionary):
			continue
		var key := str(entry.get("id", ""))
		if key == "":
			continue
		counts[key] = int(counts.get(key, 0)) + 1
	return counts

static func _pick_weighted_key(candidates: Array[Dictionary], run_manager: Node) -> String:
	if candidates.is_empty():
		return ""
	var total_weight := 0.0
	for candidate in candidates:
		total_weight += max(0.0, float(candidate.get("weight", 0.0)))
	if total_weight <= 0.0:
		return str(candidates[0].get("id", ""))

	var roll := _roll(run_manager) * total_weight
	var cursor := 0.0
	for candidate in candidates:
		cursor += max(0.0, float(candidate.get("weight", 0.0)))
		if roll <= cursor:
			return str(candidate.get("id", ""))
	return str(candidates[candidates.size() - 1].get("id", ""))

static func _roll(run_manager: Node) -> float:
	if run_manager != null and run_manager.has_method("random_float_for_run"):
		return float(run_manager.random_float_for_run(false))
	return randf()

static func _get_act(run_manager: Node) -> int:
	if run_manager == null:
		return 1
	return clamp(max(1, int(run_manager.get("current_act"))), 1, 6)
