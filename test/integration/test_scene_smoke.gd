extends GutTest

const SCENE_PATHS: Array[String] = [
	"res://src/ui/main_menu/main_menu.tscn",
	"res://src/ui/hub/hub_scene.tscn",
	"res://src/ui/main_game_ui.tscn",
	"res://src/ui/shop/shop_scene.tscn",
	"res://src/ui/debug/debug_sandbox.tscn",
]

var _run_manager_snapshot: Dictionary = {}

func before_all():
	var rm = get_node_or_null("/root/RunManager")
	if rm:
		var completed_route_nodes: Array[int] = []
		for node_index in rm.completed_route_nodes:
			completed_route_nodes.append(int(node_index))
		_run_manager_snapshot = {
			"is_run_active": rm.is_run_active,
			"is_run_complete": rm.is_run_complete,
			"current_act": rm.current_act,
			"current_route_index": rm.current_route_index,
			"completed_route_nodes": completed_route_nodes,
		}

func after_all():
	var rm = get_node_or_null("/root/RunManager")
	if rm and not _run_manager_snapshot.is_empty():
		rm.is_run_active = bool(_run_manager_snapshot["is_run_active"])
		rm.is_run_complete = bool(_run_manager_snapshot["is_run_complete"])
		rm.current_act = int(_run_manager_snapshot["current_act"])
		rm.current_route_index = int(_run_manager_snapshot["current_route_index"])
		rm.completed_route_nodes = _to_int_array(_run_manager_snapshot["completed_route_nodes"])
	GlobalTooltip.hide()

func before_each():
	var rm = get_node_or_null("/root/RunManager")
	if rm:
		rm.is_run_active = true
		rm.is_run_complete = false
		rm.current_act = 1
		rm.current_route_index = 0
		rm.completed_route_nodes = [] as Array[int]
	GlobalTooltip.hide()

func test_key_scenes_load_headless():
	for scene_path in SCENE_PATHS:
		await _assert_scene_loads(scene_path)

func _assert_scene_loads(scene_path: String) -> void:
	var packed_scene = load(scene_path)
	assert_not_null(packed_scene, "Scene should load: %s" % scene_path)
	if packed_scene == null:
		return

	var instance = packed_scene.instantiate()
	assert_not_null(instance, "Scene should instantiate: %s" % scene_path)
	if instance == null:
		return

	add_child(instance)
	await get_tree().process_frame
	await get_tree().create_timer(0.15).timeout

	assert_true(is_instance_valid(instance), "Scene should remain valid after startup: %s" % scene_path)

	instance.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	assert_no_new_orphans("Scene should not leak after smoke load: %s" % scene_path)

func _to_int_array(value: Variant) -> Array[int]:
	var result: Array[int] = []
	if not value is Array:
		return result
	for entry in value:
		result.append(int(entry))
	return result
