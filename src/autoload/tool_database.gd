extends Node

const TOOL_DATA_PATH := "res://data/tools/tools.json"
const ToolDataScript = preload("res://src/core/tools/tool_data.gd")

var tools: Dictionary = {}

func _ready() -> void:
	load_all_tools()

func load_all_tools() -> void:
	tools.clear()
	if not FileAccess.file_exists(TOOL_DATA_PATH):
		push_error("[ToolDatabase] Missing tool table: " + TOOL_DATA_PATH)
		return

	var file = FileAccess.open(TOOL_DATA_PATH, FileAccess.READ)
	var parsed = JSON.parse_string(file.get_as_text())
	if not (parsed is Array):
		push_error("[ToolDatabase] Invalid tool table JSON")
		return

	for entry in parsed:
		if not (entry is Dictionary):
			continue
		var tool = _create_tool_data(entry)
		if tool.id != "":
			tools[tool.id] = tool
	print("[ToolDatabase] Loaded tools: ", tools.size())

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
