extends Control

## 主菜单：使用整张正式美术图作为背景，按钮只提供透明点击热区。

const BASE_MENU_SIZE := Vector2(1920.0, 1080.0)
const HOTSPOT_RECTS := {
	"NewGameButton": Rect2(1370.0, 180.0, 390.0, 125.0),
	"ContinueButton": Rect2(1370.0, 300.0, 390.0, 125.0),
	"GalleryButton": Rect2(1360.0, 430.0, 390.0, 155.0),
	"SettingsButton": Rect2(1360.0, 585.0, 370.0, 165.0),
	"QuitButton": Rect2(1605.0, 750.0, 250.0, 300.0),
	"ContinueDisabledOverlay": Rect2(1385.0, 300.0, 230.0, 125.0),
}

@onready var continue_button: Button = $MenuHotspots/ContinueButton
@onready var new_game_button: Button = $MenuHotspots/NewGameButton
@onready var gallery_button: Button = $MenuHotspots/GalleryButton
@onready var settings_button: Button = $MenuHotspots/SettingsButton
@onready var quit_button: Button = $MenuHotspots/QuitButton
@onready var continue_disabled_overlay: ColorRect = $MenuHotspots/ContinueDisabledOverlay
@onready var settings_container: Control = $CanvasLayer/SettingsContainer

var run_manager_override = null

func _ready() -> void:
	print("[MainMenu] 进入主菜单")
	GlobalInput.set_context(GlobalInput.Context.MENU)
	GlobalAudio.play_bgm("menu")

	resized.connect(_update_menu_hotspots)
	call_deferred("_update_menu_hotspots")
	_configure_hotspot_labels()
	_refresh_continue_state()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_F1:
		GlobalScene.transition_to(GlobalScene.SceneType.DEBUG)

func _configure_hotspot_labels() -> void:
	new_game_button.text = ""
	continue_button.text = ""
	gallery_button.text = ""
	settings_button.text = ""
	quit_button.text = ""
	new_game_button.tooltip_text = "开始游戏"
	gallery_button.tooltip_text = "图鉴"
	settings_button.tooltip_text = "设置"
	quit_button.tooltip_text = "退出"

func _refresh_continue_state() -> void:
	var rm = _get_run_manager()
	var has_continue_save: bool = rm != null and rm.saver != null and rm.saver.has_save() and not rm.is_run_complete
	continue_button.disabled = not has_continue_save
	continue_disabled_overlay.visible = not has_continue_save
	if has_continue_save:
		continue_button.tooltip_text = "继续游戏（第 %d 场景）" % rm.current_act
	else:
		continue_button.tooltip_text = "继续游戏（无存档）"

func _update_menu_hotspots() -> void:
	var viewport_size := get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		viewport_size = BASE_MENU_SIZE

	var scale_factor: float = maxf(viewport_size.x / BASE_MENU_SIZE.x, viewport_size.y / BASE_MENU_SIZE.y)
	var displayed_art_size: Vector2 = BASE_MENU_SIZE * scale_factor
	var displayed_art_origin: Vector2 = (viewport_size - displayed_art_size) * 0.5

	for node_name in HOTSPOT_RECTS.keys():
		var node := get_node_or_null("MenuHotspots/%s" % node_name)
		if node == null or not node is Control:
			continue
		var source_rect: Rect2 = HOTSPOT_RECTS[node_name]
		var target_rect: Rect2 = Rect2(
			displayed_art_origin + source_rect.position * scale_factor,
			source_rect.size * scale_factor
		)
		var control := node as Control
		control.position = target_rect.position
		control.size = target_rect.size
		control.pivot_offset = target_rect.size * 0.5

func _on_new_game_button_pressed() -> void:
	print("[MainMenu] 点击新游戏")
	if _start_new_run():
		GlobalScene.transition_to(GlobalScene.SceneType.HUB)

func _start_new_run() -> bool:
	var rm = _get_run_manager()
	if rm == null or not rm.has_method("start_new_run"):
		push_warning("[MainMenu] RunManager missing; cannot start a new run.")
		return false
	rm.start_new_run()
	return true

func _get_run_manager():
	if run_manager_override != null:
		return run_manager_override
	return get_node_or_null("/root/RunManager")

func _on_continue_button_pressed() -> void:
	print("[MainMenu] 点击继续游戏")
	GlobalScene.transition_to(GlobalScene.SceneType.HUB)

func _on_gallery_button_pressed() -> void:
	print("[MainMenu] 进入图鉴")
	GlobalScene.transition_to(GlobalScene.SceneType.GALLERY)

func _on_settings_button_pressed() -> void:
	if settings_container.get_child_count() > 0:
		for child in settings_container.get_children():
			child.queue_free()
	else:
		var scene = load("res://src/ui/settings/audio_settings_ui.tscn")
		var ui = scene.instantiate()
		settings_container.add_child(ui)

func _on_quit_button_pressed() -> void:
	get_tree().quit()
