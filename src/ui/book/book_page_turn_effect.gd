@tool
class_name BookPageTurnEffect
extends Control

const PAGE_TURN_SHADER_PATH := "res://src/ui/transitions/page_turn.gdshader"

@export var curl_width := 0.26:
	set(value):
		curl_width = clampf(value, 0.05, 0.45)
		_sync_shader_parameters()

@export var page_back_color := Color(0.92, 0.86, 0.72, 1.0):
	set(value):
		page_back_color = value
		_sync_shader_parameters()

@export var crease_shadow_color := Color(0.0, 0.0, 0.0, 0.36):
	set(value):
		crease_shadow_color = value
		_sync_shader_parameters()

@export var highlight_color := Color(1.0, 0.95, 0.78, 0.24):
	set(value):
		highlight_color = value
		_sync_shader_parameters()

@export var fallback_page_color := Color(0.88, 0.78, 0.59, 1.0):
	set(value):
		fallback_page_color = value
		_fallback_texture = null

var progress := 0.0:
	set(value):
		progress = clampf(value, 0.0, 1.0)
		_sync_shader_parameters()
		queue_redraw()

var _page_texture: Texture2D = null
var _front_tint := Color.WHITE
var _turn_left_to_right := false
var _shader_material: ShaderMaterial = null
var _fallback_texture: Texture2D = null
var _page_turn_shader: Shader = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_ensure_shader_material()
	queue_redraw()


func start_turn(left_to_right: bool, page_texture: Texture2D, start_progress: float = 0.0, front_tint: Color = Color.WHITE) -> void:
	_ensure_shader_material()
	_page_texture = page_texture
	_front_tint = front_tint
	_turn_left_to_right = left_to_right
	progress = start_progress
	visible = true
	_sync_shader_parameters()
	queue_redraw()


func finish_turn() -> void:
	visible = false
	_page_texture = null
	_front_tint = Color.WHITE
	_turn_left_to_right = false
	progress = 0.0


func _draw() -> void:
	if size.x <= 1.0 or size.y <= 1.0:
		return
	var texture := _page_texture
	if texture == null:
		texture = _get_fallback_texture()
	draw_texture_rect(texture, Rect2(Vector2.ZERO, size), false, _front_tint)


func _ensure_shader_material() -> void:
	if _shader_material != null:
		return
	_page_turn_shader = load(PAGE_TURN_SHADER_PATH) as Shader
	if _page_turn_shader == null:
		material = null
		return
	_shader_material = ShaderMaterial.new()
	_shader_material.shader = _page_turn_shader
	material = _shader_material
	_sync_shader_parameters()


func _sync_shader_parameters() -> void:
	if _shader_material == null:
		return
	_shader_material.set_shader_parameter("progress", progress)
	_shader_material.set_shader_parameter("turn_direction", -1.0 if _turn_left_to_right else 1.0)
	_shader_material.set_shader_parameter("curl_width", curl_width)
	_shader_material.set_shader_parameter("page_back_color", page_back_color)
	_shader_material.set_shader_parameter("crease_shadow_color", crease_shadow_color)
	_shader_material.set_shader_parameter("highlight_color", highlight_color)


func _get_fallback_texture() -> Texture2D:
	if _fallback_texture != null:
		return _fallback_texture
	var image := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	image.fill(fallback_page_color)
	_fallback_texture = ImageTexture.create_from_image(image)
	return _fallback_texture
