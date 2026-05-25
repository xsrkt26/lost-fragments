extends Control

## 设置界面：在正式书页美术上放置可交互控件。

const BASE_SIZE := Vector2(1920.0, 1080.0)
const CONTROL_RECTS := {
	"BackButton": Rect2(0.0, 70.0, 92.0, 112.0),
	"ResolutionOption": Rect2(780.0, 215.0, 270.0, 56.0),
	"WindowModeOption": Rect2(1068.0, 215.0, 250.0, 56.0),
	"MasterSlider": Rect2(754.0, 497.0, 520.0, 48.0),
	"MasterValue": Rect2(1302.0, 492.0, 160.0, 58.0),
	"MusicSlider": Rect2(754.0, 586.0, 520.0, 48.0),
	"MusicValue": Rect2(1302.0, 580.0, 160.0, 58.0),
	"SfxSlider": Rect2(754.0, 696.0, 520.0, 48.0),
	"SfxValue": Rect2(1302.0, 690.0, 160.0, 58.0),
	"MuteButton": Rect2(1320.0, 760.0, 150.0, 54.0),
	"AnimationSpeedOption": Rect2(872.0, 914.0, 360.0, 62.0),
	"ResetButton": Rect2(1326.0, 904.0, 126.0, 54.0),
	"CloseButton": Rect2(1464.0, 904.0, 126.0, 54.0),
}

const SPEED_IDS := [
	"slow",
	"normal",
	"fast",
]

@onready var master_slider: HSlider = $UiLayer/MasterSlider
@onready var music_slider: HSlider = $UiLayer/MusicSlider
@onready var sfx_slider: HSlider = $UiLayer/SfxSlider
@onready var master_value: Label = $UiLayer/MasterValue
@onready var music_value: Label = $UiLayer/MusicValue
@onready var sfx_value: Label = $UiLayer/SfxValue
@onready var mute_button: Button = $UiLayer/MuteButton
@onready var resolution_option: OptionButton = $UiLayer/ResolutionOption
@onready var window_mode_option: OptionButton = $UiLayer/WindowModeOption
@onready var animation_speed_option: OptionButton = $UiLayer/AnimationSpeedOption
@onready var reset_button: Button = $UiLayer/ResetButton
@onready var close_button: Button = $UiLayer/CloseButton
@onready var back_button: Button = $UiLayer/BackButton

var _is_updating := false

func _ready() -> void:
	resized.connect(_layout_controls)
	_populate_options()
	_connect_controls()
	_update_ui()
	call_deferred("_layout_controls")

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or Input.is_key_pressed(KEY_ESCAPE):
		_on_close_pressed()
		get_viewport().set_input_as_handled()

func _populate_options() -> void:
	resolution_option.clear()
	for resolution in SettingsManager.RESOLUTION_OPTIONS:
		resolution_option.add_item("%dx%d" % [resolution.x, resolution.y])

	window_mode_option.clear()
	window_mode_option.add_item("窗口模式")
	window_mode_option.add_item("全屏")

	animation_speed_option.clear()
	animation_speed_option.add_item("慢")
	animation_speed_option.add_item("中")
	animation_speed_option.add_item("快")

func _connect_controls() -> void:
	master_slider.value_changed.connect(_on_master_changed)
	music_slider.value_changed.connect(_on_music_changed)
	sfx_slider.value_changed.connect(_on_sfx_changed)
	mute_button.pressed.connect(_on_mute_toggled)
	resolution_option.item_selected.connect(_on_resolution_selected)
	window_mode_option.item_selected.connect(_on_window_mode_selected)
	animation_speed_option.item_selected.connect(_on_animation_speed_selected)
	reset_button.pressed.connect(_on_reset_pressed)
	close_button.pressed.connect(_on_close_pressed)
	back_button.pressed.connect(_on_close_pressed)

func _update_ui() -> void:
	_is_updating = true
	var audio: Dictionary = SettingsManager.audio_settings
	master_slider.value = float(audio["master_volume"])
	music_slider.value = float(audio["music_volume"])
	sfx_slider.value = float(audio["sfx_volume"])
	_update_volume_labels()
	mute_button.text = "解除静音" if bool(audio["is_muted"]) else "静音"

	var resolution: Vector2i = SettingsManager.display_settings["resolution"]
	resolution_option.select(_resolution_index(resolution))
	window_mode_option.select(1 if str(SettingsManager.display_settings["window_mode"]) == SettingsManager.WINDOW_MODE_FULLSCREEN else 0)
	animation_speed_option.select(max(0, SPEED_IDS.find(str(SettingsManager.game_settings["animation_speed"]))))
	_is_updating = false

func _layout_controls() -> void:
	var viewport_size := get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		viewport_size = BASE_SIZE
	var scale_factor: float = maxf(viewport_size.x / BASE_SIZE.x, viewport_size.y / BASE_SIZE.y)
	var displayed_art_size := BASE_SIZE * scale_factor
	var displayed_art_origin := (viewport_size - displayed_art_size) * 0.5

	for node_name in CONTROL_RECTS.keys():
		var node := get_node_or_null("UiLayer/%s" % node_name) as Control
		if node == null:
			continue
		var source_rect: Rect2 = CONTROL_RECTS[node_name]
		var target_rect := Rect2(
			displayed_art_origin + source_rect.position * scale_factor,
			source_rect.size * scale_factor
		)
		node.position = target_rect.position
		node.size = target_rect.size

func _update_volume_labels() -> void:
	master_value.text = "%d%%" % roundi(master_slider.value * 100.0)
	music_value.text = "%d%%" % roundi(music_slider.value * 100.0)
	sfx_value.text = "%d%%" % roundi(sfx_slider.value * 100.0)

func _on_master_changed(val: float) -> void:
	if _is_updating:
		return
	SettingsManager.set_master_volume(val)
	_update_volume_labels()

func _on_music_changed(val: float) -> void:
	if _is_updating:
		return
	SettingsManager.set_music_volume(val)
	_update_volume_labels()

func _on_sfx_changed(val: float) -> void:
	if _is_updating:
		return
	SettingsManager.set_sfx_volume(val)
	_update_volume_labels()

func _on_mute_toggled() -> void:
	var muted = SettingsManager.toggle_mute()
	mute_button.text = "解除静音" if muted else "静音"

func _on_resolution_selected(index: int) -> void:
	if _is_updating:
		return
	if index >= 0 and index < SettingsManager.RESOLUTION_OPTIONS.size():
		SettingsManager.set_resolution(SettingsManager.RESOLUTION_OPTIONS[index])

func _on_window_mode_selected(index: int) -> void:
	if _is_updating:
		return
	var mode := SettingsManager.WINDOW_MODE_FULLSCREEN if index == 1 else SettingsManager.WINDOW_MODE_WINDOWED
	SettingsManager.set_window_mode(mode)

func _on_animation_speed_selected(index: int) -> void:
	if _is_updating:
		return
	if index >= 0 and index < SPEED_IDS.size():
		SettingsManager.set_animation_speed(SPEED_IDS[index])

func _on_reset_pressed() -> void:
	SettingsManager.reset_to_defaults()
	_update_ui()

func _on_close_pressed() -> void:
	queue_free()

func _resolution_index(resolution: Vector2i) -> int:
	for i in range(SettingsManager.RESOLUTION_OPTIONS.size()):
		if SettingsManager.RESOLUTION_OPTIONS[i] == resolution:
			return i
	return 0
