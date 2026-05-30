extends Node

const EVENT_DATA_PATH := "res://data/events/events.json"
const EventDataScript = preload("res://src/core/events/event_data.gd")

var events: Dictionary = {}

func _ready() -> void:
	load_all_events()

func load_all_events() -> void:
	events.clear()
	if not FileAccess.file_exists(EVENT_DATA_PATH):
		push_error("[EventDatabase] Missing event table: " + EVENT_DATA_PATH)
		return

	var file = FileAccess.open(EVENT_DATA_PATH, FileAccess.READ)
	var parsed = JSON.parse_string(file.get_as_text())
	if not (parsed is Array):
		push_error("[EventDatabase] Invalid event table JSON")
		return

	for entry in parsed:
		if not (entry is Dictionary):
			continue
		var event_data = _create_event_data(entry)
		if event_data.id != "":
			events[event_data.id] = event_data
	print("[EventDatabase] Loaded events: ", events.size())

func get_event_by_id(event_id: String):
	if events.has(event_id):
		return _with_event_choice_context(events[event_id].duplicate(true))
	return null

func get_all_events() -> Array:
	var result: Array = []
	for key in events:
		result.append(events[key].duplicate(true))
	result.sort_custom(func(a, b): return a.id < b.id)
	return result

func get_available_events(act: int, excluded_ids: Array = []) -> Array:
	var result: Array = []
	for event_data in events.values():
		if event_data.earliest_act <= act and not excluded_ids.has(event_data.id):
			result.append(_with_event_choice_context(event_data.duplicate(true)))
	result.sort_custom(func(a, b): return a.id < b.id)
	return result

func pick_event_for_run(run_manager: Node, rng: RandomNumberGenerator = null):
	var act = 1
	var route_index = 0
	var seen_ids: Array[String] = []
	if run_manager != null:
		act = max(1, int(run_manager.get("current_act")))
		route_index = max(0, int(run_manager.get("current_route_index")))
		for event_id in Array(run_manager.get("seen_event_ids")):
			seen_ids.append(str(event_id))
	var available = get_available_events(act, seen_ids)
	if available.is_empty():
		available = get_available_events(act)
	if available.is_empty():
		return null
	if rng != null:
		var candidates: Array[Dictionary] = []
		for event_data in available:
			candidates.append({
				"event": event_data,
				"weight": _get_event_weight(event_data, run_manager),
			})
		var picked = WeightedRandom.pick(candidates, rng)
		if not picked.is_empty():
			return picked.get("event")
	return available[(act + route_index) % available.size()]

func _create_event_data(entry: Dictionary):
	var data = EventDataScript.new()
	data.id = str(entry.get("id", ""))
	data.event_name = str(entry.get("title", "事件"))
	data.description = str(entry.get("description", ""))
	data.earliest_act = int(entry.get("earliest_act", 1))
	data.weight = float(entry.get("weight", 1.0))
	data.risk = float(entry.get("risk", 0.0))
	data.reward = float(entry.get("reward", 0.0))
	data.tags = _to_string_array(entry.get("tags", []))
	data.choices = _to_dictionary_array(entry.get("choices", []))
	return data

func _to_dictionary_array(value: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry in Array(value):
		if entry is Dictionary:
			result.append(entry)
	return result

func _with_event_choice_context(event_data):
	if event_data == null:
		return null
	var choices: Array[Dictionary] = []
	for choice in event_data.choices:
		var next_choice = choice.duplicate(true)
		next_choice["event_id"] = event_data.id
		choices.append(next_choice)
	event_data.choices = choices
	return event_data

func _get_event_weight(event_data, run_manager: Node) -> float:
	var weight = max(0.0, float(event_data.weight))
	if weight <= 0.0:
		return 0.0
	var current_shards = int(run_manager.get("current_shards")) if run_manager != null else 0
	var risk = clampf(float(event_data.risk), 0.0, 1.0)
	var reward = clampf(float(event_data.reward), 0.0, 1.0)
	if current_shards < 8 and risk > reward:
		weight *= 0.45
	elif reward > risk:
		weight *= 1.0 + (reward - risk) * 0.35
	weight += _get_tag_affinity(event_data.tags, run_manager)
	return max(0.01, weight)

func _get_tag_affinity(event_tags: Array[String], run_manager: Node) -> float:
	if run_manager == null:
		return 0.0
	var affinity := 0.0
	var current_shards = int(run_manager.get("current_shards"))
	var owned_ornaments = Array(run_manager.get("current_ornaments"))
	var backpack_width = int(run_manager.get("backpack_usable_width"))
	var backpack_height = int(run_manager.get("backpack_usable_height"))
	for tag in event_tags:
		match tag:
			"碎片":
				if current_shards < 15:
					affinity += 0.25
			"饰品":
				if owned_ornaments.is_empty():
					affinity += 0.25
			"背包", "空间":
				if backpack_width < 7 or backpack_height < 7:
					affinity += 0.25
	return affinity

func _to_string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	for entry in Array(value):
		result.append(str(entry))
	return result
