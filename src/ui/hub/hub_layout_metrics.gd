extends RefCounted

const DesignScaler = preload("res://src/ui/layout/ui_design_scaler.gd")

static func calculate(viewport_size: Vector2, source_size: Vector2, source_offset: Vector2) -> Dictionary:
	var scale_factor := DesignScaler.get_scale_factor(viewport_size, source_size, DesignScaler.SCALE_MODE_CONTAIN)
	var book_origin := DesignScaler.get_design_origin(viewport_size, source_size, scale_factor)
	return {
		"scale": scale_factor,
		"book_origin": book_origin,
		"art_origin": book_origin + source_offset * scale_factor,
	}

static func source_rect_to_viewport(source_rect: Rect2, viewport_size: Vector2, source_size: Vector2, source_offset: Vector2) -> Rect2:
	var offset_rect := Rect2(source_rect.position + source_offset, source_rect.size)
	return DesignScaler.design_to_viewport_rect(offset_rect, viewport_size, source_size, DesignScaler.SCALE_MODE_CONTAIN)

static func apply_node2d_source_transform(node: Node2D, origin: Vector2, scale_factor: float) -> void:
	if node == null:
		return
	node.position = origin
	node.scale = Vector2(scale_factor, scale_factor)

static func apply_scaled_control_root(control: Control, origin: Vector2, source_size: Vector2, scale_factor: float) -> void:
	if control == null:
		return
	control.set_anchors_preset(Control.PRESET_TOP_LEFT, true)
	control.position = origin
	control.size = source_size
	control.scale = Vector2(scale_factor, scale_factor)

static func apply_full_size_control(control: Control, source_size: Vector2) -> void:
	if control == null:
		return
	control.set_anchors_preset(Control.PRESET_TOP_LEFT, true)
	control.position = Vector2.ZERO
	control.size = source_size
	control.scale = Vector2.ONE
