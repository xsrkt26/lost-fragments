extends RefCounted

const SCALE_MODE_COVER := "cover"
const SCALE_MODE_CONTAIN := "contain"


static func layout_root(control: Control, viewport_size: Vector2, design_size: Vector2, scale_mode: String = "cover") -> void:
	if control == null:
		return
	var resolved_viewport_size := get_valid_viewport_size(viewport_size, design_size)
	var scale_factor := get_scale_factor(resolved_viewport_size, design_size, scale_mode)
	control.set_anchors_preset(Control.PRESET_TOP_LEFT, true)
	control.position = get_design_origin(resolved_viewport_size, design_size, scale_factor)
	control.size = design_size
	control.scale = Vector2(scale_factor, scale_factor)


static func get_valid_viewport_size(viewport_size: Vector2, fallback_size: Vector2) -> Vector2:
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return fallback_size
	return viewport_size


static func get_scale_factor(viewport_size: Vector2, design_size: Vector2, scale_mode: String = "cover") -> float:
	if design_size.x <= 0.0 or design_size.y <= 0.0:
		return 1.0
	var scale_x := viewport_size.x / design_size.x
	var scale_y := viewport_size.y / design_size.y
	if scale_mode == SCALE_MODE_CONTAIN:
		return minf(scale_x, scale_y)
	return maxf(scale_x, scale_y)


static func get_design_origin(viewport_size: Vector2, design_size: Vector2, scale_factor: float) -> Vector2:
	return (viewport_size - design_size * scale_factor) * 0.5


static func design_to_viewport_rect(rect: Rect2, viewport_size: Vector2, design_size: Vector2, scale_mode: String = "cover") -> Rect2:
	var resolved_viewport_size := get_valid_viewport_size(viewport_size, design_size)
	var scale_factor := get_scale_factor(resolved_viewport_size, design_size, scale_mode)
	return Rect2(
		get_design_origin(resolved_viewport_size, design_size, scale_factor) + rect.position * scale_factor,
		rect.size * scale_factor
	)


static func viewport_to_design_point(point: Vector2, viewport_size: Vector2, design_size: Vector2, scale_mode: String = "cover") -> Vector2:
	var resolved_viewport_size := get_valid_viewport_size(viewport_size, design_size)
	var scale_factor := get_scale_factor(resolved_viewport_size, design_size, scale_mode)
	if scale_factor <= 0.0:
		return point
	return (point - get_design_origin(resolved_viewport_size, design_size, scale_factor)) / scale_factor
