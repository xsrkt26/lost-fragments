extends GutTest

const EventDatabaseScript = preload("res://src/autoload/event_database.gd")
const ItemDatabaseScript = preload("res://src/autoload/item_database.gd")
const OrnamentDatabaseScript = preload("res://src/autoload/ornament_database.gd")
const ToolDatabaseScript = preload("res://src/autoload/tool_database.gd")


func test_item_database_failed_reload_keeps_existing_items() -> void:
	var db = autofree(ItemDatabaseScript.new())
	var existing := ItemData.new()
	existing.id = "existing_item"
	db.items = {"existing_item": existing}
	db.drawable_items = [existing] as Array[ItemData]

	assert_false(db.load_all_items("user://missing_items_for_loader_test/"))

	assert_push_warning("Missing item data directory")
	assert_true(db.items.has("existing_item"))
	assert_eq(db.drawable_items.size(), 1)


func test_tool_database_failed_reload_keeps_existing_tools() -> void:
	var db = autofree(ToolDatabaseScript.new())
	db.tools = {"existing_tool": Resource.new()}

	assert_false(db.load_all_tools("user://missing_tools_for_loader_test.json"))

	assert_push_warning("Missing tool table")
	assert_true(db.tools.has("existing_tool"))


func test_ornament_database_failed_reload_keeps_existing_ornaments() -> void:
	var db = autofree(OrnamentDatabaseScript.new())
	db.ornaments = {"existing_ornament": Resource.new()}

	assert_false(db.load_all_ornaments("user://missing_ornaments_for_loader_test.json"))

	assert_push_warning("Missing ornament table")
	assert_true(db.ornaments.has("existing_ornament"))


func test_event_database_invalid_json_keeps_existing_events() -> void:
	var path := "user://invalid_events_for_loader_test.json"
	_write_text(path, "{invalid")
	var db = autofree(EventDatabaseScript.new())
	db.events = {"existing_event": Resource.new()}

	assert_false(db.load_all_events(path))

	assert_push_warning("Invalid event table JSON")
	assert_true(db.events.has("existing_event"))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _write_text(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	assert_not_null(file)
	if file == null:
		return
	file.store_string(text)
	file.close()
