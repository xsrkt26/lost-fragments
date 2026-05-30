class_name GiftBoxEffect
extends ItemEffect


@export var score_amount: int = 5

func on_hit(instance: BackpackManager.ItemInstance, _source_instance: BackpackManager.ItemInstance, _resolver: ImpactResolver, context: GameContext, multiplier: int = 1) -> GameAction:
	var generated_count := 0
	if context and context.battle:
		generated_count = _replace_with_random_small_items(instance, context.battle.backpack_manager, context)

	var action = GameAction.new(GameAction.Type.NUMERIC, "Gift box score")
	action.value = {
		"type": "score",
		"amount": score_amount * multiplier,
		"refresh_backpack_visuals": generated_count > 0,
	}
	return action

func _replace_with_random_small_items(instance: BackpackManager.ItemInstance, backpack: BackpackManager, context: GameContext) -> int:
	if instance == null or backpack == null:
		return 0

	var occupied_cells: Array[Vector2i] = []
	for offset in instance.data.shape:
		occupied_cells.append(instance.root_pos + offset)

	var item_db = context.get_root_node_or_null("/root/ItemDatabase") if context != null else null
	var run_manager = _get_run_manager(context)
	var generated_items := _draw_generated_items(_pick_cell_count_pattern(context), item_db, run_manager)

	backpack.remove_instance(instance)

	if generated_items.is_empty():
		return 0
	return _place_items_inside_cells(generated_items, occupied_cells, backpack, context)

func _pick_cell_count_pattern(context: GameContext) -> Array[int]:
	var total_cells := _pick_total_cell_count(context)
	match total_cells:
		1:
			return [1]
		2:
			return [2]
		3:
			return [1, 2]
		4:
			if _roll(context) < 0.5:
				return [1, 1, 2]
			return [2, 2]
	return [2]

func _pick_total_cell_count(context: GameContext) -> int:
	var options := [
		{"cells": 1, "weight": 5.0},
		{"cells": 2, "weight": 30.0},
		{"cells": 3, "weight": 45.0},
		{"cells": 4, "weight": 20.0},
	]
	var total_weight := 0.0
	for option in options:
		total_weight += float(option.weight)
	var roll := _roll(context) * total_weight
	var cursor := 0.0
	for option in options:
		cursor += float(option.weight)
		if roll <= cursor:
			return int(option.cells)
	return 4

func _draw_generated_items(cell_counts: Array[int], item_db: Node, run_manager: Node) -> Array[ItemData]:
	var result: Array[ItemData] = []
	if item_db == null:
		return result
	for cell_count in cell_counts:
		var item_id := ItemDrawPool.draw_item_id_by_cell_count(run_manager, item_db, cell_count)
		if item_id == "":
			continue
		var item = item_db.get_item_by_id(item_id)
		if item != null:
			result.append(item)
	return result

func _place_items_inside_cells(items: Array[ItemData], footprint: Array[Vector2i], backpack: BackpackManager, context: GameContext) -> int:
	var sorted_items := items.duplicate()
	sorted_items.sort_custom(func(a: ItemData, b: ItemData): return a.shape.size() > b.shape.size())
	var placed_count := 0
	for item in sorted_items:
		if _place_single_item_inside_cells(item, footprint, backpack, context):
			placed_count += 1
	return placed_count

func _place_single_item_inside_cells(item: ItemData, footprint: Array[Vector2i], backpack: BackpackManager, context: GameContext) -> bool:
	var candidates := _build_placement_candidates(item, footprint, backpack)
	while not candidates.is_empty():
		var index := context.random_index(candidates.size()) if context != null else randi() % candidates.size()
		var candidate = candidates[index]
		candidates.remove_at(index)
		if backpack.place_item(candidate.item, candidate.root, true):
			return true
	return false

func _build_placement_candidates(item: ItemData, footprint: Array[Vector2i], backpack: BackpackManager) -> Array[Dictionary]:
	var candidates: Array[Dictionary] = []
	var footprint_lookup := {}
	for cell in footprint:
		footprint_lookup[_cell_key(cell)] = true
	for variant in _build_shape_variants(item):
		for root in footprint:
			if _shape_fits_footprint(variant, root, footprint_lookup, backpack):
				candidates.append({"item": variant.duplicate(true), "root": root})
	return candidates

func _build_shape_variants(item: ItemData) -> Array[ItemData]:
	var variants: Array[ItemData] = []
	var seen := {}
	var current: ItemData = item.duplicate(true)
	for _i in range(4):
		var key := _shape_key(current.shape)
		if not seen.has(key):
			seen[key] = true
			variants.append(current.duplicate(true))
		if not current.can_rotate:
			break
		current.rotate_90()
	return variants

func _shape_fits_footprint(item: ItemData, root: Vector2i, footprint_lookup: Dictionary, backpack: BackpackManager) -> bool:
	for offset in item.shape:
		var cell := root + offset
		if not footprint_lookup.has(_cell_key(cell)) or backpack.grid.has(cell):
			return false
	return backpack.can_place_item(item, root, true)

func _shape_key(shape: Array[Vector2i]) -> String:
	var parts: Array[String] = []
	for cell in shape:
		parts.append("%d:%d" % [cell.x, cell.y])
	parts.sort()
	return "|".join(parts)

func _cell_key(cell: Vector2i) -> String:
	return "%d:%d" % [cell.x, cell.y]

func _roll(context: GameContext) -> float:
	return context.random_float() if context != null else randf()

func _get_run_manager(context: GameContext) -> Node:
	return context.get_root_node_or_null("/root/RunManager") if context != null else null
