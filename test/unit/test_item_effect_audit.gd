extends GutTest

const BattleManagerScript = preload("res://src/battle/battle_manager.gd")

const ITEM_IDS := [
	"alarm_clock",
	"apple",
	"apple_core",
	"baseball",
	"brake_pad",
	"central_engine",
	"counting_wheel",
	"cracked_lens",
	"crankshaft",
	"differential",
	"dream_seed_1x1",
	"dream_seed_2x2",
	"dream_seed_3x3",
	"dream_seed_4x4",
	"dual_axis_wheel",
	"energy_flywheel",
	"expired_medicine",
	"gear_rack",
	"gift_box",
	"insurance_contract",
	"iron_ball",
	"joker",
	"leaky_pen",
	"left_transmission_elbow",
	"leftover_box",
	"mineral_water_bottle",
	"old_soccer_ball",
	"paper_ball",
	"pill_bottle",
	"right_transmission_elbow",
	"roast_chicken",
	"root_dream",
	"rusty_gear",
	"sad_teddy_bear",
	"small_gear",
	"star_ring_bearing",
	"sticky_note",
	"syringe",
	"terminal_computer",
	"tin_can",
	"transmission_belt",
	"trash_bag",
	"trash_recycler",
	"wet_cardboard_box",
]

const ITEM_DIRECT_ASSERTIONS := {
	"alarm_clock": "test_simple_score_items_apply_their_hit_values",
	"apple": "test_draw_and_discard_reactive_items_trigger_their_runtime_hooks",
	"apple_core": "test_draw_and_discard_reactive_items_trigger_their_runtime_hooks",
	"baseball": "test_draw_and_discard_reactive_items_trigger_their_runtime_hooks",
	"brake_pad": "test_mechanical_basic_items_score_stop_and_continue_correctly",
	"central_engine": "test_mechanical_after_resolution_items_read_final_summary",
	"counting_wheel": "test_mechanical_after_resolution_items_read_final_summary",
	"cracked_lens": "test_special_hit_items_transform_or_copy_effects",
	"crankshaft": "test_mechanical_transmission_items_turn_filter_and_branch",
	"differential": "test_mechanical_after_resolution_items_read_final_summary",
	"dream_seed_1x1": "test_seed_items_score_by_runtime_level_and_stage",
	"dream_seed_2x2": "test_seed_items_score_by_runtime_level_and_stage",
	"dream_seed_3x3": "test_seed_items_score_by_runtime_level_and_stage",
	"dream_seed_4x4": "test_seed_items_score_by_runtime_level_and_stage",
	"dual_axis_wheel": "test_mechanical_transmission_items_turn_filter_and_branch",
	"energy_flywheel": "test_mechanical_after_resolution_items_read_final_summary",
	"expired_medicine": "test_pollution_and_cleanup_items_apply_direct_effects",
	"gear_rack": "test_mechanical_basic_items_score_stop_and_continue_correctly",
	"gift_box": "test_special_hit_items_transform_or_copy_effects",
	"insurance_contract": "test_insurance_contract_recovers_failed_target_run_once",
	"iron_ball": "test_draw_and_discard_reactive_items_trigger_their_runtime_hooks",
	"joker": "test_simple_score_items_apply_their_hit_values",
	"leaky_pen": "test_pollution_and_cleanup_items_apply_direct_effects",
	"left_transmission_elbow": "test_mechanical_transmission_items_turn_filter_and_branch",
	"leftover_box": "test_pollution_and_cleanup_items_apply_direct_effects",
	"mineral_water_bottle": "test_simple_score_items_apply_their_hit_values",
	"old_soccer_ball": "test_draw_and_discard_reactive_items_trigger_their_runtime_hooks",
	"paper_ball": "test_pollution_and_cleanup_items_apply_direct_effects",
	"pill_bottle": "test_pollution_and_cleanup_items_apply_direct_effects",
	"right_transmission_elbow": "test_mechanical_transmission_items_turn_filter_and_branch",
	"roast_chicken": "test_simple_score_items_apply_their_hit_values",
	"root_dream": "test_draw_and_discard_reactive_items_trigger_their_runtime_hooks",
	"rusty_gear": "test_pollution_and_cleanup_items_apply_direct_effects",
	"sad_teddy_bear": "test_special_hit_items_transform_or_copy_effects",
	"small_gear": "test_mechanical_basic_items_score_stop_and_continue_correctly",
	"star_ring_bearing": "test_mechanical_transmission_items_turn_filter_and_branch",
	"sticky_note": "test_sticky_note_scores_on_each_three_pollution_threshold",
	"syringe": "test_pollution_and_cleanup_items_apply_direct_effects",
	"terminal_computer": "test_mechanical_after_resolution_items_read_final_summary",
	"tin_can": "test_simple_score_items_apply_their_hit_values",
	"transmission_belt": "test_mechanical_basic_items_score_stop_and_continue_correctly",
	"trash_bag": "test_pollution_and_cleanup_items_apply_direct_effects",
	"trash_recycler": "test_pollution_and_cleanup_items_apply_direct_effects",
	"wet_cardboard_box": "test_pollution_and_cleanup_items_apply_direct_effects",
}

var item_db
var rm
var gs
var run_snapshot := {}

func before_each():
	item_db = get_node_or_null("/root/ItemDatabase")
	rm = get_node_or_null("/root/RunManager")
	gs = get_node_or_null("/root/GameState")
	if item_db and item_db.items.is_empty():
		item_db.load_all_items()
	if rm:
		run_snapshot = rm.serialize_run()
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
	return manager

func _place(manager: BattleManager, item_id: String, pos: Vector2i, direction: int = ItemData.Direction.RIGHT) -> BackpackManager.ItemInstance:
	var item = item_db.get_item_by_id(item_id)
	assert_not_null(item)
	item.direction = direction
	assert_true(manager.backpack_manager.place_item(item, pos))
	return manager.backpack_manager.grid[pos]

func _make_test_item(id: String, tags: Array[String] = [] as Array[String], direction: int = ItemData.Direction.RIGHT) -> ItemData:
	var item = ItemData.new()
	item.id = id
	item.item_name = id
	item.tags = tags.duplicate()
	item.shape = [Vector2i.ZERO] as Array[Vector2i]
	item.direction = direction
	item.transmission_mode = ItemData.TransmissionMode.NORMAL
	item.can_draw = false
	return item

func _make_source(pos: Vector2i, direction: int = ItemData.Direction.RIGHT) -> BackpackManager.ItemInstance:
	var source_data = _make_test_item("audit_source", [] as Array[String], direction)
	return BackpackManager.ItemInstance.new(source_data, pos)

func _resolve(manager: BattleManager, start_pos: Vector2i, direction: int, source = null) -> Dictionary:
	var resolver = ImpactResolver.new(manager.backpack_manager, manager.context)
	var actions = resolver.resolve_impact(start_pos, direction, source)
	return {"resolver": resolver, "actions": actions}

func _score_for_instance(actions: Array, instance: BackpackManager.ItemInstance) -> int:
	var score := 0
	for action in actions:
		if action.type == GameAction.Type.NUMERIC and action.item_instance == instance and action.value.type == "score":
			score += int(action.value.amount)
	return score

func _score_for_id(actions: Array, item_id: String) -> int:
	var score := 0
	for action in actions:
		if action.type == GameAction.Type.NUMERIC and action.item_instance != null and action.item_instance.data.id == item_id and action.value.type == "score":
			score += int(action.value.amount)
	return score

func _sanity_amount_for_instance(actions: Array, instance: BackpackManager.ItemInstance) -> int:
	var amount := 0
	for action in actions:
		if action.type == GameAction.Type.NUMERIC and action.item_instance == instance and action.value.type == "sanity":
			amount += int(action.value.amount)
	return amount

func _impact_ids(actions: Array) -> Array[String]:
	var ids: Array[String] = []
	for action in actions:
		if action.type == GameAction.Type.IMPACT and action.item_instance != null:
			ids.append(action.item_instance.data.id)
	return ids

func _score_from_after_resolution(manager: BattleManager, item_id: String, hit_count: int, mechanical_count: int, turn_count: int = 0, bidirectional_count: int = 0) -> int:
	var instance = _place(manager, item_id, Vector2i(2, 2))
	var resolver = ImpactResolver.new(manager.backpack_manager, manager.context)
	resolver.resolution_context.hit_count = hit_count
	resolver.resolution_context.mechanical_hit_count = mechanical_count
	resolver.resolution_context.turn_transmission_count = turn_count
	resolver.resolution_context.bidirectional_transmission_count = bidirectional_count
	for effect in instance.data.effects:
		if effect.has_method("after_resolution"):
			var action = effect.after_resolution(instance, resolver, manager.context, 1)
			return int(action.value.amount) if action != null else 0
	return 0

func test_item_database_loads_full_official_item_pool():
	var all_items = item_db.get_all_items()
	var ids = all_items.map(func(item): return item.id)

	assert_eq(all_items.size(), 44)
	for item_id in ITEM_IDS:
		assert_true(ids.has(item_id), "Missing item id: %s" % item_id)

func test_simple_score_items_apply_their_hit_values():
	var manager = await _make_manager()
	var alarm_clock = _place(manager, "alarm_clock", Vector2i(2, 1))
	manager.draw_count = 16
	assert_eq(_score_for_instance(_resolve(manager, alarm_clock.root_pos, ItemData.Direction.RIGHT).actions, alarm_clock), 11)

	manager.backpack_manager.grid.clear()
	var mineral_water_bottle = _place(manager, "mineral_water_bottle", Vector2i(2, 1))
	assert_eq(_score_for_instance(_resolve(manager, mineral_water_bottle.root_pos, ItemData.Direction.RIGHT).actions, mineral_water_bottle), 5)

	manager.backpack_manager.grid.clear()
	var tin_can = _place(manager, "tin_can", Vector2i(2, 1))
	assert_eq(_score_for_instance(_resolve(manager, tin_can.root_pos, ItemData.Direction.RIGHT).actions, tin_can), 9)

	manager.backpack_manager.grid.clear()
	var roast_chicken = _place(manager, "roast_chicken", Vector2i(2, 1))
	assert_eq(_score_for_instance(_resolve(manager, roast_chicken.root_pos, ItemData.Direction.RIGHT).actions, roast_chicken), 20)

	manager.backpack_manager.grid.clear()
	var joker = _place(manager, "joker", Vector2i(2, 1))
	assert_eq(_score_for_instance(_resolve(manager, joker.root_pos, ItemData.Direction.RIGHT).actions, joker), 3)

func test_pollution_and_cleanup_items_apply_direct_effects():
	var manager = await _make_manager()
	var paper_ball = _place(manager, "paper_ball", Vector2i(2, 1))
	var result = _resolve(manager, paper_ball.root_pos, ItemData.Direction.RIGHT)
	assert_eq(_score_for_instance(result.actions, paper_ball), 2)
	assert_eq(paper_ball.current_pollution, 1)

	manager.backpack_manager.grid.clear()
	var expired_medicine = _place(manager, "expired_medicine", Vector2i(2, 1))
	result = _resolve(manager, expired_medicine.root_pos, ItemData.Direction.RIGHT)
	assert_eq(_score_for_instance(result.actions, expired_medicine), 5)
	assert_eq(expired_medicine.current_pollution, 3)

	manager.backpack_manager.grid.clear()
	var wet_cardboard_box = _place(manager, "wet_cardboard_box", Vector2i(2, 2), ItemData.Direction.RIGHT)
	var wet_target = _place(manager, "tin_can", Vector2i(4, 2))
	result = _resolve(manager, wet_cardboard_box.root_pos, ItemData.Direction.RIGHT)
	assert_eq(_score_for_instance(result.actions, wet_cardboard_box), 6)
	assert_eq(wet_target.current_pollution, 3)

	manager.backpack_manager.grid.clear()
	var leaky_pen = _place(manager, "leaky_pen", Vector2i(2, 2), ItemData.Direction.RIGHT)
	leaky_pen.data.transmission_mode = ItemData.TransmissionMode.NONE
	var leaky_target = _place(manager, "paper_ball", Vector2i(4, 2))
	result = _resolve(manager, leaky_pen.root_pos, ItemData.Direction.RIGHT)
	assert_eq(_score_for_instance(result.actions, leaky_pen), 3)
	assert_eq(leaky_target.current_pollution, 1)

	manager.backpack_manager.grid.clear()
	var leftover_box = _place(manager, "leftover_box", Vector2i(2, 2))
	leftover_box.data.transmission_mode = ItemData.TransmissionMode.NONE
	var waste_neighbor = _place(manager, "paper_ball", Vector2i(5, 3))
	_place(manager, "apple", Vector2i(1, 3))
	_resolve(manager, leftover_box.root_pos, ItemData.Direction.RIGHT)
	assert_eq(waste_neighbor.current_pollution, 1)

	manager.backpack_manager.grid.clear()
	var pill_bottle = _place(manager, "pill_bottle", Vector2i(2, 1))
	var low_pollution = _place(manager, "paper_ball", Vector2i(3, 1))
	var high_pollution = _place(manager, "expired_medicine", Vector2i(2, 2))
	low_pollution.current_pollution = 1
	high_pollution.current_pollution = 3
	_resolve(manager, pill_bottle.root_pos, ItemData.Direction.RIGHT)
	assert_eq(high_pollution.current_pollution, 4)

	manager.backpack_manager.grid.clear()
	var syringe = _place(manager, "syringe", Vector2i(1, 2), ItemData.Direction.RIGHT)
	syringe.data.transmission_mode = ItemData.TransmissionMode.NONE
	var first_waste = _place(manager, "paper_ball", Vector2i(4, 2))
	var second_waste = _place(manager, "joker", Vector2i(5, 2))
	_resolve(manager, syringe.root_pos, ItemData.Direction.RIGHT)
	assert_eq(first_waste.current_pollution, 1)
	assert_eq(second_waste.current_pollution, 1)

	manager.backpack_manager.grid.clear()
	var rusty_gear = _place(manager, "rusty_gear", Vector2i(2, 2))
	var rusty_neighbor = _place(manager, "tin_can", Vector2i(3, 2))
	_resolve(manager, rusty_gear.root_pos, ItemData.Direction.RIGHT)
	assert_eq(rusty_gear.current_pollution, 1)
	assert_eq(rusty_neighbor.current_pollution, 1)

	manager.backpack_manager.grid.clear()
	var trash_bag = _place(manager, "trash_bag", Vector2i(2, 2))
	trash_bag.data.transmission_mode = ItemData.TransmissionMode.NONE
	var dirty_neighbor = _place(manager, "paper_ball", Vector2i(4, 2))
	dirty_neighbor.current_pollution = 4
	result = _resolve(manager, trash_bag.root_pos, ItemData.Direction.RIGHT)
	assert_eq(dirty_neighbor.current_pollution, 0)
	assert_eq(_sanity_amount_for_instance(result.actions, trash_bag), 4)

	manager.backpack_manager.grid.clear()
	var trash_recycler = _place(manager, "trash_recycler", Vector2i(2, 2))
	trash_recycler.data.transmission_mode = ItemData.TransmissionMode.NONE
	var dirty_a = _place(manager, "paper_ball", Vector2i(1, 3))
	var dirty_b = _place(manager, "joker", Vector2i(5, 3))
	dirty_a.current_pollution = 1
	dirty_b.current_pollution = 2
	result = _resolve(manager, trash_recycler.root_pos, ItemData.Direction.RIGHT)
	assert_eq(_score_for_instance(result.actions, trash_recycler), 100)
	assert_eq(dirty_a.current_pollution + dirty_b.current_pollution, 0)

func test_sticky_note_scores_on_each_three_pollution_threshold():
	var manager = await _make_manager()
	var sticky_note = _place(manager, "sticky_note", Vector2i(2, 2))
	var resolver = ImpactResolver.new(manager.backpack_manager, manager.context)

	resolver.add_pollution(sticky_note, 2)
	assert_eq(_score_for_instance(resolver.actions_history, sticky_note), 0)

	resolver.add_pollution(sticky_note, 1)
	assert_eq(_score_for_instance(resolver.actions_history, sticky_note), 10)

	resolver.add_pollution(sticky_note, 3)
	assert_eq(_score_for_instance(resolver.actions_history, sticky_note), 20)

func test_seed_items_score_by_runtime_level_and_stage():
	var manager = await _make_manager()
	var seed_1 = BackpackManager.ItemInstance.new(item_db.get_item_by_id("dream_seed_1x1"), Vector2i.ZERO)
	seed_1.dream_seed_level = 9
	assert_eq(seed_1.data.effects[0].on_hit(seed_1, null, ImpactResolver.new(manager.backpack_manager, manager.context), manager.context).value.amount, 9)

	var seed_2 = BackpackManager.ItemInstance.new(item_db.get_item_by_id("dream_seed_2x2"), Vector2i.ZERO)
	seed_2.dream_seed_level = 10
	assert_eq(seed_2.data.effects[0].on_hit(seed_2, null, ImpactResolver.new(manager.backpack_manager, manager.context), manager.context).value.amount, 20)

	var seed_3 = BackpackManager.ItemInstance.new(item_db.get_item_by_id("dream_seed_3x3"), Vector2i.ZERO)
	seed_3.dream_seed_level = 20
	assert_eq(seed_3.data.effects[0].on_hit(seed_3, null, ImpactResolver.new(manager.backpack_manager, manager.context), manager.context).value.amount, 80)

	var seed_4 = BackpackManager.ItemInstance.new(item_db.get_item_by_id("dream_seed_4x4"), Vector2i.ZERO)
	seed_4.dream_seed_level = 30
	assert_eq(seed_4.data.effects[0].on_hit(seed_4, null, ImpactResolver.new(manager.backpack_manager, manager.context), manager.context).value.amount, 240)

func test_draw_and_discard_reactive_items_trigger_their_runtime_hooks():
	var manager = await _make_manager()
	manager.battle_state = BattleManager.BattleState.RESOLVING

	var apple = _place(manager, "apple", Vector2i(2, 1), ItemData.Direction.RIGHT)
	gs.current_sanity = 50
	manager.backpack_manager.remove_instance(apple)
	apple.data.effects[0].on_discard_instance(apple, manager.context)
	assert_eq(gs.current_sanity, 53)
	assert_eq(manager.backpack_manager.grid[Vector2i(2, 1)].data.id, "apple_core")

	manager.backpack_manager.grid.clear()
	var apple_core = _place(manager, "apple_core", Vector2i(2, 1))
	manager.draw_count = 5
	apple_core.data.effects[0].on_global_item_drawn(item_db.get_item_by_id("paper_ball"), apple_core, manager.context)
	assert_eq(manager.backpack_manager.grid[Vector2i(2, 1)].data.id, "apple")

	manager.backpack_manager.grid.clear()
	var baseball = _place(manager, "baseball", Vector2i(2, 1))
	var drawn_baseball = item_db.get_item_by_id("baseball")
	drawn_baseball.runtime_id = baseball.data.runtime_id + 1
	baseball.data.effects[0].on_global_item_drawn(drawn_baseball, baseball, manager.context)
	assert_eq(manager._impact_queue.size(), 1)

	manager._impact_queue.clear()
	manager.backpack_manager.grid.clear()
	var iron_ball = _place(manager, "iron_ball", Vector2i(2, 1))
	var drawn_iron_ball = item_db.get_item_by_id("iron_ball")
	drawn_iron_ball.runtime_id = iron_ball.data.runtime_id + 1
	iron_ball.data.effects[0].on_global_item_drawn(drawn_iron_ball, iron_ball, manager.context)
	assert_eq(manager._impact_queue.size(), 1)

	manager._impact_queue.clear()
	manager.backpack_manager.grid.clear()
	var old_soccer_ball = _place(manager, "old_soccer_ball", Vector2i(2, 1))
	old_soccer_ball.data.effects[0].on_global_item_drawn(item_db.get_item_by_id("paper_ball"), old_soccer_ball, manager.context)
	assert_eq(manager._impact_queue.size(), 1)

	manager._impact_queue.clear()
	manager.backpack_manager.grid.clear()
	var root_dream = _place(manager, "root_dream", Vector2i(2, 1))
	manager.draw_count = 5
	root_dream.data.effects[0].on_global_item_drawn(item_db.get_item_by_id("paper_ball"), root_dream, manager.context)
	assert_eq(manager._impact_queue.size(), 1)

func test_special_hit_items_transform_or_copy_effects():
	var manager = await _make_manager()
	var source = _place(manager, "mineral_water_bottle", Vector2i(1, 2), ItemData.Direction.RIGHT)
	var cracked_lens = _place(manager, "cracked_lens", Vector2i(3, 2))
	var result = _resolve(manager, Vector2i(2, 2), ItemData.Direction.RIGHT, source)
	assert_eq(_score_for_instance(result.actions, cracked_lens), 10)

	manager.backpack_manager.grid.clear()
	var gift_box = _place(manager, "gift_box", Vector2i(2, 1))
	result = _resolve(manager, gift_box.root_pos, ItemData.Direction.RIGHT)
	assert_eq(_score_for_instance(result.actions, gift_box), 5)
	assert_true(manager.backpack_manager.grid.has(Vector2i(2, 1)))
	assert_ne(manager.backpack_manager.grid[Vector2i(2, 1)].data.id, "gift_box")

	manager.backpack_manager.grid.clear()
	var sad_teddy_bear = _place(manager, "sad_teddy_bear", Vector2i(2, 1))
	result = _resolve(manager, sad_teddy_bear.root_pos, ItemData.Direction.RIGHT)
	assert_eq(_score_for_instance(result.actions, sad_teddy_bear), 10)
	assert_eq(sad_teddy_bear.current_pollution, 2)

func test_insurance_contract_recovers_failed_target_run_once():
	var manager = await _make_manager()
	rm.current_route_index = 6
	rm.current_act = 1
	gs.current_score = 0
	gs.current_sanity = 1
	_place(manager, "insurance_contract", Vector2i(2, 1))

	manager.apply_sanity_loss(2, "effect", null)

	assert_eq(gs.current_sanity, 5)
	assert_true(manager.backpack_manager.get_all_instances().filter(func(instance): return instance.data.id == "insurance_contract").is_empty())

func test_mechanical_basic_items_score_stop_and_continue_correctly():
	var manager = await _make_manager()
	var transmission_belt = _place(manager, "transmission_belt", Vector2i(1, 2), ItemData.Direction.RIGHT)
	var small_gear = _place(manager, "small_gear", Vector2i(3, 2), ItemData.Direction.RIGHT)
	var result = _resolve(manager, transmission_belt.root_pos, ItemData.Direction.RIGHT)
	assert_eq(_score_for_instance(result.actions, transmission_belt), 7)
	assert_eq(_score_for_instance(result.actions, small_gear), 5)

	manager.backpack_manager.grid.clear()
	var gear_rack = _place(manager, "gear_rack", Vector2i(1, 2), ItemData.Direction.RIGHT)
	_place(manager, "small_gear", Vector2i(4, 2), ItemData.Direction.RIGHT)
	result = _resolve(manager, gear_rack.root_pos, ItemData.Direction.RIGHT)
	assert_eq(_score_for_instance(result.actions, gear_rack), 5)

	manager.backpack_manager.grid.clear()
	var brake_pad = _place(manager, "brake_pad", Vector2i(2, 1), ItemData.Direction.RIGHT)
	_place(manager, "small_gear", Vector2i(3, 1), ItemData.Direction.RIGHT)
	result = _resolve(manager, brake_pad.root_pos, ItemData.Direction.RIGHT)
	assert_eq(_score_for_instance(result.actions, brake_pad), 8)
	assert_false(_impact_ids(result.actions).has("small_gear"))

func test_mechanical_transmission_items_turn_filter_and_branch():
	var manager = await _make_manager()
	var left_transmission_elbow = _place(manager, "left_transmission_elbow", Vector2i(2, 2), ItemData.Direction.RIGHT)
	var left_target = _place(manager, "small_gear", Vector2i(2, 1), ItemData.Direction.RIGHT)
	var result = _resolve(manager, left_transmission_elbow.root_pos, ItemData.Direction.RIGHT)
	assert_true(_impact_ids(result.actions).has(left_target.data.id))

	manager.backpack_manager.grid.clear()
	var right_transmission_elbow = _place(manager, "right_transmission_elbow", Vector2i(2, 2), ItemData.Direction.RIGHT)
	var right_target = _place(manager, "small_gear", Vector2i(2, 4), ItemData.Direction.RIGHT)
	result = _resolve(manager, right_transmission_elbow.root_pos, ItemData.Direction.RIGHT)
	assert_true(_impact_ids(result.actions).has(right_target.data.id))

	manager.backpack_manager.grid.clear()
	var crankshaft = _place(manager, "crankshaft", Vector2i(2, 2), ItemData.Direction.RIGHT)
	_place(manager, "small_gear", Vector2i(2, 3), ItemData.Direction.RIGHT)
	result = _resolve(manager, crankshaft.root_pos, ItemData.Direction.RIGHT)
	assert_eq(_score_for_instance(result.actions, crankshaft), 10)

	manager.backpack_manager.grid.clear()
	_place(manager, "transmission_belt", Vector2i(1, 3), ItemData.Direction.RIGHT)
	_place(manager, "small_gear", Vector2i(3, 3), ItemData.Direction.RIGHT)
	var dual_axis_wheel = _place(manager, "dual_axis_wheel", Vector2i(4, 3), ItemData.Direction.RIGHT)
	_place(manager, "small_gear", Vector2i(4, 2), ItemData.Direction.RIGHT)
	_place(manager, "brake_pad", Vector2i(4, 5), ItemData.Direction.RIGHT)
	result = _resolve(manager, Vector2i(1, 3), ItemData.Direction.RIGHT)
	assert_true(_impact_ids(result.actions).has(dual_axis_wheel.data.id))
	assert_eq(result.resolver.get_current_resolution_summary().bidirectional_transmission_count, 1)

	manager.backpack_manager.grid.clear()
	var star_ring_bearing = _place(manager, "star_ring_bearing", Vector2i(3, 3), ItemData.Direction.RIGHT)
	_place(manager, "small_gear", Vector2i(3, 2), ItemData.Direction.RIGHT)
	_place(manager, "brake_pad", Vector2i(5, 3), ItemData.Direction.RIGHT)
	result = _resolve(manager, star_ring_bearing.root_pos, ItemData.Direction.RIGHT)
	assert_true(_impact_ids(result.actions).has("small_gear"))
	assert_true(_impact_ids(result.actions).has("brake_pad"))

func test_mechanical_after_resolution_items_read_final_summary():
	var manager = await _make_manager()

	assert_eq(_score_from_after_resolution(manager, "counting_wheel", 9, 0), 32)
	manager.backpack_manager.grid.clear()
	assert_eq(_score_from_after_resolution(manager, "energy_flywheel", 0, 7), 24)
	manager.backpack_manager.grid.clear()
	assert_eq(_score_from_after_resolution(manager, "differential", 0, 4, 2), 18)
	manager.backpack_manager.grid.clear()
	assert_eq(_score_from_after_resolution(manager, "central_engine", 0, 10, 3), 90)
	manager.backpack_manager.grid.clear()
	assert_eq(_score_from_after_resolution(manager, "terminal_computer", 0, 15, 0, 1), 60)

func test_every_item_has_direct_behavior_assertion_in_this_file():
	assert_eq(ITEM_DIRECT_ASSERTIONS.size(), ITEM_IDS.size())
	for item_id in ITEM_IDS:
		assert_true(ITEM_DIRECT_ASSERTIONS.has(item_id), "Item id has no direct behavior assertion: %s" % item_id)
