@tool
extends Node2D

const DesignScaler = preload("res://src/ui/layout/ui_design_scaler.gd")
const HubLayoutMetrics = preload("res://src/ui/hub/hub_layout_metrics.gd")
const HubBattleController = preload("res://src/ui/hub/hub_battle_controller.gd")
const HubMerchantController = preload("res://src/ui/hub/hub_merchant_controller.gd")
const HubPlayerController = preload("res://src/ui/hub/hub_player_controller.gd")
const HubInteractionFlowController = preload("res://src/ui/hub/hub_interaction_flow_controller.gd")
const HubShopVisualControllerScript = preload("res://src/ui/hub/hub_shop_visual_controller.gd")
const HubDialogueBubbleControllerScript = preload("res://src/ui/hub/hub_dialogue_bubble_controller.gd")
const XIAOMI_TEXTURE_PATH := AssetPaths.XIAOMI_CAT
const HUB_PLUSH_TRANSITION_FRAME_PATHS := [
	"res://assets/ui/hub/plush_transition/plush_transition_01.png",
	"res://assets/ui/hub/plush_transition/plush_transition_02.png",
	"res://assets/ui/hub/plush_transition/plush_transition_03.png",
	"res://assets/ui/hub/plush_transition/plush_transition_04.png",
	"res://assets/ui/hub/plush_transition/plush_transition_05.png",
]

const BookPageNavigator = preload("res://src/ui/book/book_page_navigator.gd")

const PAGE_MAIN_MENU := BookPageNavigator.PAGE_MAIN_MENU
const HUB_SOURCE_SIZE := BookBackgroundConfig.DESIGN_SIZE
const DEFAULT_VIEWPORT_SIZE := BookBackgroundConfig.DESIGN_SIZE
const DREAMCATCHER_SWING_PIVOT_DISTANCE_RATIO: float = 0.82
const PLAYER_START_SOURCE_X := 548.0
const PLAYER_FLOOR_SOURCE_Y := 1000.0
const PLAYER_FLOOR_OFFSET := 64.0
const PLAYER_WALK_MIN_SOURCE_X := 410.0
const PLAYER_WALK_MAX_SOURCE_X := 1640.0
const AUTO_INTERACTION_ROUTE := HubInteractionFlowController.AUTO_INTERACTION_ROUTE
const AUTO_INTERACTION_GALLERY := HubInteractionFlowController.AUTO_INTERACTION_GALLERY
const AUTO_INTERACTION_MERCHANT := HubInteractionFlowController.AUTO_INTERACTION_MERCHANT
const LEFT_BOOKMARK_BUTTON_PATHS := [
	"CanvasLayer/DesignRoot/RouteButton",
	"CanvasLayer/DesignRoot/BackpackButton",
	"CanvasLayer/DesignRoot/GalleryButton",
	"CanvasLayer/DesignRoot/SettingsButton",
	"CanvasLayer/DesignRoot/MainMenuButton",
]
const HUB_LEFT_TAB_BUTTONS := {
	BookBackgroundConfig.PAGE_HUB: "RouteButton",
	BookBackgroundConfig.PAGE_BACKPACK: "BackpackButton",
	BookBackgroundConfig.PAGE_GALLERY: "GalleryButton",
	BookBackgroundConfig.PAGE_SETTINGS: "SettingsButton",
}
const HUB_LEFT_TAB_NODES := {
	BookBackgroundConfig.PAGE_HUB: "AlbumTab",
	BookBackgroundConfig.PAGE_BACKPACK: "BackpackTab",
	BookBackgroundConfig.PAGE_GALLERY: "GalleryTab",
	BookBackgroundConfig.PAGE_SETTINGS: "SettingsTab",
}
const HUB_BACK_TAB_BUTTON := "MainMenuButton"
const ROUTE_INTERACTION_SOURCE_X := 1326.0
const GALLERY_INTERACTION_SOURCE_X := 771.0
const HUB_BATTLE_LAYER_NAME := "BattleLayer"
const HUB_TO_BATTLE_FOCUS_ZOOM := 1.55
const HUB_TO_BATTLE_FOCUS_DURATION := 0.72
const HUB_TO_BATTLE_MIN_FOCUS_ZOOM := 1.05
const HUB_TO_BATTLE_BOARD_TARGET_UV := Vector2(0.24, 0.35)
const HUB_TO_BATTLE_BOARD_BOTTOM_LOCK_OFFSET := 0.0
const HUB_PLUSH_TRANSITION_TARGET_WIDTH_RATIO := 1.16
const HUB_PLUSH_TRANSITION_MIN_WIDTH := 180.0
const HUB_PLUSH_TRANSITION_MAX_WIDTH := 290.0
const HUB_PLUSH_TRANSITION_SCALE_MULTIPLIER := 1.8
const HUB_PLUSH_TRANSITION_UPWARD_BODY_RATIO := 0.75
const HUB_PLUSH_TRANSITION_BODY_BOTTOM_RATIO := 0.58
const HUB_PLUSH_TRANSITION_VERTICAL_GAP := 6.0
const HUB_PLUSH_TRANSITION_FALLBACK_DROP_DURATION := 0.62
const HUB_PLUSH_TRANSITION_FALLBACK_FRAME_TIME := 0.34
const INVALID_HUB_POINT := Vector2(1.0e20, 1.0e20)
const DEFAULT_SPEECH_TEXT := "你终于醒了！"
const SHOP_INTRO_FRAME_RATE := 60.0
const ENABLE_DEBUG_SHORTCUTS_IN_RELEASE := true
const XIAOMI_STORY_ACT := 1
const XIAOMI_ANCHOR_SOURCE_POSITION := Vector2(760.0, 1010.0)
const XIAOMI_SPRITE_OFFSET := Vector2(-70.5, -170.4)
const XIAOMI_SPRITE_SCALE := Vector2(0.8, 0.8)
func _first_existing_node(paths: Array[String]) -> Node:
	for path in paths:
		var node := get_node_or_null(path)
		if node != null:
			return node
	return null


@export var hub_art_source_offset := Vector2(0.0, -30.0):
	set(value):
		hub_art_source_offset = value
		if Engine.is_editor_hint() and is_node_ready():
			_layout_scene()

@onready var book_canvas_layer: CanvasLayer = $BookCanvasLayer
@onready var book_design_root: Control = $BookCanvasLayer/BookDesignRoot
@onready var book_background: Control = $BookCanvasLayer/BookDesignRoot/BookBackground
@onready var battle_disabled_bookmark_pins: Control = get_node_or_null("BookCanvasLayer/BookDesignRoot/BattleDisabledBookmarkPins") as Control
@onready var hub_art: Node2D = $HubArt
@onready var hub_board_viewport: Control = _first_existing_node(["HubArt/BoardViewport"]) as Control
@onready var hub_board_content: Node = _first_existing_node(["HubArt/BoardViewport/BoardContent", "HubArt"])
@onready var board_dimming_mask: ColorRect = _first_existing_node(["HubArt/BoardViewport/BoardContent/BoardDimmingMask", "HubArt/BoardDimmingMask"]) as ColorRect
@onready var canvas_design_root: Control = $CanvasLayer/DesignRoot
@onready var overlay_root: Control = $CanvasLayer/OverlayRoot
@onready var player: CharacterBody2D = $Player
@onready var floor_body: StaticBody2D = $Floor
@onready var interactions: Node2D = $Interactions
@onready var room_art: Sprite2D = _first_existing_node(["HubArt/BoardViewport/BoardContent/Room", "HubArt/Room"]) as Sprite2D
@onready var foreground_art: Sprite2D = _first_existing_node(["HubArt/BoardViewport/BoardContent/Foreground", "HubArt/Foreground"]) as Sprite2D
@onready var speech_bubble: Sprite2D = _first_existing_node(["HubArt/BoardViewport/BoardContent/SpeechBubble", "HubArt/SpeechBubble"]) as Sprite2D
@onready var speech_text: Label = _first_existing_node(["HubArt/BoardViewport/BoardContent/SpeechText", "HubArt/SpeechText"]) as Label
@onready var dreamcatcher_net: Sprite2D = _first_existing_node(["HubArt/BoardViewport/BoardContent/DreamcatcherNet", "HubArt/DreamcatcherNet"]) as Sprite2D
@onready var dreamcatcher_plush_transition: Sprite2D = _first_existing_node(["HubArt/BoardViewport/BoardContent/DreamcatcherPlushTransition", "HubArt/DreamcatcherPlushTransition"]) as Sprite2D
@onready var merchant_sprite: AnimatedSprite2D = _first_existing_node(["HubArt/BoardViewport/BoardContent/MerchantSprite", "HubArt/MerchantSprite"]) as AnimatedSprite2D
@onready var merchant_button: Button = $CanvasLayer/DesignRoot/MerchantButton
@onready var dreamcatcher_button: Button = $CanvasLayer/DesignRoot/DreamcatcherButton
@onready var book_page_navigator: Control = $CanvasLayer/BookPageNavigator
@onready var battle_layer: Control = get_node_or_null("CanvasLayer/" + HUB_BATTLE_LAYER_NAME) as Control

var current_zone: String = ""
var _book_origin: Vector2 = Vector2.ZERO
var _art_origin: Vector2 = Vector2.ZERO
var _art_scale: float = 1.0
var _has_positioned_player := false
var _default_room_texture: Texture2D = null
var _default_room_position := Vector2.ZERO
var _default_room_scale := Vector2.ONE
var _default_room_display_size := Vector2.ZERO
var _default_dreamcatcher_net_position := Vector2.ZERO
var _default_dreamcatcher_net_scale := Vector2.ONE
var _default_dreamcatcher_net_rotation := 0.0
var _default_dreamcatcher_net_offset := Vector2.ZERO
var _default_dreamcatcher_net_centered := true
var _dreamcatcher_button_source_position := Vector2.ZERO
var _dreamcatcher_button_source_size := Vector2.ZERO
var _hub_background_textures: Dictionary = {}
var _hub_foreground_textures: Dictionary = {}
var _hub_source_size := HUB_SOURCE_SIZE
var _hub_page_visual_root: Control = null
var _hub_transition_player_frozen := false
var _hub_transition_player_process_mode := Node.PROCESS_MODE_INHERIT
var _dreamcatcher_net_base_position := Vector2.ZERO
var _dreamcatcher_net_base_rotation := 0.0
var _dreamcatcher_net_base_offset := Vector2.ZERO
var _dreamcatcher_idle_tween: Tween = null
var _hub_to_battle_focus_tween: Tween = null
var _hub_to_battle_focus_token := 0
var _hub_plush_transition_max_frame_size := Vector2.ZERO
var _hub_plush_transition_play_token := 0
var _hub_battle_manager: BattleManager = null
var _is_hub_battle_session_active := false
var _hub_focus_layer_base_transforms: Dictionary = {}
var _shop_visual_overlay_canvas: CanvasLayer = null
var _is_shop_visual_state_active := false
var _is_shop_intro_sequence_running := false
var _shop_route_entry_token := 0
var _hub_dreamcatcher_swing_token := 0
var _shop_intro_overlay_token := 0
var _pending_merchant_shop_open := false
var _merchant_shop_sequence_running := false
var _story_book_return_transition_running := false
var _xiaomi_anchor: Node2D = null
var _story_bubble_controller: Control = null
var _battle_controller = HubBattleController.new()
var _merchant_controller = HubMerchantController.new()
var _player_controller = HubPlayerController.new()
var _interaction_flow_controller = HubInteractionFlowController.new()
var _shop_visual_controller = HubShopVisualControllerScript.new()
var _pending_auto_interaction: String:
	get:
		return _get_pending_auto_interaction()
	set(value):
		_set_pending_auto_interaction(value)


func _ready() -> void:
	_cache_layout_source_data()
	_capture_default_hub_room_art()
	_setup_battle_controller()
	_setup_merchant_controller()
	_setup_player_controller()
	_setup_interaction_flow_controller()
	_setup_hub_page_visual_root()
	if Engine.is_editor_hint():
		_sync_editor_preview_state()
		_layout_scene()
		return

	if battle_layer != null:
		battle_layer.visible = false
		battle_layer.z_index = 40
		if _has_node_property(battle_layer, "auto_initialize"):
			battle_layer.set("auto_initialize", false)

	print("[Hub] Entered dream route.")
	_hub_background_textures = AssetPaths.load_texture_map(AssetPaths.HUB_BACKGROUND_PATHS)
	_hub_foreground_textures = AssetPaths.load_texture_map(AssetPaths.HUB_FOREGROUND_PATHS)
	GlobalInput.set_context(GlobalInput.Context.WORLD)
	GlobalAudio.play_bgm(_get_stage_bgm_key("hub_bgm_key", "hub"))
	_hide_speech()

	var rm = _get_run_manager()
	if rm and rm.has_signal("route_changed"):
		var route_changed_callback := Callable(self, "_on_route_changed")
		if not rm.route_changed.is_connected(route_changed_callback):
			rm.route_changed.connect(route_changed_callback)
	_apply_stage_hub_background()
	_apply_hub_dreamcatcher_stage_visual()
	_configure_hub_dreamcatcher_swing_pivot()
	_capture_hub_dreamcatcher_pose()
	_sync_hub_plush_transition_pose()
	_reset_hub_plush_transition()

	if rm and rm.is_run_complete:
		GlobalScene.transition_to(GlobalScene.SceneType.MAIN_MENU, false)
		return

	if interactions:
		interactions.hide()
	if get_viewport():
		get_viewport().size_changed.connect(_layout_scene)
	_layout_scene()
	if book_background != null and book_background.has_method("set_active_page_id"):
		book_background.call("set_active_page_id", BookBackgroundConfig.PAGE_HUB)
	if book_page_navigator != null and book_page_navigator.has_method("configure"):
		book_page_navigator.configure(self)
	var should_play_story_return := _consume_story_book_return_transition_request()
	if should_play_story_return:
		should_play_story_return = _prepare_story_book_return_transition()
	_sync_xiaomi_anchor_for_current_act()
	if should_play_story_return:
		call_deferred("_play_story_book_return_transition")
	else:
		_try_play_pending_hub_story_on_ready()
	_update_merchant_state()
	_update_dreamcatcher_state()
	_start_hub_dreamcatcher_idle_swing()
	call_deferred("_apply_pending_hub_shortcut_request")


func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if not _is_book_hub_current():
		return
	_sync_merchant_presence_state()
	_try_start_pending_merchant_shop_sequence()


func _exit_tree() -> void:
	_stop_hub_dreamcatcher_idle_swing()
	_cancel_hub_to_battle_focus()
	_cancel_hub_plush_transition()


func _get_stage_bgm_key(key: String, fallback: String) -> String:
	var visual := _get_stage_visual()
	var bgm_key = str(visual.get(key, fallback))
	return bgm_key if bgm_key != "" else fallback


func _get_run_manager() -> Node:
	return get_node_or_null("/root/RunManager")


func _play_audio_sfx(sfx_key: String, pitch_range: float = 0.0) -> void:
	var audio = get_node_or_null("/root/GlobalAudio")
	if audio and audio.has_method("play_sfx"):
		audio.play_sfx(sfx_key, pitch_range)


func _get_item_database() -> Node:
	return get_node_or_null("/root/ItemDatabase")


func _get_ornament_database() -> Node:
	return get_node_or_null("/root/OrnamentDatabase")


func _get_stage_visual() -> Dictionary:
	var rm = _get_run_manager()
	if rm == null or not rm.has_method("get_current_stage_visual"):
		return {}
	var visual = rm.get_current_stage_visual()
	return Dictionary(visual).duplicate(true) if visual is Dictionary else {}


func _on_route_changed(_current_act: int, _route_index: int, _current_node: Dictionary) -> void:
	_apply_stage_hub_background()
	_apply_hub_dreamcatcher_stage_visual()
	_configure_hub_dreamcatcher_swing_pivot()
	_capture_hub_dreamcatcher_pose()
	_reset_hub_plush_transition()
	_layout_canvas_design_root()
	_sync_xiaomi_anchor_for_current_act()
	_update_dreamcatcher_state()
	_start_hub_dreamcatcher_idle_swing()
	_update_merchant_state()


func _capture_default_hub_room_art() -> void:
	if room_art == null or _default_room_texture != null:
		return
	_default_room_texture = room_art.texture
	_default_room_position = room_art.position
	_default_room_scale = room_art.scale
	if _default_room_texture != null:
		_default_room_display_size = _default_room_texture.get_size() * _default_room_scale


func _cache_layout_source_data() -> void:
	_hub_source_size = BookBackgroundConfig.DESIGN_SIZE
	if dreamcatcher_net != null:
		_default_dreamcatcher_net_position = dreamcatcher_net.position
		_default_dreamcatcher_net_scale = dreamcatcher_net.scale
		_default_dreamcatcher_net_rotation = dreamcatcher_net.rotation
		_default_dreamcatcher_net_offset = dreamcatcher_net.offset
		_default_dreamcatcher_net_centered = dreamcatcher_net.centered
	if dreamcatcher_button != null:
		_dreamcatcher_button_source_position = dreamcatcher_button.position
		_dreamcatcher_button_source_size = dreamcatcher_button.size


func _setup_battle_controller() -> void:
	if _battle_controller == null:
		_battle_controller = HubBattleController.new()
	_battle_controller.setup(dreamcatcher_button, self)

	var enter_callback := Callable(self, "_on_battle_controller_enter_requested")
	if not _battle_controller.request_enter_battle.is_connected(enter_callback):
		_battle_controller.request_enter_battle.connect(enter_callback)

	var restart_idle_callback := Callable(self, "_on_battle_controller_idle_restart_requested")
	if not _battle_controller.request_idle_restart.is_connected(restart_idle_callback):
		_battle_controller.request_idle_restart.connect(restart_idle_callback)


func _on_battle_controller_enter_requested() -> void:
	if _interaction_flow_controller != null:
		_interaction_flow_controller.mark_transitioning()
	_enter_current_route_node()


func _on_battle_controller_idle_restart_requested() -> void:
	_start_hub_dreamcatcher_idle_swing()


func _setup_merchant_controller() -> void:
	if _merchant_controller == null:
		_merchant_controller = HubMerchantController.new()
	_merchant_controller.setup(
		merchant_sprite,
		merchant_button,
		player,
		room_art,
		_default_room_position,
		Callable(self, "_source_rect_to_viewport"),
		Callable(self, "_get_player_collision_half_width")
	)
	_merchant_controller.set_layout_scale(_art_scale)

	var move_callback := Callable(self, "_on_merchant_move_requested")
	if not _merchant_controller.move_requested.is_connected(move_callback):
		_merchant_controller.move_requested.connect(move_callback)

	var open_shop_callback := Callable(self, "_on_merchant_open_shop_requested")
	if not _merchant_controller.request_open_shop.is_connected(open_shop_callback):
		_merchant_controller.request_open_shop.connect(open_shop_callback)


func _setup_player_controller() -> void:
	if _player_controller == null:
		_player_controller = HubPlayerController.new()
	_player_controller.setup(player)
	var target_reached_callback := Callable(self, "_on_player_move_target_reached")
	if not _player_controller.is_connected("target_reached", target_reached_callback):
		_player_controller.connect("target_reached", target_reached_callback)


func _setup_interaction_flow_controller() -> void:
	if _interaction_flow_controller == null:
		_interaction_flow_controller = HubInteractionFlowController.new()
	_interaction_flow_controller.setup(_player_controller, _merchant_controller, _battle_controller)

	var route_callback := Callable(self, "_on_interaction_flow_enter_route_node_requested")
	if not _interaction_flow_controller.is_connected("request_enter_route_node", route_callback):
		_interaction_flow_controller.connect("request_enter_route_node", route_callback)

	var gallery_callback := Callable(self, "_on_interaction_flow_open_gallery_requested")
	if not _interaction_flow_controller.is_connected("request_open_gallery", gallery_callback):
		_interaction_flow_controller.connect("request_open_gallery", gallery_callback)


func _on_interaction_flow_enter_route_node_requested() -> void:
	_enter_current_route_node()


func _on_interaction_flow_open_gallery_requested() -> void:
	_enter_gallery()


func _on_merchant_move_requested(target_x: float, should_open_shop: bool) -> void:
	_pending_merchant_shop_open = should_open_shop
	if should_open_shop and _interaction_flow_controller != null:
		_interaction_flow_controller.mark_idle()
	_queue_auto_interaction(AUTO_INTERACTION_MERCHANT, target_x)
	_try_start_pending_merchant_shop_sequence()


func _on_merchant_open_shop_requested() -> void:
	if _is_shop_visual_state_active or _is_shop_intro_sequence_running:
		return
	if _merchant_controller != null:
		_merchant_controller.shop_click_ready = false
	_pending_merchant_shop_open = false
	_merchant_shop_sequence_running = false
	_is_shop_intro_sequence_running = true
	if _interaction_flow_controller != null:
		_interaction_flow_controller.mark_transitioning()
	GlobalInput.set_context(GlobalInput.Context.LOCKED)
	_shop_intro_overlay_token += 1
	var overlay_token := _shop_intro_overlay_token
	var overlay_state := _play_shop_intro_overlay(true)
	if overlay_state is GDScriptFunctionState and overlay_state.is_valid():
		overlay_state.connect("completed", _on_shop_intro_overlay_completed.bind(overlay_token), Object.CONNECT_ONE_SHOT)
		return
	_on_shop_intro_overlay_completed(overlay_token, overlay_state)


func _on_shop_intro_overlay_completed(token: int, overlay_canvas: Variant = null, _result = null) -> void:
	if token != _shop_intro_overlay_token:
		return
	if overlay_canvas is CanvasLayer:
		_shop_visual_overlay_canvas = overlay_canvas
	else:
		_shop_visual_overlay_canvas = null
	_is_shop_intro_sequence_running = false
	_enter_shop_visual_state()


func _try_start_pending_merchant_shop_sequence() -> void:
	if not _pending_merchant_shop_open:
		return
	if _merchant_shop_sequence_running or _is_shop_visual_state_active or _is_shop_intro_sequence_running:
		return
	if _merchant_controller == null or not _merchant_controller.is_player_in_position(_get_run_manager()):
		return
	_merchant_shop_sequence_running = true
	_pending_merchant_shop_open = false
	_clear_pending_auto_interaction()
	if _player_controller != null and _player_controller.has_method("clear_move_target"):
		_player_controller.clear_move_target()
	_merchant_controller.is_player_at_merchant = true
	_merchant_controller.complete_interaction(_get_run_manager(), false, Callable(self, "_on_pending_merchant_shop_sequence_completed"))


func _on_pending_merchant_shop_sequence_completed() -> void:
	_merchant_shop_sequence_running = false


func _apply_stage_hub_background() -> void:
	var rm = _get_run_manager()
	if rm == null or not bool(rm.get("is_run_active")):
		_restore_default_hub_background()
		_update_merchant_state()
		return

	var visual := _get_stage_visual()
	var configured_path := str(visual.get("hub_background_path", ""))
	var background_key := _normalize_hub_background_key(str(visual.get("hub_background_key", "")))
	if configured_path == "" and background_key == "":
		_restore_default_hub_background()
		_update_merchant_state()
		return

	var background_texture := _get_hub_background_texture(visual, background_key)
	if room_art == null or background_texture == null:
		_restore_default_hub_background()
		_update_merchant_state()
		return
	room_art.texture = background_texture
	_fit_hub_room_sprite(room_art, background_texture)

	if foreground_art == null:
		_update_merchant_state()
		return
	var foreground_texture := _get_hub_foreground_texture(visual, background_key)
	foreground_art.texture = foreground_texture
	foreground_art.visible = foreground_texture != null
	if foreground_texture != null:
		_fit_hub_room_sprite(foreground_art, foreground_texture)
	_update_merchant_state()


func _normalize_hub_background_key(key: String) -> String:
	if _hub_background_textures.has(key):
		return key
	return ""


func _get_hub_background_texture(visual: Dictionary, background_key: String) -> Texture2D:
	var configured_path := str(visual.get("hub_background_path", ""))
	var configured_texture := _load_texture_from_path(configured_path)
	if configured_texture != null:
		return configured_texture
	if background_key == "":
		return null
	return _hub_background_textures.get(background_key, null) as Texture2D


func _get_hub_foreground_texture(visual: Dictionary, background_key: String) -> Texture2D:
	var configured_path := str(visual.get("hub_foreground_path", ""))
	var configured_texture := _load_texture_from_path(configured_path)
	if configured_texture != null:
		return configured_texture
	var foreground_key := _normalize_hub_background_key(str(visual.get("hub_foreground_key", background_key)))
	return _hub_foreground_textures.get(foreground_key, null) as Texture2D


func _restore_default_hub_background() -> void:
	if room_art != null and _default_room_texture != null:
		room_art.texture = _default_room_texture
		room_art.position = _default_room_position
		room_art.scale = _default_room_scale
	if foreground_art != null:
		foreground_art.texture = null
		foreground_art.visible = false


func _apply_hub_dreamcatcher_stage_visual() -> void:
	if dreamcatcher_net == null:
		return
	var visual := _get_stage_visual()
	var texture_path := str(visual.get("dreamcatcher_net_path", ""))
	if texture_path == "":
		return
	var texture := _load_texture_from_path(texture_path)
	if texture != null:
		dreamcatcher_net.texture = texture
	var configured_rect := _rect_from_variant(visual.get("hub_dreamcatcher_rect", visual.get("dreamcatcher_rect", null)))
	if configured_rect.size.x > 0.0 and configured_rect.size.y > 0.0:
		_apply_hub_dreamcatcher_source_rect(configured_rect, visual)
	else:
		_restore_default_hub_dreamcatcher_transform()


func _apply_hub_dreamcatcher_source_rect(source_rect: Rect2, visual: Dictionary) -> void:
	if dreamcatcher_net == null or dreamcatcher_net.texture == null:
		return
	var texture_size := dreamcatcher_net.texture.get_size()
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return
	var rotation_degrees := float(visual.get("hub_dreamcatcher_rotation_degrees", visual.get("dreamcatcher_rotation_degrees", 0.0)))
	dreamcatcher_net.centered = true
	dreamcatcher_net.offset = Vector2.ZERO
	dreamcatcher_net.rotation = deg_to_rad(rotation_degrees)
	dreamcatcher_net.scale = Vector2(source_rect.size.x / texture_size.x, source_rect.size.y / texture_size.y)
	dreamcatcher_net.position = source_rect.get_center()


func _restore_default_hub_dreamcatcher_transform() -> void:
	if dreamcatcher_net == null:
		return
	dreamcatcher_net.centered = _default_dreamcatcher_net_centered
	dreamcatcher_net.position = _default_dreamcatcher_net_position
	dreamcatcher_net.scale = _default_dreamcatcher_net_scale
	dreamcatcher_net.rotation = _default_dreamcatcher_net_rotation
	dreamcatcher_net.offset = _default_dreamcatcher_net_offset


func _rect_from_variant(value) -> Rect2:
	if value is Rect2:
		return value
	if value is Dictionary:
		var source := value as Dictionary
		var width = source.get("w", source.get("width", 0.0))
		var height = source.get("h", source.get("height", 0.0))
		return Rect2(
			Vector2(float(source.get("x", 0.0)), float(source.get("y", 0.0))),
			Vector2(float(width), float(height))
		)
	if value is Array:
		var values := value as Array
		if values.size() >= 4:
			return Rect2(Vector2(float(values[0]), float(values[1])), Vector2(float(values[2]), float(values[3])))
	return Rect2()


func _capture_hub_dreamcatcher_pose() -> void:
	if dreamcatcher_net == null:
		return
	_dreamcatcher_net_base_position = dreamcatcher_net.position
	_dreamcatcher_net_base_rotation = dreamcatcher_net.rotation
	_dreamcatcher_net_base_offset = dreamcatcher_net.offset


func _configure_hub_dreamcatcher_swing_pivot() -> void:
	if dreamcatcher_net == null or dreamcatcher_net.texture == null:
		return
	var texture_size := dreamcatcher_net.texture.get_size()
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return
	var visual_center := _get_hub_dreamcatcher_visual_center()
	var pivot_distance := texture_size.y * DREAMCATCHER_SWING_PIVOT_DISTANCE_RATIO
	dreamcatcher_net.centered = true
	dreamcatcher_net.offset = Vector2(0.0, pivot_distance)
	dreamcatcher_net.position = visual_center - _get_hub_dreamcatcher_scaled_offset().rotated(dreamcatcher_net.rotation)


func _get_hub_dreamcatcher_visual_center() -> Vector2:
	if dreamcatcher_net == null:
		return Vector2.ZERO
	return dreamcatcher_net.position + _get_hub_dreamcatcher_scaled_offset().rotated(dreamcatcher_net.rotation)


func _get_hub_dreamcatcher_scaled_offset() -> Vector2:
	if dreamcatcher_net == null:
		return Vector2.ZERO
	return Vector2(
		dreamcatcher_net.offset.x * dreamcatcher_net.scale.x,
		dreamcatcher_net.offset.y * dreamcatcher_net.scale.y
	)


func _get_hub_dreamcatcher_focus_global_position() -> Vector2:
	if dreamcatcher_net != null:
		return dreamcatcher_net.to_global(dreamcatcher_net.offset)
	if dreamcatcher_button != null:
		return dreamcatcher_button.get_global_rect().get_center()
	return INVALID_HUB_POINT


func _start_hub_dreamcatcher_idle_swing() -> void:
	if dreamcatcher_net == null or not is_inside_tree() or not _is_book_hub_current():
		return
	_stop_hub_dreamcatcher_idle_swing()
	dreamcatcher_net.position = _dreamcatcher_net_base_position
	dreamcatcher_net.rotation = _dreamcatcher_net_base_rotation
	dreamcatcher_net.offset = _dreamcatcher_net_base_offset
	_dreamcatcher_idle_tween = create_tween()
	_dreamcatcher_idle_tween.set_loops()
	_dreamcatcher_idle_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_dreamcatcher_idle_tween.tween_property(dreamcatcher_net, "rotation", _dreamcatcher_net_base_rotation - 0.026, 1.1)
	_dreamcatcher_idle_tween.tween_property(dreamcatcher_net, "rotation", _dreamcatcher_net_base_rotation + 0.026, 2.2)
	_dreamcatcher_idle_tween.tween_property(dreamcatcher_net, "rotation", _dreamcatcher_net_base_rotation, 1.1)


func _stop_hub_dreamcatcher_idle_swing() -> void:
	if _dreamcatcher_idle_tween != null:
		_dreamcatcher_idle_tween.kill()
		_dreamcatcher_idle_tween = null


func _play_hub_dreamcatcher_start_swing() -> void:
	if dreamcatcher_net == null or not is_inside_tree():
		return
	_stop_hub_dreamcatcher_idle_swing()
	dreamcatcher_net.position = _dreamcatcher_net_base_position
	dreamcatcher_net.rotation = _dreamcatcher_net_base_rotation
	dreamcatcher_net.offset = _dreamcatcher_net_base_offset
	_play_current_dreamcatcher_sfx()
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(dreamcatcher_net, "rotation", _dreamcatcher_net_base_rotation - 0.08, 0.14)
	tween.tween_property(dreamcatcher_net, "rotation", _dreamcatcher_net_base_rotation + 0.065, 0.18)
	tween.tween_property(dreamcatcher_net, "rotation", _dreamcatcher_net_base_rotation - 0.035, 0.14)
	tween.tween_property(dreamcatcher_net, "rotation", _dreamcatcher_net_base_rotation, 0.12)
	_hub_dreamcatcher_swing_token += 1
	var swing_token := _hub_dreamcatcher_swing_token
	tween.finished.connect(_on_hub_dreamcatcher_swing_finished.bind(swing_token), Object.CONNECT_ONE_SHOT)


func _on_hub_dreamcatcher_swing_finished(token: int, _result = null) -> void:
	if token != _hub_dreamcatcher_swing_token:
		return
	if dreamcatcher_net == null or not is_inside_tree():
		return
	dreamcatcher_net.position = _dreamcatcher_net_base_position
	dreamcatcher_net.rotation = _dreamcatcher_net_base_rotation
	dreamcatcher_net.offset = _dreamcatcher_net_base_offset

func _play_current_dreamcatcher_sfx() -> void:
	var visual := _get_stage_visual()
	var key := _get_dreamcatcher_sfx_key_from_path(str(visual.get("dreamcatcher_net_path", "")))
	if key != "":
		_play_audio_sfx(key)


func _get_dreamcatcher_sfx_key_from_path(path: String) -> String:
	var normalized := path.to_lower()
	if normalized.contains("uncle") or normalized.contains("act_2"):
		return "dreamcatcher_uncle"
	if normalized.contains("xiaomi") or normalized.contains("act_1"):
		return "dreamcatcher_xiaomi"
	return ""


func _ensure_hub_plush_transition_sprite() -> Sprite2D:
	if dreamcatcher_plush_transition != null and is_instance_valid(dreamcatcher_plush_transition):
		return dreamcatcher_plush_transition
	if hub_board_content == null:
		return null
	dreamcatcher_plush_transition = Sprite2D.new()
	dreamcatcher_plush_transition.name = "DreamcatcherPlushTransition"
	dreamcatcher_plush_transition.centered = true
	dreamcatcher_plush_transition.visible = false
	if dreamcatcher_net != null:
		dreamcatcher_plush_transition.z_index = dreamcatcher_net.z_index - 1
	hub_board_content.add_child(dreamcatcher_plush_transition)
	return dreamcatcher_plush_transition


func _get_hub_plush_transition_frame_texture(index: int) -> Texture2D:
	if index < 0 or index >= HUB_PLUSH_TRANSITION_FRAME_PATHS.size():
		return null
	return AssetPaths.load_texture(str(HUB_PLUSH_TRANSITION_FRAME_PATHS[index]))


func _get_hub_plush_transition_max_frame_size() -> Vector2:
	if _hub_plush_transition_max_frame_size.x > 0.0 and _hub_plush_transition_max_frame_size.y > 0.0:
		return _hub_plush_transition_max_frame_size
	var max_frame_size := Vector2.ZERO
	for path in HUB_PLUSH_TRANSITION_FRAME_PATHS:
		var texture := AssetPaths.load_texture(str(path))
		if texture == null:
			continue
		var texture_size := texture.get_size()
		max_frame_size.x = maxf(max_frame_size.x, texture_size.x)
		max_frame_size.y = maxf(max_frame_size.y, texture_size.y)
	_hub_plush_transition_max_frame_size = max_frame_size
	return _hub_plush_transition_max_frame_size


func _sync_hub_plush_transition_pose() -> void:
	var plush_sprite := _ensure_hub_plush_transition_sprite()
	if plush_sprite == null or dreamcatcher_net == null or dreamcatcher_net.texture == null:
		return
	var net_rect := _get_hub_dreamcatcher_visual_parent_rect()
	if net_rect.size.x <= 0.0 or net_rect.size.y <= 0.0:
		return
	var max_frame_size := _get_hub_plush_transition_max_frame_size()
	if max_frame_size.x <= 0.0 or max_frame_size.y <= 0.0:
		return
	var base_target_width := clampf(
		net_rect.size.x * HUB_PLUSH_TRANSITION_TARGET_WIDTH_RATIO,
		HUB_PLUSH_TRANSITION_MIN_WIDTH,
		HUB_PLUSH_TRANSITION_MAX_WIDTH
	)
	var target_width := base_target_width * HUB_PLUSH_TRANSITION_SCALE_MULTIPLIER
	var plush_scale := target_width / max_frame_size.x
	var base_plush_display_height := max_frame_size.y * (base_target_width / max_frame_size.x)
	var plush_display_height := max_frame_size.y * plush_scale
	var plush_top_y := net_rect.position.y + net_rect.size.y * HUB_PLUSH_TRANSITION_BODY_BOTTOM_RATIO + HUB_PLUSH_TRANSITION_VERTICAL_GAP
	plush_sprite.centered = true
	plush_sprite.position = Vector2(
		net_rect.position.x + net_rect.size.x * 0.5,
		plush_top_y + plush_display_height * 0.5 - base_plush_display_height * HUB_PLUSH_TRANSITION_UPWARD_BODY_RATIO
	)
	plush_sprite.scale = Vector2(plush_scale, plush_scale)
	plush_sprite.rotation = 0.0
	plush_sprite.z_index = dreamcatcher_net.z_index - 1


func _get_hub_dreamcatcher_visual_parent_rect() -> Rect2:
	if dreamcatcher_net == null or dreamcatcher_net.texture == null:
		return Rect2()
	var texture_size := dreamcatcher_net.texture.get_size()
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return Rect2()
	var visual_center := _get_hub_dreamcatcher_visual_center()
	var half_size := texture_size * 0.5
	var corners: Array[Vector2] = [
		Vector2(-half_size.x, -half_size.y),
		Vector2(half_size.x, -half_size.y),
		half_size,
		Vector2(-half_size.x, half_size.y),
	]
	var first_point := visual_center + Vector2(
		corners[0].x * dreamcatcher_net.scale.x,
		corners[0].y * dreamcatcher_net.scale.y
	).rotated(dreamcatcher_net.rotation)
	var rect := Rect2(first_point, Vector2.ZERO)
	for index in range(1, corners.size()):
		var corner: Vector2 = corners[index]
		var point := visual_center + Vector2(corner.x * dreamcatcher_net.scale.x, corner.y * dreamcatcher_net.scale.y).rotated(dreamcatcher_net.rotation)
		rect = rect.expand(point)
	return rect


func _reset_hub_plush_transition() -> void:
	_hub_plush_transition_play_token += 1
	var plush_sprite := _ensure_hub_plush_transition_sprite()
	if plush_sprite == null:
		return
	_sync_hub_plush_transition_pose()
	_clear_hub_plush_transition_sprite()


func _cancel_hub_plush_transition() -> void:
	_hub_plush_transition_play_token += 1
	_clear_hub_plush_transition_sprite()


func _clear_hub_plush_transition_sprite() -> void:
	var plush_sprite := dreamcatcher_plush_transition
	if plush_sprite == null or not is_instance_valid(plush_sprite):
		return
	plush_sprite.texture = null
	plush_sprite.modulate = Color.WHITE
	plush_sprite.visible = false


func _set_hub_plush_transition_frame(index: int) -> bool:
	var plush_sprite := _ensure_hub_plush_transition_sprite()
	var texture := _get_hub_plush_transition_frame_texture(index)
	if plush_sprite == null or texture == null:
		return false
	plush_sprite.texture = texture
	plush_sprite.visible = true
	return true


func _play_hub_plush_transition_with_battle_intro() -> void:
	var plush_sprite := _ensure_hub_plush_transition_sprite()
	if plush_sprite == null or HUB_PLUSH_TRANSITION_FRAME_PATHS.is_empty():
		return
	_hub_plush_transition_play_token += 1
	var play_token := _hub_plush_transition_play_token
	_sync_hub_plush_transition_pose()
	if not _set_hub_plush_transition_frame(0):
		return

	var drop_duration := _get_hub_battle_intro_float("intro_bag_drop_duration", HUB_PLUSH_TRANSITION_FALLBACK_DROP_DURATION)
	if drop_duration > 0.0:
		await get_tree().create_timer(drop_duration).timeout

	for index in range(1, HUB_PLUSH_TRANSITION_FRAME_PATHS.size()):
		if not _should_continue_hub_plush_transition(play_token):
			return
		var frame_time := _get_hub_battle_intro_float("intro_bag_frame_time", HUB_PLUSH_TRANSITION_FALLBACK_FRAME_TIME)
		if frame_time > 0.0:
			await get_tree().create_timer(frame_time).timeout
		if not _should_continue_hub_plush_transition(play_token):
			return
		_sync_hub_plush_transition_pose()
		if not _set_hub_plush_transition_frame(index):
			return


func _should_continue_hub_plush_transition(play_token: int) -> bool:
	return (
		play_token == _hub_plush_transition_play_token
		and is_inside_tree()
		and dreamcatcher_plush_transition != null
		and is_instance_valid(dreamcatcher_plush_transition)
	)


func _get_hub_battle_intro_float(property_name: String, fallback: float) -> float:
	if battle_layer != null and _has_node_property(battle_layer, property_name):
		return maxf(0.0, float(battle_layer.get(property_name)))
	return fallback


func _update_dreamcatcher_state() -> void:
	if _battle_controller != null:
		_battle_controller.update_state(_get_run_manager(), _is_book_hub_current())


func _is_dreamcatcher_game_available() -> bool:
	return _battle_controller != null and _battle_controller.can_enter_battle(_get_run_manager())


func _is_dreamcatcher_transition_pending() -> bool:
	return _battle_controller != null and _battle_controller.is_transition_pending()


func _update_merchant_state() -> void:
	if _merchant_controller == null:
		return
	_merchant_controller.update_state(_get_run_manager(), _is_book_hub_current())
	_layout_merchant()
	_sync_merchant_presence_state()


func _should_show_merchant() -> bool:
	return _merchant_controller != null and _merchant_controller.should_show(_get_run_manager())


func _is_merchant_shop_available() -> bool:
	return _merchant_controller != null and _merchant_controller.can_open_shop(_get_run_manager())


func _layout_merchant() -> void:
	if _merchant_controller == null:
		return
	_merchant_controller.set_layout_scale(_art_scale)
	_merchant_controller.layout(hub_art_source_offset)


func _sync_merchant_presence_state() -> void:
	if _merchant_controller == null:
		return
	_merchant_controller.sync_presence_state(_get_run_manager(), _get_pending_auto_interaction(), AUTO_INTERACTION_MERCHANT)


func _merchant_interaction_contains_x(global_x: float) -> bool:
	return _merchant_controller != null and _merchant_controller.interaction_contains_x(global_x)


func _get_pending_auto_interaction() -> String:
	if _interaction_flow_controller == null:
		return ""
	return str(_interaction_flow_controller.get_pending_auto_interaction())


func _has_pending_auto_interaction() -> bool:
	return _interaction_flow_controller != null and _interaction_flow_controller.has_pending_auto_interaction()


func _clear_pending_auto_interaction() -> void:
	if _interaction_flow_controller != null:
		_interaction_flow_controller.clear_pending_auto_interaction()


func _set_pending_auto_interaction(value: String) -> void:
	if _player_controller == null:
		return
	_player_controller.pending_auto_interaction = value


func _request_player_manual_move(target_x: float) -> bool:
	if _interaction_flow_controller == null:
		return false
	return _interaction_flow_controller.request_manual_move(target_x) == true


func _get_player_collision_half_width() -> float:
	if player == null:
		return 0.0
	var collision_shape := player.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision_shape == null:
		return 0.0
	var rectangle_shape := collision_shape.shape as RectangleShape2D
	if rectangle_shape == null:
		return 0.0
	return rectangle_shape.size.x * absf(collision_shape.scale.x) * 0.5


func _load_texture_from_path(path: String) -> Texture2D:
	if path == "" or not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D


func _sync_editor_preview_state() -> void:
	if book_canvas_layer != null:
		book_canvas_layer.visible = true
	if hub_art != null:
		hub_art.visible = true
	if canvas_design_root != null:
		canvas_design_root.visible = true
	if player != null:
		player.visible = true
	if floor_body != null:
		floor_body.visible = true
	if interactions != null:
		interactions.visible = false
	if book_page_navigator != null:
		book_page_navigator.visible = false
	if speech_bubble != null:
		speech_bubble.visible = false
	if speech_text != null:
		speech_text.visible = false
	if foreground_art != null and foreground_art.texture == null:
		foreground_art.visible = false
	if merchant_sprite != null:
		merchant_sprite.visible = false
	if merchant_button != null:
		merchant_button.visible = false
	if canvas_design_root != null:
		var main_menu_button := canvas_design_root.get_node_or_null(HUB_BACK_TAB_BUTTON) as Control
		if main_menu_button != null:
			main_menu_button.visible = true


func _fit_hub_room_sprite(sprite: Sprite2D, texture: Texture2D) -> void:
	var texture_size := texture.get_size()
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return
	var display_size := _default_room_display_size
	if display_size.x <= 0.0 or display_size.y <= 0.0:
		display_size = texture_size
	var display_scale := minf(
		display_size.x / texture_size.x,
		display_size.y / texture_size.y
	)
	sprite.position = _default_room_position
	sprite.scale = Vector2(display_scale, display_scale)


func _input(event: InputEvent) -> void:
	if Engine.is_editor_hint():
		return
	if _is_shop_visual_state_active:
		if event.is_action_pressed("ui_cancel") or Input.is_key_pressed(KEY_ESCAPE):
			_close_shop_visual_state()
			get_viewport().set_input_as_handled()
		return
	if not GlobalInput.can_cancel():
		return
	if _is_hub_battle_session_active:
		return
	if _handle_hub_debug_shortcuts(event):
		get_viewport().set_input_as_handled()
		return

	if not _is_book_hub_current():
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			if _activate_book_page_tab_at_position(event.position):
				get_viewport().set_input_as_handled()
				return
		if event.is_action_pressed("ui_cancel") or Input.is_key_pressed(KEY_ESCAPE):
			_open_book_page(BookPageNavigator.PAGE_HUB)
			get_viewport().set_input_as_handled()
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if _activate_left_bookmark_at_position(event.position):
			get_viewport().set_input_as_handled()
			return

	if event.is_action_pressed("ui_cancel") or Input.is_key_pressed(KEY_ESCAPE):
		if _has_overlay_backpack_content():
			_close_backpack_overlay_with_transition()
		else:
			_return_to_main_menu()
		get_viewport().set_input_as_handled()
		return

	if GlobalInput.is_context(GlobalInput.Context.WORLD):
		if _is_next_route_node_shortcut(event):
			if _advance_to_next_route_node_by_shortcut():
				get_viewport().set_input_as_handled()
			return
		if _is_route_advance_shortcut(event):
			if _advance_current_route_by_shortcut():
				get_viewport().set_input_as_handled()
			return
		if event.is_action_pressed("ui_accept") or Input.is_key_pressed(KEY_E):
			get_viewport().set_input_as_handled()


func _handle_hub_debug_shortcuts(event: InputEvent) -> bool:
	if not _is_debug_shortcut_enabled():
		return false
	var debug_act := _debug_shortcut_act_from_event(event)
	if debug_act > 0:
		return _debug_jump_to_act(debug_act)

	if not (event is InputEventKey):
		return false
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return false
	var keycode := key_event.keycode if key_event.keycode != 0 else key_event.physical_keycode
	match keycode:
		KEY_F7:
			_open_book_page(BookPageNavigator.PAGE_BACKPACK)
			return true
		KEY_F8:
			_open_book_page(BookPageNavigator.PAGE_GALLERY)
			return true
		KEY_F9:
			_open_book_page(BookPageNavigator.PAGE_SETTINGS)
			return true
		KEY_F11:
			_transition_from_hub(GlobalScene.SceneType.DEBUG, true)
			return true
	return false


func _is_debug_shortcut_enabled() -> bool:
	return OS.is_debug_build() or ENABLE_DEBUG_SHORTCUTS_IN_RELEASE


func _debug_shortcut_act_from_event(event: InputEvent) -> int:
	if not (event is InputEventKey):
		return 0
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return 0
	var shortcut_key := key_event.keycode
	if shortcut_key == 0:
		shortcut_key = key_event.physical_keycode
	match shortcut_key:
		KEY_F1:
			return 1
		KEY_F2:
			return 2
		KEY_F3:
			return 3
		KEY_F4:
			return 4
		KEY_F5:
			return 5
		KEY_F6:
			return 6
	return 0


func _debug_jump_to_act(act: int) -> bool:
	var rm = _get_run_manager()
	if rm == null or not rm.has_method("start_new_run"):
		push_warning("[Hub Debug] RunManager is missing; cannot jump to target act.")
		return false
	var target_act := clampi(act, 1, StageConfig.get_max_act())
	rm.start_new_run()
	rm.current_act = target_act
	rm.current_route_id = StageConfig.get_route_id_for_act(target_act, RouteConfig.DEFAULT_ROUTE_ID)
	rm.current_route_index = 0
	rm.completed_route_nodes = [] as Array[int]
	rm.is_run_active = true
	rm.is_run_complete = false
	if rm.has_method("save_current_state"):
		rm.save_current_state()
	if rm.has_method("_emit_route_changed"):
		rm._emit_route_changed()
	if target_act > 1:
		_suppress_story_for_debug_jump(target_act)
	_clear_pending_auto_interaction()
	_close_backpack_overlay()
	_open_book_page(BookPageNavigator.PAGE_HUB)
	print("[Hub Debug] Jumped to act ", target_act, ".")
	return true


func _suppress_story_for_debug_jump(target_act: int) -> void:
	var story_manager := get_node_or_null("/root/StoryManager")
	if story_manager != null and story_manager.has_method("suppress_debug_jump_story"):
		story_manager.call("suppress_debug_jump_story", target_act)


func _is_next_route_node_shortcut(event: InputEvent) -> bool:
	if not (event is InputEventKey):
		return false
	var key_event := event as InputEventKey
	return key_event.pressed and not key_event.echo and (key_event.keycode == KEY_F10 or key_event.physical_keycode == KEY_F10)


func _apply_pending_hub_shortcut_request() -> void:
	var rm = _get_run_manager()
	if rm == null:
		return
	var requested_page_id := str(rm.get("debug_hub_page_request"))
	var should_advance_next_node := bool(rm.get("debug_hub_advance_next_node_request"))
	rm.debug_hub_page_request = ""
	rm.debug_hub_advance_next_node_request = false
	if should_advance_next_node:
		_advance_to_next_route_node_by_shortcut()
		return
	if requested_page_id != "":
		_open_book_page(requested_page_id)


func _is_route_advance_shortcut(event: InputEvent) -> bool:
	if not (event is InputEventKey):
		return false
	var key_event := event as InputEventKey
	return key_event.pressed and not key_event.echo and (key_event.keycode == KEY_Z or key_event.physical_keycode == KEY_Z)


func _advance_to_next_route_node_by_shortcut() -> bool:
	if _has_pending_auto_interaction() or _is_dreamcatcher_transition_pending():
		return false
	var rm = _get_run_manager()
	if rm == null or not bool(rm.get("is_run_active")):
		return false
	if rm.has_method("can_enter_current_route_node"):
		if not rm.can_enter_current_route_node():
			return false
	elif not rm.has_method("can_enter_route_node") or not rm.can_enter_route_node(int(rm.get("current_route_index"))):
		return false
	if not rm.has_method("advance_route_node"):
		return false
	var skipped_node: Dictionary = rm.advance_route_node()
	if skipped_node.is_empty():
		return false
	print("[Hub Debug] Advanced to next route node by shortcut. skipped=", skipped_node.get("id", ""))
	if bool(rm.get("is_run_active")) and rm.has_method("can_enter_current_route_node") and rm.can_enter_current_route_node():
		_enter_current_route_node()
	return true


func _advance_current_route_by_shortcut() -> bool:
	if _has_pending_auto_interaction() or _is_dreamcatcher_transition_pending():
		return false
	var rm = _get_run_manager()
	if rm == null or not bool(rm.get("is_run_active")):
		return false
	if rm.has_method("can_enter_current_route_node"):
		if not rm.can_enter_current_route_node():
			return false
	elif not rm.has_method("can_enter_route_node") or not rm.can_enter_route_node(int(rm.get("current_route_index"))):
		return false

	var node_type: String = rm.get_current_route_node_type() if rm.has_method("get_current_route_node_type") else ""
	if RouteConfig.is_battle_node_type(node_type):
		_on_dreamcatcher_button_pressed()
		return true
	if node_type == RouteConfig.NODE_SHOP:
		_enter_current_route_node()
		return true
	return false


func _unhandled_input(event: InputEvent) -> void:
	if Engine.is_editor_hint():
		return
	if _is_hub_battle_session_active:
		return
	if not _is_book_hub_current():
		return
	if _has_overlay_backpack_content():
		return
	if not GlobalInput.is_context(GlobalInput.Context.WORLD):
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if _activate_left_bookmark_at_position(event.position):
			get_viewport().set_input_as_handled()
			return
		if _activate_hub_dreamcatcher_at_position(event.position):
			get_viewport().set_input_as_handled()
			return
		if _request_player_manual_move(event.position.x):
			get_viewport().set_input_as_handled()


func _is_point_on_left_bookmark(point: Vector2) -> bool:
	return _get_left_bookmark_page_at_position(point) != ""


func _activate_left_bookmark_at_position(point: Vector2) -> bool:
	var page_id := _get_left_bookmark_page_at_position(point)
	if page_id == "":
		return false
	if page_id == PAGE_MAIN_MENU:
		_return_to_main_menu()
	else:
		_open_book_page(page_id)
	return true


func _activate_book_page_tab_at_position(point: Vector2) -> bool:
	if book_page_navigator == null or not book_page_navigator.has_method("activate_tab_at_position"):
		return false
	return bool(book_page_navigator.call("activate_tab_at_position", point))


func _activate_hub_dreamcatcher_at_position(point: Vector2) -> bool:
	if _is_dreamcatcher_transition_pending() or not _is_dreamcatcher_game_available():
		return false
	if not _is_point_on_hub_dreamcatcher(point):
		return false
	_on_dreamcatcher_button_pressed()
	return true


func _is_point_on_hub_dreamcatcher(point: Vector2) -> bool:
	var visual_rect := _get_hub_dreamcatcher_global_rect()
	if visual_rect.size.x > 1.0 and visual_rect.size.y > 1.0:
		return visual_rect.has_point(point)
	if dreamcatcher_button == null or not dreamcatcher_button.visible:
		return false
	return dreamcatcher_button.get_global_rect().has_point(point)


func _get_hub_dreamcatcher_global_rect() -> Rect2:
	if dreamcatcher_net == null or not dreamcatcher_net.visible:
		return Rect2()
	return _get_sprite_global_rect(dreamcatcher_net)


func _get_sprite_global_rect(sprite: Sprite2D) -> Rect2:
	if sprite == null or sprite.texture == null:
		return Rect2()
	var local_rect := sprite.get_rect()
	var sprite_transform := sprite.get_global_transform()
	return _get_aabb_from_points([
		sprite_transform * local_rect.position,
		sprite_transform * Vector2(local_rect.end.x, local_rect.position.y),
		sprite_transform * local_rect.end,
		sprite_transform * Vector2(local_rect.position.x, local_rect.end.y),
	])


func _get_aabb_from_points(points: Array) -> Rect2:
	if points.is_empty():
		return Rect2()
	var min_position: Vector2 = points[0]
	var max_position: Vector2 = points[0]
	for point: Vector2 in points:
		min_position.x = minf(min_position.x, point.x)
		min_position.y = minf(min_position.y, point.y)
		max_position.x = maxf(max_position.x, point.x)
		max_position.y = maxf(max_position.y, point.y)
	return Rect2(min_position, max_position - min_position)


func _get_left_bookmark_page_at_position(point: Vector2) -> String:
	if _is_book_background_child_hit("BackTab", point):
		return PAGE_MAIN_MENU
	for page_id in HUB_LEFT_TAB_NODES.keys():
		var tab_node_name := str(HUB_LEFT_TAB_NODES[page_id])
		if _is_book_background_child_hit(tab_node_name, point):
			return str(page_id)
	if canvas_design_root == null:
		return ""
	var main_menu_button := canvas_design_root.get_node_or_null(HUB_BACK_TAB_BUTTON) as Button
	if _is_bookmark_button_hit(main_menu_button, point):
		return PAGE_MAIN_MENU
	for page_id in HUB_LEFT_TAB_BUTTONS.keys():
		var button := canvas_design_root.get_node_or_null(str(HUB_LEFT_TAB_BUTTONS[page_id])) as Button
		if _is_bookmark_button_hit(button, point):
			return str(page_id)
	return ""


func _is_book_background_child_hit(child_name: String, point: Vector2) -> bool:
	if book_background == null or child_name == "":
		return false
	var child := book_background.get_node_or_null(child_name) as Control
	if child == null or not child.visible:
		return false
	return child.get_global_rect().has_point(point)


func _is_bookmark_button_hit(button: Button, point: Vector2) -> bool:
	if button == null or not button.visible or button.disabled:
		return false
	return button.get_global_rect().has_point(point)


func _queue_auto_interaction(interaction: String, target_x: float) -> void:
	if _interaction_flow_controller != null:
		_interaction_flow_controller.queue_auto_interaction(interaction, target_x)


func _on_player_move_target_reached(interaction: String, target_x: float) -> void:
	if _interaction_flow_controller == null:
		return
	_interaction_flow_controller.complete_player_arrival(
		interaction,
		target_x,
		_get_run_manager(),
		merchant_sprite,
		Callable(self, "_merchant_interaction_contains_x")
	)


func _get_merchant_interaction_target_x() -> float:
	if _merchant_controller == null:
		return 0.0
	return _merchant_controller.get_interaction_target_x()


func _source_x_to_viewport(source_x: float) -> float:
	return _source_rect_to_viewport(Rect2(Vector2(source_x, 0.0), Vector2.ZERO)).position.x


func _enter_current_route_node(use_scene_transition: bool = true) -> void:
	var rm = _get_run_manager()
	if rm:
		_enter_route_node(rm.current_route_index, use_scene_transition)


func _enter_route_node(index: int, use_scene_transition: bool = true) -> void:
	var rm = _get_run_manager()
	if not rm or not rm.can_enter_route_node(index):
		print("[Hub] 节点未解锁，无法进入: ", index)
		return

	var node = rm.get_current_route_node()
	print("[Hub] 进入路线节点: ", node.get("id", ""))
	_lock_before_transition()

	# 获取点击的位置作为缩放中心（捕梦网）
	var dreamcatcher_uv := Vector2(0.5, 0.5)
	var dreamcatcher_focus := _get_hub_dreamcatcher_focus_global_position()
	if _is_valid_hub_point(dreamcatcher_focus):
		var focus_viewport_size = get_viewport_rect().size
		dreamcatcher_uv = dreamcatcher_focus / focus_viewport_size

	var end_focus := Vector2(0.32, 0.36)
	var battle_focus_target := _get_hub_to_battle_board_target_global_position()
	if _is_valid_hub_point(battle_focus_target):
		var target_viewport_size = get_viewport_rect().size
		end_focus = battle_focus_target / target_viewport_size

	var target_scene: int = rm.get_current_node_scene_type()
	var route_node_type: String = str(rm.get_current_route_node_type()) if rm.has_method("get_current_route_node_type") else ""
	var is_battle_route: bool = target_scene == GlobalScene.SceneType.BATTLE or RouteConfig.is_battle_node_type(route_node_type)
	var is_shop_route: bool = target_scene == GlobalScene.SceneType.SHOP or route_node_type == RouteConfig.NODE_SHOP
	var target_scene_name: String = str(target_scene)
	if target_scene >= 0 and target_scene < GlobalScene.SceneType.keys().size():
		target_scene_name = str(GlobalScene.SceneType.keys()[target_scene])
	print(
		"[Hub] Entering route node. target_scene=", target_scene_name,
		", route_node_type=", route_node_type,
		", is_battle_route=", is_battle_route,
		", rm_can_enter=", rm.can_enter_route_node(index)
	)
	if is_battle_route:
		print("[Hub] Battle node: starting battle inside hub scene without scene transition.")
		_start_hub_to_battle_focus(dreamcatcher_uv, end_focus)
	elif is_shop_route:
		print("[Hub] Shop node: starting shop visual inside hub scene.")
		_enter_current_shop_route_visual()
	else:
		print("[Hub] Non-battle node: fallback to SceneManager transition.")
		if use_scene_transition:
			GlobalScene.transition_with_zoom(target_scene, dreamcatcher_uv, end_focus)
		else:
			GlobalScene.transition_to_direct(target_scene)


func _enter_current_shop_route_visual() -> void:
	if _is_shop_visual_state_active or _is_shop_intro_sequence_running:
		return
	_clear_pending_auto_interaction()
	_shop_route_entry_token += 1
	var route_token := _shop_route_entry_token
	if _merchant_controller != null:
		_update_merchant_state()
		_merchant_controller.is_player_at_merchant = true
		_merchant_controller.shop_click_ready = false
		var played_arrival := _merchant_controller.play_arrival_animation()
		if played_arrival and merchant_sprite != null and merchant_sprite.is_playing():
			merchant_sprite.animation_finished.connect(_on_shop_route_entered_animation_finished.bind(route_token), Object.CONNECT_ONE_SHOT)
			return
	_on_shop_route_entered_animation_finished(route_token)


func _on_shop_route_entered_animation_finished(token: int, _result = null) -> void:
	if token != _shop_route_entry_token:
		return
	_on_merchant_open_shop_requested()


func _enter_shop_visual_state() -> void:
	_is_shop_visual_state_active = true
	current_zone = "shop"
	if _interaction_flow_controller != null:
		_interaction_flow_controller.mark_idle()
	_play_audio_sfx("shop_hand")
	GlobalInput.set_context(GlobalInput.Context.UI)


func _close_shop_visual_state() -> void:
	_is_shop_visual_state_active = false
	_is_shop_intro_sequence_running = false
	_pending_merchant_shop_open = false
	_merchant_shop_sequence_running = false
	current_zone = ""
	if _shop_visual_controller != null:
		_shop_visual_controller.close()
	_shop_visual_overlay_canvas = null
	_complete_current_shop_route_node()
	if _interaction_flow_controller != null:
		_interaction_flow_controller.mark_idle()
	GlobalInput.set_context(GlobalInput.Context.WORLD)
	_try_play_pending_hub_story_on_ready()


func _play_shop_intro_overlay(keep_final_frame: bool = false):
	_play_audio_sfx("shop_emerge")
	return await _shop_visual_controller.play_intro_overlay(
		self,
		_get_run_manager(),
		_get_item_database(),
		_get_ornament_database(),
		keep_final_frame,
		SHOP_INTRO_FRAME_RATE,
		Callable(self, "_close_shop_visual_state")
	)


func _complete_current_shop_route_node() -> void:
	var rm = _get_run_manager()
	if rm == null or not rm.has_method("get_current_route_node_type") or not rm.has_method("advance_route_node"):
		return
	if str(rm.get_current_route_node_type()) != RouteConfig.NODE_SHOP:
		return
	rm.advance_route_node()


func _open_hub_battle_session() -> void:
	if battle_layer == null:
		push_warning("[Hub] BattleLayer is missing; cannot start battle inside hub.")
		_return_dreamcatcher_to_ready_state()
		return

	if _is_hub_battle_session_active:
		battle_layer.visible = true
		return

	_clear_overlay_children(true)
	if battle_layer.has_method("use_hub_dreamcatcher"):
		battle_layer.call("use_hub_dreamcatcher", dreamcatcher_net, dreamcatcher_button)
	_set_hub_chrome_visible_for_battle(false)

	if _has_node_property(battle_layer, "auto_initialize"):
		battle_layer.set("auto_initialize", false)

	var battle_manager := BattleManager.new()
	_remove_hub_battle_runtime_children()
	battle_layer.add_child(battle_manager)
	_hub_battle_manager = battle_manager
	battle_layer.z_index = 40
	battle_layer.visible = true
	_is_hub_battle_session_active = true

	if battle_layer.has_method("setup"):
		battle_layer.call("setup", battle_manager, Callable(self, "_on_hub_battle_session_closed"))
	var story_manager := get_node_or_null("/root/StoryManager")
	if story_manager != null and story_manager.has_method("play_current_battle_intro"):
		story_manager.play_current_battle_intro()
	else:
		push_warning("[Hub] BattleLayer does not expose setup().")
		_cleanup_hub_battle_session()
		_return_dreamcatcher_to_ready_state()


func _on_hub_battle_session_closed(target_scene: int) -> void:
	var next_scene = target_scene
	if next_scene == -1:
		next_scene = GlobalScene.SceneType.HUB

	_cleanup_hub_battle_session()
	_return_dreamcatcher_to_ready_state()

	if next_scene == GlobalScene.SceneType.MAIN_MENU:
		if _story_manager_has_pending_hub_sequences():
			_layout_scene()
			_try_play_pending_hub_story_on_ready()
			return
		_transition_from_hub(next_scene, false)
		return

	_layout_scene()
	_try_play_pending_hub_story_on_ready()


func _cleanup_hub_battle_session(do_persist_backpack: bool = true) -> void:
	if _hub_battle_manager != null and is_instance_valid(_hub_battle_manager):
		if do_persist_backpack and _hub_battle_manager.has_method("persist_backpack_to_run"):
			_hub_battle_manager.persist_backpack_to_run()
		_hub_battle_manager.queue_free()
	_hub_battle_manager = null
	_remove_hub_battle_runtime_children()
	_is_hub_battle_session_active = false
	_set_board_dimming_mask_visible(false)
	if battle_layer != null:
		battle_layer.visible = false


func _remove_hub_battle_runtime_children() -> void:
	if battle_layer == null or not is_instance_valid(battle_layer):
		return
	for child in battle_layer.get_children():
		if child.name != "ContentLayer":
			child.queue_free()


func _set_hub_chrome_visible_for_battle(chrome_visible: bool) -> void:
	_set_battle_disabled_bookmark_pins_visible(not chrome_visible)
	_set_board_dimming_mask_visible(not chrome_visible)
	if canvas_design_root != null:
		canvas_design_root.visible = chrome_visible
	if player != null:
		player.visible = chrome_visible
		if not chrome_visible and player.has_method("clear_move_target"):
			player.clear_move_target()
	if floor_body != null:
		floor_body.visible = chrome_visible
	if merchant_button != null:
		merchant_button.visible = chrome_visible and _should_show_merchant()
	if chrome_visible:
		_restore_hub_focus_layer_base_transforms()
		_reset_hub_plush_transition()
		_layout_scene()
		_update_merchant_state()
		_update_dreamcatcher_state()
		_start_hub_dreamcatcher_idle_swing()
	else:
		_clear_pending_auto_interaction()
		_stop_hub_dreamcatcher_idle_swing()
		_update_dreamcatcher_state()


func _set_battle_disabled_bookmark_pins_visible(pins_visible: bool) -> void:
	if battle_disabled_bookmark_pins != null:
		battle_disabled_bookmark_pins.visible = pins_visible


func _set_board_dimming_mask_visible(mask_visible: bool) -> void:
	if board_dimming_mask != null:
		board_dimming_mask.visible = mask_visible


func _return_dreamcatcher_to_ready_state() -> void:
	if _battle_controller != null:
		_battle_controller.return_to_ready_state(_get_run_manager(), _is_book_hub_current())
	if _interaction_flow_controller != null:
		_interaction_flow_controller.mark_idle()
	GlobalInput.set_context(GlobalInput.Context.WORLD)
	_set_hub_chrome_visible_for_battle(true)


func _has_overlay_backpack_content() -> bool:
	if overlay_root == null:
		return false
	return overlay_root.get_child_count() > 0


func _has_node_property(node: Object, property_name: String) -> bool:
	for property in node.get_property_list():
		if str(property.get("name", "")) == property_name:
			return true
	return false


func _clear_overlay_children(do_persist_backpack: bool = true) -> void:
	if overlay_root == null:
		return
	for child in overlay_root.get_children():
		if do_persist_backpack:
			var manager = child.get("battle_manager")
			if manager != null and manager.has_method("persist_backpack_to_run"):
				manager.persist_backpack_to_run()
		child.queue_free()


func _start_hub_to_battle_focus(start_focus_uv: Vector2, end_focus_uv: Vector2, duration: float = HUB_TO_BATTLE_FOCUS_DURATION) -> void:
	var play_token := _begin_hub_to_battle_focus(start_focus_uv, end_focus_uv, duration)
	if play_token == 0:
		return
	if _hub_to_battle_focus_tween == null:
		_complete_hub_to_battle_focus(play_token)
		return
	_hub_to_battle_focus_tween.finished.connect(_complete_hub_to_battle_focus.bind(play_token), CONNECT_ONE_SHOT)


func _begin_hub_to_battle_focus(start_focus_uv: Vector2, end_focus_uv: Vector2, duration: float = HUB_TO_BATTLE_FOCUS_DURATION) -> int:
	if Engine.is_editor_hint() or not is_inside_tree():
		return 0
	_cancel_hub_to_battle_focus()
	_hub_to_battle_focus_token += 1
	var play_token := _hub_to_battle_focus_token
	_stop_hub_dreamcatcher_idle_swing()
	var viewport_size := _validated_layout_viewport_size(get_viewport_rect().size)
	var start_focus := start_focus_uv * viewport_size
	var end_focus := end_focus_uv * viewport_size
	var focus_nodes := _get_hub_to_battle_focus_layers()
	var focus_scale := _get_hub_to_battle_focus_scale(start_focus)
	_capture_hub_focus_layer_base_transforms(focus_nodes)
	if duration <= 0.0:
		for node in focus_nodes:
			_apply_hub_focus_node(node, start_focus, end_focus, focus_scale)
		return play_token

	var tween := create_tween()
	_hub_to_battle_focus_tween = tween
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN_OUT)
	for node in focus_nodes:
		_tween_hub_focus_node(tween, node, start_focus, end_focus, focus_scale, duration)
	return play_token


func _complete_hub_to_battle_focus(play_token: int) -> void:
	if play_token != _hub_to_battle_focus_token:
		return
	_hub_to_battle_focus_tween = null
	if not is_inside_tree():
		return
	_open_hub_battle_session()
	if _is_hub_battle_session_active:
		call_deferred("_play_hub_plush_transition_with_battle_intro")


func _cancel_hub_to_battle_focus() -> void:
	_hub_to_battle_focus_token += 1
	if _hub_to_battle_focus_tween != null:
		_hub_to_battle_focus_tween.kill()
		_hub_to_battle_focus_tween = null


func _tween_hub_focus_node(tween: Tween, node: Node, focus_point: Vector2, target_point: Vector2, focus_scale: Vector2, duration: float) -> void:
	if node == null:
		return
	var canvas_item := node as CanvasItem
	if canvas_item == null or not canvas_item.visible:
		return
	var current_scale: Vector2 = node.get("scale")
	var target_scale := Vector2(current_scale.x * focus_scale.x, current_scale.y * focus_scale.y)
	var target_position := _get_hub_focus_target_local_position(canvas_item, focus_point, target_point, target_scale)
	tween.tween_property(node, "position", target_position, duration)
	tween.tween_property(node, "scale", target_scale, duration)


func _apply_hub_focus_node(node: Node, focus_point: Vector2, target_point: Vector2, focus_scale: Vector2) -> void:
	if node == null:
		return
	var canvas_item := node as CanvasItem
	if canvas_item == null or not canvas_item.visible:
		return
	var current_scale: Vector2 = node.get("scale")
	var target_scale := Vector2(current_scale.x * focus_scale.x, current_scale.y * focus_scale.y)
	node.set("position", _get_hub_focus_target_local_position(canvas_item, focus_point, target_point, target_scale))
	node.set("scale", target_scale)


func _get_hub_focus_target_local_position(canvas_item: CanvasItem, focus_point: Vector2, target_point: Vector2, target_scale: Vector2) -> Vector2:
	if canvas_item == hub_board_content:
		var parent_canvas := canvas_item.get_parent() as CanvasItem
		if parent_canvas != null:
			var focus_local := canvas_item.get_global_transform().affine_inverse() * focus_point
			var target_parent_position := parent_canvas.get_global_transform().affine_inverse() * target_point
			var target_position := target_parent_position - Vector2(focus_local.x * target_scale.x, focus_local.y * target_scale.y)
			target_position.y = _get_hub_board_bottom_locked_focus_y(target_position.y, target_scale.y)
			return target_position

	var current_global_position := canvas_item.get_global_transform().origin
	var mirrored_focus_target := focus_point - (target_point - focus_point)
	var fallback_zoom := (target_scale.x + target_scale.y) * 0.5
	var target_global_position := mirrored_focus_target + (current_global_position - focus_point) * fallback_zoom
	var fallback_parent_canvas := canvas_item.get_parent() as CanvasItem
	if fallback_parent_canvas == null:
		return target_global_position
	return fallback_parent_canvas.get_global_transform().affine_inverse() * target_global_position


func _get_hub_board_bottom_locked_focus_y(target_y: float, target_scale_y: float) -> float:
	if hub_board_viewport == null or target_scale_y <= 0.0:
		return target_y
	var clip_rect := _get_hub_board_source_clip_rect()
	if clip_rect.size.y <= 0.0 or hub_board_viewport.size.y <= 0.0:
		return target_y
	var locked_y := hub_board_viewport.size.y + HUB_TO_BATTLE_BOARD_BOTTOM_LOCK_OFFSET - clip_rect.end.y * target_scale_y
	return minf(target_y, locked_y)


func _get_hub_to_battle_focus_zoom(focus_point: Vector2) -> float:
	return HUB_TO_BATTLE_FOCUS_ZOOM if _is_valid_hub_point(focus_point) else HUB_TO_BATTLE_MIN_FOCUS_ZOOM


func _get_hub_to_battle_focus_scale(focus_point: Vector2) -> Vector2:
	var zoom := _get_hub_to_battle_focus_zoom(focus_point)
	return Vector2(zoom, zoom)


func _get_hub_to_battle_board_target_global_position() -> Vector2:
	if hub_board_viewport == null:
		return INVALID_HUB_POINT
	var board_rect := hub_board_viewport.get_global_rect()
	if board_rect.size.x <= 0.0 or board_rect.size.y <= 0.0:
		return INVALID_HUB_POINT
	return Vector2(
		board_rect.position.x + board_rect.size.x * HUB_TO_BATTLE_BOARD_TARGET_UV.x,
		board_rect.position.y + board_rect.size.y * HUB_TO_BATTLE_BOARD_TARGET_UV.y
	)


func _is_valid_hub_point(point: Vector2) -> bool:
	return absf(point.x) < INVALID_HUB_POINT.x * 0.5 and absf(point.y) < INVALID_HUB_POINT.y * 0.5


func _get_hub_to_battle_focus_layers() -> Array[Node]:
	var layers: Array[Node] = []
	if hub_board_content != null:
		layers.append(hub_board_content)
	return layers


func _is_hub_board_focus_item(canvas_item: CanvasItem) -> bool:
	if canvas_item == null or hub_board_content == null:
		return false
	if canvas_item == hub_board_content:
		return true
	var parent := canvas_item.get_parent()
	while parent != null:
		if parent == hub_board_content:
			return true
		parent = parent.get_parent()
	return false


func _capture_hub_focus_layer_base_transforms(nodes: Array[Node]) -> void:
	_hub_focus_layer_base_transforms.clear()
	for node in nodes:
		if node == null or not is_instance_valid(node):
			continue
		var layer_transform := {
			"node": node,
			"position": node.get("position"),
			"scale": node.get("scale"),
		}
		if _has_node_property(node, "rotation"):
			layer_transform["rotation"] = node.get("rotation")
		if _has_node_property(node, "offset"):
			layer_transform["offset"] = node.get("offset")
		_hub_focus_layer_base_transforms[node.get_instance_id()] = layer_transform


func _restore_hub_focus_layer_base_transforms() -> void:
	for layer_transform in _hub_focus_layer_base_transforms.values():
		if not (layer_transform is Dictionary):
			continue
		var node := layer_transform.get("node", null) as Node
		if node == null or not is_instance_valid(node):
			continue
		if layer_transform.has("position"):
			node.set("position", layer_transform["position"])
		if layer_transform.has("scale"):
			node.set("scale", layer_transform["scale"])
		if layer_transform.has("rotation"):
			node.set("rotation", layer_transform["rotation"])
		if layer_transform.has("offset"):
			node.set("offset", layer_transform["offset"])
	_hub_focus_layer_base_transforms.clear()


func _lock_before_transition() -> void:
	if _interaction_flow_controller != null:
		_interaction_flow_controller.mark_transitioning()
	GlobalInput.set_context(GlobalInput.Context.LOCKED)


func _on_battle_trigger_body_entered(_body) -> void:
	current_zone = "battle"
	print("[Hub] Entered battle trigger.")


func _on_shop_trigger_body_entered(_body) -> void:
	current_zone = "shop"
	print("[Hub] Entered shop trigger.")


func _on_gallery_trigger_body_entered(_body) -> void:
	current_zone = "gallery"
	print("[Hub] Entered gallery trigger.")


func _on_zone_body_exited(_body) -> void:
	current_zone = ""
	print("[Hub] 离开区域")


func _on_main_menu_button_pressed() -> void:
	_return_to_main_menu()

func _on_route_button_pressed() -> void:
	_clear_pending_auto_interaction()
	_open_book_page(BookPageNavigator.PAGE_HUB)

func _on_dreamcatcher_button_pressed() -> void:
	if _interaction_flow_controller == null:
		return
	_interaction_flow_controller.request_battle_start(
		_get_run_manager(),
		_is_book_hub_current(),
		Callable(self, "_play_hub_dreamcatcher_start_swing")
	)

func _on_merchant_button_pressed() -> void:
	if _interaction_flow_controller != null:
		if _is_merchant_shop_available():
			_interaction_flow_controller.mark_idle()
		if _interaction_flow_controller.request_merchant_interaction(_get_run_manager()):
			return
	if _merchant_controller != null:
		_merchant_controller.interact(_get_run_manager())

func _on_gallery_button_pressed() -> void:
	_open_book_page(BookPageNavigator.PAGE_GALLERY)

func _on_settings_button_pressed() -> void:
	_open_book_page(BookPageNavigator.PAGE_SETTINGS)


func _return_to_main_menu() -> void:
	_transition_from_hub(GlobalScene.SceneType.MAIN_MENU, false)


func _enter_battle() -> void:
	_enter_current_route_node()


func _enter_shop() -> void:
	_enter_current_route_node()


func _enter_gallery() -> void:
	_open_book_page(BookPageNavigator.PAGE_GALLERY)


func _transition_from_hub(target: int, push_to_history: bool = true) -> void:
	_lock_before_transition()
	GlobalScene.transition_to(target, push_to_history)


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
	_open_book_page(BookPageNavigator.PAGE_BACKPACK)


func _open_book_page(page_id: String) -> void:
	if book_page_navigator != null and book_page_navigator.has_method("go_to_page"):
		book_page_navigator.go_to_page(page_id)


func play_story_book_page(sequence_id: String) -> bool:
	if book_page_navigator == null or not book_page_navigator.has_method("play_story_sequence"):
		return false
	return bool(book_page_navigator.call("play_story_sequence", sequence_id))


func can_play_pending_story_sequence() -> bool:
	return not _story_book_return_transition_running \
		and not _is_hub_battle_session_active \
		and not _is_shop_visual_state_active \
		and not _is_shop_intro_sequence_running \
		and not _merchant_shop_sequence_running


func _consume_story_book_return_transition_request() -> bool:
	var scene_manager := get_node_or_null("/root/GlobalScene")
	if scene_manager == null or not scene_manager.has_method("consume_story_book_return_transition_request"):
		return false
	return bool(scene_manager.call("consume_story_book_return_transition_request"))


func _prepare_story_book_return_transition() -> bool:
	if book_page_navigator == null or not book_page_navigator.has_method("prepare_story_return_page"):
		return false
	var prepared := bool(book_page_navigator.call("prepare_story_return_page", _consume_story_book_return_page_state()))
	_story_book_return_transition_running = prepared
	return prepared


func _consume_story_book_return_page_state() -> Dictionary:
	var scene_manager := get_node_or_null("/root/GlobalScene")
	if scene_manager == null or not scene_manager.has_method("consume_story_book_return_page_state"):
		return {}
	var page_state: Variant = scene_manager.call("consume_story_book_return_page_state")
	if page_state is Dictionary:
		return Dictionary(page_state)
	return {}


func _play_story_book_return_transition() -> void:
	if book_page_navigator != null and book_page_navigator.has_method("play_story_return_to_hub"):
		await book_page_navigator.call("play_story_return_to_hub")
	_story_book_return_transition_running = false
	_try_play_pending_hub_story_on_ready()


func play_story_bubble_dialogue(sequence_id: String) -> bool:
	if not _should_show_xiaomi_story_actor():
		return false
	var controller := _ensure_story_bubble_controller()
	if controller == null:
		return false
	var story_manager := get_node_or_null("/root/StoryManager")
	if story_manager == null or not story_manager.has_method("get_sequence_frames"):
		return false
	var raw_frames: Variant = story_manager.call("get_sequence_frames", sequence_id)
	if not (raw_frames is Array):
		return false
	var frames: Array = Array(raw_frames)
	if frames.is_empty():
		return false
	if _ensure_xiaomi_anchor() == null:
		return false
	controller.call("start_dialogue", sequence_id, frames, player, _xiaomi_anchor)
	return true


func _should_show_xiaomi_story_actor() -> bool:
	var rm = _get_run_manager()
	return rm != null and bool(rm.get("is_run_active")) and int(rm.get("current_act")) == XIAOMI_STORY_ACT


func _sync_xiaomi_anchor_for_current_act() -> void:
	if _should_show_xiaomi_story_actor():
		_ensure_xiaomi_anchor()
	else:
		_remove_xiaomi_anchor()


func _ensure_xiaomi_anchor() -> Node2D:
	if _xiaomi_anchor != null and is_instance_valid(_xiaomi_anchor):
		return _xiaomi_anchor
	_xiaomi_anchor = Node2D.new()
	_xiaomi_anchor.name = "XiaomiDialogueAnchor"
	_xiaomi_anchor.position = XIAOMI_ANCHOR_SOURCE_POSITION
	var texture := _load_xiaomi_texture(XIAOMI_TEXTURE_PATH)
	if texture != null:
		var sprite := Sprite2D.new()
		sprite.name = "XiaomiSprite"
		sprite.texture = texture
		sprite.centered = false
		sprite.position = XIAOMI_SPRITE_OFFSET
		sprite.scale = XIAOMI_SPRITE_SCALE
		sprite.z_index = 16
		_xiaomi_anchor.add_child(sprite)
	if hub_art != null:
		hub_art.add_child(_xiaomi_anchor)
	else:
		add_child(_xiaomi_anchor)
	return _xiaomi_anchor


func _remove_xiaomi_anchor() -> void:
	if _xiaomi_anchor != null and is_instance_valid(_xiaomi_anchor):
		var parent := _xiaomi_anchor.get_parent()
		if parent != null:
			parent.remove_child(_xiaomi_anchor)
		_xiaomi_anchor.free()
	_xiaomi_anchor = null


func _load_xiaomi_texture(path: String) -> Texture2D:
	var loaded := load(path) as Texture2D
	if loaded != null:
		return loaded
	var image := Image.new()
	var error := image.load(ProjectSettings.globalize_path(path))
	if error != OK:
		push_warning("[Hub] Failed to load Xiaomi texture: %s" % path)
		return null
	return ImageTexture.create_from_image(image)


func _ensure_story_bubble_controller() -> Control:
	if _story_bubble_controller != null and is_instance_valid(_story_bubble_controller):
		return _story_bubble_controller
	var controller := HubDialogueBubbleControllerScript.new() as Control
	controller.name = "HubDialogueBubbleController"
	controller.z_index = 3000
	var canvas := get_node_or_null("CanvasLayer") as CanvasLayer
	if canvas != null:
		canvas.add_child(controller)
	else:
		add_child(controller)
	var callback := Callable(self, "_on_story_bubble_dialogue_finished")
	if controller.has_signal("dialogue_finished") and not controller.is_connected("dialogue_finished", callback):
		controller.connect("dialogue_finished", callback)
	_story_bubble_controller = controller
	return _story_bubble_controller


func _on_story_bubble_dialogue_finished(sequence_id: String) -> void:
	var story_manager := get_node_or_null("/root/StoryManager")
	if story_manager == null or not story_manager.has_method("finish_current_sequence"):
		return
	var active_sequence: Variant = story_manager.get("current_playing_sequence")
	if sequence_id == "" or str(active_sequence) == sequence_id:
		story_manager.call("finish_current_sequence")


func _try_play_pending_hub_story_on_ready() -> void:
	var story_manager := get_node_or_null("/root/StoryManager")
	if story_manager == null or not story_manager.has_method("play_pending_hub_sequences_if_ready"):
		return
	story_manager.call("play_pending_hub_sequences_if_ready")


func _story_manager_has_pending_hub_sequences() -> bool:
	var story_manager := get_node_or_null("/root/StoryManager")
	if story_manager == null or not story_manager.has_method("has_pending_hub_sequences"):
		return false
	return bool(story_manager.call("has_pending_hub_sequences"))


func _is_book_hub_current() -> bool:
	if book_page_navigator == null or not book_page_navigator.has_method("is_hub_current"):
		return true
	return bool(book_page_navigator.is_hub_current())


func get_book_hub_transition_layer() -> Control:
	return null


func set_book_hub_transition_frozen(frozen: bool) -> void:
	if player == null:
		return
	if frozen:
		if _hub_transition_player_frozen:
			return
		_hub_transition_player_frozen = true
		_hub_transition_player_process_mode = player.process_mode
		if player.has_method("clear_move_target"):
			player.clear_move_target()
		player.process_mode = Node.PROCESS_MODE_DISABLED
		return
	if not _hub_transition_player_frozen:
		return
	player.process_mode = _hub_transition_player_process_mode
	_hub_transition_player_frozen = false


func get_book_hub_transition_layers() -> Array[Node]:
	var layers: Array[Node] = []
	for node in [book_design_root, hub_art, player]:
		var layer := node as Node
		if layer != null and is_instance_valid(layer):
			layers.append(layer)
	return layers


func _setup_hub_page_visual_root() -> void:
	# Keep HubArt and Player at their stable scene paths; BookPageNavigator
	# temporarily reparents those layers only while a book transition is active.
	pass


func _layout_hub_page_visual_root(viewport_size: Vector2) -> void:
	if _hub_page_visual_root == null or not is_instance_valid(_hub_page_visual_root):
		return
	_hub_page_visual_root.set_anchors_preset(Control.PRESET_TOP_LEFT, false)
	_hub_page_visual_root.position = Vector2.ZERO
	_hub_page_visual_root.size = viewport_size
	_hub_page_visual_root.scale = Vector2.ONE
	_hub_page_visual_root.pivot_offset = Vector2(viewport_size.x, 0.0)


func set_book_hub_visible(page_visible: bool) -> void:
	_setup_hub_page_visual_root()
	if _hub_page_visual_root != null:
		_hub_page_visual_root.visible = page_visible
	if book_canvas_layer != null:
		book_canvas_layer.visible = page_visible
	if book_design_root != null:
		book_design_root.visible = true
	if hub_art != null:
		hub_art.visible = page_visible
	if player != null:
		player.visible = page_visible
		if not page_visible and player.has_method("clear_move_target"):
			player.clear_move_target()
	if floor_body != null:
		floor_body.visible = page_visible
	if canvas_design_root != null:
		canvas_design_root.visible = page_visible
	if merchant_button != null:
		merchant_button.visible = page_visible and _should_show_merchant()
	if page_visible:
		_layout_scene()
		_update_merchant_state()
		_update_dreamcatcher_state()
		_start_hub_dreamcatcher_idle_swing()
	else:
		_clear_pending_auto_interaction()
		_stop_hub_dreamcatcher_idle_swing()
		_update_dreamcatcher_state()


func _open_backpack_overlay_with_transition() -> void:
	GlobalScene.transition_with_page_turn(Callable(self, "_open_backpack_overlay"))


func _open_backpack_overlay() -> void:
	print("[Hub] 正在打开背包浮层...")
	GlobalInput.set_context(GlobalInput.Context.UI)
	var ui_scene = load("res://src/ui/backpack/backpack_page.tscn")
	var overlay = ui_scene.instantiate()
	if overlay.has_method("configure_for_backpack_overlay"):
		overlay.configure_for_backpack_overlay(Callable(self, "_return_to_main_menu"))
	overlay_root.add_child(overlay)


func _close_backpack_overlay_with_transition() -> void:
	if overlay_root.get_child_count() <= 0:
		return
	GlobalScene.transition_with_page_turn(Callable(self, "_close_backpack_overlay"))


func _close_backpack_overlay() -> void:
	print("[Hub] 正在关闭背包浮层")
	for child in overlay_root.get_children():
		var manager = child.get("battle_manager")
		if manager != null and manager.has_method("persist_backpack_to_run"):
			manager.persist_backpack_to_run()
		child.queue_free()
	GlobalInput.set_context(GlobalInput.Context.WORLD)

func _layout_scene() -> void:
	var viewport_size := _get_layout_viewport_size()
	if Engine.is_editor_hint():
		_has_positioned_player = false
	_layout_hub_page_visual_root(viewport_size)
	_layout_hub_art(viewport_size)
	_sync_hub_plush_transition_pose()
	_layout_book_design_root()
	_layout_canvas_design_root()
	if _shop_visual_controller != null:
		_shop_visual_controller.layout(viewport_size)
	_layout_player_and_floor(viewport_size)
	_layout_merchant()


func _get_layout_viewport_size() -> Vector2:
	if Engine.is_editor_hint():
		var width := DEFAULT_VIEWPORT_SIZE.x
		var height := DEFAULT_VIEWPORT_SIZE.y
		if ProjectSettings.has_setting("display/window/size/viewport_width"):
			width = float(ProjectSettings.get_setting("display/window/size/viewport_width"))
		if ProjectSettings.has_setting("display/window/size/viewport_height"):
			height = float(ProjectSettings.get_setting("display/window/size/viewport_height"))
		return _validated_layout_viewport_size(Vector2(width, height))
	return _validated_layout_viewport_size(get_viewport_rect().size)


func _validated_layout_viewport_size(viewport_size: Vector2) -> Vector2:
	return DesignScaler.get_valid_viewport_size(viewport_size, DEFAULT_VIEWPORT_SIZE)


func _layout_hub_art(viewport_size: Vector2) -> void:
	var metrics := HubLayoutMetrics.calculate(viewport_size, _hub_source_size, hub_art_source_offset)
	_art_scale = float(metrics.get("scale", 1.0))
	_book_origin = metrics.get("book_origin", Vector2.ZERO)
	_art_origin = metrics.get("art_origin", Vector2.ZERO)
	HubLayoutMetrics.apply_node2d_source_transform(hub_art, _art_origin, _art_scale)
	if hub_board_viewport != null:
		var clip_rect := _get_hub_board_source_clip_rect()
		hub_board_viewport.set_anchors_preset(Control.PRESET_TOP_LEFT, true)
		hub_board_viewport.position = clip_rect.position
		hub_board_viewport.size = clip_rect.size
		hub_board_viewport.clip_contents = true
		hub_board_viewport.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if hub_board_content != null:
			var board_content_control := hub_board_content as Control
			if board_content_control != null:
				board_content_control.set_anchors_preset(Control.PRESET_TOP_LEFT, true)
				board_content_control.position = -clip_rect.position
				board_content_control.size = _hub_source_size
				board_content_control.pivot_offset = Vector2.ZERO
			else:
				var board_content_node_2d := hub_board_content as Node2D
				if board_content_node_2d != null:
					board_content_node_2d.position = -clip_rect.position


func _get_hub_board_source_clip_rect() -> Rect2:
	var room_rect := _get_default_room_source_rect()
	if room_rect.size.x > 0.0 and room_rect.size.y > 0.0:
		return room_rect
	return _get_hub_art_corner_source_bounds()


func _get_default_room_source_rect() -> Rect2:
	var room_size := _default_room_display_size
	if (room_size.x <= 0.0 or room_size.y <= 0.0) and _default_room_texture != null:
		room_size = _default_room_texture.get_size() * _default_room_scale
	return Rect2(_default_room_position, room_size)


func _get_hub_art_corner_source_bounds() -> Rect2:
	var has_clip_rect := false
	var clip_rect := Rect2(Vector2.ZERO, _hub_source_size)
	if hub_art == null:
		return clip_rect
	for child_name in ["CornerTopLeft", "CornerTopRight", "CornerBottomLeft", "CornerBottomRight"]:
		var sprite := hub_art.get_node_or_null(child_name) as Sprite2D
		if sprite == null or sprite.texture == null:
			continue
		var sprite_rect := _get_sprite_parent_rect(sprite)
		if not has_clip_rect:
			clip_rect = sprite_rect
			has_clip_rect = true
		else:
			clip_rect = clip_rect.merge(sprite_rect)
	return clip_rect if has_clip_rect else Rect2(Vector2.ZERO, _hub_source_size)


func _get_sprite_parent_rect(sprite: Sprite2D) -> Rect2:
	var texture_size := sprite.texture.get_size()
	var local_origin := sprite.offset
	if sprite.centered:
		local_origin -= texture_size * 0.5
	var points := [
		sprite.transform * local_origin,
		sprite.transform * (local_origin + Vector2(texture_size.x, 0.0)),
		sprite.transform * (local_origin + texture_size),
		sprite.transform * (local_origin + Vector2(0.0, texture_size.y)),
	]
	var rect := Rect2(points[0], Vector2.ZERO)
	for index in range(1, points.size()):
		rect = rect.expand(points[index])
	return rect


func _layout_book_design_root() -> void:
	HubLayoutMetrics.apply_scaled_control_root(book_design_root, _book_origin, _hub_source_size, _art_scale)
	HubLayoutMetrics.apply_full_size_control(book_background, _hub_source_size)

func _layout_canvas_design_root() -> void:
	if canvas_design_root == null:
		return
	HubLayoutMetrics.apply_scaled_control_root(canvas_design_root, _book_origin, _hub_source_size, _art_scale)
	_layout_hub_back_tab_button()
	_layout_hub_left_tab_buttons()
	_layout_hub_world_buttons()


func _layout_hub_back_tab_button() -> void:
	if canvas_design_root == null:
		return
	var button := canvas_design_root.get_node_or_null(HUB_BACK_TAB_BUTTON) as Control
	if button == null:
		return
	var rect := _get_book_background_child_rect("BackTab", BookBackgroundConfig.get_back_tab_rect())
	button.position = rect.position
	button.size = rect.size
	button.visible = true


func _layout_hub_left_tab_buttons() -> void:
	if canvas_design_root == null:
		return
	for page_id in HUB_LEFT_TAB_BUTTONS.keys():
		var button := canvas_design_root.get_node_or_null(str(HUB_LEFT_TAB_BUTTONS[page_id])) as Control
		if button == null:
			continue
		var tab_node_name := str(HUB_LEFT_TAB_NODES.get(BookBackgroundConfig.normalize_page_id(str(page_id)), ""))
		var rect := _get_book_background_child_rect(tab_node_name, BookBackgroundConfig.get_tab_rect(str(page_id), BookBackgroundConfig.PAGE_HUB))
		button.position = rect.position
		button.size = rect.size


func _get_book_background_child_rect(child_name: String, fallback_rect: Rect2) -> Rect2:
	if book_background == null or child_name == "":
		return fallback_rect
	var child := book_background.get_node_or_null(child_name) as Control
	if child == null:
		return fallback_rect
	var global_rect := child.get_global_rect()
	if global_rect.size.x <= 1.0 or global_rect.size.y <= 1.0:
		return fallback_rect
	var inverse_transform := canvas_design_root.get_global_transform().affine_inverse()
	var local_position := (inverse_transform * global_rect.position).round()
	var local_end := (inverse_transform * global_rect.end).round()
	return Rect2(local_position, local_end - local_position)


func _layout_hub_world_buttons() -> void:
	if dreamcatcher_button != null:
		var dreamcatcher_rect := _get_hub_dreamcatcher_button_local_rect()
		if dreamcatcher_rect.size.x > 1.0 and dreamcatcher_rect.size.y > 1.0:
			dreamcatcher_button.position = dreamcatcher_rect.position
			dreamcatcher_button.size = dreamcatcher_rect.size
		else:
			dreamcatcher_button.position = _dreamcatcher_button_source_position + hub_art_source_offset
			dreamcatcher_button.size = _dreamcatcher_button_source_size


func _get_hub_dreamcatcher_button_local_rect() -> Rect2:
	if canvas_design_root == null:
		return Rect2()
	var global_rect := _get_hub_dreamcatcher_global_rect()
	if global_rect.size.x <= 1.0 or global_rect.size.y <= 1.0:
		return Rect2()
	return _global_rect_to_canvas_design_rect(global_rect)


func _global_rect_to_canvas_design_rect(global_rect: Rect2) -> Rect2:
	var inverse_transform := canvas_design_root.get_global_transform().affine_inverse()
	var local_position := (inverse_transform * global_rect.position).round()
	var local_end := (inverse_transform * global_rect.end).round()
	return Rect2(local_position, local_end - local_position)


func _layout_player_and_floor(viewport_size: Vector2) -> void:
	var floor_y := _art_origin.y + PLAYER_FLOOR_SOURCE_Y * _art_scale
	if floor_body != null:
		floor_body.position = Vector2(viewport_size.x * 0.5, floor_y)
	if player == null:
		return

	var min_x := _art_origin.x + PLAYER_WALK_MIN_SOURCE_X * _art_scale
	var max_x := _art_origin.x + PLAYER_WALK_MAX_SOURCE_X * _art_scale
	if not Engine.is_editor_hint() and player.has_method("set_walk_bounds"):
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
	return HubLayoutMetrics.source_rect_to_viewport(source_rect, _get_layout_viewport_size(), _hub_source_size, hub_art_source_offset)
