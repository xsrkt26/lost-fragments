class_name ToolDrawPool
extends RefCounted

const TOOL_ENTRY_PREFIX := "tool:"
const TOOL_DRAW_RATE := 0.15

const RARITY_COMMON := "道具"
const RARITY_UNCOMMON := "罕见道具"
const RARITY_RARE := "稀有道具"

const TOOL_RULES := {
	"small_patch": {"unlock_act": 1, "weight": 1.2},
	"dream_value_candy": {"unlock_act": 1, "weight": 1.1},
	"turning_screw": {"unlock_act": 1, "weight": 1.0},
	"cracked_marble": {"unlock_act": 1, "weight": 0.9},
	"black_ink_drop": {"unlock_act": 2, "weight": 1.0},
	"disinfectant_spray": {"unlock_act": 2, "weight": 0.9},
	"extension_hook": {"unlock_act": 2, "weight": 0.8},
	"apple_wax": {"unlock_act": 2, "weight": 0.8},
	"corrosive_acid": {"unlock_act": 3, "weight": 0.7},
	"transmission_oil": {"unlock_act": 3, "weight": 0.7},
	"recycling_clip": {"unlock_act": 3, "weight": 0.7},
	"blank_talisman": {"unlock_act": 4, "weight": 0.6},
}

static func make_tool_entry(tool_id: String) -> String:
	return TOOL_ENTRY_PREFIX + tool_id

static func is_tool_entry(entry: String) -> bool:
	return entry.begins_with(TOOL_ENTRY_PREFIX)

static func tool_id_from_entry(entry: String) -> String:
	if not is_tool_entry(entry):
		return ""
	return entry.substr(TOOL_ENTRY_PREFIX.length())

static func tools_enabled_for_route(run_manager: Node) -> bool:
	if run_manager == null:
		return false
	var act: int = max(1, int(run_manager.get("current_act")))
	var route_index: int = max(0, int(run_manager.get("current_route_index")))
	return act > 1 or route_index > 0

static func get_tool_rule(tool_id: String) -> Dictionary:
	return Dictionary(TOOL_RULES.get(tool_id, {})).duplicate(true)

static func get_available_tools(run_manager: Node, tool_db: Node) -> Array:
	var result: Array = []
	if tool_db == null or not tool_db.has_method("get_available_tools"):
		return result
	if not tools_enabled_for_route(run_manager):
		return result
	var act: int = max(1, int(run_manager.get("current_act"))) if run_manager != null else 1
	for tool in tool_db.get_available_tools(act):
		if tool == null:
			continue
		var rule := get_tool_rule(str(tool.id))
		if rule.is_empty():
			continue
		if int(rule.get("unlock_act", 1)) <= act:
			result.append(tool)
	return result

static func draw_tool_id(run_manager: Node, tool_db: Node) -> String:
	var candidates := _build_tool_candidates(run_manager, tool_db)
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

static func should_replace_draw_with_tool(run_manager: Node, tool_db: Node) -> bool:
	if get_available_tools(run_manager, tool_db).is_empty():
		return false
	return _roll(run_manager) < TOOL_DRAW_RATE

static func _build_tool_candidates(run_manager: Node, tool_db: Node) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var act: int = max(1, int(run_manager.get("current_act"))) if run_manager != null else 1
	for tool in get_available_tools(run_manager, tool_db):
		var rule := get_tool_rule(str(tool.id))
		var weight: float = float(rule.get("weight", 1.0))
		if int(rule.get("unlock_act", 1)) == act:
			weight *= 1.2
		weight *= _rarity_weight(str(tool.rarity))
		result.append({"id": str(tool.id), "weight": max(0.01, weight)})
	return result

static func _rarity_weight(rarity: String) -> float:
	match rarity:
		RARITY_COMMON:
			return 1.0
		RARITY_UNCOMMON:
			return 0.72
		RARITY_RARE:
			return 0.48
	return 0.8

static func _roll(run_manager: Node) -> float:
	if run_manager != null and run_manager.has_method("random_float_for_run"):
		return float(run_manager.random_float_for_run(false))
	return randf()
