extends GutTest

const SaveManagerScript = preload("res://src/autoload/save_manager.gd")
const RunPersistenceCodec = preload("res://src/core/run/run_persistence_codec.gd")

const TEST_SAVE_PATH := "user://test_run_data_save_manager.cfg"

var save_manager


func before_each() -> void:
	_cleanup_test_files()
	save_manager = autofree(SaveManagerScript.new())
	save_manager.save_path = TEST_SAVE_PATH


func after_each() -> void:
	_cleanup_test_files()


func test_save_run_writes_valid_schema_and_loads_it() -> void:
	assert_true(save_manager.save_run({"is_active": true, "shards": 7}))
	assert_true(save_manager.has_save())

	var loaded: Dictionary = save_manager.load_run()

	assert_eq(int(loaded.get("schema_version", 0)), RunPersistenceCodec.SAVE_SCHEMA_VERSION)
	assert_eq(int(loaded.get("shards", 0)), 7)


func test_save_run_keeps_previous_valid_save_as_backup() -> void:
	assert_true(save_manager.save_run({"is_active": true, "shards": 7}))
	assert_true(save_manager.save_run({"is_active": true, "shards": 11}))

	var current := _read_run_config(TEST_SAVE_PATH)
	var backup := _read_run_config(TEST_SAVE_PATH + ".bak")

	assert_eq(int(current.get("shards", 0)), 11)
	assert_eq(int(backup.get("shards", 0)), 7)


func test_corrupt_primary_save_is_not_considered_valid() -> void:
	_write_text(TEST_SAVE_PATH, "{invalid")

	assert_false(save_manager.has_save())
	assert_true(save_manager.load_run().is_empty())
	assert_false(FileAccess.file_exists(TEST_SAVE_PATH))
	assert_true(FileAccess.file_exists(TEST_SAVE_PATH + ".corrupt"))


func test_load_run_falls_back_to_backup_when_primary_is_corrupt() -> void:
	_write_text(TEST_SAVE_PATH, "{invalid")
	_write_run_config(TEST_SAVE_PATH + ".bak", {"is_active": true, "shards": 33})

	assert_true(save_manager.has_save())
	var loaded: Dictionary = save_manager.load_run()

	assert_eq(int(loaded.get("shards", 0)), 33)
	assert_false(FileAccess.file_exists(TEST_SAVE_PATH))
	assert_true(FileAccess.file_exists(TEST_SAVE_PATH + ".corrupt"))


func _write_run_config(path: String, data: Dictionary) -> void:
	var config := ConfigFile.new()
	for key in data.keys():
		config.set_value("run", key, data[key])
	assert_eq(config.save(path), OK)


func _read_run_config(path: String) -> Dictionary:
	var result := {}
	var config := ConfigFile.new()
	assert_eq(config.load(path), OK)
	for key in config.get_section_keys("run"):
		result[key] = config.get_value("run", key)
	return result


func _write_text(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	assert_not_null(file)
	if file == null:
		return
	file.store_string(text)
	file.close()


func _cleanup_test_files() -> void:
	for path in [
		TEST_SAVE_PATH,
		TEST_SAVE_PATH + ".bak",
		TEST_SAVE_PATH + ".tmp",
		TEST_SAVE_PATH + ".corrupt",
		TEST_SAVE_PATH + ".bak.corrupt",
	]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
