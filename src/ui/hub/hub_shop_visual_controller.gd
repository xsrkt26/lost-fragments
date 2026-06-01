extends RefCounted

const BackpackUIScene = preload("res://src/ui/backpack/backpack_ui.tscn")
const ItemUIScene = preload("res://src/ui/item/item_ui.tscn")
const PendingItemPresenter = preload("res://src/ui/backpack/pending_item_presenter.gd")
const PlayableBagTexture = preload("res://assets/ui/battle/intro_bag_reveal/bag_reveal_05.png")

const DESIGN_SIZE := BookBackgroundConfig.DESIGN_SIZE
const INTRO_CANVAS_LAYER := 90
const BACKPACK_CANVAS_LAYER := 89
const OFFER_CANVAS_LAYER := 92
const BACKPACK_DESIGN_RECT := Rect2(Vector2(364.0, 104.0), Vector2(676.0, 854.0))
const BACKPACK_RISE_OFFSET_Y := 620.0
const BACKPACK_RISE_DURATION := 1.0
const SHOP_EXIT_DESIGN_RECT := Rect2(Vector2(92.0, 612.0), Vector2(240.0, 86.0))
const SHOP_EXIT_HOVER_SCALE := 1.08
const SHOP_BUYBACK_DESIGN_RECT := Rect2(Vector2(44.0, 820.0), Vector2(270.0, 108.0))
const SHOP_BUYBACK_HOVER_SCALE := 1.08
const SHOP_BUYBACK_ITEM_HOVER_SCALE := 1.1
const PLAYABLE_BAG_SOURCE_SIZE := Vector2(806.6115, 1018.74243)
const PLAYABLE_BAG_GRID_SOURCE_RECT := Rect2(Vector2(119.28073, 384.0497), Vector2(576.8495, 532.6164))
const SHOP_SKULL_FADE_START_PROGRESS := 0.82
const SHOP_SKULL_FADE_END_PROGRESS := 0.96
const OFFER_ITEM_MARGIN := Vector2(4.0, 4.0)
const OFFER_TEXT_COLOR := Color(0.12, 0.08, 0.04, 1.0)
const OFFER_PRICE_COLOR := Color(0.86, 0.02, 0.02, 1.0)
const OFFER_SOLD_OVERLAY_COLOR := Color(0.08, 0.06, 0.04, 0.52)
const SHOP_SKULL_DESIGN_RECTS := [
	Rect2(Vector2(976.0, 288.0), Vector2(212.0, 189.0)),
	Rect2(Vector2(1324.0, 339.0), Vector2(281.0, 157.0)),
	Rect2(Vector2(1565.0, 229.0), Vector2(256.0, 226.0)),
	Rect2(Vector2(1787.0, 75.0), Vector2(128.0, 186.0)),
]
const OFFER_DESIGN_RECTS := [
	Rect2(Vector2(1092.0, 118.0), Vector2(150.0, 226.0)),
	Rect2(Vector2(1306.0, 134.0), Vector2(160.0, 224.0)),
	Rect2(Vector2(1510.0, 118.0), Vector2(150.0, 226.0)),
	Rect2(Vector2(1630.0, 18.0), Vector2(196.0, 206.0)),
	Rect2(Vector2(1006.0, 488.0), Vector2(162.0, 184.0)),
	Rect2(Vector2(1040.0, 718.0), Vector2(198.0, 182.0)),
	Rect2(Vector2(1510.0, 488.0), Vector2(206.0, 184.0)),
	Rect2(Vector2(1650.0, 632.0), Vector2(218.0, 190.0)),
]

var _owner_node: Node = null
var _intro_canvas: CanvasLayer = null
var _intro_frame: TextureRect = null
var _shop_skull_root: Control = null
var _shop_skull_nodes: Array[TextureRect] = []
var _backpack_canvas: CanvasLayer = null
var _backpack_root: Control = null
var _backpack_panel: Control = null
var _backpack_art: TextureRect = null
var _backpack_ui: Control = null
var _shards_label: Label = null
var _pending_item_panel: Control = null
var _pending_item_area: Control = null
var _offers_canvas: CanvasLayer = null
var _offers_root: Control = null
var _exit_button: Button = null
var _buyback_button: Button = null
var _offer_buttons: Array[Button] = []
var _last_viewport_size := DESIGN_SIZE
var _battle_manager: BattleManager = null
var _rendered_item_uis: Array[Control] = []
var _trimmed_offer_texture_cache: Dictionary = {}
var _last_drag_root_grid_pos := Vector2i(-999999, -999999)
var _last_drag_item_id := 0
var _buyback_drag_active := false
var _buyback_button_hovered := false
var _buyback_hover_item: Control = null
var _buyback_button_tween: Tween = null
var _buyback_item_tween: Tween = null
var _is_closing := false
var _close_requested_callback: Callable = Callable()


func play_intro_overlay(owner_node: Node, run_manager: Node, item_db: Node, ornament_db: Node, keep_final_frame: bool = true, frame_rate: float = 30.0, close_requested_callback: Callable = Callable()):
	_owner_node = owner_node
	close()
	_close_requested_callback = close_requested_callback
	if owner_node == null or not owner_node.is_inside_tree():
		return null

	_last_viewport_size = Vector2(owner_node.get_viewport().get_visible_rect().size)
	_create_intro_canvas(owner_node)
	_create_backpack_overlay(owner_node)
	_setup_interactive_backpack(owner_node, run_manager, item_db)
	await owner_node.get_tree().process_frame
	_layout_all(_last_viewport_size, true)
	_render_backpack(run_manager, item_db)
	_animate_backpack_in()

	var frame_paths: Array = AssetPaths.shop_intro_frame_paths()
	var frame_delay := 1.0 / maxf(frame_rate, 1.0)
	_set_shop_skull_alpha(0.0)
	for frame_index in range(frame_paths.size()):
		var frame_path = frame_paths[frame_index]
		if owner_node == null or not owner_node.is_inside_tree():
			break
		var texture: Texture2D = AssetPaths.load_texture(str(frame_path)) as Texture2D
		if texture == null:
			continue
		if _intro_frame != null and is_instance_valid(_intro_frame):
			_intro_frame.texture = texture
		_update_shop_skull_fade(frame_index, frame_paths.size())
		await owner_node.get_tree().create_timer(frame_delay).timeout

	if keep_final_frame:
		if _intro_frame != null and is_instance_valid(_intro_frame):
			_intro_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_set_shop_skull_alpha(1.0)
		_render_offer_buttons(run_manager, item_db, ornament_db)
		_create_buyback_button(owner_node)
		_create_exit_button(owner_node)
		_layout_buyback_button()
		_layout_exit_button()
		return _intro_canvas
	close()
	return null


func request_close_with_animation(frame_rate: float = 60.0) -> void:
	if _is_closing:
		return
	_is_closing = true
	_set_shop_interactable(false)
	_persist_backpack()
	_hide_tooltips()
	await _play_close_animation(frame_rate)
	if _close_requested_callback.is_valid():
		_close_requested_callback.call()
	else:
		close()


func close() -> void:
	_reset_buyback_feedback(true)
	if _battle_manager != null and is_instance_valid(_battle_manager):
		if _battle_manager.has_method("persist_backpack_to_run"):
			_battle_manager.persist_backpack_to_run()
		_battle_manager.queue_free()
	if _intro_canvas != null and is_instance_valid(_intro_canvas):
		_intro_canvas.queue_free()
	if _backpack_canvas != null and is_instance_valid(_backpack_canvas):
		_backpack_canvas.queue_free()
	if _offers_canvas != null and is_instance_valid(_offers_canvas):
		_offers_canvas.queue_free()
	_intro_canvas = null
	_intro_frame = null
	_shop_skull_root = null
	_shop_skull_nodes.clear()
	_backpack_canvas = null
	_backpack_root = null
	_backpack_panel = null
	_backpack_art = null
	_backpack_ui = null
	_shards_label = null
	_pending_item_panel = null
	_pending_item_area = null
	_offers_canvas = null
	_offers_root = null
	_exit_button = null
	_buyback_button = null
	_battle_manager = null
	_rendered_item_uis.clear()
	_reset_drag_highlight_tracking()
	_offer_buttons.clear()
	_is_closing = false
	_close_requested_callback = Callable()
	GlobalTooltip.hide()


func layout(viewport_size: Vector2) -> void:
	_layout_all(viewport_size, false)


func _create_intro_canvas(owner_node: Node) -> void:
	_intro_canvas = CanvasLayer.new()
	_intro_canvas.name = "ShopIntroOverlayCanvas"
	_intro_canvas.layer = INTRO_CANVAS_LAYER
	owner_node.add_child(_intro_canvas)

	_intro_frame = TextureRect.new()
	_intro_frame.name = "ShopIntroFrame"
	_intro_frame.mouse_filter = Control.MOUSE_FILTER_STOP
	_intro_frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_intro_frame.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_intro_canvas.add_child(_intro_frame)
	_intro_frame.set_anchors_preset(Control.PRESET_FULL_RECT, true)

	_create_shop_skull_overlay()


func _create_shop_skull_overlay() -> void:
	if _intro_canvas == null:
		return
	_shop_skull_root = Control.new()
	_shop_skull_root.name = "ShopSkullOverlay"
	_shop_skull_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shop_skull_root.modulate.a = 0.0
	_intro_canvas.add_child(_shop_skull_root)
	_shop_skull_root.set_anchors_preset(Control.PRESET_FULL_RECT, true)

	_shop_skull_nodes.clear()
	var paths := AssetPaths.SHOP_SKULL_PATHS
	for index in range(mini(paths.size(), SHOP_SKULL_DESIGN_RECTS.size())):
		var texture := AssetPaths.load_texture(str(paths[index]))
		if texture == null:
			continue
		var skull := TextureRect.new()
		skull.name = "ShopSkull%d" % (index + 1)
		skull.mouse_filter = Control.MOUSE_FILTER_IGNORE
		skull.texture = texture
		skull.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		skull.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_shop_skull_root.add_child(skull)
		_shop_skull_nodes.append(skull)


func _create_backpack_overlay(owner_node: Node) -> void:
	_backpack_canvas = CanvasLayer.new()
	_backpack_canvas.name = "ShopBackpackOverlayCanvas"
	_backpack_canvas.layer = BACKPACK_CANVAS_LAYER
	owner_node.add_child(_backpack_canvas)

	_backpack_root = Control.new()
	_backpack_root.name = "ShopBackpackRoot"
	_backpack_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_backpack_canvas.add_child(_backpack_root)
	_backpack_root.set_anchors_preset(Control.PRESET_FULL_RECT, true)

	_backpack_panel = Control.new()
	_backpack_panel.name = "ShopBackpackPanel"
	_backpack_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_backpack_root.add_child(_backpack_panel)

	_backpack_art = TextureRect.new()
	_backpack_art.name = "PlayableBagArt"
	_backpack_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_backpack_art.texture = PlayableBagTexture
	_backpack_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_backpack_art.stretch_mode = TextureRect.STRETCH_SCALE
	_backpack_panel.add_child(_backpack_art)

	_shards_label = Label.new()
	_shards_label.name = "ShardLabel"
	_shards_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_shards_label.add_theme_font_size_override("font_size", 22)
	_shards_label.add_theme_color_override("font_color", Color(0.1, 0.07, 0.04, 1.0))
	_backpack_panel.add_child(_shards_label)

	_pending_item_panel = Control.new()
	_pending_item_panel.name = "PendingItemPanel"
	_pending_item_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_backpack_panel.add_child(_pending_item_panel)

	var pending_label := Label.new()
	pending_label.name = "PendingItemLabel"
	pending_label.text = "待放置商品"
	pending_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pending_label.add_theme_font_size_override("font_size", 20)
	pending_label.add_theme_color_override("font_color", Color(0.1, 0.07, 0.04, 1.0))
	_pending_item_panel.add_child(pending_label)

	_pending_item_area = Control.new()
	_pending_item_area.name = "PendingItemArea"
	_pending_item_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pending_item_panel.add_child(_pending_item_area)

	_backpack_ui = BackpackUIScene.instantiate() as Control
	if _backpack_ui == null:
		return
	_backpack_ui.name = "ShopBackpackUI"
	_backpack_panel.add_child(_backpack_ui)


func _render_backpack(run_manager: Node, item_db: Node) -> void:
	if _owner_node == null or _backpack_ui == null or _battle_manager == null or run_manager == null or item_db == null:
		return
	_render_existing_backpack_items()
	_render_pending_items(run_manager, item_db)
	_update_shards_label(run_manager)


func _setup_interactive_backpack(owner_node: Node, run_manager: Node, item_db: Node) -> void:
	if owner_node == null or _backpack_ui == null:
		return
	_battle_manager = BattleManager.new()
	_battle_manager.name = "ShopBackpackBattleManager"
	_battle_manager.run_manager_override = run_manager
	_battle_manager.item_database_override = item_db
	owner_node.add_child(_battle_manager)
	_battle_manager.backpack_ui = _backpack_ui


func _render_existing_backpack_items() -> void:
	_clear_rendered_item_uis()
	if _battle_manager == null or _backpack_ui == null:
		return
	_battle_manager.managed_item_uis.clear()
	if _backpack_ui.get("item_ui_map") is Dictionary:
		_backpack_ui.set("item_ui_map", {})
	if _backpack_ui.has_method("clear_item_visuals"):
		_backpack_ui.clear_item_visuals()
	if _backpack_ui.has_method("_refresh_grid"):
		_backpack_ui._refresh_grid()
	for instance in _battle_manager.backpack_manager.get_all_instances():
		if instance == null or instance.data == null:
			continue
		var card := ItemUIScene.instantiate() as Control
		if card == null:
			continue
		_backpack_panel.add_child(card)
		card.setup(instance.data, _battle_manager.context)
		card.set("item_instance", instance)
		_battle_manager.managed_item_uis.append(card)
		_rendered_item_uis.append(card)
		_connect_item_ui_signals(card)
		if _backpack_ui.has_method("add_item_visual"):
			_backpack_ui.add_item_visual(card, instance.root_pos)


func _clear_rendered_item_uis() -> void:
	for item_ui in _rendered_item_uis:
		if is_instance_valid(item_ui):
			item_ui.queue_free()
	_rendered_item_uis.clear()


func _render_pending_items(run_manager: Node, item_db: Node) -> void:
	if _pending_item_panel == null or _pending_item_area == null:
		return
	if run_manager == null or item_db == null or not run_manager.has_method("get_pending_item_rewards"):
		PendingItemPresenter.clear(_pending_item_panel, _pending_item_area)
		return
	var pending_items: Array = Array(run_manager.get_pending_item_rewards())
	PendingItemPresenter.render(_pending_item_panel, _pending_item_area, pending_items, item_db, _battle_manager.context if _battle_manager != null else null, Callable(self, "_connect_item_ui_signals"))


func _connect_item_ui_signals(card: Control) -> void:
	if card == null or not card.has_signal("dropped") or not card.has_signal("drag_moved") or not card.has_signal("rotation_requested"):
		return
	_replace_owned_item_signal_connection(card, "dropped", Callable(self, "_handle_item_dropped"))
	_replace_owned_item_signal_connection(card, "drag_moved", Callable(self, "_handle_item_dragged"))
	_replace_owned_item_signal_connection(card, "rotation_requested", Callable(self, "_handle_item_rotation_requested"))


func _replace_owned_item_signal_connection(card: Control, signal_name: StringName, expected_callback: Callable) -> void:
	var has_expected := false
	for connection in card.get_signal_connection_list(signal_name):
		var connected_callback: Callable = connection.get("callable", Callable())
		if connected_callback == expected_callback:
			has_expected = true
		elif connected_callback.is_valid() and connected_callback.get_object() == self:
			card.disconnect(signal_name, connected_callback)
	if not has_expected:
		card.connect(signal_name, expected_callback)


func _reset_drag_highlight_tracking() -> void:
	_last_drag_root_grid_pos = Vector2i(-999999, -999999)
	_last_drag_item_id = 0


func _get_drag_item_id(item_ui: Control) -> int:
	return int(item_ui.get_instance_id()) if item_ui != null else 0


func _clear_backpack_placement_highlight() -> void:
	if _backpack_ui == null:
		return
	if _backpack_ui.has_method("clear_placement_highlight"):
		_backpack_ui.clear_placement_highlight()
	elif _backpack_ui.has_method("update_slot_visuals"):
		_backpack_ui.update_slot_visuals()


func _handle_item_dragged(item_ui: Control, mouse_pos: Vector2, pivot_offset: Vector2i) -> void:
	var over_buyback := _is_buyback_drop_position(mouse_pos)
	_set_buyback_drag_active(over_buyback and _can_buyback_item(item_ui), item_ui)
	if over_buyback:
		_clear_backpack_placement_highlight()
		_reset_drag_highlight_tracking()
		return
	if _backpack_ui == null or not _backpack_ui.has_method("get_grid_pos_at") or not _backpack_ui.has_method("highlight_placement"):
		return
	var drag_item_id := _get_drag_item_id(item_ui)
	var mouse_grid_pos: Vector2i = _backpack_ui.get_grid_pos_at(mouse_pos)
	var root_grid_pos := mouse_grid_pos - pivot_offset if mouse_grid_pos != Vector2i(-1, -1) else Vector2i(-1, -1)
	if _last_drag_item_id == drag_item_id and _last_drag_root_grid_pos == root_grid_pos:
		return
	_last_drag_item_id = drag_item_id
	_last_drag_root_grid_pos = root_grid_pos
	var item_data = item_ui.get("item_data") if item_ui != null else null
	_backpack_ui.highlight_placement(root_grid_pos, item_data)


func _handle_item_dropped(item_ui: Control, mouse_pos: Vector2, pivot_offset: Vector2i) -> void:
	_reset_drag_highlight_tracking()
	if _backpack_ui != null and _backpack_ui.has_method("update_slot_visuals"):
		_backpack_ui.update_slot_visuals()
	if _is_buyback_drop_position(mouse_pos) and _try_buyback_item(item_ui):
		_set_buyback_drag_active(false, item_ui)
		return
	_set_buyback_drag_active(false, item_ui)
	if _battle_manager == null or _backpack_ui == null or not _backpack_ui.has_method("get_grid_pos_at"):
		return
	var mouse_grid_pos: Vector2i = _backpack_ui.get_grid_pos_at(mouse_pos)
	var root_grid_pos := mouse_grid_pos - pivot_offset if mouse_grid_pos != Vector2i(-1, -1) else Vector2i(-1, -1)
	_battle_manager.request_place_item(item_ui, root_grid_pos)
	_consume_pending_item_if_placed(item_ui)
	_persist_backpack()


func _handle_item_rotation_requested(item_ui: Control, mouse_global_pos: Vector2, pivot_offset: Vector2i) -> void:
	_clear_backpack_placement_highlight()
	_reset_drag_highlight_tracking()
	if _battle_manager != null and _battle_manager.has_method("request_rotate_item"):
		_battle_manager.request_rotate_item(item_ui, mouse_global_pos, pivot_offset)
		_persist_backpack()


func _consume_pending_item_if_placed(item_ui: Control) -> void:
	if item_ui == null or not item_ui.has_meta("pending_item_uid"):
		return
	if item_ui.get("item_instance") == null:
		return
	var run_manager := _get_run_manager()
	if run_manager != null and run_manager.has_method("consume_pending_item"):
		run_manager.consume_pending_item(int(item_ui.get_meta("pending_item_uid")))
	item_ui.remove_meta("pending_item_uid")
	if _battle_manager != null and not _battle_manager.managed_item_uis.has(item_ui):
		_battle_manager.managed_item_uis.append(item_ui)
	_render_pending_items(run_manager, _get_item_database())


func _can_buyback_item(item_ui: Control) -> bool:
	if item_ui == null or item_ui.has_meta("pending_item_uid"):
		return false
	return _get_item_ui_runtime_id(item_ui) != -1


func _get_item_ui_runtime_id(item_ui: Control) -> int:
	if item_ui == null:
		return -1
	var item_data := item_ui.get("item_data") as ItemData
	if item_data != null:
		return int(item_data.runtime_id)
	var instance := item_ui.get("item_instance") as BackpackManager.ItemInstance
	if instance != null and instance.data != null:
		return int(instance.data.runtime_id)
	return -1


func _try_buyback_item(item_ui: Control) -> bool:
	if not _can_buyback_item(item_ui):
		return false
	var run_manager := _get_run_manager()
	var item_db := _get_item_database()
	if run_manager == null or not run_manager.has_method("sell_backpack_item"):
		return false
	var runtime_id := _get_item_ui_runtime_id(item_ui)
	var gained := int(run_manager.sell_backpack_item(runtime_id, item_db))
	if gained <= 0:
		return false
	print("[HubShop] buyback backpack item, gained shards: ", gained)
	_restore_backpack_from_run(run_manager, item_db)
	_render_backpack(run_manager, item_db)
	_refresh_offer_buttons(run_manager)
	return true


func _restore_backpack_from_run(run_manager: Node, item_db: Node) -> void:
	if _battle_manager == null or _battle_manager.backpack_manager == null:
		return
	if run_manager != null and run_manager.has_method("restore_backpack_state"):
		run_manager.restore_backpack_state(_battle_manager.backpack_manager, item_db)


func _persist_backpack() -> void:
	if _battle_manager != null and _battle_manager.has_method("persist_backpack_to_run"):
		_battle_manager.persist_backpack_to_run()


func _create_offer_overlay(owner_node: Node) -> void:
	if _offers_canvas != null and is_instance_valid(_offers_canvas):
		return
	_offers_canvas = CanvasLayer.new()
	_offers_canvas.name = "ShopOfferOverlayCanvas"
	_offers_canvas.layer = OFFER_CANVAS_LAYER
	owner_node.add_child(_offers_canvas)

	_offers_root = Control.new()
	_offers_root.name = "ShopOfferRoot"
	_offers_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_offers_canvas.add_child(_offers_root)
	_offers_root.set_anchors_preset(Control.PRESET_FULL_RECT, true)


func _render_offer_buttons(run_manager: Node, item_db: Node, ornament_db: Node) -> void:
	if _owner_node == null or not _owner_node.is_inside_tree():
		return
	_create_offer_overlay(_owner_node)
	_clear_offer_buttons()
	if _offers_root == null or run_manager == null or item_db == null:
		return

	var offers: Array = _get_current_offers(run_manager, item_db, ornament_db)
	var tool_db := _get_tool_database()
	var button_count: int = mini(offers.size(), OFFER_DESIGN_RECTS.size())
	for index in range(button_count):
		var offer: Dictionary = Dictionary(offers[index])
		var button := Button.new()
		button.name = "ShopOfferButton%d" % index
		button.flat = true
		button.focus_mode = Control.FOCUS_NONE
		button.mouse_filter = Control.MOUSE_FILTER_STOP
		button.clip_contents = true
		button.set_meta("offer", offer)
		button.text = ""
		button.tooltip_text = ""
		button.add_theme_font_size_override("font_size", 20)
		button.add_theme_color_override("font_color", OFFER_TEXT_COLOR)
		button.add_theme_color_override("font_hover_color", Color(0.05, 0.03, 0.01, 1.0))
		_apply_offer_button_style(button)
		_build_offer_content(button, offer, item_db, tool_db, ornament_db, run_manager)
		button.pressed.connect(_on_offer_button_pressed.bind(button, offer, run_manager, item_db))
		button.mouse_entered.connect(_show_offer_tooltip.bind(offer, item_db, ornament_db, tool_db))
		button.mouse_exited.connect(_hide_offer_tooltip)
		_offers_root.add_child(button)
		_offer_buttons.append(button)
	_layout_offer_buttons()
	_refresh_offer_buttons(run_manager)


func _clear_offer_buttons() -> void:
	for button in _offer_buttons:
		if is_instance_valid(button):
			button.queue_free()
	_offer_buttons.clear()


func _on_offer_button_pressed(button: Button, offer: Dictionary, run_manager: Node, item_db: Node) -> void:
	if button == null or run_manager == null or item_db == null:
		return
	var purchase_offer: Dictionary = offer.duplicate(true)
	if str(purchase_offer.get("type", "")) == ShopGenerator.TYPE_ITEM or str(purchase_offer.get("type", "")) == ShopGenerator.TYPE_TOOL:
		purchase_offer["item_destination"] = "staging"
		purchase_offer["destination"] = "staging"
	if run_manager.has_method("buy_shop_offer") and bool(run_manager.buy_shop_offer(purchase_offer, item_db)):
		button.set_meta("purchased", true)
		button.disabled = true
		_restore_backpack_from_run(run_manager, item_db)
		_render_backpack(run_manager, item_db)
		_refresh_offer_buttons(run_manager)
		return
	print("[HubShop] buy offer failed: ", offer.get("title", ""))


func _refresh_offer_buttons(run_manager: Node) -> void:
	_update_shards_label(run_manager)
	var current_shards := 0
	if run_manager != null:
		current_shards = int(run_manager.get("current_shards"))
	for button in _offer_buttons:
		if not is_instance_valid(button) or not button.has_meta("offer"):
			continue
		var offer: Dictionary = Dictionary(button.get_meta("offer"))
		var is_purchased := bool(button.get_meta("purchased", false)) or _is_offer_purchased(run_manager, offer)
		var price := _get_offer_price(offer, run_manager)
		button.disabled = is_purchased or current_shards < price
		button.text = ""
		_update_offer_content(button, offer, run_manager, is_purchased)


func _get_current_offers(run_manager: Node, item_db: Node, ornament_db: Node) -> Array:
	if run_manager == null or item_db == null or not run_manager.has_method("generate_current_shop_offers"):
		return []
	return Array(run_manager.generate_current_shop_offers(item_db, ornament_db, ShopGenerator.DEFAULT_OFFER_COUNT))


func _format_offer_text(offer: Dictionary, run_manager: Node) -> String:
	var title := str(offer.get("title", "商品"))
	var price := _get_offer_price(offer, run_manager)
	var kind_text := _get_offer_kind_text(offer)
	return "%s\n%d 碎片\n%s" % [title, price, kind_text]


func _get_offer_kind_text(offer: Dictionary) -> String:
	match str(offer.get("type", "")):
		ShopGenerator.TYPE_ITEM:
			return "购买后拖入背包"
		ShopGenerator.TYPE_ORNAMENT:
			return "饰品"
		ShopGenerator.TYPE_TOOL:
			return "道具/待放置"
	return "商品"



func _get_offer_price(offer: Dictionary, run_manager: Node) -> int:
	if run_manager != null and run_manager.has_method("get_current_shop_offer_price"):
		return int(run_manager.get_current_shop_offer_price(offer))
	return int(offer.get("price", 0))


func _is_offer_purchased(run_manager: Node, offer: Dictionary) -> bool:
	if run_manager != null and run_manager.has_method("is_current_shop_offer_purchased"):
		return bool(run_manager.is_current_shop_offer_purchased(offer))
	return false


func _show_offer_tooltip(offer: Dictionary, item_db: Node, ornament_db: Node, tool_db: Node) -> void:
	match str(offer.get("type", "")):
		ShopGenerator.TYPE_ITEM:
			if item_db == null or not item_db.has_method("get_item_by_id"):
				GlobalTooltip.hide()
				return
			var item_data = item_db.get_item_by_id(str(offer.get("id", "")))
			if item_data != null:
				GlobalTooltip.show_item(item_data)
			else:
				GlobalTooltip.hide()
		ShopGenerator.TYPE_ORNAMENT:
			if ornament_db == null or not ornament_db.has_method("get_ornament_by_id"):
				GlobalTooltip.hide()
				return
			var ornament = ornament_db.get_ornament_by_id(str(offer.get("id", "")))
			if ornament != null and GlobalTooltip.has_method("show_text"):
				var ornament_body := _tooltip_body_without_repeated_title(ornament.ornament_name, ornament.get_tooltip_text())
				GlobalTooltip.show_text(ornament.ornament_name, ornament_body)
			else:
				GlobalTooltip.hide()
		ShopGenerator.TYPE_TOOL:
			if tool_db == null or not tool_db.has_method("get_tool_by_id"):
				GlobalTooltip.hide()
				return
			var tool = tool_db.get_tool_by_id(str(offer.get("id", "")))
			if tool != null and GlobalTooltip.has_method("show_text"):
				var tool_body := _tooltip_body_without_repeated_title(tool.tool_name, tool.get_tooltip_text(1))
				GlobalTooltip.show_text(tool.tool_name, tool_body)
			else:
				GlobalTooltip.hide()
		_:
			GlobalTooltip.hide()



func _hide_offer_tooltip() -> void:
	GlobalTooltip.hide()


func _build_offer_content(button: Button, offer: Dictionary, item_db: Node, tool_db: Node, ornament_db: Node, run_manager: Node) -> void:
	var content := Control.new()
	content.name = "OfferContent"
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(content)

	var visual_area := Control.new()
	visual_area.name = "VisualArea"
	visual_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(visual_area)

	_add_offer_visual(visual_area, offer, item_db, tool_db, ornament_db)

	var title_label := _make_offer_label("TitleLabel", str(offer.get("title", "鍟嗗搧")), 18, OFFER_TEXT_COLOR)
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	content.add_child(title_label)

	var price_label := _make_offer_label("PriceLabel", "", 30, OFFER_PRICE_COLOR)
	price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	price_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	content.add_child(price_label)

	var sold_overlay := ColorRect.new()
	sold_overlay.name = "SoldOverlay"
	sold_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sold_overlay.color = OFFER_SOLD_OVERLAY_COLOR
	sold_overlay.visible = false
	button.add_child(sold_overlay)

	var sold_label := _make_offer_label("SoldLabel", "已购买", 24, Color(1.0, 0.93, 0.72, 1.0))
	sold_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sold_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	sold_overlay.add_child(sold_label)

	_update_offer_content(button, offer, run_manager, false)


func _add_offer_visual(visual_area: Control, offer: Dictionary, item_db: Node, tool_db: Node, ornament_db: Node) -> void:
	match str(offer.get("type", "")):
		ShopGenerator.TYPE_ITEM:
			_add_item_offer_visual(visual_area, offer, item_db)
		ShopGenerator.TYPE_TOOL:
			_add_tool_offer_visual(visual_area, offer, tool_db)
		ShopGenerator.TYPE_ORNAMENT:
			_add_ornament_offer_visual(visual_area, offer, ornament_db)
		_:
			_add_text_offer_visual(visual_area, "?")


func _add_item_offer_visual(visual_area: Control, offer: Dictionary, item_db: Node) -> void:
	var item_data = item_db.get_item_by_id(str(offer.get("id", ""))) if item_db != null and item_db.has_method("get_item_by_id") else null
	if item_data == null or item_data.icon == null:
		_add_text_offer_visual(visual_area, "物")
		return
	var icon := TextureRect.new()
	icon.name = "OfferItemIcon"
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.texture = _trim_texture_to_alpha(item_data.icon)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	visual_area.add_child(icon)


func _add_tool_offer_visual(visual_area: Control, offer: Dictionary, tool_db: Node) -> void:
	var tool = tool_db.get_tool_by_id(str(offer.get("id", ""))) if tool_db != null and tool_db.has_method("get_tool_by_id") else null
	if tool == null or tool.icon == null:
		_add_text_offer_visual(visual_area, "具")
		return
	var icon := TextureRect.new()
	icon.name = "OfferToolIcon"
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.texture = _trim_texture_to_alpha(tool.icon)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	visual_area.add_child(icon)


func _add_ornament_offer_visual(visual_area: Control, offer: Dictionary, ornament_db: Node) -> void:
	var ornament = ornament_db.get_ornament_by_id(str(offer.get("id", ""))) if ornament_db != null and ornament_db.has_method("get_ornament_by_id") else null
	if ornament != null and ornament.icon != null:
		var icon := TextureRect.new()
		icon.name = "OfferOrnamentIcon"
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.texture = _trim_texture_to_alpha(ornament.icon)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		visual_area.add_child(icon)
		return

	var tag := PanelContainer.new()
	tag.name = "OfferOrnamentTag"
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_apply_ornament_tag_style(tag, str(offer.get("rarity", "")))
	visual_area.add_child(tag)

	var label := _make_offer_label("OrnamentGlyph", "饰", 28, Color(0.2, 0.09, 0.04, 1.0))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tag.add_child(label)


func _add_text_offer_visual(visual_area: Control, text: String) -> void:
	var label := _make_offer_label("OfferTextVisual", text, 28, Color(0.2, 0.09, 0.04, 1.0))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	visual_area.add_child(label)


func _make_offer_label(label_name: String, text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.name = label_name
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.text = text
	label.clip_text = true
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(1.0, 0.92, 0.72, 0.45))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	return label


func _update_offer_content(button: Button, offer: Dictionary, run_manager: Node, is_purchased: bool) -> void:
	var content := button.get_node_or_null("OfferContent") as Control
	if content == null:
		return
	var title_label := content.get_node_or_null("TitleLabel") as Label
	if title_label != null:
		title_label.text = str(offer.get("title", "商品"))
	var price_label := content.get_node_or_null("PriceLabel") as Label
	if price_label != null:
		price_label.text = "%d" % _get_offer_price(offer, run_manager)
	content.modulate.a = 0.5 if button.disabled and not is_purchased else 1.0
	var sold_overlay := button.get_node_or_null("SoldOverlay") as ColorRect
	if sold_overlay != null:
		sold_overlay.visible = is_purchased
		var sold_label := sold_overlay.get_node_or_null("SoldLabel") as Label
		if sold_label != null:
			sold_label.text = "已购买"


func _layout_offer_content(button: Button) -> void:
	var content := button.get_node_or_null("OfferContent") as Control
	if content == null:
		return
	content.position = Vector2.ZERO
	content.size = button.size

	var visual_area := content.get_node_or_null("VisualArea") as Control
	if visual_area != null:
		visual_area.position = Vector2(0.0, 0.0)
		visual_area.size = Vector2(button.size.x, button.size.y * 0.66)
		_layout_offer_visual_area(visual_area)

	var title_label := content.get_node_or_null("TitleLabel") as Label
	if title_label != null:
		title_label.position = Vector2(0.0, button.size.y * 0.63)
		title_label.size = Vector2(button.size.x, button.size.y * 0.16)
	var price_label := content.get_node_or_null("PriceLabel") as Label
	if price_label != null:
		price_label.position = Vector2(0.0, button.size.y * 0.76)
		price_label.size = Vector2(button.size.x, button.size.y * 0.23)
	var sold_overlay := button.get_node_or_null("SoldOverlay") as ColorRect
	if sold_overlay != null:
		sold_overlay.position = Vector2.ZERO
		sold_overlay.size = button.size
		var sold_label := sold_overlay.get_node_or_null("SoldLabel") as Label
		if sold_label != null:
			sold_label.position = Vector2.ZERO
			sold_label.size = sold_overlay.size


func _layout_offer_visual_area(visual_area: Control) -> void:
	var inset_rect := Rect2(OFFER_ITEM_MARGIN, visual_area.size - OFFER_ITEM_MARGIN * 2.0)
	if inset_rect.size.x <= 0.0 or inset_rect.size.y <= 0.0:
		return
	var icon_rect := _centered_offer_icon_rect(inset_rect)
	var item_icon := visual_area.get_node_or_null("OfferItemIcon") as TextureRect
	if item_icon != null:
		item_icon.position = icon_rect.position
		item_icon.size = icon_rect.size
	var tool_icon := visual_area.get_node_or_null("OfferToolIcon") as TextureRect
	if tool_icon != null:
		tool_icon.position = icon_rect.position
		tool_icon.size = icon_rect.size
	var ornament_icon := visual_area.get_node_or_null("OfferOrnamentIcon") as TextureRect
	if ornament_icon != null:
		ornament_icon.position = icon_rect.position
		ornament_icon.size = icon_rect.size
	var ornament_tag := visual_area.get_node_or_null("OfferOrnamentTag") as Control
	if ornament_tag != null:
		var size := Vector2(minf(inset_rect.size.x, inset_rect.size.y * 0.78), inset_rect.size.y)
		ornament_tag.position = inset_rect.position + (inset_rect.size - size) * 0.5
		ornament_tag.size = size
		var glyph := ornament_tag.get_node_or_null("OrnamentGlyph") as Label
		if glyph != null:
			glyph.position = Vector2.ZERO
			glyph.size = size
	var text_visual := visual_area.get_node_or_null("OfferTextVisual") as Label
	if text_visual != null:
		text_visual.position = inset_rect.position
		text_visual.size = inset_rect.size


func _centered_offer_icon_rect(container_rect: Rect2) -> Rect2:
	var edge := minf(container_rect.size.x, container_rect.size.y)
	var icon_size := Vector2(edge, edge)
	return Rect2(container_rect.position + (container_rect.size - icon_size) * 0.5, icon_size)


func _trim_texture_to_alpha(texture: Texture2D) -> Texture2D:
	if texture == null:
		return null
	var cache_key := _get_offer_texture_cache_key(texture)
	if _trimmed_offer_texture_cache.has(cache_key):
		return _trimmed_offer_texture_cache[cache_key]
	var image := texture.get_image()
	if image == null or image.get_width() <= 0 or image.get_height() <= 0:
		_trimmed_offer_texture_cache[cache_key] = texture
		return texture
	var rect := _find_opaque_image_rect(image, 0.02, 4)
	if rect.size.x <= 0 or rect.size.y <= 0:
		_trimmed_offer_texture_cache[cache_key] = texture
		return texture
	if rect.position == Vector2i.ZERO and rect.size == Vector2i(image.get_width(), image.get_height()):
		_trimmed_offer_texture_cache[cache_key] = texture
		return texture
	var atlas := AtlasTexture.new()
	atlas.atlas = texture
	atlas.region = Rect2(Vector2(rect.position), Vector2(rect.size))
	_trimmed_offer_texture_cache[cache_key] = atlas
	return atlas


func _get_offer_texture_cache_key(texture: Texture2D) -> String:
	if texture.resource_path != "":
		return texture.resource_path
	return str(texture.get_instance_id())


func _find_opaque_image_rect(image: Image, alpha_threshold: float, padding: int) -> Rect2i:
	var width := image.get_width()
	var height := image.get_height()
	var min_x := width
	var min_y := height
	var max_x := -1
	var max_y := -1
	for y in range(height):
		for x in range(width):
			if image.get_pixel(x, y).a <= alpha_threshold:
				continue
			min_x = mini(min_x, x)
			min_y = mini(min_y, y)
			max_x = maxi(max_x, x)
			max_y = maxi(max_y, y)
	if max_x < min_x or max_y < min_y:
		return Rect2i()
	min_x = maxi(0, min_x - padding)
	min_y = maxi(0, min_y - padding)
	max_x = mini(width - 1, max_x + padding)
	max_y = mini(height - 1, max_y + padding)
	return Rect2i(Vector2i(min_x, min_y), Vector2i(max_x - min_x + 1, max_y - min_y + 1))


func _tooltip_body_without_repeated_title(title: String, body: String) -> String:
	var trimmed := body.strip_edges()
	if trimmed == title:
		return ""
	var prefix := title + "\n"
	if trimmed.begins_with(prefix):
		return trimmed.substr(prefix.length()).strip_edges()
	return trimmed


func _apply_ornament_tag_style(panel: PanelContainer, rarity: String) -> void:
	var style := StyleBoxFlat.new()
	match rarity:
		"稀有":
			style.bg_color = Color(0.62, 0.48, 0.84, 0.46)
			style.border_color = Color(0.32, 0.18, 0.48, 0.5)
		"进阶":
			style.bg_color = Color(0.54, 0.72, 0.6, 0.44)
			style.border_color = Color(0.18, 0.36, 0.22, 0.48)
		_:
			style.bg_color = Color(0.9, 0.76, 0.5, 0.46)
			style.border_color = Color(0.35, 0.19, 0.08, 0.45)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	panel.add_theme_stylebox_override("panel", style)


func _update_shards_label(run_manager: Node) -> void:
	if _shards_label == null:
		return
	var current_shards := 0
	if run_manager != null:
		current_shards = int(run_manager.get("current_shards"))
	_shards_label.text = "碎片: %d" % current_shards


func _layout_all(viewport_size: Vector2, place_backpack_at_start: bool) -> void:
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return
	_last_viewport_size = viewport_size
	if _intro_frame != null and is_instance_valid(_intro_frame):
		_intro_frame.position = Vector2.ZERO
		_intro_frame.size = viewport_size
	if _backpack_root != null and is_instance_valid(_backpack_root):
		_backpack_root.size = viewport_size
	if _offers_root != null and is_instance_valid(_offers_root):
		_offers_root.size = viewport_size
	_layout_backpack_panel(place_backpack_at_start)
	_layout_shop_skull_overlay()
	_layout_offer_buttons()
	_layout_buyback_button()
	_layout_exit_button()


func _layout_backpack_panel(place_at_start: bool) -> void:
	if _backpack_panel == null or not is_instance_valid(_backpack_panel):
		return
	var target_rect := _design_rect_to_viewport(BACKPACK_DESIGN_RECT)
	_backpack_panel.size = target_rect.size
	var target_position := target_rect.position
	if place_at_start:
		target_position.y += BACKPACK_RISE_OFFSET_Y * _get_cover_scale()
	_backpack_panel.position = target_position
	if _backpack_art != null:
		_backpack_art.position = Vector2.ZERO
		_backpack_art.size = target_rect.size
	if _shards_label != null:
		_shards_label.position = Vector2(target_rect.size.x * 0.16, target_rect.size.y * 0.29)
		_shards_label.size = Vector2(target_rect.size.x * 0.68, target_rect.size.y * 0.055)
	if _pending_item_panel != null:
		_pending_item_panel.position = Vector2(target_rect.size.x * 0.08, target_rect.size.y * 0.08)
		_pending_item_panel.size = Vector2(target_rect.size.x * 0.84, target_rect.size.y * 0.2)
		var pending_label := _pending_item_panel.get_node_or_null("PendingItemLabel") as Label
		if pending_label != null:
			pending_label.position = Vector2.ZERO
			pending_label.size = Vector2(_pending_item_panel.size.x, target_rect.size.y * 0.045)
		if _pending_item_area != null:
			_pending_item_area.position = Vector2(0.0, target_rect.size.y * 0.05)
			_pending_item_area.size = Vector2(_pending_item_panel.size.x, _pending_item_panel.size.y - _pending_item_area.position.y)
	if _backpack_ui != null:
		var grid_rect := _get_backpack_grid_rect(target_rect.size)
		_backpack_ui.position = grid_rect.position
		_backpack_ui.size = grid_rect.size
		_backpack_ui.custom_minimum_size = grid_rect.size


func _layout_offer_buttons() -> void:
	for index in range(_offer_buttons.size()):
		var button := _offer_buttons[index]
		if not is_instance_valid(button) or index >= OFFER_DESIGN_RECTS.size():
			continue
		var target_rect := _design_rect_to_viewport(OFFER_DESIGN_RECTS[index])
		button.position = target_rect.position
		button.size = target_rect.size
		_layout_offer_content(button)


func _create_buyback_button(owner_node: Node) -> void:
	if _offers_root == null:
		_create_offer_overlay(owner_node)
	if _offers_root == null:
		return
	if _buyback_button != null and is_instance_valid(_buyback_button):
		return
	_buyback_button = Button.new()
	_buyback_button.name = "ShopBuybackButton"
	_buyback_button.text = "回购"
	_buyback_button.flat = true
	_buyback_button.focus_mode = Control.FOCUS_NONE
	_buyback_button.mouse_filter = Control.MOUSE_FILTER_STOP
	_buyback_button.rotation_degrees = -6.0
	_buyback_button.pivot_offset = SHOP_BUYBACK_DESIGN_RECT.size * 0.5
	_buyback_button.add_theme_font_size_override("font_size", 40)
	_buyback_button.add_theme_color_override("font_color", Color.WHITE)
	_buyback_button.add_theme_color_override("font_hover_color", Color.WHITE)
	_buyback_button.add_theme_color_override("font_pressed_color", Color.WHITE)
	_buyback_button.add_theme_color_override("font_disabled_color", Color(1.0, 1.0, 1.0, 0.55))
	_apply_exit_button_style(_buyback_button)
	_buyback_button.mouse_entered.connect(_on_buyback_button_mouse_entered)
	_buyback_button.mouse_exited.connect(_on_buyback_button_mouse_exited)
	_offers_root.add_child(_buyback_button)


func _layout_buyback_button() -> void:
	if _buyback_button == null or not is_instance_valid(_buyback_button):
		return
	var target_rect := _design_rect_to_viewport(SHOP_BUYBACK_DESIGN_RECT)
	_buyback_button.position = target_rect.position
	_buyback_button.size = target_rect.size
	_buyback_button.pivot_offset = target_rect.size * 0.5


func _on_buyback_button_mouse_entered() -> void:
	_buyback_button_hovered = true
	_update_buyback_button_scale()


func _on_buyback_button_mouse_exited() -> void:
	_buyback_button_hovered = false
	_update_buyback_button_scale()


func _is_buyback_drop_position(mouse_pos: Vector2) -> bool:
	if _buyback_button == null or not is_instance_valid(_buyback_button):
		return false
	return _buyback_button.get_global_rect().has_point(mouse_pos)


func _set_buyback_drag_active(active: bool, item_ui: Control = null) -> void:
	var target_item := item_ui if active else _buyback_hover_item
	if _buyback_drag_active == active and _buyback_hover_item == target_item:
		return
	if _buyback_hover_item != null and _buyback_hover_item != target_item:
		_tween_buyback_item_scale(_buyback_hover_item, Vector2.ONE)
	_buyback_drag_active = active
	_buyback_hover_item = target_item if active else null
	_update_buyback_button_scale()
	if target_item != null:
		_tween_buyback_item_scale(target_item, Vector2.ONE * (SHOP_BUYBACK_ITEM_HOVER_SCALE if active else 1.0))


func _update_buyback_button_scale() -> void:
	var target_scale := SHOP_BUYBACK_HOVER_SCALE if _buyback_drag_active or _buyback_button_hovered else 1.0
	_tween_buyback_button_scale(Vector2.ONE * target_scale)


func _tween_buyback_button_scale(target_scale: Vector2) -> void:
	if _buyback_button == null or not is_instance_valid(_buyback_button) or _is_closing:
		return
	if _buyback_button_tween != null:
		_buyback_button_tween.kill()
	_buyback_button_tween = _buyback_button.create_tween()
	_buyback_button_tween.set_trans(Tween.TRANS_QUAD)
	_buyback_button_tween.set_ease(Tween.EASE_OUT)
	_buyback_button_tween.tween_property(_buyback_button, "scale", target_scale, 0.12)


func _tween_buyback_item_scale(item_ui: Control, target_scale: Vector2) -> void:
	if item_ui == null or not is_instance_valid(item_ui):
		return
	item_ui.pivot_offset = item_ui.size * 0.5
	if _buyback_item_tween != null:
		_buyback_item_tween.kill()
	_buyback_item_tween = item_ui.create_tween()
	_buyback_item_tween.set_trans(Tween.TRANS_QUAD)
	_buyback_item_tween.set_ease(Tween.EASE_OUT)
	_buyback_item_tween.tween_property(item_ui, "scale", target_scale, 0.12)


func _reset_buyback_feedback(immediate: bool = false) -> void:
	_buyback_drag_active = false
	_buyback_button_hovered = false
	if _buyback_button_tween != null:
		_buyback_button_tween.kill()
		_buyback_button_tween = null
	if _buyback_item_tween != null:
		_buyback_item_tween.kill()
		_buyback_item_tween = null
	if _buyback_button != null and is_instance_valid(_buyback_button):
		_buyback_button.scale = Vector2.ONE
	if _buyback_hover_item != null and is_instance_valid(_buyback_hover_item):
		if immediate:
			_buyback_hover_item.scale = Vector2.ONE
		else:
			_tween_buyback_item_scale(_buyback_hover_item, Vector2.ONE)
	_buyback_hover_item = null


func _layout_shop_skull_overlay() -> void:
	if _shop_skull_root == null or not is_instance_valid(_shop_skull_root):
		return
	if is_equal_approx(_shop_skull_root.anchor_left, _shop_skull_root.anchor_right) and is_equal_approx(_shop_skull_root.anchor_top, _shop_skull_root.anchor_bottom):
		_shop_skull_root.size = _last_viewport_size
	for index in range(_shop_skull_nodes.size()):
		var skull := _shop_skull_nodes[index]
		if not is_instance_valid(skull) or index >= SHOP_SKULL_DESIGN_RECTS.size():
			continue
		var target_rect := _design_rect_to_viewport(SHOP_SKULL_DESIGN_RECTS[index])
		skull.position = target_rect.position
		skull.size = target_rect.size


func _update_shop_skull_fade(frame_index: int, frame_count: int) -> void:
	if frame_count <= 0:
		_set_shop_skull_alpha(1.0)
		return
	var progress := float(frame_index + 1) / float(frame_count)
	var fade_range := maxf(0.001, SHOP_SKULL_FADE_END_PROGRESS - SHOP_SKULL_FADE_START_PROGRESS)
	var alpha := clampf((progress - SHOP_SKULL_FADE_START_PROGRESS) / fade_range, 0.0, 1.0)
	_set_shop_skull_alpha(alpha * alpha * (3.0 - 2.0 * alpha))


func _set_shop_skull_alpha(alpha: float) -> void:
	if _shop_skull_root == null or not is_instance_valid(_shop_skull_root):
		return
	_shop_skull_root.modulate.a = clampf(alpha, 0.0, 1.0)


func _animate_backpack_in() -> void:
	if _backpack_panel == null or not is_instance_valid(_backpack_panel):
		return
	var target_rect := _design_rect_to_viewport(BACKPACK_DESIGN_RECT)
	var tween := _backpack_panel.create_tween()
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(_backpack_panel, "position:y", target_rect.position.y, BACKPACK_RISE_DURATION)


func _animate_backpack_out(duration: float) -> void:
	if _backpack_panel == null or not is_instance_valid(_backpack_panel):
		return
	var target_y := _last_viewport_size.y + 80.0 * _get_cover_scale()
	var tween := _backpack_panel.create_tween()
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_IN)
	tween.tween_property(_backpack_panel, "position:y", target_y, maxf(duration, 0.1))
	await tween.finished


func _play_close_animation(frame_rate: float) -> void:
	var owner_node := _owner_node
	if owner_node == null or not owner_node.is_inside_tree():
		return
	var frame_paths: Array = AssetPaths.shop_intro_frame_paths()
	frame_paths.reverse()
	var frame_delay := 1.0 / maxf(frame_rate, 1.0)
	_animate_backpack_out(float(frame_paths.size()) * frame_delay)
	for frame_index in range(frame_paths.size()):
		var frame_path = frame_paths[frame_index]
		if owner_node == null or not owner_node.is_inside_tree():
			break
		var texture: Texture2D = AssetPaths.load_texture(str(frame_path)) as Texture2D
		if texture == null:
			continue
		if _intro_frame != null and is_instance_valid(_intro_frame):
			_intro_frame.texture = texture
		_update_shop_skull_fade(frame_paths.size() - frame_index - 1, frame_paths.size())
		await owner_node.get_tree().create_timer(frame_delay).timeout


func _design_rect_to_viewport(design_rect: Rect2) -> Rect2:
	var cover_scale := _get_cover_scale()
	var rendered_size := DESIGN_SIZE * cover_scale
	var rendered_offset := (_last_viewport_size - rendered_size) * 0.5
	return Rect2(rendered_offset + design_rect.position * cover_scale, design_rect.size * cover_scale)


func _get_backpack_grid_rect(panel_size: Vector2) -> Rect2:
	var scale := Vector2(
		panel_size.x / PLAYABLE_BAG_SOURCE_SIZE.x,
		panel_size.y / PLAYABLE_BAG_SOURCE_SIZE.y
	)
	return Rect2(
		PLAYABLE_BAG_GRID_SOURCE_RECT.position * scale,
		PLAYABLE_BAG_GRID_SOURCE_RECT.size * scale
	)


func _get_cover_scale() -> float:
	if _last_viewport_size.x <= 0.0 or _last_viewport_size.y <= 0.0:
		return 1.0
	return maxf(_last_viewport_size.x / DESIGN_SIZE.x, _last_viewport_size.y / DESIGN_SIZE.y)


func _apply_panel_style(panel: PanelContainer) -> void:
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.78, 0.62, 0.43, 0.72)
	panel_style.border_color = Color(0.26, 0.16, 0.08, 0.72)
	panel_style.set_border_width_all(3)
	panel_style.set_corner_radius_all(18)
	panel.add_theme_stylebox_override("panel", panel_style)


func _apply_offer_button_style(button: Button) -> void:
	var empty := StyleBoxEmpty.new()
	button.add_theme_stylebox_override("normal", empty)
	button.add_theme_stylebox_override("hover", empty)
	button.add_theme_stylebox_override("pressed", empty)
	button.add_theme_stylebox_override("disabled", empty)


func _create_exit_button(owner_node: Node) -> void:
	if _offers_root == null:
		_create_offer_overlay(owner_node)
	if _offers_root == null:
		return
	if _exit_button != null and is_instance_valid(_exit_button):
		return
	_exit_button = Button.new()
	_exit_button.name = "ShopExitButton"
	_exit_button.text = "退出"
	_exit_button.flat = true
	_exit_button.focus_mode = Control.FOCUS_NONE
	_exit_button.mouse_filter = Control.MOUSE_FILTER_STOP
	_exit_button.rotation_degrees = -6.0
	_exit_button.pivot_offset = SHOP_EXIT_DESIGN_RECT.size * 0.5
	_exit_button.add_theme_font_size_override("font_size", 38)
	_exit_button.add_theme_color_override("font_color", Color.BLACK)
	_exit_button.add_theme_color_override("font_hover_color", Color.BLACK)
	_exit_button.add_theme_color_override("font_pressed_color", Color.BLACK)
	_apply_exit_button_style(_exit_button)
	_exit_button.mouse_entered.connect(_on_exit_button_mouse_entered)
	_exit_button.mouse_exited.connect(_on_exit_button_mouse_exited)
	_exit_button.pressed.connect(func(): await request_close_with_animation(60.0))
	_offers_root.add_child(_exit_button)


func _layout_exit_button() -> void:
	if _exit_button == null or not is_instance_valid(_exit_button):
		return
	var target_rect := _design_rect_to_viewport(SHOP_EXIT_DESIGN_RECT)
	_exit_button.position = target_rect.position
	_exit_button.size = target_rect.size
	_exit_button.pivot_offset = target_rect.size * 0.5


func _apply_exit_button_style(button: Button) -> void:
	var empty := StyleBoxEmpty.new()
	button.add_theme_stylebox_override("normal", empty)
	button.add_theme_stylebox_override("hover", empty)
	button.add_theme_stylebox_override("pressed", empty)
	button.add_theme_stylebox_override("disabled", empty)


func _on_exit_button_mouse_entered() -> void:
	_tween_exit_button_scale(Vector2.ONE * SHOP_EXIT_HOVER_SCALE)


func _on_exit_button_mouse_exited() -> void:
	_tween_exit_button_scale(Vector2.ONE)


func _tween_exit_button_scale(target_scale: Vector2) -> void:
	if _exit_button == null or not is_instance_valid(_exit_button) or _is_closing:
		return
	var tween := _exit_button.create_tween()
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(_exit_button, "scale", target_scale, 0.12)


func _set_shop_interactable(enabled: bool) -> void:
	for button in _offer_buttons:
		if is_instance_valid(button):
			button.disabled = not enabled
	if _exit_button != null and is_instance_valid(_exit_button):
		_exit_button.disabled = not enabled
	if _buyback_button != null and is_instance_valid(_buyback_button):
		_buyback_button.disabled = not enabled
	if _backpack_panel != null and is_instance_valid(_backpack_panel):
		_backpack_panel.mouse_filter = Control.MOUSE_FILTER_STOP if enabled else Control.MOUSE_FILTER_IGNORE
	if _intro_frame != null and is_instance_valid(_intro_frame):
		_intro_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _hide_tooltips() -> void:
	GlobalTooltip.hide()


func _get_run_manager() -> Node:
	if _owner_node == null:
		return null
	return _owner_node.get_node_or_null("/root/RunManager")


func _get_item_database() -> Node:
	if _owner_node == null:
		return null
	return _owner_node.get_node_or_null("/root/ItemDatabase")


func _get_tool_database() -> Node:
	if _owner_node == null:
		return null
	return _owner_node.get_node_or_null("/root/ToolDatabase")
