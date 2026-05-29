extends GutTest

const ItemDrawPool = preload("res://src/core/items/item_draw_pool.gd")
const RunManagerScript = preload("res://src/autoload/run_manager.gd")

const POLLUTION_ITEM_IDS: Array[String] = [
	"paper_ball",
	"joker",
	"sticky_note",
	"leaky_pen",
	"sad_teddy_bear",
	"pill_bottle",
	"trash_bag",
	"old_soccer_ball",
	"expired_medicine",
	"syringe",
	"leftover_box",
	"wet_cardboard_box",
	"trash_recycler",
	"rusty_gear",
]

var item_db

func before_each():
	item_db = get_node_or_null("/root/ItemDatabase")
	assert_not_null(item_db)
	if item_db and item_db.items.is_empty():
		item_db.load_all_items()

func test_act_one_uses_first_layer_general_pool_only():
	var pool = ItemDrawPool.get_unlocked_items_by_category(item_db, 1)
	var general_ids := _ids_from_entries(pool.get(ItemDrawPool.CATEGORY_GENERAL, []))

	general_ids.sort()
	assert_eq(general_ids, ["alarm_clock", "apple", "baseball", "mineral_water_bottle", "tin_can"] as Array[String])
	assert_true(Array(pool.get(ItemDrawPool.CATEGORY_POLLUTION, [])).is_empty())
	assert_true(Array(pool.get(ItemDrawPool.CATEGORY_MECHANICAL, [])).is_empty())

func test_all_current_pollution_flow_items_unlock_by_act_five():
	var pool = ItemDrawPool.get_unlocked_items_by_category(item_db, 5)
	var pollution_ids := _ids_from_entries(pool.get(ItemDrawPool.CATEGORY_POLLUTION, []))

	pollution_ids.sort()
	var expected := POLLUTION_ITEM_IDS.duplicate()
	expected.sort()
	assert_eq(pollution_ids, expected)

func test_design_doc_category_and_role_weights_are_encoded():
	var act_4_category_weights = ItemDrawPool.get_category_weights(4)
	assert_eq(float(act_4_category_weights.get(ItemDrawPool.CATEGORY_GENERAL, 0.0)), 22.0)
	assert_eq(float(act_4_category_weights.get(ItemDrawPool.CATEGORY_POLLUTION, 0.0)), 26.0)
	assert_eq(float(act_4_category_weights.get(ItemDrawPool.CATEGORY_DREAM_SEED, 0.0)), 26.0)
	assert_eq(float(act_4_category_weights.get(ItemDrawPool.CATEGORY_MECHANICAL, 0.0)), 26.0)

	var act_4_role_weights = ItemDrawPool.get_role_weights(4)
	assert_eq(float(act_4_role_weights.get(ItemDrawPool.ROLE_STARTER, 0.0)), 30.0)
	assert_eq(float(act_4_role_weights.get(ItemDrawPool.ROLE_CORE, 0.0)), 45.0)
	assert_eq(float(act_4_role_weights.get(ItemDrawPool.ROLE_LATE, 0.0)), 25.0)

func test_generated_draw_deck_uses_more_than_legacy_three_items():
	var run_manager = autofree(RunManagerScript.new())
	run_manager.is_run_active = true
	run_manager.current_act = 5
	run_manager.current_deck = [] as Array[String]
	run_manager.current_backpack_items = [] as Array[Dictionary]
	run_manager.set_random_seed(24680)

	var deck := ItemDrawPool.build_deck(run_manager, item_db, 40)
	var unique_ids := {}
	var pollution_count := 0
	for item_id in deck:
		unique_ids[item_id] = true
		var rule = ItemDrawPool.get_item_rule(item_id)
		if rule.get("category", "") == ItemDrawPool.CATEGORY_POLLUTION:
			pollution_count += 1

	assert_eq(deck.size(), 40)
	assert_gt(unique_ids.size(), 3)
	assert_gt(pollution_count, 0)

func test_initial_act_one_draw_deck_can_show_all_starter_general_items():
	var run_manager = autofree(RunManagerScript.new())
	run_manager.is_run_active = true
	run_manager.current_act = 1
	run_manager.current_deck = RunManagerScript.INITIAL_DECK.duplicate()
	run_manager.current_backpack_items = [] as Array[Dictionary]
	run_manager.set_random_seed(13579)

	var deck := ItemDrawPool.build_deck(run_manager, item_db, 120)
	var unique_ids := {}
	for item_id in deck:
		unique_ids[item_id] = true

	for expected_id in ["alarm_clock", "apple", "baseball", "mineral_water_bottle", "tin_can"]:
		assert_true(unique_ids.has(expected_id), "Act 1 starter pool should include %s" % expected_id)

func _ids_from_entries(entries: Array) -> Array[String]:
	var ids: Array[String] = []
	for entry in entries:
		if entry is Dictionary:
			ids.append(str(entry.get("id", "")))
	return ids
