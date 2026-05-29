class_name BookBackgroundConfig
extends RefCounted

const PAGE_HUB := "hub"
const PAGE_GALLERY := "gallery"
const PAGE_BACKPACK := "backpack"
const PAGE_SETTINGS := "settings"

const PAGE_ORDER := [
	PAGE_HUB,
	PAGE_GALLERY,
	PAGE_BACKPACK,
	PAGE_SETTINGS,
]

const DESIGN_SIZE := Vector2(1920.0, 1080.0)

const PAGE_STACK_Z := {
	PAGE_HUB: 0,
	PAGE_GALLERY: -1,
	PAGE_BACKPACK: -2,
	PAGE_SETTINGS: -3,
}

# Visible sheets include the current page and the pages behind it.
const PAGE_SHEET_COUNT := {
	PAGE_HUB: 4,
	PAGE_GALLERY: 3,
	PAGE_BACKPACK: 2,
	PAGE_SETTINGS: 1,
}

const TAB_SOURCE_RECTS := {
	PAGE_HUB: Rect2(0.0, 191.0, 217.0, 164.0),
	PAGE_BACKPACK: Rect2(0.0, 292.0, 250.0, 180.0),
	PAGE_GALLERY: Rect2(0.0, 399.0, 255.0, 183.0),
	PAGE_SETTINGS: Rect2(0.0, 497.0, 222.0, 186.0),
}

const RIGHT_TAB_X := {
	PAGE_HUB: 1604.0,
	PAGE_BACKPACK: 1554.0,
	PAGE_GALLERY: 1580.0,
	PAGE_SETTINGS: 1700.0,
}


static func normalize_page_id(page_id: String) -> String:
	return page_id if PAGE_STACK_Z.has(page_id) else PAGE_HUB


static func get_page_sheet_count(page_id: String) -> int:
	return int(PAGE_SHEET_COUNT[normalize_page_id(page_id)])


static func should_place_tab_on_right(page_id: String, active_page_id: String) -> bool:
	var active_page := normalize_page_id(active_page_id)
	var target_page := normalize_page_id(page_id)
	return active_page != PAGE_HUB and int(PAGE_STACK_Z[target_page]) > int(PAGE_STACK_Z[active_page])


static func get_tab_rect(page_id: String, active_page_id: String) -> Rect2:
	var target_page := normalize_page_id(page_id)
	var rect: Rect2 = TAB_SOURCE_RECTS[target_page]
	if should_place_tab_on_right(target_page, active_page_id):
		rect.position.x = float(RIGHT_TAB_X.get(target_page, DESIGN_SIZE.x - rect.size.x))
	return rect
