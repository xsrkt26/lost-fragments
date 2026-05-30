extends RefCounted

const HUB_BACKGROUND_PATHS := {
	"xiaojia": "res://assets/ui/hub/backgrounds/xiaojia.png",
	"parents": "res://assets/ui/hub/backgrounds/parents.png",
	"cardboard": "res://assets/ui/hub/backgrounds/cardboard.png",
	"grandma": "res://assets/ui/hub/backgrounds/grandma.png",
	"stage": "res://assets/ui/hub/backgrounds/stage.png",
}

const HUB_FOREGROUND_PATHS := {
	"xiaojia": "res://assets/ui/hub/backgrounds/xiaojia_foreground.png",
	"stage": "res://assets/ui/hub/backgrounds/stage_foreground.png",
}

const MERCHANT_FRAME_COUNTS := {
	"cat": 11,
	"grandma": 5,
	"stage": 7,
}


static func load_texture_map(paths: Dictionary) -> Dictionary:
	var result := {}
	for key in paths.keys():
		var texture := load_texture(str(paths[key]))
		if texture != null:
			result[key] = texture
	return result


static func load_texture(path: String) -> Texture2D:
	if path == "" or not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D


static func merchant_frame_paths(animation_key: String) -> Array[String]:
	var count := int(MERCHANT_FRAME_COUNTS.get(animation_key, 0))
	if count <= 0:
		return []
	var paths: Array[String] = []
	for index in range(count):
		paths.append("res://assets/characters/merchant/%s/%s_%04d.png" % [animation_key, animation_key, index])
	return paths
