extends GutTest

const BattleManagerScript = preload("res://src/battle/battle_manager.gd")
const RunManagerScript = preload("res://src/autoload/run_manager.gd")
const OrnamentSlotBarScript = preload("res://src/ui/ornament/ornament_slot_bar.gd")
const BackpackPageScene = preload("res://src/ui/backpack/backpack_page.tscn")
const TOOL_ORNAMENT_IDS := [
	"tool_belt",
	"specimen_pin_case",
	"recycling_hook",
	"calibration_screwdriver",
	"universal_toolbox",
]

const REMOVED_SEED_ORNAMENT_IDS := [
	"gardener_gloves",
	"moon_dew_bottle",
	"compost_bag",
	"honey_spoon",
	"greenhouse_glass",
	"root_bell",
	"seed_insurance",
	"apple_wooden_tag",
	"harvest_basket",
	"rejuvenation_talisman",
	"gardening_toolkit",
]

var rm
var gs
var item_db
var ornament_db
var run_snapshot := {}

func before_each():
	rm = get_node_or_null("/root/RunManager")
	gs = get_node_or_null("/root/GameState")
	item_db = get_node_or_null("/root/ItemDatabase")
	ornament_db = get_node_or_null("/root/OrnamentDatabase")
	if rm:
		run_snapshot = rm.serialize_run()
		rm.current_ornaments = [] as Array[String]
		rm.current_tools = {}
		rm.pending_item_rewards = [] as Array[Dictionary]
		rm.next_pending_item_uid = 1
		rm.current_deck = [] as Array[String]
	if gs:
		gs.reset_game()
	if item_db and item_db.items.is_empty():
		item_db.load_all_items()
	if ornament_db and ornament_db.ornaments.is_empty():
		ornament_db.load_all_ornaments()

func after_each():
	if rm and not run_snapshot.is_empty():
		rm.deserialize_run(run_snapshot)
	run_snapshot = {}
	if gs:
		gs.reset_game()

func _make_manager(ornament_ids: Array[String]) -> BattleManager:
	var ids: Array[String] = ornament_ids.duplicate()
	rm.current_ornaments = ids
	var manager = add_child_autofree(BattleManagerScript.new())
	await get_tree().process_frame
	manager.backpack_manager.grid.clear()
	return manager

func _make_draw_item(cost: int = 0) -> ItemData:
	var item = ItemData.new()
	item.id = "test_draw"
	item.item_name = "Test Draw"
	item.base_cost = cost
	item.can_draw = false
	return item

func _make_runtime_item(id: String, tags: Array[String], price: int = 0, direction: int = ItemData.Direction.RIGHT) -> ItemData:
	var item = _make_draw_item(0)
	item.id = id
	item.item_name = id
	item.tags = tags.duplicate()
	item.price = price
	item.direction = direction
	item.shape = [Vector2i(0, 0)] as Array[Vector2i]
	return item

func _make_instance(id: String, tags: Array[String], price: int = 0, direction: int = ItemData.Direction.RIGHT, pollution: int = 0) -> BackpackManager.ItemInstance:
	var item = _make_runtime_item(id, tags, price, direction)
	var instance = BackpackManager.ItemInstance.new(item, Vector2i.ZERO)
	instance.current_pollution = pollution
	return instance

func _place_runtime_item(manager: BattleManager, id: String, pos: Vector2i, tags: Array[String], price: int = 0, direction: int = ItemData.Direction.RIGHT) -> BackpackManager.ItemInstance:
	var item = _make_runtime_item(id, tags, price, direction)
	assert_true(manager.backpack_manager.place_item(item, pos))
	return manager.backpack_manager.grid[pos]

func _impact_action(instance: BackpackManager.ItemInstance) -> GameAction:
	var action = GameAction.new(GameAction.Type.IMPACT, "hit")
	action.item_instance = instance
	return action

func _make_tool(id: String, tags: Array[String]) -> ToolData:
	var tool = ToolData.new()
	tool.id = id
	tool.tool_name = id
	tool.tags = tags.duplicate()
	return tool

func test_ornament_database_loads_formal_table_and_filters_available_pool():
	assert_not_null(ornament_db)
	var all_ornaments = ornament_db.get_all_ornaments()
	assert_eq(all_ornaments.size(), ornament_db.ornaments.size())
	assert_not_null(ornament_db.get_ornament_by_id("old_pocket_watch"))
	var enabled_count := 0
	for ornament in all_ornaments:
		assert_ne(ornament.effect_id, "")
		assert_not_null(ornament.effect)
		assert_not_null(ornament.icon)
		if ornament.enabled:
			enabled_count += 1
	assert_eq(enabled_count, ornament_db.get_available_ornaments(99, [] as Array[String]).size())
	for ornament_id in TOOL_ORNAMENT_IDS:
		var ornament = ornament_db.get_ornament_by_id(ornament_id)
		assert_not_null(ornament)
		assert_true(ornament.enabled)
		assert_eq(ornament.effect_id, ornament_id)
	for ornament_id in REMOVED_SEED_ORNAMENT_IDS:
		assert_null(ornament_db.get_ornament_by_id(ornament_id))

func test_ornament_database_maps_exported_import_entries_to_source_texture_paths():
	assert_eq(ornament_db._get_texture_source_file_name("Thurisaz.png"), "Thurisaz.png")
	assert_eq(ornament_db._get_texture_source_file_name("Thurisaz.png.import"), "Thurisaz.png")
	assert_eq(ornament_db._get_texture_source_file_name("Thurisaz.ctex"), "")

func test_ornament_slot_bar_aligns_to_playable_bag_rings():
	assert_not_null(ornament_db)
	var container := Control.new()
	add_child_autofree(container)
	container.size = Vector2(767.0, 314.0)

	var ornament_ids := [
		"old_pocket_watch",
		"dreamcatcher_filter",
		"echo_earring",
		"guiding_compass",
		"safety_pin",
		"sanity_coin_purse",
		"recycling_coupon",
		"sturdy_strap",
		"buckle_guide",
		"light_pendant",
	]
	OrnamentSlotBarScript.render_to_container(
		container,
		ornament_ids,
		ornament_db,
		1.0,
		OrnamentSlotBarScript.PLAYABLE_BAG_SLOT_CENTERS
	)

	assert_eq(container.get_child_count(), OrnamentSlotBarScript.PLAYABLE_BAG_SLOT_CENTERS.size())
	for index in range(OrnamentSlotBarScript.PLAYABLE_BAG_SLOT_CENTERS.size()):
		var slot := container.get_child(index) as Control
		assert_not_null(slot)
		var configured_center: Vector2 = OrnamentSlotBarScript.PLAYABLE_BAG_SLOT_CENTERS[index]
		var expected_center := Vector2(
			configured_center.x * container.size.x,
			configured_center.y * container.size.y
		)
		var actual_center := slot.position + slot.size * 0.5
		assert_almost_eq(actual_center.x, expected_center.x, 0.001)
		assert_almost_eq(actual_center.y, expected_center.y, 0.001)

func test_backpack_page_uses_playable_bag_art_for_ornament_slots():
	var page := BackpackPageScene.instantiate()
	add_child_autofree(page)
	await get_tree().process_frame

	var playable_bag := page.get_node_or_null("ContentLayer/BackpackArt/PlayableBagArt") as TextureRect
	assert_not_null(playable_bag)
	assert_not_null(playable_bag.texture)
	assert_eq(playable_bag.texture.resource_path, "res://assets/ui/battle/intro_bag_reveal/bag_reveal_05.png")
	assert_null(page.get_node_or_null("ContentLayer/BackpackArt/OrnamentBar"))

	var ornament_slots := page.get_node_or_null("ContentLayer/OrnamentSlots") as Control
	assert_not_null(ornament_slots)
	assert_eq(ornament_slots.position, playable_bag.position)
	assert_eq(ornament_slots.size, Vector2(767.0, 314.0))


func test_backpack_page_restores_placed_shop_item_after_cached_page_reopens():
	assert_not_null(item_db)
	assert_not_null(ornament_db)
	var manager = autofree(RunManagerScript.new())
	manager.is_run_active = true
	manager.current_shards = 100
	manager.current_backpack_items = [] as Array[Dictionary]
	manager.pending_item_rewards = [] as Array[Dictionary]
	manager.next_pending_item_uid = 1
	manager.current_ornaments = ["old_pocket_watch"] as Array[String]

	var page := BackpackPageScene.instantiate()
	page.run_manager_override = manager
	page.item_database_override = item_db
	page.ornament_database_override = ornament_db
	var page_battle_manager := page.get_node("BattleManager") as BattleManager
	page_battle_manager.run_manager_override = manager
	page_battle_manager.item_database_override = item_db
	page_battle_manager.ornament_database_override = ornament_db
	add_child_autofree(page)
	await get_tree().process_frame
	await get_tree().process_frame

	var pending_panel := page.get_node("ContentLayer/PendingItemPanel") as Control
	var pending_area := page.get_node("ContentLayer/PendingItemPanel/PendingItemArea") as Control
	assert_not_null(pending_panel)
	assert_not_null(pending_area)
	assert_false(pending_panel.visible)

	page.visible = false
	assert_true(manager.buy_shop_offer({
		"type": "item",
		"id": "paper_ball",
		"price": 1,
		"item_destination": RunManagerScript.ITEM_DEST_STAGING,
	}, item_db))
	var pending_uid := int(manager.pending_item_rewards[0].uid)
	assert_true(manager.place_pending_item_in_backpack(pending_uid, item_db))
	await get_tree().process_frame

	page.visible = true
	await get_tree().process_frame

	assert_true(manager.pending_item_rewards.is_empty())
	assert_false(pending_panel.visible)
	assert_eq(pending_area.get_child_count(), 0)
	assert_true(_backpack_page_has_rendered_item(page, "paper_ball"))


func test_ornament_slot_hover_uses_card_tooltip():
	assert_not_null(ornament_db)
	GlobalTooltip.hide()
	var container := Control.new()
	add_child_autofree(container)
	container.size = Vector2(767.0, 314.0)
	OrnamentSlotBarScript.render_to_container(container, ["old_pocket_watch"], ornament_db)

	var slot := container.get_child(0) as Button
	assert_not_null(slot)
	assert_eq(slot.tooltip_text, "")
	assert_true(slot.get_signal_connection_list("mouse_entered").size() > 0)
	assert_true(slot.get_signal_connection_list("mouse_exited").size() > 0)

	slot.mouse_entered.emit()
	await get_tree().create_timer(0.25).timeout
	var tooltip = GlobalTooltip._tooltip_instance
	assert_not_null(tooltip)
	assert_true(tooltip.is_panel_visible())
	var title_label = tooltip.get_node("PanelContainer/MarginContainer/VBoxContainer/TitleLabel")
	assert_eq(title_label.text, "Fehu")

	slot.mouse_exited.emit()
	await get_tree().create_timer(0.12).timeout
	assert_false(tooltip.is_panel_visible())

	var act_one = ornament_db.get_available_ornaments(1, ["old_pocket_watch"] as Array[String])
	for ornament in act_one:
		assert_true(ornament.earliest_act <= 1)
		assert_true(ornament.id != "old_pocket_watch")

	var all_available = ornament_db.get_available_ornaments(6, [] as Array[String])
	var available_ids = all_available.map(func(ornament): return ornament.id)
	for ornament_id in TOOL_ORNAMENT_IDS:
		assert_true(available_ids.has(ornament_id))

func test_run_manager_prevents_duplicate_ornaments():
	var manager = autofree(RunManagerScript.new())
	manager.current_ornaments = [] as Array[String]

	assert_true(manager.add_ornament("old_pocket_watch"))
	assert_false(manager.add_ornament("old_pocket_watch"))
	assert_eq(manager.current_ornaments, ["old_pocket_watch"])

	manager.current_ornaments.clear()
	for index in range(RunManagerScript.MAX_ORNAMENTS):
		assert_true(manager.add_ornament("ornament_%d" % index, false))
	assert_false(manager.add_ornament("overflow_ornament", false))
	assert_eq(manager.current_ornaments.size(), RunManagerScript.MAX_ORNAMENTS)


func _backpack_page_has_rendered_item(page: Control, item_id: String) -> bool:
	var backpack_ui := page.get_node_or_null("ContentLayer/GridPanel/BackpackUI") as Control
	if backpack_ui == null:
		return false
	for child in backpack_ui.get_children():
		if child.name == "GridContainer":
			continue
		var item_data = child.get("item_data") if child is Control else null
		if item_data != null and str(item_data.id) == item_id:
			return true
	return false


func test_old_pocket_watch_and_safety_pin_modify_sanity_loss_in_order():
	var manager = await _make_manager(["old_pocket_watch", "safety_pin"] as Array[String])
	var item = _make_draw_item(-1)

	manager._process_new_item_acquisition(item)
	assert_eq(gs.current_sanity, 100)

	manager._process_new_item_acquisition(item)
	assert_eq(gs.current_sanity, 100)

	manager._process_new_item_acquisition(item)
	assert_eq(gs.current_sanity, 98)

func test_dreamcatcher_filter_scores_every_three_draws():
	var manager = await _make_manager(["dreamcatcher_filter"] as Array[String])
	var item = _make_draw_item(0)

	manager._process_new_item_acquisition(item)
	manager._process_new_item_acquisition(item)
	assert_eq(gs.current_score, 0)

	manager._process_new_item_acquisition(item)
	assert_eq(gs.current_score, 3)

func test_echo_earring_scores_once_when_chain_hits_any_item():
	var manager = await _make_manager(["echo_earring"] as Array[String])
	var action = GameAction.new(GameAction.Type.IMPACT, "hit")

	manager._apply_ornament_impact_chain_resolved(null, [action] as Array[GameAction])

	assert_eq(gs.current_score, 2)

func test_guiding_compass_rotates_root_dream_after_empty_chain():
	var manager = await _make_manager(["guiding_compass"] as Array[String])
	var root = ItemData.new()
	root.id = "root_dream"
	root.direction = ItemData.Direction.RIGHT
	var source = BackpackManager.ItemInstance.new(root, Vector2i(1, 1))

	manager._apply_ornament_impact_chain_resolved(source, [] as Array[GameAction])

	assert_eq(root.direction, ItemData.Direction.DOWN)

func test_sturdy_strap_reduces_large_item_draw_cost():
	var manager = await _make_manager(["sturdy_strap"] as Array[String])
	var item = _make_draw_item(4)
	item.shape = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)] as Array[Vector2i]

	manager._process_new_item_acquisition(item)

	assert_eq(gs.current_sanity, 98)

func test_buckle_guide_scores_once_per_draw_for_same_direction_neighbors():
	var manager = await _make_manager(["buckle_guide"] as Array[String])
	_place_runtime_item(manager, "left", Vector2i(1, 1), [] as Array[String], 0, ItemData.Direction.RIGHT)
	var placed = _place_runtime_item(manager, "right", Vector2i(2, 1), [] as Array[String], 0, ItemData.Direction.RIGHT)

	manager._apply_ornament_item_placed(placed)
	manager._apply_ornament_item_placed(placed)
	assert_eq(gs.current_score, 3)

	manager.draw_count = 1
	manager._apply_ornament_item_placed(placed)
	assert_eq(gs.current_score, 6)

func test_pollution_ornaments_react_to_pollution_changes():
	var manager = await _make_manager(["sealed_bottle", "active_petri_dish", "corrosion_guide"] as Array[String])
	var paper = item_db.get_item_by_id("paper_ball")
	manager.backpack_manager.place_item(paper, Vector2i(1, 1))
	var instance = manager.backpack_manager.grid[Vector2i(1, 1)]

	instance.add_pollution(1)
	assert_eq(gs.current_score, 5)

	instance.add_pollution(1)
	assert_eq(gs.current_score, 8)

func test_pollution_chain_ornaments_apply_hit_thresholds():
	var manager = await _make_manager(["protective_gloves", "waste_receipt", "black_raincoat", "pathology_lens"] as Array[String])
	var target = _make_instance("polluted_waste", ["废弃物"] as Array[String], 4, ItemData.Direction.RIGHT, 5)

	manager._apply_ornament_impact_chain_resolved(null, [_impact_action(target)] as Array[GameAction])

	assert_eq(gs.current_score, 22)

func test_leaking_valve_adds_pollution_from_root_dream_hits():
	var manager = await _make_manager(["leaking_valve"] as Array[String])
	var source = _make_instance("root_dream", [] as Array[String])
	var target = _make_instance("target", [] as Array[String])

	manager._apply_ornament_impact_chain_resolved(source, [_impact_action(target)] as Array[GameAction])

	assert_eq(target.current_pollution, 1)

func test_stain_sticker_and_black_tide_bottle_add_pollution_on_draws():
	var manager = await _make_manager(["stain_sticker", "black_tide_bottle"] as Array[String])
	var waste = _place_runtime_item(manager, "paper_ball", Vector2i(1, 1), ["废弃物"] as Array[String], 1)
	var drawn_waste = _make_runtime_item("drawn_waste", ["废弃物"] as Array[String], 1)

	manager._apply_ornament_item_drawn(drawn_waste)
	assert_eq(waste.current_pollution, 1)

	manager.draw_count = 6
	manager._apply_ornament_item_drawn(_make_draw_item(0))
	assert_eq(waste.current_pollution, 2)

func test_purification_ornaments_score_and_restore_sanity_with_caps():
	var manager = await _make_manager(["purification_bell", "black_market_trash_bag"] as Array[String])
	gs.current_sanity = 50
	var waste = _place_runtime_item(manager, "paper_ball", Vector2i(1, 1), ["废弃物"] as Array[String], 1)
	waste.current_pollution = 5

	waste.current_pollution = 1
	assert_eq(gs.current_sanity, 55)
	assert_eq(gs.current_score, 8)

	waste.current_pollution = 0
	assert_eq(gs.current_sanity, 57)
	assert_eq(gs.current_score, 8)

func test_discard_ornaments_apply_once_and_count_discards():
	var manager = await _make_manager(["sanity_coin_purse", "light_pendant"] as Array[String])
	gs.current_sanity = 80
	var waste = _make_draw_item(0)
	waste.id = "paper_ball"
	waste.tags = ["废弃物"] as Array[String]
	waste.price = 5

	manager._apply_ornament_item_discarded(waste, null, false)
	manager._apply_ornament_item_discarded(waste, null, false)
	manager._apply_ornament_item_discarded(waste, null, false)

	assert_eq(gs.current_score, 10)
	assert_eq(gs.current_sanity, 82)

func test_chain_end_ornaments_score_from_hit_count_thresholds():
	var manager = await _make_manager(["chain_counter", "terminal_pressure_gauge"] as Array[String])
	var actions: Array[GameAction] = []
	for index in range(8):
		var action = GameAction.new(GameAction.Type.IMPACT, "hit")
		var item = _make_draw_item(0)
		item.runtime_id = 9000 + index
		action.item_instance = BackpackManager.ItemInstance.new(item, Vector2i(index, 0))
		actions.append(action)

	manager._apply_ornament_impact_chain_resolved(null, actions)

	assert_eq(gs.current_score, 16)

func test_terminal_pressure_gauge_counts_mechanical_hits_only():
	var manager = await _make_manager(["terminal_pressure_gauge"] as Array[String])
	var actions: Array[GameAction] = []
	for index in range(8):
		var action = GameAction.new(GameAction.Type.IMPACT, "hit")
		var item = _make_draw_item(0)
		item.tags = ["机械"] as Array[String]
		item.runtime_id = 9100 + index
		action.item_instance = BackpackManager.ItemInstance.new(item, Vector2i(index, 0))
		actions.append(action)

	manager._apply_ornament_impact_chain_resolved(null, actions)

	assert_eq(gs.current_score, 25)

func test_gear_oil_scores_successful_mechanical_transmissions_only():
	var manager = await _make_manager(["gear_oil"] as Array[String])
	var source_data = _make_draw_item(0)
	source_data.direction = ItemData.Direction.RIGHT
	var source = BackpackManager.ItemInstance.new(source_data, Vector2i(0, 1))

	var gear = item_db.get_item_by_id("small_gear")
	manager.backpack_manager.place_item(gear, Vector2i(1, 1))
	var first = manager.backpack_manager.grid[Vector2i(1, 1)]
	first.data.direction = ItemData.Direction.RIGHT

	var brake = item_db.get_item_by_id("brake_pad")
	manager.backpack_manager.place_item(brake, Vector2i(2, 1))

	var resolver = ImpactResolver.new(manager.backpack_manager, manager.context)
	var actions = resolver.resolve_impact(source.root_pos, ItemData.Direction.RIGHT, source)
	manager._apply_ornament_impact_chain_resolved(source, actions)

	assert_eq(gs.current_score, 2)

func test_gear_oil_ignores_mechanical_hits_without_transmission():
	var manager = await _make_manager(["gear_oil"] as Array[String])
	var source_data = _make_draw_item(0)
	source_data.direction = ItemData.Direction.RIGHT
	var source = BackpackManager.ItemInstance.new(source_data, Vector2i(0, 1))

	var gear = item_db.get_item_by_id("small_gear")
	manager.backpack_manager.place_item(gear, Vector2i(1, 1))
	var first = manager.backpack_manager.grid[Vector2i(1, 1)]
	first.data.direction = ItemData.Direction.DOWN

	var resolver = ImpactResolver.new(manager.backpack_manager, manager.context)
	var actions = resolver.resolve_impact(source.root_pos, ItemData.Direction.RIGHT, source)
	manager._apply_ornament_impact_chain_resolved(source, actions)

	assert_eq(gs.current_score, 0)

func test_universal_bearing_adds_bidirectional_transmission_inside_same_resolution():
	var manager = await _make_manager(["universal_bearing"] as Array[String])
	var source_data = _make_draw_item(0)
	source_data.direction = ItemData.Direction.RIGHT
	var source = BackpackManager.ItemInstance.new(source_data, Vector2i(0, 2))

	var gear = item_db.get_item_by_id("small_gear")
	manager.backpack_manager.place_item(gear, Vector2i(1, 2))
	var first = manager.backpack_manager.grid[Vector2i(1, 2)]
	first.data.direction = ItemData.Direction.RIGHT

	var upper = item_db.get_item_by_id("brake_pad")
	manager.backpack_manager.place_item(upper, Vector2i(1, 1))
	var lower = item_db.get_item_by_id("brake_pad")
	manager.backpack_manager.place_item(lower, Vector2i(1, 3))

	var resolver = ImpactResolver.new(manager.backpack_manager, manager.context)
	var actions = resolver.resolve_impact(source.root_pos, ItemData.Direction.RIGHT, source)
	var summary = resolver.get_current_resolution_summary()

	assert_eq(summary.mechanical_hit_count, 3)
	assert_eq(summary.bidirectional_transmission_count, 1)
	assert_eq(_impact_count(actions), 3)

func test_recoil_plate_queues_mechanical_filtered_recoil():
	var manager = await _make_manager(["recoil_plate"] as Array[String])
	var target_data = item_db.get_item_by_id("small_gear")
	manager.backpack_manager.place_item(target_data, Vector2i(2, 2))
	var target = manager.backpack_manager.grid[Vector2i(2, 2)]

	var action = GameAction.new(GameAction.Type.IMPACT, "hit")
	action.item_instance = target
	manager._apply_ornament_impact_chain_resolved(null, [action] as Array[GameAction])

	assert_eq(manager._impact_queue.size(), 1)
	assert_true(Array(manager._impact_queue[0].get("filters", [])).has("机械"))

func test_basic_mechanical_hit_ornaments_score_from_chain_summary():
	var manager = await _make_manager(["marble_spring", "tailing_spark", "return_ruler", "magnetic_pendant"] as Array[String])
	var source = _make_instance("root_dream", [] as Array[String], 0, ItemData.Direction.RIGHT)
	var first = _make_instance("small_gear", ["机械"] as Array[String], 0, ItemData.Direction.RIGHT)
	var second = _make_instance("plain_a", [] as Array[String])
	var third = _make_instance("plain_b", [] as Array[String])

	manager._apply_ornament_impact_chain_resolved(source, [_impact_action(first), _impact_action(second), _impact_action(third)] as Array[GameAction])

	assert_eq(gs.current_score, 22)

func test_overload_lamp_scores_on_consecutive_impact_draws():
	var manager = await _make_manager(["overload_lamp"] as Array[String])
	var target = _make_instance("target", [] as Array[String])
	manager.draw_count = 1
	manager._apply_ornament_impact_chain_resolved(null, [_impact_action(target)] as Array[GameAction])
	assert_eq(gs.current_score, 0)

	var actions: Array[GameAction] = []
	for index in range(5):
		actions.append(_impact_action(_make_instance("target_%d" % index, [] as Array[String])))
	manager.draw_count = 2
	manager._apply_ornament_impact_chain_resolved(null, actions)
	assert_eq(gs.current_score, 20)

func test_mixed_chain_ornaments_score_tags_waste_value_and_neighbors():
	var manager = await _make_manager(["kaleidoscope", "black_market_stamp", "fusion_badge"] as Array[String])
	var target = _place_runtime_item(manager, "mixed_waste", Vector2i(2, 2), ["机械", "废弃物", "污染"] as Array[String], 7)
	_place_runtime_item(manager, "same_tag_neighbor", Vector2i(3, 2), ["机械"] as Array[String])

	manager._apply_ornament_impact_chain_resolved(null, [_impact_action(target)] as Array[GameAction])

	assert_eq(gs.current_score, 20)

func _impact_count(actions: Array[GameAction]) -> int:
	var count = 0
	for action in actions:
		if action.type == GameAction.Type.IMPACT:
			count += 1
	return count

func _score_for_instance(actions: Array[GameAction], instance: BackpackManager.ItemInstance) -> int:
	var score = 0
	for action in actions:
		if action.type == GameAction.Type.NUMERIC and action.item_instance == instance and action.value.type == "score":
			score += int(action.value.amount)
	return score

func _total_tool_count(tools: Dictionary) -> int:
	var total = 0
	for count in tools.values():
		total += int(count)
	return total

func _pending_item_count(run_manager, item_id: String) -> int:
	var total := 0
	for entry in run_manager.pending_item_rewards:
		if str(entry.get("id", "")) == item_id:
			total += max(1, int(entry.get("stack_count", 1)))
	return total

func _pending_total_item_count(run_manager) -> int:
	var total := 0
	for entry in run_manager.pending_item_rewards:
		total += max(1, int(entry.get("stack_count", 1)))
	return total

func test_recycling_coupon_discounts_next_item_after_first_item_purchase():
	var manager = autofree(RunManagerScript.new())
	manager.current_shards = 100
	manager.current_ornaments = ["recycling_coupon"] as Array[String]
	manager.current_deck = [] as Array[String]
	manager.is_run_active = true
	var offer = {"type": "item", "id": "paper_ball", "price": 10}

	assert_eq(manager.get_current_shop_offer_price(offer), 10)
	assert_true(manager.buy_shop_offer(offer))
	assert_eq(manager.current_shards, 90)
	assert_eq(manager.get_current_shop_offer_price(offer), 8)
	assert_true(manager.buy_shop_offer(offer))
	assert_eq(manager.current_shards, 82)
	assert_eq(manager.get_current_shop_offer_price(offer), 10)

func test_tool_linked_score_ornaments_react_to_tool_usage():
	var manager = await _make_manager(["tool_belt", "specimen_pin_case", "recycling_hook"] as Array[String])
	var waste = _make_instance("paper_ball", ["废弃物"] as Array[String], 1)
	var pollution_tool = _make_tool("black_ink_drop", ["污染"] as Array[String])

	manager._apply_ornament_tool_used(pollution_tool, {"type": "item", "instance": waste}, {"success": true})
	assert_eq(gs.current_score, 9)

	var discard_tool = _make_tool("recycling_clip", ["丢弃"] as Array[String])
	manager._apply_ornament_tool_used(discard_tool, {"type": "discard"}, {"success": true})
	assert_eq(gs.current_score, 13)

	gs.current_sanity = 50
	var discarded_waste = _make_runtime_item("paper_ball", ["废弃物"] as Array[String], 1)
	manager._apply_ornament_item_discarded(discarded_waste, null, false)
	manager._apply_ornament_item_discarded(discarded_waste, null, false)
	manager._apply_ornament_item_discarded(discarded_waste, null, false)
	assert_eq(gs.current_sanity, 52)

func test_calibration_screwdriver_scores_next_successful_mechanical_transmission():
	var manager = await _make_manager(["calibration_screwdriver"] as Array[String])
	var source_data = _make_draw_item(0)
	source_data.direction = ItemData.Direction.RIGHT
	var source = BackpackManager.ItemInstance.new(source_data, Vector2i(0, 1))

	var control_gear = _make_runtime_item("control_mech", ["机械"] as Array[String], 0, ItemData.Direction.RIGHT)
	manager.backpack_manager.place_item(control_gear, Vector2i(1, 1))
	var control_first = manager.backpack_manager.grid[Vector2i(1, 1)]
	var control_brake = item_db.get_item_by_id("brake_pad")
	manager.backpack_manager.place_item(control_brake, Vector2i(2, 1))
	var control_resolver = ImpactResolver.new(manager.backpack_manager, manager.context)
	var control_actions = control_resolver.resolve_impact(source.root_pos, ItemData.Direction.RIGHT, source)
	var base_score = _score_for_instance(control_actions, control_first)

	manager.backpack_manager.grid.clear()
	var gear = _make_runtime_item("calibrated_mech", ["机械"] as Array[String], 0, ItemData.Direction.RIGHT)
	manager.backpack_manager.place_item(gear, Vector2i(1, 1))
	var first = manager.backpack_manager.grid[Vector2i(1, 1)]

	var brake = item_db.get_item_by_id("brake_pad")
	manager.backpack_manager.place_item(brake, Vector2i(2, 1))

	var tool = _make_tool("turning_screw", [] as Array[String])
	manager._apply_ornament_tool_used(tool, {"type": "item", "instance": first}, {"success": true})
	assert_eq(int(first.data.get_meta("orn_calibration_bonus_pending", 0)), 1)

	var resolver = ImpactResolver.new(manager.backpack_manager, manager.context)
	var actions = resolver.resolve_impact(source.root_pos, ItemData.Direction.RIGHT, source)

	assert_eq(_score_for_instance(actions, first) - base_score, 5)
	assert_eq(int(first.data.get_meta("orn_calibration_bonus_pending", 0)), 0)

func test_universal_toolbox_rewards_once_after_three_target_types():
	var manager = await _make_manager(["universal_toolbox"] as Array[String])
	rm.current_tools = {}
	var tool = _make_tool("small_patch", [] as Array[String])

	manager._apply_ornament_tool_used(tool, {"type": "item"}, {"success": true})
	manager._apply_ornament_tool_used(tool, {"type": "discard"}, {"success": true})
	assert_eq(gs.current_score, 0)

	manager._apply_ornament_tool_used(tool, {"type": "dreamcatcher"}, {"success": true})
	assert_eq(gs.current_score, 12)
	assert_eq(_pending_total_item_count(rm), 1)
	assert_eq(_pending_item_count(rm, "small_patch"), 0)

	manager._apply_ornament_tool_used(tool, {"type": "item"}, {"success": true})
	assert_eq(gs.current_score, 12)

func test_late_game_score_modifiers_bonus_and_multiplier():
	var manager = await _make_manager(["nightmare_contract", "twilight_hourglass", "marble_spring"] as Array[String])
	var source = _make_instance("root_dream", [] as Array[String])
	gs.current_sanity = 19

	manager.draw_count = 1
	manager._apply_ornament_item_drawn(_make_draw_item(0))
	manager._apply_ornament_impact_chain_resolved(source, [] as Array[GameAction])
	assert_eq(gs.current_score, 4)

	manager.draw_count = 15
	manager._apply_ornament_item_drawn(_make_draw_item(0))
	manager._apply_ornament_impact_chain_resolved(source, [] as Array[GameAction])
	assert_eq(gs.current_score, 9)

func test_collection_cabinet_scores_for_category_diversity_on_battle_start():
	var manager = await _make_manager([
		"collection_cabinet",
		"old_pocket_watch",
		"sealed_bottle",
		"recycling_hook",
		"gear_oil"
	] as Array[String])

	assert_eq(gs.current_score, 12)
	assert_eq(manager.active_ornaments.size(), 5)

func test_tri_phase_crown_requires_pollution_tool_and_large_chain_once():
	var manager = await _make_manager(["tri_phase_crown"] as Array[String])
	var polluted = _place_runtime_item(manager, "polluted", Vector2i(1, 1), [] as Array[String])
	manager._on_ornament_pollution_changed(polluted, 0, 1)
	manager._apply_ornament_tool_used(_make_tool("black_ink_drop", ["污染"] as Array[String]), {"type": "item"}, {"success": true})
	var actions: Array[GameAction] = []
	for index in range(5):
		actions.append(_impact_action(_make_instance("hit_%d" % index, [] as Array[String])))

	manager._apply_ornament_impact_chain_resolved(null, actions)
	manager._apply_ornament_impact_chain_resolved(null, actions)

	assert_eq(gs.current_score, 45)

func test_empty_dream_trophy_bonus_requires_target_and_score_margin():
	var old_ornaments: Array[String] = Array(rm.current_ornaments).duplicate()
	var old_route_index = rm.current_route_index
	var old_act = rm.current_act

	rm.current_ornaments = ["empty_dream_trophy"] as Array[String]
	rm.current_route_index = 4
	rm.current_act = 1
	assert_false(rm.has_empty_dream_trophy_reward_bonus(95))
	assert_true(rm.has_empty_dream_trophy_reward_bonus(96))

	rm.current_ornaments = [] as Array[String]
	assert_false(rm.has_empty_dream_trophy_reward_bonus(96))

	rm.current_ornaments = ["empty_dream_trophy"] as Array[String]
	rm.current_route_index = 0
	assert_false(rm.has_empty_dream_trophy_reward_bonus(999))

	rm.current_ornaments = old_ornaments
	rm.current_route_index = old_route_index
	rm.current_act = old_act
