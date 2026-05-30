class_name RunRouteProgress
extends RefCounted


func reset_route_progress(manager, route_id: String = RouteConfig.DEFAULT_ROUTE_ID) -> void:
	manager.current_route_id = RouteConfig.normalize_route_id(route_id)
	manager.current_act = 1
	manager.current_route_index = 0
	var completed_nodes: Array[int] = []
	manager.completed_route_nodes = completed_nodes
	manager.is_run_complete = false

func get_current_stage_route_id(manager) -> String:
	return RouteConfig.normalize_route_id(StageConfig.get_route_id_for_act(manager.current_act, manager.current_route_id))

func get_current_stage_config(manager) -> Dictionary:
	return StageConfig.get_stage(manager.current_act)

func get_current_stage_visual(manager) -> Dictionary:
	return StageConfig.get_visual(manager.current_act)

func get_current_battle_modifiers(manager) -> Dictionary:
	return StageConfig.get_battle_modifiers(manager.current_act)

func get_route_nodes(manager) -> Array:
	return RouteConfig.get_route_nodes(get_current_stage_route_id(manager))

func get_current_route_node(manager) -> Dictionary:
	return RouteConfig.get_route_node(get_current_stage_route_id(manager), manager.current_route_index)

func get_current_route_node_type(manager) -> String:
	return get_current_route_node(manager).get("type", "")

func can_enter_route_node(manager, index: int) -> bool:
	return manager.is_run_active and index == manager.current_route_index and not get_current_route_node(manager).is_empty()

func get_scene_type_for_node(node: Dictionary) -> int:
	var scene_key = RouteConfig.get_scene_key_for_node(node)
	match scene_key:
		RouteConfig.SCENE_BATTLE:
			return GlobalScene.SceneType.BATTLE
		RouteConfig.SCENE_SHOP:
			return GlobalScene.SceneType.SHOP
		RouteConfig.SCENE_EVENT:
			return GlobalScene.SceneType.EVENT
		RouteConfig.SCENE_HUB:
			return GlobalScene.SceneType.HUB
	return GlobalScene.SceneType.HUB

func get_current_node_scene_type(manager) -> int:
	return get_scene_type_for_node(get_current_route_node(manager))

func get_current_battle_config(manager) -> Dictionary:
	var node_type = get_current_route_node_type(manager)
	var node = get_current_route_node(manager)
	var score_rule = RouteConfig.get_score_target_rule(node, manager.current_act)
	if RouteConfig.is_boss_node_type(node_type):
		var stage_score_rule = StageConfig.get_boss_score_target_rule(manager.current_act)
		if bool(stage_score_rule.get("enabled", false)):
			score_rule = stage_score_rule
	var has_target = bool(score_rule.get("enabled", false))
	return {
		"act": manager.current_act,
		"stage": get_current_stage_config(manager),
		"node_type": node_type,
		"is_boss": RouteConfig.is_boss_node_type(node_type),
		"has_score_target": has_target,
		"target_score": int(score_rule.get("target", manager.NO_SCORE_TARGET)) if has_target else manager.NO_SCORE_TARGET,
		"battle_modifiers": get_current_battle_modifiers(manager),
		"visual": get_current_stage_visual(manager),
		"boss": StageConfig.get_boss_config(manager.current_act),
	}

func current_battle_has_score_target(manager) -> bool:
	return bool(get_current_battle_config(manager).get("has_score_target", false))

func get_current_battle_target_score(manager) -> int:
	return int(get_current_battle_config(manager).get("target_score", manager.NO_SCORE_TARGET))

func is_current_battle_score_success(manager, score: int) -> bool:
	var config = get_current_battle_config(manager)
	if not config.get("has_score_target", false):
		return true
	return score >= int(config.get("target_score", manager.NO_SCORE_TARGET))

func has_empty_dream_trophy_reward_bonus(manager, score: int) -> bool:
	if not manager.current_ornaments.has("empty_dream_trophy"):
		return false
	var config = get_current_battle_config(manager)
	if not bool(config.get("has_score_target", false)):
		return false
	return score > int(config.get("target_score", manager.NO_SCORE_TARGET)) + 50

func get_boss_target_score(manager) -> int:
	var node = get_current_route_node(manager)
	var score_rule = RouteConfig.get_score_target_rule(node, manager.current_act)
	var stage_score_rule = StageConfig.get_boss_score_target_rule(manager.current_act)
	if bool(stage_score_rule.get("enabled", false)):
		score_rule = stage_score_rule
	if bool(score_rule.get("enabled", false)):
		return int(score_rule.get("target", manager.NO_SCORE_TARGET))
	return manager.NO_SCORE_TARGET

func advance_route_node(manager, expected_node_id: String = "") -> Dictionary:
	if not manager.is_run_active:
		return {}
	var current_node = get_current_route_node(manager)
	if current_node.is_empty():
		return {}
	if expected_node_id != "" and current_node.get("id", "") != expected_node_id:
		return {}
	if not manager.completed_route_nodes.has(manager.current_route_index):
		manager.completed_route_nodes.append(manager.current_route_index)
	manager.current_route_index += 1

	if manager.current_route_index >= RouteConfig.get_route_size(get_current_stage_route_id(manager)):
		if manager.current_act >= StageConfig.get_max_act():
			manager._complete_run()
			manager._emit_route_changed()
			return current_node
		manager.current_act += 1
		manager.current_route_index = 0
		var completed_nodes: Array[int] = []
		manager.completed_route_nodes = completed_nodes

	manager.save_current_state()
	manager._emit_route_changed()
	return current_node
