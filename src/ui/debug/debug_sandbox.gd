extends Node2D

## 调试沙盒：集成环境

@onready var main_ui = $CanvasLayer/MainGameUI
@onready var debug_list = $CanvasLayer/DebugItemList
var battle_manager: BattleManager

func _ready():
	# 1. 创建逻辑中枢
	battle_manager = BattleManager.new()
	add_child(battle_manager)
	
	# 2. 初始化主 UI
	if main_ui:
		main_ui.setup(battle_manager)
	
	# 3. 初始化调试列表
	if debug_list:
		debug_list.setup(battle_manager)
	
	print("[Sandbox] Ready.")

func _input(event):
	# 输入权限检查
	if not GlobalInput.can_cancel(): return

	# ESC 返回主菜单
	if event.is_action_pressed("ui_cancel") or Input.is_key_pressed(KEY_ESCAPE):
		GlobalScene.go_back()
		return

	# Tab / F1 切换调试面板显示
	if event.is_action_pressed("ui_focus_next"): # Tab 键默认映射
		debug_list.visible = !debug_list.visible
