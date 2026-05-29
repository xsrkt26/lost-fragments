extends CanvasLayer

## 卡牌提示视觉组件：负责具体的渲染与排版

@onready var panel = $PanelContainer
@onready var title_label = $PanelContainer/MarginContainer/VBoxContainer/TitleLabel
@onready var desc_label = $PanelContainer/MarginContainer/VBoxContainer/DescLabel
@onready var status_label = $PanelContainer/MarginContainer/VBoxContainer/StatusLabel

func _ready():
	add_to_group("card_tooltip")
	panel.hide()
	# 初始透明度为0，用于淡入
	panel.modulate.a = 0

func is_panel_visible() -> bool:
	return panel.visible

func show_tooltip(p_name: String, p_desc: String, instance_data: Variant = null):
	title_label.text = p_name
	desc_label.text = p_desc

	if is_instance_valid(instance_data) and instance_data.current_pollution > 0:
		status_label.text = "当前污染: " + str(instance_data.current_pollution) + " 层"
		status_label.show()
	else:
		status_label.hide()

	_update_position()

	if not panel.visible:
		panel.show()
		var tween = create_tween()
		tween.tween_property(panel, "modulate:a", 1.0, 0.1)

func hide_tooltip():
	if not panel.visible: return
	
	var tween = create_tween()
	await tween.tween_property(panel, "modulate:a", 0.0, 0.1).finished
	panel.hide()

func _process(_delta):
	if panel.visible:
		_update_position()

func _update_position():
	var mouse_pos = panel.get_global_mouse_position()
	var mouse_offset = Vector2(20, 20) 
	var new_pos = mouse_pos + mouse_offset
	
	# 智能边界检查
	var viewport_size = get_viewport().get_visible_rect().size
	
	# 如果超出右边界，移到鼠标左侧
	if new_pos.x + panel.size.x > viewport_size.x:
		new_pos.x = mouse_pos.x - panel.size.x - 20
		
	# 如果超出下边界，移到鼠标上方
	if new_pos.y + panel.size.y > viewport_size.y:
		new_pos.y = mouse_pos.y - panel.size.y - 20
		
	# 确保不超出左边或顶边
	new_pos.x = max(10, new_pos.x)
	new_pos.y = max(10, new_pos.y)
		
	panel.global_position = new_pos
