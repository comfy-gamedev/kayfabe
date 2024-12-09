@tool
class_name AppWindow
extends Container

signal close_requested()
signal closing_window()
signal minimizing_window()

enum {
	FLAG_SHOW_TITLEBAR = 1,
	FLAG_SHOW_FOOTER = 2,
	FLAG_SHOW_USER_BUTTONS = 4,
}

const META_HIT_DETECTED = &"AppWindow_hit_detected"

@export var title: String = "":
	set(v):
		title = v
		if is_instance_valid(frame):
			frame.title = title

@export var close_when_requested: bool = true

@export_group("Frame", "frame_")

@export var frame_scene: PackedScene = preload("default_app_window_frame.tscn")

var service: AppService

var is_current: bool = false

var frame: Control

var is_maximized: bool = false
var is_minimized: bool = false

var _dragging: bool = false
var _drag_resize: bool = false
var _drag_anchor: Vector2

var _rect_before_maximize: Rect2

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_STOP
	
	if theme_type_variation == &"":
		theme_type_variation = &"AppWindow"
	
	frame = frame_scene.instantiate()
	frame.title = title + " " + name
	frame.close_pressed.connect(_on_close_pressed)
	frame.maximize_pressed.connect(_on_maximize_pressed)
	frame.minimize_pressed.connect(_on_minimize_pressed)
	frame.smile_pressed.connect(_on_smile_pressed)
	add_child(frame, false, INTERNAL_MODE_FRONT)

func _process(_delta: float) -> void:
	if _dragging:
		var d := get_local_mouse_position() - _drag_anchor
		if _drag_resize:
			size += d
			_drag_anchor = get_local_mouse_position()
		else:
			position += d
		_dragging = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)

func _notification(what: int) -> void:
	match what:
		NOTIFICATION_SORT_CHILDREN:
			_sort_children()
		NOTIFICATION_THEME_CHANGED:
			pass#_reset_theme_cache()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.has_meta(META_HIT_DETECTED):
			return
		if event.pressed and get_rect().has_point(event.position):
			event.set_meta(META_HIT_DETECTED, true)
			Desktop.current.window_bring_to_front(self)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			accept_event()
			_dragging = true
			_drag_resize = event.position.x >= size.x - 5 and event.position.y >= size.y - 5
			_drag_anchor = event.position
	elif event is InputEventMouseMotion:
		if Rect2(size - Vector2(5, 5), Vector2(5, 5)).has_point(event.position):
			mouse_default_cursor_shape = CURSOR_FDIAGSIZE
		else:
			mouse_default_cursor_shape = CURSOR_ARROW

func _get_allowed_size_flags_horizontal() -> PackedInt32Array:
	return [SIZE_FILL, SIZE_SHRINK_BEGIN, SIZE_SHRINK_CENTER, SIZE_SHRINK_END]

func _get_allowed_size_flags_vertical() -> PackedInt32Array:
	return [SIZE_FILL, SIZE_SHRINK_BEGIN, SIZE_SHRINK_CENTER, SIZE_SHRINK_END]

func _get_minimum_size() -> Vector2:
	var min_size := Vector2.ZERO
	for i: int in get_child_count():
		var c := get_child(i)
		if c is Control:
			if c.visible and not c.top_level:
				min_size = min_size.max(c.get_combined_minimum_size())
	if is_instance_valid(frame):
		min_size += frame.get_frame_size()
		min_size = min_size.max(frame.get_combined_minimum_size())
	return min_size

func _sort_children() -> void:
	if not frame:
		print_stack()
	var content_rect: Rect2 = frame.get_content_rect()
	for i: int in get_child_count():
		var c := get_child(i)
		if c is Control:
			if c.visible and not c.top_level:
				fit_child_in_rect(c, content_rect)

func minimize() -> void:
	visible = false
	minimizing_window.emit()

func maximize() -> void:
	if is_maximized: return
	_rect_before_maximize = get_rect()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	position = Vector2.ZERO
	size = get_parent_area_size()
	queue_sort.call_deferred()
	is_maximized = true

func unmaximize() -> void:
	if not is_maximized: return
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	position = _rect_before_maximize.position
	size = _rect_before_maximize.size
	queue_sort.call_deferred()
	is_maximized = false

func bring_to_front() -> void:
	Desktop.current.window_bring_to_front(self)

func _on_close_pressed() -> void:
	close_requested.emit()
	if close_when_requested:
		closing_window.emit()
		Desktop.current.window_close(self)

func _on_maximize_pressed() -> void:
	if not is_maximized:
		maximize()
	else:
		unmaximize()

func _on_minimize_pressed() -> void:
	if not is_minimized:
		minimize()

func _on_smile_pressed() -> void:
	var voice = DisplayServer.tts_get_voices_for_language("en")[-1]
	DisplayServer.tts_speak("Aeiou", voice, 50, 2.0, 2.0)
