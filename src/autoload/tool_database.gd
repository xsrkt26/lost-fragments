extends Node

const TOOL_DATA_PATH := "res://data/tools/tools.json"
const ToolDataScript = preload("res://src/core/tools/tool_data.gd")

var tools: Dictionary = {}


func _ready() -> void:
	load_all_tools()


func load_all_tools(path: String = TOOL_DATA_PATH) -> bool:
	var loaded := _load_tool_table(path)
	if loaded.is_empty():
		return false
	tools = loaded
	print("[ToolDatabase] Loaded tools: ", tools.size())
	return true


func get_tool_by_id(tool_id: String):
	if tools.has(tool_id):
		return tools[tool_id].duplicate(true)
	return null


func get_all_tools() -> Array:
	var result: Array = []
	for key in tools:
		result.append(tools[key].duplicate(true))
	return result


func get_available_tools(act: int = 0) -> Array:
	var result: Array = []
	for tool in tools.values():
		if tool.enabled and (act <= 0 or int(tool.earliest_act) <= act):
			result.append(tool.duplicate(true))
	return result


func get_tools_by_rarity(rarity: String) -> Array:
	var result: Array = []
	for tool in tools.values():
		if tool.enabled and str(tool.rarity) == rarity:
			result.append(tool.duplicate(true))
	return result


func _load_tool_table(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_warning("[ToolDatabase] Missing tool table: " + path)
		return {}
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_warning("[ToolDatabase] Failed to open tool table: " + path)
		return {}
	var parser := JSON.new()
	var err := parser.parse(file.get_as_text())
	if err != OK or not (parser.data is Array):
		push_warning("[ToolDatabase] Invalid tool table JSON: %s (%s)" % [path, parser.get_error_message()])
		return {}

	var loaded := {}
	for entry in Array(parser.data):
		if not (entry is Dictionary):
			continue
		var tool = _create_tool_data(entry)
		if tool.id != "":
			loaded[tool.id] = tool
	if loaded.is_empty():
		push_warning("[ToolDatabase] Tool table contains no valid tools: " + path)
	return loaded


func _create_tool_data(entry: Dictionary):
	var data = ToolDataScript.new()
	data.id = str(entry.get("id", ""))
	data.tool_name = str(entry.get("name", ""))
	data.category = str(entry.get("category", ""))
	data.rarity = str(entry.get("rarity", "道具"))
	data.earliest_act = int(entry.get("earliest_act", 1))
	data.price = int(entry.get("price", 1))
	data.target_type = str(entry.get("target_type", ToolDataScript.TARGET_ITEM))
	data.tags = _to_string_array(entry.get("tags", []))
	data.effect_text = str(entry.get("effect_text", ""))
	data.enabled = bool(entry.get("enabled", true))
	return data


func _to_string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	for entry in Array(value):
		result.append(str(entry))
	return result
