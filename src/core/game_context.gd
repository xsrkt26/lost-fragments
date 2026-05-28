class_name GameContext
extends RefCounted

## 游戏上下文：依赖注入的容器
## 包含了逻辑执行过程中需要访问的所有外部服务和状态管理

var state: Node # 指向 GameState 单例或其他状态节点
var battle: Node # 指向当前 BattleManager
var event_bus: Node # 指向 GlobalEventBus

func _init(p_state: Node, p_battle: Node = null):
	state = p_state
	battle = p_battle
	event_bus = p_state.get_node_or_null("/root/GlobalEventBus") if p_state != null else null

## 快捷访问方法
func add_score(amount: int):
	if state and state.has_method("add_score"):
		state.add_score(amount)

func change_sanity(amount: int):
	if state:
		if amount > 0:
			state.heal_sanity(amount)
		else:
			if battle and battle.has_method("apply_sanity_loss"):
				battle.apply_sanity_loss(abs(amount), "effect", null)
				return
			state.consume_sanity(abs(amount))

func random_float() -> float:
	var run_manager := _get_run_manager()
	if run_manager != null and run_manager.has_method("random_float_for_run"):
		return run_manager.random_float_for_run(false)
	return randf()

func random_index(max_exclusive: int) -> int:
	if max_exclusive <= 0:
		return 0
	var run_manager := _get_run_manager()
	if run_manager != null and run_manager.has_method("random_int_for_run"):
		return run_manager.random_int_for_run(max_exclusive, false)
	return randi() % max_exclusive

func _get_run_manager() -> Node:
	if state == null or not state.is_inside_tree():
		return null
	return state.get_node_or_null("/root/RunManager")
