extends GutTest

const BattleManagerScript = preload("res://src/battle/battle_manager.gd")

const TOOL_IDS := [
	"small_patch",
	"dream_value_candy",
	"turning_screw",
	"cracked_marble",
	"black_ink_drop",
	"disinfectant_spray",
	"corrosive_acid",
	"small_water_drop",
	"fertilizer_bag",
	"fast_sprout_agent",
	"extension_hook",
	"transmission_oil",
	"apple_wax",
	"recycling_clip",
	"blank_talisman",
]

const TOOL_DIRECT_ASSERTIONS := {
	"small_patch": "test_common_tools_apply_patch_discount_rotation_and_queued_impact",
	"dream_value_candy": "test_common_tools_apply_patch_discount_rotation_and_queued_impact",
	"turning_screw": "test_common_tools_apply_patch_discount_rotation_and_queued_impact",
	"cracked_marble": "test_common_tools_apply_patch_discount_rotation_and_queued_impact",
	"black_ink_drop": "test_pollution_tools_apply_pollution_cleanse_and_value_loss",
	"disinfectant_spray": "test_pollution_tools_apply_pollution_cleanse_and_value_loss",
	"corrosive_acid": "test_pollution_tools_apply_pollution_cleanse_and_value_loss",
	"small_water_drop": "test_seed_tools_sow_upgrade_and_score_growth",
	"fertilizer_bag": "test_seed_tools_sow_upgrade_and_score_growth",
	"fast_sprout_agent": "test_seed_tools_sow_upgrade_and_score_growth",
	"extension_hook": "test_mechanical_tools_extend_and_bonus_successful_transmission",
	"transmission_oil": "test_mechanical_tools_extend_and_bonus_successful_transmission",
	"apple_wax": "test_discard_tools_apply_food_wax_and_recycling_clip",
	"recycling_clip": "test_discard_tools_apply_food_wax_and_recycling_clip",
	"blank_talisman": "test_blank_talisman_refreshes_once_per_ornament",
}

var item_db
var tool_db
var rm
var gs
var run_snapshot := {}

func before_each():
	item_db = get_node_or_null("/root/ItemDatabase")
	tool_db = get_node_or_null("/root/ToolDatabase")
	rm = get_node_or_null("/root/RunManager")
	gs = get_node_or_null("/root/GameState")
	if item_db and item_db.items.is_empty():
		item_db.load_all_items()
	if tool_db and tool_db.tools.is_empty():
		tool_db.load_all_tools()
	if rm:
		run_snapshot = rm.serialize_run()
		rm.current_tools = {}
	if gs:
		gs.reset_game()

func after_each():
	if rm and not run_snapshot.is_empty():
		rm.deserialize_run(run_snapshot)
	run_snapshot = {}
	if gs:
		gs.reset_game()

func _make_manager() -> BattleManager:
	var manager = add_child_autofree(BattleManagerScript.new())
	await get_tree().process_frame
	manager.backpack_manager.grid.clear()
	manager._impact_queue.clear()
	manager.battle_state = BattleManager.BattleState.INTERACTIVE
	return manager

func _place(manager: BattleManager, item_id: String, pos: Vector2i, direction: int = ItemData.Direction.RIGHT) -> BackpackManager.ItemInstance:
	var item = item_db.get_item_by_id(item_id)
	assert_not_null(item)
	item.direction = direction
	assert_true(manager.backpack_manager.place_item(item, pos))
	return manager.backpack_manager.grid[pos]

func _score_for_instance(actions: Array, instance: BackpackManager.ItemInstance) -> int:
	var score := 0
	for action in actions:
		if action.type == GameAction.Type.NUMERIC and action.item_instance == instance and action.value.type == "score":
			score += int(action.value.amount)
	return score

func _total_tool_count() -> int:
	var total := 0
	for count in rm.current_tools.values():
		total += int(count)
	return total

func test_tool_database_loads_full_official_tool_pool():
	var all_tools = tool_db.get_all_tools()
	var ids = all_tools.map(func(tool): return tool.id)

	assert_eq(all_tools.size(), 15)
	for tool_id in TOOL_IDS:
		assert_true(ids.has(tool_id), "Missing tool id: %s" % tool_id)

func test_common_tools_apply_patch_discount_rotation_and_queued_impact():
	var manager = await _make_manager()
	var target = _place(manager, "paper_ball", Vector2i(2, 2), ItemData.Direction.RIGHT)
	rm.current_tools = {
		"small_patch": 1,
		"dream_value_candy": 1,
		"turning_screw": 1,
		"cracked_marble": 1,
	}

	assert_true(manager.request_use_tool("small_patch", {"type": "item", "instance": target}))
	assert_eq(target.data.price, -2)

	assert_true(manager.request_use_tool("dream_value_candy", {"type": "dreamcatcher"}))
	assert_eq(manager._next_draw_cost_discount, 2)

	var score_before = gs.current_score
	assert_true(manager.request_use_tool("turning_screw", {"type": "item", "instance": target}))
	assert_eq(target.data.direction, ItemData.Direction.DOWN)
	assert_eq(gs.current_score, score_before + 2)

	manager.backpack_manager.grid.clear()
	target = _place(manager, "paper_ball", Vector2i(2, 2), ItemData.Direction.RIGHT)
	manager.battle_state = BattleManager.BattleState.INTERACTIVE
	assert_true(manager.request_use_tool("cracked_marble", {"type": "item", "instance": target}))
	assert_eq(manager._impact_queue.size(), 1)

func test_pollution_tools_apply_pollution_cleanse_and_value_loss():
	var manager = await _make_manager()
	var waste = _place(manager, "paper_ball", Vector2i(2, 2))
	rm.current_tools = {
		"black_ink_drop": 1,
		"disinfectant_spray": 1,
		"corrosive_acid": 1,
	}

	assert_true(manager.request_use_tool("black_ink_drop", {"type": "item", "instance": waste}))
	assert_eq(waste.current_pollution, 2)

	var score_before = gs.current_score
	assert_true(manager.request_use_tool("disinfectant_spray", {"type": "item", "instance": waste}))
	assert_eq(waste.current_pollution, 0)
	assert_eq(gs.current_score, score_before + 6)

	var price_before = waste.data.price
	assert_true(manager.request_use_tool("corrosive_acid", {"type": "item", "instance": waste}))
	assert_eq(waste.current_pollution, 2)
	assert_eq(waste.data.price, price_before - 5)

func test_seed_tools_sow_upgrade_and_score_growth():
	var manager = await _make_manager()
	rm.current_tools = {
		"small_water_drop": 1,
		"fertilizer_bag": 1,
		"fast_sprout_agent": 1,
	}

	assert_true(manager.request_use_tool("small_water_drop", {"type": "empty_cell", "x": 2, "y": 2}))
	var seed = manager.backpack_manager.grid[Vector2i(2, 2)]
	assert_eq(seed.data.id, "dream_seed_1x1")

	assert_true(manager.request_use_tool("fertilizer_bag", {"type": "item", "instance": seed}))
	assert_eq(seed.dream_seed_level, 3)

	seed.dream_seed_level = 9
	seed.data.set_meta("dream_seed_level", 9)
	var score_before = gs.current_score
	assert_true(manager.request_use_tool("fast_sprout_agent", {"type": "item", "instance": seed}))
	var upgraded = manager.backpack_manager.grid[Vector2i(2, 2)]
	assert_eq(upgraded.data.id, "dream_seed_2x2")
	assert_eq(upgraded.dream_seed_level, 12)
	assert_eq(gs.current_score, score_before + 8)

func test_mechanical_tools_extend_and_bonus_successful_transmission():
	var manager = await _make_manager()
	var hooked = _place(manager, "paper_ball", Vector2i(2, 2), ItemData.Direction.RIGHT)
	_place(manager, "tin_can", Vector2i(4, 2))
	rm.current_tools = {"extension_hook": 1}

	assert_true(manager.request_use_tool("extension_hook", {"type": "item", "instance": hooked}))
	assert_true(hooked.data.get_meta("tool_extension_hook", false))
	var resolver = ImpactResolver.new(manager.backpack_manager, manager.context)
	var actions = resolver.resolve_impact(hooked.root_pos, ItemData.Direction.RIGHT)
	assert_true(actions.any(func(action): return action.type == GameAction.Type.IMPACT and action.item_instance.data.id == "tin_can"))

	manager.backpack_manager.grid.clear()
	var belt = _place(manager, "transmission_belt", Vector2i(1, 2), ItemData.Direction.RIGHT)
	_place(manager, "small_gear", Vector2i(3, 2), ItemData.Direction.RIGHT)
	rm.current_tools = {"transmission_oil": 1}
	assert_true(manager.request_use_tool("transmission_oil", {"type": "item", "instance": belt}))
	resolver = ImpactResolver.new(manager.backpack_manager, manager.context)
	actions = resolver.resolve_impact(belt.root_pos, ItemData.Direction.RIGHT)
	assert_eq(_score_for_instance(actions, belt), 10)
	assert_eq(int(belt.data.get_meta("tool_transmission_oil_remaining", 0)), 2)

func test_discard_tools_apply_food_wax_and_recycling_clip():
	var manager = await _make_manager()
	var apple = _place(manager, "apple", Vector2i(2, 2), ItemData.Direction.RIGHT)
	rm.current_tools = {"apple_wax": 1, "recycling_clip": 1}

	assert_true(manager.request_use_tool("apple_wax", {"type": "item", "instance": apple}))
	assert_true(apple.data.get_meta("tool_apple_wax", false))
	gs.current_sanity = 50
	manager._apply_tool_item_discarded(apple.data, apple, true)
	assert_eq(gs.current_sanity, 52)
	assert_eq(manager.backpack_manager.grid[Vector2i(3, 2)].data.id, "dream_seed_1x1")

	var waste = item_db.get_item_by_id("paper_ball")
	var score_before = gs.current_score
	assert_true(manager.request_use_tool("recycling_clip", {"type": "discard"}))
	manager._apply_tool_item_discarded(waste, null, false)
	assert_eq(gs.current_score, score_before + 8)
	assert_eq(rm.current_deck[rm.current_deck.size() - 1], "paper_ball")

func test_blank_talisman_refreshes_once_per_ornament():
	rm.current_ornaments = ["light_pendant"] as Array[String]
	rm.current_tools = {"blank_talisman": 2}
	var manager = await _make_manager()
	assert_eq(manager.active_ornaments.size(), 1)
	manager.active_ornaments[0]["state"] = {"used": true}

	assert_true(manager.request_use_tool("blank_talisman", {"type": "ornament", "ornament_id": "light_pendant"}))
	assert_false(manager.active_ornaments[0]["state"].has("used"))
	assert_eq(rm.get_tool_count("blank_talisman"), 1)

	assert_false(manager.request_use_tool("blank_talisman", {"type": "ornament", "ornament_id": "light_pendant"}))
	assert_eq(rm.get_tool_count("blank_talisman"), 1)

func test_every_tool_has_direct_behavior_assertion_in_this_file():
	assert_eq(TOOL_DIRECT_ASSERTIONS.size(), TOOL_IDS.size())
	for tool_id in TOOL_IDS:
		assert_true(TOOL_DIRECT_ASSERTIONS.has(tool_id), "Tool id has no direct behavior assertion: %s" % tool_id)
	assert_eq(_total_tool_count(), 0)
