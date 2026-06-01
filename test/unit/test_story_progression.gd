extends GutTest


func test_battle_intro_sequences_are_scoped_to_story_act() -> void:
	var story_manager = get_node_or_null("/root/StoryManager")
	assert_not_null(story_manager)
	if story_manager == null:
		return

	var act_one: Array = story_manager.call("_get_battle_intro_sequence_ids", 1)
	var act_two: Array = story_manager.call("_get_battle_intro_sequence_ids", 2)

	assert_true(act_one.has("进入局内1"))
	assert_true(act_one.has("进入局内"))
	assert_true(act_two.has("进入局内2"))
	assert_false(act_two.has("进入局内"))


func test_fixed_event_sequence_ids_match_story_table() -> void:
	var story_manager = get_node_or_null("/root/StoryManager")
	assert_not_null(story_manager)
	if story_manager == null:
		return

	var act_one: Array = story_manager.call("_get_fixed_event_sequence_ids", 1)
	var act_two: Array = story_manager.call("_get_fixed_event_sequence_ids", 2)
	var event_ids: Array = story_manager.call("_get_event_sequence_ids", 1, {})

	assert_true(act_one.has("固定事件1·小咪"))
	assert_false(act_one.has("固定事件1·小咭"))
	assert_true(act_two.has("固定事件2·小舅"))
	assert_false(act_two.has("固定事件2·小舌"))
	assert_false(event_ids.has("固定事件1·小咪"))


func test_act_opening_queues_fixed_event_before_stage_intro() -> void:
	var story_manager = get_node_or_null("/root/StoryManager")
	assert_not_null(story_manager)
	if story_manager == null:
		return

	_reset_story_manager_queue(story_manager)

	story_manager.call("_queue_act_opening_sequences", 1)

	var pending: Array = story_manager.get("_pending_hub_sequences")
	assert_eq(pending.slice(0, 2), ["固定事件1·小咪", "进入场景1"])


func _reset_story_manager_queue(story_manager: Node) -> void:
	var pending: Array[String] = []
	var queued: Array[String] = []
	story_manager.set("_pending_hub_sequences", pending)
	story_manager.set("_sequence_queue", queued)
	story_manager.set("current_playing_sequence", "")
	if story_manager.has_method("set_played_flags"):
		story_manager.call("set_played_flags", {})
	var run_manager = get_node_or_null("/root/RunManager")
	if run_manager != null and run_manager.has_method("set_story_played_flags"):
		run_manager.call("set_story_played_flags", {}, false)
