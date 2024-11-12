extends Control

signal clicked()

enum Layout {
	GRID,
	ROW,
}

var layout: Layout:
	set(v):
		layout = v
		update_minimum_size()
		queue_redraw()

var icon_size: Vector2:
	set(v):
		icon_size = v
		update_minimum_size()
		queue_redraw()

var app_key: StringName:
	set(v):
		app_key = v
		queue_redraw()

var _theme_font: Font
var _theme_font_size: int

func _init() -> void:
	theme_type_variation = "AppItemListItem"
	size_flags_horizontal = SIZE_EXPAND_FILL

func _ready() -> void:
	_update_theme_cache()
	theme_changed.connect(_update_theme_cache)

func _get_minimum_size() -> Vector2:
	var text_height = _theme_font.get_height(_theme_font_size) if _theme_font else 0
	match layout:
		Layout.GRID:
			return Vector2(icon_size.x, icon_size.y + text_height)
		Layout.ROW:
			return Vector2(icon_size.x, maxf(icon_size.y, text_height))
	breakpoint
	return Vector2()

func _draw() -> void:
	var app_manifest = AppManager.get_app_manifest(app_key)
	match layout:
		Layout.GRID:
			if app_manifest.icon:
				draw_texture_rect(app_manifest.icon, Rect2(Vector2(size.x / 2 - icon_size.x / 2, 0), icon_size), false)
			draw_string(
				_theme_font,
				Vector2(0, size.y),
				app_manifest.name,
				HORIZONTAL_ALIGNMENT_CENTER,
				size.x,
				_theme_font_size,
				Color.WHITE,
				TextServer.JUSTIFICATION_CONSTRAIN_ELLIPSIS)
		Layout.ROW:
			if app_manifest.icon:
				draw_texture_rect(app_manifest.icon, Rect2(Vector2(0, size.y / 2 - icon_size.y / 2), icon_size), false)
			var text_height = _theme_font.get_height(_theme_font_size) if _theme_font else 0
			draw_string(
				_theme_font,
				Vector2(icon_size.x, size.y / 2 + text_height / 2),
				app_manifest.name,
				HORIZONTAL_ALIGNMENT_LEFT,
				size.x - icon_size.x,
				_theme_font_size,
				Color.WHITE,
				TextServer.JUSTIFICATION_CONSTRAIN_ELLIPSIS)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			clicked.emit()

func _update_theme_cache() -> void:
	_theme_font = get_theme_font("font")
	_theme_font_size = get_theme_font_size("font_size")
	update_minimum_size()
	queue_redraw()
