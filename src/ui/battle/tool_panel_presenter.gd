extends RefCounted

const SELECTED_MODULATE := Color(1.0, 0.92, 0.55)
const DEFAULT_MODULATE := Color.WHITE
const TOOL_BUTTON_SIZE := Vector2(72, 56)
const TOOL_ICON_MARGIN := Vector2(8, 4)
const COUNT_LABEL_COLOR := Color(0.10, 0.07, 0.04, 0.96)

static func render(
	tool_panel: Control,
	slot_area: Control,
	entries: Array,
	tool_db: Node,
	selected_tool_id: String,
	button_input_callback: Callable
) -> void:
	if tool_panel == null or slot_area == null:
		return
	_clear_slots(slot_area)
	tool_panel.visible = not entries.is_empty()
	if entries.is_empty():
		return
	for entry in entries:
		var tool_id := str(entry.get("id", ""))
		var button := _create_tool_button(entry, tool_db, tool_id)
		if button_input_callback.is_valid():
			button.gui_input.connect(func(event): button_input_callback.call(event, tool_id, button))
		slot_area.add_child(button)
	update_selection_visuals(slot_area, selected_tool_id)

static func clear(tool_panel: Control, slot_area: Control) -> void:
	if slot_area != null:
		_clear_slots(slot_area)
	if tool_panel != null:
		tool_panel.hide()

static func update_selection_visuals(slot_area: Control, selected_tool_id: String) -> void:
	if slot_area == null:
		return
	for child in slot_area.get_children():
		if child is Button:
			var is_selected := str(child.get_meta("tool_id", "")) == selected_tool_id
			child.modulate = SELECTED_MODULATE if is_selected else DEFAULT_MODULATE

static func _create_tool_button(entry: Dictionary, tool_db: Node, tool_id: String) -> Button:
	var tool = tool_db.get_tool_by_id(tool_id) if tool_db != null and tool_db.has_method("get_tool_by_id") else null
	var button := Button.new()
	button.custom_minimum_size = TOOL_BUTTON_SIZE
	button.focus_mode = Control.FOCUS_NONE
	button.text = ""
	button.tooltip_text = tool.get_tooltip_text(int(entry.get("count", 0))) if tool != null else str(entry.get("description", ""))
	button.set_meta("tool_id", tool_id)
	if tool != null and tool.icon != null:
		_add_icon(button, tool.icon)
		_add_count_label(button, int(entry.get("count", 0)))
	else:
		button.text = "%s\nx%d" % [str(entry.get("title", tool_id)).substr(0, 4), int(entry.get("count", 0))]
	return button

static func _add_icon(button: Button, icon_texture: Texture2D) -> void:
	var icon := TextureRect.new()
	icon.name = "ToolIcon"
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.texture = icon_texture
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.anchor_right = 1.0
	icon.anchor_bottom = 1.0
	icon.offset_left = TOOL_ICON_MARGIN.x
	icon.offset_top = TOOL_ICON_MARGIN.y
	icon.offset_right = -TOOL_ICON_MARGIN.x
	icon.offset_bottom = -TOOL_ICON_MARGIN.y
	button.add_child(icon)

static func _add_count_label(button: Button, count: int) -> void:
	var count_label := Label.new()
	count_label.name = "CountLabel"
	count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	count_label.text = "x%d" % count
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	count_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	count_label.anchor_left = 0.5
	count_label.anchor_top = 0.52
	count_label.anchor_right = 1.0
	count_label.anchor_bottom = 1.0
	count_label.offset_left = 0.0
	count_label.offset_top = 0.0
	count_label.offset_right = -6.0
	count_label.offset_bottom = -4.0
	count_label.add_theme_color_override("font_color", COUNT_LABEL_COLOR)
	count_label.add_theme_color_override("font_shadow_color", Color(1, 1, 1, 0.7))
	count_label.add_theme_constant_override("shadow_offset_x", 1)
	count_label.add_theme_constant_override("shadow_offset_y", 1)
	count_label.add_theme_font_size_override("font_size", 13)
	button.add_child(count_label)

static func _clear_slots(slot_area: Control) -> void:
	for child in slot_area.get_children():
		child.queue_free()
