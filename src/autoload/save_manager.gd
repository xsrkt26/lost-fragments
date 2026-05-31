class_name SaveManager
extends Node

const SAVE_PATH = "user://run_data.cfg"

var save_path := SAVE_PATH


func has_save() -> bool:
	return has_valid_save()


func has_valid_save() -> bool:
	return not _read_valid_run_data(save_path).is_empty() or not _read_valid_run_data(_backup_path()).is_empty()


func save_run(data: Dictionary) -> bool:
	var migrated := RunPersistenceCodec.migrate_save_data(data)
	if migrated.is_empty() or not RunPersistenceCodec.is_save_data_compatible(migrated):
		push_error("[SaveManager] Refusing to save invalid run data.")
		return false

	var temp_path := _temp_path()
	_remove_if_exists(temp_path)
	var err := _write_run_config(temp_path, migrated)
	if err != OK:
		push_error("[SaveManager] Save temp file failed: %s (%s)" % [temp_path, err])
		return false
	if _read_valid_run_data(temp_path, true).is_empty():
		push_error("[SaveManager] Save temp file validation failed: " + temp_path)
		_remove_if_exists(temp_path)
		return false

	if FileAccess.file_exists(save_path):
		if _read_valid_run_data(save_path).is_empty():
			_quarantine_file(save_path)
		else:
			var backup_err := _replace_with_rename(save_path, _backup_path())
			if backup_err != OK:
				push_error("[SaveManager] Save backup failed: %s" % backup_err)
				_remove_if_exists(temp_path)
				return false

	var replace_err := _replace_with_rename(temp_path, save_path)
	if replace_err != OK:
		push_error("[SaveManager] Save replacement failed: %s" % replace_err)
		if FileAccess.file_exists(_backup_path()) and not FileAccess.file_exists(save_path):
			_rename_user_path(_backup_path(), save_path)
		return false

	print("[SaveManager] Save successful: ", save_path)
	return true


func load_run() -> Dictionary:
	var data := _read_valid_run_data(save_path, true)
	if not data.is_empty():
		print("[SaveManager] Load successful: ", save_path)
		return data

	var backup_data := _read_valid_run_data(_backup_path(), true)
	if not backup_data.is_empty():
		if FileAccess.file_exists(save_path):
			_quarantine_file(save_path)
		print("[SaveManager] Primary save invalid; loaded backup: ", _backup_path())
		return backup_data

	if FileAccess.file_exists(save_path):
		_quarantine_file(save_path)
	return {}


func delete_save() -> void:
	for path in [save_path, _backup_path(), _temp_path(), _corrupt_path(), _backup_path() + ".corrupt"]:
		_remove_if_exists(path)


func _write_run_config(path: String, data: Dictionary) -> Error:
	var config = ConfigFile.new()
	for key in data.keys():
		config.set_value("run", key, data[key])
	return config.save(path)


func _read_valid_run_data(path: String, warn_on_error: bool = false) -> Dictionary:
	if path == "" or not FileAccess.file_exists(path):
		return {}
	var config = ConfigFile.new()
	var err := config.load(path)
	if err != OK:
		if warn_on_error:
			push_warning("[SaveManager] Failed to read save %s: %s" % [path, err])
		return {}
	if not config.has_section("run"):
		if warn_on_error:
			push_warning("[SaveManager] Save has no run section: " + path)
		return {}

	var data := {}
	for key in config.get_section_keys("run"):
		data[key] = config.get_value("run", key)
	var migrated := RunPersistenceCodec.migrate_save_data(data)
	if migrated.is_empty() or not RunPersistenceCodec.is_save_data_compatible(migrated):
		if warn_on_error:
			push_warning("[SaveManager] Save data is incompatible: " + path)
		return {}
	return migrated


func _replace_with_rename(source_path: String, target_path: String) -> Error:
	_remove_if_exists(target_path)
	return _rename_user_path(source_path, target_path)


func _rename_user_path(source_path: String, target_path: String) -> Error:
	return DirAccess.rename_absolute(ProjectSettings.globalize_path(source_path), ProjectSettings.globalize_path(target_path))


func _remove_if_exists(path: String) -> Error:
	if path == "" or not FileAccess.file_exists(path):
		return OK
	return DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _quarantine_file(path: String) -> void:
	var quarantine_path := _corrupt_path()
	if path == _backup_path():
		quarantine_path = _backup_path() + ".corrupt"
	_remove_if_exists(quarantine_path)
	var err := _rename_user_path(path, quarantine_path)
	if err != OK:
		push_warning("[SaveManager] Failed to quarantine invalid save %s: %s" % [path, err])


func _backup_path() -> String:
	return save_path + ".bak"


func _temp_path() -> String:
	return save_path + ".tmp"


func _corrupt_path() -> String:
	return save_path + ".corrupt"
