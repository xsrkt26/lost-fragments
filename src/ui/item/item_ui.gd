class_name ItemUI
extends Control

@export var item_data: ItemData

const DIRECTION_BADGE_MIN_RADIUS := 7.0
const DIRECTION_BADGE_MAX_RADIUS := 11.0
const DIRECTION_BADGE_MARGIN := 4.0
const DIRECTION_BADGE_OVERHANG := 0.42
const DIRECTION_LINE_MIN_LENGTH := 18.0

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

signal dropped(mouse_global_pos: Vector2, pivot_offset: Vector2i)
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
	queue_redraw()


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
	if _is_hovered or _is_dragging:
		_draw_direction_preview()
	_draw_direction_badge()


func _draw_direction_badge() -> void:
	var radius := _get_direction_badge_radius()
	var center := _get_direction_badge_center(radius)
	var is_active := _is_hovered or _is_dragging
	var active_amount := 1.0 if is_active else 0.0
	var opacity := clampf(0.26 + active_amount * 0.22 + _direction_flash * 0.28, 0.0, 0.78)
	var accent_color := Color(0.58, 0.82, 0.9, opacity)
	var shadow_color := Color(0.0, 0.0, 0.0, 0.22 + active_amount * 0.08 + _direction_flash * 0.10)
	if _direction_flash > 0.01:
		draw_circle(center, radius + 5.0 * _direction_flash, Color(0.48, 0.78, 0.96, 0.12 * _direction_flash))
	var corner := Vector2(size.x - DIRECTION_BADGE_MARGIN, DIRECTION_BADGE_MARGIN)
	var corner_arm := radius * 1.5
	draw_line(corner - Vector2(corner_arm, 0.0) + Vector2(1.0, 1.0), corner + Vector2(1.0, 1.0), shadow_color, 2.0, true)
	draw_line(corner + Vector2(1.0, 1.0), corner + Vector2(1.0, corner_arm + 1.0), shadow_color, 2.0, true)
	draw_line(corner - Vector2(corner_arm, 0.0), corner, accent_color, 1.25, true)
	draw_line(corner, corner + Vector2(0.0, corner_arm), accent_color, 1.25, true)
	_draw_direction_arrow(center + Vector2(1.0, 1.0), radius * 0.86, shadow_color, 2.8, 1.0)
	_draw_direction_arrow(center, radius * 0.86, accent_color, 1.65, 1.0)


func _draw_direction_arrow(center: Vector2, radius: float, arrow_color: Color, stroke_width: float, arrow_scale: float) -> void:
	draw_set_transform(center, _get_direction_angle(), Vector2.ONE * arrow_scale)
	draw_line(Vector2(-radius * 0.56, 0.0), Vector2(radius * 0.22, 0.0), arrow_color, stroke_width, true)
	draw_colored_polygon(PackedVector2Array([
		Vector2(radius * 0.08, -radius * 0.36),
		Vector2(radius * 0.58, 0.0),
		Vector2(radius * 0.08, radius * 0.36),
	]), arrow_color)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_direction_preview() -> void:
	var direction := _get_direction_vector()
	if direction == Vector2.ZERO:
		return
	var shortest_side := minf(size.x, size.y)
	var start := size * 0.5 + direction * maxf(8.0, shortest_side * 0.08)
	var end := size * 0.5 + direction * maxf(DIRECTION_LINE_MIN_LENGTH, shortest_side * 0.38)
	var inset := _get_direction_badge_radius() + DIRECTION_BADGE_MARGIN + 3.0
	end.x = clampf(end.x, inset, maxf(inset, size.x - inset))
	end.y = clampf(end.y, inset, maxf(inset, size.y - inset))
	var line_width := clampf(shortest_side * 0.04, 2.0, 4.0)
	draw_line(start + Vector2(1.0, 1.0), end + Vector2(1.0, 1.0), Color(0.0, 0.0, 0.0, 0.26), line_width + 1.5, true)
	draw_line(start, end, Color(0.58, 0.82, 0.9, 0.34), line_width, true)
	var side := Vector2(-direction.y, direction.x)
	var head_length := line_width * 2.25
	var head_width := line_width * 1.45
	draw_colored_polygon(PackedVector2Array([
		end + direction * head_length,
		end - direction * head_length * 0.3 + side * head_width,
		end - direction * head_length * 0.3 - side * head_width,
	]), Color(0.68, 0.9, 1.0, 0.38))


func _get_direction_badge_radius() -> float:
	return clampf(minf(size.x, size.y) * 0.17, DIRECTION_BADGE_MIN_RADIUS, DIRECTION_BADGE_MAX_RADIUS)


func _get_direction_badge_center(radius: float) -> Vector2:
	var inset := radius * (1.0 - DIRECTION_BADGE_OVERHANG) + DIRECTION_BADGE_MARGIN
	return Vector2(maxf(radius + DIRECTION_BADGE_MARGIN, size.x - inset), inset)


func _get_direction_angle() -> float:
	match item_data.direction:
		ItemData.Direction.UP:
			return -PI * 0.5
		ItemData.Direction.DOWN:
			return PI * 0.5
		ItemData.Direction.LEFT:
			return PI
	return 0.0


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
				_start_drag()
			else:
				_stop_drag()
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			_request_rotation()


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


func _start_drag():
	_is_dragging = true
	set_process(true)
	var local_mouse = get_local_mouse_position()
	var safe_cell_size := Vector2(maxf(cell_size.x, 1.0), maxf(cell_size.y, 1.0))
	_held_pivot_offset = Vector2i(
		floori(local_mouse.x / safe_cell_size.x),
		floori(local_mouse.y / safe_cell_size.y)
	)
	_drag_offset = get_global_mouse_position() - global_position
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
	dropped.emit(get_global_mouse_position(), _held_pivot_offset)


func _request_rotation():
	_is_dragging = false
	set_process(false)
	queue_redraw()
	var local_mouse = get_local_mouse_position()
	var safe_cell_size := Vector2(maxf(cell_size.x, 1.0), maxf(cell_size.y, 1.0))
	var item_pivot_offset = Vector2i(
		floori(local_mouse.x / safe_cell_size.x),
		floori(local_mouse.y / safe_cell_size.y)
	)
	rotation_requested.emit(self, get_global_mouse_position(), item_pivot_offset)


func _process(_delta):
	if _is_dragging:
		global_position = get_global_mouse_position() - _drag_offset
		drag_moved.emit(self, get_global_mouse_position(), _held_pivot_offset)
