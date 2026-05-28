extends Node

# 全局游戏状态管理 (GameState)
# 建议在 Godot 的 Project Settings -> Autoload 中将其注册为 "GS" 或 "GameState"

signal sanity_changed(new_value: int)
signal score_changed(new_value: int)
signal game_over

@export var max_sanity: int = 100
var current_sanity: int = 100:
	set(v):
		var was_alive := current_sanity > 0
		current_sanity = clamp(v, 0, max_sanity)
		sanity_changed.emit(current_sanity)
		if was_alive and current_sanity <= 0:
			game_over.emit()

var current_score: int = 0:
	set(v):
		current_score = v
		score_changed.emit(current_score)

# 全局修饰器系统 (Global Modifiers)
var modifiers: Dictionary = {}

func set_modifier(key: String, value: Variant):
	modifiers[key] = value

func get_modifier(key: String, default_value: Variant = null) -> Variant:
	return modifiers.get(key, default_value)

func reset_game():
	current_sanity = max_sanity
	current_score = 0
	modifiers.clear()

func add_score(amount: int):
	current_score += amount
	print("[GS] 分数 +", amount, " | 当前总分: ", current_score)

func consume_sanity(amount: int):
	current_sanity -= amount
	print("[GS] 梦值 -", amount, " | 当前梦值: ", current_sanity)

func heal_sanity(amount: int):
	current_sanity += amount
	print("[GS] 梦值 +", amount, " | 当前梦值: ", current_sanity)
