extends Control

signal dialogue_finished(sequence_id: String)

const BUBBLE_TEXTURE := preload("res://assets/ui/hub/dialog_bubble.png")
const XIAOMI_TEXTURE := preload("res://assets/ui/hub/xiaomi_cat.png")
const DESIGN_SIZE := Vector2(1920.0, 1080.0)
const BUBBLE_DESIGN_SIZE := Vector2(430.0, 316.0)
const BUBBLE_TEXT_DESIGN_RECT := Rect2(58.0, 48.0, 314.0, 174.0)
const XIAOMI_DESIGN_SIZE := Vector2(164.0, 164.0)
const DEFAULT_BUBBLE_SCALE := 0.78
const SCREEN_MARGIN := 18.0
const TYPE_SPEED := 0.035
const FADE_DURATION := 0.16
const MOVE_DURATION := 0.18

var _bubble_button: Button = null
var _bubble_texture: TextureRect = null
var _content_label: Label = null
var _xiaomi_texture: TextureRect = null
var _ui_root: Control = null
var _sequence_id := ""
var _frames: Array = []
var _current_frame_idx := -1
var _is_typing := false
var _type_timer := 0.0
var _finishing := false
var _layout_tween: Tween = null
var _fade_tween: Tween = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(false)
	_build_nodes()
	_layout_to_parent()
	visible = false


func start_dialogue(sequence_id: String, frames: Array, ui_root: Control) -> void:
	_build_nodes()
	_sequence_id = sequence_id
	_frames = frames.duplicate(true)
	_ui_root = ui_root
	_current_frame_idx = -1
	_is_typing = false
	_type_timer = 0.0
	_finishing = false
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_process(true)
	_next_frame()


func _build_nodes() -> void:
	if _bubble_button != null:
		return
	_xiaomi_texture = TextureRect.new()
	_xiaomi_texture.name = "XiaomiTexture"
	_xiaomi_texture.texture = XIAOMI_TEXTURE
	_xiaomi_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_xiaomi_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_xiaomi_texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_xiaomi_texture)

	_bubble_button = Button.new()
	_bubble_button.name = "DialogueBubbleButton"
	_bubble_button.text = ""
	_bubble_button.focus_mode = Control.FOCUS_NONE
	_bubble_button.mouse_filter = Control.MOUSE_FILTER_STOP
	_bubble_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_bubble_button.modulate.a = 0.0
	_apply_transparent_button_style(_bubble_button)
	_bubble_button.pressed.connect(_advance_dialogue)
	add_child(_bubble_button)

	_bubble_texture = TextureRect.new()
	_bubble_texture.name = "BubbleTexture"
	_bubble_texture.texture = BUBBLE_TEXTURE
	_bubble_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_bubble_texture.stretch_mode = TextureRect.STRETCH_SCALE
	_bubble_texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bubble_button.add_child(_bubble_texture)

	_content_label = Label.new()
	_content_label.name = "ContentLabel"
	_content_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_content_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_content_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_content_label.add_theme_color_override("font_color", Color(0.08, 0.045, 0.018, 1.0))
	_bubble_button.add_child(_content_label)


func _apply_transparent_button_style(button: Button) -> void:
	var empty_style := StyleBoxEmpty.new()
	button.add_theme_stylebox_override("normal", empty_style)
	button.add_theme_stylebox_override("hover", empty_style)
	button.add_theme_stylebox_override("pressed", empty_style)
	button.add_theme_stylebox_override("focus", empty_style)
	button.add_theme_stylebox_override("disabled", empty_style)


func _process(delta: float) -> void:
	_layout_to_parent()
	if not _is_typing or _content_label == null:
		return
	_type_timer += delta
	if _type_timer < TYPE_SPEED:
		return
	_type_timer = 0.0
	_content_label.visible_characters += 1
	if _content_label.visible_characters >= _content_label.get_total_character_count():
		_is_typing = false


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		_advance_dialogue()


func _layout_to_parent() -> void:
	var layout_rect := _get_layout_rect()
	set_anchors_preset(Control.PRESET_TOP_LEFT, true)
	position = layout_rect.position
	size = layout_rect.size


func _next_frame() -> void:
	_current_frame_idx += 1
	if _current_frame_idx >= _frames.size():
		_finish_dialogue()
		return
	var frame_data := _get_current_frame()
	if _content_label != null:
		_content_label.text = str(frame_data.get("text", ""))
		_content_label.visible_characters = 0
	_is_typing = true
	_type_timer = 0.0
	_layout_current_frame(true)
	_play_fade_in()


func _advance_dialogue() -> void:
	if _finishing or _content_label == null:
		return
	if _is_typing:
		_content_label.visible_characters = _content_label.get_total_character_count()
		_is_typing = false
		return
	_next_frame()


func _layout_current_frame(animated: bool) -> void:
	var frame_data := _get_current_frame()
	var bubble_scale := clampf(float(frame_data.get("bubble_scale", DEFAULT_BUBBLE_SCALE)), 0.62, 1.0)
	var xiaomi_scale := clampf(float(frame_data.get("xiaomi_scale", 1.0)), 0.75, 1.25)
	var bubble_size := BUBBLE_DESIGN_SIZE * bubble_scale
	var xiaomi_size := XIAOMI_DESIGN_SIZE * xiaomi_scale
	var target_key := str(frame_data.get("target", frame_data.get("tutorial_target", "center")))
	var target_rect := _get_target_rect(target_key)
	var xiaomi_side := str(frame_data.get("xiaomi_side", _get_default_xiaomi_side(target_key)))
	var bubble_side := str(frame_data.get("bubble_side", _get_default_bubble_side(target_key)))
	var xiaomi_position := _get_xiaomi_position(target_rect, xiaomi_side, xiaomi_size)
	var bubble_position := _get_bubble_position(xiaomi_position, xiaomi_size, bubble_size, bubble_side, target_rect)
	xiaomi_position = _apply_manual_position(frame_data, "xiaomi_position", "xiaomi_offset", xiaomi_position, xiaomi_size)
	bubble_position = _apply_manual_position(frame_data, "bubble_position", "bubble_offset", bubble_position, bubble_size)

	_bubble_button.size = bubble_size
	_bubble_button.pivot_offset = bubble_size * 0.5
	_bubble_texture.position = Vector2.ZERO
	_bubble_texture.size = bubble_size
	_content_label.position = BUBBLE_TEXT_DESIGN_RECT.position * bubble_scale
	_content_label.size = BUBBLE_TEXT_DESIGN_RECT.size * bubble_scale
	_content_label.add_theme_font_size_override("font_size", max(18, int(round(29.0 * bubble_scale))))
	_xiaomi_texture.size = xiaomi_size

	if _layout_tween != null and _layout_tween.is_running():
		_layout_tween.kill()
	if not animated or _current_frame_idx <= 0:
		_xiaomi_texture.position = xiaomi_position
		_bubble_button.position = bubble_position
		return
	_layout_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_layout_tween.tween_property(_xiaomi_texture, "position", xiaomi_position, MOVE_DURATION)
	_layout_tween.tween_property(_bubble_button, "position", bubble_position, MOVE_DURATION)


func _play_fade_in() -> void:
	if _fade_tween != null and _fade_tween.is_running():
		_fade_tween.kill()
	_bubble_button.modulate.a = 0.0
	_xiaomi_texture.modulate.a = 0.0
	_fade_tween = create_tween().set_parallel(true)
	_fade_tween.tween_property(_bubble_button, "modulate:a", 1.0, FADE_DURATION)
	_fade_tween.tween_property(_xiaomi_texture, "modulate:a", 1.0, FADE_DURATION)


func _finish_dialogue() -> void:
	if _finishing:
		return
	_finishing = true
	_is_typing = false
	set_process(false)
	if _fade_tween != null and _fade_tween.is_running():
		_fade_tween.kill()
	_fade_tween = create_tween().set_parallel(true)
	_fade_tween.tween_property(_bubble_button, "modulate:a", 0.0, FADE_DURATION)
	_fade_tween.tween_property(_xiaomi_texture, "modulate:a", 0.0, FADE_DURATION)
	await _fade_tween.finished
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	dialogue_finished.emit(_sequence_id)


func _get_current_frame() -> Dictionary:
	if _current_frame_idx < 0 or _current_frame_idx >= _frames.size():
		return {}
	var frame: Variant = _frames[_current_frame_idx]
	if frame is Dictionary:
		return Dictionary(frame)
	return {}


func _get_layout_rect() -> Rect2:
	var parent_control := get_parent() as Control
	if parent_control != null and parent_control.size.x > 0.0 and parent_control.size.y > 0.0:
		return Rect2(Vector2.ZERO, parent_control.size)
	var viewport_size := get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		viewport_size = DESIGN_SIZE
	return Rect2(Vector2.ZERO, viewport_size)


func _get_target_rect(target_key: String) -> Rect2:
	var control := _get_target_control(target_key)
	if control != null:
		return _control_rect_in_self(control)
	var layout_rect := _get_layout_rect()
	var center := layout_rect.size * 0.5
	return Rect2(center - Vector2(80.0, 80.0), Vector2(160.0, 160.0))


func _get_target_control(target_key: String) -> Control:
	if _ui_root == null or not is_instance_valid(_ui_root):
		return null
	match target_key:
		"dreamcatcher":
			return _ui_root.get_node_or_null("ContentLayer/DreamcatcherPanel") as Control
		"backpack":
			return _ui_root.get_node_or_null("ContentLayer/GridPanel") as Control
		"stats":
			return _ui_root.get_node_or_null("ContentLayer/StatsPanel") as Control
		"score":
			return _ui_root.get_node_or_null("ContentLayer/StatsPanel/ScoreLabel") as Control
		"trash":
			var trash_art := _ui_root.get_node_or_null("ContentLayer/StatsPanel/TrashIconArt") as Control
			if trash_art != null:
				return trash_art
			return _ui_root.get_node_or_null("ContentLayer/GridPanel/TrashBin") as Control
		"ornaments":
			return _ui_root.get_node_or_null("ContentLayer/OrnamentsPanel") as Control
		"tools":
			return _ui_root.get_node_or_null("ContentLayer/ToolPanel") as Control
		"pending":
			return _ui_root.get_node_or_null("ContentLayer/PendingItemPanel") as Control
		_:
			return null


func _control_rect_in_self(control: Control) -> Rect2:
	var global_rect := control.get_global_rect()
	var inverse := get_global_transform().affine_inverse()
	var local_position := inverse * global_rect.position
	var local_end := inverse * global_rect.end
	var min_position := Vector2(minf(local_position.x, local_end.x), minf(local_position.y, local_end.y))
	var max_position := Vector2(maxf(local_position.x, local_end.x), maxf(local_position.y, local_end.y))
	return Rect2(min_position, max_position - min_position)


func _get_default_xiaomi_side(target_key: String) -> String:
	match target_key:
		"dreamcatcher":
			return "right"
		"backpack", "trash", "ornaments":
			return "left"
		"stats":
			return "right"
		_:
			return "bottom"


func _get_default_bubble_side(target_key: String) -> String:
	match target_key:
		"dreamcatcher", "stats":
			return "right"
		"backpack", "trash", "ornaments":
			return "left"
		_:
			return "above"


func _get_xiaomi_position(target_rect: Rect2, side: String, xiaomi_size: Vector2) -> Vector2:
	var gap := 18.0
	var position := target_rect.get_center() - xiaomi_size * 0.5
	match side:
		"left":
			position = Vector2(target_rect.position.x - xiaomi_size.x - gap, target_rect.get_center().y - xiaomi_size.y * 0.5)
		"right":
			position = Vector2(target_rect.end.x + gap, target_rect.get_center().y - xiaomi_size.y * 0.5)
		"top":
			position = Vector2(target_rect.get_center().x - xiaomi_size.x * 0.5, target_rect.position.y - xiaomi_size.y - gap)
		"bottom":
			position = Vector2(target_rect.get_center().x - xiaomi_size.x * 0.5, target_rect.end.y + gap)
		"bottom_left":
			position = Vector2(target_rect.position.x - xiaomi_size.x * 0.3, target_rect.end.y + gap)
		"bottom_right":
			position = Vector2(target_rect.end.x - xiaomi_size.x * 0.7, target_rect.end.y + gap)
	return _clamp_rect_position(position, xiaomi_size)


func _get_bubble_position(xiaomi_position: Vector2, xiaomi_size: Vector2, bubble_size: Vector2, side: String, target_rect: Rect2) -> Vector2:
	var candidates := [side, "right", "left", "above", "below"]
	var best_position := Vector2.ZERO
	var best_overlap := 1.0e20
	for candidate in candidates:
		var position := _candidate_bubble_position(xiaomi_position, xiaomi_size, bubble_size, str(candidate))
		var overlap := _overlap_area(Rect2(position, bubble_size), target_rect)
		if overlap < best_overlap:
			best_overlap = overlap
			best_position = position
	return best_position


func _candidate_bubble_position(xiaomi_position: Vector2, xiaomi_size: Vector2, bubble_size: Vector2, side: String) -> Vector2:
	var gap := 12.0
	var xiaomi_center := xiaomi_position + xiaomi_size * 0.5
	var position := Vector2(xiaomi_center.x - bubble_size.x * 0.5, xiaomi_position.y - bubble_size.y - gap)
	match side:
		"left":
			position = Vector2(xiaomi_position.x - bubble_size.x - gap, xiaomi_position.y - bubble_size.y * 0.22)
		"right":
			position = Vector2(xiaomi_position.x + xiaomi_size.x + gap, xiaomi_position.y - bubble_size.y * 0.22)
		"below":
			position = Vector2(xiaomi_center.x - bubble_size.x * 0.5, xiaomi_position.y + xiaomi_size.y + gap)
		"above":
			position = Vector2(xiaomi_center.x - bubble_size.x * 0.5, xiaomi_position.y - bubble_size.y - gap)
	return _clamp_rect_position(position, bubble_size)


func _clamp_rect_position(position: Vector2, rect_size: Vector2) -> Vector2:
	var layout_size := _get_layout_rect().size
	var margin := SCREEN_MARGIN
	return Vector2(
		clampf(position.x, margin, maxf(margin, layout_size.x - rect_size.x - margin)),
		clampf(position.y, margin, maxf(margin, layout_size.y - rect_size.y - margin))
	)


func _apply_manual_position(frame_data: Dictionary, position_key: String, offset_key: String, auto_position: Vector2, rect_size: Vector2) -> Vector2:
	var position := auto_position
	if _has_vector2_value(frame_data.get(position_key)):
		position = _scale_design_vector(_vector2_from_variant(frame_data.get(position_key), position))
	if _has_vector2_value(frame_data.get(offset_key)):
		position += _scale_design_vector(_vector2_from_variant(frame_data.get(offset_key), Vector2.ZERO))
	return _clamp_rect_position(position, rect_size)


func _scale_design_vector(value: Vector2) -> Vector2:
	var layout_size := _get_layout_rect().size
	if layout_size.x <= 0.0 or layout_size.y <= 0.0:
		return value
	return Vector2(
		value.x * layout_size.x / DESIGN_SIZE.x,
		value.y * layout_size.y / DESIGN_SIZE.y
	)


func _vector2_from_variant(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value
	if value is Vector2i:
		return Vector2(value)
	if value is Dictionary:
		var dict := value as Dictionary
		if dict.has("x") and dict.has("y"):
			return Vector2(float(dict.get("x", fallback.x)), float(dict.get("y", fallback.y)))
		if dict.has("left") and dict.has("top"):
			return Vector2(float(dict.get("left", fallback.x)), float(dict.get("top", fallback.y)))
	if value is Array:
		var array := value as Array
		if array.size() >= 2:
			return Vector2(float(array[0]), float(array[1]))
	return fallback


func _has_vector2_value(value: Variant) -> bool:
	if value is Vector2 or value is Vector2i:
		return true
	if value is Dictionary:
		var dict := value as Dictionary
		return (dict.has("x") and dict.has("y")) or (dict.has("left") and dict.has("top"))
	if value is Array:
		return (value as Array).size() >= 2
	return false


func _overlap_area(a: Rect2, b: Rect2) -> float:
	var left := maxf(a.position.x, b.position.x)
	var top := maxf(a.position.y, b.position.y)
	var right := minf(a.end.x, b.end.x)
	var bottom := minf(a.end.y, b.end.y)
	if right <= left or bottom <= top:
		return 0.0
	return (right - left) * (bottom - top)
