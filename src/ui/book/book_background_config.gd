class_name BookBackgroundConfig
extends RefCounted

const PAGE_HUB := "hub"
const PAGE_STORY := "story"
const PAGE_GALLERY := "gallery"
const PAGE_BACKPACK := "backpack"
const PAGE_SETTINGS := "settings"

const PAGE_ORDER := [
	PAGE_STORY,
	PAGE_HUB,
	PAGE_GALLERY,
	PAGE_BACKPACK,
	PAGE_SETTINGS,
]

const DESIGN_SIZE := Vector2(1920.0, 1080.0)

const PAGE_STACK_Z := {
	PAGE_STORY: 1,
	PAGE_HUB: 0,
	PAGE_GALLERY: -1,
	PAGE_BACKPACK: -2,
	PAGE_SETTINGS: -3,
}

const TAB_Z_INDEX := {
	PAGE_HUB: 11,
	PAGE_GALLERY: 9,
	PAGE_BACKPACK: 7,
	PAGE_SETTINGS: 5,
}

const ACTIVE_LEFT_TAB_Z_INDEX := 11
const RIGHT_TAB_Z_INDEX := 12
const BACK_TAB_Z_INDEX := 1
const BOOK_PAGE_NAVIGATOR_Z_INDEX := 30

# Z-index ranges for all book pages. Keep page-owned content below navigation
# and transition effects so slow page changes never reveal target page text above
# the moving source page.
const Z_RANGE_BOOK_ART := Vector2i(-100, 99)
const Z_RANGE_PAGE_CONTENT := Vector2i(100, 999)
const Z_RANGE_PAGE_FLOATING := Vector2i(1000, 1999)
const Z_RANGE_BOOK_NAVIGATION := Vector2i(2000, 2899)
const Z_RANGE_BOOK_TRANSITION := Vector2i(3000, 3099)
const PAGE_LOCAL_Z_RANGE := Vector2i(Z_RANGE_BOOK_ART.x, Z_RANGE_PAGE_FLOATING.y)
const PAGE_ROOT_Z_INDEX := 1
const PAGE_CONTENT_Z_INDEX := 100
const PAGE_CONTROL_Z_INDEX := 110
const PAGE_FLOATING_Z_INDEX := 120
const PAGE_TURN_EFFECT_Z_INDEX := 3000
const NAV_TAB_BUTTON_Z_INDEX := 3002

const PAGE_Z_RANGES := {
	PAGE_STORY: PAGE_LOCAL_Z_RANGE,
	PAGE_HUB: PAGE_LOCAL_Z_RANGE,
	PAGE_GALLERY: PAGE_LOCAL_Z_RANGE,
	PAGE_BACKPACK: PAGE_LOCAL_Z_RANGE,
	PAGE_SETTINGS: PAGE_LOCAL_Z_RANGE,
}

# Visible sheets include the current page and the pages behind it.
const PAGE_SHEET_COUNT := {
	PAGE_STORY: 5,
	PAGE_HUB: 4,
	PAGE_GALLERY: 3,
	PAGE_BACKPACK: 2,
	PAGE_SETTINGS: 1,
}

const TAB_SOURCE_RECTS := {
	PAGE_HUB: Rect2(58.0, 196.0, 217.0, 164.0),
	PAGE_BACKPACK: Rect2(24.0, 312.0, 250.0, 180.0),
	PAGE_GALLERY: Rect2(62.0, 426.0, 255.0, 183.0),
	PAGE_SETTINGS: Rect2(26.0, 532.0, 222.0, 186.0),
}
const BACK_TAB_RECT := Rect2(4.0, 84.0, 207.0, 161.0)
const TAB_HOVER_PULL_DISTANCE := 12.0

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


static func get_tab_z_index(page_id: String, active_page_id: String = "") -> int:
	var target_page := normalize_page_id(page_id)
	if active_page_id != "" and target_page == normalize_page_id(active_page_id):
		return ACTIVE_LEFT_TAB_Z_INDEX
	return int(TAB_Z_INDEX.get(target_page, ACTIVE_LEFT_TAB_Z_INDEX))


static func get_right_tab_z_index() -> int:
	return RIGHT_TAB_Z_INDEX


static func get_back_tab_z_index() -> int:
	return BACK_TAB_Z_INDEX


static func get_back_tab_rect() -> Rect2:
	return BACK_TAB_RECT


static func get_page_z_range(page_id: String) -> Vector2i:
	return PAGE_Z_RANGES[normalize_page_id(page_id)]


static func is_z_index_in_range(z_index: int, z_range: Vector2i) -> bool:
	return z_index >= z_range.x and z_index <= z_range.y


static func should_place_tab_on_right(page_id: String, active_page_id: String) -> bool:
	var active_page := normalize_page_id(active_page_id)
	var target_page := normalize_page_id(page_id)
	return active_page != PAGE_HUB and int(PAGE_STACK_Z[target_page]) > int(PAGE_STACK_Z[active_page])


static func get_tab_rect(page_id: String, active_page_id: String) -> Rect2:
	var target_page := normalize_page_id(page_id)
	if not TAB_SOURCE_RECTS.has(target_page):
		return Rect2()
	var rect: Rect2 = TAB_SOURCE_RECTS[target_page]
	if should_place_tab_on_right(target_page, active_page_id):
		rect.position.x = float(RIGHT_TAB_X.get(target_page, DESIGN_SIZE.x - rect.size.x))
	return rect
