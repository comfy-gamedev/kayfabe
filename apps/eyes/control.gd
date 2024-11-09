extends Control

var pmp: Vector2

func _ready() -> void:
	pmp = get_global_mouse_position()
	await get_parent().ready
	get_parent().frame.add_user_button("b1", "b1", preload("res://apps/eyes/smile_icon.tres"))
	get_parent().frame.add_user_button("b2", "b2", preload("res://apps/eyes/smile_icon.tres"))
	get_parent().frame.user_button_pressed.connect(_on_user_button_pressed)

func _process(delta: float) -> void:
	var mp = get_global_mouse_position()
	if mp != pmp:
		pmp = mp
		queue_redraw()

func _draw() -> void:
	var eyesz = Vector2(size.x / 2.0, size.y)
	_draw_ellipse(size * Vector2(0.25, 0.5), eyesz, Color.WHITE)
	_draw_ellipse(size * Vector2(0.75, 0.5), eyesz, Color.WHITE)
	
	var p1 = size * Vector2(0.25, 0.5) + (get_local_mouse_position() - size * Vector2(0.25, 0.5)).normalized() * eyesz * 0.4
	_draw_ellipse(p1, eyesz * 0.1, Color.BLACK)
	var p2 = size * Vector2(0.75, 0.5) + (get_local_mouse_position() - size * Vector2(0.75, 0.5)).normalized() * eyesz * 0.4
	_draw_ellipse(p2, eyesz * 0.1, Color.BLACK)

func _draw_ellipse(pos: Vector2, extents: Vector2, color: Color) -> void:
	draw_set_transform(pos, 0.0, extents)
	draw_circle(Vector2.ZERO, 0.5, color)

func _on_user_button_pressed(id: StringName) -> void:
	var voice = DisplayServer.tts_get_voices_for_language("en")[-1]
	DisplayServer.tts_speak("User button pressed " + id, voice, 50, 2.0, 2.0)
