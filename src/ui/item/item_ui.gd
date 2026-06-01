class_name ItemUI
extends Control

@export var item_data: ItemData

const DIRECTION_LINE_MIN_LENGTH := 14.0
const DIRECTION_LINE_MAX_LENGTH := 22.0
const DIRECTION_MARKER_CELL_X := 0.80
const DIRECTION_MARKER_CELL_Y := 0.28
const ROTATION_REQUEST_COOLDOWN_MSEC := 180

var cell_size: Vector2 = Vector2.ZERO
var item_instance: BackpackManager.ItemInstance:
	set(v):
		if item_instance and item_instance.pollution_changed.is_connected(_on_item_pollution_changed):
			item_instance.pollution_changed.disconnect(_on_item_pollution_changed)
		item_instance = v
		if item_instance and not item_instance.pollution_changed.is_connected(_on_item_pollution_changed):
			item_instance.pollution_changed.connect(_on_item_pollution_changed)
		_sync_visuals()
		_refresh_hover_tooltip()

@onready var background = $Background
@onready var direction_icon = $DirectionIcon
@onready var icon = $Icon
@onready var pollution_label = $PollutionLabel
@onready var name_label = $NameLabel
@onready var stack_label = $StackLabel

signal dropped(item_ui: Control, mouse_global_pos: Vector2, pivot_offset: Vector2i)
signal drag_moved(item_ui: Control, center_pos: Vector2, pivot_offset: Vector2i)
signal rotation_requested(item_ui: Control, mouse_global_pos: Vector2, pivot_offset: Vector2i)

var _is_dragging: bool = false
var _is_hovered: bool = false
var _drag_offset: Vector2 = Vector2.ZERO
var _held_pivot_offset: Vector2i = Vector2i.ZERO
var _direction_flash := 0.0:
	set(value):
		_direction_flash = clampf(value, 0.0, 1.0)
		queue_redraw()
var _last_direction: int = -1
var _has_direction_state := false
var _direction_feedback_tween: Tween = null
var _rotation_blocked_tween: Tween = null
var _last_rotation_emit_msec := -ROTATION_REQUEST_COOLDOWN_MSEC


func _ready():
	set_process(false)
	add_to_group("item_uis")
	_init_cell_size_from_scene()
	if direction_icon:
		direction_icon.visible = false
	if item_data:
		setup(item_data)
	gui_input.connect(_on_gui_input)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)


func _exit_tree():
	if _direction_feedback_tween != null and _direction_feedback_tween.is_running():
		_direction_feedback_tween.kill()
	if _rotation_blocked_tween != null and _rotation_blocked_tween.is_running():
		_rotation_blocked_tween.kill()
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
	if not is_node_ready():
		return
	if not item_data:
		return
	_init_cell_size_from_scene()
	if name_label:
		name_label.text = item_data.item_name
	if icon:
		icon.texture = item_data.icon
		icon.visible = item_data.icon != null
	if background:
		background.visible = item_data.icon == null

	var rect = item_data.get_bounding_rect()
	custom_minimum_size = Vector2(rect.size.x * cell_size.x, rect.size.y * cell_size.y)
	size = custom_minimum_size

	_update_direction_visual()

	if item_instance and item_instance.current_pollution > 0:
		pollution_label.text = str(item_instance.current_pollution)
		pollution_label.show()
	else:
		pollution_label.hide()
	_update_stack_visual()
	queue_redraw()

func _update_stack_visual() -> void:
	if stack_label == null:
		return
	if not _is_tool_item():
		stack_label.hide()
		return
	var count := 1
	if item_instance != null:
		count = max(1, int(item_instance.stack_count))
	elif item_data != null and item_data.has_meta("stack_count"):
		count = max(1, int(item_data.get_meta("stack_count")))
	stack_label.text = "x%d" % count
	stack_label.show()

func _is_tool_item() -> bool:
	return item_data != null and (item_data.tags.has("道具") or bool(item_data.get_meta("is_tool", false)))
func _update_direction_visual():
	if direction_icon:
		direction_icon.visible = false
		match item_data.direction:
			ItemData.Direction.UP:
				direction_icon.rotation_degrees = -90
			ItemData.Direction.DOWN:
				direction_icon.rotation_degrees = 90
			ItemData.Direction.LEFT:
				direction_icon.rotation_degrees = 180
			ItemData.Direction.RIGHT:
				direction_icon.rotation_degrees = 0
	var new_direction := int(item_data.direction)
	if _has_direction_state and _last_direction != new_direction:
		_play_direction_feedback()
	_last_direction = new_direction
	_has_direction_state = true


func _draw() -> void:
	if item_data == null:
		return
	_draw_direction_preview()


func _draw_direction_preview() -> void:
	var direction := _get_direction_vector()
	if direction == Vector2.ZERO:
		return
	var shortest_side := minf(size.x, size.y)
	var center := _get_direction_marker_center()
	var half_length := clampf(shortest_side * 0.14, DIRECTION_LINE_MIN_LENGTH * 0.5, DIRECTION_LINE_MAX_LENGTH * 0.5)
	var start := center - direction * half_length
	var end := center + direction * half_length
	var line_width := _get_direction_line_width()
	draw_line(start, end, Color.BLACK, line_width, true)
	var side := Vector2(-direction.y, direction.x)
	var head_length := line_width * 1.55
	var head_width := line_width * 1.05
	var head_tip := end + direction * head_length
	var head_base := end - direction * head_length * 0.3
	draw_line(head_tip, head_base + side * head_width, Color.BLACK, line_width, true)
	draw_line(head_tip, head_base - side * head_width, Color.BLACK, line_width, true)


func _get_direction_marker_center() -> Vector2:
	var top_right_cell := _get_top_right_bounding_cell()
	var rect := item_data.get_bounding_rect()
	var local_cell := top_right_cell - rect.position
	return Vector2(
		(float(local_cell.x) + DIRECTION_MARKER_CELL_X) * cell_size.x,
		(float(local_cell.y) + DIRECTION_MARKER_CELL_Y) * cell_size.y
	)


func _get_top_right_bounding_cell() -> Vector2i:
	if item_data == null or item_data.shape.is_empty():
		return Vector2i.ZERO
	var rect := item_data.get_bounding_rect()
	return rect.position + Vector2i(maxi(rect.size.x - 1, 0), 0)


func _get_direction_line_width() -> float:
	var shortest_side := minf(size.x, size.y)
	var width_scale := 0.04
	if _is_hovered or _is_dragging:
		width_scale = 0.052
	var line_width := clampf(shortest_side * width_scale, 2.75, 4.25)
	if _direction_flash > 0.01:
		line_width += 0.75 * _direction_flash
	return line_width


func _get_direction_vector() -> Vector2:
	match item_data.direction:
		ItemData.Direction.UP:
			return Vector2.UP
		ItemData.Direction.DOWN:
			return Vector2.DOWN
		ItemData.Direction.LEFT:
			return Vector2.LEFT
	return Vector2.RIGHT


func _play_direction_feedback() -> void:
	if not is_inside_tree():
		return
	if _direction_feedback_tween != null and _direction_feedback_tween.is_running():
		_direction_feedback_tween.kill()
	_direction_flash = 1.0
	_direction_feedback_tween = create_tween()
	_direction_feedback_tween.tween_property(self, "_direction_flash", 0.0, 0.24).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func play_impact_anim():
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2(1.2, 1.2), 0.1)
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.1)
	return tween.finished


func play_effect_anim():
	var base_scale = scale
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", base_scale * 1.2, 0.1)
	tween.tween_property(background, "color", Color.WHITE, 0.1)
	tween.set_parallel(false)
	tween.tween_property(self, "scale", base_scale, 0.1)
	tween.tween_property(background, "color", Color(0.25, 0.45, 0.65, 1), 0.1)
	return tween.finished


func _on_gui_input(event: InputEvent):
	if not GlobalInput.can_interact_with_cards():
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_start_drag(event.position, get_global_mouse_position())
			else:
				_stop_drag()
			accept_event()
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			_request_rotation(event.position, get_global_mouse_position())
			accept_event()


func _on_mouse_entered():
	_is_hovered = true
	queue_redraw()
	if not _is_dragging and item_data:
		GlobalTooltip.show_item(item_data, item_instance)


func _on_mouse_exited():
	_is_hovered = false
	queue_redraw()
	GlobalTooltip.hide()


func _on_item_pollution_changed(_new_val: int):
	_sync_visuals()
	_refresh_hover_tooltip()


func _refresh_hover_tooltip():
	if _is_hovered and not _is_dragging and item_data:
		GlobalTooltip.show_item(item_data, item_instance)


func _start_drag(local_mouse: Vector2 = get_local_mouse_position(), global_mouse_pos: Vector2 = get_global_mouse_position()):
	_is_dragging = true
	set_process(true)
	var safe_cell_size := Vector2(maxf(cell_size.x, 1.0), maxf(cell_size.y, 1.0))
	_held_pivot_offset = Vector2i(
		floori(local_mouse.x / safe_cell_size.x),
		floori(local_mouse.y / safe_cell_size.y)
	)
	_drag_offset = global_mouse_pos - global_position
	z_index = 100
	GlobalTooltip.hide()
	queue_redraw()


func _stop_drag():
	if not _is_dragging:
		return
	_is_dragging = false
	set_process(false)
	z_index = 0
	queue_redraw()
	dropped.emit(self, get_global_mouse_position(), _held_pivot_offset)


func _request_rotation(local_mouse: Vector2 = get_local_mouse_position(), mouse_global_pos: Vector2 = get_global_mouse_position()):
	_is_dragging = false
	set_process(false)
	queue_redraw()
	if item_data == null or not item_data.can_rotate:
		_play_rotation_blocked_feedback()
		return
	if _should_ignore_duplicate_rotation_emit():
		return
	var safe_cell_size := Vector2(maxf(cell_size.x, 1.0), maxf(cell_size.y, 1.0))
	var item_pivot_offset = Vector2i(
		floori(local_mouse.x / safe_cell_size.x),
		floori(local_mouse.y / safe_cell_size.y)
	)
	rotation_requested.emit(self, mouse_global_pos, item_pivot_offset)


func _should_ignore_duplicate_rotation_emit() -> bool:
	var now := Time.get_ticks_msec()
	if now - _last_rotation_emit_msec < ROTATION_REQUEST_COOLDOWN_MSEC:
		return true
	_last_rotation_emit_msec = now
	return false


func _play_rotation_blocked_feedback() -> void:
	GlobalAudio.play_sfx("error")
	if not is_inside_tree():
		return
	if _rotation_blocked_tween != null and _rotation_blocked_tween.is_running():
		_rotation_blocked_tween.kill()
	var base_scale := scale
	_rotation_blocked_tween = create_tween()
	_rotation_blocked_tween.tween_property(self, "scale", base_scale * 0.94, 0.05)
	_rotation_blocked_tween.tween_property(self, "scale", base_scale, 0.09)


func _process(_delta):
	if _is_dragging:
		global_position = get_global_mouse_position() - _drag_offset
		drag_moved.emit(self, get_global_mouse_position(), _held_pivot_offset)

