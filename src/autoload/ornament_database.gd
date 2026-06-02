extends Node

const ORNAMENT_DATA_PATH := "res://data/ornaments/ornaments.json"
const OrnamentDataScript = preload("res://src/core/ornaments/ornament_data.gd")
const GenericOrnamentEffect = preload("res://src/core/ornaments/effects/generic_ornament_effect.gd")

const RUNE_ICON_DIR := "res://assets/ui/ornaments/runes"

var ornaments: Dictionary = {}
var _rune_icon_path_by_name: Dictionary = {}


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
	data.icon = _load_ornament_icon(data.ornament_name)
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


func _load_ornament_icon(name: String) -> Texture2D:
	var image_path := _get_ornament_image_path(name)
	if image_path == "":
		return null
	if not ResourceLoader.exists(image_path) and not FileAccess.file_exists(image_path):
		return null
	return load(image_path) as Texture2D


func _get_ornament_image_path(name: String) -> String:
	var lookup := _get_rune_icon_path_lookup()
	return str(lookup.get(_normalize_ornament_name(name), ""))


func _get_rune_icon_path_lookup() -> Dictionary:
	if not _rune_icon_path_by_name.is_empty():
		return _rune_icon_path_by_name
	var dir := DirAccess.open(RUNE_ICON_DIR)
	if dir == null:
		push_warning("[OrnamentDatabase] Missing rune icon directory: " + RUNE_ICON_DIR)
		return _rune_icon_path_by_name
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir():
			var source_file_name := _get_texture_source_file_name(file_name)
			if source_file_name != "":
				var key := _normalize_ornament_name(source_file_name.get_basename())
				_rune_icon_path_by_name[key] = "%s/%s" % [RUNE_ICON_DIR, source_file_name]
		file_name = dir.get_next()
	dir.list_dir_end()
	return _rune_icon_path_by_name


func _get_texture_source_file_name(file_name: String) -> String:
	var lowered := file_name.to_lower()
	if lowered.ends_with(".png"):
		return file_name
	if lowered.ends_with(".png.import"):
		return file_name.substr(0, file_name.length() - ".import".length())
	return ""


func _normalize_ornament_name(name: String) -> String:
	var key := str(name).strip_edges().to_lower()
	key = key.replace(" ", "")
	key = key.replace("_", "")
	key = key.replace("-", "")
	key = key.replace("á", "a")
	key = key.replace("à", "a")
	key = key.replace("ă", "a")
	key = key.replace("â", "a")
	key = key.replace("ä", "a")
	key = key.replace("é", "e")
	key = key.replace("è", "e")
	key = key.replace("ê", "e")
	key = key.replace("ë", "e")
	key = key.replace("í", "i")
	key = key.replace("ì", "i")
	key = key.replace("î", "i")
	key = key.replace("ï", "i")
	key = key.replace("ó", "o")
	key = key.replace("ò", "o")
	key = key.replace("ô", "o")
	key = key.replace("ö", "o")
	key = key.replace("ú", "u")
	key = key.replace("ù", "u")
	key = key.replace("û", "u")
	key = key.replace("ü", "u")
	return key


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
