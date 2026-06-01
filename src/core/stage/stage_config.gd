class_name StageConfig
extends RefCounted

const STAGE_DATA_PATH := "res://data/stages/stages.json"
const DEFAULT_STAGE_ID := "act_1"
const DEFAULT_MAX_ACT := 6
const FALLBACK_BOSS_SCORE_TARGETS := {
	1: 45,
	2: 65,
	3: 85,
	4: 110,
	5: 135,
	6: 165,
}

const DEFAULT_STAGE := {
	"id": DEFAULT_STAGE_ID,
	"name": "Stage 1",
	"route_id": "default",
	"visual": {
		"battle_bgm_key": "battle",
		"hub_bgm_key": "hub",
		"ui_tint": "#10151d",
	},
	"battle_modifiers": {
		"draw_cost_delta": 0,
		"pollution_added_bonus": 0,
		"blocked_cells": [],
	},
	"boss": {
		"mechanics": ["score_target"],
		"score_target": {"enabled": true, "value": 45},
	},
	"reward_weight_modifiers": {
		"types": {},
		"ids": {},
		"tags": {},
		"rarities": {},
	},
	"shop_weight_modifiers": {
		"types": {},
		"ids": {},
		"tags": {},
		"rarities": {},
	},
}

static var _stage_table_cache: Dictionary = {}

static func clear_cache_for_tests() -> void:
	_stage_table_cache.clear()

static func load_stage_table_from_path(path: String = STAGE_DATA_PATH) -> Dictionary:
	if _stage_table_cache.has(path):
		return Dictionary(_stage_table_cache[path]).duplicate(true)
	var table = _load_stage_table_uncached(path)
	_stage_table_cache[path] = table.duplicate(true)
	return table.duplicate(true)

static func _load_stage_table_uncached(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return _fallback_stage_table("[StageConfig] Missing stage table: " + path)

	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return _fallback_stage_table("[StageConfig] Failed to open stage table: " + path)

	var parser = JSON.new()
	if parser.parse(file.get_as_text()) != OK:
		return _fallback_stage_table("[StageConfig] Invalid stage table JSON %s: %s" % [path, parser.get_error_message()])
	var parsed = parser.data
	if not (parsed is Dictionary):
		return _fallback_stage_table("[StageConfig] Stage table root must be a dictionary: " + path)

	var normalized = _normalize_stage_table(parsed)
	if normalized.is_empty():
		return _fallback_stage_table("[StageConfig] Stage table contains no valid stages: " + path)
	return normalized

static func get_max_act(path: String = STAGE_DATA_PATH) -> int:
	return max(1, int(load_stage_table_from_path(path).get("max_act", DEFAULT_MAX_ACT)))

static func get_stage(act: int, path: String = STAGE_DATA_PATH) -> Dictionary:
	var table = load_stage_table_from_path(path)
	var stages = table.get("stages", {})
	if not (stages is Dictionary):
		return DEFAULT_STAGE.duplicate(true)
	var key = str(clampi(act, 1, int(table.get("max_act", DEFAULT_MAX_ACT))))
	if stages.has(key):
		return Dictionary(stages[key]).duplicate(true)
	var default_stage_id = str(table.get("default_stage_id", DEFAULT_STAGE_ID))
	for stage in stages.values():
		if stage is Dictionary and str(stage.get("id", "")) == default_stage_id:
			return Dictionary(stage).duplicate(true)
	return DEFAULT_STAGE.duplicate(true)

static func get_route_id_for_act(act: int, fallback_route_id: String = "default", path: String = STAGE_DATA_PATH) -> String:
	var route_id = str(get_stage(act, path).get("route_id", ""))
	return route_id if route_id != "" else fallback_route_id

static func get_visual(act: int, path: String = STAGE_DATA_PATH) -> Dictionary:
	return _dictionary_or_empty(get_stage(act, path).get("visual", {}))

static func get_battle_modifiers(act: int, path: String = STAGE_DATA_PATH) -> Dictionary:
	return _normalize_battle_modifiers(get_stage(act, path).get("battle_modifiers", {}))

static func get_boss_config(act: int, path: String = STAGE_DATA_PATH) -> Dictionary:
	return _dictionary_or_empty(get_stage(act, path).get("boss", {}))

static func get_boss_battle_modifiers(act: int, path: String = STAGE_DATA_PATH) -> Dictionary:
	return _normalize_battle_modifiers(get_boss_config(act, path).get("battle_modifiers", {}))

static func get_boss_score_target_rule(act: int, path: String = STAGE_DATA_PATH) -> Dictionary:
	var boss = get_boss_config(act, path)
	var score_target = boss.get("score_target", {})
	if not (score_target is Dictionary):
		return {"enabled": false, "target": -1}
	if not bool(score_target.get("enabled", false)):
		return {"enabled": false, "target": -1}
	if score_target.has("value"):
		return {"enabled": true, "target": max(0, int(score_target.get("value", 0)))}
	var base = int(score_target.get("base", 0))
	var act_multiplier = int(score_target.get("act_multiplier", 0))
	return {"enabled": true, "target": max(0, base + max(1, act) * act_multiplier)}

static func get_reward_weight_modifiers(act: int, path: String = STAGE_DATA_PATH) -> Dictionary:
	return _normalize_weight_modifiers(get_stage(act, path).get("reward_weight_modifiers", {}))

static func get_shop_weight_modifiers(act: int, path: String = STAGE_DATA_PATH) -> Dictionary:
	return _normalize_weight_modifiers(get_stage(act, path).get("shop_weight_modifiers", {}))

static func apply_weight_modifiers(base_weight: float, candidate_type: String, candidate_id: String, tags: Array, rarity: String, modifiers: Dictionary) -> float:
	var result = max(0.1, base_weight)
	result *= _multiplier_from_map(modifiers.get("types", {}), candidate_type)
	result *= _multiplier_from_map(modifiers.get("ids", {}), candidate_id)
	result *= _multiplier_from_map(modifiers.get("rarities", {}), rarity)
	var tag_modifiers = modifiers.get("tags", {})
	if tag_modifiers is Dictionary:
		for tag_value in tags:
			result *= _multiplier_from_map(tag_modifiers, str(tag_value))
	return max(0.1, result)

static func _fallback_stage_table(reason: String = "") -> Dictionary:
	if reason != "":
		push_warning(reason)
	var stages := {}
	for act in range(1, DEFAULT_MAX_ACT + 1):
		var stage = DEFAULT_STAGE.duplicate(true)
		stage["id"] = "act_%d" % act
		stage["name"] = "Stage %d" % act
		stage["boss"] = {
			"mechanics": ["score_target"],
			"score_target": {"enabled": true, "value": int(FALLBACK_BOSS_SCORE_TARGETS.get(act, 45 + (act - 1) * 20))},
		}
		stages[str(act)] = stage
	return {
		"version": 1,
		"max_act": DEFAULT_MAX_ACT,
		"default_stage_id": DEFAULT_STAGE_ID,
		"stages": stages,
	}

static func _normalize_stage_table(raw: Dictionary) -> Dictionary:
	var max_act = max(1, int(raw.get("max_act", DEFAULT_MAX_ACT)))
	var stages = _normalize_stages(raw.get("stages", {}), max_act)
	if stages.is_empty():
		return {}
	return {
		"version": int(raw.get("version", 1)),
		"max_act": max_act,
		"default_stage_id": str(raw.get("default_stage_id", DEFAULT_STAGE_ID)),
		"stages": stages,
	}

static func _normalize_stages(value: Variant, max_act: int) -> Dictionary:
	var result := {}
	if value is Dictionary:
		for key in value.keys():
			var act = int(key)
			if act < 1 or act > max_act:
				continue
			var normalized = _normalize_stage(value[key], act)
			if not normalized.is_empty():
				result[str(act)] = normalized
	elif value is Array:
		for stage_value in value:
			if not (stage_value is Dictionary):
				continue
			var act = int(stage_value.get("act", 0))
			if act < 1 or act > max_act:
				continue
			var normalized = _normalize_stage(stage_value, act)
			if not normalized.is_empty():
				result[str(act)] = normalized
	return result

static func _normalize_stage(value: Variant, act: int) -> Dictionary:
	if not (value is Dictionary):
		return {}
	var stage = DEFAULT_STAGE.duplicate(true)
	for key in value.keys():
		stage[key] = value[key]
	if str(stage.get("id", "")) == "":
		stage["id"] = "act_%d" % act
	if str(stage.get("name", "")) == "":
		stage["name"] = "Stage %d" % act
	stage["visual"] = _dictionary_or_empty(stage.get("visual", {}))
	stage["battle_modifiers"] = _normalize_battle_modifiers(stage.get("battle_modifiers", {}))
	stage["boss"] = _dictionary_or_empty(stage.get("boss", {}))
	stage["reward_weight_modifiers"] = _normalize_weight_modifiers(stage.get("reward_weight_modifiers", {}))
	stage["shop_weight_modifiers"] = _normalize_weight_modifiers(stage.get("shop_weight_modifiers", {}))
	return stage

static func _normalize_battle_modifiers(value: Variant) -> Dictionary:
	var modifiers = _dictionary_or_empty(value)
	modifiers["draw_cost_delta"] = int(modifiers.get("draw_cost_delta", 0))
	modifiers["pollution_added_bonus"] = int(modifiers.get("pollution_added_bonus", 0))
	if not (modifiers.get("blocked_cells", []) is Array):
		modifiers["blocked_cells"] = []
	else:
		modifiers["blocked_cells"] = Array(modifiers.get("blocked_cells", [])).duplicate(true)
	return modifiers

static func _normalize_weight_modifiers(value: Variant) -> Dictionary:
	var source = _dictionary_or_empty(value)
	return {
		"types": _dictionary_or_empty(source.get("types", {})),
		"ids": _dictionary_or_empty(source.get("ids", {})),
		"tags": _dictionary_or_empty(source.get("tags", {})),
		"rarities": _dictionary_or_empty(source.get("rarities", {})),
	}

static func _dictionary_or_empty(value: Variant) -> Dictionary:
	return Dictionary(value).duplicate(true) if value is Dictionary else {}

static func _multiplier_from_map(value: Variant, key: String) -> float:
	if key == "" or not (value is Dictionary) or not value.has(key):
		return 1.0
	return max(0.0, float(value.get(key, 1.0)))
