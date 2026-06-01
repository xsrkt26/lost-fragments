extends Node

## Global audio routing for music, one-shot SFX, and named looping SFX.

enum Bus { MASTER, MUSIC, SFX }

const BGM_PATHS := AssetPaths.BGM_PATHS
const SFX_PATHS := AssetPaths.SFX_PATHS
const REQUIRED_AUDIO_BUSES := [
	"Music",
	"SFX",
]
const SFX_DEFAULT_POLICY := {
	"pitch_range": 0.0,
	"cooldown": 0.0,
	"priority": 1,
	"max_instances": 4,
}
const SFX_POLICIES := {
	"button": {"pitch_range": 0.04, "cooldown": 0.03, "priority": 1, "max_instances": 4},
	"click": {"pitch_range": 0.04, "cooldown": 0.03, "priority": 1, "max_instances": 4},
	"button_alt": {"pitch_range": 0.0, "cooldown": 0.05, "priority": 2, "max_instances": 2},
	"page_turn": {"pitch_range": 0.0, "cooldown": 0.08, "priority": 2, "max_instances": 2},
	"draw": {"pitch_range": 0.0, "cooldown": 0.08, "priority": 3, "max_instances": 2},
	"place": {"pitch_range": 0.02, "cooldown": 0.03, "priority": 2, "max_instances": 3},
	"discard": {"pitch_range": 0.02, "cooldown": 0.05, "priority": 2, "max_instances": 2},
	"hit": {"pitch_range": 0.05, "cooldown": 0.04, "priority": 2, "max_instances": 4},
	"score": {"pitch_range": 0.0, "cooldown": 0.12, "priority": 3, "max_instances": 2},
	"error": {"pitch_range": 0.0, "cooldown": 0.12, "priority": 4, "max_instances": 1},
	"zipper": {"pitch_range": 0.0, "cooldown": 0.08, "priority": 2, "max_instances": 1},
	"shop_emerge": {"pitch_range": 0.0, "cooldown": 0.1, "priority": 3, "max_instances": 1},
	"shop_hand": {"pitch_range": 0.0, "cooldown": 0.1, "priority": 3, "max_instances": 1},
	"dreamcatcher_xiaomi": {"pitch_range": 0.0, "cooldown": 0.08, "priority": 3, "max_instances": 1},
	"dreamcatcher_uncle": {"pitch_range": 0.0, "cooldown": 0.08, "priority": 3, "max_instances": 1},
}

var _bgm_players: Array[AudioStreamPlayer] = []
var _active_bgm_index: int = -1
var _current_bgm_key: String = ""
var _sfx_pool: Array[AudioStreamPlayer] = []
var _pool_size: int = 16
var _fade_tween: Tween = null
var _audio_disabled: bool = false
var _sfx_streams: Dictionary = {}
var _bgm_streams: Dictionary = {}
var _loop_sfx_players: Dictionary = {}
var _loop_sfx_tweens: Dictionary = {}
var _sfx_player_keys: Dictionary = {}
var _sfx_player_priorities: Dictionary = {}
var _sfx_player_started_at: Dictionary = {}
var _last_sfx_played_at: Dictionary = {}

func _ready():
	_ensure_audio_buses()
	_audio_disabled = DisplayServer.get_name() == "headless"
	if _audio_disabled:
		AudioServer.set_bus_mute(0, true)
		print("[GlobalAudio] Audio manager disabled in headless mode.")
		return
	_setup_audio_nodes()
	_cache_sfx_streams()
	print("[GlobalAudio] Audio manager ready.")

func _setup_audio_nodes():
	for i in range(2):
		var bgm_player := AudioStreamPlayer.new()
		bgm_player.name = "BgmPlayer%d" % (i + 1)
		bgm_player.bus = "Music"
		bgm_player.volume_db = -80.0
		add_child(bgm_player)
		_bgm_players.append(bgm_player)
	
	for i in range(_pool_size):
		var player := AudioStreamPlayer.new()
		player.name = "SfxPlayer%d" % (i + 1)
		player.bus = "SFX"
		player.finished.connect(_on_sfx_player_finished.bind(player))
		add_child(player)
		_sfx_pool.append(player)

func _exit_tree():
	if _fade_tween and is_instance_valid(_fade_tween):
		_fade_tween.kill()
	_fade_tween = null
	for player in _bgm_players:
		if is_instance_valid(player):
			player.stop()
			player.stream = null
	for player in _sfx_pool:
		if is_instance_valid(player):
			player.stop()
			player.stream = null
	for tween in _loop_sfx_tweens.values():
		if tween != null and tween.is_valid():
			tween.kill()
	for player in _loop_sfx_players.values():
		if is_instance_valid(player):
			player.stop()
			player.queue_free()
	_sfx_streams.clear()
	_bgm_streams.clear()
	_loop_sfx_players.clear()
	_loop_sfx_tweens.clear()
	_sfx_player_keys.clear()
	_sfx_player_priorities.clear()
	_sfx_player_started_at.clear()
	_last_sfx_played_at.clear()
	print("[GlobalAudio] Audio resources released.")

func play_bgm(bgm_key: String, fade_time: float = 1.0, loop_enabled: bool = true):
	if _audio_disabled:
		return
	var stream := _get_bgm_stream(bgm_key)
	if stream == null:
		return
	_configure_stream_loop(stream, loop_enabled)
	var active_player := _get_active_bgm_player()
	if _current_bgm_key == bgm_key and active_player != null and active_player.playing:
		return

	if _fade_tween and _fade_tween.is_running():
		_fade_tween.kill()
	_fade_tween = null

	var next_index := _get_next_bgm_player_index()
	if next_index < 0:
		return
	var incoming := _bgm_players[next_index]
	var outgoing := active_player
	incoming.stop()
	incoming.stream = stream
	incoming.bus = "Music"
	incoming.volume_db = -80.0 if fade_time > 0.0 and outgoing != null and outgoing.playing else 0.0
	incoming.play()
	_active_bgm_index = next_index
	_current_bgm_key = bgm_key

	if fade_time > 0.0 and outgoing != null and outgoing.playing and outgoing != incoming:
		_fade_tween = create_tween()
		_fade_tween.set_parallel(true)
		_fade_tween.tween_property(outgoing, "volume_db", -80.0, fade_time)
		_fade_tween.tween_property(incoming, "volume_db", 0.0, fade_time)
		_fade_tween.finished.connect(func():
			if is_instance_valid(outgoing):
				outgoing.stop()
				outgoing.stream = null
				outgoing.volume_db = -80.0
			if is_instance_valid(incoming):
				incoming.volume_db = 0.0
			_fade_tween = null
		)
	else:
		_stop_inactive_bgm_players()
		incoming.volume_db = 0.0

func stop_bgm(fade_time: float = 1.0):
	if _audio_disabled:
		return
	if _fade_tween and _fade_tween.is_running():
		_fade_tween.kill()
	_fade_tween = null
	_stop_inactive_bgm_players()
	var active_player := _get_active_bgm_player()
	if active_player == null or not active_player.playing:
		_current_bgm_key = ""
		_active_bgm_index = -1
		return
	if fade_time > 0.0:
		_fade_tween = create_tween()
		_fade_tween.tween_property(active_player, "volume_db", -80.0, fade_time)
		_fade_tween.finished.connect(func():
			if is_instance_valid(active_player):
				active_player.stop()
				active_player.stream = null
				active_player.volume_db = -80.0
			_current_bgm_key = ""
			_active_bgm_index = -1
			_fade_tween = null
		)
	else:
		active_player.stop()
		active_player.stream = null
		active_player.volume_db = -80.0
		_current_bgm_key = ""
		_active_bgm_index = -1

func play_sfx(sfx_key: String, pitch_range: float = -1.0):
	if _audio_disabled:
		return
	var stream := _get_sfx_stream(sfx_key)
	if stream == null:
		return
	_configure_stream_loop(stream, false)
	var policy := _get_sfx_policy(sfx_key)
	if not _can_play_sfx(sfx_key, policy):
		return
	var effective_pitch_range := float(policy.get("pitch_range", 0.0)) if pitch_range < 0.0 else pitch_range
	var priority := int(policy.get("priority", 1))
	if _play_stream_from_pool(sfx_key, stream, effective_pitch_range, priority):
		_last_sfx_played_at[sfx_key] = Time.get_ticks_msec()

func play_loop_sfx(sfx_key: String, fade_time: float = 0.08, volume_db: float = 0.0, pitch_scale: float = 1.0) -> void:
	if _audio_disabled:
		return
	var stream := _get_sfx_stream(sfx_key)
	if stream == null:
		return
	_configure_stream_loop(stream, true)
	var player := _get_loop_sfx_player(sfx_key)
	if player == null:
		return
	_kill_loop_sfx_tween(sfx_key)
	player.stream = stream
	player.pitch_scale = pitch_scale
	player.bus = "SFX"
	if player.playing:
		player.volume_db = volume_db
		return
	if fade_time > 0.0:
		player.volume_db = -80.0
		player.play()
		var tween := player.create_tween()
		_loop_sfx_tweens[sfx_key] = tween
		tween.tween_property(player, "volume_db", volume_db, fade_time)
	else:
		player.volume_db = volume_db
		player.play()

func stop_loop_sfx(sfx_key: String, fade_time: float = 0.08) -> void:
	if _audio_disabled:
		return
	if not _loop_sfx_players.has(sfx_key):
		return
	var player := _loop_sfx_players[sfx_key] as AudioStreamPlayer
	if player == null or not is_instance_valid(player) or not player.playing:
		return
	_kill_loop_sfx_tween(sfx_key)
	if fade_time > 0.0:
		var tween := player.create_tween()
		_loop_sfx_tweens[sfx_key] = tween
		tween.tween_property(player, "volume_db", -80.0, fade_time)
		tween.tween_callback(func():
			player.stop()
			player.volume_db = 0.0
		)
	else:
		player.stop()
		player.volume_db = 0.0

func stop_all_loop_sfx(fade_time: float = 0.08) -> void:
	for key in _loop_sfx_players.keys():
		stop_loop_sfx(str(key), fade_time)

func _play_stream_from_pool(sfx_key: String, stream: AudioStream, pitch_range: float, priority: int) -> bool:
	var pitch := 1.0
	var clamped_pitch_range := maxf(pitch_range, 0.0)
	if clamped_pitch_range > 0.0:
		pitch += randf_range(-clamped_pitch_range, clamped_pitch_range)
	for player in _sfx_pool:
		if not player.playing:
			_start_sfx_player(player, sfx_key, stream, pitch, priority)
			return true
	var fallback := _select_stealable_sfx_player(priority)
	if fallback == null:
		return false
	_start_sfx_player(fallback, sfx_key, stream, pitch, priority)
	return true

func _start_sfx_player(player: AudioStreamPlayer, sfx_key: String, stream: AudioStream, pitch: float, priority: int) -> void:
	player.stop()
	player.stream = stream
	player.pitch_scale = pitch
	player.volume_db = 0.0
	player.bus = "SFX"
	var instance_id := player.get_instance_id()
	_sfx_player_keys[instance_id] = sfx_key
	_sfx_player_priorities[instance_id] = priority
	_sfx_player_started_at[instance_id] = Time.get_ticks_msec()
	player.play()

func _select_stealable_sfx_player(incoming_priority: int) -> AudioStreamPlayer:
	var candidate: AudioStreamPlayer = null
	var candidate_priority := 999
	var candidate_started_at := 9223372036854775807
	for player in _sfx_pool:
		if not player.playing:
			return player
		var instance_id := player.get_instance_id()
		var priority := int(_sfx_player_priorities.get(instance_id, 0))
		if priority > incoming_priority:
			continue
		var started_at := int(_sfx_player_started_at.get(instance_id, 0))
		if candidate == null or priority < candidate_priority or (priority == candidate_priority and started_at < candidate_started_at):
			candidate = player
			candidate_priority = priority
			candidate_started_at = started_at
	return candidate

func _on_sfx_player_finished(player: AudioStreamPlayer) -> void:
	if player == null:
		return
	var instance_id := player.get_instance_id()
	_sfx_player_keys.erase(instance_id)
	_sfx_player_priorities.erase(instance_id)
	_sfx_player_started_at.erase(instance_id)
	player.stream = null

func _get_loop_sfx_player(sfx_key: String) -> AudioStreamPlayer:
	if _loop_sfx_players.has(sfx_key):
		var existing := _loop_sfx_players[sfx_key] as AudioStreamPlayer
		if existing != null and is_instance_valid(existing):
			return existing
	var player := AudioStreamPlayer.new()
	player.name = "LoopSfx_%s" % sfx_key
	player.bus = "SFX"
	add_child(player)
	_loop_sfx_players[sfx_key] = player
	return player

func _kill_loop_sfx_tween(sfx_key: String) -> void:
	if not _loop_sfx_tweens.has(sfx_key):
		return
	var tween := _loop_sfx_tweens[sfx_key] as Tween
	if tween != null and tween.is_valid():
		tween.kill()
	_loop_sfx_tweens.erase(sfx_key)

func _cache_sfx_streams() -> void:
	_sfx_streams.clear()
	for key in SFX_PATHS.keys():
		var stream := _load_audio_stream(str(SFX_PATHS[key]))
		if stream != null:
			_sfx_streams[str(key)] = stream
		else:
			push_warning("[GlobalAudio] Missing SFX stream: %s" % str(SFX_PATHS[key]))

func _get_sfx_stream(sfx_key: String) -> AudioStream:
	if _sfx_streams.has(sfx_key):
		return _sfx_streams[sfx_key] as AudioStream
	if not SFX_PATHS.has(sfx_key):
		return null
	var stream := _load_audio_stream(str(SFX_PATHS[sfx_key]))
	if stream != null:
		_sfx_streams[sfx_key] = stream
	return stream

func _get_sfx_policy(sfx_key: String) -> Dictionary:
	var policy := SFX_DEFAULT_POLICY.duplicate()
	if not SFX_POLICIES.has(sfx_key):
		return policy
	var overrides := SFX_POLICIES[sfx_key] as Dictionary
	for key in overrides.keys():
		policy[key] = overrides[key]
	return policy

func _can_play_sfx(sfx_key: String, policy: Dictionary) -> bool:
	var cooldown := float(policy.get("cooldown", 0.0))
	if cooldown > 0.0:
		var now := Time.get_ticks_msec()
		var cooldown_ms := int(roundf(cooldown * 1000.0))
		var last_played := int(_last_sfx_played_at.get(sfx_key, -cooldown_ms))
		if now - last_played < cooldown_ms:
			return false
	var max_instances := int(policy.get("max_instances", _pool_size))
	return max_instances <= 0 or _count_active_sfx_instances(sfx_key) < max_instances

func _count_active_sfx_instances(sfx_key: String) -> int:
	var count := 0
	for player in _sfx_pool:
		if not player.playing:
			continue
		if str(_sfx_player_keys.get(player.get_instance_id(), "")) == sfx_key:
			count += 1
	return count

func _get_bgm_stream(bgm_key: String) -> AudioStream:
	if _bgm_streams.has(bgm_key):
		return _bgm_streams[bgm_key] as AudioStream
	if not BGM_PATHS.has(bgm_key):
		return null
	var stream := _load_audio_stream(str(BGM_PATHS[bgm_key]))
	if stream != null:
		_bgm_streams[bgm_key] = stream
	else:
		push_warning("[GlobalAudio] Missing BGM stream: %s" % str(BGM_PATHS[bgm_key]))
	return stream

func _load_audio_stream(path: String) -> AudioStream:
	if path == "" or not ResourceLoader.exists(path):
		return null
	return ResourceLoader.load(path) as AudioStream

func _get_active_bgm_player() -> AudioStreamPlayer:
	if _active_bgm_index < 0 or _active_bgm_index >= _bgm_players.size():
		return null
	var player := _bgm_players[_active_bgm_index]
	return player if is_instance_valid(player) else null

func _get_next_bgm_player_index() -> int:
	if _bgm_players.is_empty():
		return -1
	if _active_bgm_index < 0:
		return 0
	return (_active_bgm_index + 1) % _bgm_players.size()

func _stop_inactive_bgm_players() -> void:
	for i in range(_bgm_players.size()):
		if i == _active_bgm_index:
			continue
		var player := _bgm_players[i]
		if is_instance_valid(player):
			player.stop()
			player.stream = null
			player.volume_db = -80.0

func _configure_stream_loop(stream: AudioStream, loop_enabled: bool) -> void:
	if stream is AudioStreamWAV:
		var wav_stream := stream as AudioStreamWAV
		wav_stream.loop_mode = AudioStreamWAV.LOOP_FORWARD if loop_enabled else AudioStreamWAV.LOOP_DISABLED
	elif stream is AudioStreamOggVorbis:
		var ogg_stream := stream as AudioStreamOggVorbis
		ogg_stream.loop = loop_enabled
	elif stream is AudioStreamMP3:
		var mp3_stream := stream as AudioStreamMP3
		mp3_stream.loop = loop_enabled

func set_volume(bus_type: Bus, volume: float):
	_ensure_audio_buses()
	var bus_name = "Master"
	match bus_type:
		Bus.MUSIC: bus_name = "Music"
		Bus.SFX: bus_name = "SFX"
	var idx = AudioServer.get_bus_index(bus_name)
	if idx != -1:
		var clamped := clampf(volume, 0.0, 1.0)
		AudioServer.set_bus_volume_db(idx, -80.0 if clamped <= 0.0 else linear_to_db(clamped))

func _ensure_audio_buses() -> void:
	for bus_name in REQUIRED_AUDIO_BUSES:
		if AudioServer.get_bus_index(bus_name) != -1:
			continue
		var bus_index := AudioServer.get_bus_count()
		AudioServer.add_bus(bus_index)
		AudioServer.set_bus_name(bus_index, bus_name)
		AudioServer.set_bus_send(bus_index, "Master")
