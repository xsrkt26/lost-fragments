extends RefCounted

const SELECTED_MODULATE := Color(1.0, 0.92, 0.55)
const DEFAULT_MODULATE := Color.WHITE
const TOOL_BUTTON_SIZE := Vector2(72, 56)

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
	button.text = "%s\nx%d" % [str(entry.get("title", tool_id)).substr(0, 4), int(entry.get("count", 0))]
	button.tooltip_text = tool.get_tooltip_text(int(entry.get("count", 0))) if tool != null else str(entry.get("description", ""))
	button.set_meta("tool_id", tool_id)
	return button

static func _clear_slots(slot_area: Control) -> void:
	for child in slot_area.get_children():
		child.queue_free()
