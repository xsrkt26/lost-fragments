@tool
class_name BookBackground
extends Control

# Ordered from the top sheet to the bottom sheet.
const PAGE_SHEET_NAMES := [
	"StoryPage",
	"AlbumPage",
	"PageMiddle",
	"PageBackpackCover",
	"PageRouteCover",
]

const TAB_NODE_NAMES := {
	BookBackgroundConfig.PAGE_HUB: "AlbumTab",
	BookBackgroundConfig.PAGE_BACKPACK: "BackpackTab",
	BookBackgroundConfig.PAGE_GALLERY: "GalleryTab",
	BookBackgroundConfig.PAGE_SETTINGS: "SettingsTab",
}
const STORY_DISABLED_TAB_PIN_TEXTURE_PATH := "res://assets/ui/backpack/locked_cell_pin.png"
const STORY_DISABLED_TAB_PIN_Z_INDEX := 50
const STORY_DISABLED_TAB_PIN_RECTS := {
	BookBackgroundConfig.PAGE_HUB: Rect2(41.0, 216.0, 74.0, 85.0),
	BookBackgroundConfig.PAGE_BACKPACK: Rect2(54.0, 328.0, 74.0, 85.0),
	BookBackgroundConfig.PAGE_GALLERY: Rect2(60.0, 440.0, 74.0, 85.0),
	BookBackgroundConfig.PAGE_SETTINGS: Rect2(54.0, 536.0, 74.0, 85.0),
}

@export_enum("story", "hub", "gallery", "backpack", "settings") var active_page_id: String = BookBackgroundConfig.PAGE_HUB:
	set(value):
		active_page_id = BookBackgroundConfig.normalize_page_id(value)
		_refresh_book_background()

@export var show_back_tab_on_hub := true:
	set(value):
		show_back_tab_on_hub = value
		_refresh_book_background()

@export var scene_suppressed_tab_page_ids: Array[String] = []:
	set(value):
		scene_suppressed_tab_page_ids = _normalize_page_id_array(value)
		_rebuild_scene_suppressed_tab_lookup()
		_refresh_book_background()

var _scene_suppressed_tab_page_ids: Dictionary = {}
var _runtime_suppressed_tab_page_ids: Dictionary = {}
var _story_disabled_tab_pins: Dictionary = {}
var _transition_tabs_hidden := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_TOP_LEFT, false)
	size = BookBackgroundConfig.DESIGN_SIZE
	_refresh_book_background()


func set_active_page_id(page_id: String) -> void:
	active_page_id = page_id


func set_suppressed_tab_page_ids(page_ids: Array) -> void:
	_runtime_suppressed_tab_page_ids.clear()
	for page_id in page_ids:
		_runtime_suppressed_tab_page_ids[BookBackgroundConfig.normalize_page_id(str(page_id))] = true
	_refresh_book_background()


func set_transition_tabs_hidden(tabs_hidden: bool) -> void:
	_transition_tabs_hidden = tabs_hidden
	_refresh_book_background()


func get_visible_page_sheet_count() -> int:
	return BookBackgroundConfig.get_page_sheet_count(active_page_id)


func get_page_turn_sheet_info() -> Dictionary:
	var sheet := get_page_turn_sheet()
	if sheet == null:
		return {}
	return {
		"texture": sheet.texture,
		"global_rect": sheet.get_global_rect(),
		"modulate": sheet.modulate,
	}


func get_page_turn_sheet() -> TextureRect:
	for sheet_name in PAGE_SHEET_NAMES:
		var sheet := get_node_or_null(sheet_name) as TextureRect
		if sheet != null and sheet.visible:
			return sheet
	return null


func _refresh_book_background() -> void:
	if not is_inside_tree() and get_child_count() == 0:
		return
	_refresh_page_sheets()
	_refresh_tabs()
	_refresh_back_tab()
	_refresh_story_disabled_tab_pins()


func _refresh_page_sheets() -> void:
	var visible_count := clampi(get_visible_page_sheet_count(), 0, PAGE_SHEET_NAMES.size())
	var first_visible_index := PAGE_SHEET_NAMES.size() - visible_count
	for index in range(PAGE_SHEET_NAMES.size()):
		var sheet := get_node_or_null(PAGE_SHEET_NAMES[index]) as CanvasItem
		if sheet != null:
			sheet.visible = index >= first_visible_index


func _refresh_tabs() -> void:
	for page_id in TAB_NODE_NAMES.keys():
		var left_tab := get_node_or_null(str(TAB_NODE_NAMES[page_id])) as Control
		var right_tab := get_node_or_null("%sRight" % str(TAB_NODE_NAMES[page_id])) as Control
		if _transition_tabs_hidden:
			if left_tab != null:
				left_tab.visible = false
			if right_tab != null:
				right_tab.visible = false
			continue
		var tab_page_id := BookBackgroundConfig.normalize_page_id(str(page_id))
		var is_suppressed := _is_tab_suppressed(tab_page_id)
		var use_right := BookBackgroundConfig.should_place_tab_on_right(str(page_id), active_page_id)
		var tab_z_index := BookBackgroundConfig.get_tab_z_index(str(page_id), active_page_id)
		var left_rect := BookBackgroundConfig.get_tab_rect(str(page_id), BookBackgroundConfig.PAGE_HUB)
		var active_rect := BookBackgroundConfig.get_tab_rect(str(page_id), active_page_id)
		if left_tab != null:
			_apply_tab_rect(left_tab, left_rect)
			left_tab.z_index = tab_z_index
			left_tab.visible = not use_right and not is_suppressed
		if right_tab != null:
			_apply_tab_rect(right_tab, active_rect)
			right_tab.z_index = BookBackgroundConfig.get_right_tab_z_index()
			right_tab.visible = use_right and not is_suppressed


func _apply_tab_rect(tab: Control, rect: Rect2) -> void:
	tab.set_anchors_preset(Control.PRESET_TOP_LEFT, false)
	tab.position = rect.position
	tab.size = rect.size


func _normalize_page_id_array(page_ids: Array) -> Array[String]:
	var normalized: Array[String] = []
	for page_id in page_ids:
		normalized.append(BookBackgroundConfig.normalize_page_id(str(page_id)))
	return normalized


func _rebuild_scene_suppressed_tab_lookup() -> void:
	_scene_suppressed_tab_page_ids.clear()
	for page_id in scene_suppressed_tab_page_ids:
		_scene_suppressed_tab_page_ids[BookBackgroundConfig.normalize_page_id(str(page_id))] = true


func _is_tab_suppressed(page_id: String) -> bool:
	var normalized := BookBackgroundConfig.normalize_page_id(page_id)
	return _scene_suppressed_tab_page_ids.has(normalized) or _runtime_suppressed_tab_page_ids.has(normalized)


func _refresh_back_tab() -> void:
	var back_tab := get_node_or_null("BackTab") as Control
	if back_tab != null:
		_apply_tab_rect(back_tab, BookBackgroundConfig.get_back_tab_rect())
		back_tab.z_index = BookBackgroundConfig.get_back_tab_z_index()
		back_tab.visible = not _transition_tabs_hidden and (show_back_tab_on_hub or active_page_id != BookBackgroundConfig.PAGE_HUB)


func _refresh_story_disabled_tab_pins() -> void:
	var show_pins := active_page_id == BookBackgroundConfig.PAGE_STORY and not _transition_tabs_hidden
	var pin_texture: Texture2D = null
	if show_pins:
		pin_texture = load(STORY_DISABLED_TAB_PIN_TEXTURE_PATH) as Texture2D
	for page_id in STORY_DISABLED_TAB_PIN_RECTS.keys():
		var normalized_page_id := BookBackgroundConfig.normalize_page_id(str(page_id))
		var pin: TextureRect = null
		if show_pins:
			pin = _get_or_create_story_disabled_tab_pin(normalized_page_id)
		else:
			pin = _story_disabled_tab_pins.get(normalized_page_id, null) as TextureRect
		if pin == null:
			continue
		var pin_rect: Rect2 = STORY_DISABLED_TAB_PIN_RECTS[page_id]
		_apply_tab_rect(pin, pin_rect)
		pin.texture = pin_texture
		pin.z_index = STORY_DISABLED_TAB_PIN_Z_INDEX
		var tab := get_node_or_null(str(TAB_NODE_NAMES.get(page_id, ""))) as CanvasItem
		pin.visible = show_pins and pin_texture != null and tab != null and tab.visible


func _get_or_create_story_disabled_tab_pin(page_id: String) -> TextureRect:
	var normalized := BookBackgroundConfig.normalize_page_id(page_id)
	var existing := _story_disabled_tab_pins.get(normalized, null) as TextureRect
	if existing != null and is_instance_valid(existing):
		return existing
	var tab_node_name := str(TAB_NODE_NAMES.get(normalized, ""))
	if tab_node_name == "":
		return null
	var pin := TextureRect.new()
	pin.name = "%sDisabledPin" % tab_node_name
	pin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pin.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pin.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	add_child(pin)
	_story_disabled_tab_pins[normalized] = pin
	return pin
