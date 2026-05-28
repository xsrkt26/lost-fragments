extends GutTest

const BattleManagerScript = preload("res://src/battle/battle_manager.gd")

var manager: BattleManager
var finish_reasons: Array[String]

func before_each():
	manager = add_child_autofree(BattleManagerScript.new())
	finish_reasons = []
	manager.battle_finish_requested.connect(func(reason: String): finish_reasons.append(reason))
	await get_tree().process_frame

func test_interactive_finish_request_emits_immediately():
	manager.battle_state = BattleManager.BattleState.INTERACTIVE

	var accepted = manager.request_finish_battle("manual")
	var accepted_again = manager.request_finish_battle("manual")

	assert_true(accepted)
	assert_false(accepted_again)
	assert_eq(finish_reasons, ["manual"] as Array[String])
	assert_eq(manager.battle_state, BattleManager.BattleState.FINISHING)

func test_finish_request_during_resolution_waits_until_settlement_completes():
	manager.battle_state = BattleManager.BattleState.RESOLVING

	var accepted = manager.request_finish_battle("sanity_depleted")

	assert_true(accepted)
	assert_true(finish_reasons.is_empty())
	assert_eq(manager.battle_state, BattleManager.BattleState.RESOLVING)

	manager._settle_interactive_state()

	assert_eq(finish_reasons, ["sanity_depleted"] as Array[String])
	assert_eq(manager.battle_state, BattleManager.BattleState.FINISHING)

func test_mark_battle_finished_blocks_later_finish_requests():
	manager.mark_battle_finished()

	var accepted = manager.request_finish_battle("manual")

	assert_false(accepted)
	assert_true(finish_reasons.is_empty())
	assert_eq(manager.battle_state, BattleManager.BattleState.FINISHED)

func test_deck_refill_does_not_restore_backpack_state():
	var rm = get_node_or_null("/root/RunManager")
	assert_not_null(rm)
	var snapshot = rm.serialize_run() if rm else {}
	var item_db = get_node_or_null("/root/ItemDatabase")
	assert_not_null(item_db)
	if item_db and item_db.items.is_empty():
		item_db.load_all_items()

	rm.current_deck = ["paper_ball"] as Array[String]
	rm.current_backpack_items.clear()
	manager._current_battle_deck.clear()
	manager.backpack_manager.grid.clear()
	var paper = item_db.get_item_by_id("paper_ball")
	assert_true(manager.backpack_manager.place_item(paper, Vector2i(2, 2)))
	var instance_before = manager.backpack_manager.grid[Vector2i(2, 2)]

	manager._refill_battle_deck_from_run(rm)

	assert_eq(manager.backpack_manager.grid[Vector2i(2, 2)], instance_before)
	assert_eq(manager._current_battle_deck.size(), 1)
	if rm and not snapshot.is_empty():
		rm.deserialize_run(snapshot)
