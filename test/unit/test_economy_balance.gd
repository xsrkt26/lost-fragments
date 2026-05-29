extends GutTest

const EconomyConfigScript = preload("res://src/core/rewards/economy_config.gd")
const RewardGeneratorScript = preload("res://src/core/rewards/reward_generator.gd")
const RunManagerScript = preload("res://src/autoload/run_manager.gd")
const ShopGeneratorScript = preload("res://src/core/rewards/shop_generator.gd")

var item_db
var ornament_db


func before_each():
	EconomyConfigScript.clear_cache_for_tests()
	item_db = get_node_or_null("/root/ItemDatabase")
	ornament_db = get_node_or_null("/root/OrnamentDatabase")
	if item_db and item_db.items.is_empty():
		item_db.load_all_items()
	if ornament_db and ornament_db.ornaments.is_empty():
		ornament_db.load_all_ornaments()


func _make_run_manager(act: int, route_index: int):
	var rm = autofree(RunManagerScript.new())
	rm.current_act = act
	rm.current_route_index = route_index
	rm.current_ornaments = [] as Array[String]
	rm.current_deck = [] as Array[String]
	rm.current_backpack_items = [] as Array[Dictionary]
	rm.is_run_active = true
	return rm


func test_economy_snapshot_matches_current_balance_targets():
	var expected = [
		{"act": 1, "normal": 8, "boss": 18, "route": 34, "normal_nodes": 2, "elite_nodes": 0, "boss_nodes": 1, "refresh": 7, "item_pct": 100, "common_pct": 100, "advanced_pct": 108, "rare_pct": 115},
		{"act": 2, "normal": 10, "boss": 22, "route": 42, "normal_nodes": 2, "elite_nodes": 0, "boss_nodes": 1, "refresh": 9, "item_pct": 107, "common_pct": 109, "advanced_pct": 117, "rare_pct": 124},
		{"act": 3, "normal": 12, "boss": 26, "route": 50, "normal_nodes": 2, "elite_nodes": 0, "boss_nodes": 1, "refresh": 11, "item_pct": 114, "common_pct": 118, "advanced_pct": 126, "rare_pct": 133},
		{"act": 4, "normal": 14, "boss": 30, "route": 58, "normal_nodes": 2, "elite_nodes": 0, "boss_nodes": 1, "refresh": 13, "item_pct": 121, "common_pct": 127, "advanced_pct": 135, "rare_pct": 142},
		{"act": 5, "normal": 16, "boss": 34, "route": 66, "normal_nodes": 2, "elite_nodes": 0, "boss_nodes": 1, "refresh": 15, "item_pct": 128, "common_pct": 136, "advanced_pct": 144, "rare_pct": 151},
		{"act": 6, "normal": 18, "boss": 38, "route": 74, "normal_nodes": 2, "elite_nodes": 0, "boss_nodes": 1, "refresh": 17, "item_pct": 135, "common_pct": 145, "advanced_pct": 153, "rare_pct": 160},
	]

	for row in expected:
		var snapshot = EconomyConfigScript.act_economy_snapshot(row.act)
		assert_eq(snapshot.normal_battle_shards, row.normal)
		assert_eq(snapshot.boss_battle_shards, row.boss)
		assert_eq(snapshot.route_battle_shards, row.route)
		assert_eq(snapshot.route_normal_battle_nodes, row.normal_nodes)
		assert_eq(snapshot.route_elite_battle_nodes, row.elite_nodes)
		assert_eq(snapshot.route_boss_battle_nodes, row.boss_nodes)
		assert_eq(snapshot.first_refresh_cost, row.refresh)
		assert_eq(snapshot.item_price_multiplier_percent, row.item_pct)
		assert_eq(snapshot.common_ornament_price_multiplier_percent, row.common_pct)
		assert_eq(snapshot.advanced_ornament_price_multiplier_percent, row.advanced_pct)
		assert_eq(snapshot.rare_ornament_price_multiplier_percent, row.rare_pct)


func test_economy_config_uses_json_and_fallback_defaults():
	var config = EconomyConfigScript.load_config_from_path()
	assert_eq(int(config.battle_rewards.normal_base), 8)
	assert_eq(int(config.shop.item_price_act_step_percent), 7)

	var fallback = EconomyConfigScript.load_config_from_path("res://missing/economy.json")
	assert_eq(int(fallback.battle_rewards.normal_base), EconomyConfigScript.NORMAL_BATTLE_SHARDS_BASE)
	assert_eq(int(fallback.shop.refresh_base_cost), EconomyConfigScript.SHOP_REFRESH_BASE_COST)

func test_economy_config_cache_returns_defensive_copies():
	var config = EconomyConfigScript.load_config_from_path()
	config.battle_rewards.normal_base = 999

	var cached_config = EconomyConfigScript.load_config_from_path()
	assert_eq(int(cached_config.battle_rewards.normal_base), 8)


func test_reward_shards_use_economy_config_for_normal_and_boss_nodes():
	var normal_run = _make_run_manager(3, 0)
	var boss_run = _make_run_manager(3, 6)

	var normal_reward = RewardGeneratorScript.generate_options(normal_run, null, null, 1)[0]
	var boss_reward = RewardGeneratorScript.generate_options(boss_run, null, null, 1)[0]

	assert_eq(normal_reward.amount, EconomyConfigScript.battle_reward_shards(3, false))
	assert_eq(boss_reward.amount, EconomyConfigScript.battle_reward_shards(3, true))
	assert_true(int(boss_reward.amount) > int(normal_reward.amount))


func test_shop_prices_and_refresh_use_economy_config():
	var cheap_item = item_db.get_item_by_id("paper_ball")
	var expensive_item = item_db.get_item_by_id("rusty_gear")
	var common_ornament = ornament_db.get_ornament_by_id("dreamcatcher_filter")
	var rare_ornament = ornament_db.get_ornament_by_id("terminal_pressure_gauge")

	assert_eq(ShopGeneratorScript._calculate_item_price(cheap_item, 1), 5)
	assert_eq(ShopGeneratorScript._calculate_item_price(cheap_item, 6), 7)
	assert_eq(ShopGeneratorScript._calculate_item_price(expensive_item, 6), 41)
	assert_eq(ShopGeneratorScript._calculate_ornament_price(common_ornament, 6), 58)
	assert_eq(ShopGeneratorScript._calculate_ornament_price(rare_ornament, 6), 256)
	assert_eq(ShopGeneratorScript.calculate_refresh_cost(4, 2), EconomyConfigScript.shop_refresh_cost(4, 2))


func test_purchase_power_ranges_stay_reasonable_across_acts():
	for act in range(1, 7):
		var snapshot = EconomyConfigScript.act_economy_snapshot(act)
		var cheap_item_price = EconomyConfigScript.shop_item_price(5, act)
		var expensive_item_price = EconomyConfigScript.shop_item_price(30, act)
		var cheapest_common_ornament_price = EconomyConfigScript.shop_ornament_price(40, EconomyConfigScript.RARITY_COMMON, act)

		assert_true(cheap_item_price <= int(snapshot.normal_battle_shards))
		assert_true(expensive_item_price <= int(snapshot.route_battle_shards))
		assert_true(cheapest_common_ornament_price <= int(snapshot.route_battle_shards) + RunManagerScript.INITIAL_SHARDS)
		assert_true(int(snapshot.boss_battle_shards) >= int(snapshot.normal_battle_shards) * 2)
