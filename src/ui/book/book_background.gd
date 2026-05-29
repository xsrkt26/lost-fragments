@tool
class_name BookBackground
extends Control

const BookBackgroundConfig = preload("res://src/ui/book/book_background_config.gd")

const PAGE_SHEET_NAMES := [
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

@export_enum("hub", "gallery", "backpack", "settings") var active_page_id: String = BookBackgroundConfig.PAGE_HUB:
	set(value):
		active_page_id = BookBackgroundConfig.normalize_page_id(value)
		_refresh_book_background()

@export var show_back_tab_on_hub := false:
	set(value):
		show_back_tab_on_hub = value
		_refresh_book_background()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = BookBackgroundConfig.DESIGN_SIZE
	_refresh_book_background()


func set_active_page_id(page_id: String) -> void:
	active_page_id = page_id


func get_visible_page_sheet_count() -> int:
	return BookBackgroundConfig.get_page_sheet_count(active_page_id)


func _refresh_book_background() -> void:
	if not is_inside_tree() and get_child_count() == 0:
		return
	_refresh_page_sheets()
	_refresh_tabs()
	_refresh_back_tab()


func _refresh_page_sheets() -> void:
	var visible_count := get_visible_page_sheet_count()
	for index in range(PAGE_SHEET_NAMES.size()):
		var sheet := get_node_or_null(PAGE_SHEET_NAMES[index]) as CanvasItem
		if sheet != null:
			sheet.visible = index < visible_count


func _refresh_tabs() -> void:
	for page_id in TAB_NODE_NAMES.keys():
		var left_tab := get_node_or_null(str(TAB_NODE_NAMES[page_id])) as CanvasItem
		var right_tab := get_node_or_null("%sRight" % str(TAB_NODE_NAMES[page_id])) as CanvasItem
		var use_right := BookBackgroundConfig.should_place_tab_on_right(str(page_id), active_page_id)
		var tab_z_index := BookBackgroundConfig.get_tab_z_index(str(page_id), active_page_id)
		if left_tab != null:
			left_tab.z_index = tab_z_index
			left_tab.visible = not use_right
		if right_tab != null:
			right_tab.z_index = BookBackgroundConfig.get_right_tab_z_index()
			right_tab.visible = use_right


func _refresh_back_tab() -> void:
	var back_tab := get_node_or_null("BackTab") as CanvasItem
	if back_tab != null:
		back_tab.visible = show_back_tab_on_hub or active_page_id != BookBackgroundConfig.PAGE_HUB
