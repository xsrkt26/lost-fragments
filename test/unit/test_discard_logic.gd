extends GutTest

const MockItemUI = preload("res://test/support/mock_item_ui.gd")

var gs
var backpack: BackpackManager
var context: GameContext
var battle: BattleManager
var item_db

func before_each():
	gs = autofree(Node.new())
	gs.set_script(preload("res://src/autoload/game_state.gd"))
	add_child(gs)
	gs.reset_game()

	battle = autofree(BattleManager.new())
	add_child(battle)

	battle.context.state = gs

	backpack = battle.backpack_manager
	context = battle.context

	item_db = get_node_or_null("/root/ItemDatabase")

func _make_item_ui(item_data: ItemData, item_instance = null) -> Control:
	var item_ui = autoqfree(MockItemUI.new())
	add_child(item_ui)
	item_ui.item_data = item_data
	item_ui.item_instance = item_instance
	return item_ui

func _flush_queued_nodes():
	await get_tree().process_frame
	await get_tree().process_frame

func test_discard_floating_items_at_end():
	var item_data = item_db.get_item_by_id("paper_ball")

	var item_ui1 = _make_item_ui(item_data)

	backpack.place_item(item_data, Vector2i(2, 2))
	var inst2 = backpack.grid[Vector2i(2, 2)]
	var item_ui2 = _make_item_ui(item_data, inst2)

	battle.managed_item_uis = [item_ui1, item_ui2]

	battle.discard_all_outside_items()

	assert_true(item_ui1.is_queued_for_deletion(), "Floating item should be discarded")
	assert_false(item_ui2.is_queued_for_deletion(), "Placed item should NOT be discarded")
	assert_eq(battle.managed_item_uis.size(), 1, "Managed list should now only contain the placed item")

	await _flush_queued_nodes()
	assert_no_new_orphans("Discarding floating items should not leak mock UI nodes")

func test_on_discard_effect_trigger():
	var apple_data = item_db.get_item_by_id("apple")
	gs.current_sanity = 50
	gs.current_score = 0

	backpack.place_item(apple_data, Vector2i(2, 2))
	var apple_instance = backpack.grid[Vector2i(2, 2)]
	var apple_ui = _make_item_ui(apple_instance.data, apple_instance)

	battle.managed_item_uis = [apple_ui]
	battle.request_discard_item(apple_ui)

	assert_eq(gs.current_sanity, 53, "Discarding apple from backpack should restore dream value")
	assert_eq(gs.current_score, 0, "Discarding apple should not add score")
	assert_true(backpack.grid.has(Vector2i(2, 2)), "Discarding apple from backpack should leave a core")
	assert_eq(backpack.grid[Vector2i(2, 2)].data.id, "apple_core")
	assert_false(apple_ui.is_queued_for_deletion(), "Apple UI should be reused for the core left in place")
	await _flush_queued_nodes()
	assert_no_new_orphans("Discarding a backpack item should not leak mock UI nodes")

func test_backpack_apple_discard_uses_item_instance_when_ui_data_is_stale():
	var apple_data = item_db.get_item_by_id("apple")
	gs.current_sanity = 50

	backpack.place_item(apple_data, Vector2i(2, 2))
	var apple_instance = backpack.grid[Vector2i(2, 2)]
	var stale_data = item_db.get_item_by_id("apple").duplicate(true)
	stale_data.runtime_id = -1
	var apple_ui = _make_item_ui(stale_data, apple_instance)

	battle.managed_item_uis = [apple_ui]
	battle.request_discard_item(apple_ui)

	assert_eq(gs.current_sanity, 53)
	assert_true(backpack.grid.has(Vector2i(2, 2)))
	assert_eq(backpack.grid[Vector2i(2, 2)].data.id, "apple_core")
	await _flush_queued_nodes()
	assert_no_new_orphans("Discarding with stale UI data should not leak mock UI nodes")

func test_outside_apple_discard_does_not_trigger_backpack_discard_effect():
	var apple_data = item_db.get_item_by_id("apple")
	gs.current_sanity = 50
	gs.current_score = 0

	var apple_ui = _make_item_ui(apple_data)

	battle.managed_item_uis = [apple_ui]
	battle.discard_all_outside_items()

	assert_eq(gs.current_sanity, 50, "Apple discard bonus only applies from backpack")
	assert_eq(gs.current_score, 0)
	await _flush_queued_nodes()
	assert_no_new_orphans("Discarding an outside item should not leak mock UI nodes")
