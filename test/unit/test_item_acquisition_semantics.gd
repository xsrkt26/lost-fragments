extends GutTest

const RunManagerScript = preload("res://src/autoload/run_manager.gd")
const ShopGeneratorScript = preload("res://src/core/rewards/shop_generator.gd")

var run_manager
var item_db
var ornament_db

func before_each():
	run_manager = autofree(RunManagerScript.new())
	run_manager.is_run_active = true
	run_manager.current_route_index = 1
	run_manager.current_deck = [] as Array[String]
	run_manager.current_backpack_items = [] as Array[Dictionary]
	run_manager.pending_item_rewards = [] as Array[Dictionary]
	run_manager.next_pending_item_uid = 1
	item_db = get_node_or_null("/root/ItemDatabase")
	ornament_db = get_node_or_null("/root/OrnamentDatabase")
	if item_db and item_db.items.is_empty():
		item_db.load_all_items()
	if ornament_db and ornament_db.ornaments.is_empty():
		ornament_db.load_all_ornaments()

func test_item_reward_defaults_to_deck_and_can_stage():
	assert_true(run_manager.apply_reward({"type": "item", "id": "paper_ball"}, item_db))
	assert_eq(run_manager.current_deck, ["paper_ball"])

	assert_true(run_manager.apply_reward({
		"type": "item",
		"id": "tin_can",
		"item_destination": "staging",
	}, item_db))
	assert_eq(run_manager.pending_item_rewards.size(), 1)
	assert_eq(run_manager.pending_item_rewards[0].id, "tin_can")

func test_grant_item_to_backpack_places_when_space_exists():
	assert_true(run_manager.grant_item("tin_can", RunManagerScript.ITEM_DEST_BACKPACK, item_db))

	assert_true(_backpack_has_item("root_dream"))
	assert_true(_backpack_has_item("tin_can"))
	assert_true(run_manager.pending_item_rewards.is_empty())

func test_grant_item_to_full_backpack_falls_back_to_staging():
	_fill_usable_backpack_with_single_cell_items()

	assert_true(run_manager.grant_item("tin_can", RunManagerScript.ITEM_DEST_BACKPACK, item_db))

	assert_eq(run_manager.pending_item_rewards.size(), 1)
	assert_eq(run_manager.pending_item_rewards[0].id, "tin_can")

func test_pending_item_can_be_confirmed_to_deck_or_backpack():
	assert_true(run_manager.grant_item("paper_ball", RunManagerScript.ITEM_DEST_STAGING, item_db))
	var deck_uid = int(run_manager.pending_item_rewards[0].uid)

	assert_true(run_manager.move_pending_item_to_deck(deck_uid))
	assert_eq(run_manager.current_deck, ["paper_ball"])
	assert_true(run_manager.pending_item_rewards.is_empty())

	assert_true(run_manager.grant_item("tin_can", RunManagerScript.ITEM_DEST_STAGING, item_db))
	var backpack_uid = int(run_manager.pending_item_rewards[0].uid)

	assert_true(run_manager.place_pending_item_in_backpack(backpack_uid, item_db))
	assert_true(_backpack_has_item("tin_can"))
	assert_true(run_manager.pending_item_rewards.is_empty())

func test_pending_items_persist_across_save_data():
	assert_true(run_manager.grant_item("paper_ball", RunManagerScript.ITEM_DEST_STAGING, item_db))
	var serialized = run_manager.serialize_run()

	var restored = autofree(RunManagerScript.new())
	restored.deserialize_run(serialized)

	assert_eq(restored.pending_item_rewards.size(), 1)
	assert_eq(restored.pending_item_rewards[0].id, "paper_ball")
	assert_eq(restored.next_pending_item_uid, 2)

func test_shop_generated_item_offer_is_staged_after_purchase():
	run_manager.current_shards = 100
	var offers = ShopGeneratorScript.generate_offers(run_manager, item_db, ornament_db)
	var item_offer = _find_item_offer(offers)

	assert_false(item_offer.is_empty())
	assert_eq(item_offer.get("item_destination", ""), RunManagerScript.ITEM_DEST_STAGING)
	assert_true(run_manager.buy_shop_offer(item_offer, item_db))
	assert_true(run_manager.current_deck.is_empty())
	assert_eq(run_manager.pending_item_rewards.size(), 1)
	assert_eq(run_manager.pending_item_rewards[0].id, item_offer.id)

func _backpack_has_item(item_id: String) -> bool:
	for entry in run_manager.current_backpack_items:
		if str(entry.get("id", "")) == item_id:
			return true
	return false

func _fill_usable_backpack_with_single_cell_items() -> void:
	run_manager.current_backpack_items = [] as Array[Dictionary]
	var runtime_id := 1000
	var bounds := _usable_backpack_bounds()
	for y in range(int(bounds.start_y), int(bounds.start_y) + int(bounds.height)):
		for x in range(int(bounds.start_x), int(bounds.start_x) + int(bounds.width)):
			run_manager.current_backpack_items.append({
				"id": "paper_ball",
				"x": x,
				"y": y,
				"direction": ItemData.Direction.RIGHT,
				"shape": [{"x": 0, "y": 0}],
				"runtime_id": runtime_id,
			})
			runtime_id += 1

func _usable_backpack_bounds() -> Dictionary:
	var config = run_manager.get_backpack_grid_config()
	var width := int(config.get("usable_width", RunManagerScript.INITIAL_BACKPACK_USABLE_WIDTH))
	var height := int(config.get("usable_height", RunManagerScript.INITIAL_BACKPACK_USABLE_HEIGHT))
	return {
		"start_x": floori((RunManagerScript.BACKPACK_GRID_WIDTH - width) / 2.0),
		"start_y": floori((RunManagerScript.BACKPACK_GRID_HEIGHT - height) / 2.0),
		"width": width,
		"height": height,
	}

func _find_item_offer(offers: Array[Dictionary]) -> Dictionary:
	for offer in offers:
		if str(offer.get("type", "")) == "item":
			return offer
	return {}
