extends Node

## 设置管理器：负责持久化玩家偏好。

const SETTINGS_FILE = "user://settings.cfg"
const WINDOW_MODE_WINDOWED := "windowed"
const WINDOW_MODE_BORDERLESS_FULLSCREEN := "borderless_fullscreen"
const WINDOW_MODE_FULLSCREEN := WINDOW_MODE_BORDERLESS_FULLSCREEN
const LEGACY_WINDOW_MODE_EXCLUSIVE_FULLSCREEN := "fullscreen"
const DISPLAY_SETTINGS_VERSION := 4
const DEFAULT_RESOLUTION := Vector2i(1920, 1080)
const ANIMATION_SPEED_SLOW := "slow"
const ANIMATION_SPEED_NORMAL := "normal"
const ANIMATION_SPEED_FAST := "fast"
const RESOLUTION_OPTIONS := [
	Vector2i(1280, 720),
	Vector2i(1600, 900),
	DEFAULT_RESOLUTION,
]
const REQUIRED_AUDIO_BUSES := [
	"Music",
	"SFX",
]

var config = ConfigFile.new()

var audio_settings = {
	"master_volume": 0.8,
	"music_volume": 0.7,
	"sfx_volume": 0.9,
	"is_muted": true,
}

var display_settings = {
	"version": DISPLAY_SETTINGS_VERSION,
	"window_mode": WINDOW_MODE_BORDERLESS_FULLSCREEN,
	"resolution": DEFAULT_RESOLUTION,
}

var game_settings = {
	"animation_speed": ANIMATION_SPEED_NORMAL,
}

func _ready():
	_ensure_audio_buses()
	load_settings()
	apply_audio_settings()
	apply_display_settings()

func save_settings():
	for key in audio_settings:
		config.set_value("audio", key, audio_settings[key])
	for key in display_settings:
		config.set_value("display", key, display_settings[key])
	for key in game_settings:
		config.set_value("game", key, game_settings[key])
	config.save(SETTINGS_FILE)
	print("[Settings] 设置已保存至: ", SETTINGS_FILE)

func load_settings():
	var err = config.load(SETTINGS_FILE)
	if err == OK:
		for key in audio_settings.keys():
			audio_settings[key] = config.get_value("audio", key, audio_settings[key])
		var display_version := int(config.get_value("display", "version", 0))
		if display_version >= DISPLAY_SETTINGS_VERSION:
			for key in display_settings.keys():
				display_settings[key] = config.get_value("display", key, display_settings[key])
		else:
			display_settings = _default_display_settings()
		for key in game_settings.keys():
			game_settings[key] = config.get_value("game", key, game_settings[key])
		display_settings["resolution"] = _normalize_resolution(display_settings["resolution"])
		display_settings["window_mode"] = _normalize_window_mode(str(display_settings["window_mode"]))
		display_settings["version"] = DISPLAY_SETTINGS_VERSION
		game_settings["animation_speed"] = _normalize_animation_speed(str(game_settings["animation_speed"]))
		print("[Settings] 设置已加载")
		if display_version < DISPLAY_SETTINGS_VERSION:
			save_settings()
	else:
		print("[Settings] 未发现旧设置，使用默认配置")

func apply_audio_settings():
	_ensure_audio_buses()
	_set_bus_vol("Master", audio_settings["master_volume"])
	_set_bus_vol("Music", audio_settings["music_volume"])
	_set_bus_vol("SFX", audio_settings["sfx_volume"])
	
	AudioServer.set_bus_mute(0, audio_settings["is_muted"])

func apply_display_settings():
	if not _can_control_window():
		return
	var window_mode := str(display_settings["window_mode"])
	if window_mode == WINDOW_MODE_BORDERLESS_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	var resolution := _normalize_resolution(display_settings["resolution"])
	DisplayServer.window_set_size(resolution)
	_center_window(resolution)

func _set_bus_vol(bus_name: String, linear_vol: float):
	var idx = AudioServer.get_bus_index(bus_name)
	if idx != -1:
		var clamped := clampf(linear_vol, 0.0, 1.0)
		AudioServer.set_bus_volume_db(idx, -80.0 if clamped <= 0.0 else linear_to_db(clamped))

func toggle_mute():
	audio_settings["is_muted"] = !audio_settings["is_muted"]
	AudioServer.set_bus_mute(0, audio_settings["is_muted"])
	save_settings()
	return audio_settings["is_muted"]

func set_master_volume(val: float):
	_set_audio_volume("master_volume", "Master", val)

func set_music_volume(val: float):
	_set_audio_volume("music_volume", "Music", val)

func set_sfx_volume(val: float):
	_set_audio_volume("sfx_volume", "SFX", val)

func set_muted(is_muted: bool) -> void:
	audio_settings["is_muted"] = is_muted
	AudioServer.set_bus_mute(0, is_muted)
	save_settings()

func set_window_mode(window_mode: String) -> void:
	display_settings["window_mode"] = _normalize_window_mode(window_mode)
	apply_display_settings()
	save_settings()

func set_resolution(resolution: Vector2i) -> void:
	display_settings["resolution"] = _normalize_resolution(resolution)
	apply_display_settings()
	save_settings()

func set_animation_speed(speed: String) -> void:
	game_settings["animation_speed"] = _normalize_animation_speed(speed)
	save_settings()

func get_animation_speed_multiplier() -> float:
	match str(game_settings["animation_speed"]):
		ANIMATION_SPEED_SLOW:
			return 1.45
		ANIMATION_SPEED_FAST:
			return 0.7
	return 1.0

func reset_to_defaults() -> void:
	audio_settings = {
		"master_volume": 0.8,
		"music_volume": 0.7,
		"sfx_volume": 0.9,
		"is_muted": true,
	}
	display_settings = _default_display_settings()
	game_settings = {
		"animation_speed": ANIMATION_SPEED_NORMAL,
	}
	apply_audio_settings()
	apply_display_settings()
	save_settings()

func _set_audio_volume(key: String, bus_name: String, val: float) -> void:
	_ensure_audio_buses()
	var clamped := clampf(val, 0.0, 1.0)
	audio_settings[key] = clamped
	_set_bus_vol(bus_name, clamped)
	save_settings()

func _ensure_audio_buses() -> void:
	for bus_name in REQUIRED_AUDIO_BUSES:
		if AudioServer.get_bus_index(bus_name) != -1:
			continue
		var bus_index := AudioServer.get_bus_count()
		AudioServer.add_bus(bus_index)
		AudioServer.set_bus_name(bus_index, bus_name)
		AudioServer.set_bus_send(bus_index, "Master")

func _normalize_window_mode(value: String) -> String:
	if value == WINDOW_MODE_BORDERLESS_FULLSCREEN or value == LEGACY_WINDOW_MODE_EXCLUSIVE_FULLSCREEN:
		return WINDOW_MODE_BORDERLESS_FULLSCREEN
	return WINDOW_MODE_WINDOWED

func _normalize_animation_speed(value: String) -> String:
	if [ANIMATION_SPEED_SLOW, ANIMATION_SPEED_NORMAL, ANIMATION_SPEED_FAST].has(value):
		return value
	return ANIMATION_SPEED_NORMAL

func _normalize_resolution(value) -> Vector2i:
	if value is Vector2i:
		return value
	if value is Vector2:
		return Vector2i(int(value.x), int(value.y))
	if value is String:
		var parts: PackedStringArray = value.split("x")
		if parts.size() == 2:
			return Vector2i(int(parts[0]), int(parts[1]))
	return RESOLUTION_OPTIONS[0]

func _default_display_settings() -> Dictionary:
	return {
		"version": DISPLAY_SETTINGS_VERSION,
		"window_mode": WINDOW_MODE_BORDERLESS_FULLSCREEN,
		"resolution": DEFAULT_RESOLUTION,
	}

func _can_control_window() -> bool:
	if DisplayServer.get_name() == "headless":
		return false
	# Editor embedded game windows are owned by the editor and cannot be resized or moved.
	return not OS.has_feature("editor")

func _center_window(resolution: Vector2i) -> void:
	var screen := DisplayServer.window_get_current_screen()
	var screen_rect := DisplayServer.screen_get_usable_rect(screen)
	var centered_offset := Vector2i(
		floori(float(screen_rect.size.x - resolution.x) / 2.0),
		floori(float(screen_rect.size.y - resolution.y) / 2.0)
	)
	DisplayServer.window_set_position(screen_rect.position + centered_offset)
