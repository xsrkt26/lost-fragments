extends Node

const ITEM_DATA_DIR := "res://data/items/"

var items: Dictionary = {}
var drawable_items: Array[ItemData] = []


func _ready():
	load_all_items()


func load_all_items(path: String = ITEM_DATA_DIR) -> bool:
	var loaded := _load_item_table(path)
	var loaded_drawable: Array[ItemData] = []
	loaded_drawable.assign(Array(loaded.get("drawable_items", [])))
	var loaded_items: Dictionary = Dictionary(loaded.get("items", {}))
	if loaded_items.is_empty():
		return false
	items = loaded_items
	drawable_items = loaded_drawable
	print("[ItemDatabase] Total loaded items: ", items.size(), ", drawable items: ", drawable_items.size())
	return true


func get_all_items() -> Array[ItemData]:
	var list: Array[ItemData] = []
	for key in items:
		list.append(items[key])
	return list


func get_random_item() -> ItemData:
	if drawable_items.is_empty():
		push_error("[ItemDatabase] Error: no drawable items loaded.")
		return null
	var index = randi() % drawable_items.size()
	return drawable_items[index].duplicate(true)


func get_item_by_id(item_id: String) -> ItemData:
	if items.has(item_id):
		return items[item_id].duplicate(true)
	return null


func _load_item_table(path: String) -> Dictionary:
	if not DirAccess.dir_exists_absolute(path):
		push_warning("[ItemDatabase] Missing item data directory: " + path)
		return {}
	var dir = DirAccess.open(path)
	if dir == null:
		push_warning("[ItemDatabase] Failed to open item data directory: " + path)
		return {}

	var loaded_items: Dictionary = {}
	var loaded_drawable: Array[ItemData] = []
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir():
			var clean_name = file_name.trim_suffix(".remap")
			if clean_name.ends_with(".tres") or clean_name.ends_with(".res"):
				var full_path = path + clean_name
				var item = load(full_path)
				if item is ItemData:
					if item.id == "":
						item.id = clean_name.get_basename()
					loaded_items[item.id] = item
					if item.can_draw:
						loaded_drawable.append(item)
					print("[ItemDatabase] Loaded item: ", item.item_name, " (ID: ", item.id, ")")
		file_name = dir.get_next()
	if loaded_items.is_empty():
		push_warning("[ItemDatabase] Item data directory contains no valid items: " + path)
	return {
		"items": loaded_items,
		"drawable_items": loaded_drawable,
	}
