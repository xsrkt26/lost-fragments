class_name BackpackUI
extends Control

## 背包 UI：纯表现层 (View)
## 只负责显示网格、对齐物品、以及将玩家的操作“上报”给管理器

signal item_dropped_on_grid(item_ui: Control, grid_pos: Vector2i)

@export var grid_container_path: NodePath = "GridContainer"
@onready var grid_container: GridContainer = get_node(grid_container_path)

const COLOR_LOCKED = Color(0, 0, 0, 0)
const COLOR_EMPTY = Color(1, 1, 1, 0)
const COLOR_OCCUPIED = Color(0.2, 0.5, 0.8, 0.2) # 蓝色表示已有物品
const COLOR_VALID = Color(0.2, 0.8, 0.2, 0.4)   # 绿色表示可放置
const COLOR_INVALID = Color(0.8, 0.2, 0.2, 0.4) # 红色表示不可用

var context: GameContext
var manager: BackpackManager # 仅用于读取网格尺寸等基础信息
var item_ui_map: Dictionary = {}
var grid_step = Vector2(103.2857, 97.7142)

func _ready() -> void:
	_sync_grid_geometry()
	if not resized.is_connected(_on_resized):
		resized.connect(_on_resized)

func setup(p_context: GameContext):
	print("[BackpackUI] 接收到 Context，正在执行 setup...")
	context = p_context
	manager = context.battle.backpack_manager
	
	if manager:
		if not manager.grid_changed.is_connected(update_slot_visuals):
			manager.grid_changed.connect(update_slot_visuals)
	
	_refresh_grid()

func _refresh_grid():
	if not manager: 
		print("[BackpackUI] 警告: manager 为空，无法刷新网格")
		return
	
	print("[BackpackUI] 正在生成网格: ", manager.grid_width, "x", manager.grid_height)
	for child in grid_container.get_children():
		child.queue_free()
	
	grid_container.columns = manager.grid_width
	grid_container.add_theme_constant_override("h_separation", 0)
	grid_container.add_theme_constant_override("v_separation", 0)
	_sync_grid_geometry()
	
	for i in range(manager.grid_width * manager.grid_height):
		var pos = Vector2i(i % manager.grid_width, floori(float(i) / manager.grid_width))
		var slot = ColorRect.new()
		slot.custom_minimum_size = grid_step
		slot.name = "Slot_%d_%d" % [pos.x, pos.y]
		slot.tooltip_text = "可用格"
		grid_container.add_child(slot)
	
	update_slot_visuals()
	print("[BackpackUI] 网格刷新完成，子节点数: ", grid_container.get_child_count())

## 更新所有格子的基础颜色（锁定/空闲/占用）
func _on_resized() -> void:
	_sync_grid_geometry()
	for child in grid_container.get_children():
		if child is Control:
			child.custom_minimum_size = grid_step
	grid_container.queue_sort()

func _sync_grid_geometry() -> void:
	var grid_width := manager.grid_width if manager else 7
	var grid_height := manager.grid_height if manager else 7
	var grid_size := size
	if grid_size.x <= 0.0 or grid_size.y <= 0.0:
		grid_size = custom_minimum_size
	if grid_size.x <= 0.0 or grid_size.y <= 0.0:
		grid_size = Vector2(723.0, 684.0)
	grid_step = Vector2(grid_size.x / float(grid_width), grid_size.y / float(grid_height))
	grid_container.set_anchors_preset(Control.PRESET_TOP_LEFT, true)
	grid_container.position = Vector2.ZERO
	grid_container.size = grid_size
	grid_container.custom_minimum_size = grid_size

func get_grid_cell_size() -> Vector2:
	_sync_grid_geometry()
	return grid_step

func get_grid_cell_size_for_parent(target_parent: Node) -> Vector2:
	_sync_grid_geometry()
	if not (target_parent is CanvasItem):
		return grid_step
	grid_container.force_update_transform()
	var target_canvas_item := target_parent as CanvasItem
	var grid_transform := grid_container.get_global_transform_with_canvas()
	var parent_inverse := target_canvas_item.get_global_transform_with_canvas().affine_inverse()
	var origin := parent_inverse * (grid_transform * Vector2.ZERO)
	var right := parent_inverse * (grid_transform * Vector2(grid_step.x, 0.0))
	var down := parent_inverse * (grid_transform * Vector2(0.0, grid_step.y))
	return Vector2(origin.distance_to(right), origin.distance_to(down))

func configure_item_for_grid(item_ui: Control, target_parent: Node = null) -> void:
	if item_ui == null or not item_ui.has_method("set_cell_size"):
		return
	var parent_for_size := target_parent
	if parent_for_size == null:
		parent_for_size = item_ui.get_parent()
	var item_cell_size := grid_step
	if parent_for_size != null and parent_for_size != self:
		item_cell_size = get_grid_cell_size_for_parent(parent_for_size)
	else:
		_sync_grid_geometry()
		item_cell_size = grid_step
	item_ui.set_cell_size(item_cell_size)

func update_slot_visuals(ignore_item_data: ItemData = null):
	if not manager: return
	
	for i in range(grid_container.get_child_count()):
		var slot = grid_container.get_child(i) as ColorRect
		var pos = Vector2i(i % manager.grid_width, floori(float(i) / manager.grid_width))
		
		if manager.has_method("is_pos_blocked") and manager.is_pos_blocked(pos):
			slot.color = COLOR_LOCKED
			slot.tooltip_text = "锁定格"
		elif not manager.is_pos_usable(pos):
			slot.color = COLOR_LOCKED
			slot.tooltip_text = "锁定格"
		elif manager.grid.has(pos):
			var occupied_item = manager.grid[pos].data
			if ignore_item_data and ignore_item_data.runtime_id != -1 and occupied_item.runtime_id == ignore_item_data.runtime_id:
				slot.color = COLOR_EMPTY # 如果是自己正在被拖拽，原地显示为空闲
				slot.tooltip_text = "可用格"
			else:
				slot.color = COLOR_EMPTY
				slot.tooltip_text = occupied_item.item_name
		else:
			slot.color = COLOR_EMPTY
			slot.tooltip_text = "可用格"

## 高亮显示预测的放置结果 (由外部在 Drag 过程中调用)
func highlight_placement(root_pos: Vector2i, item_data: ItemData):
	update_slot_visuals(item_data) # 先重置，并忽略当前拖拽物品的占位
	
	if root_pos == Vector2i(-1, -1): return
	
	var can_place = manager.can_place_item(item_data, root_pos)
	var highlight_color = COLOR_VALID if can_place else COLOR_INVALID
	
	for offset in item_data.shape:
		var target_pos = root_pos + offset
		if target_pos.x >= 0 and target_pos.x < manager.grid_width and \
		   target_pos.y >= 0 and target_pos.y < manager.grid_height:
			var index = target_pos.y * manager.grid_width + target_pos.x
			var slot = grid_container.get_child(index) as ColorRect
			slot.color = highlight_color


func get_slot_center_position(grid_pos: Vector2i) -> Vector2:
	if not manager or grid_pos.x < 0 or grid_pos.y < 0: return Vector2.ZERO
	grid_container.force_update_transform()
	var index = grid_pos.y * manager.grid_width + grid_pos.x
	if index >= grid_container.get_child_count(): return Vector2.ZERO
	var slot = grid_container.get_child(index) as Control
	return slot.position + (slot.size / 2.0)

func get_grid_pos_at(global_pos: Vector2) -> Vector2i:
	if not manager:
		return Vector2i(-1, -1)
	grid_container.force_update_transform()
	var local_pos := grid_container.get_global_transform_with_canvas().affine_inverse() * global_pos
	if local_pos.x < 0.0 or local_pos.y < 0.0:
		return Vector2i(-1, -1)
	var grid_pos := Vector2i(floori(local_pos.x / grid_step.x), floori(local_pos.y / grid_step.y))
	if grid_pos.x < 0 or grid_pos.x >= manager.grid_width or grid_pos.y < 0 or grid_pos.y >= manager.grid_height:
		return Vector2i(-1, -1)
	return grid_pos

	var closest_pos = Vector2i(-1, -1)
	var min_dist = 99999.0
	var threshold = 100.0 # 缩小阈值适配更小的格子
	
	for i in range(grid_container.get_child_count()):
		var slot = grid_container.get_child(i) as Control
		var slot_center = slot.global_position + (slot.size / 2.0)
		var dist = global_pos.distance_to(slot_center)
		if dist < min_dist and dist < threshold:
			min_dist = dist
			closest_pos = Vector2i(i % manager.grid_width, int(float(i) / manager.grid_width))
	
	if closest_pos != Vector2i(-1, -1):
		print("[BackpackUI] 捕捉到最近格子: ", closest_pos, " 距离: ", min_dist)
	return closest_pos

## 将物品 UI 添加并对齐到网格
func add_item_visual(item_ui: Control, grid_pos: Vector2i):
	if grid_pos == Vector2i(-1, -1): return # 不在网格内
	
	# 更新映射关系（使用 runtime_id 作为稳定键）
	item_ui_map[item_ui.item_data.runtime_id] = item_ui
	
	if item_ui.get_parent() != self:
		if item_ui.get_parent(): item_ui.get_parent().remove_child(item_ui)
		add_child(item_ui)
	
	# 放入网格后使用背包自己的本地格子尺寸，父级缩放由场景层处理。
	configure_item_for_grid(item_ui, self)
	item_ui.scale = Vector2.ONE
	
	grid_container.force_update_transform()
	await get_tree().process_frame
	
	# --- 核心修复：多格物品对齐 ---
	# 计算形状的最小偏移量（防止形状不是从 (0,0) 开始的情况）
	var min_offset = Vector2i(0, 0)
	for p in item_ui.item_data.shape:
		min_offset.x = min(min_offset.x, p.x)
		min_offset.y = min(min_offset.y, p.y)
	
	var index = grid_pos.y * manager.grid_width + grid_pos.x
	var slot = grid_container.get_child(index) as Control
	item_ui.position = slot.position + Vector2(min_offset.x * grid_step.x, min_offset.y * grid_step.y)

## 同步最新的映射关系（当 Data 被克隆后调用）
func update_item_mapping(old_data: ItemData, new_data: ItemData):
	if item_ui_map.has(old_data.runtime_id):
		var ui = item_ui_map[old_data.runtime_id]
		# 如果新旧 ID 一致（由于 @export 已经保留了），我们只需确保 map 指向最新数据即可
		# 如果项目逻辑需要更严谨，可以保留这个手动同步
		item_ui_map[new_data.runtime_id] = ui
		print("[BackpackUI] 映射关系已同步. RID: ", new_data.runtime_id)

## UI 层的松手处理：不再直接计算逻辑，而是发出信号
func handle_item_dropped(item_ui: Control, drop_center_pos: Vector2):
	var grid_pos = get_grid_pos_at(drop_center_pos)
	# 向上级报告：有人想在这个位置放东西
	item_dropped_on_grid.emit(item_ui, grid_pos)
