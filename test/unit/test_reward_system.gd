extends GutTest

const RewardGeneratorScript = preload("res://src/core/rewards/reward_generator.gd")
const RunManagerScript = preload("res://src/autoload/run_manager.gd")
const TOOL_ORNAMENT_IDS := [
	"tool_belt",
	"specimen_pin_case",
	"gardening_toolkit",
	"recycling_hook",
	"calibration_screwdriver",
	"universal_toolbox",
]

var item_db
var ornament_db

func before_each():
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
	rm.is_run_active = true
	return rm

func test_normal_battle_rewards_include_item_ornament_and_shards():
	var rm = _make_run_manager(1, 0)

	var options = RewardGeneratorScript.generate_options(rm, item_db, ornament_db, 3)
	var types = options.map(func(reward): return reward.get("type", ""))

	assert_eq(options.size(), 3)
	assert_true(types.has("item"))
	assert_true(types.has("ornament"))
	assert_true(types.has("shards"))

func test_boss_rewards_prioritize_rare_ornaments_when_available():
	var rm = _make_run_manager(4, 6)

	var options = RewardGeneratorScript.generate_options(rm, item_db, ornament_db, 3)

	assert_eq(options[0].get("type"), "ornament")
	assert_eq(options[0].get("rarity"), "稀有")

func test_reward_generation_is_reproducible_with_injected_random_seed():
	var rm_a = _make_run_manager(3, 0)
	var rm_b = _make_run_manager(3, 0)
	rm_a.current_deck = ["rusty_gear", "trash_recycler"] as Array[String]
	rm_b.current_deck = ["rusty_gear", "trash_recycler"] as Array[String]
	var rng_a = RandomNumberGenerator.new()
	var rng_b = RandomNumberGenerator.new()
	rng_a.seed = 90210
	rng_b.seed = 90210

	var options_a = RewardGeneratorScript.generate_options(rm_a, item_db, ornament_db, 4, rng_a)
	var options_b = RewardGeneratorScript.generate_options(rm_b, item_db, ornament_db, 4, rng_b)

	assert_eq(_reward_keys(options_a), _reward_keys(options_b))

func test_reward_generation_includes_enabled_tool_ornaments():
	var rm = _make_run_manager(6, 0)

	var options = RewardGeneratorScript.generate_options(rm, item_db, ornament_db, 80)
	var ornament_ids = options.filter(func(reward): return reward.get("type", "") == "ornament").map(func(reward): return str(reward.get("id", "")))

	for ornament_id in TOOL_ORNAMENT_IDS:
		assert_true(ornament_ids.has(ornament_id))

func test_reward_generator_falls_back_to_shards_when_pools_are_empty():
	var rm = _make_run_manager(1, 0)

	var options = RewardGeneratorScript.generate_options(rm, null, null, 3)
	var types = options.map(func(reward): return reward.get("type", ""))

	assert_eq(options.size(), 3)
	assert_eq(types, ["shards", "shards", "shards"])

func test_apply_reward_updates_long_term_state_and_blocks_duplicate_ornaments():
	var rm = _make_run_manager(1, 0)
	rm.current_shards = 0

	assert_true(rm.apply_reward({"type": "shards", "amount": 9}))
	assert_eq(rm.current_shards, 9)

	assert_true(rm.apply_reward({"type": "item", "id": "paper_ball"}))
	assert_eq(rm.current_deck, ["paper_ball"])

	assert_true(rm.apply_reward({"type": "ornament", "id": "old_pocket_watch"}))
	assert_false(rm.apply_reward({"type": "ornament", "id": "old_pocket_watch"}))
	assert_eq(rm.current_ornaments, ["old_pocket_watch"])

	assert_true(rm.apply_reward({"type": "tool", "id": "small_patch", "amount": 2}))
	assert_true(rm.current_tools.is_empty())
	assert_eq(rm.pending_item_rewards.size(), 1)
	assert_eq(str(rm.pending_item_rewards[0].get("id", "")), "small_patch")
	assert_eq(int(rm.pending_item_rewards[0].get("stack_count", 0)), 2)

func _reward_keys(options: Array[Dictionary]) -> Array[String]:
	var keys: Array[String] = []
	for reward in options:
		keys.append("%s:%s" % [str(reward.get("type", "")), str(reward.get("id", ""))])
	return keys
