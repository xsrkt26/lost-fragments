extends GutTest

var _game_over_count := 0


func test_game_over_emits_only_when_sanity_crosses_to_zero():
	var gs = autofree(load("res://src/autoload/game_state.gd").new())
	_game_over_count = 0
	gs.game_over.connect(_on_game_over)

	gs.current_sanity = 3
	gs.consume_sanity(5)
	gs.consume_sanity(1)
	gs.current_sanity = 0

	assert_eq(_game_over_count, 1)

func _on_game_over() -> void:
	_game_over_count += 1
