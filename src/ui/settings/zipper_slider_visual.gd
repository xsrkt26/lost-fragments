extends Control

@export var top_texture: Texture2D
@export var bottom_texture: Texture2D
@export var head_texture: Texture2D

const CLOSED_GAP := 2.0
const TRACK_TOP_HEIGHT := 24.0
const TRACK_BOTTOM_HEIGHT := 20.0
const HEAD_HEIGHT := 30.0
const MAX_OPEN_ROTATION := 0.18

var zipper_value := 1.0:
	set(new_value):
		zipper_value = clampf(new_value, 0.0, 1.0)
		queue_redraw()

func set_zipper_value(new_value: float) -> void:
	zipper_value = new_value

func get_debug_layout() -> Dictionary:
	var head_w: float = _head_width()
	var head_center_x: float = head_w * 0.5 + zipper_value * maxf(0.0, size.x - head_w)
	var seam_x: float = size.x if zipper_value >= 0.995 else head_center_x
	return {
		"value": zipper_value,
		"head_center_x": head_center_x,
		"closed_width": seam_x,
		"open_width": maxf(0.0, size.x - seam_x),
		"closed_gap": CLOSED_GAP,
	}

func _ready() -> void:
	resized.connect(func(): queue_redraw())

func _draw() -> void:
	if top_texture == null or bottom_texture == null or head_texture == null:
		return
	if size.x <= 0.0 or size.y <= 0.0:
		return

	var top_h: float = minf(TRACK_TOP_HEIGHT, size.y * 0.34)
	var bottom_h: float = minf(TRACK_BOTTOM_HEIGHT, size.y * 0.30)
	var head_w: float = _head_width()
	var head_h: float = _head_height()
	var head_center_x: float = head_w * 0.5 + zipper_value * maxf(0.0, size.x - head_w)
	var seam_x: float = size.x if zipper_value >= 0.995 else head_center_x
	var center_y: float = size.y * 0.5
	var top_join_y: float = center_y - CLOSED_GAP * 0.5
	var bottom_join_y: float = center_y + CLOSED_GAP * 0.5
	var open_width: float = maxf(0.0, size.x - seam_x)

	_draw_closed_segment(seam_x, top_h, bottom_h, top_join_y, bottom_join_y)
	if open_width > 0.5:
		_draw_open_segment(seam_x, open_width, top_h, bottom_h, top_join_y, bottom_join_y)
	_draw_head(head_center_x, center_y, head_w, head_h)

func _draw_closed_segment(width: float, top_h: float, bottom_h: float, top_join_y: float, bottom_join_y: float) -> void:
	if width <= 0.5:
		return
	var top_src := Rect2(0.0, 0.0, top_texture.get_width() * width / size.x, top_texture.get_height())
	var bottom_src := Rect2(0.0, 0.0, bottom_texture.get_width() * width / size.x, bottom_texture.get_height())
	draw_texture_rect_region(
		top_texture,
		Rect2(0.0, top_join_y - top_h, width, top_h),
		top_src
	)
	draw_texture_rect_region(
		bottom_texture,
		Rect2(0.0, bottom_join_y, width, bottom_h),
		bottom_src
	)

func _draw_open_segment(seam_x: float, width: float, top_h: float, bottom_h: float, top_join_y: float, bottom_join_y: float) -> void:
	var src_x_top: float = top_texture.get_width() * seam_x / size.x
	var src_x_bottom: float = bottom_texture.get_width() * seam_x / size.x
	var top_src := Rect2(src_x_top, 0.0, top_texture.get_width() - src_x_top, top_texture.get_height())
	var bottom_src := Rect2(src_x_bottom, 0.0, bottom_texture.get_width() - src_x_bottom, bottom_texture.get_height())
	var rotation_amount: float = MAX_OPEN_ROTATION * (1.0 - zipper_value)

	draw_set_transform(Vector2(seam_x, top_join_y), -rotation_amount, Vector2.ONE)
	draw_texture_rect_region(top_texture, Rect2(0.0, -top_h, width, top_h), top_src)

	draw_set_transform(Vector2(seam_x, bottom_join_y), rotation_amount, Vector2.ONE)
	draw_texture_rect_region(bottom_texture, Rect2(0.0, 0.0, width, bottom_h), bottom_src)

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_head(center_x: float, center_y: float, head_w: float, head_h: float) -> void:
	draw_texture_rect(
		head_texture,
		Rect2(center_x - head_w * 0.5, center_y - head_h * 0.5, head_w, head_h),
		false
	)

func _head_height() -> float:
	if head_texture == null:
		return HEAD_HEIGHT
	return minf(HEAD_HEIGHT, size.y * 0.46)

func _head_width() -> float:
	if head_texture == null:
		return 0.0
	return head_texture.get_width() * _head_height() / maxf(1.0, head_texture.get_height())
