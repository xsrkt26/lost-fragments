extends GutTest

func test_global_theme_builds_without_font_files() -> void:
	assert_not_null(GlobalTheme.ui_theme)
	assert_true(GlobalTheme.get_body_font_path() is String)
	assert_true(GlobalTheme.get_display_font_path() is String)

func test_global_theme_applies_to_controls() -> void:
	var control := autofree(Control.new())

	GlobalTheme.apply_theme(control)

	assert_eq(control.theme, GlobalTheme.ui_theme)
	assert_true(control.has_meta(GlobalTheme.THEME_META))
