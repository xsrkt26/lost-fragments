extends Control

const DesignScaler = preload("res://src/ui/layout/ui_design_scaler.gd")

## 设置界面：DesignRoot 中的编辑器布局为唯一布局源，运行时只缩放整层。
const DESIGN_SIZE := BookBackgroundConfig.DESIGN_SIZE
const SPEED_IDS := [
	"slow",
	"normal",
	"fast",
]
const POPUP_PANEL_COLOR := Color(0.91, 0.79, 0.58, 0.96)
const POPUP_HOVER_COLOR := Color(0.58, 0.36, 0.18, 0.28)
const POPUP_BORDER_COLOR := Color(0.16, 0.09, 0.04, 0.0)
const POPUP_FONT_COLOR := Color(0.05, 0.035, 0.02, 1.0)

@onready var design_root: Control = $DesignRoot
@onready var art_layer: Control = $DesignRoot/ArtLayer
@onready var master_slider: HSlider = $DesignRoot/UiLayer/MasterSlider
@onready var music_slider: HSlider = $DesignRoot/UiLayer/MusicSlider
@onready var sfx_slider: HSlider = $DesignRoot/UiLayer/SfxSlider
@onready var master_value: Label = $DesignRoot/UiLayer/MasterValue
@onready var music_value: Label = $DesignRoot/UiLayer/MusicValue
@onready var sfx_value: Label = $DesignRoot/UiLayer/SfxValue
@onready var mute_button: Button = $DesignRoot/UiLayer/MuteButton
@onready var resolution_option: OptionButton = $DesignRoot/UiLayer/ResolutionOption
@onready var window_mode_option: OptionButton = $DesignRoot/UiLayer/WindowModeOption
@onready var animation_speed_option: OptionButton = $DesignRoot/UiLayer/AnimationSpeedOption
@onready var reset_button: Button = $DesignRoot/UiLayer/ResetButton
@onready var close_button: Button = $DesignRoot/UiLayer/CloseButton
@onready var back_button: Button = $DesignRoot/UiLayer/BackButton

var _is_updating := false
var _book_page_navigator: Node = null

func _ready() -> void:
	resized.connect(_layout_controls)
	_configure_book_background()
	_populate_options()
	_style_dropdown_popups()
	_connect_controls()
	_update_ui()
	call_deferred("_layout_controls")

func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel") or Input.is_key_pressed(KEY_ESCAPE):
		_on_close_pressed()
		get_viewport().set_input_as_handled()


func set_book_page_navigator(navigator: Node) -> void:
	_book_page_navigator = navigator


func _configure_book_background() -> void:
	if art_layer != null and art_layer.has_method("set_active_page_id"):
		art_layer.call("set_active_page_id", BookBackgroundConfig.PAGE_SETTINGS)

func _populate_options() -> void:
	resolution_option.clear()
	for resolution in SettingsManager.RESOLUTION_OPTIONS:
		resolution_option.add_item("%dx%d" % [resolution.x, resolution.y])

	window_mode_option.clear()
	window_mode_option.add_item("Windowed")
	window_mode_option.add_item("Borderless Fullscreen")

	animation_speed_option.clear()
	animation_speed_option.add_item("慢")
	animation_speed_option.add_item("中")
	animation_speed_option.add_item("快")

func _style_dropdown_popups() -> void:
	for dropdown in [resolution_option, window_mode_option, animation_speed_option]:
		_style_dropdown_popup(dropdown)

func _style_dropdown_popup(dropdown: OptionButton) -> void:
	var popup := dropdown.get_popup()
	popup.borderless = true
	popup.transparent = true
	popup.transparent_bg = true
	popup.add_theme_stylebox_override("embedded_border", StyleBoxEmpty.new())
	popup.add_theme_stylebox_override("embedded_unfocused_border", StyleBoxEmpty.new())
	popup.add_theme_stylebox_override("panel", _make_dropdown_stylebox(POPUP_PANEL_COLOR, POPUP_BORDER_COLOR, 0, 6, false))
	popup.add_theme_stylebox_override("hover", _make_dropdown_stylebox(POPUP_HOVER_COLOR, Color(0, 0, 0, 0), 0, 4, false))
	popup.add_theme_color_override("font_color", POPUP_FONT_COLOR)
	popup.add_theme_color_override("font_hover_color", POPUP_FONT_COLOR)
	popup.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0))
	popup.add_theme_color_override("font_disabled_color", Color(0.22, 0.16, 0.1, 0.45))
	popup.add_theme_font_size_override("font_size", 26)
	popup.add_theme_constant_override("outline_size", 0)
	popup.add_theme_constant_override("v_separation", 8)
	popup.add_theme_constant_override("item_start_padding", 18)
	popup.add_theme_constant_override("item_end_padding", 18)
	var restyle_callback := Callable(self, "_style_dropdown_popup").bind(dropdown)
	if not popup.about_to_popup.is_connected(restyle_callback):
		popup.about_to_popup.connect(restyle_callback)

func _make_dropdown_stylebox(bg_color: Color, border_color: Color, border_width: int, radius: int, with_shadow: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = border_color
	style.border_width_left = border_width
	style.border_width_top = border_width
	style.border_width_right = border_width
	style.border_width_bottom = border_width
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_right = radius
	style.corner_radius_bottom_left = radius
	style.content_margin_left = 12.0
	style.content_margin_top = 8.0
	style.content_margin_right = 12.0
	style.content_margin_bottom = 8.0
	if with_shadow:
		style.shadow_color = Color(0.2, 0.12, 0.06, 0.14)
		style.shadow_size = 4
		style.shadow_offset = Vector2(0.0, 1.0)
	return style

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
	window_mode_option.select(1 if str(SettingsManager.display_settings["window_mode"]) == SettingsManager.WINDOW_MODE_BORDERLESS_FULLSCREEN else 0)
	animation_speed_option.select(max(0, SPEED_IDS.find(str(SettingsManager.game_settings["animation_speed"]))))
	_is_updating = false

func _layout_controls() -> void:
	DesignScaler.layout_root(design_root, get_viewport_rect().size, DESIGN_SIZE, DesignScaler.SCALE_MODE_COVER)
	_update_zipper_heads()

func _update_zipper_heads() -> void:
	_set_zipper_visual_value("Master", master_slider.value)
	_set_zipper_visual_value("Music", music_slider.value)
	_set_zipper_visual_value("Sfx", sfx_slider.value)

func _set_zipper_visual_value(track_name: String, value: float) -> void:
	var visual := get_node_or_null("DesignRoot/ArtLayer/ZipperVisual%s" % track_name)
	if visual != null and visual.has_method("set_zipper_value"):
		visual.set_zipper_value(value)

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
	var mode := SettingsManager.WINDOW_MODE_BORDERLESS_FULLSCREEN if index == 1 else SettingsManager.WINDOW_MODE_WINDOWED
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
	if _book_page_navigator != null and is_instance_valid(_book_page_navigator) and _book_page_navigator.has_method("return_to_main_menu"):
		_book_page_navigator.return_to_main_menu()
	else:
		GlobalScene.transition_to(GlobalScene.SceneType.MAIN_MENU, false)

func _resolution_index(resolution: Vector2i) -> int:
	for i in range(SettingsManager.RESOLUTION_OPTIONS.size()):
		if SettingsManager.RESOLUTION_OPTIONS[i] == resolution:
			return i
	return 0
