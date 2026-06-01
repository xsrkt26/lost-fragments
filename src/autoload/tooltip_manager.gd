extends Node

## 全局提示管理器：统一调度卡牌和 UI 的浮窗显示
## 支持显示延迟、内容格式化和自动定位

# 关键词高亮映射
const KEYWORD_COLORS = {
	"污染": "#ff55ff",
	"防腐": "#55ffff",
	"分": "#ffff55",
	"梦值": "#ff5555",
	"捕梦": "#ffaa55",
	"撞击": "#ffffff"
}

var _tooltip_instance: Node = null
var _display_delay: float = 0.2
var _delay_timer: Timer

func _ready():
	_delay_timer = Timer.new()
	_delay_timer.one_shot = true
	_delay_timer.timeout.connect(_on_delay_timeout)
	add_child(_delay_timer)
	
	# 预加载并实例化浮窗层
	var scene = load("res://src/ui/tooltip/card_tooltip.tscn")
	_tooltip_instance = scene.instantiate()
	add_child(_tooltip_instance)

# --- 外部调用接口 ---

## 显示卡牌提示
func show_item(item_data: ItemData, instance_data: Variant = null):
	if item_data == null:
		hide()
		return
	if _tooltip_instance == null:
		return
	# 停止当前的延迟或隐藏
	_delay_timer.stop()
	
	# 准备数据
	var processed_desc = _process_text(item_data.get_tooltip_text(instance_data))
	
	# 如果正在显示，直接更新内容；否则开启延迟计时
	if _tooltip_instance.is_panel_visible():
		_tooltip_instance.show_tooltip(item_data.item_name, processed_desc, instance_data)
	else:
		_current_request = {"name": item_data.item_name, "desc": processed_desc, "inst": instance_data}
		_delay_timer.start(_display_delay)

func show_text(title: String, body: String, instance_data: Variant = null) -> void:
	if title == "" and body == "":
		hide()
		return
	if _tooltip_instance == null:
		return
	_delay_timer.stop()
	var processed_desc = _process_text(body)
	if _tooltip_instance.is_panel_visible():
		_tooltip_instance.show_tooltip(title, processed_desc, instance_data)
	else:
		_current_request = {"name": title, "desc": processed_desc, "inst": instance_data}
		_delay_timer.start(_display_delay)

## 隐藏提示
func hide():
	_delay_timer.stop()
	_current_request = null
	if _tooltip_instance:
		_tooltip_instance.hide_tooltip()

# --- 内部逻辑 ---

var _current_request = null

func _on_delay_timeout():
	if _current_request:
		_tooltip_instance.show_tooltip(_current_request.name, _current_request.desc, _current_request.inst)

func _process_text(text: String) -> String:
	var result = text
	# 自动替换关键词为 BBCode 颜色代码
	for keyword in KEYWORD_COLORS.keys():
		var color = KEYWORD_COLORS[keyword]
		# 使用正则或简单替换 (注意：这里简单替换，复杂情况需正则)
		result = result.replace(keyword, "[color=%s]%s[/color]" % [color, keyword])
	return result
