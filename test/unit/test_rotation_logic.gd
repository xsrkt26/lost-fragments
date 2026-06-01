extends "res://addons/gut/test.gd"

var ItemData = load("res://src/core/item_data.gd")
var BackpackManager = load("res://src/core/backpack/backpack_manager.gd")
var BattleManager = load("res://src/battle/battle_manager.gd")
const MockItemUIBase = preload("res://test/support/mock_item_ui.gd")

class MockItemUI extends MockItemUIBase:
	pass

class MockBackpackUI extends Control:
	var item_ui_map = {}
	var grid_width = 7
	var grid_height = 7
	
	# UI 3.0 尺寸 (适配 7x7 塞入 723x684)
	const GRID_STEP = Vector2(103.2857, 97.7142)
	const SLOT_HALF = Vector2(51.6428, 48.8571)

	func setup(_context): pass
	
	func get_grid_pos_at(center_pos: Vector2) -> Vector2i:
		var res = Vector2i(floori(center_pos.x / GRID_STEP.x), floori(center_pos.y / GRID_STEP.y))
		if res.x < 0 or res.x >= grid_width or res.y < 0 or res.y >= grid_height:
			return Vector2i(-1, -1)
		return res
		
	func add_item_visual(_item_ui, _pos): pass
	func update_item_mapping(_old, _new): pass

func after_all():
	await get_tree().create_timer(0.25).timeout

func test_item_data_rotation_normalization_1x2():
	var item = ItemData.new()
	item.item_name = "Tin Can"
	item.shape = [Vector2i(0, 0), Vector2i(0, 1)] as Array[Vector2i]
	item.direction = ItemData.Direction.UP
	
	item.rotate_90()
	
	assert_eq(item.direction, ItemData.Direction.RIGHT)
	assert_true(item.shape.has(Vector2i(0, 0)))
	assert_true(item.shape.has(Vector2i(1, 0)))
	assert_eq(item.shape.size(), 2)

func test_item_data_rotation_square_no_shape_change():
	var item = ItemData.new()
	item.item_name = "Box"
	item.shape = [Vector2i(0,0), Vector2i(1,0), Vector2i(0,1), Vector2i(1,1)] as Array[Vector2i]
	item.direction = ItemData.Direction.UP
	
	var old_shape = item.shape.duplicate()
	item.rotate_90()
	
	assert_eq(item.direction, ItemData.Direction.RIGHT)
	assert_eq(item.shape, old_shape)

func test_backpack_remove_by_runtime_id():
	var manager = autofree(BackpackManager.new())
	manager.setup_grid(7, 7, 5, 5)
	
	var item = ItemData.new()
	item.runtime_id = 12345
	item.shape = [Vector2i(0, 0), Vector2i(0, 1)] as Array[Vector2i]
	
	manager.place_item(item, Vector2i(1, 1))
	assert_true(manager.grid.has(Vector2i(1, 1)))
	
	manager.remove_by_runtime_id(12345)
	assert_false(manager.grid.has(Vector2i(1, 1)))

func test_rotation_success_mid_grid_1x3():
	var manager = autofree(BattleManager.new())
	add_child(manager)
	manager.backpack_manager.setup_grid(7, 7, 5, 5)
	var mock_bp_ui = autofree(MockBackpackUI.new())
	add_child(mock_bp_ui)
	manager.backpack_ui = mock_bp_ui
	
	var plank = ItemData.new(); plank.runtime_id = 201
	plank.shape = [Vector2i(0,0), Vector2i(1,0), Vector2i(2,0)] as Array[Vector2i]
	manager.backpack_manager.place_item(plank, Vector2i(1, 2))
	
	var rotated_data = manager.backpack_manager.grid[Vector2i(1, 2)].data
	# 测试逻辑现在由 manager 内部处理旋转

	
	var mock_ui = autofree(MockItemUI.new())
	mock_ui.item_data = rotated_data
	
	# 以 (2,2) 为中心旋转：新 root 应在 (2,1)
	# (2,2) 中心 = (2 * 103.2857 + 51.6428, 2 * 97.7142 + 48.8571) = (258.2142, 244.2855)
	# 相对 root_pos(1,2) 的 pivot_offset 为 (1,0)
	manager.request_rotate_item(mock_ui, Vector2(258.2142, 244.2855), Vector2i(1, 0))
	
	assert_not_null(mock_ui.item_instance)
	assert_eq(manager.backpack_manager.grid[Vector2i(2, 1)].root_pos, Vector2i(2, 1))


func test_rapid_duplicate_rotation_requests_rotate_once():
	var manager = autofree(BattleManager.new())
	add_child(manager)
	manager.backpack_manager.setup_grid(7, 7, 5, 5)
	var mock_bp_ui = autofree(MockBackpackUI.new())
	add_child(mock_bp_ui)
	manager.backpack_ui = mock_bp_ui

	var can = ItemData.new(); can.runtime_id = 701
	can.direction = ItemData.Direction.UP
	can.shape = [Vector2i(0,0), Vector2i(0,1)] as Array[Vector2i]
	manager.backpack_manager.place_item(can, Vector2i(2, 2))

	var data = manager.backpack_manager.grid[Vector2i(2, 2)].data
	var mock_ui = autofree(MockItemUI.new())
	mock_ui.item_data = data
	mock_ui.item_instance = manager.backpack_manager.grid[Vector2i(2, 2)]

	manager.request_rotate_item(mock_ui, Vector2(258.2142, 244.2855), Vector2i(0, 0))
	await get_tree().process_frame
	manager.request_rotate_item(mock_ui, Vector2(258.2142, 244.2855), Vector2i(0, 0))

	var rotated_instance = manager.backpack_manager.grid[Vector2i(1, 2)]
	assert_not_null(rotated_instance)
	assert_eq(rotated_instance.data.direction, ItemData.Direction.RIGHT)

func test_rotation_failure_right_edge():
	var manager = autofree(BattleManager.new())
	add_child(manager)
	manager.backpack_manager.setup_grid(7, 7, 5, 5) # 5x5 可用
	var mock_bp_ui = autofree(MockBackpackUI.new())
	add_child(mock_bp_ui)
	manager.backpack_ui = mock_bp_ui
	
	var can = ItemData.new(); can.runtime_id = 301
	can.shape = [Vector2i(0,0), Vector2i(0,1)] as Array[Vector2i]
	manager.backpack_manager.place_item(can, Vector2i(5, 1)) # 占据 (5,1), (5,2)
	
	var data = manager.backpack_manager.grid[Vector2i(5, 1)].data
	# 测试逻辑现在由 manager 内部处理旋转
	
	var mock_ui = autofree(MockItemUI.new())
	mock_ui.item_data = data
	# 以 (5,2) 为中心旋转 (pivot_offset = 0,1)
	# 旋转后新 pivot offset 为 (0,0), 新 root_pos 为 (5,2) - (0,0) = (5,2)
	# 占用 (5,2), (6,2)，其中 x=6 处于未解锁区域，预期被弹出
	# (5,2) 中心 = (5 * 103.2857 + 51.6428, 2 * 97.7142 + 48.8571) = (568.0713, 244.2855)
	manager.request_rotate_item(mock_ui, Vector2(568.0713, 244.2855), Vector2i(0, 1))
	
	assert_null(mock_ui.item_instance, "Should pop out at locked edge")

func test_rotation_failure_collision():
	var manager = autofree(BattleManager.new())
	add_child(manager)
	manager.backpack_manager.setup_grid(7, 7, 5, 5)
	var mock_bp_ui = autofree(MockBackpackUI.new())
	add_child(mock_bp_ui)
	manager.backpack_ui = mock_bp_ui
	
	var obstacle = ItemData.new(); obstacle.runtime_id = 999; obstacle.shape = [Vector2i(0,0)] as Array[Vector2i]
	manager.backpack_manager.place_item(obstacle, Vector2i(2, 2))
	
	var can = ItemData.new(); can.runtime_id = 401; can.shape = [Vector2i(0,0), Vector2i(0,1)] as Array[Vector2i]
	manager.backpack_manager.place_item(can, Vector2i(1, 2)) # 占据 (1,2), (1,3)
	
	var data = manager.backpack_manager.grid[Vector2i(1, 2)].data
	# 测试逻辑现在由 manager 内部处理旋转
	
	var mock_ui = autofree(MockItemUI.new())
	mock_ui.item_data = data
	# 尝试从 (1,2) 开始占用 (1,2) 和 (2,2) -> 撞到 obstacle
	# 以 (1,2) 为中心，中心 = (1 * 103.2857 + 51.6428, 2 * 97.7142 + 48.8571) = (154.9285, 244.2855)
	manager.request_rotate_item(mock_ui, Vector2(154.9285, 244.2855), Vector2i(0, 0))
	
	assert_null(mock_ui.item_instance, "Should pop out due to collision")

func test_rotation_360_degree_stability():
	var item = ItemData.new()
	item.shape = [Vector2i(0,0), Vector2i(1,0), Vector2i(2,0)] as Array[Vector2i]
	for i in range(4):
		item.rotate_90()
	assert_eq(item.shape, [Vector2i(0,0), Vector2i(1,0), Vector2i(2,0)] as Array[Vector2i], "360 rotation should return to original normalized shape")
func test_place_item_outside_removes_grid_occupancy():
	var manager = autofree(BattleManager.new())
	add_child(manager)
	manager.backpack_manager.setup_grid(7, 7, 5, 5)
	var mock_bp_ui = autofree(MockBackpackUI.new())
	add_child(mock_bp_ui)
	manager.backpack_ui = mock_bp_ui

	var item = ItemData.new(); item.runtime_id = 501
	item.shape = [Vector2i(0,0), Vector2i(1,0)] as Array[Vector2i]
	manager.backpack_manager.place_item(item, Vector2i(1, 1))
	var data = manager.backpack_manager.grid[Vector2i(1, 1)].data

	var mock_ui = autofree(MockItemUI.new())
	mock_ui.item_data = data
	mock_ui.item_instance = manager.backpack_manager.grid[Vector2i(1, 1)]

	manager.request_place_item(mock_ui, Vector2i(-1, -1))

	assert_eq(manager.backpack_manager.grid.size(), 0)
	assert_null(mock_ui.item_instance)

func test_rotation_outside_backpack_rotates_without_grid_placement():
	var manager = autofree(BattleManager.new())
	add_child(manager)
	manager.backpack_manager.setup_grid(7, 7, 5, 5)
	var mock_bp_ui = autofree(MockBackpackUI.new())
	add_child(mock_bp_ui)
	manager.backpack_ui = mock_bp_ui

	var item = ItemData.new(); item.runtime_id = 601
	item.shape = [Vector2i(0,0), Vector2i(0,1)] as Array[Vector2i]
	item.direction = ItemData.Direction.UP

	var mock_ui = autofree(MockItemUI.new())
	mock_ui.item_data = item
	mock_ui.item_instance = null

	manager.request_rotate_item(mock_ui, Vector2(-100, -100), Vector2i(0, 0))

	assert_eq(manager.backpack_manager.grid.size(), 0)
	assert_null(mock_ui.item_instance)
	assert_eq(item.direction, ItemData.Direction.RIGHT)
	assert_true(item.shape.has(Vector2i(1, 0)))
