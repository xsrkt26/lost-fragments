extends RefCounted
class_name AssetPaths

const ROOT := "res://assets"
const UI_ROOT := ROOT + "/ui"
const AUDIO_ROOT := ROOT + "/audio"
const CHARACTER_ROOT := ROOT + "/characters"
const FONT_ROOT := ROOT + "/fonts"
const STORY_ROOT := ROOT + "/story"
const SHOP_INTRO_ROOT := UI_ROOT + "/shop/intro_alpha"

const FONT_BODY := FONT_ROOT + "/chill_huosong_f_regular.otf"
const FONT_DISPLAY := FONT_ROOT + "/chill_huosong_f_ex_bold.otf"

const STORY_EVENTS := STORY_ROOT + "/story_events.json"

const PHOTO_CORNER := UI_ROOT + "/gallery/photo_corner.png"
const GALLERY_MEMORY_PAPER := UI_ROOT + "/gallery/gallery_memory_paper.png"
const XIAOMI_CAT := UI_ROOT + "/hub/xiaomi_cat.png"

const SHOP_SKULL_PATHS := [
	UI_ROOT + "/shop/merchant_skull_1.png",
	UI_ROOT + "/shop/merchant_skull_2.png",
	UI_ROOT + "/shop/merchant_skull_3.png",
	UI_ROOT + "/shop/merchant_skull_4.png",
]

const BGM_PATHS := {
	"menu": AUDIO_ROOT + "/bgm/main_menu.wav",
	"hub": AUDIO_ROOT + "/bgm/hub_theme.wav",
	"battle": AUDIO_ROOT + "/bgm/battle_theme.wav",
}

const SFX_PATHS := {
	"click": AUDIO_ROOT + "/sfx/ui_click.wav",
	"draw": AUDIO_ROOT + "/sfx/card_draw.wav",
	"place": AUDIO_ROOT + "/sfx/card_place.wav",
	"hit": AUDIO_ROOT + "/sfx/hit_impact.wav",
	"score": AUDIO_ROOT + "/sfx/score_up.wav",
	"error": AUDIO_ROOT + "/sfx/ui_error.wav",
}

const POTION_STATE_PATHS := [
	UI_ROOT + "/battle/potion_state_100.png",
	UI_ROOT + "/battle/potion_state_75.png",
	UI_ROOT + "/battle/potion_state_50.png",
	UI_ROOT + "/battle/potion_state_25.png",
	UI_ROOT + "/battle/potion_state_0.png",
]

const INTRO_BAG_REVEAL_FRAME_PATHS := [
	UI_ROOT + "/battle/intro_bag_reveal/bag_reveal_01.png",
	UI_ROOT + "/battle/intro_bag_reveal/bag_reveal_02.png",
	UI_ROOT + "/battle/intro_bag_reveal/bag_reveal_03.png",
	UI_ROOT + "/battle/intro_bag_reveal/bag_reveal_04.png",
	UI_ROOT + "/battle/intro_bag_reveal/bag_reveal_05.png",
]

const SHOP_INTRO_FRAME_COUNT := 147

const HUB_BACKGROUND_PATHS := {
	"grandma": UI_ROOT + "/hub/backgrounds/grandma.png",
	"xiaojia": UI_ROOT + "/hub/backgrounds/xiaojia.png",
	"parents": UI_ROOT + "/hub/backgrounds/parents.png",
	"cardboard": UI_ROOT + "/hub/hub_room.png",
	"stage": UI_ROOT + "/hub/backgrounds/stage.png",
}

const HUB_FOREGROUND_PATHS := {
	"xiaojia": UI_ROOT + "/hub/backgrounds/xiaojia_foreground.png",
	"stage": UI_ROOT + "/hub/backgrounds/stage_foreground.png",
}

const MERCHANT_FRAME_SPECS := {
	"cat": {
		"directory": CHARACTER_ROOT + "/merchant/cat",
		"prefix": "cat",
		"indices": [0, 0, 0, 0, 4, 5, 6, 7, 8, 9, 10],
	},
	"grandma": {
		"directory": CHARACTER_ROOT + "/merchant/grandma",
		"prefix": "grandma",
		"count": 5,
	},
	"stage": {
		"directory": CHARACTER_ROOT + "/merchant/stage",
		"prefix": "stage",
		"count": 7,
	},
}

static func numbered_paths(directory: String, prefix: String, count: int, start_index: int = 0, digits: int = 4, extension: String = ".png") -> PackedStringArray:
	var paths := PackedStringArray()
	for i in range(maxi(count, 0)):
		var number := str(start_index + i).pad_zeros(digits)
		paths.append("%s/%s_%s%s" % [directory, prefix, number, extension])
	return paths


static func numbered_index_paths(directory: String, prefix: String, indices: Array, digits: int = 4, extension: String = ".png") -> PackedStringArray:
	var paths := PackedStringArray()
	for index in indices:
		var number := str(int(index)).pad_zeros(digits)
		paths.append("%s/%s_%s%s" % [directory, prefix, number, extension])
	return paths


static func intro_bag_reveal_frame_paths() -> PackedStringArray:
	return PackedStringArray(INTRO_BAG_REVEAL_FRAME_PATHS)


static func shop_intro_frame_paths() -> PackedStringArray:
	return numbered_paths(SHOP_INTRO_ROOT, "shop_intro", SHOP_INTRO_FRAME_COUNT, 1, 3)


static func merchant_frame_paths(merchant_id: String) -> PackedStringArray:
	var spec: Dictionary = MERCHANT_FRAME_SPECS.get(merchant_id, {})
	if spec.is_empty():
		return PackedStringArray()
	if spec.has("indices"):
		return numbered_index_paths(
			str(spec.get("directory", "")),
			str(spec.get("prefix", "")),
			spec.get("indices", [])
		)
	return numbered_paths(
		str(spec.get("directory", "")),
		str(spec.get("prefix", "")),
		int(spec.get("count", 0))
	)


static func load_texture(path: String) -> Texture2D:
	if path == "" or not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D


static func load_texture_map(paths_by_id: Dictionary) -> Dictionary:
	var textures := {}
	for key in paths_by_id.keys():
		var texture := load_texture(str(paths_by_id[key]))
		if texture != null:
			textures[key] = texture
	return textures


static func load_texture_list(paths: PackedStringArray) -> Array[Texture2D]:
	var textures: Array[Texture2D] = []
	for path in paths:
		var texture := load_texture(path)
		if texture != null:
			textures.append(texture)
	return textures
