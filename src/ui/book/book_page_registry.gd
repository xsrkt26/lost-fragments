extends RefCounted

const PAGE_SCENE_PATHS := {
	BookBackgroundConfig.PAGE_STORY: "res://src/ui/story/story_book_page.tscn",
	BookBackgroundConfig.PAGE_BACKPACK: "res://src/ui/backpack/backpack_page.tscn",
	BookBackgroundConfig.PAGE_GALLERY: "res://src/ui/gallery/gallery_scene.tscn",
	BookBackgroundConfig.PAGE_SETTINGS: "res://src/ui/settings/audio_settings_ui.tscn",
}

static func get_scene_path(page_id: String) -> String:
	return str(PAGE_SCENE_PATHS.get(page_id, ""))

static func instantiate_page(page_id: String, page_name: String = "") -> Control:
	var scene_path := get_scene_path(page_id)
	if scene_path == "":
		return null
	var packed := load(scene_path) as PackedScene
	if packed == null:
		push_warning("[BookPageRegistry] Failed to load page scene: %s" % scene_path)
		return null
	var page := packed.instantiate() as Control
	if page == null:
		push_warning("[BookPageRegistry] Page scene is not a Control: %s" % scene_path)
		return null
	if page_name != "":
		page.name = page_name
	return page
