extends GutTest

var run_manager
var item_db

func before_each():
	run_manager = autofree(load("res://src/autoload/run_manager.gd").new())
	run_manager.is_run_active = true
	item_db = get_node_or_null("/root/ItemDatabase")
	if item_db and item_db.items.is_empty():
		item_db.load_all_items()

func test_save_backpack_filters_derived_items_and_pollution():
	var backpack = autofree(BackpackManager.new())
	backpack.setup_grid(7, 7, 5, 5)
	var tin_can: ItemData = item_db.get_item_by_id("tin_can").duplicate(true)
	tin_can.direction = ItemData.Direction.DOWN
	var apple_core: ItemData = item_db.get_item_by_id("apple_core")

	backpack.place_item(tin_can, Vector2i(1, 1))
	backpack.grid[Vector2i(1, 1)].current_pollution = 5
	backpack.place_item(apple_core, Vector2i(3, 3))

	run_manager.save_backpack_state(backpack)

	assert_eq(run_manager.current_backpack_items.size(), 1)
	assert_eq(run_manager.current_backpack_items[0].id, "tin_can")
	assert_eq(run_manager.current_backpack_items[0].direction, ItemData.Direction.DOWN)
	assert_false(run_manager.current_backpack_items[0].has("current_pollution"))

func test_restore_backpack_rebuilds_saved_items_without_pollution():
	run_manager.current_backpack_items.clear()
	run_manager.current_backpack_items.append({
		"id": "tin_can",
		"x": 1,
		"y": 1,
		"direction": ItemData.Direction.DOWN,
		"shape": [{"x": 0, "y": 0}, {"x": 1, "y": 0}],
		"runtime_id": 1234
	})
	var backpack = autofree(BackpackManager.new())
	backpack.setup_grid(7, 7, 5, 5)

	run_manager.restore_backpack_state(backpack, item_db)

	var instances = backpack.get_all_instances()
	assert_eq(instances.size(), 2)
	var tin_can = _find_instance(backpack, "tin_can")
	assert_not_null(tin_can)
	assert_eq(tin_can.root_pos, Vector2i(1, 1))
	assert_eq(tin_can.data.direction, ItemData.Direction.DOWN)
	assert_eq(tin_can.data.runtime_id, 1234)
	assert_eq(tin_can.current_pollution, 0)

func test_restore_backpack_preserves_saved_position_on_blocked_stage_cell():
	run_manager.current_backpack_items.clear()
	run_manager.current_backpack_items.append({
		"id": "paper_ball",
		"x": 1,
		"y": 1,
		"direction": ItemData.Direction.RIGHT,
		"shape": [{"x": 0, "y": 0}],
		"runtime_id": 5678
	})
	var backpack = autofree(BackpackManager.new())
	backpack.setup_grid(7, 7, 5, 5)
	backpack.set_blocked_cells([Vector2i(1, 1), Vector2i(5, 5)] as Array[Vector2i])

	run_manager.restore_backpack_state(backpack, item_db)

	var paper = _find_instance(backpack, "paper_ball")
	assert_not_null(paper)
	assert_eq(paper.root_pos, Vector2i(1, 1))
	assert_eq(paper.data.runtime_id, 5678)
	assert_true(backpack.is_pos_blocked(Vector2i(1, 1)))
	assert_false(backpack.can_place_item(item_db.get_item_by_id("paper_ball"), Vector2i(5, 5)))

func test_restore_backpack_moves_root_dream_off_blocked_cell():
	run_manager.current_backpack_items.clear()
	run_manager.current_backpack_items.append({
		"id": "root_dream",
		"x": 1,
		"y": 1,
		"direction": ItemData.Direction.RIGHT,
		"shape": [{"x": 0, "y": 0}],
		"runtime_id": -1
	})
	var backpack = autofree(BackpackManager.new())
	backpack.setup_grid(7, 7, 5, 5)
	backpack.set_blocked_cells([Vector2i(1, 1)] as Array[Vector2i])

	run_manager.restore_backpack_state(backpack, item_db)

	var root = _find_instance(backpack, "root_dream")
	assert_not_null(root)
	assert_eq(root.root_pos, Vector2i(3, 3))

func test_restore_backpack_preserves_saved_root_dream_position():
	run_manager.current_backpack_items.clear()
	run_manager.current_backpack_items.append({
		"id": "root_dream",
		"x": 1,
		"y": 1,
		"direction": ItemData.Direction.RIGHT,
		"shape": [{"x": 0, "y": 0}],
		"runtime_id": -1
	})
	var backpack = autofree(BackpackManager.new())
	backpack.setup_grid(7, 7, 5, 5)

	run_manager.restore_backpack_state(backpack, item_db)

	var root = _find_instance(backpack, "root_dream")
	assert_not_null(root)
	assert_eq(root.root_pos, Vector2i(1, 1))

func test_restore_backpack_does_not_move_root_dream_over_center_item():
	run_manager.current_backpack_items.clear()
	run_manager.current_backpack_items.append({
		"id": "root_dream",
		"x": 1,
		"y": 1,
		"direction": ItemData.Direction.RIGHT,
		"shape": [{"x": 0, "y": 0}],
		"runtime_id": -1
	})
	run_manager.current_backpack_items.append({
		"id": "paper_ball",
		"x": 3,
		"y": 3,
		"direction": ItemData.Direction.RIGHT,
		"shape": [{"x": 0, "y": 0}],
		"runtime_id": 9988
	})
	var backpack = autofree(BackpackManager.new())
	backpack.setup_grid(7, 7, 5, 5)

	run_manager.restore_backpack_state(backpack, item_db)

	var root = _find_instance(backpack, "root_dream")
	var paper = _find_instance(backpack, "paper_ball")
	assert_not_null(root)
	assert_not_null(paper)
	assert_eq(root.root_pos, Vector2i(1, 1))
	assert_eq(paper.root_pos, Vector2i(3, 3))

func test_restore_backpack_repairs_root_dream_saved_shape():
	run_manager.current_backpack_items.clear()
	run_manager.current_backpack_items.append({
		"id": "root_dream",
		"x": 0,
		"y": 0,
		"direction": ItemData.Direction.DOWN,
		"shape": [{"x": 0, "y": 0}, {"x": 0, "y": 1}],
		"runtime_id": -1
	})
	var backpack = autofree(BackpackManager.new())
	backpack.setup_grid(7, 7, 5, 5)

	run_manager.restore_backpack_state(backpack, item_db)

	var root = _find_instance(backpack, "root_dream")
	assert_not_null(root)
	assert_eq(root.root_pos, Vector2i(3, 3))
	assert_eq(root.data.direction, ItemData.Direction.DOWN)
	assert_eq(root.data.shape, [Vector2i(0, 0)] as Array[Vector2i])
	assert_false(backpack.grid.has(Vector2i(3, 4)))

func test_new_run_starts_with_root_dream():
	run_manager.start_new_run()

	assert_eq(run_manager.current_backpack_items.size(), 1)
	assert_eq(run_manager.current_backpack_items[0].id, "root_dream")
	assert_eq(run_manager.current_backpack_items[0].x, 3)
	assert_eq(run_manager.current_backpack_items[0].y, 3)

func test_restore_backpack_adds_root_dream_for_old_saves():
	run_manager.current_backpack_items.clear()
	var backpack = autofree(BackpackManager.new())
	backpack.setup_grid(7, 7, 5, 5)

	run_manager.restore_backpack_state(backpack, item_db)

	var root = _find_instance(backpack, "root_dream")
	assert_not_null(root)
	assert_eq(root.root_pos, Vector2i(3, 3))
	assert_eq(root.data.direction, ItemData.Direction.RIGHT)

func test_restore_backpack_adds_root_dream_at_default_center_when_available():
	run_manager.current_backpack_items.clear()
	run_manager.current_backpack_items.append({
		"id": "paper_ball",
		"x": 1,
		"y": 1,
		"direction": ItemData.Direction.RIGHT,
		"shape": [{"x": 0, "y": 0}],
		"runtime_id": 4321
	})
	var backpack = autofree(BackpackManager.new())
	backpack.setup_grid(7, 7, 5, 5)

	run_manager.restore_backpack_state(backpack, item_db)

	var root = _find_instance(backpack, "root_dream")
	assert_not_null(root)
	assert_eq(root.root_pos, Vector2i(3, 3))
	assert_true(backpack.can_place_item(item_db.get_item_by_id("root_dream"), Vector2i(2, 1)))

func test_restore_backpack_adds_root_dream_at_first_available_slot_when_center_blocked():
	run_manager.current_backpack_items.clear()
	run_manager.current_backpack_items.append({
		"id": "paper_ball",
		"x": 3,
		"y": 3,
		"direction": ItemData.Direction.RIGHT,
		"shape": [{"x": 0, "y": 0}],
		"runtime_id": 4321
	})
	var backpack = autofree(BackpackManager.new())
	backpack.setup_grid(7, 7, 5, 5)

	run_manager.restore_backpack_state(backpack, item_db)

	var root = _find_instance(backpack, "root_dream")
	assert_not_null(root)
	assert_eq(root.root_pos, Vector2i(1, 1))

func test_restore_required_item_does_not_mutate_database_resource():
	var root_resource: ItemData = item_db.get_item_by_id("root_dream")
	var original_direction = root_resource.direction
	var original_shape = root_resource.shape.duplicate()
	root_resource.direction = ItemData.Direction.DOWN
	root_resource.shape = [Vector2i(0, 0), Vector2i(0, 1)] as Array[Vector2i]

	run_manager.current_backpack_items.clear()
	var backpack = autofree(BackpackManager.new())
	backpack.setup_grid(7, 7, 5, 5)
	run_manager.restore_backpack_state(backpack, item_db)

	var observed_direction = root_resource.direction
	var observed_shape = root_resource.shape.duplicate()
	root_resource.direction = original_direction
	root_resource.shape = original_shape

	assert_eq(observed_direction, ItemData.Direction.DOWN)
	assert_eq(observed_shape, [Vector2i(0, 0), Vector2i(0, 1)] as Array[Vector2i])

func _find_instance(backpack: BackpackManager, item_id: String):
	for instance in backpack.get_all_instances():
		if instance.data.id == item_id:
			return instance
	return null
