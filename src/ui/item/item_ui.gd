class_name ItemUI
extends Control

## 物品 UI 脚本：负责物品的视觉表现和拖拽信号

@export var item_data: ItemData

var cell_size: Vector2 = Vector2.ZERO
var item_instance: BackpackManager.ItemInstance: # 逻辑实例
	set(v):
		if item_instance and item_instance.pollution_changed.is_connected(_on_item_pollution_changed):
			item_instance.pollution_changed.disconnect(_on_item_pollution_changed)
		item_instance = v
		if item_instance and not item_instance.pollution_changed.is_connected(_on_item_pollution_changed):
			item_instance.pollution_changed.connect(_on_item_pollution_changed)
		_sync_visuals()
		_refresh_hover_tooltip()

# --- 视觉节点引用 ---
@onready var background = $Background
@onready var direction_icon = $DirectionIcon
@onready var icon = $Icon
@onready var pollution_label = $PollutionLabel
@onready var name_label = $NameLabel

# --- 信号 ---
signal dropped(mouse_global_pos: Vector2, pivot_offset: Vector2i)
signal drag_moved(item_ui: Control, center_pos: Vector2, pivot_offset: Vector2i)
signal rotation_requested(item_ui: Control, mouse_global_pos: Vector2, pivot_offset: Vector2i)

# --- 交互变量 ---
var _is_dragging: bool = false
var _is_hovered: bool = false
var _drag_offset: Vector2 = Vector2.ZERO
var _held_pivot_offset: Vector2i = Vector2i.ZERO # 拖拽时鼠标按在哪个格子上

func _ready():
	add_to_group("item_uis")
	_init_cell_size_from_scene()
	if item_data:
		setup(item_data)
	
	# 连接鼠标事件
	gui_input.connect(_on_gui_input)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

func _exit_tree():
	if item_instance and item_instance.pollution_changed.is_connected(_on_item_pollution_changed):
		item_instance.pollution_changed.disconnect(_on_item_pollution_changed)
	if _is_hovered:
		GlobalTooltip.hide()

func setup(p_data: ItemData, _context: GameContext = null):
	item_data = p_data
	_sync_visuals()

func set_cell_size(p_cell_size: Vector2) -> void:
	if p_cell_size.x <= 0.0 or p_cell_size.y <= 0.0:
		return
	cell_size = p_cell_size
	_sync_visuals()

func _init_cell_size_from_scene() -> void:
	if cell_size.x > 0.0 and cell_size.y > 0.0:
		return
	cell_size = size
	if cell_size.x <= 0.0 or cell_size.y <= 0.0:
		cell_size = custom_minimum_size
	if cell_size.x <= 0.0 or cell_size.y <= 0.0:
		cell_size = Vector2.ONE

func _sync_visuals():
	if not is_node_ready(): return
	if not item_data: return
	_init_cell_size_from_scene()
	
	# 0. 设置名称
	if name_label:
		name_label.text = item_data.item_name
	
	# 1. 根据 Shape 设置 UI 尺寸
	var rect = item_data.get_bounding_rect()
	# UI 物理像素 = 格子数 * 当前背包网格步进
	custom_minimum_size = Vector2(rect.size.x * cell_size.x, rect.size.y * cell_size.y)
	size = custom_minimum_size
	
	# 2. 设置颜色和方向
	_update_direction_visual()
	
	# 3. 设置污染层级
	if item_instance and item_instance.current_pollution > 0:
		pollution_label.text = str(item_instance.current_pollution)
		pollution_label.show()
	else:
		pollution_label.hide()

func _update_direction_visual():
	if not direction_icon: return
	match item_data.direction:
		ItemData.Direction.UP: direction_icon.rotation_degrees = -90
		ItemData.Direction.DOWN: direction_icon.rotation_degrees = 90
		ItemData.Direction.LEFT: direction_icon.rotation_degrees = 180
		ItemData.Direction.RIGHT: direction_icon.rotation_degrees = 0

# --- 核心动画方法 ---

func play_impact_anim():
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2(1.2, 1.2), 0.1)
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.1)
	return tween.finished

func play_effect_anim():
	var base_scale = scale
	var tween = create_tween()
	# 缩放并改变颜色
	tween.set_parallel(true)
	tween.tween_property(self, "scale", base_scale * 1.2, 0.1)
	tween.tween_property(background, "color", Color.WHITE, 0.1)
	
	tween.set_parallel(false)
	tween.tween_property(self, "scale", base_scale, 0.1)
	tween.tween_property(background, "color", Color(0.25, 0.45, 0.65, 1), 0.1)
	return tween.finished

# --- 交互逻辑 ---

func _on_gui_input(event: InputEvent):
	# 如果处于 LOCKED 模式，完全不响应
	if not GlobalInput.can_interact_with_cards(): return

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_start_drag()
			else:
				_stop_drag()
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			_request_rotation()

func _on_mouse_entered():
	# 只要不是在拖拽中，就显示提示
	_is_hovered = true
	if not _is_dragging and item_data:
		GlobalTooltip.show_item(item_data, item_instance)

func _on_mouse_exited():
	_is_hovered = false
	GlobalTooltip.hide()

func _on_item_pollution_changed(_new_val: int):
	_sync_visuals()
	_refresh_hover_tooltip()

func _refresh_hover_tooltip():
	if _is_hovered and not _is_dragging and item_data:
		GlobalTooltip.show_item(item_data, item_instance)

func _start_drag():
	_is_dragging = true
	var local_mouse = get_local_mouse_position()
	var safe_cell_size := Vector2(maxf(cell_size.x, 1.0), maxf(cell_size.y, 1.0))
	_held_pivot_offset = Vector2i(
		floori(local_mouse.x / safe_cell_size.x),
		floori(local_mouse.y / safe_cell_size.y)
	)
	_drag_offset = get_global_mouse_position() - global_position
	z_index = 100 # 确保在最上方
	GlobalTooltip.hide() # 拖拽时隐藏提示

func _stop_drag():
	if not _is_dragging: return
	_is_dragging = false
	z_index = 0
	
	dropped.emit(get_global_mouse_position(), _held_pivot_offset)

func _request_rotation():
	# 旋转时停止拖拽
	_is_dragging = false
	var local_mouse = get_local_mouse_position()
	var safe_cell_size := Vector2(maxf(cell_size.x, 1.0), maxf(cell_size.y, 1.0))
	var pivot_offset = Vector2i(
		floori(local_mouse.x / safe_cell_size.x),
		floori(local_mouse.y / safe_cell_size.y)
	)
	rotation_requested.emit(self, get_global_mouse_position(), pivot_offset)

func _process(_delta):
	if _is_dragging:
		global_position = get_global_mouse_position() - _drag_offset
		drag_moved.emit(self, get_global_mouse_position(), _held_pivot_offset)
