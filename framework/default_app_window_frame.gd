@tool
extends Control

signal close_pressed()
signal maximize_pressed()
signal minimize_pressed()
signal smile_pressed()
signal user_button_pressed(id)

enum Icon {
	NORMAL,
	DISABLED,
	HOVER,
	PRESSED,
}

const ICON_NAMES = [&"normal", &"disabled", &"hover", &"pressed"]
const THEME_TYPE_USER_BUTTON = &"AppWindowUserButton"
const THEME_TYPE_USER_LAST_BUTTON = &"AppWindowUserLastButton"

@export var title: String = "":
	set(v): title = v; _queue_update()

@export var show_titlebar: bool = true:
	set(v): show_titlebar = v; _queue_update()

@export var show_footer: bool = true:
	set(v): show_footer = v; _queue_update()

var _update_queued: bool = true

var _user_buttons: Dictionary

@onready var titlebar_panel_container: PanelContainer = %AppWindowTitlebarPanelContainer
@onready var content_panel_container: PanelContainer = %AppWindowContentPanelContainer
@onready var user_buttons_panel_container: PanelContainer = %AppWindowUserButtonsPanelContainer
@onready var footer_panel_container: PanelContainer = %AppWindowFooterPanelContainer
@onready var window_footer_h_box_container: HBoxContainer = %AppWindowFooterHBoxContainer

@onready var user_buttons_h_box_container: HBoxContainer = %AppWindowUserButtonsHBoxContainer

@onready var titlebar_label: Label = %AppWindowTitlebarLabel

func _ready() -> void:
	_update()

func get_content_rect() -> Rect2:
	var style := content_panel_container.get_theme_stylebox("panel")
	return Rect2(
		content_panel_container.position + style.get_offset(),
		content_panel_container.size - style.get_minimum_size())

func add_user_button(id: StringName, p_tooltip_text: String = "", normal_icon: Texture2D = null, disabled_icon: Texture2D = null, hover_icon: Texture2D = null, pressed_icon: Texture2D = null) -> void:
	if id in _user_buttons:
		push_error("User button already exists with id %s" % id)
		return
	
	var button = AppWindowUserButton.new()
	button.name = "AppWindowUserButton_%s" % id
	button.tooltip_text = p_tooltip_text
	button.size_flags_vertical = SIZE_SHRINK_CENTER
	if normal_icon:
		button.add_theme_icon_override(ICON_NAMES[Icon.NORMAL], normal_icon)
	if disabled_icon:
		button.add_theme_icon_override(ICON_NAMES[Icon.DISABLED], disabled_icon)
	if hover_icon:
		button.add_theme_icon_override(ICON_NAMES[Icon.HOVER], hover_icon)
	if pressed_icon:
		button.add_theme_icon_override(ICON_NAMES[Icon.PRESSED], pressed_icon)
	button.pressed.connect(_on_app_user_button_pressed.bind(id))
	user_buttons_h_box_container.add_child(button)
	_user_buttons[id] = button
	_update_button_themes()

func remove_user_button(id: StringName) -> void:
	var button: AppWindowUserButton = _user_buttons.get(id) as AppWindowUserButton
	if button == null:
		return
	user_buttons_h_box_container.remove_child(button)
	button.queue_free()
	_user_buttons.erase(id)
	_update_button_themes()

func set_button_visible(id: StringName, p_visible: bool) -> void:
	var button: AppWindowUserButton = _user_buttons.get(id) as AppWindowUserButton
	if button == null:
		push_error("Unknown user button id %s" % id)
		return
	button.visible = p_visible
	_update_button_themes()

func set_button_disabled(id: StringName, disabled: bool) -> void:
	var button: AppWindowUserButton = _user_buttons.get(id) as AppWindowUserButton
	if button == null:
		push_error("Unknown user button id %s" % id)
		return
	button.disabled = disabled
	_update_button_themes()

func set_button_icon(id: StringName, icon_type: Icon, icon: Texture2D) -> void:
	var button: AppWindowUserButton = _user_buttons.get(id) as AppWindowUserButton
	if button == null:
		push_error("Unknown user button id %s" % id)
		return
	button.add_theme_icon_override(ICON_NAMES[icon_type], icon)

func _update_button_themes() -> void:
	var n = user_buttons_h_box_container.get_child_count()
	var first = true
	for i in range(n - 1, -1, -1):
		var button: AppWindowUserButton = user_buttons_h_box_container.get_child(i)
		if not button.visible:
			continue
		button.theme_type_variation = THEME_TYPE_USER_LAST_BUTTON if first else THEME_TYPE_USER_BUTTON
		first = false

func _queue_update() -> void:
	if not _update_queued and is_inside_tree():
		_update_queued = true
		_update.call_deferred()

func _update() -> void:
	_update_queued = false
	titlebar_panel_container.visible = show_titlebar
	window_footer_h_box_container.visible = show_footer
	titlebar_label.text = title

func _on_app_window_close_button_pressed() -> void:
	close_pressed.emit()

func _on_app_window_maximize_button_pressed() -> void:
	maximize_pressed.emit()

func _on_app_window_minimize_button_pressed() -> void:
	minimize_pressed.emit()

func _on_app_window_smile_button_pressed() -> void:
	smile_pressed.emit()

func _on_app_user_button_pressed(id: StringName) -> void:
	user_button_pressed.emit(id)
