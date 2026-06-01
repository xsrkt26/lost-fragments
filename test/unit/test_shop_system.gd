extends GutTest

const RunManagerScript = preload("res://src/autoload/run_manager.gd")
const ShopGeneratorScript = preload("res://src/core/rewards/shop_generator.gd")
const HubShopVisualControllerScript = preload("res://src/ui/hub/hub_shop_visual_controller.gd")
const TOOL_ORNAMENT_IDS := [
	"tool_belt",
	"specimen_pin_case",
	"gardening_toolkit",
	"recycling_hook",
	"calibration_screwdriver",
	"universal_toolbox",
]

var item_db
var ornament_db
var tool_db

func before_each():
	item_db = get_node_or_null("/root/ItemDatabase")
	ornament_db = get_node_or_null("/root/OrnamentDatabase")
	tool_db = get_node_or_null("/root/ToolDatabase")
	if item_db and item_db.items.is_empty():
		item_db.load_all_items()
	if ornament_db and ornament_db.ornaments.is_empty():
		ornament_db.load_all_ornaments()
	if tool_db and tool_db.tools.is_empty():
		tool_db.load_all_tools()

func after_each():
	GlobalTooltip.hide()
	await get_tree().process_frame

func _make_run_manager(act: int = 1):
	var rm = autofree(RunManagerScript.new())
	rm.current_act = act
	rm.current_route_index = 1
	rm.current_shards = 100
	rm.current_deck = [] as Array[String]
	rm.current_ornaments = [] as Array[String]
	rm.is_run_active = true
	return rm

func test_shop_offers_include_items_and_available_ornaments():
	var rm = _make_run_manager(1)

	var offers = ShopGeneratorScript.generate_offers(rm, item_db, ornament_db)

	assert_eq(offers.size(), ShopGeneratorScript.DEFAULT_OFFER_COUNT)
	assert_eq(_count_offer_type(offers, ShopGeneratorScript.TYPE_ORNAMENT), ShopGeneratorScript.SHOP_ORNAMENT_COUNT)
	assert_eq(_count_offer_type(offers, ShopGeneratorScript.TYPE_TOOL), ShopGeneratorScript.SHOP_TOOL_COUNT)
	assert_eq(_count_offer_type(offers, ShopGeneratorScript.TYPE_ITEM), ShopGeneratorScript.SHOP_ITEM_COUNT)
	for offer in offers:
		assert_true(int(offer.get("price", 0)) > 0)

func test_shop_filters_owned_ornaments():
	var rm = _make_run_manager(1)
	rm.current_ornaments = ["dreamcatcher_filter"] as Array[String]

	var offers = ShopGeneratorScript.generate_offers(rm, item_db, ornament_db)
	for offer in offers:
		assert_false(offer.get("type", "") == "ornament" and offer.get("id", "") == "dreamcatcher_filter")

func test_shop_generation_includes_enabled_tool_ornaments():
	var rm = _make_run_manager(6)

	var offers = ShopGeneratorScript.generate_offers(rm, item_db, ornament_db, 80)
	var ornament_ids = offers.filter(func(offer): return offer.get("type", "") == "ornament").map(func(offer): return str(offer.get("id", "")))

	for ornament_id in TOOL_ORNAMENT_IDS:
		assert_true(ornament_ids.has(ornament_id))

func test_shop_generation_is_reproducible_with_run_seed_and_cached_per_node():
	var rm = _make_run_manager(2)
	rm.current_route_index = 1
	rm.set_random_seed(123456)

	var first = rm.generate_current_shop_offers(item_db, ornament_db)
	var second = rm.generate_current_shop_offers(item_db, ornament_db)
	var restored = autofree(RunManagerScript.new())
	restored.deserialize_run(rm.serialize_run())
	var restored_cached = restored.generate_current_shop_offers(item_db, ornament_db)

	assert_eq(_offer_keys(first), _offer_keys(second))
	assert_eq(_offer_keys(first), _offer_keys(restored_cached))

func test_shop_refresh_spends_shards_and_updates_refresh_cost():
	var rm = _make_run_manager(2)
	rm.current_route_index = 1
	rm.current_shards = 100
	rm.set_random_seed(222)
	var initial_cost = rm.get_current_shop_refresh_cost()

	var before = rm.generate_current_shop_offers(item_db, ornament_db)
	var after = rm.refresh_current_shop_offers(item_db, ornament_db)

	assert_eq(rm.current_shards, 100 - initial_cost)
	assert_eq(rm.get_current_shop_refresh_cost(), initial_cost + 3)
	assert_eq(before.size(), ShopGeneratorScript.DEFAULT_OFFER_COUNT)
	assert_eq(after.size(), ShopGeneratorScript.DEFAULT_OFFER_COUNT)

func test_shop_prices_scale_with_act():
	var early = _make_run_manager(1)
	var late = _make_run_manager(5)

	var early_offers = ShopGeneratorScript.generate_offers(early, item_db, ornament_db, 12)
	var late_offers = ShopGeneratorScript.generate_offers(late, item_db, ornament_db, 12)
	var early_by_key = _offers_by_key(early_offers)
	var late_by_key = _offers_by_key(late_offers)
	var shared_key = ""
	for key in early_by_key.keys():
		if late_by_key.has(key):
			shared_key = key
			break

	assert_ne(shared_key, "")
	assert_true(int(late_by_key[shared_key].get("price", 0)) >= int(early_by_key[shared_key].get("price", 0)))

func test_buy_shop_offer_spends_shards_and_updates_long_term_state():
	var rm = _make_run_manager(1)

	assert_true(rm.buy_shop_offer({"type": "item", "id": "paper_ball", "price": 7}))
	assert_eq(rm.current_shards, 93)
	assert_eq(rm.current_deck, ["paper_ball"])

	assert_true(rm.buy_shop_offer({"type": "ornament", "id": "old_pocket_watch", "price": 45}))
	assert_eq(rm.current_shards, 48)
	assert_eq(rm.current_ornaments, ["old_pocket_watch"])

	assert_false(rm.buy_shop_offer({"type": "ornament", "id": "old_pocket_watch", "price": 45}))
	assert_eq(rm.current_shards, 48)

	assert_true(rm.buy_shop_offer({"type": "tool", "id": "small_patch", "price": 8}))
	assert_eq(rm.current_shards, 40)
	assert_eq(rm.get_tool_count("small_patch"), 1)

func test_sell_backpack_item_removes_item_and_grants_sell_value():
	var rm = _make_run_manager(1)
	rm.current_shards = 10
	rm.current_backpack_items = [
		{
			"id": RunManagerScript.ROOT_DREAM_ID,
			"x": 1,
			"y": 3,
			"direction": ItemData.Direction.RIGHT,
			"shape": [{"x": 0, "y": 0}],
			"runtime_id": -1,
		},
		{
			"id": "tin_can",
			"x": 2,
			"y": 2,
			"direction": ItemData.Direction.RIGHT,
			"shape": [{"x": 0, "y": 0}, {"x": 1, "y": 0}],
			"runtime_id": 100,
		},
	] as Array[Dictionary]

	assert_eq(rm.sell_backpack_item(-1, item_db), 0)
	assert_eq(rm.sell_backpack_item(100, item_db), 8)
	assert_eq(rm.current_shards, 18)
	assert_eq(rm.current_backpack_items.size(), 1)
	assert_eq(str(rm.current_backpack_items[0].get("id", "")), RunManagerScript.ROOT_DREAM_ID)

func test_visual_shop_buyback_button_uses_repurchase_copy_and_drag_scale():
	var owner := Control.new()
	add_child_autofree(owner)
	owner.size = BookBackgroundConfig.DESIGN_SIZE
	var controller = HubShopVisualControllerScript.new()
	controller._create_offer_overlay(owner)
	controller._create_buyback_button(owner)
	controller._last_viewport_size = BookBackgroundConfig.DESIGN_SIZE
	controller._layout_buyback_button()
	var button := owner.get_node_or_null("ShopOfferOverlayCanvas/ShopOfferRoot/ShopBuybackButton") as Button
	assert_not_null(button)
	assert_eq(button.text, "回购")
	assert_eq(button.get_theme_color("font_color"), Color.WHITE)
	assert_true(button.position.y > 700.0)
	assert_true(controller._is_buyback_drop_position(button.get_global_rect().get_center()))

	var dragged_item := Control.new()
	dragged_item.size = Vector2(80.0, 80.0)
	owner.add_child(dragged_item)
	controller._set_buyback_drag_active(true, dragged_item)
	await get_tree().create_timer(0.16).timeout
	assert_almost_eq(button.scale.x, 1.08, 0.02)
	assert_almost_eq(dragged_item.scale.x, 1.1, 0.02)
	controller._set_buyback_drag_active(false, dragged_item)
	await get_tree().create_timer(0.16).timeout
	assert_almost_eq(button.scale.x, 1.0, 0.02)
	assert_almost_eq(dragged_item.scale.x, 1.0, 0.02)


func test_visual_shop_skull_overlay_matches_reference_pixels():
	var owner := Control.new()
	add_child_autofree(owner)
	owner.size = BookBackgroundConfig.DESIGN_SIZE
	var controller = HubShopVisualControllerScript.new()
	controller._last_viewport_size = BookBackgroundConfig.DESIGN_SIZE
	controller._create_intro_canvas(owner)
	controller._layout_shop_skull_overlay()

	var expected_rects := [
		Rect2(Vector2(976.0, 288.0), Vector2(212.0, 189.0)),
		Rect2(Vector2(1324.0, 339.0), Vector2(281.0, 157.0)),
		Rect2(Vector2(1565.0, 229.0), Vector2(256.0, 226.0)),
		Rect2(Vector2(1787.0, 75.0), Vector2(128.0, 186.0)),
	]
	for index in range(expected_rects.size()):
		var skull := owner.get_node_or_null("ShopIntroOverlayCanvas/ShopSkullOverlay/ShopSkull%d" % (index + 1)) as TextureRect
		assert_not_null(skull)
		assert_eq(skull.position, expected_rects[index].position)
		assert_eq(skull.size, expected_rects[index].size)
		assert_eq(skull.stretch_mode, TextureRect.STRETCH_KEEP_ASPECT_CENTERED)


func test_visual_shop_offer_slots_use_reference_layout_and_product_content():
	var owner := Control.new()
	add_child_autofree(owner)
	owner.size = BookBackgroundConfig.DESIGN_SIZE
	var rm = _make_run_manager(2)
	var controller = HubShopVisualControllerScript.new()
	controller._owner_node = owner
	controller._last_viewport_size = BookBackgroundConfig.DESIGN_SIZE

	controller._render_offer_buttons(rm, item_db, ornament_db)
	await get_tree().process_frame

	assert_eq(controller._offer_buttons.size(), ShopGeneratorScript.DEFAULT_OFFER_COUNT)
	for index in range(controller._offer_buttons.size()):
		var button: Button = controller._offer_buttons[index]
		assert_eq(button.text, "")
		assert_eq(button.tooltip_text, "")
		assert_not_null(button.get_node_or_null("OfferContent/VisualArea"))
		assert_not_null(button.get_node_or_null("OfferContent/TitleLabel"))
		var price_label := button.get_node_or_null("OfferContent/PriceLabel") as Label
		assert_not_null(price_label)
		assert_true(price_label.text.ends_with("元"))
		if index < 4:
			assert_true(button.position.y < 360.0)
		else:
			assert_true(button.position.y > 460.0)


func test_visual_shop_offer_content_renders_item_tool_and_ornament_visuals():
	var owner := Control.new()
	add_child_autofree(owner)
	var rm = _make_run_manager(2)
	var controller = HubShopVisualControllerScript.new()

	var item_button := Button.new()
	owner.add_child(item_button)
	item_button.size = Vector2(160, 190)
	controller._build_offer_content(item_button, {"type": "item", "id": "paper_ball", "title": "纸团", "price": 10}, item_db, tool_db, rm)
	controller._layout_offer_content(item_button)
	var item_icon := item_button.get_node_or_null("OfferContent/VisualArea/OfferItemIcon") as TextureRect
	assert_not_null(item_icon)
	assert_true(item_icon.texture is Texture2D)
	assert_almost_eq(item_icon.size.x, item_icon.size.y, 0.001)

	var tool_button := Button.new()
	owner.add_child(tool_button)
	tool_button.size = Vector2(160, 190)
	controller._build_offer_content(tool_button, {"type": "tool", "id": "small_patch", "title": "小补丁", "price": 10}, item_db, tool_db, rm)
	controller._layout_offer_content(tool_button)
	var tool_icon := tool_button.get_node_or_null("OfferContent/VisualArea/OfferToolIcon") as TextureRect
	assert_not_null(tool_icon)
	assert_true(tool_icon.texture is Texture2D)
	assert_almost_eq(tool_icon.size.x, tool_icon.size.y, 0.001)

	var ornament_button := Button.new()
	owner.add_child(ornament_button)
	ornament_button.size = Vector2(160, 190)
	controller._build_offer_content(ornament_button, {"type": "ornament", "id": "old_pocket_watch", "title": "旧怀表", "rarity": "普通", "price": 10}, item_db, tool_db, rm)
	controller._layout_offer_content(ornament_button)
	assert_not_null(ornament_button.get_node_or_null("OfferContent/VisualArea/OfferOrnamentTag"))


func test_hub_shop_offers_use_card_tooltips_for_all_types():
	var controller = HubShopVisualControllerScript.new()

	controller._show_offer_tooltip({"type": "item", "id": "paper_ball"}, item_db, ornament_db, tool_db)
	await get_tree().create_timer(0.25).timeout

	var tooltip = GlobalTooltip._tooltip_instance
	assert_not_null(tooltip)
	assert_true(tooltip.is_panel_visible())

	var expected_item = item_db.get_item_by_id("paper_ball")
	var title_label = tooltip.get_node("PanelContainer/MarginContainer/VBoxContainer/TitleLabel")
	assert_eq(title_label.text, expected_item.item_name)

	controller._show_offer_tooltip({"type": "ornament", "id": "old_pocket_watch"}, item_db, ornament_db, tool_db)
	await get_tree().create_timer(0.25).timeout
	assert_eq(title_label.text, "旧怀表")

	controller._show_offer_tooltip({"type": "tool", "id": "small_patch"}, item_db, ornament_db, tool_db)
	await get_tree().create_timer(0.25).timeout
	assert_eq(title_label.text, "小补丁")

func _offer_keys(offers: Array[Dictionary]) -> Array[String]:
	var keys: Array[String] = []
	for offer in offers:
		keys.append(ShopGeneratorScript.make_offer_key(offer))
	return keys

func _offers_by_key(offers: Array[Dictionary]) -> Dictionary:
	var result := {}
	for offer in offers:
		result[ShopGeneratorScript.make_offer_key(offer)] = offer
	return result

func _count_offer_type(offers: Array[Dictionary], offer_type: String) -> int:
	var count := 0
	for offer in offers:
		if str(offer.get("type", "")) == offer_type:
			count += 1
	return count
