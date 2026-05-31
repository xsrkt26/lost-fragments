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


func _refresh_page_sheets() -> void:
	var visible_count := clampi(get_visible_page_sheet_count(), 0, PAGE_SHEET_NAMES.size())
	var first_visible_index := PAGE_SHEET_NAMES.size() - visible_count
	for index in range(PAGE_SHEET_NAMES.size()):
		var sheet := get_node_or_null(PAGE_SHEET_NAMES[index]) as CanvasItem
		if sheet != null:
			sheet.visible = index >= first_visible_index


func _refresh_tabs() -> void:
	if active_page_id == BookBackgroundConfig.PAGE_STORY:
		for story_hidden_page_id in TAB_NODE_NAMES.keys():
			var story_left_tab := get_node_or_null(str(TAB_NODE_NAMES[story_hidden_page_id])) as Control
			var story_right_tab := get_node_or_null("%sRight" % str(TAB_NODE_NAMES[story_hidden_page_id])) as Control
			if story_left_tab != null:
				story_left_tab.visible = false
			if story_right_tab != null:
				story_right_tab.visible = false
		return
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
		back_tab.visible = not _transition_tabs_hidden and active_page_id != BookBackgroundConfig.PAGE_STORY and (show_back_tab_on_hub or active_page_id != BookBackgroundConfig.PAGE_HUB)
