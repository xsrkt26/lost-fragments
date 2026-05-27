extends Node2D

const HUB_SOURCE_SIZE := Vector2(1593.0, 872.0)
const HUB_ROOM_SOURCE_POS := Vector2(156.0, 50.0)
const HUB_ROOM_DISPLAY_SIZE := Vector2(1371.0, 772.0)
const HUB_BACKGROUND_TEXTURES := {
	"grandma": preload("res://assets/ui/hub/backgrounds/grandma.png"),
	"xiaojia": preload("res://assets/ui/hub/backgrounds/xiaojia.png"),
	"parents": preload("res://assets/ui/hub/backgrounds/parents.png"),
	"cardboard": preload("res://assets/ui/hub/backgrounds/cardboard.png"),
	"stage": preload("res://assets/ui/hub/backgrounds/stage.png"),
}
const HUB_FOREGROUND_TEXTURES := {
	"xiaojia": preload("res://assets/ui/hub/backgrounds/xiaojia_foreground.png"),
	"stage": preload("res://assets/ui/hub/backgrounds/stage_foreground.png"),
}
const PLAYER_START_SOURCE_X := 455.0
const PLAYER_FLOOR_SOURCE_Y := 818.0
const PLAYER_FLOOR_OFFSET := 64.0
const PLAYER_WALK_MIN_SOURCE_X := 250.0
const PLAYER_WALK_MAX_SOURCE_X := 1360.0
const DEFAULT_SPEECH_TEXT := "你终于醒了！"
const OPTION_RECTS := {
	"RouteButton": Rect2(0.0, 170.0, 176.0, 100.0),
	"BackpackButton": Rect2(0.0, 282.0, 166.0, 96.0),
	"GalleryButton": Rect2(0.0, 386.0, 176.0, 100.0),
	"SettingsButton": Rect2(0.0, 492.0, 166.0, 100.0),
}

@onready var viewport_background: TextureRect = $ViewportBackground
@onready var hub_art: Node2D = $HubArt
@onready var overlay_root: Control = $CanvasLayer/OverlayRoot
@onready var player: CharacterBody2D = $Player
@onready var floor_body: StaticBody2D = $Floor
@onready var interactions: Node2D = $Interactions
@onready var room_art: Sprite2D = $HubArt/Room
@onready var foreground_art: Sprite2D = $HubArt/Foreground
@onready var speech_bubble: Sprite2D = $HubArt/SpeechBubble
@onready var speech_text: Label = $HubArt/SpeechText

var current_zone: String = ""
var _art_origin: Vector2 = Vector2.ZERO
var _art_scale: float = 1.0
var _has_positioned_player := false
var _default_room_texture: Texture2D = null
var _default_room_position := Vector2.ZERO
var _default_room_scale := Vector2.ONE


func _ready() -> void:
	print("[Hub] 已进入梦境路线。")
	GlobalInput.set_context(GlobalInput.Context.WORLD)
	GlobalAudio.play_bgm(_get_stage_bgm_key("hub_bgm_key", "hub"))
	_hide_speech()
	_capture_default_hub_room_art()

	var rm = get_node_or_null("/root/RunManager")
	if rm and rm.has_signal("route_changed"):
		var route_changed_callback := Callable(self, "_on_route_changed")
		if not rm.route_changed.is_connected(route_changed_callback):
			rm.route_changed.connect(route_changed_callback)
	_apply_stage_hub_background()

	if rm and rm.is_run_complete:
		GlobalScene.transition_to(GlobalScene.SceneType.MAIN_MENU, false)
		return

	if interactions:
		interactions.hide()
	if get_viewport():
		get_viewport().size_changed.connect(_layout_scene)
	_layout_scene()

func _get_stage_bgm_key(key: String, fallback: String) -> String:
	var visual := _get_stage_visual()
	var bgm_key = str(visual.get(key, fallback))
	return bgm_key if bgm_key != "" else fallback


func _get_stage_visual() -> Dictionary:
	var rm = get_node_or_null("/root/RunManager")
	if rm == null or not rm.has_method("get_current_stage_visual"):
		return {}
	var visual = rm.get_current_stage_visual()
	return Dictionary(visual).duplicate(true) if visual is Dictionary else {}


func _on_route_changed(_current_act: int, _route_index: int, _current_node: Dictionary) -> void:
	_apply_stage_hub_background()


func _capture_default_hub_room_art() -> void:
	if room_art == null or _default_room_texture != null:
		return
	_default_room_texture = room_art.texture
	_default_room_position = room_art.position
	_default_room_scale = room_art.scale


func _apply_stage_hub_background() -> void:
	var rm = get_node_or_null("/root/RunManager")
	if rm == null or not bool(rm.get("is_run_active")):
		_restore_default_hub_background()
		return

	var visual := _get_stage_visual()
	var configured_path := str(visual.get("hub_background_path", ""))
	var background_key := _normalize_hub_background_key(str(visual.get("hub_background_key", "")))
	if configured_path == "" and background_key == "":
		_restore_default_hub_background()
		return

	var background_texture := _get_hub_background_texture(visual, background_key)
	if room_art == null or background_texture == null:
		_restore_default_hub_background()
		return
	room_art.texture = background_texture
	_fit_hub_room_sprite(room_art, background_texture)

	if foreground_art == null:
		return
	var foreground_texture := _get_hub_foreground_texture(visual, background_key)
	foreground_art.texture = foreground_texture
	foreground_art.visible = foreground_texture != null
	if foreground_texture != null:
		_fit_hub_room_sprite(foreground_art, foreground_texture)


func _normalize_hub_background_key(key: String) -> String:
	if HUB_BACKGROUND_TEXTURES.has(key):
		return key
	return ""


func _get_hub_background_texture(visual: Dictionary, background_key: String) -> Texture2D:
	var configured_path := str(visual.get("hub_background_path", ""))
	var configured_texture := _load_texture_from_path(configured_path)
	if configured_texture != null:
		return configured_texture
	if background_key == "":
		return null
	return HUB_BACKGROUND_TEXTURES.get(background_key, null) as Texture2D


func _get_hub_foreground_texture(visual: Dictionary, background_key: String) -> Texture2D:
	var configured_path := str(visual.get("hub_foreground_path", ""))
	var configured_texture := _load_texture_from_path(configured_path)
	if configured_texture != null:
		return configured_texture
	var foreground_key := _normalize_hub_background_key(str(visual.get("hub_foreground_key", background_key)))
	return HUB_FOREGROUND_TEXTURES.get(foreground_key, null) as Texture2D


func _restore_default_hub_background() -> void:
	if room_art != null and _default_room_texture != null:
		room_art.texture = _default_room_texture
		room_art.position = _default_room_position
		room_art.scale = _default_room_scale
	if foreground_art != null:
		foreground_art.texture = null
		foreground_art.visible = false


func _load_texture_from_path(path: String) -> Texture2D:
	if path == "" or not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D


func _fit_hub_room_sprite(sprite: Sprite2D, texture: Texture2D) -> void:
	var texture_size := texture.get_size()
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return
	var display_scale := minf(
		HUB_ROOM_DISPLAY_SIZE.x / texture_size.x,
		HUB_ROOM_DISPLAY_SIZE.y / texture_size.y
	)
	sprite.position = HUB_ROOM_SOURCE_POS
	sprite.scale = Vector2(display_scale, display_scale)


func _input(event: InputEvent) -> void:
	if not GlobalInput.can_cancel():
		return

	if event.is_action_pressed("ui_cancel") or Input.is_key_pressed(KEY_ESCAPE):
		if overlay_root.get_child_count() > 0:
			_close_backpack_overlay()
		else:
			_return_to_main_menu()
		get_viewport().set_input_as_handled()
		return

	if GlobalInput.is_context(GlobalInput.Context.WORLD):
		if event.is_action_pressed("ui_accept") or Input.is_key_pressed(KEY_E):
			if current_zone == "gallery":
				_enter_gallery()
			else:
				_enter_current_route_node()


func _unhandled_input(event: InputEvent) -> void:
	if overlay_root.get_child_count() > 0:
		return
	if not GlobalInput.is_context(GlobalInput.Context.WORLD):
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if player and player.has_method("move_to_global_x"):
			player.move_to_global_x(event.position.x)
			get_viewport().set_input_as_handled()


func _enter_current_route_node() -> void:
	var rm = get_node_or_null("/root/RunManager")
	if rm:
		_enter_route_node(rm.current_route_index)


func _enter_route_node(index: int) -> void:
	var rm = get_node_or_null("/root/RunManager")
	if not rm or not rm.can_enter_route_node(index):
		print("[Hub] 节点未解锁，无法进入: ", index)
		return

	var node = rm.get_current_route_node()
	print("[Hub] 进入路线节点: ", node.get("id", ""))
	await _lock_briefly_before_transition()
	GlobalScene.transition_to(rm.get_current_node_scene_type())


func _lock_briefly_before_transition() -> void:
	GlobalInput.set_context(GlobalInput.Context.LOCKED)
	await get_tree().create_timer(0.1).timeout


func _on_battle_trigger_body_entered(_body) -> void:
	current_zone = "battle"
	show_speech_message("按 E 进入梦境")
	print("[Hub] 站在 [进入战斗] 区域。按 E 进入。")


func _on_shop_trigger_body_entered(_body) -> void:
	current_zone = "shop"
	show_speech_message("按 E 查看商店")
	print("[Hub] 站在 [梦境商店] 区域。按 E 进入。")


func _on_gallery_trigger_body_entered(_body) -> void:
	current_zone = "gallery"
	show_speech_message("按 E 查看图鉴")
	print("[Hub] 站在 [物品图鉴] 区域。按 E 进入。")


func _on_zone_body_exited(_body) -> void:
	current_zone = ""
	_hide_speech()
	print("[Hub] 离开区域")


func _on_main_menu_button_pressed() -> void:
	_return_to_main_menu()

func _on_route_button_pressed() -> void:
	_enter_current_route_node()

func _on_gallery_button_pressed() -> void:
	_enter_gallery()

func _on_settings_button_pressed() -> void:
	GlobalScene.transition_to(GlobalScene.SceneType.SETTINGS)


func _return_to_main_menu() -> void:
	GlobalScene.transition_to(GlobalScene.SceneType.MAIN_MENU, false)


func _enter_battle() -> void:
	_enter_current_route_node()


func _enter_shop() -> void:
	_enter_current_route_node()


func _enter_gallery() -> void:
	GlobalScene.transition_to(GlobalScene.SceneType.GALLERY)


func show_speech_message(message: String = "") -> void:
	if speech_bubble == null or speech_text == null:
		return
	speech_text.text = DEFAULT_SPEECH_TEXT if message.is_empty() else message
	speech_bubble.visible = true
	speech_text.visible = true


func hide_speech_message() -> void:
	_hide_speech()


func _hide_speech() -> void:
	if speech_bubble != null:
		speech_bubble.visible = false
	if speech_text != null:
		speech_text.visible = false


func _on_backpack_button_pressed() -> void:
	if overlay_root.get_child_count() > 0:
		_close_backpack_overlay()
	else:
		_open_backpack_overlay()


func _open_backpack_overlay() -> void:
	print("[Hub] 正在打开背包浮层...")
	GlobalInput.set_context(GlobalInput.Context.UI)
	var ui_scene = load("res://src/ui/main_game_ui.tscn")
	var overlay = ui_scene.instantiate()
	if overlay.has_method("configure_for_backpack_overlay"):
		overlay.configure_for_backpack_overlay(_close_backpack_overlay)
	overlay_root.add_child(overlay)


func _close_backpack_overlay() -> void:
	print("[Hub] 正在关闭背包浮层")
	for child in overlay_root.get_children():
		if child.has_method("_on_menu_button_pressed") and child.get("battle_manager") != null:
			var manager = child.get("battle_manager")
			if manager and manager.has_method("persist_backpack_to_run"):
				manager.persist_backpack_to_run()
		child.queue_free()
	GlobalInput.set_context(GlobalInput.Context.WORLD)

func _layout_scene() -> void:
	var viewport_size := get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		viewport_size = Vector2(1280.0, 720.0)
	if viewport_background != null:
		viewport_background.position = Vector2.ZERO
		viewport_background.size = viewport_size
	_layout_hub_art(viewport_size)
	_layout_player_and_floor(viewport_size)
	for button_name in OPTION_RECTS.keys():
		var button := get_node_or_null("CanvasLayer/%s" % button_name) as Control
		if button == null:
			continue
		var target := _source_rect_to_viewport(OPTION_RECTS[button_name])
		button.position = target.position
		button.size = target.size


func _layout_hub_art(viewport_size: Vector2) -> void:
	_art_scale = minf(
		viewport_size.x / HUB_SOURCE_SIZE.x,
		viewport_size.y / HUB_SOURCE_SIZE.y
	)
	var displayed_size := HUB_SOURCE_SIZE * _art_scale
	_art_origin = (viewport_size - displayed_size) * 0.5
	if hub_art != null:
		hub_art.position = _art_origin
		hub_art.scale = Vector2(_art_scale, _art_scale)


func _layout_player_and_floor(viewport_size: Vector2) -> void:
	var floor_y := _art_origin.y + PLAYER_FLOOR_SOURCE_Y * _art_scale
	if floor_body != null:
		floor_body.position = Vector2(viewport_size.x * 0.5, floor_y)
	if player == null:
		return

	var min_x := _art_origin.x + PLAYER_WALK_MIN_SOURCE_X * _art_scale
	var max_x := _art_origin.x + PLAYER_WALK_MAX_SOURCE_X * _art_scale
	if player.has_method("set_walk_bounds"):
		player.set_walk_bounds(min_x, max_x)

	if not _has_positioned_player:
		player.global_position = Vector2(
			_art_origin.x + PLAYER_START_SOURCE_X * _art_scale,
			floor_y - PLAYER_FLOOR_OFFSET
		)
		_has_positioned_player = true
	else:
		player.global_position.y = floor_y - PLAYER_FLOOR_OFFSET
		player.global_position.x = clampf(player.global_position.x, min_x, max_x)


func _source_rect_to_viewport(source_rect: Rect2) -> Rect2:
	return Rect2(
		_art_origin + source_rect.position * _art_scale,
		source_rect.size * _art_scale
	)
