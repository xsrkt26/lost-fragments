extends GutTest

const BattleManagerScript = preload("res://src/battle/battle_manager.gd")

const BATTLE_PUBLIC_METHODS: Array[String] = [
	"request_draw",
	"request_place_item",
	"request_use_tool",
	"request_finish_battle",
	"mark_battle_finished",
]

const BATTLE_PUBLIC_SIGNALS: Array[String] = [
	"item_drawn",
	"battle_finish_requested",
]

var manager

func before_each():
	manager = add_child_autofree(BattleManagerScript.new())
	await get_tree().process_frame

func test_battle_manager_public_methods_remain_available():
	for method_name in BATTLE_PUBLIC_METHODS:
		assert_true(manager.has_method(method_name), "Missing BattleManager public method: %s" % method_name)

func test_battle_manager_public_signals_remain_available():
	for signal_name in BATTLE_PUBLIC_SIGNALS:
		assert_true(manager.has_signal(signal_name), "Missing BattleManager signal: %s" % signal_name)
