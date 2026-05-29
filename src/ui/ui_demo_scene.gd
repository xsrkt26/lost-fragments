extends Node2D

## 演示场景：整合了拼贴风格 UI 与 战斗系统

@onready var main_ui = $MainGameUI # 假设场景中有名为 MainGameUI 的实例
var battle_manager: BattleManager

func _ready():
	battle_manager = BattleManager.new()
	add_child(battle_manager)

	if main_ui:
		main_ui.setup(battle_manager)

	print("[Demo] Integrated scene ready; click draw to start.")