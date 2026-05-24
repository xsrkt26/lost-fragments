class_name BattleManager
extends Node

const ToolEffectScript = preload("res://src/core/tools/tool_effect.gd")

## 战斗管理器：游戏的逻辑中枢 (Controller)
## 负责协调 backpack 数据、碰撞解析、序列播放和音频触发

signal turn_started
signal turn_finished
signal item_drawn(item_data: ItemData)
signal battle_finish_requested(reason: String)

enum BattleState {
	INTERACTIVE,
	DRAWING,
	RESOLVING,
	FINISHING,
	FINISHED
}

var backpack_manager: BackpackManager
var context: GameContext
var backpack_ui: Control: # 保持 Control 以兼容 Mock 测试
	set(v):
		backpack_ui = v
		if backpack_ui and context:
			if backpack_ui.has_method("setup"):
				backpack_ui.setup(context)

# UI 3.0 尺寸适配 (原始素材像素)
const GRID_STEP = Vector2(103.2857, 97.7142)
const SLOT_HALF = Vector2(51.6428, 48.8571)

func _init():
	print("[BattleManager] 正在初始化逻辑数据...")
	# 初始化逻辑数据
	backpack_manager = BackpackManager.new()
	add_child(backpack_manager)
	# 7x7 总格，5x5 可用
	backpack_manager.setup_grid(7, 7, 5, 5)
	if not backpack_manager.item_data_replaced.is_connected(_on_backpack_item_data_replaced):
		backpack_manager.item_data_replaced.connect(_on_backpack_item_data_replaced)

# --- 运行相关的逻辑变量 ---
var _current_battle_deck: Array[String] = []
var draw_count: int = 0 # 记录当前局内抽取次数
var managed_item_uis: Array[Control] = [] # 追踪当前战场上所有的物品 UI
var active_ornaments: Array[Dictionary] = []
var battle_state: BattleState = BattleState.INTERACTIVE
var _pending_finish_reason: String = ""
var _impact_queue: Array[Dictionary] = []
var _impact_queue_sequence: int = 0
var _is_processing_impact_queue: bool = false
var _next_draw_cost_discount: int = 0
var _tool_recycling_clip_pending: int = 0
var _blank_talisman_refreshed_ornaments: Array[String] = []
var _battle_modifiers: Dictionary = {}

func _ready():
	print("[BattleManager] 节点就绪")
	# 初始化上下文（依赖注入）
	var gs = get_node_or_null("/root/GameState")
	context = GameContext.new(gs, self)
	if gs and not gs.game_over.is_connected(_try_consume_insurance_contract):
		gs.game_over.connect(_try_consume_insurance_contract)
	_connect_ornament_bus()
	
	# 如果 UI 已经注入，确保它被初始化
	if backpack_ui:
		print("[BattleManager] 正在初始化已绑定的 UI...")
		if backpack_ui.has_method("setup"):
			backpack_ui.setup(context)
		
	_initialize_battle_data()

func _exit_tree():
	print("[BattleManager] 正在卸载...")
	_disconnect_ornament_bus()

func _initialize_battle_data():
	print("[BattleManager] 正在从 RunManager 初始化战斗数据...")
	var rm = get_node_or_null("/root/RunManager")
	if rm:
		_battle_modifiers = rm.get_current_battle_modifiers() if rm.has_method("get_current_battle_modifiers") else {}
		_apply_backpack_grid_config(rm)
		_current_battle_deck = Array(rm.current_deck).duplicate()
		_current_battle_deck.shuffle()
		_load_ornaments_from_run(rm)
		_restore_backpack_from_run(rm)
		_apply_ornament_battle_started()
		print("[BattleManager] 洗牌完成，当前战斗卡包大小: ", _current_battle_deck.size())
	else:
		print("[BattleManager] 警告: 未找到 RunManager，使用空卡包运行。")

func _apply_backpack_grid_config(rm) -> void:
	if rm == null or not rm.has_method("get_backpack_grid_config"):
		return
	var config = rm.get_backpack_grid_config()
	var grid_width = int(config.get("grid_width", 7))
	var grid_height = int(config.get("grid_height", 7))
	if backpack_manager.grid_width != grid_width or backpack_manager.grid_height != grid_height:
		return
	backpack_manager.setup_grid(
		grid_width,
		grid_height,
		int(config.get("usable_width", 5)),
		int(config.get("usable_height", 5))
	)
	if backpack_manager.has_method("set_blocked_cells"):
		backpack_manager.set_blocked_cells(_to_vector2i_array(config.get("blocked_cells", [])))

func _to_vector2i_array(value: Variant) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for entry in Array(value):
		if entry is Vector2i:
			result.append(entry)
		elif entry is Dictionary:
			result.append(Vector2i(int(entry.get("x", 0)), int(entry.get("y", 0))))
	return result

func _load_ornaments_from_run(rm) -> void:
	active_ornaments.clear()
	if rm == null:
		return
	var ornament_db = get_node_or_null("/root/OrnamentDatabase")
	if ornament_db == null:
		return
	for ornament_id in rm.current_ornaments:
		var ornament = ornament_db.get_ornament_by_id(ornament_id)
		if ornament == null:
			continue
		active_ornaments.append({"data": ornament, "state": {}})

func _connect_ornament_bus() -> void:
	var bus = get_node_or_null("/root/GlobalEventBus")
	if bus == null:
		return
	if not bus.seed_sown.is_connected(_on_ornament_seed_sown):
		bus.seed_sown.connect(_on_ornament_seed_sown)
	if not bus.seed_upgraded.is_connected(_on_ornament_seed_upgraded):
		bus.seed_upgraded.connect(_on_ornament_seed_upgraded)
	if not bus.seed_sow_failed.is_connected(_on_ornament_seed_sow_failed):
		bus.seed_sow_failed.connect(_on_ornament_seed_sow_failed)
	if not bus.pollution_changed.is_connected(_on_ornament_pollution_changed):
		bus.pollution_changed.connect(_on_ornament_pollution_changed)

func _disconnect_ornament_bus() -> void:
	var bus = get_node_or_null("/root/GlobalEventBus")
	if bus == null:
		return
	if bus.seed_sown.is_connected(_on_ornament_seed_sown):
		bus.seed_sown.disconnect(_on_ornament_seed_sown)
	if bus.seed_upgraded.is_connected(_on_ornament_seed_upgraded):
		bus.seed_upgraded.disconnect(_on_ornament_seed_upgraded)
	if bus.seed_sow_failed.is_connected(_on_ornament_seed_sow_failed):
		bus.seed_sow_failed.disconnect(_on_ornament_seed_sow_failed)
	if bus.pollution_changed.is_connected(_on_ornament_pollution_changed):
		bus.pollution_changed.disconnect(_on_ornament_pollution_changed)

func _restore_backpack_from_run(rm) -> void:
	if rm == null or not rm.has_method("restore_backpack_state"):
		return
	var item_db = get_node_or_null("/root/ItemDatabase")
	rm.restore_backpack_state(backpack_manager, item_db)

func persist_backpack_to_run() -> void:
	var rm = get_node_or_null("/root/RunManager")
	if rm and rm.has_method("save_backpack_state"):
		rm.save_backpack_state(backpack_manager)

func apply_sanity_loss(amount: int, reason: String = "effect", item_data: ItemData = null) -> int:
	if amount <= 0:
		return 0
	var modified_amount = amount
	for runtime in active_ornaments:
		var ornament = runtime.get("data")
		var state = runtime.get("state", {}) as Dictionary
		if ornament != null and ornament.effect != null:
			modified_amount = ornament.effect.modify_sanity_loss(modified_amount, reason, item_data, context, state)
			modified_amount = max(0, modified_amount)
	var gs = get_node_or_null("/root/GameState")
	if gs:
		gs.consume_sanity(modified_amount)
	return modified_amount

func add_next_draw_cost_discount(amount: int) -> void:
	_next_draw_cost_discount += max(0, amount)

func get_stage_pollution_added_bonus() -> int:
	return max(0, int(_battle_modifiers.get("pollution_added_bonus", 0)))

func add_recycling_clip_pending(amount: int) -> void:
	_tool_recycling_clip_pending += max(0, amount)

func refresh_ornament_once(ornament_id: String) -> bool:
	if ornament_id == "" or _blank_talisman_refreshed_ornaments.has(ornament_id):
		return false
	for runtime in active_ornaments:
		var ornament = runtime.get("data")
		if ornament == null or ornament.id != ornament_id:
			continue
		var state = runtime.get("state", {}) as Dictionary
		for key in ["used", "used_draw", "scored_draw", "used_resolution_id", "last_trigger_draw"]:
			state.erase(key)
		runtime["state"] = state
		_blank_talisman_refreshed_ornaments.append(ornament_id)
		return true
	return false

func request_use_tool(tool_id: String, target: Dictionary) -> bool:
	if battle_state != BattleState.INTERACTIVE:
		return false
	var rm = get_node_or_null("/root/RunManager")
	var tool_db = get_node_or_null("/root/ToolDatabase")
	if rm == null or tool_db == null or not rm.has_method("get_tool_count") or rm.get_tool_count(tool_id) <= 0:
		return false
	var tool = tool_db.get_tool_by_id(tool_id) if tool_db.has_method("get_tool_by_id") else null
	if tool == null:
		return false
	var item_db = get_node_or_null("/root/ItemDatabase")
	var ornament_db = get_node_or_null("/root/OrnamentDatabase")
	var result = ToolEffectScript.apply_tool(tool, target, self, rm, item_db, ornament_db)
	if not bool(result.get("success", false)):
		return false
	if not rm.consume_tool(tool_id, 1):
		return false
	_apply_ornament_tool_used(tool, target, result)
	var bus = get_node_or_null("/root/GlobalEventBus")
	if bus:
		bus.tool_used.emit(tool, target, result)
	persist_backpack_to_run()
	return true

## 处理物品在背包内被旋转的逻辑请求
func request_rotate_item(item_ui: Control, mouse_global_pos: Vector2, pivot_offset: Vector2i):
	var item_data = item_ui.get("item_data") as ItemData
	if not item_data: return
	
	print("[BattleManager] 收到旋转请求: ", item_data.item_name)
	
	var old_pos = _find_item_old_pos(item_data)
	if old_pos == Vector2i(-1, -1):
		_rotate_outside_item(item_ui, mouse_global_pos, pivot_offset)
		return
	if old_pos != Vector2i(-1, -1):
		# 1. 尝试将物品从逻辑中移除
		backpack_manager.remove_by_runtime_id(item_data.runtime_id)
	
	if not is_instance_valid(backpack_ui):
		return
		
	# 保存旋转前的状态
	var old_direction = item_data.direction
	var old_shape = item_data.shape.duplicate()
	
	# 预测新局部偏移量 (如果旋转的话)
	var new_pivot_offset = item_data.get_rotated_offset(pivot_offset)
		
	# 真正执行旋转
	item_data.rotate_90()
	if item_ui.has_method("_sync_visuals"):
		item_ui._sync_visuals()
		
	# 2. 精确计算新的 root_pos 
	var mouse_grid_pos = backpack_ui.get_grid_pos_at(mouse_global_pos)
	var new_root_pos = mouse_grid_pos - new_pivot_offset
	
	if backpack_manager.can_place_item(item_data, new_root_pos):
		# 3a. 碰撞检测通过：放回去
		backpack_manager.place_item(item_data, new_root_pos)
		GlobalAudio.play_sfx("place")
		
		var new_instance = backpack_manager.grid[new_root_pos]
		item_ui.set("item_instance", new_instance)
		item_ui.set("item_data", new_instance.data)
		
		# 视觉表现
		if backpack_ui.has_method("add_item_visual"):
			backpack_ui.add_item_visual(item_ui, new_root_pos)
		print("[BattleManager] 旋转成功，新位置: ", new_root_pos)
	else:
		# 3b. 碰撞检测失败：恢复状态并强制弹出 (符合用户对“失败弹出”位置的需求)
		item_data.direction = old_direction
		item_data.shape = old_shape
		if item_ui.has_method("_sync_visuals"):
			item_ui._sync_visuals()
			
		print("[BattleManager] 旋转导致碰撞/出界，强制弹出到侧边。")
		_handle_place_failure(item_ui, Vector2i(-1, -1), [])

## 处理玩家放置物品的逻辑请求
func request_place_item(item_ui: Control, grid_pos: Vector2i):
	var item_data = item_ui.get("item_data") as ItemData
	if not item_data: return
	
	var old_pos = _find_item_old_pos(item_data)
	var old_shape = _get_logical_shape_in_grid(item_data)
	
	if grid_pos == Vector2i(-1, -1):
		request_place_item_outside(item_ui)
		return

	# 在检查可放置性之前，先把物品从网格中临时移除
	# 这样拖拽多格物品时就不会和它自己原本的格子发生碰撞
	if old_pos != Vector2i(-1, -1):
		backpack_manager.remove_by_runtime_id(item_data.runtime_id)

	if not backpack_manager.can_place_item(item_data, grid_pos):
		# 如果放置失败，_handle_place_failure 会负责把它放回 old_pos
		_handle_place_failure(item_ui, old_pos, old_shape)
		return
	
	backpack_manager.place_item(item_data, grid_pos)
	GlobalAudio.play_sfx("place")
	
	var bus = get_node_or_null("/root/GlobalEventBus")
	if bus:
		bus.item_placed.emit(backpack_manager.grid[grid_pos])
	
	var old_data = item_data
	var new_instance = backpack_manager.grid[grid_pos]
	item_ui.set("item_instance", new_instance)
	item_ui.set("item_data", new_instance.data)
	
	if is_instance_valid(backpack_ui):
		if backpack_ui.has_method("update_item_mapping"):
			backpack_ui.update_item_mapping(old_data, new_instance.data)
		if backpack_ui.has_method("add_item_visual"):
			backpack_ui.add_item_visual(item_ui, grid_pos)
	_apply_ornament_item_placed(new_instance)
	
	print("[BattleManager] 物品已放置")

## 处理物品放置到背包外的逻辑
func request_place_item_outside(item_ui: Control):
	var item_data = item_ui.get("item_data") as ItemData
	if not item_data: return
	
	var old_pos = _find_item_old_pos(item_data)
	if old_pos != Vector2i(-1, -1):
		backpack_manager.remove_by_runtime_id(item_data.runtime_id)
	_remove_item_visual_mapping(item_data)
	item_ui.set("item_instance", null)
	_move_item_visual_outside(item_ui, item_ui.global_position)
	
	if is_instance_valid(backpack_ui) and backpack_ui.has_method("update_slot_visuals"):
		backpack_ui.update_slot_visuals()
	
	print("[BattleManager] Item placed outside backpack")

func request_discard_item(item_ui: Control):
	var item_data = item_ui.get("item_data") as ItemData
	if not item_data: return
	
	print("[BattleManager] 正在丢弃物品: ", item_data.item_name)
	
	# 1. 如果在背包内，先移除
	var old_pos = _find_item_old_pos(item_data)
	var old_instance = backpack_manager.grid.get(old_pos) if old_pos != Vector2i(-1, -1) else null
	if old_pos != Vector2i(-1, -1):
		backpack_manager.remove_by_runtime_id(item_data.runtime_id)
	_remove_item_visual_mapping(item_data)
		
	# 2. 触发丢弃效果
	for effect in item_data.effects:
		if old_instance != null and effect.has_method("on_discard_instance"):
			effect.on_discard_instance(old_instance, context)
		else:
			effect.on_discard(item_data, context)
	_apply_ornament_item_discarded(item_data, old_instance, old_instance != null)
	_apply_tool_item_discarded(item_data, old_instance, old_instance != null)
	var bus = get_node_or_null("/root/GlobalEventBus")
	if bus:
		bus.item_discarded.emit(item_data)
		
	# 3. 视觉表现与清理
	if managed_item_uis.has(item_ui):
		managed_item_uis.erase(item_ui)
		
	item_ui.queue_free()
	GlobalAudio.play_sfx("discard")

## 清理所有不在背包格宫内的物品
func discard_all_outside_items():
	print("[BattleManager] 正在自动清理背包外物品...")
	var to_discard = []
	for item_ui in managed_item_uis:
		if not is_instance_valid(item_ui): continue
		
		# 检查它是否在逻辑网格中
		var item_instance = item_ui.get("item_instance")
		if item_instance == null:
			to_discard.append(item_ui)
			
	for item_ui in to_discard:
		request_discard_item(item_ui)
	
	print("[BattleManager] 清理完成，共丢弃 ", to_discard.size(), " 件物品。")

func _rotate_outside_item(item_ui: Control, _mouse_global_pos: Vector2, pivot_offset: Vector2i):
	var item_data = item_ui.get("item_data") as ItemData
	if not item_data: return
	
	var new_pivot_offset = item_data.get_rotated_offset(pivot_offset)
	item_data.rotate_90()
	if item_ui.has_method("_sync_visuals"):
		item_ui._sync_visuals()
	
	var pivot_delta = Vector2(pivot_offset.x - new_pivot_offset.x, pivot_offset.y - new_pivot_offset.y)
	_move_item_visual_outside(item_ui, item_ui.global_position + pivot_delta * Vector2(100.0, 94.0) * 0.7)
	GlobalAudio.play_sfx("place")
	print("[BattleManager] Outside item rotated")

func _move_item_visual_outside(item_ui: Control, global_pos: Vector2):
	var target_parent = _get_outside_item_parent()
	if target_parent and item_ui.get_parent() != target_parent:
		if item_ui.get_parent():
			item_ui.get_parent().remove_child(item_ui)
		target_parent.add_child(item_ui)
	
	item_ui.scale = Vector2(0.7, 0.7)
	item_ui.global_position = global_pos
	item_ui.z_index = 0

func _get_outside_item_parent() -> Node:
	if is_instance_valid(backpack_ui):
		var grid_panel = backpack_ui.get_parent()
		if grid_panel and grid_panel.get_parent():
			return grid_panel.get_parent()
	if get_parent():
		return get_parent()
	return self

func _remove_item_visual_mapping(item_data: ItemData):
	if not is_instance_valid(backpack_ui):
		return
	var item_ui_map = backpack_ui.get("item_ui_map")
	if item_ui_map is Dictionary and item_ui_map.has(item_data.runtime_id):
		item_ui_map.erase(item_data.runtime_id)
		backpack_ui.set("item_ui_map", item_ui_map)

func _on_backpack_item_data_replaced(old_data: ItemData, new_instance: BackpackManager.ItemInstance) -> void:
	for runtime in active_ornaments:
		var ornament = runtime.get("data")
		var state = runtime.get("state", {}) as Dictionary
		if ornament != null and ornament.effect != null:
			ornament.effect.after_item_replaced(old_data, new_instance, context, state)

	if not is_instance_valid(backpack_ui) or old_data == null or new_instance == null:
		return
	var item_ui_map = backpack_ui.get("item_ui_map")
	if not (item_ui_map is Dictionary):
		return

	var item_ui = item_ui_map.get(old_data.runtime_id)
	if item_ui == null:
		item_ui = item_ui_map.get(new_instance.data.runtime_id)
	if not is_instance_valid(item_ui):
		return

	item_ui.set("item_data", new_instance.data)
	item_ui.set("item_instance", new_instance)
	if item_ui.has_method("_sync_visuals"):
		item_ui._sync_visuals()
	if backpack_ui.has_method("update_item_mapping"):
		backpack_ui.update_item_mapping(old_data, new_instance.data)

func _get_logical_shape_in_grid(item_data: ItemData) -> Array[Vector2i]:
	var old_pos = _find_item_old_pos(item_data)
	if old_pos != Vector2i(-1, -1):
		return backpack_manager.grid[old_pos].data.shape
	return item_data.shape

func _handle_place_failure(item_ui: Control, old_pos: Vector2i, _old_shape: Array[Vector2i]):
	var item_data = item_ui.get("item_data") as ItemData
	if old_pos != Vector2i(-1, -1) and backpack_manager.can_place_item(item_data, old_pos):
		backpack_manager.place_item(item_data, old_pos)
		var new_instance = backpack_manager.grid[old_pos]
		item_ui.set("item_instance", new_instance)
		item_ui.set("item_data", new_instance.data)
		if is_instance_valid(backpack_ui) and backpack_ui.has_method("add_item_visual"):
			backpack_ui.add_item_visual(item_ui, old_pos)
	else:
		GlobalAudio.play_sfx("error")
		if item_ui.get_parent() == backpack_ui:
			backpack_ui.remove_child(item_ui)
			# 统一回到 ContentLayer (scale 1.0)，避免叠加 GridPanel 的 0.7 缩放
			var content_layer = backpack_ui.get_parent().get_parent()
			if content_layer:
				content_layer.add_child(item_ui)
			else:
				# 兜底方案
				get_parent().add_child(item_ui)
				
		item_ui.set("item_instance", null)
		item_ui.scale = Vector2(0.7, 0.7)
		
		# 统一弹出位置：背包左侧一点 (相对 GridPanel 坐标系)
		var bp_rect = backpack_ui.get_global_rect() if is_instance_valid(backpack_ui) else Rect2(Vector2(500, 300), Vector2(1,1))
		item_ui.global_position = Vector2(bp_rect.position.x - 180, bp_rect.position.y + 150)
		
		var tween = create_tween()
		tween.tween_property(item_ui, "scale", Vector2(0.77, 0.77), 0.1)
		tween.tween_property(item_ui, "scale", Vector2(0.7, 0.7), 0.1)

func trigger_impact_at(pos: Vector2i):
	queue_impact_at(pos, -1, null, "direct")

func queue_impact_at(pos: Vector2i, direction: int = -1, source: BackpackManager.ItemInstance = null, reason: String = "queued", filters: Array[String] = []) -> bool:
	var instance = _resolve_impact_source(pos, source)
	if instance == null or instance.data == null:
		return false

	var impact_direction = direction
	if impact_direction < 0:
		impact_direction = instance.data.direction

	_impact_queue_sequence += 1
	_impact_queue.append(_make_impact_queue_item(instance.root_pos, impact_direction, instance, reason, filters))
	_sort_impact_queue()

	if battle_state == BattleState.INTERACTIVE and not _is_processing_impact_queue:
		call_deferred("_process_impact_queue")
	return true

func request_draw():
	if battle_state != BattleState.INTERACTIVE:
		return
	battle_state = BattleState.DRAWING
	if _current_battle_deck.is_empty():
		_initialize_battle_data()
	if _current_battle_deck.is_empty():
		_settle_interactive_state()
		return
	
	GlobalAudio.play_sfx("draw")
	var item_id = _current_battle_deck.pop_back()
	var item_db = get_node_or_null("/root/ItemDatabase")
	var item = item_db.get_item_by_id(item_id)
	if item:
		battle_state = BattleState.RESOLVING
		_process_new_item_acquisition(item)
		await _process_impact_queue()
	_settle_interactive_state()

func _process_new_item_acquisition(item: ItemData):
	if not item: return
	
	draw_count += 1
	
	# 扣除捕梦梦值
	var gs = get_node_or_null("/root/GameState")
	if gs:
		var cost = 0
		if item.base_cost == -1:
			# 特殊规则：阶梯递增 (例如：基础 1 + 已经抽取的次数)
			cost = 1 + draw_count
		else:
			# 其他数值取绝对值作为消耗，避免负数变成恢复
			cost = abs(item.base_cost)
		cost = max(1, cost + int(_battle_modifiers.get("draw_cost_delta", 0)))
		if _next_draw_cost_discount > 0:
			cost = max(1, cost - _next_draw_cost_discount)
			_next_draw_cost_discount = 0
		
		var actual_cost = apply_sanity_loss(cost, "draw", item)
		print("[BattleManager] 捕梦消耗: ", actual_cost, " (原始: ", cost, ") | 当前抽卡次数: ", draw_count)
	
	if item.runtime_id <= 0:
		item.runtime_id = randi()
	for effect in item.effects:
		effect.on_draw(item, context)
	item_drawn.emit(item)
	var all_instances = backpack_manager.get_all_instances()
	for inst in all_instances:
		for effect in inst.data.effects:
			if effect.has_method("on_global_item_drawn"):
				effect.on_global_item_drawn(item, inst, context)
	_apply_ornament_item_drawn(item)

func _try_consume_insurance_contract():
	var gs = get_node_or_null("/root/GameState")
	var rm = get_node_or_null("/root/RunManager")
	if gs == null or rm == null:
		return
	if rm.has_method("current_battle_has_score_target") and not rm.current_battle_has_score_target():
		return
	var target_score = rm.get_current_battle_target_score() if rm.has_method("get_current_battle_target_score") else rm.get_target_score()
	if target_score < 0 or gs.current_score >= target_score:
		return

	for instance in backpack_manager.get_all_instances():
		if instance.data.id != "insurance_contract":
			continue
		var recovery = 5
		for effect in instance.data.effects:
			if effect.has_method("get_sanity_recovery"):
				recovery = effect.get_sanity_recovery(instance, context)
				break
		backpack_manager.remove_instance(instance)
		gs.heal_sanity(recovery)
		return

func _process_impact_queue() -> void:
	if _is_processing_impact_queue:
		return
	if battle_state == BattleState.FINISHING or battle_state == BattleState.FINISHED:
		_impact_queue.clear()
		return

	_is_processing_impact_queue = true
	while not _impact_queue.is_empty():
		if battle_state == BattleState.FINISHING or battle_state == BattleState.FINISHED:
			_impact_queue.clear()
			break

		var queue_item = _dequeue_next_impact()
		if not _is_impact_queue_item_valid(queue_item):
			continue

		var source = queue_item["source"] as BackpackManager.ItemInstance
		await _run_impact_sequence(source.root_pos, queue_item["direction"], source, false, Array(queue_item.get("filters", [])))

	_is_processing_impact_queue = false
	_settle_interactive_state()

func _run_impact_sequence(start_pos: Vector2i, dir: ItemData.Direction, source: BackpackManager.ItemInstance = null, settle_after: bool = true, filters: Array[String] = []):
	if battle_state == BattleState.FINISHING or battle_state == BattleState.FINISHED:
		return
	battle_state = BattleState.RESOLVING
	turn_started.emit()
	var resolver = ImpactResolver.new(backpack_manager, context)
	var actions = resolver.resolve_impact(start_pos, dir, source, filters)
	var player = SequencePlayer.new()
	add_child(player)
	var ui_map = {}
	if is_instance_valid(backpack_ui):
		ui_map = backpack_ui.get("item_ui_map")
	await player.play_sequence(actions, ui_map, context)
	_apply_ornament_impact_chain_resolved(source, actions)
	player.queue_free()
	turn_finished.emit()
	if settle_after:
		_settle_interactive_state()

func _apply_ornament_item_drawn(item: ItemData) -> void:
	for runtime in active_ornaments:
		var ornament = runtime.get("data")
		var state = runtime.get("state", {}) as Dictionary
		if ornament != null and ornament.effect != null:
			ornament.effect.after_item_drawn(item, draw_count, context, state)

func _apply_ornament_battle_started() -> void:
	for runtime in active_ornaments:
		var ornament = runtime.get("data")
		var state = runtime.get("state", {}) as Dictionary
		if ornament != null and ornament.effect != null:
			ornament.effect.after_battle_started(context, state)

func _apply_ornament_item_placed(instance: BackpackManager.ItemInstance) -> void:
	for runtime in active_ornaments:
		var ornament = runtime.get("data")
		var state = runtime.get("state", {}) as Dictionary
		if ornament != null and ornament.effect != null:
			ornament.effect.after_item_placed(instance, context, state)

func _apply_ornament_item_discarded(item_data: ItemData, old_instance: BackpackManager.ItemInstance, from_backpack: bool) -> void:
	for runtime in active_ornaments:
		var ornament = runtime.get("data")
		var state = runtime.get("state", {}) as Dictionary
		if ornament != null and ornament.effect != null:
			ornament.effect.after_item_discarded(item_data, old_instance, from_backpack, context, state)

func _apply_tool_item_discarded(item_data: ItemData, old_instance: BackpackManager.ItemInstance, from_backpack: bool) -> void:
	if old_instance != null and old_instance.data != null and old_instance.data.has_meta("tool_apple_wax"):
		if context != null:
			context.change_sanity(2)
		if item_data != null and item_data.id == "apple":
			var item_db = get_node_or_null("/root/ItemDatabase")
			if item_db != null:
				backpack_manager.sow_seed(old_instance, old_instance.data.direction, item_db, 1)

	if _tool_recycling_clip_pending > 0 and _is_waste_item(item_data):
		_tool_recycling_clip_pending -= 1
		if context != null:
			context.add_score(8)
		var rm = get_node_or_null("/root/RunManager")
		var item_db = get_node_or_null("/root/ItemDatabase")
		if rm != null and rm.has_method("grant_item"):
			rm.grant_item("paper_ball", "deck", item_db, "recycling_clip")

func _apply_ornament_tool_used(tool_data, target: Dictionary, result: Dictionary) -> void:
	for runtime in active_ornaments:
		var ornament = runtime.get("data")
		var state = runtime.get("state", {}) as Dictionary
		if ornament != null and ornament.effect != null and ornament.effect.has_method("after_tool_used"):
			ornament.effect.after_tool_used(tool_data, target, result, context, state)

func _is_waste_item(item_data: ItemData) -> bool:
	return item_data != null and (item_data.tags.has("废弃物") or item_data.price < 0)

func _apply_ornament_impact_chain_resolved(source: BackpackManager.ItemInstance, actions: Array[GameAction]) -> void:
	for runtime in active_ornaments:
		var ornament = runtime.get("data")
		var state = runtime.get("state", {}) as Dictionary
		if ornament != null and ornament.effect != null:
			ornament.effect.after_impact_chain_resolved(source, actions, context, state)

func _on_ornament_seed_sown(instance) -> void:
	if not _is_instance_in_grid(instance):
		return
	for runtime in active_ornaments:
		var ornament = runtime.get("data")
		var state = runtime.get("state", {}) as Dictionary
		if ornament != null and ornament.effect != null:
			ornament.effect.after_seed_sown(instance, context, state)

func _on_ornament_seed_upgraded(instance, old_level: int, new_level: int) -> void:
	if not _is_instance_in_grid(instance):
		return
	for runtime in active_ornaments:
		var ornament = runtime.get("data")
		var state = runtime.get("state", {}) as Dictionary
		if ornament != null and ornament.effect != null:
			ornament.effect.after_seed_upgraded(instance, old_level, new_level, context, state)

func _on_ornament_seed_sow_failed(source, direction: int) -> void:
	if source != null and not _is_instance_in_grid(source):
		return
	for runtime in active_ornaments:
		var ornament = runtime.get("data")
		var state = runtime.get("state", {}) as Dictionary
		if ornament != null and ornament.effect != null:
			ornament.effect.after_seed_sow_failed(source, direction, context, state)

func _on_ornament_pollution_changed(instance, old_value: int, new_value: int) -> void:
	if not _is_instance_in_grid(instance):
		return
	for runtime in active_ornaments:
		var ornament = runtime.get("data")
		var state = runtime.get("state", {}) as Dictionary
		if ornament != null and ornament.effect != null:
			ornament.effect.after_pollution_changed(instance, old_value, new_value, context, state)

func _resolve_impact_source(pos: Vector2i, source: BackpackManager.ItemInstance = null) -> BackpackManager.ItemInstance:
	if source != null:
		if _is_instance_in_grid(source):
			return source
		return null
	if backpack_manager.grid.has(pos):
		return backpack_manager.grid[pos]
	return null

func _is_instance_in_grid(instance: BackpackManager.ItemInstance) -> bool:
	if instance == null:
		return false
	if backpack_manager.grid.has(instance.root_pos) and backpack_manager.grid[instance.root_pos] == instance:
		return true
	for value in backpack_manager.grid.values():
		if value == instance:
			return true
	return false

func _make_impact_queue_item(pos: Vector2i, direction: int, source: BackpackManager.ItemInstance, reason: String, filters: Array[String] = []) -> Dictionary:
	return {
		"pos": pos,
		"direction": direction,
		"source": source,
		"reason": reason,
		"filters": filters.duplicate(),
		"priority": _get_impact_priority(pos),
		"sequence": _impact_queue_sequence,
	}

func _get_impact_priority(pos: Vector2i) -> int:
	return pos.y * max(1, backpack_manager.grid_width) + pos.x

func _sort_impact_queue() -> void:
	_impact_queue.sort_custom(_compare_impact_queue_items)

func _compare_impact_queue_items(a: Dictionary, b: Dictionary) -> bool:
	var a_priority = int(a.get("priority", 0))
	var b_priority = int(b.get("priority", 0))
	if a_priority == b_priority:
		return int(a.get("sequence", 0)) < int(b.get("sequence", 0))
	return a_priority < b_priority

func _dequeue_next_impact() -> Dictionary:
	_sort_impact_queue()
	return _impact_queue.pop_front()

func _is_impact_queue_item_valid(queue_item: Dictionary) -> bool:
	if queue_item.is_empty() or not queue_item.has("source"):
		return false
	var source = queue_item["source"] as BackpackManager.ItemInstance
	return _is_instance_in_grid(source)

func _find_item_old_pos(item_data: ItemData) -> Vector2i:
	for pos in backpack_manager.grid.keys():
		var inst = backpack_manager.grid[pos]
		if inst.data.runtime_id == item_data.runtime_id:
			return inst.root_pos
	return Vector2i(-1, -1)

func debug_get_item(item_id: String):
	var item_db = get_node_or_null("/root/ItemDatabase")
	if item_db:
		var item = item_db.get_item_by_id(item_id)
		if item:
			_process_new_item_acquisition(item)

func debug_clear_all():
	if backpack_manager:
		backpack_manager.grid.clear()
		if is_instance_valid(backpack_ui) and backpack_ui.has_method("_refresh_grid"):
			backpack_ui._refresh_grid()

func request_finish_battle(reason: String = "manual") -> bool:
	if battle_state == BattleState.FINISHING or battle_state == BattleState.FINISHED:
		return false
	if battle_state == BattleState.DRAWING or battle_state == BattleState.RESOLVING:
		_pending_finish_reason = reason
		return true
	_emit_finish_requested(reason)
	return true

func mark_battle_finished() -> void:
	_pending_finish_reason = ""
	battle_state = BattleState.FINISHED

func _settle_interactive_state() -> void:
	if battle_state == BattleState.FINISHING or battle_state == BattleState.FINISHED:
		return
	battle_state = BattleState.INTERACTIVE
	if _pending_finish_reason != "":
		var reason = _pending_finish_reason
		_pending_finish_reason = ""
		_emit_finish_requested(reason)

func _emit_finish_requested(reason: String) -> void:
	battle_state = BattleState.FINISHING
	battle_finish_requested.emit(reason)
