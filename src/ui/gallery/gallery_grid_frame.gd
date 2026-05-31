extends Control

const FRAME_TEXTURE: Texture2D = preload("res://assets/ui/gallery/gallery_grid_background.png")

@export var columns := 6
@export var visible_rows := 6
@export var cell_size := Vector2(116.15, 100.0)

var texture_scale := 1.0
var texture_visible_origin := Vector2.ZERO

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = false

func set_grid_size(p_columns: int, p_visible_rows: int, p_cell_size: Vector2) -> void:
	columns = maxi(1, p_columns)
	visible_rows = maxi(1, p_visible_rows)
	cell_size = p_cell_size
	queue_redraw()

func set_texture_layout(p_visible_origin: Vector2, p_scale: float) -> void:
	texture_visible_origin = p_visible_origin
	texture_scale = maxf(0.001, p_scale)
	queue_redraw()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()

func _draw() -> void:
	if FRAME_TEXTURE == null or cell_size.x <= 0.0 or cell_size.y <= 0.0:
		return

	var texture_size := Vector2(FRAME_TEXTURE.get_width(), FRAME_TEXTURE.get_height()) * texture_scale
	var texture_position := -texture_visible_origin * texture_scale
	draw_texture_rect(FRAME_TEXTURE, Rect2(texture_position, texture_size), false)
