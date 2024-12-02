extends Control

var pmp: Dictionary

func _ready() -> void:
	pmp = get_parent().service.get_cursors().duplicate()
	await get_parent().ready
	get_parent().frame.add_user_button("b1", "b1", preload("res://apps/eyes/smile_icon.tres"))
	get_parent().frame.add_user_button("b2", "b2", preload("res://apps/eyes/smile_icon.tres"))
	get_parent().frame.user_button_pressed.connect(_on_user_button_pressed)

func _process(_delta: float) -> void:
	var mp = get_parent().service.get_cursors()
	if mp != pmp:
		pmp = mp.duplicate()
		queue_redraw()

func _draw() -> void:
	var eyesz = Vector2(size.x / 2.0, size.y)
	_draw_ellipse(size * Vector2(0.25, 0.5), eyesz, Color.WHITE)
	_draw_ellipse(size * Vector2(0.75, 0.5), eyesz, Color.WHITE)
	
	var xform = get_global_transform_with_canvas().affine_inverse()
	for peer_id in pmp:
		if peer_id == multiplayer.get_unique_id():
			continue
		var pos = xform * pmp[peer_id]
		var p1 = size * Vector2(0.25, 0.5) + (pos - size * Vector2(0.25, 0.5)).normalized() * eyesz * 0.4
		var p2 = size * Vector2(0.75, 0.5) + (pos - size * Vector2(0.75, 0.5)).normalized() * eyesz * 0.4
		_draw_ellipse(p1, eyesz * 0.1, Color.RED)
		_draw_ellipse(p2, eyesz * 0.1, Color.RED)
	
	var pos = xform * pmp[multiplayer.get_unique_id()]
	var p1 = size * Vector2(0.25, 0.5) + (pos - size * Vector2(0.25, 0.5)).normalized() * eyesz * 0.4
	var p2 = size * Vector2(0.75, 0.5) + (pos - size * Vector2(0.75, 0.5)).normalized() * eyesz * 0.4
	_draw_ellipse(p1, eyesz * 0.1, Color.BLACK)
	_draw_ellipse(p2, eyesz * 0.1, Color.BLACK)

func _draw_ellipse(pos: Vector2, extents: Vector2, color: Color) -> void:
	draw_set_transform(pos, 0.0, extents)
	draw_circle(Vector2.ZERO, 0.5, color)

func _on_user_button_pressed(id: StringName) -> void:
	var voice = DisplayServer.tts_get_voices_for_language("en")[-1]
	DisplayServer.tts_speak("User button pressed " + id, voice, 50, 2.0, 2.0)
