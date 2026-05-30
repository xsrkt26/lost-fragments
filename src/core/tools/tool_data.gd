class_name ToolData
extends Resource

const TARGET_NONE := "none"
const TARGET_ITEM := "item"
const TARGET_EMPTY_CELL := "empty_cell"
const TARGET_ITEM_OR_EMPTY_CELL := "item_or_empty_cell"
const TARGET_DREAMCATCHER := "dreamcatcher"
const TARGET_DISCARD := "discard"
const TARGET_ORNAMENT := "ornament"

@export var id: String = ""
@export var tool_name: String = ""
@export var category: String = ""
@export var rarity: String = "道具"
@export var earliest_act: int = 1
@export var price: int = 1
@export var target_type: String = TARGET_ITEM
@export var tags: Array[String] = []
@export_multiline var effect_text: String = ""
@export var enabled: bool = true

func get_tooltip_text(count: int = 0) -> String:
	var lines: Array[String] = [tool_name]
	if rarity != "":
		lines.append(rarity)
	if count > 0:
		lines.append("数量: %d" % count)
	if effect_text != "":
		lines.append(effect_text)
	return "\n".join(lines)
