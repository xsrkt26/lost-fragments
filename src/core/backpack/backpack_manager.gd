class_name BackpackManager
extends Node

## 内部类，记录物品在网格中的实例信息
class ItemInstance extends RefCounted:
	signal pollution_changed(new_val: int)
	
	var data: ItemData
	var root_pos: Vector2i
	var is_preserved: bool = false
	var dream_seed_level: int = 0
	var current_pollution: int = 0:
		set(val):
			if is_preserved:
				print("[BackpackManager] 物品 ", data.item_name, " 已防腐，拒绝修改污染 (", current_pollution, " -> ", val, ")")
				return
			var old_value = current_pollution
			current_pollution = max(0, val)
			pollution_changed.emit(current_pollution)
			if old_value != current_pollution:
				_emit_pollution_changed(old_value, current_pollution)
	
	func _init(p_data: ItemData, p_pos: Vector2i):
		data = p_data
		root_pos = p_pos

	func add_pollution(amount: int):
		# 现在 setter 会自动处理 guard
		current_pollution += amount

	func _emit_pollution_changed(old_value: int, new_value: int) -> void:
		var main_loop = Engine.get_main_loop()
		if main_loop is SceneTree:
			var bus = main_loop.root.get_node_or_null("GlobalEventBus")
			if bus:
				bus.pollution_changed.emit(self, old_value, new_value)

signal grid_changed
signal item_data_replaced(old_data, new_instance)

var grid_width: int = 7
var grid_height: int = 7
var usable_width: int = 5
var usable_height: int = 5
var blocked_cells: Dictionary = {}
const DREAM_SEED_TAG := "梦境之种"
const DREAM_SEED_LEGACY_TAG := "梦之种"
const DERIVED_TAG := "衍生物品"
const MAX_DREAM_SEED_STAGE := 4

## 核心网格字典：Key 是 Vector2i 坐标，Value 是 ItemInstance
var grid: Dictionary = {}

func _exit_tree() -> void:
	grid.clear()

func setup_grid(w: int, h: int, uw: int = -1, uh: int = -1) -> void:
	grid_width = w
	grid_height = h
	usable_width = uw if uw > 0 else w
	usable_height = uh if uh > 0 else h
	grid.clear()
	blocked_cells.clear()
	print("[BackpackManager] 网格已初始化. 总大小: ", w, "x", h, " 可用大小: ", usable_width, "x", usable_height)
	grid_changed.emit()

func set_blocked_cells(cells: Array[Vector2i]) -> void:
	blocked_cells.clear()
	for cell in cells:
		if cell.x >= 0 and cell.x < grid_width and cell.y >= 0 and cell.y < grid_height:
			blocked_cells[cell] = true
	grid_changed.emit()

func is_pos_blocked(pos: Vector2i) -> bool:
	return blocked_cells.has(pos)

## 检查是否处于可用区域内 (居中算法)
func is_pos_usable(pos: Vector2i) -> bool:
	if is_pos_blocked(pos):
		return false
	var start_x = floori((grid_width - usable_width) / 2.0)
	var start_y = floori((grid_height - usable_height) / 2.0)
	
	var is_usable = pos.x >= start_x and pos.x < (start_x + usable_width) and \
		   pos.y >= start_y and pos.y < (start_y + usable_height)
	
	if not is_usable:
		# 仅在调试时打开，避免日志爆炸
		# print("[BackpackManager] 检查可用性: ", pos, " -> start(", start_x, ",", start_y, ") usable(", usable_width, "x", usable_height, ") -> ", is_usable)
		pass
		
	return is_usable

## 检查指定位置是否可以放置该物品
func can_place_item(item_data: ItemData, root_pos: Vector2i) -> bool:
	if item_data == null or item_data.shape.is_empty():
		return false
	for offset in item_data.shape:
		var target_pos = root_pos + offset
		
		# 边界检查
		if target_pos.x < 0 or target_pos.x >= grid_width or target_pos.y < 0 or target_pos.y >= grid_height:
			print("[BackpackManager] 放置拒绝: 坐标 ", target_pos, " 超出物理边界 (", grid_width, "x", grid_height, ")")
			return false
			
		# 可用区域检查
		if not is_pos_usable(target_pos):
			print("[BackpackManager] 放置拒绝: 坐标 ", target_pos, " 处于未解锁区域")
			return false

		# 重叠检查
		if grid.has(target_pos):
			if item_data.runtime_id != -1 and grid[target_pos].data.runtime_id == item_data.runtime_id:
				continue
			print("[BackpackManager] 放置拒绝: 坐标 ", target_pos, " 已有物品: ", grid[target_pos].data.item_name, " (拖拽ID: ", item_data.runtime_id, ", 网格ID: ", grid[target_pos].data.runtime_id, ")")
			return false
			
	return true

## 放置物品到网格
func place_item(item_data: ItemData, root_pos: Vector2i) -> bool:
	if not can_place_item(item_data, root_pos):
		return false
	
	# --- 核心重构：资源隔离 ---
	# 每一个进入背包的物品都必须是唯一的副本，
	# 这样修改这一张卡的属性（如强化、诅咒）才不会影响到其他同类卡。
	var unique_data = item_data.duplicate(true)
	if unique_data.runtime_id <= 0:
		unique_data.runtime_id = randi()
	
	var instance = ItemInstance.new(unique_data, root_pos)
	_initialize_seed_instance(instance)
	for offset in unique_data.shape:
		var target_pos = root_pos + offset
		grid[target_pos] = instance
	
	grid_changed.emit()
	return true

## 替换指定位置物品的数据 (用于变身、进化等逻辑)
func replace_item_data(pos: Vector2i, new_data: ItemData) -> bool:
	if not grid.has(pos) or new_data == null:
		return false
	
	var instance: ItemInstance = grid[pos]
	var root_pos = instance.root_pos
	var old_data = instance.data
	var replacement = new_data.duplicate(true)
	replacement.runtime_id = old_data.runtime_id
	
	# 如果形状改变，需要先清理旧网格，再重新放置
	# 如果形状一致，直接修改 data 即可
	if old_data.shape == replacement.shape:
		instance.data = replacement
		grid_changed.emit()
		item_data_replaced.emit(old_data, instance)
		return true
	else:
		var removed_data = remove_item_at(root_pos)
		if place_item(replacement, root_pos):
			item_data_replaced.emit(old_data, grid[root_pos])
			return true
		else:
			# 如果新形状放不下，回退到原物品
			print("[BackpackManager] 变身/替换失败，空间不足，回退。")
			place_item(removed_data, root_pos)
			return false

## 根据运行时 ID 彻底移除物品 (最高优先级，防任何引用误差)
func remove_by_runtime_id(rid: int):
	if rid == -1: return
	var keys_to_remove = []
	for pos in grid.keys():
		var inst = grid[pos]
		if inst and inst.data and inst.data.runtime_id == rid:
			keys_to_remove.append(pos)
			
	for pos in keys_to_remove:
		grid.erase(pos)
	
	if not keys_to_remove.is_empty():
		print("[BackpackManager] 已根据 RID ", rid, " 清理网格格子数: ", keys_to_remove.size())
		grid_changed.emit()

## 彻底从网格中移除某个物品实例 (防幽灵算法)
func remove_instance(instance: ItemInstance):
	if instance == null or instance.data == null: return
	remove_by_runtime_id(instance.data.runtime_id)

## 移除并返回指定位置的物品数据
func remove_item_at(pos: Vector2i) -> ItemData:
	if not grid.has(pos):
		return null
		
	var instance: ItemInstance = grid[pos]
	var item_data = instance.data
	remove_instance(instance)
	return item_data

## 寻找并返回所有空闲的格子坐标
func get_empty_slots() -> Array[Vector2i]:
	var empty_slots: Array[Vector2i] = []
	for y in range(grid_height):
		for x in range(grid_width):
			var pos = Vector2i(x, y)
			if not grid.has(pos) and is_pos_usable(pos):
				empty_slots.append(pos)
	return empty_slots

## 查找一个足以放下指定形状物品的空闲 root 位置
func find_available_pos(item_data: ItemData) -> Vector2i:
	# 简单算法：从左上角开始扫描
	for y in range(grid_height):
		for x in range(grid_width):
			var pos = Vector2i(x, y)
			if can_place_item(item_data, pos):
				return pos
	return Vector2i(-1, -1)

func sow_seed(source_instance: ItemInstance, direction: ItemData.Direction, item_db: Node, levels: int = 1) -> ItemInstance:
	if source_instance == null or item_db == null:
		_emit_seed_sow_failed(source_instance, direction)
		return null
	var target_pos = _get_seed_target_pos(source_instance, direction)
	if target_pos == Vector2i(-1, -1):
		_emit_seed_sow_failed(source_instance, direction)
		return null
	if grid.has(target_pos):
		var target_instance = grid[target_pos]
		if _is_dream_seed(target_instance):
			return upgrade_seed(target_instance, item_db, levels)
		_emit_seed_sow_failed(source_instance, direction)
		return null

	var seed_data = item_db.get_item_by_id("dream_seed_1x1") if item_db.has_method("get_item_by_id") else null
	if seed_data == null:
		_emit_seed_sow_failed(source_instance, direction)
		return null
	var runtime_seed: ItemData = seed_data.duplicate(true)
	if not runtime_seed.tags.has(DERIVED_TAG):
		runtime_seed.tags.append(DERIVED_TAG)
	if not place_item(runtime_seed, target_pos):
		_emit_seed_sow_failed(source_instance, direction)
		return null
	var instance = grid[target_pos]
	_emit_seed_sown(instance)
	if levels > 1:
		return upgrade_seed(instance, item_db, levels - 1)
	return instance

func sow_seed_at(target_pos: Vector2i, item_db: Node, levels: int = 1) -> ItemInstance:
	if item_db == null:
		_emit_seed_sow_failed(null, -1)
		return null
	if target_pos.x < 0 or target_pos.x >= grid_width or target_pos.y < 0 or target_pos.y >= grid_height:
		_emit_seed_sow_failed(null, -1)
		return null
	if grid.has(target_pos) or not is_pos_usable(target_pos):
		_emit_seed_sow_failed(null, -1)
		return null
	var seed_data = item_db.get_item_by_id("dream_seed_1x1") if item_db.has_method("get_item_by_id") else null
	if seed_data == null:
		_emit_seed_sow_failed(null, -1)
		return null
	var runtime_seed: ItemData = seed_data.duplicate(true)
	if not runtime_seed.tags.has(DERIVED_TAG):
		runtime_seed.tags.append(DERIVED_TAG)
	if not place_item(runtime_seed, target_pos):
		_emit_seed_sow_failed(null, -1)
		return null
	var instance = grid[target_pos]
	_emit_seed_sown(instance)
	if levels > 1:
		return upgrade_seed(instance, item_db, levels - 1)
	return instance

func upgrade_seed(seed_instance: ItemInstance, item_db: Node, levels: int = 1) -> ItemInstance:
	if not _is_dream_seed(seed_instance) or item_db == null or levels <= 0:
		return seed_instance
	var old_level = _get_seed_runtime_level(seed_instance)
	var new_level = max(1, old_level + levels)
	if new_level == old_level:
		return seed_instance
	var old_stage = _get_seed_stage_for_level(old_level)
	var new_stage = _get_seed_stage_for_level(new_level)

	if new_stage == old_stage:
		_set_seed_runtime_level(seed_instance, new_level)
		_emit_seed_upgraded(seed_instance, old_level, new_level)
		return seed_instance

	var new_data = item_db.get_item_by_id(_get_seed_id(new_stage)) if item_db.has_method("get_item_by_id") else null
	if new_data == null:
		return seed_instance
	var old_data = seed_instance.data
	var old_root = seed_instance.root_pos
	var runtime_seed: ItemData = new_data.duplicate(true)
	runtime_seed.runtime_id = old_data.runtime_id
	runtime_seed.direction = old_data.direction
	runtime_seed.set_meta("dream_seed_level", new_level)
	if old_data.tags.has(DERIVED_TAG) and not runtime_seed.tags.has(DERIVED_TAG):
		runtime_seed.tags.append(DERIVED_TAG)

	if can_place_item(runtime_seed, old_root):
		remove_instance(seed_instance)
		place_item(runtime_seed, old_root)
		var upgraded_instance = grid[old_root]
		_set_seed_runtime_level(upgraded_instance, new_level)
		_emit_seed_upgraded(upgraded_instance, old_level, new_level)
		return upgraded_instance

	_emit_seed_sow_failed(seed_instance, old_data.direction)
	remove_instance(seed_instance)
	var dropped_instance = ItemInstance.new(runtime_seed, old_root)
	_initialize_seed_instance(dropped_instance)
	_set_seed_runtime_level(dropped_instance, new_level)
	grid_changed.emit()
	return dropped_instance

func _get_seed_target_pos(source_instance: ItemInstance, direction: ItemData.Direction) -> Vector2i:
	var step = _direction_to_vector(direction)
	if step == Vector2i.ZERO:
		return Vector2i(-1, -1)
	var occupied = {}
	for offset in source_instance.data.shape:
		occupied[source_instance.root_pos + offset] = true
	var candidates: Array[Vector2i] = []
	for cell in occupied.keys():
		var target = cell + step
		if not occupied.has(target):
			candidates.append(target)
	candidates.sort()
	for target in candidates:
		if target.x >= 0 and target.x < grid_width and target.y >= 0 and target.y < grid_height:
			return target
	return Vector2i(-1, -1)

func _direction_to_vector(direction: ItemData.Direction) -> Vector2i:
	match direction:
		ItemData.Direction.UP:
			return Vector2i.UP
		ItemData.Direction.DOWN:
			return Vector2i.DOWN
		ItemData.Direction.LEFT:
			return Vector2i.LEFT
		ItemData.Direction.RIGHT:
			return Vector2i.RIGHT
	return Vector2i.ZERO

func _is_dream_seed(instance: ItemInstance) -> bool:
	return instance != null and _is_dream_seed_data(instance.data)

func _is_dream_seed_data(data: ItemData) -> bool:
	if data == null:
		return false
	return data.tags.has(DREAM_SEED_TAG) or data.tags.has(DREAM_SEED_LEGACY_TAG)

func _initialize_seed_instance(instance: ItemInstance) -> void:
	if instance == null or not _is_dream_seed_data(instance.data):
		return
	if instance.data.has_meta("dream_seed_level"):
		instance.dream_seed_level = max(1, int(instance.data.get_meta("dream_seed_level")))
	else:
		instance.dream_seed_level = _get_seed_min_level_for_stage(_get_seed_stage_from_data(instance.data))
	instance.data.set_meta("dream_seed_level", instance.dream_seed_level)

func _get_seed_runtime_level(instance: ItemInstance) -> int:
	if instance == null:
		return 0
	if instance.dream_seed_level > 0:
		return instance.dream_seed_level
	if instance.data != null and instance.data.has_meta("dream_seed_level"):
		return max(1, int(instance.data.get_meta("dream_seed_level")))
	return _get_seed_min_level_for_stage(_get_seed_stage_from_data(instance.data))

func _set_seed_runtime_level(instance: ItemInstance, level: int) -> void:
	if instance == null or instance.data == null:
		return
	instance.dream_seed_level = max(1, level)
	instance.data.set_meta("dream_seed_level", instance.dream_seed_level)

func _get_seed_stage_from_data(data: ItemData) -> int:
	if data == null:
		return 1
	for stage in range(1, MAX_DREAM_SEED_STAGE + 1):
		if data.id == _get_seed_id(stage):
			return stage
	return 1

func _get_seed_stage_for_level(level: int) -> int:
	if level >= 30:
		return 4
	if level >= 20:
		return 3
	if level >= 10:
		return 2
	return 1

func _get_seed_min_level_for_stage(stage: int) -> int:
	match stage:
		2:
			return 10
		3:
			return 20
		4:
			return 30
	return 1

func _get_seed_id(stage: int) -> String:
	return "dream_seed_%dx%d" % [stage, stage]

func _emit_seed_sown(instance: ItemInstance) -> void:
	var bus = get_node_or_null("/root/GlobalEventBus") if is_inside_tree() else null
	if bus:
		bus.seed_sown.emit(instance)

func _emit_seed_upgraded(instance: ItemInstance, old_level: int, new_level: int) -> void:
	var bus = get_node_or_null("/root/GlobalEventBus") if is_inside_tree() else null
	if bus:
		bus.seed_upgraded.emit(instance, old_level, new_level)

func _emit_seed_sow_failed(source_instance: ItemInstance, direction: int) -> void:
	var bus = get_node_or_null("/root/GlobalEventBus") if is_inside_tree() else null
	if bus:
		bus.seed_sow_failed.emit(source_instance, direction)

## 获取一个物品实例的所有相邻物品实例 (不含自己)
func get_neighbor_instances(instance: ItemInstance) -> Array[ItemInstance]:
	var neighbors: Array[ItemInstance] = []
	
	# 遍历该物品占据的所有格子
	for offset in instance.data.shape:
		var cell = instance.root_pos + offset
		# 检查该格子周围的 4 个方向
		for dir in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			var neighbor_cell = cell + dir
			if grid.has(neighbor_cell):
				var neighbor_instance = grid[neighbor_cell]
				if neighbor_instance != instance and not neighbors.has(neighbor_instance):
					neighbors.append(neighbor_instance)
					
	return neighbors

## 获取背包中所有不重复的物品实例
func get_all_instances() -> Array[ItemInstance]:
	var instances: Array[ItemInstance] = []
	for pos in grid.keys():
		var instance = grid[pos]
		if not instances.has(instance):
			instances.append(instance)
	return instances

## 获取特定方向上的邻居物品坐标（用于撞击算法）
func get_next_item_pos(start_pos: Vector2i, direction: ItemData.Direction, filter_tags: Array[String] = []) -> Vector2i:
	var step = Vector2i.ZERO
	match direction:
		ItemData.Direction.UP: step = Vector2i(0, -1)
		ItemData.Direction.DOWN: step = Vector2i(0, 1)
		ItemData.Direction.LEFT: step = Vector2i(-1, 0)
		ItemData.Direction.RIGHT: step = Vector2i(1, 0)
	
	# 获取起始位置的物品实例（如果有），搜索时应跳过它
	var source_instance = grid.get(start_pos)
	
	var current_pos = start_pos + step
	# 沿方向搜索直到撞到物品或出界
	while current_pos.x >= 0 and current_pos.x < grid_width and \
		  current_pos.y >= 0 and current_pos.y < grid_height:
		if grid.has(current_pos):
			var hit_instance = grid[current_pos]
			# 只有撞到的不是自己时，才处理
			if hit_instance != source_instance:
				# 如果有过滤器，检查是否匹配
				if filter_tags.is_empty():
					return current_pos
				else:
					var matched = false
					for tag in filter_tags:
						if hit_instance.data.tags.has(tag):
							matched = true
							break
					if matched:
						return current_pos
					else:
						# 不匹配，跳过该物品继续向后搜索 (实现“穿透”非目标的效果)
						print("[BackpackManager] 过滤器跳过物品: ", hit_instance.data.item_name)
		current_pos += step
		
	return Vector2i(-1, -1) # 表示未击中
