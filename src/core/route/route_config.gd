class_name RouteConfig
extends RefCounted

const DEFAULT_ROUTE_ID := "default"
const MAX_ACT := 6
const ROUTE_DATA_PATH := "res://data/routes/routes.json"

const NODE_BATTLE := "battle"
const NODE_BOSS_BATTLE := "boss_battle"
const NODE_SHOP := "shop"
const NODE_EVENT := "event"
const NODE_CUTSCENE := "cutscene"
const NODE_REWARD := "reward"
const NODE_ELITE_BATTLE := "elite_battle"

const SCENE_BATTLE := "battle"
const SCENE_SHOP := "shop"
const SCENE_EVENT := "event"
const SCENE_HUB := "hub"

const FALLBACK_ROUTES := {
	DEFAULT_ROUTE_ID: [
		{"id": "battle_1", "type": NODE_BATTLE, "label": "局内游戏", "scene": SCENE_BATTLE},
		{"id": "shop_1", "type": NODE_SHOP, "label": "商店", "scene": SCENE_SHOP},
		{"id": "event_1", "type": NODE_EVENT, "label": "事件", "scene": SCENE_EVENT},
		{"id": "battle_2", "type": NODE_BATTLE, "label": "局内游戏", "scene": SCENE_BATTLE},
		{"id": "shop_2", "type": NODE_SHOP, "label": "商店", "scene": SCENE_SHOP},
		{"id": "event_2", "type": NODE_EVENT, "label": "事件", "scene": SCENE_EVENT},
		{"id": "boss_1", "type": NODE_BOSS_BATTLE, "label": "Boss局内游戏", "scene": SCENE_BATTLE, "score_target": {"enabled": true, "base": 30, "act_multiplier": 20}},
		{"id": "shop_3", "type": NODE_SHOP, "label": "商店", "scene": SCENE_SHOP},
		{"id": "event_3", "type": NODE_EVENT, "label": "事件", "scene": SCENE_EVENT},
	]
}

static var _route_table_cache: Dictionary = {}

static func clear_cache_for_tests() -> void:
	_route_table_cache.clear()

static func load_route_table_from_path(path: String = ROUTE_DATA_PATH) -> Dictionary:
	if _route_table_cache.has(path):
		return Dictionary(_route_table_cache[path]).duplicate(true)
	var table = _load_route_table_uncached(path)
	_route_table_cache[path] = table.duplicate(true)
	return table.duplicate(true)

static func _load_route_table_uncached(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return _fallback_route_table()

	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return _fallback_route_table()

	var parser = JSON.new()
	if parser.parse(file.get_as_text()) != OK:
		return _fallback_route_table()
	var parsed = parser.data
	if not (parsed is Dictionary):
		return _fallback_route_table()

	var normalized = _normalize_route_table(parsed)
	if normalized.is_empty():
		return _fallback_route_table()
	return normalized

static func normalize_route_id(route_id: String, path: String = ROUTE_DATA_PATH) -> String:
	var table = load_route_table_from_path(path)
	var routes = table.get("routes", {})
	if routes is Dictionary and routes.has(route_id):
		return route_id
	return str(table.get("default_route_id", DEFAULT_ROUTE_ID))

static func get_route_nodes(route_id: String = DEFAULT_ROUTE_ID, path: String = ROUTE_DATA_PATH) -> Array:
	var table = load_route_table_from_path(path)
	var routes = table.get("routes", {})
	if not (routes is Dictionary):
		return FALLBACK_ROUTES[DEFAULT_ROUTE_ID].duplicate(true)
	var normalized_id = normalize_route_id(route_id, path)
	return Array(routes.get(normalized_id, FALLBACK_ROUTES[DEFAULT_ROUTE_ID])).duplicate(true)

static func get_route_node(route_id: String, index: int, path: String = ROUTE_DATA_PATH) -> Dictionary:
	var nodes = get_route_nodes(route_id, path)
	if index < 0 or index >= nodes.size():
		return {}
	return nodes[index].duplicate(true)

static func get_route_size(route_id: String = DEFAULT_ROUTE_ID, path: String = ROUTE_DATA_PATH) -> int:
	return get_route_nodes(route_id, path).size()

static func get_max_act(path: String = ROUTE_DATA_PATH) -> int:
	return max(1, int(load_route_table_from_path(path).get("max_act", MAX_ACT)))

static func is_battle_node_type(node_type: String) -> bool:
	return node_type == NODE_BATTLE or node_type == NODE_BOSS_BATTLE or node_type == NODE_ELITE_BATTLE

static func is_boss_node_type(node_type: String) -> bool:
	return node_type == NODE_BOSS_BATTLE

static func get_scene_key_for_node(node: Dictionary) -> String:
	var explicit_scene = str(node.get("scene", ""))
	if explicit_scene != "":
		return explicit_scene
	match str(node.get("type", "")):
		NODE_BATTLE, NODE_BOSS_BATTLE, NODE_ELITE_BATTLE:
			return SCENE_BATTLE
		NODE_SHOP:
			return SCENE_SHOP
		NODE_EVENT, NODE_REWARD, NODE_CUTSCENE:
			return SCENE_EVENT
	return SCENE_HUB

static func get_score_target_rule(node: Dictionary, act: int) -> Dictionary:
	var raw_rule = node.get("score_target", {})
	if raw_rule is Dictionary:
		if not bool(raw_rule.get("enabled", false)):
			return {"enabled": false, "target": -1}
		if raw_rule.has("value"):
			return {"enabled": true, "target": max(0, int(raw_rule.get("value", 0)))}
		var base = int(raw_rule.get("base", 0))
		var act_multiplier = int(raw_rule.get("act_multiplier", 0))
		return {"enabled": true, "target": max(0, base + max(1, act) * act_multiplier)}
	if bool(node.get("has_score_target", false)):
		return {"enabled": true, "target": max(0, int(node.get("target_score", -1)))}
	return {"enabled": false, "target": -1}

static func _fallback_route_table() -> Dictionary:
	return {
		"default_route_id": DEFAULT_ROUTE_ID,
		"max_act": MAX_ACT,
		"routes": FALLBACK_ROUTES.duplicate(true),
	}

static func _normalize_route_table(raw: Dictionary) -> Dictionary:
	var routes = _normalize_routes(raw.get("routes", {}))
	if routes.is_empty():
		return {}

	var default_route_id = str(raw.get("default_route_id", DEFAULT_ROUTE_ID))
	if default_route_id == "" or not routes.has(default_route_id):
		default_route_id = DEFAULT_ROUTE_ID if routes.has(DEFAULT_ROUTE_ID) else str(routes.keys()[0])

	return {
		"default_route_id": default_route_id,
		"max_act": max(1, int(raw.get("max_act", MAX_ACT))),
		"routes": routes,
	}

static func _normalize_routes(value: Variant) -> Dictionary:
	var result := {}
	if value is Dictionary:
		for route_id in value.keys():
			var nodes_value = value[route_id]
			if not (nodes_value is Array):
				continue
			var nodes = _normalize_route_nodes(nodes_value)
			if not nodes.is_empty():
				result[str(route_id)] = nodes
	elif value is Array:
		for route_entry in value:
			if not (route_entry is Dictionary):
				continue
			var route_id = str(route_entry.get("id", ""))
			var nodes_value = route_entry.get("nodes", [])
			if route_id == "" or not (nodes_value is Array):
				continue
			var nodes = _normalize_route_nodes(nodes_value)
			if not nodes.is_empty():
				result[route_id] = nodes
	return result

static func _normalize_route_nodes(value: Array) -> Array:
	var result := []
	for entry in value:
		if not (entry is Dictionary):
			continue
		var node = Dictionary(entry).duplicate(true)
		var node_id = str(node.get("id", ""))
		var node_type = str(node.get("type", ""))
		if node_id == "" or node_type == "":
			continue
		node["id"] = node_id
		node["type"] = node_type
		if str(node.get("label", "")) == "":
			node["label"] = node_type
		if node.has("score_target") and not (node.get("score_target") is Dictionary):
			node.erase("score_target")
		result.append(node)
	return result
