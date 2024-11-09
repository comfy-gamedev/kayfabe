@tool
class_name AppWindowUserButton
extends Button

var _theme_cache: ThemeCache = ThemeCache.new()

func _ready() -> void:
	_refresh_theme()
	_update_icon()
	theme_changed.connect(_refresh_theme)

func _gui_input(event: InputEvent) -> void:
	if Engine.is_editor_hint() and Engine.get_singleton("EditorInterface").get_edited_scene_root().is_ancestor_of(self):
		return
	_update_icon()

func _update_icon() -> void:
	var new_icon: Texture2D
	match get_draw_mode():
		DRAW_DISABLED: new_icon = _theme_cache.disabled_icon
		DRAW_HOVER: new_icon = _theme_cache.hover_icon
		DRAW_HOVER_PRESSED: new_icon = _theme_cache.hover_icon
		DRAW_NORMAL: new_icon = _theme_cache.normal_icon
		DRAW_PRESSED: new_icon = _theme_cache.pressed_icon
	if new_icon != ThemeDB.fallback_icon and new_icon != icon:
		icon = new_icon

func _refresh_theme() -> void:
	_theme_cache.disabled_icon = get_theme_icon("disabled")
	_theme_cache.hover_icon = get_theme_icon("hover")
	_theme_cache.normal_icon = get_theme_icon("normal")
	_theme_cache.pressed_icon = get_theme_icon("pressed")
	_update_icon()

class ThemeCache:
	var disabled_icon: Texture2D
	var hover_icon: Texture2D
	var normal_icon: Texture2D
	var pressed_icon: Texture2D
