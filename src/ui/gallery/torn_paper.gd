extends Control

@export var fill_color := Color(0.45, 0.31, 0.20, 0.88)
@export var edge_color := Color(0.22, 0.14, 0.08, 0.28)
@export var grain_color := Color(0.95, 0.84, 0.62, 0.08)
@export var corner_softness := 14.0

const EDGE_POINTS := [
	Vector2(0.06, 0.02),
	Vector2(0.30, 0.00),
	Vector2(0.55, 0.03),
	Vector2(0.77, 0.01),
	Vector2(0.97, 0.08),
	Vector2(1.00, 0.34),
	Vector2(0.95, 0.58),
	Vector2(0.99, 0.84),
	Vector2(0.86, 0.98),
	Vector2(0.57, 0.95),
	Vector2(0.34, 1.00),
	Vector2(0.09, 0.94),
	Vector2(0.00, 0.70),
	Vector2(0.04, 0.44),
	Vector2(0.01, 0.20),
]

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()

func _draw() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return

	var points := PackedVector2Array()
	for point in EDGE_POINTS:
		points.append(Vector2(point.x * size.x, point.y * size.y))

	var shadow_points := PackedVector2Array()
	for point in points:
		shadow_points.append(point + Vector2(4.0, 5.0))

	draw_polygon(shadow_points, [Color(0.10, 0.06, 0.03, 0.18)])
	draw_polygon(points, [fill_color])
	draw_polyline(points, edge_color, 2.0, true)
	draw_line(points[points.size() - 1], points[0], edge_color, 2.0, true)

	var stripe_count := 12
	for i in range(stripe_count):
		var y := size.y * (float(i) / float(stripe_count))
		draw_line(Vector2(size.x * 0.12, y), Vector2(size.x * 0.88, y + sin(float(i)) * 3.0), grain_color, 1.0, true)
