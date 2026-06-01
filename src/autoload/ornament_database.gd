extends Node

const ORNAMENT_DATA_PATH := "res://data/ornaments/ornaments.json"
const OrnamentDataScript = preload("res://src/core/ornaments/ornament_data.gd")
const GenericOrnamentEffect = preload("res://src/core/ornaments/effects/generic_ornament_effect.gd")

const FUTHARK_SOURCE_DIR := "res://assets/sourceImage/卢恩符文/卢恩符文"
const OGHAM_SOURCE_DIR := "res://assets/sourceImage/欧甘树文/欧甘树文"
const FUTHARK_ORNAMENT_IMAGE_INDEX := {
	"fehu": 271,
	"uruz": 272,
	"thurisaz": 273,
	"ansuz": 274,
	"gebo": 277,
	"wunjo": 278,
	"hagalaz": 279,
	"naudiz": 280,
	"isa": 281,
	"jera": 282,
	"eihwaz": 283,
	"perthro": 284,
	"algiz": 285,
	"sowilo": 286,
	"tiwaz": 287,
	"berkano": 288,
	"laguz": 291,
	"ingwaz": 292,
	"dagaz": 293,
	"othala": 294
}

const OGHAM_ORNAMENT_IMAGE_INDEX := {
	"beith": 245,
	"luis": 246,
	"fearn": 247,
	"saille": 248,
	"nion": 249,
	"uath": 250,
	"dair": 251,
	"tinne": 252,
	"coll": 253,
	"ceirt": 254,
	"muin": 255,
	"gort": 256,
	"ngeadal": 257,
	"straif": 258,
	"ruis": 259,
	"ailm": 260,
	"onn": 261,
	"ur": 262,
	"eadhadh": 263,
	"iodhadh": 264,
	"eabhadh": 265,
	"or": 266,
	"uilleann": 267,
	"ifin": 268,
	"eamhancholl": 269
}

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
	if image_path == "" or not ResourceLoader.exists(image_path):
		return null
	return load(image_path) as Texture2D


func _get_ornament_image_path(name: String) -> String:
	var key := _normalize_ornament_name(name)
	if FUTHARK_ORNAMENT_IMAGE_INDEX.has(key):
		return "%s/图层 %d.png" % [FUTHARK_SOURCE_DIR, FUTHARK_ORNAMENT_IMAGE_INDEX[key]]
	if OGHAM_ORNAMENT_IMAGE_INDEX.has(key):
		return "%s/图层 %d.png" % [OGHAM_SOURCE_DIR, OGHAM_ORNAMENT_IMAGE_INDEX[key]]
	return ""


func _normalize_ornament_name(name: String) -> String:
	var key := str(name).strip_edges().to_lower()
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
