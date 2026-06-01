class_name OrnamentSlotBar
extends Control

const SLOT_COUNT := 10
const FALLBACK_SIZE := Vector2(767.0, 314.0)
const SLOT_SIZE_RATIO := 0.22
const MIN_SLOT_SIZE := 38.0
const MAX_SLOT_SIZE := 64.0
const ICON_INSET_RATIO := 0.12

const PLAYABLE_BAG_SLOT_CENTERS := [
	Vector2(0.105802, 0.579358),
	Vector2(0.193758, 0.724197),
	Vector2(0.309362, 0.801445),
	Vector2(0.407713, 0.814319),
	Vector2(0.512240, 0.791789),
	Vector2(0.608042, 0.701666),
	Vector2(0.698547, 0.811101),
	Vector2(0.776305, 0.730634),
	Vector2(0.856612, 0.782133),
	Vector2(0.939469, 0.695229),
]


static func render_to_container(
	container: Control,
	ornament_ids: Array,
	ornament_db: Node,
	slot_scale: float = 1.0,
	slot_centers: Array = []
) -> void:
	if container == null:
		return
	clear(container)
	if ornament_db == null or not ornament_db.has_method("get_ornament_by_id"):
		return

	var resolved_size := _get_container_size(container)
	var slot_size := _get_slot_size(resolved_size, slot_scale)
	var centers := PLAYABLE_BAG_SLOT_CENTERS if slot_centers.is_empty() else slot_centers
	var count := mini(mini(ornament_ids.size(), SLOT_COUNT), centers.size())
	for index in range(count):
		var ornament = ornament_db.get_ornament_by_id(str(ornament_ids[index]))
		if ornament == null:
			continue
		var slot := _make_slot_button(ornament, index, slot_size)
		var slot_center: Vector2 = centers[index]
		var center := Vector2(
			slot_center.x * resolved_size.x,
			slot_center.y * resolved_size.y
		)
		container.add_child(slot)
		slot.size = Vector2.ONE * slot_size
		slot.position = center - slot.size * 0.5


static func clear(container: Control) -> void:
	if container == null:
		return
	for child in container.get_children():
		child.queue_free()


static func _get_container_size(container: Control) -> Vector2:
	var resolved_size := container.size
	if resolved_size.x <= 0.0 or resolved_size.y <= 0.0:
		resolved_size = container.custom_minimum_size
	if resolved_size.x <= 0.0 or resolved_size.y <= 0.0:
		resolved_size = FALLBACK_SIZE
	return resolved_size


static func _get_slot_size(container_size: Vector2, slot_scale: float = 1.0) -> float:
	var safe_scale := maxf(slot_scale, 0.1)
	var raw_size := minf(container_size.x * 0.085, container_size.y * SLOT_SIZE_RATIO)
	return clampf(raw_size * safe_scale, MIN_SLOT_SIZE * safe_scale, MAX_SLOT_SIZE * safe_scale)


static func _make_slot_button(ornament, index: int, slot_size: float) -> Button:
	var slot := Button.new()
	slot.name = "OrnamentSlot_%02d" % (index + 1)
	slot.text = ""
	slot.size = Vector2.ONE * slot_size
	slot.custom_minimum_size = slot.size
	slot.focus_mode = Control.FOCUS_NONE
	slot.flat = true
	slot.mouse_filter = Control.MOUSE_FILTER_STOP
	slot.tooltip_text = ""
	slot.set_meta("ornament_id", ornament.id)
	_apply_transparent_button_style(slot)
	_connect_tooltip(slot, ornament)

	if ornament.icon != null:
		var icon := TextureRect.new()
		icon.name = "OrnamentIcon"
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.texture = ornament.icon
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.set_anchors_preset(Control.PRESET_FULL_RECT, true)
		var inset := roundf(slot_size * ICON_INSET_RATIO)
		icon.offset_left = inset
		icon.offset_top = inset
		icon.offset_right = -inset
		icon.offset_bottom = -inset
		slot.add_child(icon)
	else:
		slot.text = str(ornament.ornament_name).substr(0, min(2, str(ornament.ornament_name).length()))
	return slot


static func _connect_tooltip(slot: Button, ornament) -> void:
	slot.mouse_entered.connect(func(): _show_ornament_tooltip(ornament))
	slot.mouse_exited.connect(func(): GlobalTooltip.hide())
	slot.tree_exiting.connect(func(): GlobalTooltip.hide())


static func _show_ornament_tooltip(ornament) -> void:
	if ornament == null:
		GlobalTooltip.hide()
		return
	var title := str(ornament.ornament_name)
	var body: String = str(ornament.get_tooltip_text()) if ornament.has_method("get_tooltip_text") else title
	body = _tooltip_body_without_repeated_title(title, body)
	if GlobalTooltip.has_method("show_text"):
		GlobalTooltip.show_text(title, body)


static func _tooltip_body_without_repeated_title(title: String, body: String) -> String:
	var cleaned := body.strip_edges()
	if title != "" and cleaned.begins_with(title):
		cleaned = cleaned.substr(title.length()).strip_edges()
		if cleaned.begins_with("\n"):
			cleaned = cleaned.substr(1).strip_edges()
	return cleaned


static func _apply_transparent_button_style(button: Button) -> void:
	var empty := StyleBoxEmpty.new()
	button.add_theme_stylebox_override("normal", empty)
	button.add_theme_stylebox_override("hover", empty)
	button.add_theme_stylebox_override("pressed", empty)
	button.add_theme_stylebox_override("disabled", empty)
