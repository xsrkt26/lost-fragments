class_name OrnamentData
extends Resource

@export var id: String = ""
@export var ornament_name: String = ""
@export var category: String = ""
@export var rarity: String = ""
@export var icon: Texture2D
@export var earliest_act: int = 1
@export var price: int = 0
@export var tags: Array[String] = []
@export_multiline var effect_text: String = ""
@export var effect_id: String = ""
@export var enabled: bool = true
@export var effect: Resource

func get_tooltip_text() -> String:
	var lines: Array[String] = [
		ornament_name,
		"%s / Act %d" % [rarity, earliest_act],
		"Tags: " + ", ".join(tags),
		effect_text
	]
	return "\n".join(lines)
