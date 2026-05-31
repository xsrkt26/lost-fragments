extends Node

const ORNAMENT_DATA_PATH := "res://data/ornaments/ornaments.json"
const OrnamentDataScript = preload("res://src/core/ornaments/ornament_data.gd")
const GenericOrnamentEffect = preload("res://src/core/ornaments/effects/generic_ornament_effect.gd")

var ornaments: Dictionary = {}


func _ready() -> void:
	load_all_ornaments()


func load_all_ornaments(path: String = ORNAMENT_DATA_PATH) -> bool:
	var loaded := _load_ornament_table(path)
	if loaded.is_empty():
		return false
	ornaments = loaded
	print("[OrnamentDatabase] Loaded ornaments: ", ornaments.size())
	return true


func get_ornament_by_id(ornament_id: String):
	if ornaments.has(ornament_id):
		return ornaments[ornament_id].duplicate(true)
	return null


func get_all_ornaments() -> Array:
	var result: Array = []
	for key in ornaments:
		result.append(ornaments[key].duplicate(true))
	return result


func get_available_ornaments(act: int, owned_ids: Array[String] = []) -> Array:
	var result: Array = []
	for ornament in ornaments.values():
		if ornament.enabled and ornament.earliest_act <= act and not owned_ids.has(ornament.id):
			result.append(ornament.duplicate(true))
	return result


func _load_ornament_table(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_warning("[OrnamentDatabase] Missing ornament table: " + path)
		return {}
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_warning("[OrnamentDatabase] Failed to open ornament table: " + path)
		return {}
	var parser := JSON.new()
	var err := parser.parse(file.get_as_text())
	if err != OK or not (parser.data is Array):
		push_warning("[OrnamentDatabase] Invalid ornament table JSON: %s (%s)" % [path, parser.get_error_message()])
		return {}

	var loaded := {}
	for entry in Array(parser.data):
		if not (entry is Dictionary):
			continue
		var ornament = _create_ornament_data(entry)
		if ornament.id != "":
			loaded[ornament.id] = ornament
	if loaded.is_empty():
		push_warning("[OrnamentDatabase] Ornament table contains no valid ornaments: " + path)
	return loaded


func _create_ornament_data(entry: Dictionary):
	var data = OrnamentDataScript.new()
	data.id = str(entry.get("id", ""))
	data.ornament_name = str(entry.get("name", ""))
	data.category = str(entry.get("category", ""))
	data.rarity = str(entry.get("rarity", ""))
	data.earliest_act = int(entry.get("earliest_act", 1))
	data.price = int(entry.get("price", 0))
	data.tags = _to_string_array(entry.get("tags", []))
	data.effect_text = str(entry.get("effect_text", ""))
	data.effect_id = str(entry.get("effect_id", ""))
	data.enabled = bool(entry.get("enabled", true))
	if data.effect_id == "":
		data.effect_id = data.id
	data.effect = _create_effect(data.effect_id)
	return data


func _create_effect(effect_id: String):
	match effect_id:
		"old_pocket_watch":
			return OldPocketWatchEffect.new()
		"dreamcatcher_filter":
			return DreamcatcherFilterEffect.new()
		"echo_earring":
			return EchoEarringEffect.new()
		"guiding_compass":
			return GuidingCompassEffect.new()
		"safety_pin":
			return SafetyPinEffect.new()
	if effect_id != "":
		var effect = GenericOrnamentEffect.new()
		effect.effect_id = effect_id
		return effect
	return null


func _to_string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	for entry in Array(value):
		result.append(str(entry))
	return result
