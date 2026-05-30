class_name SequencePlayer
extends Node

## 序列播放器：负责按顺序执行 Action 并播放对应的动画表现
## 集成了音频触发和全局视觉反馈

signal sequence_finished

var node_map: Dictionary # 用于从 ItemData 查找 ItemUI 节点
var context: GameContext

## 执行动作序列
func play_sequence(action_list: Array[GameAction], p_node_map: Dictionary, p_context: GameContext):
	node_map = p_node_map
	context = p_context
	for action in action_list:
		await _execute_action(action)
	
	sequence_finished.emit()

func _execute_action(action: GameAction):
	# 获取关联的 UI 节点
	var target_ui: Control = null
	if action.item_instance:
		var rid = action.item_instance.data.runtime_id
		if node_map.has(rid):
			target_ui = node_map[rid]

	match action.type:
		GameAction.Type.IMPACT:
			# 视觉与音频反馈：撞击感
			GlobalAudio.play_sfx("hit")
			GlobalFeedback.shake_screen(4.0, 0.15)
			
			if target_ui:
				await target_ui.play_impact_anim()
			else:
				if action.item_instance == null:
					await get_tree().create_timer(0.1).timeout
				else:
					await get_tree().create_timer(0.2).timeout
				
		GameAction.Type.NUMERIC:
			var data = action.value
			var amount = data.get("amount", 0)
			
			# 视觉与音频反馈：数值变动
			if data.type == "score" and amount > 0:
				GlobalAudio.play_sfx("score")
				if target_ui:
					GlobalFeedback.show_text("+%d" % amount, target_ui.global_position + target_ui.size/2, GlobalFeedback.TextType.SCORE)
			elif data.type == "sanity":
				if target_ui:
					var prefix = "+" if amount > 0 else ""
					GlobalFeedback.show_text("%s%d 梦值" % [prefix, amount], target_ui.global_position + target_ui.size/2, GlobalFeedback.TextType.SANITY)

			# 播放物体本身的闪烁动画
			if target_ui:
				await target_ui.play_effect_anim()
			
			# 实际执行数值修改
			_apply_numeric_change(action)
			_apply_post_numeric_refresh(action)
			await get_tree().create_timer(0.1).timeout

func _apply_numeric_change(action: GameAction):
	var data = action.value
	if not context:
		return

	if data.type == "score":
		context.add_score(data.amount)
	elif data.type == "sanity":
		context.change_sanity(data.amount)

func _apply_post_numeric_refresh(action: GameAction) -> void:
	var data = action.value
	if not (data is Dictionary):
		return
	if not bool(data.get("refresh_backpack_visuals", false)):
		return
	if context == null or context.battle == null:
		return
	if context.battle.has_method("refresh_backpack_item_visuals"):
		context.battle.refresh_backpack_item_visuals()
