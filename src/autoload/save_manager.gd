class_name SaveManager
extends Node

## 持久化管理器：负责读写磁盘数据 (Persistence)
## 采用 ConfigFile 格式，兼顾易读性与可靠性。

const SAVE_PATH = "user://run_data.cfg"

## 检查是否存在活跃的单局存档
func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

## 保存运行数据
func save_run(data: Dictionary):
	var config = ConfigFile.new()
	for key in data.keys():
		config.set_value("run", key, data[key])
	
	var err = config.save(SAVE_PATH)
	if err == OK:
		print("[SaveManager] 存档成功: ", SAVE_PATH)
	else:
		print("[SaveManager] 存档失败: ", err)

## 加载运行数据
func load_run() -> Dictionary:
	var data = {}
	if not has_save():
		return data
		
	var config = ConfigFile.new()
	var err = config.load(SAVE_PATH)
	if err == OK:
		for key in config.get_section_keys("run"):
			data[key] = config.get_value("run", key)
		print("[SaveManager] 读档成功")
	return data

## 删除存档 (用于一局结束或失败)
func delete_save():
	if has_save():
		var err = DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
		if err == OK:
			print("[SaveManager] 存档已销毁 (Permadeath生效)")
