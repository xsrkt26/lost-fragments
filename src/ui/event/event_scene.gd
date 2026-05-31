extends Control

const DesignScaler = preload("res://src/ui/layout/ui_design_scaler.gd")

const DESIGN_SIZE := BookBackgroundConfig.DESIGN_SIZE

@onready var design_root: Control = $MarginContainer
@onready var title_label = $MarginContainer/VBoxContainer/TitleLabel
@onready var desc_label = $MarginContainer/VBoxContainer/DescLabel
@onready var choice_container = $MarginContainer/VBoxContainer/ChoiceContainer
@onready var continue_button = $MarginContainer/VBoxContainer/ContinueButton

var current_event = null
var choices_pending := false
var pending_confirm_choice_id := ""

func _ready():
	GlobalInput.set_context(GlobalInput.Context.UI)
	GlobalAudio.play_bgm("hub")
	if not resized.is_connected(_layout_design_root):
		resized.connect(_layout_design_root)
	_layout_design_root()
	continue_button.pressed.connect(_on_continue_pressed)
	_populate_event()
	call_deferred("_layout_design_root")


func _layout_design_root() -> void:
	DesignScaler.layout_root(design_root, get_viewport_rect().size, DESIGN_SIZE, DesignScaler.SCALE_MODE_CONTAIN)

func _populate_event() -> void:
	var rm = get_node_or_null("/root/RunManager")
	var event_db = get_node_or_null("/root/EventDatabase")
	for child in choice_container.get_children():
		child.queue_free()

	if rm and event_db and rm.has_method("pick_current_event"):
		current_event = rm.pick_current_event(event_db)
	elif rm and event_db and event_db.has_method("pick_event_for_run"):
		current_event = event_db.pick_event_for_run(rm)
	if current_event != null:
		title_label.text = current_event.event_name
		desc_label.text = current_event.description
		choices_pending = not current_event.choices.is_empty()
		continue_button.visible = not choices_pending
		for choice in current_event.choices:
			_add_choice_button(choice)
	elif rm:
		var node = rm.get_current_route_node()
		title_label.text = node.get("label", "事件")
		desc_label.text = "当前没有可用事件。"
		choices_pending = false
		continue_button.visible = true

func _add_choice_button(choice: Dictionary) -> void:
	var btn = Button.new()
	btn.text = _format_choice_text(choice)
	btn.tooltip_text = str(choice.get("description", ""))
	btn.custom_minimum_size = Vector2(420, 72)
	btn.pressed.connect(func(): _on_choice_pressed(choice, btn))
	choice_container.add_child(btn)

func _format_choice_text(choice: Dictionary) -> String:
	var lines: Array[String] = [str(choice.get("title", "选择")), str(choice.get("description", ""))]
	var preview = str(choice.get("preview", ""))
	if preview != "":
		lines.append(preview)
	return "\n".join(lines)

func _input(event):
	if not GlobalInput.can_cancel():
		return
	if event.is_action_pressed("ui_cancel") or Input.is_key_pressed(KEY_ESCAPE):
		if choices_pending:
			return
		_on_continue_pressed()

func _on_choice_pressed(choice: Dictionary, button: Button) -> void:
	if not choices_pending:
		return
	var rm = get_node_or_null("/root/RunManager")
	if rm == null or not rm.has_method("apply_event_choice"):
		return
	var choice_id = str(choice.get("id", choice.get("title", "")))
	if _choice_requires_confirmation(choice) and pending_confirm_choice_id != choice_id:
		pending_confirm_choice_id = choice_id
		button.text = _format_choice_text(choice) + "\n再次点击确认"
		return
	if not rm.apply_event_choice(choice):
		button.disabled = true
		button.text = str(choice.get("title", "选择")) + "\n条件不足"
		return
	choices_pending = false
	_on_continue_pressed()

func _choice_requires_confirmation(choice: Dictionary) -> bool:
	if bool(choice.get("requires_confirm", false)):
		return true
	for effect in Array(choice.get("effects", [])):
		if not (effect is Dictionary):
			continue
		var effect_type = str(effect.get("type", ""))
		if effect_type.begins_with("backpack_") and effect_type != "backpack_space":
			return true
	return false

func _on_continue_pressed():
	var rm = get_node_or_null("/root/RunManager")
	if rm and rm.get_current_route_node_type() == RouteConfig.NODE_EVENT:
		rm.advance_route_node()
	var next_scene = GlobalScene.SceneType.MAIN_MENU if rm and rm.is_run_complete else GlobalScene.SceneType.HUB
	GlobalScene.transition_to(next_scene, false)
