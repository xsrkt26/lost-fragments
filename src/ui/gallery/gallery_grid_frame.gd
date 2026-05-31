extends Control

const FRAME_TEXTURE: Texture2D = preload("res://assets/ui/gallery/gallery_cell_frame.png")

@export var columns := 7
@export var row_count := 1
@export var cell_size := Vector2(99.14, 125.6)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func set_grid_size(p_columns: int, p_rows: int, p_cell_size: Vector2) -> void:
	columns = maxi(1, p_columns)
	row_count = maxi(1, p_rows)
	cell_size = p_cell_size
	var content_size := Vector2(cell_size.x * columns, cell_size.y * row_count)
	custom_minimum_size = content_size
	size = content_size
	queue_redraw()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()

func _draw() -> void:
	if FRAME_TEXTURE == null or cell_size.x <= 0.0 or cell_size.y <= 0.0:
		return

	for row in range(row_count):
		for column in range(columns):
			var rect := Rect2(Vector2(column * cell_size.x, row * cell_size.y), cell_size)
			draw_texture_rect(FRAME_TEXTURE, rect, false)
