@tool
extends Control

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

@export var kind: String = "20": set = set_kind
@export var count: int = 0: set = set_count

var _font: Font

func _ready() -> void:
	theme_changed.connect(_update_theme)
	_update_theme()

func _get_minimum_size() -> Vector2:
	return Vector2(32, 32)

func _update_theme() -> void:
	_font = get_theme_font("font")
	queue_redraw()

func _draw() -> void:
	draw_texture_rect(D_FACES[kind], Rect2(Vector2.ZERO, size), false, Color.WHITE, false)
	var count_str := "x" + str(count)
	draw_string_outline(_font, Vector2(0, size.y), count_str, HORIZONTAL_ALIGNMENT_RIGHT, size.x, 14, 4, Color.BLACK)
	draw_string(_font, Vector2(0, size.y), count_str, HORIZONTAL_ALIGNMENT_RIGHT, size.x, 14, Color.WHITE)

func set_kind(v: String) -> void:
	kind = v
	queue_redraw()

func set_count(v: int) -> void:
	count = v
	queue_redraw()
