extends GutTest

var backpack: BackpackManager

func before_each():
	backpack = autofree(BackpackManager.new())
	backpack.setup_grid(5, 5)

func test_setup_grid():
	assert_eq(backpack.grid_width, 5)
	assert_eq(backpack.grid_height, 5)
	assert_eq(backpack.grid.size(), 0)

func test_can_place_item_out_of_bounds():
	var item = ItemData.new()
	var s: Array[Vector2i] = [Vector2i(0, 0)]
	item.shape = s
	
	assert_true(backpack.can_place_item(item, Vector2i(0, 0)), "Should place at 0,0")
	assert_false(backpack.can_place_item(item, Vector2i(-1, 0)), "Should not place at negative x")
	assert_false(backpack.can_place_item(item, Vector2i(5, 5)), "Should not place outside bounds")

func test_can_place_item_rejects_null_or_empty_shape():
	var empty_shape_item = ItemData.new()
	empty_shape_item.shape = [] as Array[Vector2i]

	assert_false(backpack.can_place_item(null, Vector2i.ZERO))
	assert_false(backpack.can_place_item(empty_shape_item, Vector2i.ZERO))

func test_can_place_item_overlap():
	var item1 = ItemData.new()
	var s1: Array[Vector2i] = [Vector2i(0, 0)]
	item1.shape = s1
	backpack.place_item(item1, Vector2i(2, 2))
	
	var item2 = ItemData.new()
	var s2: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0)]
	item2.shape = s2
	
	assert_false(backpack.can_place_item(item2, Vector2i(1, 2)), "Should detect overlap")
	assert_true(backpack.can_place_item(item2, Vector2i(3, 2)), "Should place cleanly")

func test_place_item_creates_unique_instance():
	var item = ItemData.new()
	item.item_name = "Test Item"
	var s: Array[Vector2i] = [Vector2i(0, 0)]
	item.shape = s
	
	backpack.place_item(item, Vector2i(1, 1))
	var instance = backpack.grid[Vector2i(1, 1)]
	
	assert_ne(instance.data, item, "Data should be duplicated")
	assert_eq(instance.data.item_name, "Test Item")
	assert_eq(instance.current_pollution, 0)
	
	instance.add_pollution(5)
	assert_eq(instance.current_pollution, 5)

func test_replace_item_data_preserves_runtime_id_for_same_shape():
	var original = ItemData.new()
	original.id = "original"
	original.item_name = "Original"
	original.runtime_id = 7001
	var original_shape: Array[Vector2i] = [Vector2i(0, 0)]
	original.shape = original_shape
	backpack.place_item(original, Vector2i(1, 1))
	var old_instance = backpack.grid[Vector2i(1, 1)]

	var replacement = ItemData.new()
	replacement.id = "replacement"
	replacement.item_name = "Replacement"
	var replacement_shape: Array[Vector2i] = [Vector2i(0, 0)]
	replacement.shape = replacement_shape

	var events = []
	backpack.item_data_replaced.connect(func(old_data, new_instance): events.append([old_data, new_instance]))

	assert_true(backpack.replace_item_data(Vector2i(1, 1), replacement))
	var new_instance = backpack.grid[Vector2i(1, 1)]

	assert_eq(new_instance, old_instance)
	assert_eq(new_instance.data.id, "replacement")
	assert_eq(new_instance.data.runtime_id, 7001)
	assert_eq(events.size(), 1)
	assert_eq(events[0][0].id, "original")
	assert_eq(events[0][1], new_instance)

func test_replace_item_data_preserves_runtime_id_when_shape_changes():
	var original = ItemData.new()
	original.id = "original"
	original.runtime_id = 7002
	var original_shape: Array[Vector2i] = [Vector2i(0, 0)]
	original.shape = original_shape
	backpack.place_item(original, Vector2i(1, 1))

	var replacement = ItemData.new()
	replacement.id = "wide"
	var replacement_shape: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0)]
	replacement.shape = replacement_shape

	assert_true(backpack.replace_item_data(Vector2i(1, 1), replacement))
	var new_instance = backpack.grid[Vector2i(1, 1)]

	assert_eq(new_instance.data.id, "wide")
	assert_eq(new_instance.data.runtime_id, 7002)
	assert_eq(backpack.grid[Vector2i(2, 1)], new_instance)

func test_get_next_item_pos():
	var item1 = ItemData.new()
	var s1: Array[Vector2i] = [Vector2i(0, 0)]
	item1.shape = s1
	backpack.place_item(item1, Vector2i(1, 1))
	
	var item2 = ItemData.new()
	var s2: Array[Vector2i] = [Vector2i(0, 0)]
	item2.shape = s2
	backpack.place_item(item2, Vector2i(4, 1))
	
	var next_pos = backpack.get_next_item_pos(Vector2i(1, 1), ItemData.Direction.RIGHT)
	assert_eq(next_pos, Vector2i(4, 1), "Should find item to the right")
	
	var no_pos = backpack.get_next_item_pos(Vector2i(4, 1), ItemData.Direction.RIGHT)
	assert_eq(no_pos, Vector2i(-1, -1), "Should not find anything")
