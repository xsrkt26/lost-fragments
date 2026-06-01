extends GutTest

const RunManagerScript = preload("res://src/autoload/run_manager.gd")
const BattleManagerScript = preload("res://src/battle/battle_manager.gd")
const MainGameUIScript = preload("res://src/ui/main_game_ui.gd")
const ToolPanelPresenter = preload("res://src/ui/battle/tool_panel_presenter.gd")
const MockItemUI = preload("res://test/support/mock_item_ui.gd")

var item_db
var tool_db
var root_rm
var root_snapshot := {}

func before_each():
	item_db = get_node_or_null("/root/ItemDatabase")
	tool_db = get_node_or_null("/root/ToolDatabase")
	root_rm = get_node_or_null("/root/RunManager")
	if item_db and item_db.items.is_empty():
		item_db.load_all_items()
	if tool_db and tool_db.tools.is_empty():
		tool_db.load_all_tools()
	if root_rm:
		root_snapshot = root_rm.serialize_run()
		root_rm.is_run_active = false
		root_rm.current_tools = {}

func after_each():
	if root_rm and not root_snapshot.is_empty():
		root_rm.deserialize_run(root_snapshot)
	root_snapshot = {}

func test_tool_database_loads_official_pool():
	var tools = tool_db.get_all_tools()
	var ids = tools.map(func(tool): return tool.id)

	assert_eq(tools.size(), 12)
	assert_true(ids.has("small_patch"))
	assert_true(ids.has("dream_value_candy"))
	assert_true(ids.has("blank_talisman"))
	var tool_item = item_db.get_item_by_id("small_patch")
	assert_not_null(tool_item)
	assert_true(tool_item.tags.has("道具"))
	assert_true(bool(tool_item.get_meta("is_tool", false)))

func test_tool_database_loads_official_icons():
	for tool in tool_db.get_all_tools():
		assert_true(tool.icon_path.begins_with("res://assets/ui/tools/"), "Unexpected tool icon path: %s" % tool.icon_path)
		assert_false(tool.icon_path.contains("sourceImage"), "Tool icon should not load from sourceImage: %s" % tool.icon_path)
		assert_not_null(tool.icon, "Missing tool icon for %s" % tool.id)
		if tool.icon != null:
			assert_eq(tool.icon.resource_path, tool.icon_path)
			assert_eq(tool.icon.get_width(), 256)
			assert_eq(tool.icon.get_height(), 256)

func test_run_manager_grants_tools_as_pending_stackable_items():
	var rm = autofree(RunManagerScript.new())
	rm.is_run_active = false

	assert_true(rm.grant_tool("small_patch", 2, tool_db))
	assert_true(rm.grant_tool("small_patch", 1, tool_db))
	assert_true(rm.current_tools.is_empty())
	assert_eq(_pending_stack_count(rm, "small_patch"), 3)

	var restored = autofree(RunManagerScript.new())
	restored.deserialize_run(rm.serialize_run())

	assert_true(restored.current_tools.is_empty())
	assert_eq(_pending_stack_count(restored, "small_patch"), 3)

func test_reward_shop_and_event_can_grant_tools():
	var rm = autofree(RunManagerScript.new())
	rm.is_run_active = false
	rm.current_shards = 50

	assert_true(rm.apply_reward({"type": "tool", "id": "black_ink_drop", "amount": 2}))
	assert_eq(_pending_stack_count(rm, "black_ink_drop"), 2)

	assert_true(rm.buy_shop_offer({"type": "tool", "id": "extension_hook", "price": 7}))
	assert_eq(rm.current_shards, 43)
	assert_eq(_pending_stack_count(rm, "extension_hook"), 1)

	assert_true(rm.apply_event_choice({
		"effects": [{"type": "tool", "id": "dream_value_candy", "amount": 1}]
	}))
	assert_eq(_pending_stack_count(rm, "dream_value_candy"), 1)

func test_tool_use_consumes_only_on_legal_target():
	var battle = add_child_autofree(BattleManagerScript.new())
	await get_tree().process_frame
	var paper = _place_item(battle, "paper_ball", Vector2i(2, 2))
	root_rm.current_tools = {"black_ink_drop": 1, "dream_value_candy": 1}

	assert_false(battle.request_use_tool("dream_value_candy", {"type": "item", "instance": paper}))
	assert_eq(root_rm.get_tool_count("dream_value_candy"), 1)

	assert_true(battle.request_use_tool("black_ink_drop", {"type": "item", "instance": paper}))
	assert_eq(root_rm.get_tool_count("black_ink_drop"), 0)
	assert_eq(paper.current_pollution, 2)

func test_disinfectant_scores_by_purified_pollution():
	var battle = add_child_autofree(BattleManagerScript.new())
	await get_tree().process_frame
	battle.backpack_manager.grid.clear()
	root_rm.current_tools = {"disinfectant_spray": 1}

	var paper = _place_item(battle, "paper_ball", Vector2i(4, 2))
	paper.current_pollution = 3
	var score_before = GameState.current_score
	assert_true(battle.request_use_tool("disinfectant_spray", {"type": "item", "instance": paper}))
	assert_eq(paper.current_pollution, 0)
	assert_eq(GameState.current_score, score_before + 9)

func test_tool_item_use_consumes_stack_only_on_legal_target():
	var battle = add_child_autofree(BattleManagerScript.new())
	await get_tree().process_frame
	battle.backpack_manager.grid.clear()
	var paper = _place_item(battle, "paper_ball", Vector2i(2, 2))
	var candy = _place_tool_item(battle, "dream_value_candy", Vector2i(1, 1), 1)
	var candy_ui = _make_mock_item_ui(candy)

	assert_false(battle.request_use_tool_item(candy_ui, {"type": "item", "instance": paper}))
	assert_true(battle.backpack_manager.grid.has(Vector2i(1, 1)))
	assert_eq(candy.stack_count, 1)

	var ink = _place_tool_item(battle, "black_ink_drop", Vector2i(1, 2), 2)
	var ink_ui = _make_mock_item_ui(ink)
	assert_true(battle.request_use_tool_item(ink_ui, {"type": "item", "instance": paper}))
	assert_true(battle.backpack_manager.grid.has(Vector2i(1, 2)))
	assert_eq(ink.stack_count, 1)
	assert_eq(paper.current_pollution, 2)

	assert_true(battle.request_use_tool_item(ink_ui, {"type": "item", "instance": paper}))
	assert_false(battle.backpack_manager.grid.has(Vector2i(1, 2)))
	assert_eq(paper.current_pollution, 4)

func test_placing_tool_on_same_tool_merges_stack():
	var battle = add_child_autofree(BattleManagerScript.new())
	await get_tree().process_frame
	battle.backpack_manager.grid.clear()
	var first = _place_tool_item(battle, "small_patch", Vector2i(1, 1), 2)
	var second = _place_tool_item(battle, "small_patch", Vector2i(2, 1), 3)
	var second_ui = _make_mock_item_ui(second)

	battle.request_place_item(second_ui, Vector2i(1, 1))

	assert_eq(first.stack_count, 5)
	assert_true(battle.backpack_manager.grid.has(Vector2i(1, 1)))
	assert_false(battle.backpack_manager.grid.has(Vector2i(2, 1)))

func test_tool_button_click_toggles_selected_tool():
	var ui = autofree(MainGameUIScript.new())
	var slots = autofree(HBoxContainer.new())
	var button = autofree(Button.new())
	button.set_meta("tool_id", "small_patch")
	slots.add_child(button)
	ui.tool_slot_area = slots

	var down = InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	var up = InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false

	ui._on_tool_button_gui_input(down, "small_patch", button)
	ui._on_tool_button_gui_input(up, "small_patch", button)
	assert_eq(ui._selected_tool_id, "small_patch")

	ui._on_tool_button_gui_input(down, "small_patch", button)
	ui._on_tool_button_gui_input(up, "small_patch", button)
	assert_eq(ui._selected_tool_id, "")

func test_tool_panel_renders_loaded_icon_and_count():
	var panel = autofree(Control.new())
	var slots = autofree(HBoxContainer.new())

	ToolPanelPresenter.render(
		panel,
		slots,
		[{"id": "small_patch", "title": "small_patch", "count": 2}],
		tool_db,
		"",
		Callable()
	)

	assert_true(panel.visible)
	assert_eq(slots.get_child_count(), 1)
	var button := slots.get_child(0) as Button
	assert_not_null(button)
	assert_eq(button.text, "")
	var icon := button.get_node_or_null("ToolIcon") as TextureRect
	assert_not_null(icon)
	assert_not_null(icon.texture)
	if icon.texture != null:
		assert_eq(icon.texture.resource_path, "res://assets/ui/tools/small_patch.png")
		assert_eq(icon.stretch_mode, TextureRect.STRETCH_KEEP_ASPECT_CENTERED)
	var count_label := button.get_node_or_null("CountLabel") as Label
	assert_not_null(count_label)
	assert_eq(count_label.text, "x2")

func _place_item(battle: BattleManager, item_id: String, pos: Vector2i):
	var item = item_db.get_item_by_id(item_id)
	assert_not_null(item)
	assert_true(battle.backpack_manager.place_item(item, pos))
	return battle.backpack_manager.grid[pos]

func _place_tool_item(battle: BattleManager, tool_id: String, pos: Vector2i, stack_count: int):
	var item = item_db.get_item_by_id(tool_id)
	assert_not_null(item)
	item.set_meta("stack_count", stack_count)
	assert_true(battle.backpack_manager.place_item(item, pos))
	return battle.backpack_manager.grid[pos]

func _make_mock_item_ui(instance: BackpackManager.ItemInstance) -> Control:
	var item_ui = autofree(MockItemUI.new())
	item_ui.item_instance = instance
	item_ui.item_data = instance.data
	return item_ui

func _pending_stack_count(rm, item_id: String) -> int:
	for entry in rm.pending_item_rewards:
		if str(entry.get("id", "")) == item_id:
			return max(1, int(entry.get("stack_count", 1)))
	return 0
