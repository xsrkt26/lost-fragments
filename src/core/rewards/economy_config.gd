class_name EconomyConfig
extends RefCounted

const MIN_ACT := 1
const MAX_ACT := 6
const ECONOMY_CONFIG_PATH := "res://data/economy/economy.json"
const RouteConfig = preload("res://src/core/route/route_config.gd")
const StageConfig = preload("res://src/core/stage/stage_config.gd")

const NORMAL_BATTLE_SHARDS_BASE := 8
const NORMAL_BATTLE_SHARDS_PER_ACT := 2
const BOSS_BATTLE_SHARDS_BASE := 18
const BOSS_BATTLE_SHARDS_PER_ACT := 4

const SHOP_REFRESH_BASE_COST := 5
const SHOP_REFRESH_ACT_STEP := 2
const SHOP_REFRESH_REPEAT_STEP := 3

const ITEM_PRICE_ACT_STEP_PERCENT := 7
const ORNAMENT_PRICE_ACT_STEP_PERCENT := 9
const ORNAMENT_ADVANCED_SURCHARGE_PERCENT := 8
const ORNAMENT_RARE_SURCHARGE_PERCENT := 15

const RARITY_COMMON := "普通"
const RARITY_ADVANCED := "进阶"
const RARITY_RARE := "稀有"

const DEFAULT_CONFIG := {
	"version": 1,
	"acts": {
		"min": MIN_ACT,
		"max": MAX_ACT,
	},
	"battle_rewards": {
		"normal_base": NORMAL_BATTLE_SHARDS_BASE,
		"normal_per_act": NORMAL_BATTLE_SHARDS_PER_ACT,
		"boss_base": BOSS_BATTLE_SHARDS_BASE,
		"boss_per_act": BOSS_BATTLE_SHARDS_PER_ACT,
	},
	"shop": {
		"refresh_base_cost": SHOP_REFRESH_BASE_COST,
		"refresh_act_step": SHOP_REFRESH_ACT_STEP,
		"refresh_repeat_step": SHOP_REFRESH_REPEAT_STEP,
		"item_price_act_step_percent": ITEM_PRICE_ACT_STEP_PERCENT,
		"ornament_price_act_step_percent": ORNAMENT_PRICE_ACT_STEP_PERCENT,
		"ornament_advanced_surcharge_percent": ORNAMENT_ADVANCED_SURCHARGE_PERCENT,
		"ornament_rare_surcharge_percent": ORNAMENT_RARE_SURCHARGE_PERCENT,
	},
}


static func battle_reward_shards(act: int, is_boss: bool) -> int:
	var config = load_config_from_path()
	var rewards = _section(config, "battle_rewards")
	var clamped_act = _clamp_act_for_config(act, config)
	if is_boss:
		return int(rewards.get("boss_base", BOSS_BATTLE_SHARDS_BASE)) + (clamped_act - 1) * int(rewards.get("boss_per_act", BOSS_BATTLE_SHARDS_PER_ACT))
	return int(rewards.get("normal_base", NORMAL_BATTLE_SHARDS_BASE)) + (clamped_act - 1) * int(rewards.get("normal_per_act", NORMAL_BATTLE_SHARDS_PER_ACT))


static func shop_refresh_cost(act: int, refresh_count: int) -> int:
	var config = load_config_from_path()
	var shop = _section(config, "shop")
	return max(1,
		int(shop.get("refresh_base_cost", SHOP_REFRESH_BASE_COST))
		+ _clamp_act_for_config(act, config) * int(shop.get("refresh_act_step", SHOP_REFRESH_ACT_STEP))
		+ max(0, refresh_count) * int(shop.get("refresh_repeat_step", SHOP_REFRESH_REPEAT_STEP))
	)


static func shop_item_price(base_price: int, act: int) -> int:
	var sanitized_price = max(1, abs(base_price))
	return _apply_percent(sanitized_price, shop_item_price_multiplier_percent(act))


static func shop_ornament_price(base_price: int, rarity: String, act: int) -> int:
	var sanitized_price = max(1, base_price)
	return _apply_percent(sanitized_price, shop_ornament_price_multiplier_percent(rarity, act))


static func shop_item_price_multiplier_percent(act: int) -> int:
	var config = load_config_from_path()
	var shop = _section(config, "shop")
	return 100 + (_clamp_act_for_config(act, config) - 1) * int(shop.get("item_price_act_step_percent", ITEM_PRICE_ACT_STEP_PERCENT))


static func shop_ornament_price_multiplier_percent(rarity: String, act: int) -> int:
	var config = load_config_from_path()
	var shop = _section(config, "shop")
	return 100 + (_clamp_act_for_config(act, config) - 1) * int(shop.get("ornament_price_act_step_percent", ORNAMENT_PRICE_ACT_STEP_PERCENT)) + _ornament_rarity_surcharge_percent(rarity, config)


static func act_economy_snapshot(act: int) -> Dictionary:
	var config = load_config_from_path()
	var clamped_act = _clamp_act_for_config(act, config)
	var normal_shards = battle_reward_shards(clamped_act, false)
	var boss_shards = battle_reward_shards(clamped_act, true)
	var route_summary = _route_battle_reward_summary(clamped_act)
	return {
		"act": clamped_act,
		"normal_battle_shards": normal_shards,
		"boss_battle_shards": boss_shards,
		"route_battle_shards": int(route_summary.get("route_battle_shards", normal_shards * 2 + boss_shards)),
		"route_normal_battle_nodes": int(route_summary.get("normal_battle_nodes", 2)),
		"route_elite_battle_nodes": int(route_summary.get("elite_battle_nodes", 0)),
		"route_boss_battle_nodes": int(route_summary.get("boss_battle_nodes", 1)),
		"first_refresh_cost": shop_refresh_cost(clamped_act, 0),
		"item_price_multiplier_percent": shop_item_price_multiplier_percent(clamped_act),
		"common_ornament_price_multiplier_percent": shop_ornament_price_multiplier_percent(RARITY_COMMON, clamped_act),
		"advanced_ornament_price_multiplier_percent": shop_ornament_price_multiplier_percent(RARITY_ADVANCED, clamped_act),
		"rare_ornament_price_multiplier_percent": shop_ornament_price_multiplier_percent(RARITY_RARE, clamped_act),
	}


static func load_config_from_path(path: String = ECONOMY_CONFIG_PATH) -> Dictionary:
	var config = DEFAULT_CONFIG.duplicate(true)
	if path == "" or not FileAccess.file_exists(path):
		return config
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return config
	var parsed = JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary):
		return config
	return _normalize_config(parsed)


static func _normalize_config(raw: Dictionary) -> Dictionary:
	var config = DEFAULT_CONFIG.duplicate(true)
	for section_name in ["acts", "battle_rewards", "shop"]:
		var defaults = _section(DEFAULT_CONFIG, section_name)
		var raw_section = _section(raw, section_name)
		var merged = defaults.duplicate(true)
		for key in raw_section.keys():
			merged[key] = raw_section[key]
		config[section_name] = merged
	return config


static func _route_battle_reward_summary(act: int) -> Dictionary:
	var route_id = StageConfig.get_route_id_for_act(act, RouteConfig.DEFAULT_ROUTE_ID)
	var normal_count := 0
	var elite_count := 0
	var boss_count := 0
	var route_shards := 0
	for node in RouteConfig.get_route_nodes(route_id):
		var node_type = str(node.get("type", ""))
		if not RouteConfig.is_battle_node_type(node_type):
			continue
		var is_boss = RouteConfig.is_boss_node_type(node_type)
		route_shards += battle_reward_shards(act, is_boss)
		if is_boss:
			boss_count += 1
		elif node_type == RouteConfig.NODE_ELITE_BATTLE:
			elite_count += 1
		else:
			normal_count += 1
	return {
		"route_battle_shards": route_shards,
		"normal_battle_nodes": normal_count,
		"elite_battle_nodes": elite_count,
		"boss_battle_nodes": boss_count,
	}


static func _section(config: Dictionary, section_name: String) -> Dictionary:
	var value = config.get(section_name, {})
	if value is Dictionary:
		return Dictionary(value)
	return {}


static func _clamp_act_for_config(act: int, config: Dictionary) -> int:
	var acts = _section(config, "acts")
	var min_act = int(acts.get("min", MIN_ACT))
	var max_act = max(min_act, int(acts.get("max", MAX_ACT)))
	return clamp(act, min_act, max_act)


static func _apply_percent(base_price: int, multiplier_percent: int) -> int:
	return max(1, roundi(float(base_price) * float(multiplier_percent) / 100.0))


static func _ornament_rarity_surcharge_percent(rarity: String, config: Dictionary) -> int:
	var shop = _section(config, "shop")
	match rarity:
		RARITY_ADVANCED:
			return int(shop.get("ornament_advanced_surcharge_percent", ORNAMENT_ADVANCED_SURCHARGE_PERCENT))
		RARITY_RARE:
			return int(shop.get("ornament_rare_surcharge_percent", ORNAMENT_RARE_SURCHARGE_PERCENT))
	return 0
