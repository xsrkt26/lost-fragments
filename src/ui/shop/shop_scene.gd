extends Control

## 商店场景：允许玩家购买物品和饰品

const RouteConfig = preload("res://src/core/route/route_config.gd")
const ShopGenerator = preload("res://src/core/rewards/shop_generator.gd")
const BackpackUIScene = preload("res://src/ui/backpack/backpack_ui.tscn")
const ItemUIScene = preload("res://src/ui/item/item_ui.tscn")

const SHOP_OFFER_COUNT := ShopGenerator.DEFAULT_OFFER_COUNT

@onready var shard_label = $MarginContainer/VBoxContainer/Header/ShardLabel
@onready var shelf = $MarginContainer/VBoxContainer/ScrollContainer/GridContainer
@onready var refresh_button = $MarginContainer/VBoxContainer/Header/RefreshButton
@onready var back_button = $MarginContainer/VBoxContainer/Header/BackButton

var shop_backpack_manager: BackpackManager = null
var shop_backpack_ui: Control = null
var sell_hint_label: Label = null

func _ready():
	print("[Shop] 欢迎光临梦境商店")
	GlobalInput.set_context(GlobalInput.Context.UI)
	_ensure_shop_layout()
	_update_shard_display()
	_populate_shelf()
	_render_backpack_for_sale()
	
	refresh_button.pressed.connect(_on_refresh_pressed)
	back_button.pressed.connect(_on_back_pressed)

func _input(event):
	# 输入权限检查
	if not GlobalInput.can_cancel(): return

	if event.is_action_pressed("ui_cancel") or Input.is_key_pressed(KEY_ESCAPE):
		_on_back_pressed()

func _update_shard_display():
	var rm = get_node_or_null("/root/RunManager")
	if rm:
		shard_label.text = "碎片: " + str(rm.current_shards)
	_update_refresh_button()

func _update_refresh_button() -> void:
	var rm = get_node_or_null("/root/RunManager")
	if rm == null or not rm.has_method("get_current_shop_refresh_cost"):
		refresh_button.disabled = true
		return
	var cost = rm.get_current_shop_refresh_cost()
	refresh_button.text = "刷新 %d" % cost
	refresh_button.tooltip_text = "刷新当前商店库存"
	refresh_button.disabled = int(rm.current_shards) < cost

func _ensure_shop_layout() -> void:
	var root_vbox := $MarginContainer/VBoxContainer as VBoxContainer
	var scroll_container := $MarginContainer/VBoxContainer/ScrollContainer as ScrollContainer
	if root_vbox == null or scroll_container == null:
		return
	if scroll_container.get_parent() is HBoxContainer:
		return
	root_vbox.remove_child(scroll_container)

	var body := HBoxContainer.new()
	body.name = "ShopBody"
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 32)
	root_vbox.add_child(body)

	scroll_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(scroll_container)
	shelf.columns = 2

	var side_panel := PanelContainer.new()
	side_panel.name = "BackpackSellPanel"
	side_panel.custom_minimum_size = Vector2(430, 0)
	side_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(side_panel)

	var side_vbox := VBoxContainer.new()
	side_vbox.name = "BackpackSellBox"
	side_vbox.add_theme_constant_override("separation", 12)
	side_panel.add_child(side_vbox)

	var title := Label.new()
	title.text = "背包售卖"
	title.add_theme_font_size_override("font_size", 30)
	side_vbox.add_child(title)

	sell_hint_label = Label.new()
	sell_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sell_hint_label.text = "右键或双击背包物品售卖；售价为买入价的一半。根源之梦不可售卖。"
	side_vbox.add_child(sell_hint_label)

	shop_backpack_ui = BackpackUIScene.instantiate()
	shop_backpack_ui.name = "ShopBackpackUI"
	shop_backpack_ui.custom_minimum_size = Vector2(410, 410)
	shop_backpack_ui.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shop_backpack_ui.size_flags_vertical = Control.SIZE_EXPAND_FILL
	side_vbox.add_child(shop_backpack_ui)

func _populate_shelf():
	var rm = get_node_or_null("/root/RunManager")
	var item_db = get_node_or_null("/root/ItemDatabase")
	var ornament_db = get_node_or_null("/root/OrnamentDatabase")
	if rm == null or item_db == null:
		return
	
	for child in shelf.get_children():
		child.queue_free()
	
	var offers = rm.generate_current_shop_offers(item_db, ornament_db, SHOP_OFFER_COUNT) if rm.has_method("generate_current_shop_offers") else []
	for offer in offers:
		_add_shop_offer(offer)
	_update_refresh_button()

func _add_shop_offer(offer: Dictionary):
	var btn = Button.new()
	btn.set_meta("offer", offer)
	btn.text = _format_offer_text(offer)
	btn.tooltip_text = str(offer.get("description", ""))
	btn.custom_minimum_size = Vector2(200, 100)
	btn.mouse_entered.connect(func(): _show_offer_tooltip(offer))
	btn.mouse_exited.connect(_hide_offer_tooltip)
	btn.pressed.connect(func(): _buy_offer(offer, btn))
	shelf.add_child(btn)

func _format_offer_text(offer: Dictionary) -> String:
	var title = str(offer.get("title", "商品"))
	var price = _get_offer_price(offer)
	match str(offer.get("type", "")):
		"item":
			return "%s\n物品/%s | %d 碎片" % [title, _format_item_destination(offer), price]
		"ornament":
			return "%s\n%s饰品 | %d 碎片" % [title, str(offer.get("rarity", "")), price]
		"tool":
			return "%s\n%s | %d 碎片" % [title, str(offer.get("rarity", "道具")), price]
	return "%s\n%d 碎片" % [title, price]

func _format_item_destination(offer: Dictionary) -> String:
	match str(offer.get("item_destination", offer.get("destination", "deck"))):
		"backpack":
			return "入背包"
		"staging":
			return "暂存"
	return "入卡组"

func _buy_offer(offer: Dictionary, button: Button):
	GlobalTooltip.hide()
	var rm = get_node_or_null("/root/RunManager")
	var item_db = get_node_or_null("/root/ItemDatabase")
	if rm and rm.has_method("buy_shop_offer") and rm.buy_shop_offer(offer, item_db):
		print("[Shop] 购买成功: ", offer.get("title", ""))
		button.disabled = true
		button.text = str(offer.get("title", "商品")) + "\n已购买"
		_update_shard_display()
		_refresh_offer_buttons()
		_render_backpack_for_sale()
	else:
		print("[Shop] 购买失败：碎片不足！")

func _refresh_offer_buttons() -> void:
	for child in shelf.get_children():
		if child is Button and not child.disabled and child.has_meta("offer"):
			child.text = _format_offer_text(child.get_meta("offer"))

func _get_offer_price(offer: Dictionary) -> int:
	var rm = get_node_or_null("/root/RunManager")
	if rm and rm.has_method("get_current_shop_offer_price"):
		return rm.get_current_shop_offer_price(offer)
	return int(offer.get("price", 0))

func _show_offer_tooltip(offer: Dictionary) -> void:
	if str(offer.get("type", "")) != "item":
		GlobalTooltip.hide()
		return
	var item_db = get_node_or_null("/root/ItemDatabase")
	var item = item_db.get_item_by_id(str(offer.get("id", ""))) if item_db and item_db.has_method("get_item_by_id") else null
	if item:
		GlobalTooltip.show_item(item)
	else:
		GlobalTooltip.hide()

func _hide_offer_tooltip() -> void:
	GlobalTooltip.hide()

func _render_backpack_for_sale() -> void:
	if shop_backpack_ui == null:
		return
	var rm = get_node_or_null("/root/RunManager")
	var item_db = get_node_or_null("/root/ItemDatabase")
	if rm == null or item_db == null:
		return
	if shop_backpack_manager == null:
		shop_backpack_manager = BackpackManager.new()
		add_child(shop_backpack_manager)

	var config = rm.get_backpack_grid_config() if rm.has_method("get_backpack_grid_config") else {}
	shop_backpack_manager.setup_grid(
		int(config.get("grid_width", 7)),
		int(config.get("grid_height", 7)),
		int(config.get("usable_width", 5)),
		int(config.get("usable_height", 5))
	)
	if shop_backpack_manager.has_method("set_blocked_cells"):
		shop_backpack_manager.set_blocked_cells(_to_vector2i_array(config.get("blocked_cells", [])))
	if rm.has_method("restore_backpack_state"):
		rm.restore_backpack_state(shop_backpack_manager, item_db)

	if shop_backpack_ui.has_method("clear_item_visuals"):
		shop_backpack_ui.clear_item_visuals()
	shop_backpack_ui.set("manager", shop_backpack_manager)
	if shop_backpack_ui.has_method("_refresh_grid"):
		shop_backpack_ui._refresh_grid()

	for instance in shop_backpack_manager.get_all_instances():
		if instance == null or instance.data == null:
			continue
		var card := ItemUIScene.instantiate() as Control
		if card == null:
			continue
		card.setup(instance.data)
		card.set("item_instance", instance)
		var runtime_id := int(instance.data.runtime_id)
		card.gui_input.connect(func(event): _on_shop_backpack_item_gui_input(event, runtime_id))
		if shop_backpack_ui.has_method("add_item_visual"):
			shop_backpack_ui.add_item_visual(card, instance.root_pos)

func _to_vector2i_array(value: Variant) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for entry in Array(value):
		if entry is Vector2i:
			result.append(entry)
		elif entry is Dictionary:
			result.append(Vector2i(int(entry.get("x", 0)), int(entry.get("y", 0))))
	return result

func _on_shop_backpack_item_gui_input(event: InputEvent, runtime_id: int) -> void:
	if not (event is InputEventMouseButton):
		return
	var mouse_event := event as InputEventMouseButton
	if not mouse_event.pressed:
		return
	if mouse_event.button_index != MOUSE_BUTTON_RIGHT and not (mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.double_click):
		return
	if _sell_backpack_item(runtime_id):
		get_viewport().set_input_as_handled()

func _sell_backpack_item(runtime_id: int) -> bool:
	var rm = get_node_or_null("/root/RunManager")
	var item_db = get_node_or_null("/root/ItemDatabase")
	if rm == null or not rm.has_method("sell_backpack_item"):
		return false
	var gained := int(rm.sell_backpack_item(runtime_id, item_db))
	if gained <= 0:
		return false
	print("[Shop] 售卖背包物品，获得碎片: ", gained)
	_update_shard_display()
	_render_backpack_for_sale()
	return true

func _on_refresh_pressed() -> void:
	GlobalTooltip.hide()
	var rm = get_node_or_null("/root/RunManager")
	var item_db = get_node_or_null("/root/ItemDatabase")
	var ornament_db = get_node_or_null("/root/OrnamentDatabase")
	if rm == null or item_db == null or not rm.has_method("refresh_current_shop_offers"):
		return
	rm.refresh_current_shop_offers(item_db, ornament_db, SHOP_OFFER_COUNT)
	_update_shard_display()
	_populate_shelf()

func _on_back_pressed():
	GlobalTooltip.hide()
	var rm = get_node_or_null("/root/RunManager")
	if rm and rm.get_current_route_node_type() == RouteConfig.NODE_SHOP:
		rm.advance_route_node()
		var next_scene = GlobalScene.SceneType.MAIN_MENU if rm.is_run_complete else GlobalScene.SceneType.HUB
		GlobalScene.transition_to(next_scene, false)
	else:
		GlobalScene.go_back()
