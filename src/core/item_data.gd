class_name ItemData
extends Resource

## 物品数据资源类 (Model)
## 定义物品的静态属性、形状以及携带的效果

enum Direction { UP, DOWN, LEFT, RIGHT }
enum TransmissionMode { NORMAL, OMNI, NONE, MECHANICAL_LEFT, MECHANICAL_RIGHT, MECHANICAL_BIDIRECTIONAL, MECHANICAL_OMNI }

@export var id: String
@export var item_name: String
@export_multiline var description: String = ""
@export var tags: Array[String] = [] # 类别词条，如 ["运动", "神秘", "书籍"]
@export var price: int = 5 # 物品价值
@export var base_cost: int = -1 # 基础梦值消耗 (如果为负，则使用公式计算)
@export var can_draw: bool = true # 是否可以被抽到
@export var can_rotate: bool = true # 是否允许旋转
@export var runtime_id: int = -1 # 运行时唯一 ID，用于逻辑与 UI 绑定
@export var icon: Texture2D
@export var shape: Array[Vector2i] = [Vector2i(0, 0)] # 占用的格子相对偏移
@export var direction: Direction = Direction.RIGHT
@export var transmission_mode: TransmissionMode = TransmissionMode.NORMAL
@export var hit_filter_tags: Array[String] = [] # 仅能撞击包含这些标签的物品 (为空则撞击所有)
@export var effects: Array[ItemEffect] = [] # 物品携带的效果列表

const TOOL_TAG := "道具"

## 模拟计算旋转后某个局部偏移量的新位置
func get_rotated_offset(old_offset: Vector2i) -> Vector2i:
	if not can_rotate: return old_offset
	
	var min_x = 0; var max_x = 0; var min_y = 0; var max_y = 0
	for p in shape:
		if p.x < min_x: min_x = p.x
		if p.x > max_x: max_x = p.x
		if p.y < min_y: min_y = p.y
		if p.y > max_y: max_y = p.y
	
	var w = max_x - min_x + 1
	var h = max_y - min_y + 1
	
	if w == h and shape.size() == w * h:
		return old_offset
		
	var norm_min_x: int = 0
	var norm_min_y: int = 0
	
	for p in shape:
		var rotated_p = Vector2i(-p.y, p.x)
		if rotated_p.x < norm_min_x: norm_min_x = rotated_p.x
		if rotated_p.y < norm_min_y: norm_min_y = rotated_p.y
		
	var rotated_old = Vector2i(-old_offset.y, old_offset.x)
	return rotated_old - Vector2i(norm_min_x, norm_min_y)

## 获取用于悬浮窗显示的富文本/详细信息 (预留动态计算空间)
func get_tooltip_text(_instance = null) -> String:
	var text = ""
	var stack_count := _get_stack_count(_instance)
	if _is_tool():
		var rarity := str(get_meta("tool_rarity", "道具"))
		if rarity != "":
			text += "[color=#ffaa55]" + rarity + "[/color]\n"
		text += "堆叠数量: " + str(stack_count) + "\n\n"
	
	# 1. 动态生成基础属性信息
	if _is_tool():
		pass
	elif base_cost == -1:
		text += "[color=#ffaa55]捕梦消耗: 阶梯递增[/color]\n\n"
	elif base_cost != 0:
		text += "[color=#ff5555]捕梦消耗: " + str(abs(base_cost)) + " 梦值[/color]\n\n"
		
	# 2. 静态/动态混合描述文本
	# 后续可以在这里解析 description 中的占位符，例如将 "{damage}" 替换为实际数值
	if description != "":
		text += description + "\n"
		
	# 3. 预留：遍历 effects 动态追加各个 effect 的专属描述
	# for effect in effects:
	# 	if effect.has_method("get_dynamic_desc"):
	# 		text += "\n" + effect.get_dynamic_desc(instance)
			
	return text.strip_edges()

func _is_tool() -> bool:
	return bool(get_meta("is_tool", false)) or tags.has(TOOL_TAG)

func _get_stack_count(instance) -> int:
	if instance != null:
		var value = instance.get("stack_count")
		if value != null:
			return max(1, int(value))
	if has_meta("stack_count"):
		return max(1, int(get_meta("stack_count")))
	return 1

## 获取该物品当前形状的包围盒 (Rect2i)
func get_bounding_rect() -> Rect2i:
	if shape.is_empty():
		return Rect2i(0, 0, 0, 0)
	
	var min_pos = shape[0]
	var max_pos = shape[0]
	
	for p in shape:
		min_pos.x = min(min_pos.x, p.x)
		min_pos.y = min(min_pos.y, p.y)
		max_pos.x = max(max_pos.x, p.x)
		max_pos.y = max(max_pos.y, p.y)
		
	return Rect2i(min_pos, max_pos - min_pos + Vector2i(1, 1))

## 顺时针旋转 90 度
func rotate_90():
	if not can_rotate: return
	# 1. 更新撞击方向 (UP -> RIGHT -> DOWN -> LEFT -> UP)
	match direction:
		Direction.UP: direction = Direction.RIGHT
		Direction.RIGHT: direction = Direction.DOWN
		Direction.DOWN: direction = Direction.LEFT
		Direction.LEFT: direction = Direction.UP
	
	# 2. 检查是否为完美的正方形 (宽==高，且从0,0填满)
	# 为了简化，如果宽==高，我们就认为是正方形，不需要改变相对坐标，只需改变方向
	var min_x = 0; var max_x = 0; var min_y = 0; var max_y = 0
	for p in shape:
		if p.x < min_x: min_x = p.x
		if p.x > max_x: max_x = p.x
		if p.y < min_y: min_y = p.y
		if p.y > max_y: max_y = p.y
	
	var w = max_x - min_x + 1
	var h = max_y - min_y + 1
	
	if w == h and shape.size() == w * h:
		print("[ItemData] 物品是正方形，仅旋转方向: ", direction)
		return
	
	# 3. 非正方形，更新形状坐标: (x, y) -> (-y, x)
	var new_shape: Array[Vector2i] = []
	var norm_min_x: int = 0
	var norm_min_y: int = 0
	
	for p in shape:
		var rotated_p = Vector2i(-p.y, p.x)
		new_shape.append(rotated_p)
		if rotated_p.x < norm_min_x: norm_min_x = rotated_p.x
		if rotated_p.y < norm_min_y: norm_min_y = rotated_p.y
	
	# --- 归一化 (Normalization) ---
	var normalized_shape: Array[Vector2i] = []
	var norm_offset = Vector2i(norm_min_x, norm_min_y)
	for p in new_shape:
		normalized_shape.append(p - norm_offset)
		
	shape = normalized_shape
	print("[ItemData] 物品已旋转并归一化. 新方向: ", direction, " 新形状: ", shape)
