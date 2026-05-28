extends Control

@export var columns := 7
@export var rows := 5
@export var rope_margin := Vector4(42.0, 62.0, 44.0, 128.0)

const BACKING_COLOR := Color(0.63, 0.48, 0.30, 0.20)
const PAPER_WASH := Color(0.78, 0.66, 0.48, 0.16)
const ROPE_DARK := Color(0.55, 0.20, 0.08, 0.95)
const ROPE_MID := Color(0.78, 0.33, 0.12, 0.98)
const ROPE_LIGHT := Color(0.96, 0.55, 0.26, 0.85)
const KNOT_SHADOW := Color(0.24, 0.09, 0.03, 0.30)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()

func _draw() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return

	draw_rect(Rect2(Vector2.ZERO, size), BACKING_COLOR, true)
	_draw_paper_grain()

	var left := rope_margin.x
	var top := rope_margin.y
	var right := size.x - rope_margin.z
	var bottom := size.y - rope_margin.w
	var grid_rect := Rect2(Vector2(left, top), Vector2(right - left, bottom - top))
	if grid_rect.size.x <= 0.0 or grid_rect.size.y <= 0.0:
		return

	var rope_width := maxf(5.0, size.x / 110.0)
	for col in range(columns + 1):
		var x := lerpf(grid_rect.position.x, grid_rect.end.x, float(col) / float(columns))
		_draw_rope_line(Vector2(x, grid_rect.position.y), Vector2(x, grid_rect.end.y), rope_width, col % 2 == 0)

	for row in range(rows + 1):
		var y := lerpf(grid_rect.position.y, grid_rect.end.y, float(row) / float(rows))
		_draw_rope_line(Vector2(grid_rect.position.x, y), Vector2(grid_rect.end.x, y), rope_width, row % 2 != 0)

	for col in range(columns + 1):
		var x := lerpf(grid_rect.position.x, grid_rect.end.x, float(col) / float(columns))
		for row in range(rows + 1):
			var y := lerpf(grid_rect.position.y, grid_rect.end.y, float(row) / float(rows))
			_draw_knot(Vector2(x, y), rope_width)

func _draw_paper_grain() -> void:
	var stripe_count := 22
	for i in range(stripe_count):
		var y := size.y * (float(i) / float(stripe_count))
		var alpha := 0.04 if i % 2 == 0 else 0.025
		draw_rect(Rect2(0.0, y, size.x, 2.0), Color(PAPER_WASH.r, PAPER_WASH.g, PAPER_WASH.b, alpha), true)

func _draw_rope_line(from: Vector2, to: Vector2, width: float, flip: bool) -> void:
	draw_line(from + Vector2(2.0, 3.0), to + Vector2(2.0, 3.0), KNOT_SHADOW, width + 5.0, true)
	draw_line(from, to, ROPE_DARK, width + 2.0, true)
	draw_line(from, to, ROPE_MID, width, true)

	var delta := to - from
	var length := delta.length()
	if length <= 0.0:
		return
	var direction := delta.normalized()
	var normal := Vector2(-direction.y, direction.x)
	var step := maxf(18.0, width * 2.4)
	var slash_len := width * 2.0
	var count := int(length / step)
	for i in range(count + 1):
		var center := from + direction * (float(i) * step)
		var side := -1.0 if ((i % 2 == 0) == flip) else 1.0
		var a := center - direction * slash_len + normal * side * width * 0.38
		var b := center + direction * slash_len - normal * side * width * 0.38
		draw_line(a, b, ROPE_LIGHT, maxf(1.5, width * 0.32), true)

func _draw_knot(pos: Vector2, width: float) -> void:
	var radius := maxf(7.0, width * 1.25)
	draw_circle(pos + Vector2(2.0, 3.0), radius * 1.15, KNOT_SHADOW)
	draw_circle(pos, radius, ROPE_DARK)
	draw_circle(pos, radius * 0.72, ROPE_MID)
	draw_circle(pos + Vector2(-radius * 0.18, -radius * 0.20), radius * 0.28, ROPE_LIGHT)
