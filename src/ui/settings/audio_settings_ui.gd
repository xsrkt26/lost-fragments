extends Control

## 设置界面：在正式书页美术上放置可交互控件。

const BASE_SIZE := Vector2(1920.0, 1080.0)
const ART_RECTS := {
	"WoodFloor": Rect2(0.0, 0.0, 1920.0, 1080.0),
	"RedBookCover": Rect2(32.0, 38.0, 1916.0, 1047.0),
	"BackTab": Rect2(4.0, 68.0, 207.0, 161.0),
	"AlbumPage": Rect2(51.0, 0.0, 1670.0, 1080.0),
	"AlbumTab": Rect2(1604.0, 191.0, 217.0, 164.0),
	"BackpackTab": Rect2(1554.0, 294.0, 223.0, 179.0),
	"GalleryTab": Rect2(1580.0, 419.0, 205.0, 183.0),
	"SettingsTab": Rect2(8.0, 497.0, 214.0, 186.0),
	"AlbumRingRight": Rect2(1793.0, 1.0, 127.0, 1063.0),
}
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
const STATIC_LABEL_RECTS := {
	"LabelVideo": Rect2(350.0, 148.0, 220.0, 70.0),
	"LabelResolution": Rect2(350.0, 226.0, 220.0, 52.0),
	"LabelAudio": Rect2(350.0, 432.0, 220.0, 70.0),
	"LabelMaster": Rect2(350.0, 508.0, 220.0, 52.0),
	"LabelMusic": Rect2(350.0, 610.0, 220.0, 52.0),
	"LabelSfx": Rect2(350.0, 708.0, 220.0, 52.0),
	"LabelGame": Rect2(350.0, 842.0, 220.0, 70.0),
	"LabelAnimation": Rect2(350.0, 928.0, 250.0, 52.0),
	"LabelSpeedChoices": Rect2(882.0, 928.0, 330.0, 52.0),
}
const STATIC_LABEL_TEXT := {
	"LabelVideo": "视频:",
	"LabelResolution": "分辨率:",
	"LabelAudio": "音频:",
	"LabelMaster": "主音量:",
	"LabelMusic": "BGM:",
	"LabelSfx": "音效:",
	"LabelGame": "游戏:",
	"LabelAnimation": "动画速度:",
	"LabelSpeedChoices": "慢  /  中  /  快",
}
const ZIPPER_TRACK_RECTS := {
	"Master": Rect2(754.0, 499.0, 520.0, 48.0),
	"Music": Rect2(754.0, 606.0, 520.0, 48.0),
	"Sfx": Rect2(754.0, 698.0, 520.0, 48.0),
}
const ZIPPER_HEAD_SIZE := Vector2(141.0, 36.0)
const ZIPPER_MAX_OPEN_OFFSET := 18.0
const ZIPPER_MAX_OPEN_ROTATION := 0.085

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
@onready var art_layer: Control = $ArtLayer
@onready var ui_layer: Control = $UiLayer

var _is_updating := false

func _ready() -> void:
	resized.connect(_layout_controls)
	_ensure_static_labels()
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
	_layout_art_nodes()
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
	for node_name in STATIC_LABEL_RECTS.keys():
		var label := get_node_or_null("UiLayer/%s" % node_name) as Label
		if label == null:
			continue
		var label_source_rect: Rect2 = STATIC_LABEL_RECTS[node_name]
		var label_target_rect := Rect2(
			displayed_art_origin + label_source_rect.position * scale_factor,
			label_source_rect.size * scale_factor
		)
		label.position = label_target_rect.position
		label.size = label_target_rect.size
		label.add_theme_font_size_override("font_size", roundi(_label_base_font_size(node_name) * scale_factor))
	_update_zipper_heads()

func _layout_art_nodes() -> void:
	for node_name in ART_RECTS.keys():
		var node := get_node_or_null("ArtLayer/%s" % node_name) as Control
		if node == null:
			continue
		_layout_art_control(node, ART_RECTS[node_name])
	for track_name in ZIPPER_TRACK_RECTS.keys():
		_layout_zipper_pair(track_name)
	_update_zipper_heads()

func _layout_art_control(control: Control, source_rect: Rect2) -> void:
	var target := _art_rect_to_viewport(source_rect)
	control.position = target.position
	control.size = target.size

func _art_rect_to_viewport(source_rect: Rect2) -> Rect2:
	var viewport_size := get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		viewport_size = BASE_SIZE
	var scale_factor: float = maxf(viewport_size.x / BASE_SIZE.x, viewport_size.y / BASE_SIZE.y)
	var displayed_art_size := BASE_SIZE * scale_factor
	var displayed_art_origin := (viewport_size - displayed_art_size) * 0.5
	return Rect2(
		displayed_art_origin + source_rect.position * scale_factor,
		source_rect.size * scale_factor
	)

func _ensure_static_labels() -> void:
	for node_name in STATIC_LABEL_RECTS.keys():
		if ui_layer.has_node(node_name):
			continue
		var label := Label.new()
		label.name = node_name
		label.text = STATIC_LABEL_TEXT[node_name]
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.add_theme_color_override("font_color", Color(0.03, 0.02, 0.015, 1))
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		ui_layer.add_child(label)

func _label_base_font_size(node_name: String) -> int:
	if node_name in ["LabelVideo", "LabelAudio", "LabelGame"]:
		return 48
	if node_name == "LabelSpeedChoices":
		return 34
	return 36

func _update_zipper_heads() -> void:
	_position_zipper_head("Master", master_slider.value)
	_position_zipper_head("Music", music_slider.value)
	_position_zipper_head("Sfx", sfx_slider.value)
	_layout_zipper_pair("Master", master_slider.value)
	_layout_zipper_pair("Music", music_slider.value)
	_layout_zipper_pair("Sfx", sfx_slider.value)

func _layout_zipper_pair(track_name: String, value: float = 1.0) -> void:
	if not ZIPPER_TRACK_RECTS.has(track_name):
		return
	var top := get_node_or_null("ArtLayer/SliderTrack%sTop" % track_name) as Control
	var bottom := get_node_or_null("ArtLayer/SliderTrack%sBottom" % track_name) as Control
	if top == null or bottom == null:
		return
	var source_rect: Rect2 = ZIPPER_TRACK_RECTS[track_name]
	var target: Rect2 = _art_rect_to_viewport(source_rect)
	var scale_factor: float = target.size.x / source_rect.size.x
	var open_amount: float = 1.0 - clampf(value, 0.0, 1.0)
	var offset: float = ZIPPER_MAX_OPEN_OFFSET * open_amount * scale_factor
	var rotation: float = ZIPPER_MAX_OPEN_ROTATION * open_amount
	var pivot_x: float = clampf(value, 0.0, 1.0) * target.size.x
	for node in [top, bottom]:
		node.position = target.position
		node.size = target.size
		node.pivot_offset = Vector2(pivot_x, target.size.y * 0.5)
	top.position.y -= offset
	bottom.position.y += offset
	top.rotation = -rotation
	bottom.rotation = rotation

func _position_zipper_head(track_name: String, value: float) -> void:
	if not ZIPPER_TRACK_RECTS.has(track_name):
		return
	var head := get_node_or_null("ArtLayer/SliderHead%s" % track_name) as Control
	if head == null:
		return
	var source_rect: Rect2 = ZIPPER_TRACK_RECTS[track_name]
	var track_target: Rect2 = _art_rect_to_viewport(source_rect)
	var scale_factor: float = track_target.size.x / source_rect.size.x
	var head_size: Vector2 = ZIPPER_HEAD_SIZE * scale_factor
	head.size = head_size
	head.position = Vector2(
		track_target.position.x + clampf(value, 0.0, 1.0) * maxf(0.0, track_target.size.x - head_size.x),
		track_target.position.y + (track_target.size.y - head_size.y) * 0.5
	)

func _update_volume_labels() -> void:
	master_value.text = "%d%%" % roundi(master_slider.value * 100.0)
	music_value.text = "%d%%" % roundi(music_slider.value * 100.0)
	sfx_value.text = "%d%%" % roundi(sfx_slider.value * 100.0)
	_update_zipper_heads()

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
	GlobalScene.go_back()

func _resolution_index(resolution: Vector2i) -> int:
	for i in range(SettingsManager.RESOLUTION_OPTIONS.size()):
		if SettingsManager.RESOLUTION_OPTIONS[i] == resolution:
			return i
	return 0
