extends SceneTree

const DEFAULT_CONFIG_PATH := "res://scripts/scene_smoke_scenes.json"
const SETTLE_SECONDS := 0.15
const CUTSCENE_SCENE_PATH := "res://src/ui/story/cutscene_scene.tscn"
const CUTSCENE_SMOKE_SEQUENCE := "beginning"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var config_path := _arg_value("--scene-smoke-config", DEFAULT_CONFIG_PATH)
	var scenes := _load_scene_list(config_path)
	var failures := 0

	if scenes.is_empty():
		push_error("SCENE_SMOKE: No scenes configured in %s" % config_path)
		quit(1)
		return

	print("SCENE_SMOKE: checking %d scenes" % scenes.size())
	for scene_path in scenes:
		var ok := await _check_scene(scene_path)
		if not ok:
			failures += 1

	if failures == 0:
		print("SCENE_SMOKE_RESULTS: PASS")
		quit(0)
	else:
		print("SCENE_SMOKE_RESULTS: FAIL (%d failures)" % failures)
		quit(1)


func _arg_value(name: String, default_value: String) -> String:
	var args := OS.get_cmdline_user_args()
	for index in range(args.size()):
		var arg := args[index]
		var prefix := name + "="
		if arg.begins_with(prefix):
			return arg.substr(prefix.length())
		if arg == name and index + 1 < args.size():
			return args[index + 1]
	return default_value


func _load_scene_list(config_path: String) -> Array[String]:
	if not FileAccess.file_exists(config_path):
		push_error("SCENE_SMOKE: Config file not found: %s" % config_path)
		return []

	var text := FileAccess.get_file_as_string(config_path)
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("SCENE_SMOKE: Config must be a JSON object: %s" % config_path)
		return []
	if not parsed.has("scenes") or typeof(parsed["scenes"]) != TYPE_ARRAY:
		push_error("SCENE_SMOKE: Config must contain a scenes array: %s" % config_path)
		return []

	var scenes: Array[String] = []
	for scene in parsed["scenes"]:
		if typeof(scene) == TYPE_STRING:
			scenes.append(_normalize_scene_path(scene))
	return scenes


func _normalize_scene_path(scene_path: String) -> String:
	var normalized := scene_path.replace("\\", "/").strip_edges()
	if normalized.begins_with("res://"):
		return normalized
	return "res://" + normalized.trim_prefix("/")


func _check_scene(scene_path: String) -> bool:
	if not ResourceLoader.exists(scene_path):
		push_error("SCENE_SMOKE_FAIL: missing resource %s" % scene_path)
		return false

	var resource := load(scene_path)
	if resource == null or not resource is PackedScene:
		push_error("SCENE_SMOKE_FAIL: not a PackedScene %s" % scene_path)
		return false

	var restore_state := _prepare_scene_smoke_state(scene_path)
	var instance := (resource as PackedScene).instantiate()
	if instance == null:
		push_error("SCENE_SMOKE_FAIL: instantiate returned null %s" % scene_path)
		_restore_scene_smoke_state(restore_state)
		return false

	_apply_scene_smoke_overrides(instance)
	get_root().add_child(instance)
	await process_frame
	await create_timer(SETTLE_SECONDS).timeout
	print("SCENE_SMOKE_OK: %s" % scene_path)
	instance.queue_free()
	await process_frame
	await process_frame
	_restore_scene_smoke_state(restore_state)
	return true


func _prepare_scene_smoke_state(scene_path: String) -> Dictionary:
	var state := {
		"story_manager": null,
		"previous_story_sequence": "",
	}
	if scene_path != CUTSCENE_SCENE_PATH:
		return state
	var story_manager := get_root().get_node_or_null("StoryManager")
	if story_manager == null:
		return state
	state["story_manager"] = story_manager
	state["previous_story_sequence"] = str(story_manager.get("current_playing_sequence"))
	if story_manager.has_method("has_sequence") and story_manager.call("has_sequence", CUTSCENE_SMOKE_SEQUENCE):
		story_manager.set("current_playing_sequence", CUTSCENE_SMOKE_SEQUENCE)
	return state


func _restore_scene_smoke_state(state: Dictionary) -> void:
	var story_manager := state.get("story_manager") as Node
	if story_manager == null or not is_instance_valid(story_manager):
		return
	story_manager.set("current_playing_sequence", str(state.get("previous_story_sequence", "")))


func _apply_scene_smoke_overrides(root: Node) -> void:
	if _has_property(root, "play_battle_intro"):
		root.set("play_battle_intro", false)
	for child in root.get_children():
		_apply_scene_smoke_overrides(child)


func _has_property(object: Object, property_name: String) -> bool:
	for property in object.get_property_list():
		if str(property.get("name", "")) == property_name:
			return true
	return false
