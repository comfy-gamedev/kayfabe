@tool
extends Control

signal visual_face_updated()
signal landed()

const D_FACES = {
	"2": preload("d2.png"),
	"4": preload("d4.png"),
	"6": preload("d6.png"),
	"8": preload("d8.png"),
	"10": preload("d10.png"),
	"12": preload("d12.png"),
	"20": preload("d20.png"),
	"F": preload("dF.png"),
}

const D_FACE_SHEETS = {
	"F": preload("dF_faces.png"),
}

@export var kind: String = "20": set = set_kind
@export var face: int = 0: set = set_face

var _font: Font

var _face_override: Variant = null: set = _set_face_override
var _ghost: float = 1.0: set = _set_ghost
var _tween: Tween

func _ready() -> void:
	theme_changed.connect(_update_theme)
	_update_theme()

func _get_minimum_size() -> Vector2:
	return Vector2(32, 32)

func _update_theme() -> void:
	_font = get_theme_font("font")

func _draw() -> void:
	draw_texture_rect(D_FACES[kind], Rect2(Vector2.ZERO, size), false, Color.WHITE, false)
	var face_min := -1 if kind == "F" else 1
	var face_max := 1 if kind == "F" else int(kind)
	var color := (
		Color.GOLD if face == face_max and _face_override == null
		else Color.RED if face == face_min and _face_override == null
		else Color.WHITE)
	var h := _font.get_ascent(16)
	var pos := Vector2(0, size.y/2.0 + h/2.0)
	var sheet: Texture2D = D_FACE_SHEETS.get(kind, null)
	if sheet:
		var face_i: int = face if _face_override == null else _face_override
		draw_texture_rect_region(sheet, Rect2i(Vector2.ZERO, size), Rect2i(Vector2(32 * (face_i - face_min), 0), Vector2(32, 32)), color)
		if _ghost < 1.0:
			var a := Color(1, 1, 1, 1.0 - _ghost)
			draw_set_transform(size / 2.0, 0.0, Vector2.ONE * (1.0 + _ghost))
			draw_texture_rect_region(sheet, Rect2i(-size/2.0, size), Rect2i(Vector2(32 * (face_i - face_min), 0), Vector2(32, 32)), color * a)
	else:
		var face_str := str(face if _face_override == null else _face_override)
		draw_string_outline(_font, pos, face_str, HORIZONTAL_ALIGNMENT_CENTER, size.x, 16, 5, Color.BLACK)
		draw_string(_font, pos, face_str, HORIZONTAL_ALIGNMENT_CENTER, size.x, 16, color)
		if _ghost < 1.0:
			draw_set_transform(size / 2.0, 0.0, Vector2.ONE * (1.0 + _ghost))
			pos = Vector2(-size.x/2.0, h/2.0)
			var a := Color(1, 1, 1, 1.0 - _ghost)
			draw_string_outline(_font, pos, face_str, HORIZONTAL_ALIGNMENT_CENTER, size.x, 16, 5, Color.BLACK * a)
			draw_string(_font, pos, face_str, HORIZONTAL_ALIGNMENT_CENTER, size.x, 16, color * a)

func get_visual_face() -> int:
	return _face_override if _face_override != null else face

func roll() -> void:
	var t = [0.0]
	if _tween:
		_tween.kill()
	var face_min := -1 if kind == "F" else 1
	var face_max := 1 if kind == "F" else int(kind)
	var power := randi_range(2.0, 4.0)
	_tween = create_tween()
	_tween.tween_method(func (dt):
		if dt > 0.0:
			var tt = t[0] + pow(dt, power)
			if int(tt) != int(t[0]):
				_face_override = randi_range(face_min, face_max)
			t[0] = tt
		else:
			_face_override = null
	, 1.0, 0.0, randf_range(1.8, 2.3))
	_tween.tween_callback(landed.emit)
	_tween.tween_method(func (t):
		_ghost = pow(t, 0.5)
	, 0.0, 1.0, 1.0)

func set_kind(v: String) -> void:
	kind = v
	queue_redraw()

func set_face(v: int) -> void:
	face = v
	queue_redraw()

func _set_face_override(v: Variant) -> void:
	if _face_override == v: return
	_face_override = v
	visual_face_updated.emit()
	queue_redraw()

func _set_ghost(v: float) -> void:
	_ghost = v
	queue_redraw()
