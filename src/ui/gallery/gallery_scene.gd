extends Control

## 图鉴场景：以相册页素材拼装物品图鉴，右侧为绳网索引，左侧为选中物体和记忆纸片。
const BASE_SIZE := Vector2(1920.0, 1080.0)
const PHOTO_CORNER_TEXTURE := preload("res://assets/ui/gallery/photo_corner.png")
const SLOT_STYLE_NORMAL := Color(0.78, 0.72, 0.61, 0.82)
const SLOT_STYLE_HOVER := Color(0.86, 0.78, 0.62, 0.92)
const SLOT_STYLE_SELECTED := Color(0.93, 0.82, 0.58, 0.98)
const SLOT_TEXT_COLOR := Color(0.10, 0.065, 0.035, 0.94)
const SLOT_SELECTED_TEXT_COLOR := Color(0.05, 0.03, 0.018, 1.0)

const ART_RECTS := {
	"WoodFloor": Rect2(0.0, 0.0, 1920.0, 1080.0),
	"RedBookCover": Rect2(32.0, 38.0, 1916.0, 1047.0),
	"BackTab": Rect2(4.0, 68.0, 207.0, 161.0),
	"AlbumPage": Rect2(51.0, 0.0, 1670.0, 1080.0),
	"BackpackTab": Rect2(27.0, 292.0, 223.0, 179.0),
	"GalleryTab": Rect2(50.0, 399.0, 205.0, 183.0),
	"SettingsTab": Rect2(8.0, 497.0, 214.0, 186.0),
	"AlbumTab": Rect2(1604.0, 191.0, 217.0, 164.0),
	"GridBackdrop": Rect2(870.0, 120.0, 780.0, 818.0),
	"Magnifier": Rect2(385.0, 55.0, 629.0, 910.0),
	"ForgetMeNot": Rect2(1540.0, 490.0, 435.0, 612.0),
	"AlbumRingRight": Rect2(1793.0, 3.0, 127.0, 1063.0),
}

const CONTROL_RECTS := {
	"BackButton": Rect2(0.0, 70.0, 92.0, 112.0),
	"ItemScroll": Rect2(912.0, 182.0, 694.0, 628.0),
	"SelectedPaper": Rect2(515.0, 150.0, 238.0, 218.0),
	"MemoryPaper": Rect2(338.0, 540.0, 298.0, 400.0),
	"DetailName": Rect2(284.0, 590.0, 78.0, 132.0),
	"DetailText": Rect2(392.0, 628.0, 205.0, 286.0),
}

const STATIC_LABEL_RECTS := {
	"LabelObjectA": Rect2(218.0, 142.0, 70.0, 120.0),
	"LabelObjectB": Rect2(280.0, 140.0, 120.0, 210.0),
}

const STATIC_LABEL_TEXT := {
	"LabelObjectA": "物\n体",
	"LabelObjectB": "便\n利\n贴",
}

const ITEM_CELL_SIZE := Vector2(99.14, 125.6)
const ITEM_COLUMNS := 7
const MEMORY_TEXT_LIMIT := 124

var _selected_item_id := ""
var _slot_buttons: Array[Button] = []

@onready var item_grid: GridContainer = $UiLayer/ItemScroll/ItemGrid
@onready var item_scroll: ScrollContainer = $UiLayer/ItemScroll
@onready var detail_name: Label = $UiLayer/DetailName
@onready var detail_text: Label = $UiLayer/DetailText
@onready var selected_name: Label = $UiLayer/SelectedPaper/SelectedName
@onready var selected_meta: Label = $UiLayer/SelectedPaper/SelectedMeta
@onready var art_layer: Control = $ArtLayer
@onready var ui_layer: Control = $UiLayer

func _ready() -> void:
	print("[Gallery] 进入物品图鉴")
	GlobalInput.set_context(GlobalInput.Context.UI)
	resized.connect(_layout_controls)
	_ensure_static_labels()
	_configure_static_text()
	_populate_gallery()
	call_deferred("_layout_controls")

func _input(event: InputEvent) -> void:
	if not GlobalInput.can_cancel():
		return
	if event.is_action_pressed("ui_cancel") or Input.is_key_pressed(KEY_ESCAPE):
		_on_back_pressed()
		get_viewport().set_input_as_handled()

func _populate_gallery() -> void:
	var item_db = get_node_or_null("/root/ItemDatabase")
	if item_db == null:
		return

	for child in item_grid.get_children():
		child.queue_free()
	_slot_buttons.clear()

	var item_ids: Array = item_db.items.keys()
	item_ids.sort()
	for item_id in item_ids:
		var item: ItemData = item_db.items[item_id]
		var button := _create_item_slot(item)
		item_grid.add_child(button)
		_slot_buttons.append(button)

	if not item_ids.is_empty():
		_select_item(item_db.items[item_ids[0]])

func _create_item_slot(item: ItemData) -> Button:
	var button := Button.new()
	button.custom_minimum_size = ITEM_CELL_SIZE
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.text = ""
	button.tooltip_text = _plain_text(item.get_tooltip_text())
	button.clip_text = true
	button.set_meta("item_id", item.id)
	button.add_theme_stylebox_override("normal", _make_slot_style(SLOT_STYLE_NORMAL, Color(0.20, 0.12, 0.06, 0.22), 1))
	button.add_theme_stylebox_override("hover", _make_slot_style(SLOT_STYLE_HOVER, Color(0.35, 0.19, 0.08, 0.36), 1))
	button.add_theme_stylebox_override("pressed", _make_slot_style(SLOT_STYLE_SELECTED, Color(0.42, 0.24, 0.08, 0.54), 2))
	button.pressed.connect(func(): _select_item(item))

	var corner := TextureRect.new()
	corner.name = "PhotoCorner"
	corner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	corner.texture = PHOTO_CORNER_TEXTURE
	corner.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	corner.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	button.add_child(corner)

	var label := Label.new()
	label.name = "NameLabel"
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.text = item.item_name
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("font_color", SLOT_TEXT_COLOR)
	label.add_theme_font_size_override("font_size", 15)
	button.add_child(label)

	var pin := ColorRect.new()
	pin.name = "SelectionPin"
	pin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pin.color = Color(0.50, 0.15, 0.10, 0.0)
	button.add_child(pin)

	return button

func _select_item(item: ItemData) -> void:
	_selected_item_id = item.id
	selected_name.text = item.item_name
	selected_meta.text = _build_selected_meta(item)
	detail_name.text = "记\n忆"
	detail_text.text = _build_memory_text(item)
	_update_slot_selection()

func _build_selected_meta(item: ItemData) -> String:
	var lines: Array[String] = []
	if item.tags.is_empty():
		lines.append("无词条")
	else:
		lines.append(" / ".join(item.tags))
	lines.append("价格 " + str(item.price))
	if item.base_cost == -1:
		lines.append("捕梦消耗 阶梯")
	else:
		lines.append("捕梦消耗 " + str(item.base_cost))
	return "\n".join(lines)

func _build_memory_text(item: ItemData) -> String:
	var lines: Array[String] = []
	var tooltip := _plain_text(item.get_tooltip_text())
	if tooltip != "":
		lines.append(tooltip)
	elif item.description != "":
		lines.append(_plain_text(item.description))
	else:
		lines.append("这段记忆还没有留下说明。")

	var text := "\n\n".join(lines).strip_edges()
	if text.length() > MEMORY_TEXT_LIMIT:
		text = text.substr(0, MEMORY_TEXT_LIMIT - 1).strip_edges() + "..."
	return text

func _plain_text(source: String) -> String:
	var text := source
	for token in [
		"[color=#ffaa55]",
		"[color=#ff5555]",
		"[color=#55ff55]",
		"[/color]",
	]:
		text = text.replace(token, "")
	return text.strip_edges()

func _update_slot_selection() -> void:
	for button in _slot_buttons:
		var selected := str(button.get_meta("item_id", "")) == _selected_item_id
		var label := button.get_node_or_null("NameLabel") as Label
		var pin := button.get_node_or_null("SelectionPin") as ColorRect
		if selected:
			button.add_theme_stylebox_override("normal", _make_slot_style(SLOT_STYLE_SELECTED, Color(0.42, 0.24, 0.08, 0.54), 2))
			button.z_index = 2
			if label != null:
				label.add_theme_color_override("font_color", SLOT_SELECTED_TEXT_COLOR)
			if pin != null:
				pin.color = Color(0.62, 0.16, 0.10, 0.85)
		else:
			button.add_theme_stylebox_override("normal", _make_slot_style(SLOT_STYLE_NORMAL, Color(0.20, 0.12, 0.06, 0.22), 1))
			button.z_index = 0
			if label != null:
				label.add_theme_color_override("font_color", SLOT_TEXT_COLOR)
			if pin != null:
				pin.color = Color(0.50, 0.15, 0.10, 0.0)

func _layout_controls() -> void:
	_layout_art_nodes()
	var viewport_size := get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		viewport_size = BASE_SIZE
	var scale_factor := maxf(viewport_size.x / BASE_SIZE.x, viewport_size.y / BASE_SIZE.y)
	var displayed_art_size := BASE_SIZE * scale_factor
	var displayed_art_origin := (viewport_size - displayed_art_size) * 0.5

	for node_name in CONTROL_RECTS.keys():
		var node := get_node_or_null("UiLayer/%s" % node_name) as Control
		if node == null:
			continue
		var source_rect: Rect2 = CONTROL_RECTS[node_name]
		var target_rect := Rect2(
			displayed_art_origin + source_rect.position * scale_factor,
			source_rect.size * scale_factor
		)
		node.position = target_rect.position
		node.size = target_rect.size

	for node_name in STATIC_LABEL_RECTS.keys():
		var label := get_node_or_null("UiLayer/%s" % node_name) as Label
		if label == null:
			continue
		var label_source_rect: Rect2 = STATIC_LABEL_RECTS[node_name]
		var label_target_rect := Rect2(
			displayed_art_origin + label_source_rect.position * scale_factor,
			label_source_rect.size * scale_factor
		)
		label.position = label_target_rect.position
		label.size = label_target_rect.size
		label.add_theme_font_size_override("font_size", roundi(40.0 * scale_factor))

	_layout_detail_text(scale_factor)
	_layout_item_slots(scale_factor)

func _layout_detail_text(scale_factor: float) -> void:
	detail_name.add_theme_font_size_override("font_size", roundi(38.0 * scale_factor))
	detail_text.add_theme_font_size_override("font_size", roundi(20.0 * scale_factor))
	selected_name.add_theme_font_size_override("font_size", roundi(24.0 * scale_factor))
	selected_meta.add_theme_font_size_override("font_size", roundi(16.0 * scale_factor))

func _layout_item_slots(scale_factor: float) -> void:
	var cell_size := ITEM_CELL_SIZE * scale_factor
	var rows := ceili(float(max(1, _slot_buttons.size())) / float(ITEM_COLUMNS))
	item_grid.custom_minimum_size = Vector2(cell_size.x * ITEM_COLUMNS, cell_size.y * rows)
	item_grid.add_theme_constant_override("h_separation", 0)
	item_grid.add_theme_constant_override("v_separation", 0)

	for button in _slot_buttons:
		button.custom_minimum_size = cell_size
		var corner := button.get_node_or_null("PhotoCorner") as TextureRect
		if corner != null:
			corner.position = Vector2(4.0, 3.0) * scale_factor
			corner.size = Vector2(39.0, 40.0) * scale_factor
		var label := button.get_node_or_null("NameLabel") as Label
		if label != null:
			label.position = Vector2(12.0, 18.0) * scale_factor
			label.size = (ITEM_CELL_SIZE - Vector2(24.0, 34.0)) * scale_factor
			label.add_theme_font_size_override("font_size", roundi(15.0 * scale_factor))
		var pin := button.get_node_or_null("SelectionPin") as ColorRect
		if pin != null:
			pin.position = Vector2(30.0, 10.0) * scale_factor
			pin.size = Vector2(38.0, 6.0) * scale_factor

func _layout_art_nodes() -> void:
	for node_name in ART_RECTS.keys():
		var node := get_node_or_null("ArtLayer/%s" % node_name) as Control
		if node == null:
			continue
		var target := _art_rect_to_viewport(ART_RECTS[node_name])
		node.position = target.position
		node.size = target.size

func _art_rect_to_viewport(source_rect: Rect2) -> Rect2:
	var viewport_size := get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		viewport_size = BASE_SIZE
	var scale_factor := maxf(viewport_size.x / BASE_SIZE.x, viewport_size.y / BASE_SIZE.y)
	var displayed_art_size := BASE_SIZE * scale_factor
	var displayed_art_origin := (viewport_size - displayed_art_size) * 0.5
	return Rect2(
		displayed_art_origin + source_rect.position * scale_factor,
		source_rect.size * scale_factor
	)

func _ensure_static_labels() -> void:
	for node_name in STATIC_LABEL_RECTS.keys():
		if ui_layer.has_node(node_name):
			continue
		var label := Label.new()
		label.name = node_name
		label.text = STATIC_LABEL_TEXT[node_name]
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.add_theme_color_override("font_color", Color(0.03, 0.02, 0.015, 1))
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		ui_layer.add_child(label)

func _configure_static_text() -> void:
	detail_name.text = "记\n忆"
	detail_name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	detail_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	detail_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	detail_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	selected_name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	selected_meta.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

func _make_slot_style(fill: Color, border: Color, border_width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.border_width_left = border_width
	style.border_width_top = border_width
	style.border_width_right = border_width
	style.border_width_bottom = border_width
	style.corner_radius_top_left = 2
	style.corner_radius_top_right = 2
	style.corner_radius_bottom_left = 2
	style.corner_radius_bottom_right = 2
	style.content_margin_left = 0
	style.content_margin_top = 0
	style.content_margin_right = 0
	style.content_margin_bottom = 0
	return style

func _on_back_pressed() -> void:
	GlobalScene.go_back()
