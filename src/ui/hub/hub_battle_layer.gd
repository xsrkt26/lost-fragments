extends "res://src/ui/main_game_ui.gd"

var _hub_dreamcatcher_net: Sprite2D = null
var _hub_dreamcatcher_hit_control: Control = null


func use_hub_dreamcatcher(net: Sprite2D, hit_control: Control) -> void:
	_hub_dreamcatcher_net = net
	_hub_dreamcatcher_hit_control = hit_control
	dreamcatcher_net = net
	var panel := get_node_or_null("ContentLayer/DreamcatcherPanel") as Control
	if panel != null:
		dreamcatcher_panel = panel
		draw_spawn_point = panel
	_sync_hub_dreamcatcher_hit_area()
	_capture_dreamcatcher_net_pose()


func _layout_current_scene() -> void:
	_layout_battle_scene()
	_sync_hub_dreamcatcher_hit_area()


func _configure_dreamcatcher_swing_pivot() -> void:
	pass


func _sync_hub_dreamcatcher_hit_area() -> void:
	if _hub_dreamcatcher_hit_control == null or draw_button == null:
		return
	var panel := get_node_or_null("ContentLayer/DreamcatcherPanel") as Control
	if panel == null:
		return

	var target_rect := _get_hub_dreamcatcher_global_rect()
	var parent_control := panel.get_parent() as Control
	if parent_control == null:
		return
	var inverse_transform := parent_control.get_global_transform().affine_inverse()
	var local_position := inverse_transform * target_rect.position
	var local_end := inverse_transform * target_rect.end
	panel.position = local_position
	panel.size = local_end - local_position
	panel.scale = Vector2.ONE
	panel.rotation = 0.0
	panel.visible = true
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	draw_button.set_anchors_preset(Control.PRESET_TOP_LEFT, true)
	draw_button.position = Vector2.ZERO
	draw_button.size = panel.size
	draw_button.scale = Vector2.ONE
	draw_button.rotation = 0.0
	draw_button.visible = true


func _get_hub_dreamcatcher_global_rect() -> Rect2:
	if _hub_dreamcatcher_net != null and _hub_dreamcatcher_net.texture != null:
		var local_rect := _hub_dreamcatcher_net.get_rect()
		var transform := _hub_dreamcatcher_net.get_global_transform()
		var points := [
			transform * local_rect.position,
			transform * Vector2(local_rect.end.x, local_rect.position.y),
			transform * local_rect.end,
			transform * Vector2(local_rect.position.x, local_rect.end.y),
		]
		var min_point: Vector2 = points[0]
		var max_point: Vector2 = points[0]
		for point in points:
			min_point.x = minf(min_point.x, point.x)
			min_point.y = minf(min_point.y, point.y)
			max_point.x = maxf(max_point.x, point.x)
			max_point.y = maxf(max_point.y, point.y)
		return Rect2(min_point, max_point - min_point)
	if _hub_dreamcatcher_hit_control != null:
		return _hub_dreamcatcher_hit_control.get_global_rect()
	return Rect2()
