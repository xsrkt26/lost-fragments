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
		{"act": 1, "normal": 6, "boss": 12, "route": 24, "normal_nodes": 2, "elite_nodes": 0, "boss_nodes": 1, "refresh": 5, "item_pct": 100, "common_pct": 100, "advanced_pct": 100, "rare_pct": 100},
		{"act": 2, "normal": 7, "boss": 14, "route": 28, "normal_nodes": 2, "elite_nodes": 0, "boss_nodes": 1, "refresh": 6, "item_pct": 100, "common_pct": 100, "advanced_pct": 100, "rare_pct": 100},
		{"act": 3, "normal": 8, "boss": 16, "route": 32, "normal_nodes": 2, "elite_nodes": 0, "boss_nodes": 1, "refresh": 7, "item_pct": 100, "common_pct": 100, "advanced_pct": 100, "rare_pct": 100},
		{"act": 4, "normal": 9, "boss": 18, "route": 36, "normal_nodes": 2, "elite_nodes": 0, "boss_nodes": 1, "refresh": 8, "item_pct": 100, "common_pct": 100, "advanced_pct": 100, "rare_pct": 100},
		{"act": 5, "normal": 10, "boss": 20, "route": 40, "normal_nodes": 2, "elite_nodes": 0, "boss_nodes": 1, "refresh": 9, "item_pct": 100, "common_pct": 100, "advanced_pct": 100, "rare_pct": 100},
		{"act": 6, "normal": 11, "boss": 22, "route": 44, "normal_nodes": 2, "elite_nodes": 0, "boss_nodes": 1, "refresh": 10, "item_pct": 100, "common_pct": 100, "advanced_pct": 100, "rare_pct": 100},
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
	assert_eq(int(config.battle_rewards.normal_base), 6)
	assert_eq(int(config.shop.item_price_act_step_percent), 0)

	var fallback = EconomyConfigScript.load_config_from_path("res://missing/economy.json")
	assert_eq(int(fallback.battle_rewards.normal_base), EconomyConfigScript.NORMAL_BATTLE_SHARDS_BASE)
	assert_eq(int(fallback.shop.refresh_base_cost), EconomyConfigScript.SHOP_REFRESH_BASE_COST)

func test_economy_config_cache_returns_defensive_copies():
	var config = EconomyConfigScript.load_config_from_path()
	config.battle_rewards.normal_base = 999

	var cached_config = EconomyConfigScript.load_config_from_path()
	assert_eq(int(cached_config.battle_rewards.normal_base), 6)


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

	assert_eq(ShopGeneratorScript._calculate_item_price(cheap_item, 1), 10)
	assert_eq(ShopGeneratorScript._calculate_item_price(cheap_item, 6), 10)
	assert_eq(ShopGeneratorScript._calculate_item_price(expensive_item, 6), 22)
	assert_eq(ShopGeneratorScript._calculate_ornament_price(common_ornament, 6), 36)
	assert_eq(ShopGeneratorScript._calculate_ornament_price(rare_ornament, 6), 110)
	assert_eq(ShopGeneratorScript.calculate_refresh_cost(4, 2), EconomyConfigScript.shop_refresh_cost(4, 2))


func test_item_sell_values_follow_half_buy_price_rule_across_acts():
	for act in range(1, 7):
		var one_cell_buy_price = EconomyConfigScript.shop_item_price(8, act)
		var one_cell_sell_value = EconomyConfigScript.shop_item_sell_value(8, act)
		var half_bag_sell_income = one_cell_sell_value * 14
		var common_ornament_baseline = EconomyConfigScript.shop_ornament_price(38, EconomyConfigScript.RARITY_COMMON, act)

		assert_eq(one_cell_buy_price, 8)
		assert_eq(one_cell_sell_value, 4)
		assert_eq(EconomyConfigScript.shop_item_sell_value(10, act), 5)
		assert_true(abs(half_bag_sell_income - roundi(float(common_ornament_baseline) * 1.5)) <= 2)
