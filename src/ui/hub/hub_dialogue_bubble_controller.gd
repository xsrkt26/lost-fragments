extends Control

signal dialogue_finished(sequence_id: String)

const DesignScaler = preload("res://src/ui/layout/ui_design_scaler.gd")

const BUBBLE_TEXTURE := preload("res://assets/ui/hub/dialog_bubble.png")
const DESIGN_SIZE := BookBackgroundConfig.DESIGN_SIZE
const BUBBLE_DESIGN_SIZE := Vector2(430.0, 316.0)
const BUBBLE_TEXT_DESIGN_RECT := Rect2(58.0, 48.0, 314.0, 174.0)
const BUBBLE_TAIL_POINT := Vector2(177.0, 298.0)
const XIAOMI_POINTER_OFFSET := Vector2(-24.0, -210.0)
const PLAYER_POINTER_OFFSET := Vector2(0.0, -245.0)
const SCREEN_MARGIN := 18.0
const TYPE_SPEED := 0.035
const FADE_DURATION := 0.18
const HOVER_SCALE := 1.04

const XIAOMI_SPEAKERS := [
	"小咪",
	"小喵",
	"xiaomi",
	"mimi",
	"cat",
]
const PLAYER_SPEAKERS := [
	"主角",
	"主人公",
	"拾忆",
	"我",
	"player",
	"protagonist",
]

var _bubble_button: Button = null
var _bubble_texture: TextureRect = null
var _content_label: Label = null
var _player_anchor: Node = null
var _xiaomi_anchor: Node = null
var _active_anchor: Node = null
var _active_speaker_kind := "xiaomi"
var _sequence_id := ""
var _frames: Array = []
var _current_frame_idx := -1
var _is_typing := false
var _type_timer := 0.0
var _hovered := false
var _finishing := false
var _fade_tween: Tween = null
var _hover_tween: Tween = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT, true)
	_build_bubble()
	if not resized.is_connected(_layout_bubble):
		resized.connect(_layout_bubble)
	_layout_bubble()
	visible = false
	set_process(false)


func start_dialogue(sequence_id: String, frames: Array, player_anchor: Node, xiaomi_anchor: Node) -> void:
	_sequence_id = sequence_id
	_frames = frames.duplicate(true)
	_player_anchor = player_anchor
	_xiaomi_anchor = xiaomi_anchor
	_active_anchor = _xiaomi_anchor
	_active_speaker_kind = "xiaomi"
	_current_frame_idx = -1
	_is_typing = false
	_type_timer = 0.0
	_hovered = false
	_finishing = false
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_process(true)
	_next_frame()


func _build_bubble() -> void:
	_bubble_button = Button.new()
	_bubble_button.name = "DialogueBubbleButton"
	_bubble_button.text = ""
	_bubble_button.focus_mode = Control.FOCUS_NONE
	_bubble_button.mouse_filter = Control.MOUSE_FILTER_STOP
	_bubble_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_bubble_button.modulate.a = 0.0
	_apply_transparent_button_style(_bubble_button)
	_bubble_button.pressed.connect(_on_bubble_pressed)
	_bubble_button.mouse_entered.connect(_on_bubble_mouse_entered)
	_bubble_button.mouse_exited.connect(_on_bubble_mouse_exited)
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


func _layout_bubble() -> void:
	if _bubble_button == null:
		return
	var viewport_size := _get_viewport_size()
	set_anchors_preset(Control.PRESET_TOP_LEFT, true)
	position = Vector2.ZERO
	size = viewport_size
	var scale_factor := _get_scale_factor()
	var bubble_size := BUBBLE_DESIGN_SIZE * scale_factor
	_bubble_button.size = bubble_size
	_bubble_button.pivot_offset = bubble_size * 0.5
	if _bubble_texture != null:
		_bubble_texture.position = Vector2.ZERO
		_bubble_texture.size = bubble_size
	if _content_label != null:
		_content_label.position = BUBBLE_TEXT_DESIGN_RECT.position * scale_factor
		_content_label.size = BUBBLE_TEXT_DESIGN_RECT.size * scale_factor
		_content_label.add_theme_font_size_override("font_size", max(18, int(round(32.0 * scale_factor))))
	_position_bubble()


func _process(delta: float) -> void:
	_position_bubble()
	if not _is_typing or _content_label == null:
		return
	_type_timer += delta
	if _type_timer < TYPE_SPEED:
		return
	_type_timer = 0.0
	_content_label.visible_characters += 1
	if _content_label.visible_characters >= _content_label.get_total_character_count():
		_is_typing = false


func _position_bubble() -> void:
	if _bubble_button == null:
		return
	var viewport_size := _get_viewport_size()
	var scale_factor := _get_scale_factor()
	var anchor_position := _get_anchor_viewport_position(_active_anchor)
	var pointer_offset := XIAOMI_POINTER_OFFSET if _active_speaker_kind == "xiaomi" else PLAYER_POINTER_OFFSET
	var pointer_position := anchor_position + pointer_offset * scale_factor
	var target_position := pointer_position - BUBBLE_TAIL_POINT * scale_factor
	var margin := SCREEN_MARGIN * scale_factor
	target_position.x = clampf(target_position.x, margin, maxf(margin, viewport_size.x - _bubble_button.size.x - margin))
	target_position.y = clampf(target_position.y, margin, maxf(margin, viewport_size.y - _bubble_button.size.y - margin))
	_bubble_button.position = target_position


func _on_bubble_pressed() -> void:
	if _finishing or _content_label == null:
		return
	if _is_typing:
		_content_label.visible_characters = _content_label.get_total_character_count()
		_is_typing = false
		return
	_next_frame()


func _on_bubble_mouse_entered() -> void:
	_hovered = true
	_tween_bubble_scale(HOVER_SCALE)


func _on_bubble_mouse_exited() -> void:
	_hovered = false
	_tween_bubble_scale(1.0)


func _tween_bubble_scale(target_scale: float) -> void:
	if _bubble_button == null:
		return
	if _hover_tween != null and _hover_tween.is_running():
		_hover_tween.kill()
	_hover_tween = create_tween()
	_hover_tween.tween_property(_bubble_button, "scale", Vector2(target_scale, target_scale), 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _next_frame() -> void:
	_current_frame_idx += 1
	if _current_frame_idx >= _frames.size():
		_finish_dialogue()
		return
	var raw_frame: Variant = _frames[_current_frame_idx]
	var frame_data: Dictionary = Dictionary(raw_frame) if raw_frame is Dictionary else {}
	var speaker := str(frame_data.get("speaker", ""))
	var text := str(frame_data.get("text", ""))
	_set_active_speaker(speaker)
	if _content_label != null:
		_content_label.text = text
		_content_label.visible_characters = 0
	_is_typing = true
	_type_timer = 0.0
	_position_bubble()
	_play_bubble_fade_in()


func _set_active_speaker(speaker: String) -> void:
	var normalized := speaker.strip_edges().to_lower()
	if PLAYER_SPEAKERS.has(normalized):
		_active_speaker_kind = "player"
		_active_anchor = _player_anchor
		return
	if XIAOMI_SPEAKERS.has(normalized):
		_active_speaker_kind = "xiaomi"
		_active_anchor = _xiaomi_anchor
		return
	_active_speaker_kind = "xiaomi"
	_active_anchor = _xiaomi_anchor


func _play_bubble_fade_in() -> void:
	if _bubble_button == null:
		return
	if _fade_tween != null and _fade_tween.is_running():
		_fade_tween.kill()
	_bubble_button.modulate.a = 0.0
	_bubble_button.scale = Vector2(HOVER_SCALE, HOVER_SCALE) if _hovered else Vector2.ONE
	_fade_tween = create_tween()
	_fade_tween.tween_property(_bubble_button, "modulate:a", 1.0, FADE_DURATION).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _finish_dialogue() -> void:
	if _finishing:
		return
	_finishing = true
	_is_typing = false
	set_process(false)
	if _fade_tween != null and _fade_tween.is_running():
		_fade_tween.kill()
	_fade_tween = create_tween()
	_fade_tween.tween_property(_bubble_button, "modulate:a", 0.0, FADE_DURATION).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await _fade_tween.finished
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	dialogue_finished.emit(_sequence_id)


func _get_anchor_viewport_position(anchor: Node) -> Vector2:
	var viewport_size := _get_viewport_size()
	if anchor == null or not is_instance_valid(anchor):
		return viewport_size * 0.5
	var control := anchor as Control
	if control != null:
		return control.get_global_rect().get_center()
	var canvas_item := anchor as CanvasItem
	if canvas_item != null:
		return canvas_item.get_global_transform_with_canvas().origin
	return viewport_size * 0.5


func _get_viewport_size() -> Vector2:
	var viewport_size := get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return DESIGN_SIZE
	return viewport_size


func _get_scale_factor() -> float:
	return DesignScaler.get_scale_factor(_get_viewport_size(), DESIGN_SIZE, DesignScaler.SCALE_MODE_COVER)
