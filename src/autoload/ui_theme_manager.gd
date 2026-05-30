extends Node

## 全局 UI 字体主题管理器。
## 字体文件可后续放入 assets/fonts/，缺失时自动回退到 Godot 默认字体。

const BODY_FONT_RESOURCE: FontFile = preload("res://assets/fonts/chill_huosong_f_regular.otf")
const DISPLAY_FONT_RESOURCE: FontFile = preload("res://assets/fonts/chill_huosong_f_ex_bold.otf")
const THEME_META := "_lost_fragments_theme_applied"

var ui_theme: Theme
var body_font: Font
var display_font: Font
var fallback_font: Font

func _ready() -> void:
	reload_theme()
	if get_tree() and not get_tree().node_added.is_connected(_on_node_added):
		get_tree().node_added.connect(_on_node_added)
	call_deferred("apply_theme_to_tree", get_tree().root)

func reload_theme() -> void:
	body_font = BODY_FONT_RESOURCE
	display_font = DISPLAY_FONT_RESOURCE
	fallback_font = BODY_FONT_RESOURCE
	ui_theme = _build_theme()

func apply_theme_to_tree(root: Node) -> void:
	if root == null:
		return
	if root is Control:
		apply_theme(root)
	for child in root.get_children():
		apply_theme_to_tree(child)

func apply_theme(control: Control) -> void:
	if control == null or ui_theme == null:
		return
	if control.theme == null:
		control.theme = ui_theme
	control.set_meta(THEME_META, true)

func get_body_font_path() -> String:
	return body_font.resource_path if body_font != null else ""

func get_display_font_path() -> String:
	return display_font.resource_path if display_font != null else ""

func _build_theme() -> Theme:
	var theme := Theme.new()
	var readable_font: Font = body_font if body_font != null else fallback_font
	var accent_font: Font = display_font if display_font != null else readable_font

	if readable_font != null:
		theme.default_font = readable_font
		for type_name in [
			"Label",
			"OptionButton",
			"CheckButton",
			"LineEdit",
			"TextEdit",
			"PopupMenu",
			"ItemList",
			"Tree",
		]:
			theme.set_font("font", type_name, readable_font)
		for rich_font_name in ["normal_font", "italics_font", "mono_font"]:
			theme.set_font(rich_font_name, "RichTextLabel", readable_font)
		theme.set_font("bold_font", "RichTextLabel", accent_font if accent_font != null else readable_font)
		theme.set_font("bold_italics_font", "RichTextLabel", accent_font if accent_font != null else readable_font)

	if accent_font != null:
		theme.set_font("font", "Button", accent_font)
		theme.set_type_variation("DisplayLabel", "Label")
		theme.set_type_variation("DisplayButton", "Button")
		theme.set_font("font", "DisplayLabel", accent_font)
		theme.set_font("font", "DisplayButton", accent_font)

	return theme

func _on_node_added(node: Node) -> void:
	if node is Control:
		apply_theme(node)
