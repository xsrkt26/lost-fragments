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


func test_act_opening_queues_first_stage_intro_only() -> void:
	var story_manager = get_node_or_null("/root/StoryManager")
	assert_not_null(story_manager)
	if story_manager == null:
		return

	_reset_story_manager_queue(story_manager)

	story_manager.call("_queue_act_opening_sequences", 1)

	var pending: Array = story_manager.get("_pending_hub_sequences")
	assert_eq(pending, ["进入场景1"])


func test_completed_act_queues_matching_fixed_event() -> void:
	var story_manager = get_node_or_null("/root/StoryManager")
	assert_not_null(story_manager)
	if story_manager == null:
		return

	_reset_story_manager_queue(story_manager)

	story_manager.call("_queue_completed_act_sequences", 1)

	var pending: Array = story_manager.get("_pending_hub_sequences")
	assert_eq(pending, ["固定事件1·小咪"])


func test_route_change_to_next_act_queues_previous_fixed_event() -> void:
	var story_manager = get_node_or_null("/root/StoryManager")
	var run_manager = get_node_or_null("/root/RunManager")
	assert_not_null(story_manager)
	assert_not_null(run_manager)
	if story_manager == null or run_manager == null:
		return

	_reset_story_manager_queue(story_manager)
	var previous_active := bool(run_manager.get("is_run_active"))
	run_manager.set("is_run_active", true)

	story_manager.call("_on_route_changed", 2, 0, {})
	run_manager.set("is_run_active", previous_active)

	var pending: Array = story_manager.get("_pending_hub_sequences")
	assert_eq(pending, ["固定事件1·小咪"])


func test_debug_jump_story_suppression_covers_direct_jump_through_f6() -> void:
	var story_manager = get_node_or_null("/root/StoryManager")
	var run_manager = get_node_or_null("/root/RunManager")
	assert_not_null(story_manager)
	assert_not_null(run_manager)
	if story_manager == null or run_manager == null:
		return

	_reset_story_manager_queue(story_manager)
	var previous_active := bool(run_manager.get("is_run_active"))
	run_manager.set("is_run_active", true)

	story_manager.call("_on_route_changed", 1, 0, {})
	story_manager.call("_on_route_changed", 6, 0, {})
	story_manager.call("suppress_debug_jump_story", 6)
	run_manager.set("is_run_active", previous_active)

	var pending: Array = story_manager.get("_pending_hub_sequences")
	var flags: Dictionary = story_manager.call("get_played_flags")
	var first_stage_ids: Array = story_manager.call("_get_stage_intro_sequence_ids", 1)
	var first_battle_ids: Array = story_manager.call("_get_battle_intro_sequence_ids", 1)
	var final_fixed_ids: Array = story_manager.call("_get_fixed_event_sequence_ids", 6)
	assert_true(pending.is_empty())
	assert_true(bool(flags.get("beginning", false)))
	assert_true(_has_any_played_flag(flags, first_stage_ids))
	assert_true(_has_any_played_flag(flags, first_battle_ids))
	for completed_act in range(1, 6):
		var completed_fixed_ids: Array = story_manager.call("_get_fixed_event_sequence_ids", completed_act)
		assert_true(bool(flags.get(str(completed_fixed_ids.back()), false)))
	assert_false(bool(flags.get(str(final_fixed_ids.back()), false)))


func test_victory_run_finish_queues_final_fixed_event_before_ending() -> void:
	var story_manager = get_node_or_null("/root/StoryManager")
	var run_manager = get_node_or_null("/root/RunManager")
	assert_not_null(story_manager)
	assert_not_null(run_manager)
	if story_manager == null or run_manager == null:
		return

	_reset_story_manager_queue(story_manager)
	run_manager.set("current_shards", 51)

	story_manager.call("_on_run_finished", true)

	var pending: Array = story_manager.get("_pending_hub_sequences")
	assert_eq(pending.slice(0, 2), ["固定事件6·拾忆", "end1"])


func test_fixed_event_story_frames_are_split_for_book_clicks() -> void:
	var story_manager = get_node_or_null("/root/StoryManager")
	assert_not_null(story_manager)
	if story_manager == null:
		return

	for act in range(1, 7):
		var sequence_id := str(story_manager.call("_get_fixed_event_sequence_ids", act).back())
		var frames: Array = story_manager.call("get_sequence_frames", sequence_id)
		assert_true(frames.size() > 1)
		for frame in frames:
			assert_false(str(Dictionary(frame).get("text", "")).contains("\n"))


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


func _has_any_played_flag(flags: Dictionary, sequence_ids: Array) -> bool:
	for sequence_id in sequence_ids:
		if bool(flags.get(str(sequence_id), false)):
			return true
	return false
