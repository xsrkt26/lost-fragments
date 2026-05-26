extends Control

## 图鉴场景：在正式相册美术上展示物品列表和选中详情。

const BASE_SIZE := Vector2(1920.0, 1080.0)
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
	"ItemScroll": Rect2(905.0, 186.0, 690.0, 690.0),
	"DetailName": Rect2(270.0, 585.0, 240.0, 52.0),
	"DetailText": Rect2(358.0, 612.0, 280.0, 300.0),
}
const STATIC_LABEL_RECTS := {
	"LabelObjectA": Rect2(218.0, 142.0, 70.0, 120.0),
	"LabelObjectB": Rect2(280.0, 140.0, 120.0, 210.0),
	"LabelMemory": Rect2(284.0, 590.0, 90.0, 130.0),
}
const STATIC_LABEL_TEXT := {
	"LabelObjectA": "物\n体",
	"LabelObjectB": "便\n利\n贴",
	"LabelMemory": "记\n忆",
}
const ITEM_CELL_SIZE := Vector2(82.0, 106.0)

@onready var item_grid: GridContainer = $UiLayer/ItemScroll/ItemGrid
@onready var item_scroll: ScrollContainer = $UiLayer/ItemScroll
@onready var detail_name: Label = $UiLayer/DetailName
@onready var detail_text: Label = $UiLayer/DetailText
@onready var art_layer: Control = $ArtLayer
@onready var ui_layer: Control = $UiLayer

func _ready() -> void:
	print("[Gallery] 进入物品图鉴")
	GlobalInput.set_context(GlobalInput.Context.UI)
	resized.connect(_layout_controls)
	_ensure_static_labels()
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

	var item_ids: Array = item_db.items.keys()
	item_ids.sort()
	for item_id in item_ids:
		var item: ItemData = item_db.items[item_id]
		var button := Button.new()
		button.custom_minimum_size = ITEM_CELL_SIZE
		button.focus_mode = Control.FOCUS_NONE
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button.text = item.item_name
		button.tooltip_text = item.get_tooltip_text()
		button.clip_text = true
		button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		button.add_theme_font_size_override("font_size", 16)
		button.set_meta("item_id", item.id)
		button.pressed.connect(func(): _select_item(item))
		item_grid.add_child(button)

	if not item_ids.is_empty():
		_select_item(item_db.items[item_ids[0]])

func _select_item(item: ItemData) -> void:
	detail_name.text = item.item_name
	var lines: Array[String] = []
	if not item.tags.is_empty():
		var tag_text := ""
		for tag in item.tags:
			if tag_text != "":
				tag_text += " / "
			tag_text += tag
		lines.append("词条：" + tag_text)
	var tooltip: String = item.get_tooltip_text()
	if tooltip != "":
		lines.append(tooltip.replace("[color=#ffaa55]", "").replace("[color=#ff5555]", "").replace("[/color]", ""))
	if lines.is_empty():
		lines.append("这段记忆还没有留下说明。")
	detail_text.text = "\n\n".join(lines)

func _layout_controls() -> void:
	_layout_art_nodes()
	var viewport_size := get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		viewport_size = BASE_SIZE
	var scale_factor: float = maxf(viewport_size.x / BASE_SIZE.x, viewport_size.y / BASE_SIZE.y)
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
		label.add_theme_font_size_override("font_size", roundi(38.0 * scale_factor))

	var cell_size := ITEM_CELL_SIZE * scale_factor
	for child in item_grid.get_children():
		if child is Control:
			child.custom_minimum_size = cell_size
	item_grid.add_theme_constant_override("h_separation", roundi(12.0 * scale_factor))
	item_grid.add_theme_constant_override("v_separation", roundi(12.0 * scale_factor))

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
	var scale_factor: float = maxf(viewport_size.x / BASE_SIZE.x, viewport_size.y / BASE_SIZE.y)
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

func _on_back_pressed() -> void:
	GlobalScene.go_back()
