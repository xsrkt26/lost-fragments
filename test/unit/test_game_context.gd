extends GutTest


func test_game_context_accepts_missing_state():
	var context = GameContext.new(null)

	assert_null(context.state)
	assert_null(context.event_bus)
	assert_true(context.random_float() >= 0.0)
	assert_eq(context.random_index(0), 0)

