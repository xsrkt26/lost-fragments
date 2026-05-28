class_name RunRngService
extends RefCounted

var rng_seed: int = 0
var rng_state: int = 0

var _rng := RandomNumberGenerator.new()

func set_seed(seed_value: int = 0) -> void:
	rng_seed = seed_value if seed_value != 0 else int(Time.get_ticks_usec())
	_rng.seed = rng_seed
	rng_state = _rng.state

func restore(seed_value: int, state_value: int) -> void:
	if seed_value == 0:
		set_seed()
		return
	rng_seed = seed_value
	_rng.seed = rng_seed
	if state_value != 0:
		_rng.state = state_value
	rng_state = _rng.state

func get_rng() -> RandomNumberGenerator:
	if rng_seed == 0:
		set_seed()
	elif rng_state != 0:
		_rng.state = rng_state
	return _rng

func randf_for_run() -> float:
	var value := get_rng().randf()
	_sync_state()
	return value

func randi_index(max_exclusive: int) -> int:
	if max_exclusive <= 0:
		return 0
	var value := get_rng().randi_range(0, max_exclusive - 1)
	_sync_state()
	return value

func shuffle(values: Array) -> Array:
	var result := values.duplicate()
	if result.size() <= 1:
		return result
	var rng := get_rng()
	for index in range(result.size() - 1, 0, -1):
		var swap_index := rng.randi_range(0, index)
		var current = result[index]
		result[index] = result[swap_index]
		result[swap_index] = current
	_sync_state()
	return result

func serialize() -> Dictionary:
	_sync_state()
	return {
		"rng_seed": rng_seed,
		"rng_state": rng_state,
	}

func _sync_state() -> void:
	rng_state = _rng.state
